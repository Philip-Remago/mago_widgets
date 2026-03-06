import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/buttons/button.dart' as stageButton;
import 'package:mago_widgets/src/widgets/buttons/button_style.dart'
    as stageButtonStyle;

class MagoTextButton extends stageButton.MagoButton {
  const MagoTextButton({
    super.key,
    required this.text,
    required super.onPressed,
    super.enabled = true,
    super.variant = stageButtonStyle.MagoButtonVariant.filled,
    super.padding,
    super.borderRadius,
    super.backgroundColor,
    super.foregroundColor,
    super.borderColor,
    super.borderWidth,
    super.minHeight,
    super.minWidth,
    super.maxHeight,
    super.maxWidth,
    super.expand = false,
    super.boxShadow,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final TextAlign textAlign;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget buildContent(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
