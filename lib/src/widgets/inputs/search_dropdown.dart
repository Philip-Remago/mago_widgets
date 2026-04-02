import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/constants.dart';
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
  final bool rootOverlay;

  final ThemeData? dropdownTheme;

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
    this.rootOverlay = false,
    this.dropdownTheme,
  });

  @override
  State<MagoSearchDropdown<T>> createState() => _MagoSearchDropdownState<T>();
}

class _MagoSearchDropdownState<T> extends State<MagoSearchDropdown<T>>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final FocusNode _keyListenerFocusNode;
  late final AnimationController _animController;
  late final CurvedAnimation _curvedAnim;
  late final Animation<Offset> _slideAnim;
  final _tapRegionGroupId = Object();
  OverlayEntry? _overlayEntry;

  List<T> _filtered = [];
  bool _isOpen = false;
  int _highlightIndex = -1;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _keyListenerFocusNode = FocusNode(skipTraversal: true);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _curvedAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: Offset.zero,
    ).animate(_curvedAnim);
    _filtered = List.of(widget.items);
  }

  @override
  void didUpdateWidget(covariant MagoSearchDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _filtered = List.of(widget.items);
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _curvedAnim.dispose();
    _animController.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _keyListenerFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      _filtered = List.of(widget.items);
    } else {
      _filtered = widget.items
          .where((item) => widget.itemLabel(item).toLowerCase().contains(q))
          .toList();
    }
    _highlightIndex = _filtered.isNotEmpty ? 0 : -1;
    _overlayEntry?.markNeedsBuild();
  }

  void _selectItem(T item) {
    widget.onSelected?.call(item);
    _removeOverlay();
  }

  void _clearSelection() {
    widget.onCleared?.call();
    _removeOverlay();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    if (!_isOpen || _filtered.isEmpty) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _highlightIndex = (_highlightIndex + 1) % _filtered.length;
      _overlayEntry?.markNeedsBuild();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _highlightIndex =
          (_highlightIndex - 1 + _filtered.length) % _filtered.length;
      _overlayEntry?.markNeedsBuild();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_highlightIndex >= 0 && _highlightIndex < _filtered.length) {
        _selectItem(_filtered[_highlightIndex]);
      }
    } else if (key == LogicalKeyboardKey.escape) {
      _removeOverlay();
    }
  }

  void _toggle() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_isOpen) {
      _overlayEntry?.markNeedsBuild();
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final overlay = Overlay.of(context, rootOverlay: widget.rootOverlay);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final size = renderBox.size;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);

    _searchController.clear();
    _filtered = List.of(widget.items);
    _highlightIndex = _filtered.isNotEmpty ? 0 : -1;

    final capturedTheme = widget.dropdownTheme ?? Theme.of(context);

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final theme = capturedTheme;
        final hintStyle = theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withAlpha(128),
        );
        final inputStyle = theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        );

        return Positioned(
          left: topLeft.dx,
          top: topLeft.dy + size.height + 4,
          width: size.width,
          child: FadeTransition(
            opacity: _curvedAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Theme(
                data: theme,
                child: TapRegion(
                  groupId: _tapRegionGroupId,
                  onTapOutside: (_) => _removeOverlay(),
                  child: GlassContainer(
                    borderRadius: widget.borderRadius,
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      type: MaterialType.transparency,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: TextField(
                              controller: _searchController,
                              autofocus: false,
                              textAlign: widget.textAlign,
                              textCapitalization: widget.textCapitalization,
                              style: inputStyle,
                              autocorrect: false,
                              enableSuggestions: false,
                              smartDashesType: SmartDashesType.disabled,
                              smartQuotesType: SmartQuotesType.disabled,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                prefixIcon:
                                    const Icon(LucideIcons.search, size: 16),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: widget.borderRadius,
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(60),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: widget.borderRadius,
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(60),
                                  ),
                                ),
                                hintText: widget.placeholder ?? 'Search…',
                                hintStyle: hintStyle,
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                              onChanged: _applyFilter,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: widget.maxDropdownHeight,
                            ),
                            child: _filtered.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No results',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(128),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    shrinkWrap: true,
                                    itemCount: _filtered.length,
                                    itemBuilder: (_, i) {
                                      final item = _filtered[i];
                                      final highlighted = i == _highlightIndex;
                                      return _DropdownItem<T>(
                                        item: item,
                                        label: widget.itemLabel(item),
                                        subtitle:
                                            widget.itemSubtitle?.call(item),
                                        leading: widget.itemLeading?.call(item),
                                        highlighted: highlighted,
                                        onTap: () => _selectItem(item),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
    _animController.forward(from: 0);
    setState(() {
      _isOpen = true;
    });
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    if (entry == null) return;
    _overlayEntry = null;
    _isOpen = false;
    if (mounted) setState(() {});
    _animController.reverse().whenComplete(() {
      if (entry.mounted) entry.remove();
    });
  }

  String get _displayText {
    if (widget.value != null) {
      return widget.itemLabel(widget.value as T);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        widget.fillColor ?? theme.colorScheme.surfaceContainerHighest;

    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.0,
    );
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(128),
      height: 1.0,
    );

    final displayText = _displayText;
    final hasSelection = displayText.isNotEmpty;

    return TapRegion(
      groupId: _tapRegionGroupId,
      child: KeyboardListener(
        focusNode: _keyListenerFocusNode,
        onKeyEvent: _handleKey,
        child: GestureDetector(
          onTap: _toggle,
          child: GlassContainer(
            height: widget.height,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            borderRadius: widget.borderRadius,
            glassProperties: GlassProperties(backgroundColor: fillColor),
            child: Row(
              children: [
                Icon(
                  LucideIcons.search,
                  size: 16,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasSelection ? displayText : (widget.placeholder ?? ''),
                    style: hasSelection ? textStyle : hintStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.showClearButton && hasSelection)
                  GestureDetector(
                    onTap: _clearSelection,
                    child: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  )
                else
                  Icon(
                    _isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
              ],
            ),
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
