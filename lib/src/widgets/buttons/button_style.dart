import 'package:flutter/material.dart';

enum MagoButtonVariant { filled, outline, ghost }

class MagoButtonColors {
  final Color background;
  final Color foreground;
  final BorderSide? borderSide;

  const MagoButtonColors({
    required this.background,
    required this.foreground,
    this.borderSide,
  });
}

class MagoButtonStyle {
  static MagoButtonColors resolve(
    BuildContext context, {
    required bool enabled,
    required MagoButtonVariant variant,
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    double borderWidth = 1,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!enabled) {
      return MagoButtonColors(
        background: cs.surfaceContainerHighest,
        foreground: cs.onSurface.withAlpha(115),
        borderSide: variant == MagoButtonVariant.filled
            ? null
            : BorderSide(color: cs.outline.withAlpha(64), width: borderWidth),
      );
    }

    switch (variant) {
      case MagoButtonVariant.filled:
        return MagoButtonColors(
          background: backgroundColor ?? cs.primary,
          foreground: foregroundColor ?? Colors.white,
        );

      case MagoButtonVariant.outline:
        return MagoButtonColors(
          background: Colors.transparent,
          foreground: foregroundColor ?? cs.primary,
          borderSide: BorderSide(
            color: borderColor ?? cs.outline,
            width: borderWidth,
          ),
        );

      case MagoButtonVariant.ghost:
        return MagoButtonColors(
          background: Colors.transparent,
          foreground: foregroundColor ?? cs.primary,
          borderSide: null,
        );
    }
  }
}
