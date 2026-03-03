import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/buttons/button.dart' as stage_button;
import 'package:mago_widgets/src/widgets/buttons/button_style.dart'
    as stage_button_style;

enum MagoIconButtonShape {
  circle,
  roundedSquare,
}

class MagoIconButton extends stage_button.MagoButton {
  const MagoIconButton({
    super.key,
    required this.icon,
    required super.onPressed,
    super.enabled = true,
    super.variant = stage_button_style.MagoButtonVariant.filled,
    super.backgroundColor,
    super.foregroundColor,
    super.borderColor,
    super.borderWidth,
    super.minHeight = 44,
    super.minWidth = 44,
    super.maxHeight = 44,
    super.maxWidth = 44,
    double iconSize = 20,
    EdgeInsets padding = const EdgeInsets.all(10),
    MagoIconButtonShape shape = MagoIconButtonShape.circle,
    BorderRadius? borderRadius,
  })  : _iconSize = iconSize,
        super(
          padding: padding,
          borderRadius: borderRadius ??
              (shape == MagoIconButtonShape.circle
                  ? const BorderRadius.all(Radius.circular(999))
                  : const BorderRadius.all(Radius.circular(10))),
        );

  final IconData icon;
  final double _iconSize;

  @override
  Widget buildContent(BuildContext context) {
    return Icon(icon, size: _iconSize);
  }
}
