import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/glass_container.dart';

class MagoSearchDropdown<T> extends StatefulWidget {
  final List<T> items;

  final String Function(T item) itemLabel;

  final String Function(T item)? itemSubtitle;

  final Widget Function(T item)? itemLeading;

  final ValueChanged<T>? onSelected;

  final VoidCallback? onCleared;

  final T? value;

  final String? placeholder;

  final bool autofocus;

  final Color? fillColor;
  final BorderRadius borderRadius;

  final double? height;
  final double? width;

  final double maxDropdownHeight;

  final bool showClearButton;

  final TextAlign textAlign;
  final TextCapitalization textCapitalization;

  const MagoSearchDropdown({
    super.key,
    required this.items,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemLeading,
    this.onSelected,
    this.onCleared,
    this.value,
    this.placeholder,
    this.autofocus = false,
    this.fillColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.height,
    this.width,
    this.maxDropdownHeight = 260,
    this.showClearButton = true,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<MagoSearchDropdown<T>> createState() => _MagoSearchDropdownState<T>();
}

class _MagoSearchDropdownState<T> extends State<MagoSearchDropdown<T>> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<T> _filtered = [];
  bool _isOpen = false;
  int _highlightIndex = -1;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? widget.itemLabel(widget.value as T) : '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _filtered = List.of(widget.items);
  }

  @override
  void didUpdateWidget(covariant MagoSearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text =
          widget.value != null ? widget.itemLabel(widget.value as T) : '';
    }
    if (widget.items != oldWidget.items) {
      _applyFilter(_controller.text);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _applyFilter(_controller.text);
      _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_focusNode.hasFocus) {
          _controller.text =
              widget.value != null ? widget.itemLabel(widget.value as T) : '';
          _removeOverlay();
        }
      });
    }
  }

  void _applyFilter(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.of(widget.items);
      } else {
        _filtered = widget.items
            .where((item) => widget.itemLabel(item).toLowerCase().contains(q))
            .toList();
      }
      _highlightIndex = _filtered.isNotEmpty ? 0 : -1;
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _selectItem(T item) {
    _controller.text = widget.itemLabel(item);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    widget.onSelected?.call(item);
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _clearSelection() {
    _controller.clear();
    widget.onCleared?.call();
    _applyFilter('');
    _focusNode.requestFocus();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    if (!_isOpen || _filtered.isEmpty) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightIndex = (_highlightIndex + 1) % _filtered.length;
      });
      _overlayEntry?.markNeedsBuild();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightIndex =
            (_highlightIndex - 1 + _filtered.length) % _filtered.length;
      });
      _overlayEntry?.markNeedsBuild();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_highlightIndex >= 0 && _highlightIndex < _filtered.length) {
        _selectItem(_filtered[_highlightIndex]);
      }
    } else if (key == LogicalKeyboardKey.escape) {
      _removeOverlay();
      _focusNode.unfocus();
    }
  }

  void _showOverlay() {
    if (_isOpen) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              elevation: 4,
              borderRadius: widget.borderRadius,
              color: theme.colorScheme.surfaceContainer,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.maxDropdownHeight,
                ),
                child: _filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No results',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(128),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final item = _filtered[i];
                          final highlighted = i == _highlightIndex;
                          return _DropdownItem<T>(
                            item: item,
                            label: widget.itemLabel(item),
                            subtitle: widget.itemSubtitle?.call(item),
                            leading: widget.itemLeading?.call(item),
                            highlighted: highlighted,
                            onTap: () => _selectItem(item),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
    _isOpen = true;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
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
      color: theme.colorScheme.onSurface.withAlpha(128),
    );

    final hasSelection = _controller.text.isNotEmpty;

    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: _handleKey,
        child: GlassContainer(
          height: widget.height,
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          borderRadius: widget.borderRadius,
          backgroundColor: fillColor,
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
              const SizedBox(width: 8),
              Expanded(
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
                    hintText: widget.placeholder,
                    hintStyle: hintStyle,
                  ),
                  onChanged: _applyFilter,
                ),
              ),
              if (widget.showClearButton && hasSelection)
                GestureDetector(
                  onTap: _clearSelection,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                )
              else
                Icon(
                  Icons.arrow_drop_down,
                  size: 22,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownItem<T> extends StatelessWidget {
  final T item;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool highlighted;
  final VoidCallback onTap;

  const _DropdownItem({
    required this.item,
    required this.label,
    this.subtitle,
    this.leading,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: highlighted
            ? theme.colorScheme.primary.withAlpha(30)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
