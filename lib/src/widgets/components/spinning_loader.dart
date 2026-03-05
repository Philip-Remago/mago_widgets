import 'dart:math' as math;

import 'package:flutter/material.dart';

class MagoSpinningLoader extends StatefulWidget {
  final double size;

  final double strokeWidth;

  final Color? color;

  final Color? trackColor;

  final Duration rotationDuration;

  final double sweepAngle;

  const MagoSpinningLoader({
    super.key,
    this.size = 32,
    this.strokeWidth = 3.5,
    this.color,
    this.trackColor,
    this.rotationDuration = const Duration(milliseconds: 900),
    this.sweepAngle = 270,
  });

  @override
  State<MagoSpinningLoader> createState() => _MagoSpinningLoaderState();
}

class _MagoSpinningLoaderState extends State<MagoSpinningLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.rotationDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant MagoSpinningLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rotationDuration != oldWidget.rotationDuration) {
      _controller.duration = widget.rotationDuration;
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _SpinningLoaderPainter(
            rotationAngle: _controller.value * 2 * math.pi,
            sweepAngle: widget.sweepAngle,
            strokeWidth: widget.strokeWidth,
            color: resolvedColor,
            trackColor: widget.trackColor,
          ),
        );
      },
    );
  }
}

class _SpinningLoaderPainter extends CustomPainter {
  _SpinningLoaderPainter({
    required this.rotationAngle,
    required this.sweepAngle,
    required this.strokeWidth,
    required this.color,
    this.trackColor,
  });

  final double rotationAngle;
  final double sweepAngle;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final rect = Rect.fromCircle(center: centre, radius: radius);

    if (trackColor != null) {
      final trackPaint = Paint()
        ..color = trackColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(centre, radius, trackPaint);
    }

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepRad = sweepAngle * math.pi / 180;

    canvas.drawArc(rect, rotationAngle, sweepRad, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SpinningLoaderPainter oldDelegate) =>
      rotationAngle != oldDelegate.rotationAngle ||
      sweepAngle != oldDelegate.sweepAngle ||
      strokeWidth != oldDelegate.strokeWidth ||
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor;
}
