import 'package:flutter/material.dart';

class MagoCode extends StatefulWidget {
  const MagoCode({
    super.key,
    required this.code,
    this.width = 48,
    this.heightRatio = 1.5,
    this.spacing = 8,
    this.borderRadius = 6,
    this.backgroundColor,
    this.textStyle,
  });

  final String code;
  final double width;
  final double heightRatio;
  final double spacing;
  final double borderRadius;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  @override
  State<MagoCode> createState() => _MagoCodeState();
}

class _MagoCodeState extends State<MagoCode> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letters = widget.code.split('');

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: widget.spacing,
      children: letters.map((letter) {
        return Container(
          width: widget.width,
          height: widget.width * widget.heightRatio,
          decoration: BoxDecoration(
            color: widget.backgroundColor ??
                theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Center(
            child: Text(
              letter,
              style: widget.textStyle ?? theme.textTheme.titleLarge,
            ),
          ),
        );
      }).toList(),
    );
  }
}
