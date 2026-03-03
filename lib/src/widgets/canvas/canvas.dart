import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/canvas/canvas_controller.dart';
import 'package:mago_widgets/src/widgets/canvas/stroke_models.dart';

typedef MagoStrokeWidthGetter = double Function();
typedef MagoColorGetter = Color Function();
typedef MagoBoolGetter = bool Function();

class _MagoEraserIndicator {
  const _MagoEraserIndicator(this.position, this.radius);

  final Offset position;
  final double radius;
}

class MagoCanvas extends StatefulWidget {
  const MagoCanvas({
    super.key,
    required this.controller,
    required this.strokeWidth,
    required this.eraserWidth,
    required this.color,
    required this.isEraser,
    this.backgroundColor = Colors.transparent,
    this.minPointDistance = 1.5,
    this.onStrokeStart,
    this.onStrokeEnd,
  });

  final MagoCanvasController controller;

  final MagoStrokeWidthGetter strokeWidth;
  final MagoStrokeWidthGetter eraserWidth;
  final MagoColorGetter color;
  final MagoBoolGetter isEraser;

  final Color backgroundColor;
  final double minPointDistance;

  final VoidCallback? onStrokeStart;
  final VoidCallback? onStrokeEnd;

  @override
  State<MagoCanvas> createState() => _MagoCanvasState();
}

class _MagoCanvasState extends State<MagoCanvas> {
  final Map<int, MagoStroke> _activeByPointer = {};
  final Map<int, int> _indexByPointer = {};
  final Map<int, _MagoEraserIndicator> _eraserByPointer = {};
  Size? _canvasSize;

  void _startPointer(int pointerId, Offset p) {
    final erasing = widget.isEraser();
    final width = erasing ? widget.eraserWidth() : widget.strokeWidth();
    final color = widget.color();

    final stroke = MagoStroke(
      points: <Offset>[p],
      color: color,
      width: width,
      isEraser: erasing,
    );

    final index = widget.controller.addStroke(stroke);

    _activeByPointer[pointerId] = stroke;
    _indexByPointer[pointerId] = index;

    if (erasing) {
      _eraserByPointer[pointerId] = _MagoEraserIndicator(p, width / 2);
    }

    widget.onStrokeStart?.call();
  }

  void _appendPointer(int pointerId, Offset p) {
    final active = _activeByPointer[pointerId];
    final index = _indexByPointer[pointerId];

    if (active == null || index == null) return;

    final pts = active.points;
    if (pts.isNotEmpty && (p - pts.last).distance < widget.minPointDistance) {
      return;
    }

    final erasing = widget.isEraser();
    final width = erasing ? widget.eraserWidth() : widget.strokeWidth();
    final color = widget.color();

    final updated = active.copyWith(
      points: <Offset>[...pts, p],
      isEraser: erasing,
      width: width,
      color: color,
    );

    _activeByPointer[pointerId] = updated;
    widget.controller.updateStrokeAt(index, updated);

    if (erasing) {
      _eraserByPointer[pointerId] = _MagoEraserIndicator(p, width / 2);
    } else {
      _eraserByPointer.remove(pointerId);
    }
  }

  void _endPointer(int pointerId) {
    final removed = _activeByPointer.remove(pointerId);
    _indexByPointer.remove(pointerId);
    _eraserByPointer.remove(pointerId);

    if (removed != null) {
      widget.onStrokeEnd?.call();

      if (removed.isEraser && _canvasSize != null) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        widget.controller.flatten(_canvasSize!, devicePixelRatio: dpr);
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _startPointer(e.pointer, e.localPosition),
            onPointerMove: (e) => _appendPointer(e.pointer, e.localPosition),
            onPointerUp: (e) => _endPointer(e.pointer),
            onPointerCancel: (e) => _endPointer(e.pointer),
            child: ValueListenableBuilder<ui.Image?>(
              valueListenable: widget.controller.baseImage,
              builder: (context, baseImage, _) {
                return ValueListenableBuilder<List<MagoStroke>>(
                  valueListenable: widget.controller.strokes,
                  builder: (context, strokes, _) {
                    return CustomPaint(
                      painter: _MagoDrawingPainter(
                        baseImage: baseImage,
                        strokes: strokes,
                        backgroundColor: widget.backgroundColor,
                        erasers:
                            _eraserByPointer.values.toList(growable: false),
                      ),
                      child: const SizedBox.expand(),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MagoDrawingPainter extends CustomPainter {
  _MagoDrawingPainter({
    required this.baseImage,
    required this.strokes,
    required this.backgroundColor,
    required this.erasers,
  });

  final ui.Image? baseImage;
  final List<MagoStroke> strokes;
  final Color backgroundColor;
  final List<_MagoEraserIndicator> erasers;

  @override
  void paint(ui.Canvas canvas, Size size) {
    if (backgroundColor.alpha != 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    }

    final hasEraserStroke = strokes.any((s) => s.isEraser);
    final hasContent = baseImage != null || strokes.isNotEmpty;

    if (!hasContent) return;

    if (hasEraserStroke) {
      canvas.saveLayer(Offset.zero & size, Paint());
    }

    if (baseImage != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        baseImage!.width.toDouble(),
        baseImage!.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(
        baseImage!,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.low,
      );
    }

    for (final stroke in strokes) {
      final pts = stroke.points;
      if (pts.isEmpty) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (stroke.isEraser) {
        paint
          ..blendMode = BlendMode.clear
          ..color = const Color(0x00000000);
      } else {
        paint
          ..blendMode = BlendMode.srcOver
          ..color = stroke.color;
      }

      canvas.drawPath(_smoothPath(pts), paint);
    }

    if (hasEraserStroke) {
      canvas.restore();
    }
    if (erasers.isNotEmpty) {
      final indicatorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true
        ..color = const Color(0x00000000).withAlpha(128);

      for (final e in erasers) {
        final circlePath = Path()
          ..addOval(Rect.fromCircle(center: e.position, radius: e.radius));

        _drawDashedPath(canvas, circlePath, indicatorPaint, dash: 6, gap: 5);
      }
    }
  }

  void _drawDashedPath(
    ui.Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  Path _smoothPath(List<Offset> pts) {
    final path = Path();

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
      final mid = Offset(
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

  @override
  bool shouldRepaint(covariant _MagoDrawingPainter oldDelegate) {
    return oldDelegate.baseImage != baseImage ||
        oldDelegate.strokes != strokes ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.erasers != erasers;
  }
}
