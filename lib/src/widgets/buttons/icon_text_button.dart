import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mago_widgets/src/widgets/buttons/button.dart' as stageButton;
import 'package:mago_widgets/src/widgets/buttons/button_style.dart'
    as stageButtonStyle;

enum MagoIconPlacement { start, end }

class MagoIconTextButton extends stageButton.MagoButton {
  const MagoIconTextButton({
    super.key,
    required this.icon,
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
    this.iconSize = 20,
    this.iconPlacement = MagoIconPlacement.start,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.spacing = 10,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final Object icon;
  final String text;

  final double iconSize;

  final MagoIconPlacement iconPlacement;

  final MainAxisAlignment mainAxisAlignment;

  final double spacing;

  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget buildContent(BuildContext context) {
    final Widget iconWidget;
    if (icon is String) {
      iconWidget = SvgPicture.asset(
        icon as String,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(
          IconTheme.of(context).color ?? Colors.white,
          BlendMode.srcIn,
        ),
      );
    } else {
      iconWidget = Icon(icon as IconData, size: iconSize);
    }

    final textWidget = Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
    );

    final useSpaceBetween = mainAxisAlignment == MainAxisAlignment.spaceBetween;

    final children = <Widget>[
      if (iconPlacement == MagoIconPlacement.start) ...[
        iconWidget,
        if (useSpaceBetween)
          Expanded(
              child: Align(alignment: Alignment.centerLeft, child: textWidget))
        else ...[
          SizedBox(width: spacing),
          Flexible(child: textWidget),
        ],
      ] else ...[
        if (useSpaceBetween)
          Expanded(
              child: Align(alignment: Alignment.centerLeft, child: textWidget))
        else
          Flexible(child: textWidget),
        if (!useSpaceBetween) SizedBox(width: spacing),
        iconWidget,
      ],
    ];

    final row = Row(
      mainAxisSize: useSpaceBetween ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          useSpaceBetween ? MainAxisAlignment.spaceBetween : mainAxisAlignment,
      children: children,
    );

    return useSpaceBetween ? SizedBox(width: double.infinity, child: row) : row;
  }
}
