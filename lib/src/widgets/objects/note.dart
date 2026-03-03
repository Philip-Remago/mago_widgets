import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/canvas/canvas_controller.dart';
import 'package:mago_widgets/src/widgets/canvas/canvas.dart' as stage_canvas;
import 'package:mago_widgets/src/widgets/canvas/stroke_models.dart';

class MagoNote extends StatefulWidget {
  final String? id;

  final Color? noteColor;

  const MagoNote(
      {super.key, this.id, this.noteColor = const Color(0xFFFFF9C4)});

  @override
  State<MagoNote> createState() => _MagoNoteState();
}

class _MagoNoteState extends State<MagoNote> {
  static const double _designW = 1920;
  static const double _designH = 1080;

  late final String _id;
  final MagoCanvasController _canvasController = MagoCanvasController();

  bool _isEraser = false;
  Color _color = Colors.black;

  @override
  String get syncObjectId => _id;

  @override
  String get syncObjectType => 'note';

  @override
  void initState() {
    _id = widget.id ?? 'note_${DateTime.now().millisecondsSinceEpoch}';
    super.initState();
  }

  @override
  void dispose() {
    _canvasController.dispose();
    super.dispose();
  }

  @override
  void handleRemoteUpdate(Map<String, dynamic> data) {
    final action = data['action'] as String?;

    switch (action) {
      case 'stroke':
        final s = _strokeFromMap(data['data'] as Map<String, dynamic>?);
        if (s != null) _canvasController.addStroke(s);
        break;
      case 'clear':
        _canvasController.clear();
        break;
      case 'sync':
        final list = data['strokes'] as List?;
        if (list != null) {
          final strokes = list
              .map((e) => _strokeFromMap(e as Map<String, dynamic>?))
              .whereType<MagoStroke>()
              .toList();
          _canvasController.setAll(strokes);
        }
        break;
    }
  }

  void _onStrokeEnd() {
    final strokes = _canvasController.strokes.value;
    if (strokes.isEmpty) return;
  }

  void _onClear() {
    _canvasController.clear();
  }

  Map<String, dynamic> _strokeToMap(MagoStroke s) {
    return {
      'color': s.color.value,
      'width': s.width,
      'isEraser': s.isEraser,
      'points': s.points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    };
  }

  MagoStroke? _strokeFromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final colorValue = data['color'];
    final width = data['width'];
    final isEraser = data['isEraser'];
    final pointsRaw = data['points'];

    if (colorValue is! int) return null;
    if (width is! num) return null;
    if (isEraser is! bool) return null;
    if (pointsRaw is! List) return null;

    final points = <Offset>[];
    for (final p in pointsRaw) {
      if (p is Map) {
        final dx = p['dx'];
        final dy = p['dy'];
        if (dx is num && dy is num) {
          points.add(Offset(dx.toDouble(), dy.toDouble()));
        }
      }
    }

    return MagoStroke(
      points: points,
      color: Color(colorValue),
      width: width.toDouble(),
      isEraser: isEraser,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final noteColor = widget.noteColor!;

    return LayoutBuilder(
      builder: (context, constraints) {
        const ar = 16 / 9;
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        if (!maxW.isFinite || !maxH.isFinite || maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }

        double w = maxW;
        double h = w / ar;
        if (h > maxH) {
          h = maxH;
          w = h * ar;
        }

        w = math.min(w, maxW);
        h = math.min(h, maxH);

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRect(
              clipBehavior: Clip.hardEdge,
              child: Container(
                decoration: BoxDecoration(
                  color: noteColor,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _designW,
                    height: _designH,
                    child: ClipRect(
                      clipBehavior: Clip.hardEdge,
                      child: stage_canvas.MagoCanvas(
                        controller: _canvasController,
                        backgroundColor: noteColor,
                        strokeWidth: () => 5,
                        eraserWidth: () => 14,
                        color: () => _color,
                        isEraser: () => _isEraser,
                        onStrokeEnd: _onStrokeEnd,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
