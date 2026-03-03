// ignore_for_file: library_prefixes

import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/buttons/button_style.dart'
    as stageButtonStyle;
import 'package:mago_widgets/src/widgets/components/glass_container.dart';

abstract class MagoButton extends StatefulWidget {
  const MagoButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.variant = stageButtonStyle.MagoButtonVariant.filled,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.minHeight = 48,
    this.minWidth,
    this.maxHeight,
    this.maxWidth,
    this.expand = false,
  });

  final VoidCallback? onPressed;
  final bool enabled;

  final stageButtonStyle.MagoButtonVariant variant;

  final EdgeInsets padding;
  final BorderRadius borderRadius;

  final Color? backgroundColor;
  final Color? foregroundColor;

  final Color? borderColor;
  final double borderWidth;

  final double minHeight;
  final double? minWidth;

  final double? maxHeight;
  final double? maxWidth;

  final bool expand;

  bool get isEnabled => enabled && onPressed != null;

  @protected
  Widget buildContent(BuildContext context);

  @protected
  TextStyle? resolveTextStyle(BuildContext context, Color fg) {
    final theme = Theme.of(context);
    return theme.textTheme.labelLarge?.copyWith(color: fg);
  }

  @override
  State<MagoButton> createState() => _MagoButtonState();
}

class _MagoButtonState extends State<MagoButton> {
  bool _isPressed = false;

  Color _vibrantShift(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation + 0.15).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.08).clamp(0.0, 0.85))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = stageButtonStyle.MagoButtonStyle.resolve(
      context,
      enabled: widget.isEnabled,
      variant: widget.variant,
      backgroundColor: widget.backgroundColor,
      foregroundColor: widget.foregroundColor,
      borderColor: widget.borderColor,
      borderWidth: widget.borderWidth,
    );

    final isFilled =
        widget.variant == stageButtonStyle.MagoButtonVariant.filled;

    Color bg = resolved.background;
    Color fg = resolved.foreground;
    double bgOpacity = isFilled ? 0.75 : 0.15;

    if (_isPressed && widget.isEnabled) {
      switch (widget.variant) {
        case stageButtonStyle.MagoButtonVariant.filled:
          bg = _vibrantShift(bg);
          break;
        case stageButtonStyle.MagoButtonVariant.outline:
        case stageButtonStyle.MagoButtonVariant.ghost:
          bg = widget.backgroundColor ?? theme.colorScheme.primary;
          fg = Colors.white;
          bgOpacity = 0.75;
          break;
      }
    }

    final child = DefaultTextStyle(
      style: widget.resolveTextStyle(context, fg) ?? TextStyle(color: fg),
      child: IconTheme(
        data: IconThemeData(color: fg),
        child: widget.buildContent(context),
      ),
    );

    final button = GlassContainer(
      borderRadius: widget.borderRadius,
      backgroundColor: bg,
      backgroundOpacity: bgOpacity,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: widget.borderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.isEnabled ? widget.onPressed : null,
          onTapDown: widget.isEnabled
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: widget.isEnabled
              ? (_) => setState(() => _isPressed = false)
              : null,
          onTapCancel: widget.isEnabled
              ? () => setState(() => _isPressed = false)
              : null,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: widget.padding,
            child: Center(
              widthFactor: widget.expand ? null : 1,
              child: child,
            ),
          ),
        ),
      ),
    );

    final sized = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: widget.minHeight,
        minWidth: widget.minWidth ?? 0,
        maxHeight: widget.maxHeight ?? double.infinity,
        maxWidth: widget.maxWidth ?? double.infinity,
      ),
      child: button,
    );

    if (!widget.expand) return sized;
    return SizedBox(width: double.infinity, child: sized);
  }
}
