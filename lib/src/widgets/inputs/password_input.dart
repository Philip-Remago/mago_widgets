import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/constants.dart';
import '../components/glass_container.dart';
import 'text_input.dart';

class MagoPasswordInput extends MagoTextInput {
  final bool initiallyObscured;

  const MagoPasswordInput({
    super.key,
    required super.controller,
    super.placeholder,
    super.autofocus = true,
    super.textInputAction = TextInputAction.done,
    super.fillColor,
    super.borderRadius = const BorderRadius.all(Radius.circular(4)),
    super.height,
    super.width,
    super.onSubmittedPop,
    super.textAlign,
    super.textCapitalization,
    this.initiallyObscured = true,
  }) : super(
          maxLines: 1,
          keyboardType: TextInputType.visiblePassword,
        );

  @override
  Widget build(BuildContext context) => _MagoPasswordInputBody(input: this);
}

class _MagoPasswordInputBody extends StatefulWidget {
  const _MagoPasswordInputBody({required this.input});

  final MagoPasswordInput input;

  @override
  State<_MagoPasswordInputBody> createState() => _MagoPasswordInputBodyState();
}

class _MagoPasswordInputBodyState extends State<_MagoPasswordInputBody> {
  late bool _obscure;
  late final FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _obscure = widget.input.initiallyObscured;
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.input.controller,
              focusNode: _focusNode,
              autofocus: widget.input.autofocus,
              maxLines: 1,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: widget.input.textInputAction,
              textAlign: widget.input.textAlign,
              textCapitalization: widget.input.textCapitalization,
              style: textStyle,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
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
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _obscure = !_obscure),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: theme.colorScheme.onSurface.withAlpha(178),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
