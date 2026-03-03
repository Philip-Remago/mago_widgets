import 'package:flutter/material.dart';

/// Callback for building a floating controls overlay for a selected item.
typedef FloatingControlsBuilder<T> = Widget Function(
  BuildContext context,
  T selectedItem,
  Rect itemRect,
  Size containerSize,
  VoidCallback clearSelection,
);

class MagoDragSurface<T> extends StatefulWidget {
  final List<T> items;
  final Object Function(T item) idOf;

  final Widget Function(
    BuildContext context,
    T item,
    bool isSelected,
    ValueChanged<bool> onSelectedChanged,
    VoidCallback bringToFront,
    ValueChanged<bool> onDragStateChanged,
  ) itemBuilder;

  final FloatingControlsBuilder<T>? floatingControlsBuilder;

  final Rect Function(Object id)? getItemRect;

  final VoidCallback? onSelectionCleared;

  const MagoDragSurface({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    this.floatingControlsBuilder,
    this.getItemRect,
    this.onSelectionCleared,
  });

  @override
  State<MagoDragSurface<T>> createState() => MagoDragSurfaceState<T>();
}

class MagoDragSurfaceState<T> extends State<MagoDragSurface<T>> {
  Object? _selectedId;
  bool _isDragging = false;
  late List<Object> _order;

  void clearSelection() {
    if (_selectedId != null) {
      setState(() => _selectedId = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _order = widget.items.map(widget.idOf).toList();
  }

  @override
  void didUpdateWidget(covariant MagoDragSurface<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newIds = widget.items.map(widget.idOf).toList();

    final kept = _order.where(newIds.contains).toList();

    final missing = <Object>[
      for (final id in newIds)
        if (!kept.contains(id)) id,
    ];

    _order = [...kept, ...missing];

    if (_selectedId != null && !newIds.contains(_selectedId)) {
      _selectedId = null;
    }
  }

  void _handleSelectedChanged(Object id, bool selected) {
    setState(() {
      _selectedId = selected ? id : null;
      if (selected) {
        _order.remove(id);
        _order.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedId = null);
    widget.onSelectionCleared?.call();
  }

  void _bringToFront(Object id) {
    if (_order.isNotEmpty && _order.last == id) return;

    setState(() {
      _order.remove(id);
      _order.add(id);
    });
  }

  void _handleDragStateChanged(bool isDragging) {
    setState(() {
      _isDragging = isDragging;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedId != null;

    final byId = <Object, T>{
      for (final item in widget.items) widget.idOf(item): item,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: hasSelection ? _clearSelection : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: SizedBox.expand()),
              for (final id in _order)
                if (byId.containsKey(id))
                  KeyedSubtree(
                    key: ValueKey(id),
                    child: widget.itemBuilder(
                      context,
                      byId[id] as T,
                      _selectedId == id,
                      (selected) => _handleSelectedChanged(id, selected),
                      () => _bringToFront(id),
                      _handleDragStateChanged,
                    ),
                  ),
              if (hasSelection &&
                  !_isDragging &&
                  widget.floatingControlsBuilder != null &&
                  widget.getItemRect != null &&
                  byId.containsKey(_selectedId))
                widget.floatingControlsBuilder!(
                  context,
                  byId[_selectedId] as T,
                  widget.getItemRect!(_selectedId!),
                  containerSize,
                  _clearSelection,
                ),
            ],
          ),
        );
      },
    );
  }
}
