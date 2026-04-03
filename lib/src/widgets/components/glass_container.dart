import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mago_widgets/src/helpers/constants.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.constraints,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.glassProperties = const GlassProperties(),
  });

  final Widget? child;

  final double? width;

  final double? height;

  final BoxConstraints? constraints;

  final BorderRadius borderRadius;

  final EdgeInsetsGeometry? padding;

  final GlassProperties? glassProperties;

  @override
  Widget build(BuildContext context) {
    final props = glassProperties;

    if (props == null) {
      Widget plain = SizedBox(
        width: width,
        height: height,
        child: child != null
            ? (padding != null
                ? Padding(padding: padding!, child: child)
                : child)
            : null,
      );
      if (constraints != null) {
        plain = ConstrainedBox(constraints: constraints!, child: plain);
      }
      return ClipRRect(borderRadius: borderRadius, child: plain);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgBase = props.backgroundColor ??
        (isDark
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surface);

    final resolvedBg = bgBase.withValues(alpha: props.backgroundOpacity);

    Widget content = Container(
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: borderRadius,
        border: glassBorder(context, properties: props),
      ),
      child: child != null
          ? (padding != null ? Padding(padding: padding!, child: child) : child)
          : null,
    );

    if (props.blurSigma > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: props.clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: props.blurSigma,
            sigmaY: props.blurSigma,
          ),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: props.clipBehavior,
        child: content,
      );
    }

    if (props.boxShadow != null && props.boxShadow!.isNotEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: props.boxShadow!,
        ),
        child: content,
      );
    }

    return content;
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
