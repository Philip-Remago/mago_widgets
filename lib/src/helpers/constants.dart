// App-wide constants

import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';

class GlassProperties {
  const GlassProperties({
    this.blurSigma = 10,
    this.backgroundOpacity = 0.2,
    this.borderOpacity = 0.3,
    this.borderWidth = 0.5,
    this.backgroundColor,
    this.borderColor,
    this.clipBehavior = Clip.antiAlias,
  });

  final double blurSigma;

  final double backgroundOpacity;

  final double borderOpacity;

  final double borderWidth;

  final Color? backgroundColor;

  final Color? borderColor;

  final Clip clipBehavior;
  GlassProperties copyWith({
    double? blurSigma,
    double? backgroundOpacity,
    double? borderOpacity,
    double? borderWidth,
    Color? backgroundColor,
    Color? borderColor,
    Clip? clipBehavior,
  }) {
    return GlassProperties(
      blurSigma: blurSigma ?? this.blurSigma,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      borderOpacity: borderOpacity ?? this.borderOpacity,
      borderWidth: borderWidth ?? this.borderWidth,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      clipBehavior: clipBehavior ?? this.clipBehavior,
    );
  }
}

GradientBoxBorder glassBorder(
  BuildContext context, {
  GlassProperties properties = const GlassProperties(),
  double? borderWidth,
  double? borderOpacity,
  Color? borderColor,
}) {
  final effectiveWidth = borderWidth ?? properties.borderWidth;
  final effectiveOpacity = borderOpacity ?? properties.borderOpacity;
  final effectiveColor = borderColor ?? properties.borderColor;

  final theme = Theme.of(context);
  final brdBase = effectiveColor ?? theme.colorScheme.onSurface;

  final lightEdge =
      brdBase.withValues(alpha: (effectiveOpacity * 1.8).clamp(0.0, 1.0));
  final darkEdge =
      brdBase.withValues(alpha: (effectiveOpacity * 0.2).clamp(0.0, 1.0));
  final midEdge = brdBase.withValues(alpha: effectiveOpacity);

  return GradientBoxBorder(
    width: effectiveWidth,
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
  );
}
