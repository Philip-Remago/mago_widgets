import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:pdfrx_engine/pdfrx_engine.dart' as engine;

import 'package:mago_widgets/src/services/pdf_service.dart';
import 'package:mago_widgets/src/widgets/components/object_loader.dart';

Future<ui.Image> _pdfImageToUiImage(engine.PdfImage pdfImg) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pdfImg.pixels,
    pdfImg.width,
    pdfImg.height,
    ui.PixelFormat.bgra8888,
    (image) => c.complete(image),
  );
  return c.future;
}

class MagoPdf extends StatefulWidget {
  final String url;

  final int initialPage;

  final String? contentId;

  final String? baseUrl;

  final int? maxConcurrentRenders;

  final TransformationController? externalController;

  final ValueChanged<int>? onPageChanged;

  final ValueChanged<int>? onDocumentLoaded;

  final ValueChanged<VoidCallback>? onNextPageCallback;
  final ValueChanged<VoidCallback>? onPrevPageCallback;

  final ValueChanged<Size>? onPageIntrinsicSize;

  final void Function(
    Map<String, double> xData,
    Map<String, double> yData,
    Map<String, double> scaleData,
  )? onZoomChanged;

  const MagoPdf({
    super.key,
    required this.url,
    this.initialPage = 1,
    this.contentId,
    this.baseUrl,
    this.maxConcurrentRenders,
    this.externalController,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onNextPageCallback,
    this.onPrevPageCallback,
    this.onPageIntrinsicSize,
    this.onZoomChanged,
  });

  @override
  State<MagoPdf> createState() => MagoPdfState();
}

class MagoPdfState extends State<MagoPdf>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  engine.PdfDocument? _doc;
  int _pageCount = 0;
  int _currentPage = 1;
  bool _opened = false;
  int _resetToken = 0;
  String? _errorMessage;

  final _bus = PdfImageBus();
  final _pool = RenderPool();
  final _registry = PdfStateRegistry();
  final Map<int, Size> _pageSizes = {};

  Size _layoutSize = const Size(1920, 1080);

  final Set<int> _localRendered = {};
  bool _localBgLoading = false;
  Timer? _warmTimer;
  Timer? _bgTimer;

  TransformationController? _internalZoomCtrl;
  TransformationController? get _zoomCtrl =>
      widget.externalController ?? _internalZoomCtrl;

  final ValueNotifier<bool> _lockScroll = ValueNotifier(false);
  final ValueNotifier<int> _pointers = ValueNotifier(0);

  Set<int> get _rendered => widget.contentId == null
      ? _localRendered
      : _registry.getRendered(widget.contentId!);

  void _markRendered(int page) {
    if (widget.contentId == null) {
      _localRendered.add(page);
    } else {
      _registry.setRendered(
        widget.contentId!,
        Set<int>.from(_rendered)..add(page),
      );
    }
  }

  bool get _isBgLoading => widget.contentId == null
      ? _localBgLoading
      : _registry.isBgLoading(widget.contentId!);

  set _isBgLoading(bool v) {
    if (widget.contentId == null) {
      _localBgLoading = v;
    } else {
      _registry.setBgLoading(widget.contentId!, v);
    }
  }

  int get pageCount => _pageCount;
  int get currentPage => _currentPage;
  int get loadedPageCount => _rendered.length;
  bool get isBackgroundLoading => _isBgLoading;
  Size? get currentPageSize => _pageSizes[_currentPage];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _restoreState();

    if (_doc == null) _openDocument(widget.url);

    if (widget.externalController == null) {
      _internalZoomCtrl = TransformationController();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNextPageCallback?.call(_nextPage);
      widget.onPrevPageCallback?.call(_prevPage);
      _scrollToPage(_currentPage);
    });
  }

  void _restoreState() {
    if (widget.contentId != null) {
      final id = widget.contentId!;
      _currentPage = _registry.getPage(id);
      _doc = _registry.getDoc(id);

      final sizes = _registry.getSizes(id);
      if (sizes != null) _pageSizes.addAll(sizes);

      if (_doc != null) {
        _pageCount = _doc!.pages.length;
        _opened = true;

        if (_registry.isBgLoading(id) && _rendered.length < _pageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _doc != null && !_isBgLoading) {
              _startBackgroundLoading();
            }
          });
        }
      }
    } else {
      _currentPage = widget.initialPage;
    }
  }

  @override
  void didUpdateWidget(covariant MagoPdf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _closeDoc();
      _bus.disposeAll();
      _pageCount = 0;
      _currentPage = widget.initialPage;
      _opened = false;
      _errorMessage = null;
      _bgTimer?.cancel();
      _isBgLoading = false;
      if (widget.contentId != null) {
        _registry.setRendered(widget.contentId!, {});
      }
      _openDocument(widget.url);
      setState(() {});
    }
    if (oldWidget.initialPage != widget.initialPage)
      updatePage(widget.initialPage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warmTimer?.cancel();
    _bgTimer?.cancel();
    _internalZoomCtrl?.dispose();
    _lockScroll.dispose();
    _closeDoc();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleWarm(200);
      if (!_isBgLoading && _rendered.length < _pageCount) {
        _startBackgroundLoading();
      }
    }
  }

  void updatePage(int page) {
    if (_pageCount == 0) return;
    final target = page.clamp(1, _pageCount);
    if (_currentPage == target) return;

    _currentPage = target;
    _lockScroll.value = false;
    _scrollToPage(target);
    _resetToken++;

    widget.onZoomChanged?.call({'x': 0.0}, {'y': 0.0}, {'scale': 1.0});
    setState(() {});
    _prefetch(target);

    if (widget.contentId != null) {
      _registry.setPage(widget.contentId!, _currentPage);
    }
    widget.onPageChanged?.call(target);

    if (!_isBgLoading && _rendered.length < _pageCount) {
      _startBackgroundLoading();
    }
  }

  void _nextPage() {
    if (_currentPage < _pageCount) updatePage(_currentPage + 1);
  }

  void _prevPage() {
    if (_currentPage > 1) updatePage(_currentPage - 1);
  }

  void _scrollToPage(int page) {
    // PageView handles scrolling via didUpdateWidget on _PdfScroller
  }

  Future<void> _openDocument(String rawUrl) async {
    _opened = false;
    try {
      engine.Pdfrx.getCacheDirectory ??=
          () async => (await pp.getApplicationCacheDirectory()).path;

      final url = _normalize(rawUrl);
      final file = await DefaultCacheManager()
          .getSingleFile(url)
          .timeout(const Duration(seconds: 20));
      final bytes = await file.readAsBytes();

      engine.PdfDocument doc;
      try {
        doc = await engine.PdfDocument.openData(bytes);
      } on engine.PdfException catch (e) {
        if (e.toString().contains('No password supplied')) {
          doc = await engine.PdfDocument.openData(
            bytes,
            passwordProvider: () async => '',
          );
        } else {
          _errorMessage = 'PDF parse error: $e';
          _opened = true;
          if (mounted) setState(() {});
          return;
        }
      }

      _doc = doc;
      _pageCount = doc.pages.length;
      _pageSizes.clear();
      for (var i = 0; i < _pageCount; i++) {
        final p = doc.pages[i];
        _pageSizes[i + 1] = Size(p.width.toDouble(), p.height.toDouble());
      }

      if (widget.contentId != null) {
        final id = widget.contentId!;
        _registry.setDoc(id, doc);
        _registry.setSizes(id, Map.from(_pageSizes));
        final first = _pageSizes[1];
        if (first != null) {
          _registry.setAspect(id, first.width / first.height);
        }
        _currentPage = _registry.getPage(id).clamp(1, _pageCount);
      } else {
        _currentPage = widget.initialPage.clamp(1, _pageCount);
      }

      widget.onDocumentLoaded?.call(_pageCount);
      widget.onPageChanged?.call(_currentPage);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onNextPageCallback?.call(_nextPage);
        widget.onPrevPageCallback?.call(_prevPage);
      });

      if (!mounted) return;
      final media = MediaQuery.of(context);
      _pool.tuneForDevice(
        media.devicePixelRatio,
        media.size,
        override: widget.maxConcurrentRenders,
      );

      await _renderTiny(_currentPage);
      _renderTiered(_currentPage, prioritise: true);
      _prefetch(_currentPage);
      _scheduleWarm(500);

      _opened = true;
      if (mounted) setState(() {});
    } catch (e, st) {
      _errorMessage = 'Load error: $e';
      debugPrint('MagoPdf load error: $e\n$st');
      _opened = true;
      if (mounted) setState(() {});
    }
  }

  static const double _tinyEdge = 256.0;
  static const double _previewEdge = 1024.0;

  String _key(String kind, int page, [double? bucket]) {
    final url = _normalize(widget.url);
    if (kind == 'tiny') return '$url|$page|tiny';
    if (kind == 'preview') return '$url|$page|preview';
    return '$url|$page|full|$bucket';
  }

  Future<void> _renderTiny(int page) async {
    final doc = _doc;
    if (doc == null) return;
    final pd = doc.pages[page - 1];
    final pw = pd.width.toDouble(), ph = pd.height.toDouble();
    final scale = (pw >= ph) ? (_tinyEdge / pw) : (_tinyEdge / ph);
    final key = _key('tiny', page);
    if (_bus.hasTiny(key)) return;
    try {
      final raw = await pd.render(
        fullWidth: pw * scale,
        fullHeight: ph * scale,
        backgroundColor: 0xFFFFFFFF,
      );
      if (raw == null) return;
      final img = await _pdfImageToUiImage(raw);
      raw.dispose();
      _bus.putTiny(key, img);
    } catch (_) {}
  }

  void _renderTiered(int page, {bool prioritise = false}) {
    final doc = _doc;
    if (doc == null || page < 1 || page > _pageCount) return;
    final pd = doc.pages[page - 1];
    final pw = pd.width.toDouble(), ph = pd.height.toDouble();
    final dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);

    final tKey = _key('tiny', page);
    _pool.schedule(() async {
      if (_bus.hasTiny(tKey)) return;
      final s = (pw >= ph) ? (_tinyEdge / pw) : (_tinyEdge / ph);
      final raw = await pd.render(
        fullWidth: pw * s,
        fullHeight: ph * s,
        backgroundColor: 0xFFFFFFFF,
      );
      if (raw == null) return;
      final img = await _pdfImageToUiImage(raw);
      raw.dispose();
      _bus.putTiny(tKey, img);
    });

    final pKey = _key('preview', page);
    _pool.schedule(() async {
      if (_bus.hasPreview(pKey)) return;
      final s = (pw >= ph) ? (_previewEdge / pw) : (_previewEdge / ph);
      final raw = await pd.render(
        fullWidth: pw * s,
        fullHeight: ph * s,
        backgroundColor: 0xFFFFFFFF,
      );
      if (raw == null) return;
      final img = await _pdfImageToUiImage(raw);
      raw.dispose();
      _bus.putPreview(pKey, img);
    });

    if (prioritise) {
      final targetW = _layoutSize.width * dpr;
      final targetH = _layoutSize.height * dpr;
      final fit = PdfService.fitSize(pw, ph, targetW, targetH);
      final fScale = PdfService.bucketScale(
        (pw >= ph) ? (fit.width / pw) : (fit.height / ph),
      );
      final fKey = _key('full', page, fScale);
      _pool.schedule(() async {
        if (_bus.hasFull(fKey)) return;
        final raw = await pd.render(
          fullWidth: pw * fScale,
          fullHeight: ph * fScale,
          backgroundColor: 0xFFFFFFFF,
        );
        if (raw == null) return;
        final img = await _pdfImageToUiImage(raw);
        raw.dispose();
        _bus.putFull(fKey, img);
      });
    }
  }

  void _prefetch(int center) {
    const radius = 3;
    final lo = (center - radius).clamp(1, _pageCount);
    final hi = (center + radius).clamp(1, _pageCount);
    for (int p = lo; p <= hi; p++) {
      if (p != center) _renderTiered(p);
    }
  }

  void _scheduleWarm(int delayMs) {
    _warmTimer?.cancel();
    _warmTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_doc == null || _pageCount == 0) return;
      for (int p = 1; p <= _pageCount; p++) {
        if ((p - _currentPage).abs() <= 5) _renderTiered(p);
      }
      if (!_isBgLoading) _startBackgroundLoading();
    });
  }

  void _startBackgroundLoading() {
    if (_isBgLoading || _doc == null || _pageCount == 0) return;
    if (_rendered.length >= _pageCount) return;
    _isBgLoading = true;
    _bgTimer?.cancel();
    _loadNextBatch();
  }

  Future<void> _loadNextBatch() async {
    if (!mounted || _doc == null || !_isBgLoading) return;

    final batch = <int>[];
    final slow = (_layoutSize.width < 1000);
    final batchSize = slow ? 1 : 2;

    for (int d = 0; d <= _pageCount && batch.length < batchSize; d++) {
      final before = _currentPage - d;
      final after = _currentPage + d;
      if (before >= 1 && !_rendered.contains(before)) batch.add(before);
      if (d > 0 && after <= _pageCount && !_rendered.contains(after)) {
        batch.add(after);
      }
    }

    if (batch.isEmpty) {
      _isBgLoading = false;
      return;
    }

    await Future.wait(batch.map((p) async {
      try {
        await _renderFastPass(p);
      } catch (_) {}
      _markRendered(p);
    }));

    if (!mounted || !_isBgLoading) return;

    if (_rendered.length < _pageCount) {
      _bgTimer?.cancel();
      _bgTimer = Timer(Duration(milliseconds: slow ? 1200 : 800), () {
        if (mounted && _isBgLoading) _loadNextBatch();
      });
    } else {
      _isBgLoading = false;
    }
  }

  Future<void> _renderFastPass(int page) async {
    final doc = _doc;
    if (doc == null || page < 1 || page > _pageCount) return;
    final pd = doc.pages[page - 1];
    final pw = pd.width.toDouble(), ph = pd.height.toDouble();

    const tinyLong = 192.0;
    final tKey = _key('tiny', page);
    if (!_bus.hasTiny(tKey)) {
      final s = (pw >= ph) ? (tinyLong / pw) : (tinyLong / ph);
      final raw = await _pool.schedule(
        () => pd.render(
          fullWidth: pw * s,
          fullHeight: ph * s,
          backgroundColor: 0xFFFFFFFF,
        ),
      );
      if (raw != null) {
        final img = await _pdfImageToUiImage(raw);
        raw.dispose();
        _bus.putTiny(tKey, img);
      }
    }

    if (_layoutSize.width >= 1000) {
      const prevLong = 768.0;
      final pKey = _key('preview', page);
      if (!_bus.hasPreview(pKey)) {
        final s = (pw >= ph) ? (prevLong / pw) : (prevLong / ph);
        final raw = await _pool.schedule(
          () => pd.render(
            fullWidth: pw * s,
            fullHeight: ph * s,
            backgroundColor: 0xFFFFFFFF,
          ),
        );
        if (raw != null) {
          final img = await _pdfImageToUiImage(raw);
          raw.dispose();
          _bus.putPreview(pKey, img);
        }
      }
    }
  }

  String _normalize(String raw) {
    var r = raw.trim();
    if (r.startsWith('pdf:')) r = r.substring(4);
    final parsed = Uri.tryParse(r);
    if (parsed != null &&
        parsed.hasScheme &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return parsed.toString();
    }
    if (widget.baseUrl == null) return r;
    final base = Uri.parse(widget.baseUrl!);
    if (r.startsWith('//')) return '${base.scheme}:$r';
    final withSlash = r.startsWith('/') ? r : '/$r';
    return base.resolve(withSlash).toString();
  }

  void _closeDoc() {
    if (widget.contentId == null) {
      try {
        _doc?.dispose();
      } catch (_) {}
    }
    _doc = null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(builder: (ctx, constraints) {
      if (constraints.maxWidth.isFinite && constraints.maxHeight.isFinite) {
        _layoutSize = Size(constraints.maxWidth, constraints.maxHeight);
      }
      return _buildContent();
    });
  }

  Widget _buildContent() {
    Size displayFromAspect(double ar) {
      final la = _layoutSize.width / _layoutSize.height;
      return ar > la
          ? Size(_layoutSize.width, _layoutSize.width / ar)
          : Size(_layoutSize.height * ar, _layoutSize.height);
    }

    if (!_opened) {
      final ar = _resolveAspect();
      if (ar != null) {
        final s = displayFromAspect(ar);
        return SizedBox(
          width: s.width,
          height: s.height,
          child: const ColoredBox(color: Color(0xFFF2F2F2)),
        );
      }
      return const MagoObjectLoader();
    }

    if (_doc == null || _pageCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage ?? 'Failed to load PDF',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final ar = _resolveAspect();
    final display = ar != null ? displayFromAspect(ar) : _layoutSize;

    return ValueListenableBuilder<bool>(
      valueListenable: _lockScroll,
      builder: (_, locked, __) => SizedBox(
        width: display.width,
        height: display.height,
        child: Listener(
          onPointerDown: (_) {
            _pointers.value++;
            if (_pointers.value >= 2) _lockScroll.value = true;
          },
          onPointerUp: (_) {
            _pointers.value = (_pointers.value - 1).clamp(0, 10);
            if (_pointers.value == 0) _lockScroll.value = false;
          },
          child: _PdfScroller(
            pageCount: _pageCount,
            currentPage: _currentPage,
            lockScroll: locked,
            pageWidth: display.width,
            onPageChanged: (i) {
              final p = i + 1;
              if (_currentPage == p) return;
              _currentPage = p;
              _lockScroll.value = false;
              if (widget.contentId != null) {
                _registry.setPage(widget.contentId!, p);
              }
              widget.onPageChanged?.call(p);
              _resetToken++;
              widget.onZoomChanged
                  ?.call({'x': 0.0}, {'y': 0.0}, {'scale': 1.0});
              _renderTiered(p, prioritise: true);
              _prefetch(p);
              setState(() {});
            },
            pageBuilder: (ctx, i) {
              final page = i + 1;
              return _PdfPageTile(
                page: page,
                intrinsicSize: _pageSizes[page],
                controller: _zoomCtrl,
                onZoomChanged: widget.onZoomChanged,
                onGestureActive: (active, _) => _lockScroll.value = active,
                bus: _bus,
                layoutSize: display,
                makeKey: (kind, [double? b]) => _key(kind, page, b),
                ensureRendered: (p) =>
                    _renderTiered(p, prioritise: p == _currentPage),
                onIntrinsic: (sz) => widget.onPageIntrinsicSize?.call(sz),
                resetToken: _resetToken,
              );
            },
          ),
        ),
      ),
    );
  }

  double? _resolveAspect() {
    if (widget.contentId != null) {
      final cached = _registry.getAspect(widget.contentId!);
      if (cached != null) return cached;
    }
    final ps = _pageSizes[_currentPage] ?? _pageSizes[1];
    return ps != null ? ps.width / ps.height : null;
  }
}

class _PdfScroller extends StatefulWidget {
  final int pageCount;
  final int currentPage;
  final bool lockScroll;
  final double pageWidth;
  final ValueChanged<int> onPageChanged;
  final IndexedWidgetBuilder pageBuilder;

  const _PdfScroller({
    required this.pageCount,
    required this.currentPage,
    required this.lockScroll,
    required this.pageWidth,
    required this.onPageChanged,
    required this.pageBuilder,
  });

  @override
  State<_PdfScroller> createState() => _PdfScrollerState();
}

class _PdfScrollerState extends State<_PdfScroller> {
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(initialPage: widget.currentPage - 1);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PdfScroller old) {
    super.didUpdateWidget(old);
    if (old.currentPage != widget.currentPage) {
      _ctrl.animateToPage(
        widget.currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.pageWidth,
        child: PageView.builder(
          controller: _ctrl,
          physics: widget.lockScroll
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: widget.onPageChanged,
          itemCount: widget.pageCount,
          itemBuilder: widget.pageBuilder,
        ),
      ),
    );
  }
}

class _PdfPageTile extends StatefulWidget {
  final int page;
  final Size? intrinsicSize;
  final TransformationController? controller;
  final void Function(
    Map<String, double>,
    Map<String, double>,
    Map<String, double>,
  )? onZoomChanged;
  final void Function(bool active, double scale)? onGestureActive;
  final int resetToken;
  final PdfImageBus bus;
  final Size layoutSize;
  final String Function(String kind, [double? bucket]) makeKey;
  final void Function(int page) ensureRendered;
  final ValueChanged<Size> onIntrinsic;

  const _PdfPageTile({
    required this.page,
    this.intrinsicSize,
    this.controller,
    this.onZoomChanged,
    this.onGestureActive,
    required this.resetToken,
    required this.bus,
    required this.layoutSize,
    required this.makeKey,
    required this.ensureRendered,
    required this.onIntrinsic,
  });

  @override
  State<_PdfPageTile> createState() => _PdfPageTileState();
}

class _PdfPageTileState extends State<_PdfPageTile> {
  @override
  void initState() {
    super.initState();
    widget.ensureRendered(widget.page);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final tKey = widget.makeKey('tiny');
    final pKey = widget.makeKey('preview');

    String? fKey;
    if (widget.intrinsicSize != null) {
      final pw = widget.intrinsicSize!.width;
      final ph = widget.intrinsicSize!.height;
      final tw = widget.layoutSize.width * dpr;
      final th = widget.layoutSize.height * dpr;
      final fit = PdfService.fitSize(pw, ph, tw, th);
      final s = PdfService.bucketScale(
        (pw >= ph) ? (fit.width / pw) : (fit.height / ph),
      ).clamp(0.25, 4.0);
      fKey = widget.makeKey('full', s);
    }

    return AnimatedBuilder(
      animation: widget.bus,
      builder: (_, __) {
        final ui.Image? img =
            (fKey != null ? widget.bus.getFull(fKey) : null) ??
                widget.bus.getPreview(pKey) ??
                widget.bus.getTiny(tKey);

        Size? intrinsic = widget.intrinsicSize;
        if (intrinsic == null && img != null) {
          intrinsic = Size(img.width.toDouble(), img.height.toDouble());
        }
        if (intrinsic != null) widget.onIntrinsic(intrinsic);

        if (img == null || intrinsic == null) {
          return Container(color: const Color(0xFFF2F2F2));
        }

        final base = PdfService.fitSize(
          intrinsic.width,
          intrinsic.height,
          widget.layoutSize.width,
          widget.layoutSize.height,
        );

        final content = SizedBox(
          width: base.width,
          height: base.height,
          child: RawImage(
            image: img,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        );

        return ClipRect(
          child: _ZoomViewer(
            baseSize: base,
            resetToken: widget.resetToken,
            controller: widget.controller,
            onZoomChanged: widget.onZoomChanged,
            onGestureActive: widget.onGestureActive,
            child: SizedBox(
              width: widget.layoutSize.width,
              height: widget.layoutSize.height,
              child: Center(child: content),
            ),
          ),
        );
      },
    );
  }
}

class _ZoomViewer extends StatefulWidget {
  final Size baseSize;
  final int resetToken;
  final double minScale;
  final double maxScale;
  final Widget child;
  final TransformationController? controller;
  final void Function(
    Map<String, double>,
    Map<String, double>,
    Map<String, double>,
  )? onZoomChanged;
  final void Function(bool active, double scale)? onGestureActive;

  const _ZoomViewer({
    required this.baseSize,
    required this.resetToken,
    this.minScale = 1.0,
    this.maxScale = 6.0,
    required this.child,
    this.controller,
    this.onZoomChanged,
    this.onGestureActive,
  });

  @override
  State<_ZoomViewer> createState() => _ZoomViewerState();
}

class _ZoomViewerState extends State<_ZoomViewer> {
  TransformationController? _internal;
  int _pointers = 0;

  TransformationController get _ctrl => widget.controller ?? _internal!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internal = TransformationController();
    }
    _ctrl.addListener(_onTransform);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTransform);
    _internal?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ZoomViewer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onTransform);
      _internal?.removeListener(_onTransform);
      if (widget.controller == null && _internal == null) {
        _internal = TransformationController();
      } else if (widget.controller != null) {
        _internal?.dispose();
        _internal = null;
      }
      _ctrl.addListener(_onTransform);
    }
    if (old.resetToken != widget.resetToken) {
      _ctrl.value = Matrix4.identity();
      _emitZoom();
    }
  }

  void _onTransform() {
    _snapToIdentityIfMin();
    _emitZoom();
    if (mounted) setState(() {});
  }

  void _snapToIdentityIfMin() {
    final s = _ctrl.value.getMaxScaleOnAxis();
    if (s <= widget.minScale + 1e-6) {
      final m = _ctrl.value;
      if (m.storage[12] != 0.0 ||
          m.storage[13] != 0.0 ||
          (s - 1.0).abs() > 1e-9) {
        _ctrl.value = Matrix4.identity();
      }
    }
  }

  void _emitZoom() {
    final cb = widget.onZoomChanged;
    if (cb == null) return;
    final m = _ctrl.value;
    final t = m.getTranslation();
    cb(
      {'xOffset': t.x, 'contentWidth': widget.baseSize.width},
      {'yOffset': t.y, 'contentHeight': widget.baseSize.height},
      {'scale': m.getMaxScaleOnAxis()},
    );
  }

  bool get _isZoomed =>
      _ctrl.value.getMaxScaleOnAxis() > widget.minScale + 1e-6;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        _pointers++;
        widget.onGestureActive?.call(
          _pointers >= 2 || _isZoomed,
          _ctrl.value.getMaxScaleOnAxis(),
        );
      },
      onPointerUp: (_) => _decPointer(),
      onPointerCancel: (_) => _decPointer(),
      child: InteractiveViewer(
        transformationController: _ctrl,
        panEnabled: _isZoomed,
        scaleEnabled: true,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        constrained: false,
        boundaryMargin: EdgeInsets.all(
          widget.baseSize.width * (widget.maxScale - 1.0) / 2,
        ),
        clipBehavior: Clip.hardEdge,
        onInteractionStart: (_) => widget.onGestureActive?.call(
          true,
          _ctrl.value.getMaxScaleOnAxis(),
        ),
        onInteractionEnd: (_) => widget.onGestureActive?.call(
          false,
          _ctrl.value.getMaxScaleOnAxis(),
        ),
        child: widget.child,
      ),
    );
  }

  void _decPointer() {
    _pointers = (_pointers - 1).clamp(0, 10);
    if (_pointers == 0) {
      widget.onGestureActive?.call(false, _ctrl.value.getMaxScaleOnAxis());
    }
  }
}

class MagoPdfNoOverscroll extends ScrollBehavior {
  const MagoPdfNoOverscroll();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
