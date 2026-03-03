import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart' as pp;
import 'package:pdfrx_engine/pdfrx_engine.dart' as engine;

import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart' show kIsWeb;

class _ImgEntry {
  final ui.Image image;
  _ImgEntry(this.image);
}

class PdfImageBus extends ChangeNotifier {
  static final PdfImageBus _instance = PdfImageBus._();
  PdfImageBus._();
  factory PdfImageBus() => _instance;

  final _tinyLRU = <String, _ImgEntry>{};
  final _previewLRU = <String, _ImgEntry>{};
  final _fullLRU = <String, _ImgEntry>{};

  int maxTiny = 800;
  int maxPreview = 220;
  int maxFull = 20;

  ui.Image? getTiny(String k) => _tinyLRU[k]?.image;
  ui.Image? getPreview(String k) => _previewLRU[k]?.image;
  ui.Image? getFull(String k) => _fullLRU[k]?.image;

  bool hasTiny(String k) => _tinyLRU.containsKey(k);
  bool hasPreview(String k) => _previewLRU.containsKey(k);
  bool hasFull(String k) => _fullLRU.containsKey(k);

  void putTiny(String k, ui.Image img) => _put(_tinyLRU, k, img, maxTiny);
  void putPreview(String k, ui.Image img) =>
      _put(_previewLRU, k, img, maxPreview);
  void putFull(String k, ui.Image img) => _put(_fullLRU, k, img, maxFull);

  void _put(Map<String, _ImgEntry> lru, String k, ui.Image img, int cap) {
    lru.remove(k);
    lru[k] = _ImgEntry(img);
    while (lru.length > cap) {
      final oldest = lru.keys.first;
      lru[oldest]?.image.dispose();
      lru.remove(oldest);
    }
    notifyListeners();
  }

  void disposeAll() {
    for (final e in _tinyLRU.values) {
      e.image.dispose();
    }
    for (final e in _previewLRU.values) {
      e.image.dispose();
    }
    for (final e in _fullLRU.values) {
      e.image.dispose();
    }
    _tinyLRU.clear();
    _previewLRU.clear();
    _fullLRU.clear();
    notifyListeners();
  }
}

class RenderPool {
  int maxConcurrent;
  int _inFlight = 0;
  final Queue<Future<void> Function()> _queue = Queue();

  RenderPool({this.maxConcurrent = 3});

  void tuneForDevice(double dpr, Size screen, {int? override}) {
    if (override != null) {
      maxConcurrent = override;
      return;
    }
    if (dpr >= 3.0 || screen.width > 2000) {
      maxConcurrent = 3;
    } else if (screen.width < 800) {
      maxConcurrent = 1;
    } else {
      maxConcurrent = 2;
    }
  }

  Future<T> schedule<T>(Future<T> Function() task) {
    final c = Completer<T>();
    void run() async {
      _inFlight++;
      try {
        c.complete(await task());
      } catch (e, st) {
        if (!c.isCompleted) c.completeError(e, st);
      } finally {
        _inFlight--;
        _drain();
      }
    }

    if (_inFlight < maxConcurrent) {
      run();
    } else {
      _queue.add(() async => run());
    }
    return c.future;
  }

  void _drain() {
    if (_inFlight >= maxConcurrent || _queue.isEmpty) return;
    _queue.removeFirst()();
  }

  void clear() => _queue.clear();
}

class PdfStateRegistry {
  static final PdfStateRegistry _instance = PdfStateRegistry._();
  PdfStateRegistry._();
  factory PdfStateRegistry() => _instance;

  final Map<String, int> _pages = {};
  final Map<String, engine.PdfDocument?> _docs = {};
  final Map<String, Map<int, Size>> _sizes = {};
  final Map<String, double> _aspects = {};
  final Map<String, Set<int>> _rendered = {};
  final Map<String, bool> _bgLoading = {};

  int getPage(String id) => _pages[id] ?? 1;
  void setPage(String id, int p) => _pages[id] = p;

  engine.PdfDocument? getDoc(String id) => _docs[id];
  void setDoc(String id, engine.PdfDocument? d) => _docs[id] = d;

  Map<int, Size>? getSizes(String id) => _sizes[id];
  void setSizes(String id, Map<int, Size> s) => _sizes[id] = s;

  double? getAspect(String id) => _aspects[id];
  void setAspect(String id, double a) => _aspects[id] = a;

  Set<int> getRendered(String id) => _rendered[id] ?? {};
  void setRendered(String id, Set<int> s) => _rendered[id] = s;

  bool isBgLoading(String id) => _bgLoading[id] ?? false;
  void setBgLoading(String id, bool v) => _bgLoading[id] = v;

  void clear(String id) {
    _pages.remove(id);
    _docs[id]?.dispose();
    _docs.remove(id);
    _sizes.remove(id);
    _aspects.remove(id);
    _rendered.remove(id);
    _bgLoading.remove(id);
  }
}

class PdfService {
  final String? baseUrl;
  final double thumbLongEdge;
  final double tinyLongEdge;
  final int jpegQuality;
  final int httpTimeoutSec;
  final int openTimeoutSec;

  final Map<String, Uint8List> _thumbBytes = {};
  final Map<String, Uint8List> _tinyBytes = {};
  final Map<String, String> _thumbPaths = {};

  PdfService({
    this.baseUrl,
    this.thumbLongEdge = 250.0,
    this.tinyLongEdge = 224.0,
    this.jpegQuality = 72,
    this.httpTimeoutSec = 20,
    this.openTimeoutSec = 15,
  });

  Future<Uint8List?> fetchPdfBytes(String url) async {
    try {
      final res = await http
          .get(Uri.parse(normalizeUrl(url)))
          .timeout(Duration(seconds: httpTimeoutSec));
      return res.statusCode == 200 ? res.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  Uint8List? getCachedThumbnailBytes(String url) =>
      _thumbBytes[normalizeUrl(url)];

  String? getCachedThumbnailPath(String url) => _thumbPaths[normalizeUrl(url)];

  Future<Uint8List?> generateThumbnailBytes(String url) async {
    final norm = normalizeUrl(url);
    if (_thumbBytes.containsKey(norm)) return _thumbBytes[norm];

    if (!kIsWeb) {
      final diskPath = await _candidateThumbPath(norm);
      if (diskPath != null) {
        final f = File(diskPath);
        if (await f.exists()) {
          try {
            final bytes = await f.readAsBytes();
            _thumbBytes[norm] = bytes;
            _thumbPaths[norm] = diskPath;
            return bytes;
          } catch (_) {}
        }
      }
    }

    final bytes = await _renderThumb(norm, longEdge: thumbLongEdge);
    if (bytes == null) return null;
    _thumbBytes[norm] = bytes;

    if (!kIsWeb) {
      try {
        final path = await _ensureThumbPath(norm);
        await File(path).writeAsBytes(bytes, flush: true);
        _thumbPaths[norm] = path;
      } catch (_) {}
    }
    return bytes;
  }

  Future<String?> generateThumbnail(String url) async {
    if (kIsWeb) return null;
    final norm = normalizeUrl(url);
    final cached = _thumbPaths[norm];
    if (cached != null && await File(cached).exists()) return cached;
    await generateThumbnailBytes(norm);
    return _thumbPaths[norm];
  }

  Stream<Uint8List> streamThumbnailBytes(String url) async* {
    final norm = normalizeUrl(url);
    final full = _thumbBytes[norm];
    if (full != null) {
      yield full;
      return;
    }
    var tiny = _tinyBytes[norm];
    tiny ??= await _renderThumb(norm, longEdge: tinyLongEdge);
    if (tiny != null) {
      _tinyBytes[norm] = tiny;
      yield tiny;
    }
    final bytes = await generateThumbnailBytes(norm);
    if (bytes != null) yield bytes;
  }

  Future<void> prewarmThumbnails(Iterable<String> urls) async {
    for (final raw in urls) {
      final norm = normalizeUrl(raw);
      unawaited(() async {
        _tinyBytes[norm] ??=
            await _renderThumb(norm, longEdge: tinyLongEdge) ?? Uint8List(0);
      }());
      unawaited(generateThumbnailBytes(norm));
    }
  }

  void dispose() {
    _thumbBytes.clear();
    _tinyBytes.clear();
    if (!kIsWeb) {
      for (final p in _thumbPaths.values) {
        try {
          final f = File(p);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
    _thumbPaths.clear();
  }

  String normalizeUrl(String raw) {
    var r = raw.trim();
    if (r.startsWith('pdf:')) r = r.substring(4);
    if (r.startsWith('file:')) r = r.substring(5);
    final abs = Uri.tryParse(r);
    if (abs != null &&
        abs.hasScheme &&
        (abs.scheme == 'http' || abs.scheme == 'https')) {
      return abs.toString();
    }
    if (baseUrl == null) return r;
    final base = Uri.parse(baseUrl!);
    if (r.startsWith('//')) return '${base.scheme}:$r';
    final withSlash = r.startsWith('/') ? r : '/$r';
    return base.resolve(withSlash).toString();
  }

  Future<Uint8List?> _renderThumb(
    String normUrl, {
    required double longEdge,
  }) async {
    try {
      final file = await DefaultCacheManager()
          .getSingleFile(normUrl)
          .timeout(Duration(seconds: httpTimeoutSec));
      final bytes = await file.readAsBytes();

      final doc = await engine.PdfDocument.openData(bytes)
          .timeout(Duration(seconds: openTimeoutSec));
      if (doc.pages.isEmpty) {
        await doc.dispose();
        return null;
      }

      final page = doc.pages.first;
      final pw = page.width.toDouble();
      final ph = page.height.toDouble();
      final landscape = pw >= ph;
      final rW = landscape ? longEdge : (longEdge * pw / ph);
      final rH = landscape ? (longEdge * ph / pw) : longEdge;

      final pdfImg = await page.render(
        fullWidth: rW,
        fullHeight: rH,
        backgroundColor: 0xFFFFFFFF,
      );
      if (pdfImg == null) {
        await doc.dispose();
        return null;
      }

      final nf = pdfImg.createImageNF();
      pdfImg.dispose();
      await doc.dispose();
      return Uint8List.fromList(img.encodeJpg(nf, quality: jpegQuality));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _candidateThumbPath(String normUrl) async {
    if (kIsWeb) return null;
    try {
      final dir = await _thumbDir();
      return '${dir.path}/${_stableThumbName(normUrl)}';
    } catch (_) {
      return null;
    }
  }

  Future<String> _ensureThumbPath(String normUrl) async {
    final dir = await _thumbDir();
    return '${dir.path}/${_stableThumbName(normUrl)}';
  }

  Future<Directory> _thumbDir() async {
    final tmp = await pp.getTemporaryDirectory();
    final d = Directory('${tmp.path}/pdf_thumbs');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _stableThumbName(String normUrl) {
    final h = _fnv1a(normUrl);
    return 'pdfthumb_${h}_q${jpegQuality}_l${thumbLongEdge.toInt()}.jpg';
  }

  static int _fnv1a(String s) {
    int h = 2166136261;
    for (int i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 16777619) & 0xffffffff;
    }
    return h;
  }

  static Size fitSize(double sw, double sh, double bw, double bh) {
    final s = math.min(bw / sw, bh / sh);
    return Size(sw * s, sh * s);
  }

  static double bucketScale(double x) => (x * 4.0).round() / 4.0;
}
