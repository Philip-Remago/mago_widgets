import 'dart:ui';

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.blurSigma = 10,
    this.backgroundOpacity = 0.2,
    this.borderOpacity = 0.3,
    this.borderWidth = 0.5,
    this.backgroundColor,
    this.borderColor,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget? child;

  final double? width;

  final double? height;

  final BorderRadius borderRadius;

  final EdgeInsetsGeometry? padding;

  final double blurSigma;

  final double backgroundOpacity;

  final double borderOpacity;

  final double borderWidth;

  final Color? backgroundColor;

  final Color? borderColor;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgBase = backgroundColor ??
        (isDark
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surface);
    final brdBase = borderColor ?? theme.colorScheme.onSurface;

    final resolvedBg = bgBase.withValues(alpha: backgroundOpacity);

    final lightEdge =
        brdBase.withValues(alpha: (borderOpacity * 1.8).clamp(0.0, 1.0));
    final darkEdge =
        brdBase.withValues(alpha: (borderOpacity * 0.2).clamp(0.0, 1.0));
    final midEdge = brdBase.withValues(alpha: borderOpacity);

    // SweepGradient keeps light/dark at corners regardless of aspect ratio.
    // Sweep starts at 3-o'clock and goes clockwise:
    //   0.0  → right        (mid)
    //   0.125 → bottom-right (light)
    //   0.25  → bottom       (mid)
    //   0.375 → bottom-left  (dark)
    //   0.5   → left         (mid)
    //   0.625 → top-left     (light)
    //   0.75  → top          (mid)
    //   0.875 → top-right    (dark)
    //   1.0   → right        (mid)
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: borderRadius,
        border: GradientBoxBorder(
          width: borderWidth,
          gradient: SweepGradient(
            center: Alignment.center,
            colors: [
              midEdge,
              lightEdge,
              midEdge,
              darkEdge,
              midEdge,
              lightEdge,
              midEdge,
              darkEdge,
              midEdge,
            ],
            stops: const [
              0.0,
              0.125,
              0.25,
              0.375,
              0.5,
              0.625,
              0.75,
              0.875,
              1.0,
            ],
          ),
        ),
      ),
      child: child != null
          ? (padding != null ? Padding(padding: padding!, child: child) : child)
          : null,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}

class GradientBoxBorder extends BoxBorder {
  const GradientBoxBorder({
    required this.gradient,
    this.width = 1.0,
  });

  final Gradient gradient;
  final double width;

  @override
  BorderSide get top => BorderSide.none;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  ShapeBorder scale(double t) =>
      GradientBoxBorder(gradient: gradient, width: width * t);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final adjustedRect = rect.deflate(width / 2);

    if (shape == BoxShape.circle) {
      canvas.drawCircle(
          adjustedRect.center, adjustedRect.shortestSide / 2, paint);
    } else if (borderRadius != null) {
      canvas.drawRRect(
        borderRadius.resolve(textDirection).toRRect(adjustedRect),
        paint,
      );
    } else {
      canvas.drawRect(adjustedRect, paint);
    }
  }
}
