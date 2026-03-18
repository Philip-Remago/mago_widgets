import 'package:flutter/material.dart';

import '../../helpers/constants.dart';
import '../components/glass_container.dart';

class MagoEmailChipInput extends StatefulWidget {
  final List<String> initialEmails;

  final ValueChanged<List<String>>? onChanged;

  final String? placeholder;

  final Color? fillColor;
  final BorderRadius borderRadius;

  final double? height;
  final double? width;

  final Color? chipColor;
  final Color? chipTextColor;
  final Color? chipDeleteColor;

  final bool autofocus;
  final bool commitOnFocusLost;
  final FocusNode? focusNode;

  final TextAlign textAlign;
  final TextCapitalization textCapitalization;

  const MagoEmailChipInput({
    super.key,
    this.initialEmails = const [],
    this.onChanged,
    this.placeholder,
    this.fillColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.height,
    this.width,
    this.chipColor,
    this.chipTextColor,
    this.chipDeleteColor,
    this.autofocus = false,
    this.commitOnFocusLost = true,
    this.focusNode,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<MagoEmailChipInput> createState() => _MagoEmailChipInputState();
}

class _MagoEmailChipInputState extends State<MagoEmailChipInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  late List<String> _emails;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _emails = [...widget.initialEmails];

    _focusNode.addListener(() {
      if (widget.commitOnFocusLost && !_focusNode.hasFocus) {
        _commitCurrent();
      }
    });
  }

  @override
  void dispose() {
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged?.call(List.unmodifiable(_emails));

  bool _isValidEmail(String s) {
    final v = s.trim();
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(v);
  }

  void _addEmail(String email) {
    final normalized = email.trim();

    if (normalized.isEmpty) return;
    if (!_isValidEmail(normalized)) return;

    final lower = normalized.toLowerCase();
    final exists = _emails.any((e) => e.toLowerCase() == lower);
    if (exists) return;

    setState(() {
      _emails.add(normalized);
    });
    _notify();
  }

  void _removeEmail(String email) {
    setState(() {
      _emails.removeWhere((e) => e.toLowerCase() == email.toLowerCase());
    });
    _notify();
  }

  void _commitCurrent() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    final parts =
        raw.split(RegExp(r'[\s,;]+')).where((p) => p.trim().isNotEmpty);
    for (final p in parts) {
      _addEmail(p);
    }

    _controller.clear();
    if (mounted) _focusNode.requestFocus();
  }

  void _handleChanged(String value) {
    if (value.contains(' ') ||
        value.contains(',') ||
        value.contains(';') ||
        value.contains('\n')) {
      _commitCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fillColor =
        widget.fillColor ?? theme.colorScheme.surfaceContainerHighest;

    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
    );

    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(127),
    );

    final resolvedChipColor = widget.chipColor?.withAlpha(127) ??
        theme.colorScheme.surface.withAlpha(127);
    final resolvedChipTextColor =
        widget.chipTextColor ?? theme.colorScheme.onSurface;
    final resolvedChipDeleteColor =
        widget.chipDeleteColor ?? theme.colorScheme.onSurface.withAlpha(178);

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: GlassContainer(
        height: widget.height,
        width: widget.width ?? double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        borderRadius: widget.borderRadius,
        glassProperties: GlassProperties(backgroundColor: fillColor),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final email in _emails)
              InputChip(
                label: Text(
                  email,
                  style: textStyle?.copyWith(color: resolvedChipTextColor),
                ),
                onDeleted: () => _removeEmail(email),
                deleteIconColor: resolvedChipDeleteColor,
                backgroundColor: resolvedChipColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            IntrinsicWidth(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                textAlign: widget.textAlign,
                textCapitalization: widget.textCapitalization,
                style: textStyle,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  hintText: (_emails.isEmpty) ? widget.placeholder : null,
                  hintStyle: hintStyle,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onChanged: _handleChanged,
                onSubmitted: (_) => _commitCurrent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
