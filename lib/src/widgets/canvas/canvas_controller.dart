import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:mago_widgets/src/widgets/canvas/stroke_models.dart';

class _CanvasSnapshot {
  _CanvasSnapshot({
    required this.image,
    required this.strokes,
    required this.pixelRatio,
  });

  final ui.Image? image;
  final List<MagoStroke> strokes;
  final double pixelRatio;

  void dispose() {
    image?.dispose();
  }
}

class MagoCanvasController {
  MagoCanvasController({int maxUndoHistory = 20})
      : _maxUndoHistory = maxUndoHistory;

  final int _maxUndoHistory;
  int get maxUndoHistory => _maxUndoHistory;

  final ValueNotifier<List<MagoStroke>> strokes =
      ValueNotifier<List<MagoStroke>>(<MagoStroke>[]);

  final ValueNotifier<ui.Image?> baseImage = ValueNotifier<ui.Image?>(null);

  double _baseImagePixelRatio = 1.0;
  double get baseImagePixelRatio => _baseImagePixelRatio;

  final List<_CanvasSnapshot> _undoStack = <_CanvasSnapshot>[];

  final List<_CanvasSnapshot> _redoStack = <_CanvasSnapshot>[];

  bool get canUndo => strokes.value.isNotEmpty || _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void setAll(List<MagoStroke> value) {
    _clearRedoStack();
    strokes.value = List<MagoStroke>.unmodifiable(value);
  }

  int addStroke(MagoStroke s) {
    _clearRedoStack();
    final next = [...strokes.value, s];
    strokes.value = List.unmodifiable(next);
    return next.length - 1;
  }

  void updateStrokeAt(int index, MagoStroke s) {
    final current = strokes.value;
    if (index < 0 || index >= current.length) return;
    final next = [...current];
    next[index] = s;
    strokes.value = List.unmodifiable(next);
  }

  void clear() {
    _clearUndoStack();
    _clearRedoStack();
    baseImage.value?.dispose();
    baseImage.value = null;
    strokes.value = const <MagoStroke>[];
  }

  void undo() {
    final current = strokes.value;

    if (current.isNotEmpty) {
      _redoStack.add(_CanvasSnapshot(
        image: null,
        strokes: current,
        pixelRatio: _baseImagePixelRatio,
      ));
      strokes.value =
          List<MagoStroke>.unmodifiable(current.sublist(0, current.length - 1));
      return;
    }

    if (_undoStack.isEmpty) return;

    _redoStack.add(_CanvasSnapshot(
      image: baseImage.value,
      strokes: strokes.value,
      pixelRatio: _baseImagePixelRatio,
    ));

    final snapshot = _undoStack.removeLast();
    baseImage.value = snapshot.image;
    _baseImagePixelRatio = snapshot.pixelRatio;
    strokes.value = List<MagoStroke>.unmodifiable(snapshot.strokes);
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    final snapshot = _redoStack.removeLast();

    if (snapshot.image == null && snapshot.strokes.isNotEmpty) {
      strokes.value = List<MagoStroke>.unmodifiable(snapshot.strokes);
      snapshot.dispose();
      return;
    }

    _undoStack.add(_CanvasSnapshot(
      image: baseImage.value,
      strokes: strokes.value,
      pixelRatio: _baseImagePixelRatio,
    ));

    baseImage.value = snapshot.image;
    _baseImagePixelRatio = snapshot.pixelRatio;
    strokes.value = List<MagoStroke>.unmodifiable(snapshot.strokes);
  }

  void _clearUndoStack() {
    for (final snapshot in _undoStack) {
      snapshot.dispose();
    }
    _undoStack.clear();
  }

  void _clearRedoStack() {
    for (final snapshot in _redoStack) {
      snapshot.dispose();
    }
    _redoStack.clear();
  }

  Map<String, dynamic> toJsonMap() {
    return <String, dynamic>{
      'version': 1,
      'strokes': strokes.value.map(_strokeToJson).toList(growable: false),
    };
  }

  String toJsonString({bool pretty = false}) {
    final map = toJsonMap();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  void loadFromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) return;

    final list = decoded['strokes'];
    if (list is! List) return;

    final parsed = <MagoStroke>[];
    for (final item in list) {
      final s = _strokeFromJson(item);
      if (s != null) parsed.add(s);
    }

    setAll(parsed);
  }

  Future<Uint8List> toPngBytes({
    required ui.Size size,
    ui.Color backgroundColor = const ui.Color(0x00000000),
    double pixelRatio = 1.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    if (pixelRatio != 1.0) {
      canvas.scale(pixelRatio, pixelRatio);
    }

    final scaledSize = ui.Size(size.width, size.height);

    if (backgroundColor.a != 0) {
      canvas.drawRect(
        ui.Offset.zero & scaledSize,
        ui.Paint()..color = backgroundColor,
      );
    }

    final current = strokes.value;
    final existingBase = baseImage.value;
    final hasEraserStroke = current.any((s) => s.isEraser);

    if (existingBase != null && !hasEraserStroke) {
      canvas.drawImage(existingBase, ui.Offset.zero, ui.Paint());
    }

    if (hasEraserStroke) {
      canvas.saveLayer(ui.Offset.zero & scaledSize, ui.Paint());
      if (existingBase != null) {
        canvas.drawImage(existingBase, ui.Offset.zero, ui.Paint());
      }
    }

    for (final stroke in current) {
      final pts = stroke.points;
      if (pts.isEmpty) continue;

      final paint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..isAntiAlias = true;

      if (stroke.isEraser) {
        paint
          ..blendMode = ui.BlendMode.clear
          ..color = const ui.Color(0x00000000);
      } else {
        paint
          ..blendMode = ui.BlendMode.srcOver
          ..color = stroke.color;
      }

      canvas.drawPath(_smoothPath(pts), paint);
    }

    if (hasEraserStroke) {
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return Uint8List(0);
    return byteData.buffer.asUint8List();
  }

  Future<void> flatten(ui.Size size, {double devicePixelRatio = 1.0}) async {
    final current = strokes.value;
    final existingBase = baseImage.value;
    if (current.isEmpty && existingBase == null) return;

    _saveToUndoStack();
    _clearRedoStack();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.scale(devicePixelRatio, devicePixelRatio);

    final hasEraserStroke = current.any((s) => s.isEraser);

    canvas.saveLayer(ui.Offset.zero & size, ui.Paint());

    if (existingBase != null) {
      final srcRect = ui.Rect.fromLTWH(
        0,
        0,
        existingBase.width.toDouble(),
        existingBase.height.toDouble(),
      );
      final dstRect = ui.Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(
        existingBase,
        srcRect,
        dstRect,
        ui.Paint()..filterQuality = ui.FilterQuality.low,
      );
    }

    for (final stroke in current) {
      final pts = stroke.points;
      if (pts.isEmpty) continue;

      final paint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..isAntiAlias = true;

      if (stroke.isEraser) {
        paint
          ..blendMode = ui.BlendMode.clear
          ..color = const ui.Color(0x00000000);
      } else {
        paint
          ..blendMode = ui.BlendMode.srcOver
          ..color = stroke.color;
      }

      canvas.drawPath(_smoothPath(pts), paint);
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final newImage = await picture.toImage(
      (size.width * devicePixelRatio).round(),
      (size.height * devicePixelRatio).round(),
    );

    _baseImagePixelRatio = devicePixelRatio;
    baseImage.value = newImage;

    strokes.value = const <MagoStroke>[];
  }

  void _saveToUndoStack() {
    final currentImage = baseImage.value;

    _undoStack.add(_CanvasSnapshot(
      image: currentImage,
      strokes: strokes.value,
      pixelRatio: _baseImagePixelRatio,
    ));

    while (_undoStack.length > _maxUndoHistory) {
      _undoStack.removeAt(0).dispose();
    }
  }

  void dispose() {
    _clearUndoStack();
    _clearRedoStack();
    baseImage.value?.dispose();
    baseImage.dispose();
    strokes.dispose();
  }
}

Map<String, dynamic> _strokeToJson(MagoStroke s) {
  return <String, dynamic>{
    'color': s.color.value,
    'width': s.width,
    'isEraser': s.isEraser,
    'points': s.points
        .map((p) => <String, double>{'dx': p.dx, 'dy': p.dy})
        .toList(growable: false),
  };
}

MagoStroke? _strokeFromJson(dynamic data) {
  if (data is! Map) return null;

  final colorValue = data['color'];
  final width = data['width'];
  final isEraser = data['isEraser'];
  final pointsRaw = data['points'];

  if (colorValue is! int) return null;
  if (width is! num) return null;
  if (isEraser is! bool) return null;
  if (pointsRaw is! List) return null;

  final points = <ui.Offset>[];
  for (final p in pointsRaw) {
    if (p is Map) {
      final dx = p['dx'];
      final dy = p['dy'];
      if (dx is num && dy is num) {
        points.add(ui.Offset(dx.toDouble(), dy.toDouble()));
      }
    }
  }

  return MagoStroke(
    points: points,
    color: ui.Color(colorValue),
    width: width.toDouble(),
    isEraser: isEraser,
  );
}

ui.Path _smoothPath(List<ui.Offset> pts) {
  final path = ui.Path();

  if (pts.length == 1) {
    final o = pts.first;
    path.moveTo(o.dx, o.dy);
    path.lineTo(o.dx + 0.01, o.dy + 0.01);
    return path;
  }

  path.moveTo(pts.first.dx, pts.first.dy);

  for (int i = 1; i < pts.length - 1; i++) {
    final current = pts[i];
    final next = pts[i + 1];
    final mid = ui.Offset(
      (current.dx + next.dx) / 2,
      (current.dy + next.dy) / 2,
    );
    path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
  }

  final secondLast = pts[pts.length - 2];
  final last = pts.last;
  path.quadraticBezierTo(secondLast.dx, secondLast.dy, last.dx, last.dy);

  return path;
}
