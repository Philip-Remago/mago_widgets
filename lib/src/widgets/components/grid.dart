import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/draggables/drag_object.dart';
import 'package:mago_widgets/src/widgets/draggables/drag_surface.dart';
import 'package:mago_widgets/src/widgets/painters/grid_space_painter.dart';

class GridItem {
  GridItem({
    required this.id,
    required this.data,
    this.x = -1,
    this.y = -1,
    this.xSpan = 1,
    this.ySpan = 1,
  });

  final String id;
  final String data;

  int x;

  int y;

  int xSpan;

  int ySpan;

  bool get isPlaced => x >= 0 && y >= 0;
}

typedef GridChildBuilder = Widget Function(BuildContext context, GridItem item);
typedef GridExternalDropCallback = void Function(String data, int x, int y);
typedef GridItemMovedCallback = void Function(
  GridItem item,
  int oldX,
  int oldY,
  int newX,
  int newY,
);

typedef GridItemActionCallback = void Function(GridItem item);

typedef GridSelectionChangedCallback = void Function(
  GridItem? selectedItem,
  Rect? itemRect,
);

typedef GridDragStateCallback = void Function(bool isDragging);

typedef GridExpandAnimationCallback = void Function(String itemId);

typedef GridItemFillCellCallback = bool Function(GridItem item);

class Grid extends StatefulWidget {
  final List<GridItem> items;
  final int rows;
  final int cols;
  final GridChildBuilder childBuilder;
  final GridExternalDropCallback? onExternalDrop;

  final GridItemMovedCallback? onItemMoved;

  final GridItemActionCallback? onDeleteItem;

  final GridSelectionChangedCallback? onSelectionChanged;

  final GridDragStateCallback? onDragStateChanged;

  final GridExpandAnimationCallback? onExpandAnimationUpdate;

  final List<GridCellRect>? customCells;

  final GridItemFillCellCallback? shouldFillCell;

  final Size? expandContainerSize;

  final Offset? expandContainerOffset;

  final bool showFloatingControls;

  final FloatingControlsBuilder<GridItem>? floatingControlsBuilder;

  const Grid({
    super.key,
    required this.items,
    required this.rows,
    required this.cols,
    required this.childBuilder,
    this.onExternalDrop,
    this.onItemMoved,
    this.onDeleteItem,
    this.onSelectionChanged,
    this.onDragStateChanged,
    this.onExpandAnimationUpdate,
    this.customCells,
    this.shouldFillCell,
    this.expandContainerSize,
    this.expandContainerOffset,
    this.showFloatingControls = true,
    this.floatingControlsBuilder,
  });

  @override
  State<Grid> createState() => GridState();
}

class GridState extends State<Grid> {
  static const double _cellGap = 8.0;

  final Map<String, Offset> _dragPositions = {};

  final Set<String> _animatingItems = {};

  String? _selectedItemId;

  double _lastGridWidth = 0;
  double _lastGridHeight = 0;

  (int, int)? _hoverCell;

  String? _draggingItemId;

  final Map<String, GlobalKey<MagoDragObjectState>> _itemKeys = {};

  final GlobalKey<MagoDragSurfaceState<GridItem>> _dragSurfaceKey =
      GlobalKey<MagoDragSurfaceState<GridItem>>();

  final Map<String, Widget> _childCache = {};

  GlobalKey<MagoDragObjectState> _getKey(String id) {
    return _itemKeys.putIfAbsent(id, () => GlobalKey<MagoDragObjectState>());
  }

  void toggleExpandItem(String itemId) {
    _itemKeys[itemId]?.currentState?.toggleExpand();
  }

  bool isItemExpanded(String itemId) {
    return _itemKeys[itemId]?.currentState?.isExpanded ?? false;
  }

  bool isItemAnimating(String itemId) {
    return _itemKeys[itemId]?.currentState?.isAnimating ?? false;
  }

  Rect? getItemCurrentRect(String itemId) {
    return _itemKeys[itemId]?.currentState?.getCurrentRect();
  }

  double getItemExpandProgress(String itemId) {
    return _itemKeys[itemId]?.currentState?.expandProgress ?? 0.0;
  }

  void clearSelection() {
    _selectedItemId = null;
    _dragSurfaceKey.currentState?.clearSelection();
  }

  double _cellWidth(double gridWidth) => gridWidth / widget.cols;
  double _cellHeight(double gridHeight) => gridHeight / widget.rows;

  double _itemWidth(double gridWidth, [int xSpan = 1]) =>
      _cellWidth(gridWidth) * xSpan - _cellGap;
  double _itemHeight(double gridHeight, [int ySpan = 1]) =>
      _cellHeight(gridHeight) * ySpan - _cellGap;

  (double, double)? _smallestCellSize(double gridWidth, double gridHeight) {
    if (widget.customCells == null || widget.customCells!.isEmpty) return null;

    int minXSpan = widget.customCells!.first.xSpan;
    int minYSpan = widget.customCells!.first.ySpan;

    for (final cell in widget.customCells!) {
      if (cell.xSpan < minXSpan) minXSpan = cell.xSpan;
      if (cell.ySpan < minYSpan) minYSpan = cell.ySpan;
    }

    final allSame = widget.customCells!.every(
      (c) => c.xSpan == minXSpan && c.ySpan == minYSpan,
    );
    if (allSame) return null;

    return (
      _itemWidth(gridWidth, minXSpan),
      _itemHeight(gridHeight, minYSpan),
    );
  }

  Offset _cellToPosition(int x, int y, double gridWidth, double gridHeight) {
    final cellW = _cellWidth(gridWidth);
    final cellH = _cellHeight(gridHeight);
    final px = x * cellW + _cellGap / 2.0;
    final py = y * cellH + _cellGap / 2.0;
    return Offset(px, py);
  }

  (int, int) _positionToCell(
    Offset pos,
    double gridWidth,
    double gridHeight, [
    int xSpan = 1,
    int ySpan = 1,
  ]) {
    final cellW = _cellWidth(gridWidth);
    final cellH = _cellHeight(gridHeight);
    final itemW = _itemWidth(gridWidth, xSpan);
    final itemH = _itemHeight(gridHeight, ySpan);

    final centerX = pos.dx + itemW / 2.0;
    final centerY = pos.dy + itemH / 2.0;

    final gx = (centerX / cellW).floor().clamp(0, widget.cols - 1);
    final gy = (centerY / cellH).floor().clamp(0, widget.rows - 1);
    return (gx, gy);
  }

  (int, int)? _snapToCustomCell(int x, int y) {
    if (widget.customCells == null || widget.customCells!.isEmpty) {
      return (x, y);
    }

    for (final cell in widget.customCells!) {
      final yInRange = y >= cell.y && y < cell.y + cell.ySpan;
      final xInRange = x >= cell.x && x < cell.x + cell.xSpan;
      if (yInRange && xInRange) return (cell.x, cell.y);
    }
    return null;
  }

  GridItem? _findItemAt(int x, int y, {String? exceptId}) {
    final target = _snapToCustomCell(x, y);
    if (target == null) return null;

    final (tx, ty) = target;
    for (final item in widget.items) {
      if (exceptId != null && item.id == exceptId) continue;
      if (item.x == tx && item.y == ty) return item;
    }
    return null;
  }

  (int, int)? _firstEmptyCell() {
    if (widget.customCells != null && widget.customCells!.isNotEmpty) {
      for (final cell in widget.customCells!) {
        if (_findItemAt(cell.x, cell.y) == null) return (cell.x, cell.y);
      }
      return null;
    }

    for (int gy = 0; gy < widget.rows; gy++) {
      for (int gx = 0; gx < widget.cols; gx++) {
        if (_findItemAt(gx, gy) == null) return (gx, gy);
      }
    }
    return null;
  }

  void _placeUnplacedItems() {
    for (final item in widget.items) {
      if (!item.isPlaced) {
        final cell = _firstEmptyCell();
        if (cell != null) {
          item.x = cell.$1;
          item.y = cell.$2;
        }
      }
    }
  }

  void _clampItemsToGrid() {
    final Set<String> occupied = {};

    for (final item in widget.items) {
      if (item.isPlaced) {
        int tx = item.x.clamp(0, widget.cols - 1);
        int ty = item.y.clamp(0, widget.rows - 1);
        var key = '$tx:$ty';

        if (occupied.contains(key)) {
          bool placed = false;
          for (int gy = 0; gy < widget.rows && !placed; gy++) {
            for (int gx = 0; gx < widget.cols && !placed; gx++) {
              final k = '$gx:$gy';
              if (!occupied.contains(k)) {
                tx = gx;
                ty = gy;
                key = k;
                placed = true;
              }
            }
          }
        }

        item.x = tx;
        item.y = ty;
        occupied.add(key);
      }
    }
  }

  Rect _getItemRect(String id) {
    final item = widget.items.firstWhere(
      (it) => it.id == id,
      orElse: () => GridItem(id: '', data: ''),
    );

    if (!item.isPlaced || _lastGridWidth == 0) return Rect.zero;

    final dragPos = _dragPositions[item.id];
    final pos = dragPos ??
        _cellToPosition(item.x, item.y, _lastGridWidth, _lastGridHeight);

    final w = _itemWidth(_lastGridWidth, item.xSpan);
    final h = _itemHeight(_lastGridHeight, item.ySpan);

    return Rect.fromLTWH(pos.dx, pos.dy, w, h);
  }

  void _handleSelectionChanged(String? itemId) {
    if (_selectedItemId == itemId) return;
    _selectedItemId = itemId;

    if (widget.onSelectionChanged != null) {
      if (itemId == null) {
        widget.onSelectionChanged!(null, null);
      } else {
        final item = widget.items.firstWhere(
          (it) => it.id == itemId,
          orElse: () => GridItem(id: '', data: ''),
        );
        if (item.id.isNotEmpty) {
          widget.onSelectionChanged!(item, _getItemRect(itemId));
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant Grid oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.rows != widget.rows || oldWidget.cols != widget.cols) {
      _clampItemsToGrid();
    }

    if (widget.items.any((it) => !it.isPlaced)) {
      _placeUnplacedItems();
    }

    final oldData = {for (var it in oldWidget.items) it.id: it.data};
    for (final item in widget.items) {
      if (oldData[item.id] != item.data) _childCache.remove(item.id);
    }

    final currentIds = widget.items.map((it) => it.id).toSet();
    _childCache.removeWhere((id, _) => !currentIds.contains(id));
    _itemKeys.removeWhere((id, _) => !currentIds.contains(id));
  }

  void _onDragEnd(GridItem item, double gridWidth, double gridHeight) {
    final dragPos = _dragPositions[item.id];
    if (dragPos == null) return;

    final useXSpan = widget.customCells != null ? 1 : item.xSpan;
    final useYSpan = widget.customCells != null ? 1 : item.ySpan;
    final (rawX, rawY) =
        _positionToCell(dragPos, gridWidth, gridHeight, useXSpan, useYSpan);

    final snapped = _snapToCustomCell(rawX, rawY);
    if (snapped == null) {
      setState(() {
        _dragPositions.remove(item.id);
        _hoverCell = null;
        _draggingItemId = null;
      });
      return;
    }

    final (targetX, targetY) = snapped;
    final occupant = _findItemAt(targetX, targetY, exceptId: item.id);

    final oldX = item.x;
    final oldY = item.y;

    setState(() {
      if (occupant != null) {
        final prevYSpan = item.ySpan;
        final prevXSpan = item.xSpan;

        item.x = targetX;
        item.y = targetY;
        item.xSpan = occupant.xSpan;
        item.ySpan = occupant.ySpan;

        occupant.x = oldX;
        occupant.y = oldY;
        occupant.xSpan = prevXSpan;
        occupant.ySpan = prevYSpan;

        _animatingItems.add(occupant.id);
      } else {
        item.x = targetX;
        item.y = targetY;

        if (widget.customCells != null) {
          for (final cell in widget.customCells!) {
            if (cell.x == targetX && cell.y == targetY) {
              item.xSpan = cell.xSpan;
              item.ySpan = cell.ySpan;
              break;
            }
          }
        }
      }

      _dragPositions.remove(item.id);
      _hoverCell = null;
      _draggingItemId = null;
    });

    if (oldX != targetX || oldY != targetY) {
      widget.onItemMoved?.call(item, oldX, oldY, targetX, targetY);
      if (occupant != null) {
        widget.onItemMoved?.call(occupant, targetX, targetY, oldX, oldY);
      }
    }

    if (occupant != null) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _animatingItems.remove(occupant.id));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _placeUnplacedItems();

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth;
        final gridHeight = constraints.maxHeight;

        final sizeChanged =
            _lastGridWidth != gridWidth || _lastGridHeight != gridHeight;
        _lastGridWidth = gridWidth;
        _lastGridHeight = gridHeight;

        if (sizeChanged &&
            _selectedItemId != null &&
            widget.onSelectionChanged != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_selectedItemId != null) {
              final item = widget.items.firstWhere(
                (it) => it.id == _selectedItemId,
                orElse: () => GridItem(id: '', data: ''),
              );
              if (item.id.isNotEmpty) {
                widget.onSelectionChanged!(
                  item,
                  _getItemRect(_selectedItemId!),
                );
              }
            }
          });
        }

        return DragTarget<Object>(
          onWillAcceptWithDetails: (details) {
            if (details.data is String) return true;
            if (details.data is Map<String, dynamic>) {
              return (details.data as Map<String, dynamic>).containsKey('url');
            }
            return false;
          },
          onAcceptWithDetails: (details) {
            if (widget.onExternalDrop == null) return;

            String? url;
            if (details.data is String) {
              url = details.data as String;
            } else if (details.data is Map<String, dynamic>) {
              url = (details.data as Map<String, dynamic>)['url'] as String?;
            }
            if (url == null || url.isEmpty) return;

            final RenderBox? renderBox =
                context.findRenderObject() as RenderBox?;
            if (renderBox == null) return;

            final localPos = renderBox.globalToLocal(details.offset);
            const feedbackWidth = 130.0;
            const feedbackHeight = 120.0;
            final centerX = localPos.dx + feedbackWidth / 2;
            final centerY = localPos.dy + feedbackHeight / 2;

            final gx = (centerX / _cellWidth(gridWidth))
                .floor()
                .clamp(0, widget.cols - 1);
            final gy = (centerY / _cellHeight(gridHeight))
                .floor()
                .clamp(0, widget.rows - 1);

            widget.onExternalDrop!(url, gx, gy);
          },
          builder: (context, candidateData, rejectedData) {
            final occupiedCells = widget.items
                .where((item) => item.isPlaced && item.id != _draggingItemId)
                .map((item) => OccupiedCell(x: item.x, y: item.y))
                .toList();

            return Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  painter: MagoGridSpacePainter(
                    xSpacing: _cellWidth(gridWidth),
                    ySpacing: _cellHeight(gridHeight),
                    gap: 8,
                    cellBorderWidth: 0,
                    customCells: widget.customCells,
                    occupiedCells: occupiedCells,
                    hoverCell: _hoverCell,
                  ),
                  child: const SizedBox.expand(),
                ),
                MagoDragSurface<GridItem>(
                  key: _dragSurfaceKey,
                  items: widget.items,
                  idOf: (it) => it.id,
                  onSelectionCleared: () => _handleSelectionChanged(null),
                  getItemRect: widget.showFloatingControls
                      ? (id) => _getItemRect(id as String)
                      : null,
                  floatingControlsBuilder: widget.floatingControlsBuilder,
                  itemBuilder: (
                    context,
                    item,
                    isSelected,
                    onSelectedChanged,
                    bringToFront,
                    onDragStateChanged,
                  ) {
                    if (!item.isPlaced) return const SizedBox.shrink();

                    final cellPos = _cellToPosition(
                      item.x,
                      item.y,
                      gridWidth,
                      gridHeight,
                    );
                    final pos = _dragPositions[item.id] ?? cellPos;

                    final actualItemWidth = _itemWidth(gridWidth, item.xSpan);
                    final actualItemHeight =
                        _itemHeight(gridHeight, item.ySpan);

                    final smallestCell =
                        _smallestCellSize(gridWidth, gridHeight);

                    final dragBounds = Size(gridWidth * 3, gridHeight * 3);
                    final boundsOffset = Offset(-gridWidth, -gridHeight);

                    final cachedChild = _childCache.putIfAbsent(
                      item.id,
                      () => widget.childBuilder(context, item),
                    );

                    final fillCell = widget.shouldFillCell?.call(item) ?? false;

                    final effectiveContainerSize = widget.expandContainerSize ??
                        Size(gridWidth, gridHeight);
                    final effectiveContainerOffset =
                        widget.expandContainerOffset ?? Offset.zero;

                    return MagoDragObject(
                      key: _getKey(item.id),
                      width: actualItemWidth,
                      height: actualItemHeight,
                      dragWidth: smallestCell?.$1,
                      dragHeight: smallestCell?.$2,
                      fillCell: fillCell,
                      bounds: dragBounds,
                      boundsOffset: boundsOffset,
                      position: pos,
                      isSelected: isSelected,
                      containerSize: effectiveContainerSize,
                      expandContainerOffset: effectiveContainerOffset,
                      onSelectedChanged: (selected) {
                        onSelectedChanged(selected);
                        _handleSelectionChanged(selected ? item.id : null);
                      },
                      onExpandedChanged: (expanded) {
                        if (expanded) bringToFront();
                      },
                      onExpandAnimationUpdate: () {
                        widget.onExpandAnimationUpdate?.call(item.id);
                      },
                      onDragStart: () {
                        bringToFront();
                        onDragStateChanged(true);
                        widget.onDragStateChanged?.call(true);
                        setState(() => _draggingItemId = item.id);
                      },
                      onPositionChanged: (newPos) {
                        final useXSpan =
                            widget.customCells != null ? 1 : item.xSpan;
                        final useYSpan =
                            widget.customCells != null ? 1 : item.ySpan;
                        final (rawX, rawY) = _positionToCell(
                          newPos,
                          gridWidth,
                          gridHeight,
                          useXSpan,
                          useYSpan,
                        );
                        final snapped = _snapToCustomCell(rawX, rawY);
                        setState(() {
                          _dragPositions[item.id] = newPos;
                          _hoverCell = snapped;
                        });
                      },
                      onDragEnd: () {
                        onDragStateChanged(false);
                        widget.onDragStateChanged?.call(false);
                        _onDragEnd(item, gridWidth, gridHeight);
                      },
                      animate: _animatingItems.contains(item.id),
                      child: cachedChild,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
