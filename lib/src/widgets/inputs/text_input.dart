import 'package:flutter/material.dart';

import '../../helpers/constants.dart';
import '../components/glass_container.dart';

class MagoTextInput extends StatelessWidget {
  final TextEditingController controller;

  final String? placeholder;

  final bool autofocus;
  final int maxLines;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  final Color? fillColor;
  final BorderRadius borderRadius;

  final double? height;
  final double? width;

  final VoidCallback? onSubmittedPop;

  final TextAlign textAlign;
  final TextCapitalization textCapitalization;

  const MagoTextInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.autofocus = true,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.fillColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.height,
    this.width,
    this.onSubmittedPop,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) => _MagoTextInputBody(input: this);
}

class _MagoTextInputBody extends StatefulWidget {
  const _MagoTextInputBody({required this.input});
  final MagoTextInput input;

  @override
  State<_MagoTextInputBody> createState() => _MagoTextInputBodyState();
}

class _MagoTextInputBodyState extends State<_MagoTextInputBody> {
  late final FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(BuildContext context) {
    final cb = widget.input.onSubmittedPop;
    if (cb != null) {
      cb.call();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        widget.input.fillColor ?? theme.colorScheme.surfaceContainerHighest;

    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );

    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(128),
    );

    return GlassContainer(
      height: widget.input.height,
      width: widget.input.width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      borderRadius: widget.input.borderRadius,
      glassProperties: GlassProperties(backgroundColor: fillColor),
      child: TextField(
        controller: widget.input.controller,
        focusNode: _focusNode,
        autofocus: widget.input.autofocus,
        maxLines: widget.input.maxLines,
        keyboardType: widget.input.keyboardType,
        textInputAction: widget.input.textInputAction,
        textAlign: widget.input.textAlign,
        textCapitalization: widget.input.textCapitalization,
        style: textStyle,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        expands: widget.input.height != null && widget.input.maxLines == 1
            ? false
            : false,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.transparent,
          hoverColor: Colors.transparent,
          hintText: widget.input.placeholder,
          hintStyle: hintStyle,
        ),
        onSubmitted: (_) => _handleSubmit(context),
      ),
    );
  }
}
