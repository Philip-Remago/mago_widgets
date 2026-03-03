import 'dart:math' as math;
import 'package:flutter/material.dart';

class MagoDragObject extends StatefulWidget {
  final double width;

  final double? height;

  final double? dragWidth;

  final double? dragHeight;

  final double aspectRatio;

  final bool fillCell;

  final Size? bounds;

  final Offset boundsOffset;

  final Widget? child;

  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;

  final Offset position;
  final ValueChanged<Offset>? onPositionChanged;

  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  final bool animate;

  final bool enabled;

  final bool lockDragOnSelected;

  final bool selectAfterDrag;

  final Size? containerSize;

  final Offset expandContainerOffset;

  final ValueChanged<bool>? onExpandedChanged;

  final VoidCallback? onExpandAnimationUpdate;

  final Widget Function(MagoDragObjectState state)? actionsBuilder;

  const MagoDragObject({
    super.key,
    required this.width,
    this.height,
    this.dragWidth,
    this.dragHeight,
    this.aspectRatio = 16 / 9,
    this.fillCell = true,
    this.bounds,
    this.boundsOffset = Offset.zero,
    this.child,
    this.isSelected = false,
    this.onSelectedChanged,
    this.position = Offset.zero,
    this.onPositionChanged,
    this.onDragStart,
    this.onDragEnd,
    this.animate = false,
    this.enabled = true,
    this.lockDragOnSelected = false,
    this.selectAfterDrag = false,
    this.containerSize,
    this.expandContainerOffset = Offset.zero,
    this.onExpandedChanged,
    this.onExpandAnimationUpdate,
    this.actionsBuilder,
  });

  @override
  State<MagoDragObject> createState() => MagoDragObjectState();
}

class MagoDragObjectState extends State<MagoDragObject>
    with SingleTickerProviderStateMixin {
  static const int _animationDurationMs = 300;
  static const double _selectionBorderWidth = 2.0;
  static const Curve _animationCurve = Curves.easeInOut;

  Offset? _dragStartPosition;
  bool _isDragging = false;
  bool _wasJustDragging = false;

  Offset? _tapLocalPosition;

  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  bool get isExpanded => _isExpanded;

  bool get isAnimating => _expandController.isAnimating;

  double get expandProgress => _expandAnimation.value;

  Rect getCurrentRect() {
    final normalSize = _normalSize;
    final (expandedPos, expandedSize) = _calculateExpandedRect();
    final t = _expandAnimation.value;

    final currentX =
        widget.position.dx + (expandedPos.dx - widget.position.dx) * t;
    final currentY =
        widget.position.dy + (expandedPos.dy - widget.position.dy) * t;
    final currentWidth =
        normalSize.width + (expandedSize.width - normalSize.width) * t;
    final currentHeight =
        normalSize.height + (expandedSize.height - normalSize.height) * t;

    return Rect.fromLTWH(currentX, currentY, currentWidth, currentHeight);
  }

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: _animationDurationMs),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: _animationCurve,
    );
    _expandController.addListener(_onExpandAnimationTick);
  }

  void _onExpandAnimationTick() {
    widget.onExpandAnimationUpdate?.call();
  }

  @override
  void dispose() {
    _expandController.removeListener(_onExpandAnimationTick);
    _expandController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MagoDragObject oldWidget) {
    super.didUpdateWidget(oldWidget);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureInBounds();
    });
  }

  void _setSelected(bool value) {
    widget.onSelectedChanged?.call(value);
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _tapLocalPosition = details.localPosition);
  }

  void _onTapObject() {
    if (_isDragging) return;
    if (!widget.isSelected) {
      _setSelected(true);
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled || _isExpanded) return;
    if (widget.lockDragOnSelected && widget.isSelected) return;

    widget.onDragStart?.call();
    if (!widget.isSelected) _setSelected(true);

    setState(() {
      _isDragging = true;

      final normalSize = _normalSize;
      final dragSize = _dragSize;
      final sizeDiff = Size(
        normalSize.width - dragSize.width,
        normalSize.height - dragSize.height,
      );

      Offset adjustedPos = widget.position;
      if (sizeDiff.width > 0 || sizeDiff.height > 0) {
        final cursorInWidget = details.localPosition;
        adjustedPos = Offset(
          widget.position.dx + cursorInWidget.dx - dragSize.width / 2,
          widget.position.dy + cursorInWidget.dy - dragSize.height / 2,
        );
        adjustedPos = _clampPos(adjustedPos, dragSize);
        widget.onPositionChanged?.call(adjustedPos);
      }

      _dragStartPosition = adjustedPos;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _dragStartPosition == null) return;

    _dragStartPosition = _dragStartPosition! + details.delta;
    final clamped = _clampPos(_dragStartPosition!, _dragSize);
    widget.onPositionChanged?.call(clamped);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _wasJustDragging = true;
      _dragStartPosition = null;
    });

    Future.delayed(const Duration(milliseconds: _animationDurationMs), () {
      if (mounted) {
        setState(() => _wasJustDragging = false);
      }
    });

    widget.onDragEnd?.call();
    if (!widget.selectAfterDrag) _setSelected(false);
  }

  Size get _normalSize {
    final h = widget.height ?? (widget.width / widget.aspectRatio);
    return Size(widget.width, h);
  }

  Size get _dragSize {
    final w = widget.dragWidth ?? widget.width;
    final h = widget.dragHeight ?? widget.height ?? (w / widget.aspectRatio);
    return Size(w, h);
  }

  (Offset, Size) _calculateExpandedRect() {
    final container = widget.containerSize;
    if (container == null) return (widget.position, _normalSize);

    final offset = widget.expandContainerOffset;
    return (
      Offset(offset.dx, offset.dy),
      Size(container.width, container.height),
    );
  }

  void toggleExpand() {
    if (widget.containerSize == null) return;

    setState(() => _isExpanded = !_isExpanded);

    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }

    widget.onExpandedChanged?.call(_isExpanded);
  }

  void collapse() {
    if (_isExpanded) toggleExpand();
  }

  Offset _clampPos(Offset position, Size itemSize) {
    final bounds = widget.bounds;
    if (bounds == null) return position;

    final offset = widget.boundsOffset;
    final minX = offset.dx;
    final minY = offset.dy;
    final maxX = offset.dx + bounds.width - itemSize.width;
    final maxY = offset.dy + bounds.height - itemSize.height;

    final clampedX = position.dx.clamp(minX, math.max(minX, maxX)).toDouble();
    final clampedY = position.dy.clamp(minY, math.max(minY, maxY)).toDouble();
    return Offset(clampedX, clampedY);
  }

  void _ensureInBounds() {
    if (widget.bounds == null || _isExpanded) return;

    final clamped = _clampPos(widget.position, _normalSize);
    if (clamped != widget.position) {
      widget.onPositionChanged?.call(clamped);
    }
  }

  bool _shouldShowOutline() {
    return (widget.isSelected || _isDragging) && !_isExpanded;
  }

  static const double _tapOffsetY = 10.0;
  static const double _expandedBottomInset = 50.0;

  Widget _buildActionBar({
    required double t,
    required Offset objectPos,
    required Size objectNormalSize,
    required Offset expandedPos,
    required Size expandedSize,
    required double currentX,
    required double currentY,
  }) {
    final actions = widget.actionsBuilder!(this);

    final tap = _tapLocalPosition ??
        Offset(objectNormalSize.width / 2, objectNormalSize.height / 2);

    final screenXCollapsed = objectPos.dx + tap.dx;
    final screenYCollapsed = objectPos.dy + tap.dy + _tapOffsetY;

    final screenXExpanded = expandedPos.dx + expandedSize.width / 2;
    final screenYExpanded =
        expandedPos.dy + expandedSize.height - _expandedBottomInset;

    final screenX = screenXCollapsed + (screenXExpanded - screenXCollapsed) * t;
    final screenY = screenYCollapsed + (screenYExpanded - screenYCollapsed) * t;

    final localX = screenX - currentX;
    final localY = screenY - currentY;

    return Positioned(
      top: localY,
      left: localX,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalSize = _normalSize;
    final dragSize = _dragSize;
    final (expandedPos, expandedSize) = _calculateExpandedRect();

    final shouldAnimatePosition = !_isDragging &&
        !_expandController.isAnimating &&
        (widget.animate || _wasJustDragging);
    final animDuration = shouldAnimatePosition
        ? const Duration(milliseconds: _animationDurationMs)
        : Duration.zero;

    final baseSize = _isDragging ? dragSize : normalSize;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final t = _expandAnimation.value;

        final baseX = widget.position.dx;
        final baseY = widget.position.dy;
        final currentX = baseX + (expandedPos.dx - baseX) * t;
        final currentY = baseY + (expandedPos.dy - baseY) * t;
        final currentWidth =
            baseSize.width + (expandedSize.width - baseSize.width) * t;
        final currentHeight =
            baseSize.height + (expandedSize.height - baseSize.height) * t;

        return AnimatedPositioned(
          duration: animDuration,
          curve: _animationCurve,
          left: currentX,
          top: currentY,
          width: currentWidth,
          height: currentHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            onTap: _onTapObject,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.transparent,
                  const Color(0xFF191919),
                  t,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: IgnorePointer(
                        ignoring: !widget.isSelected && !_isExpanded,
                        child: child,
                      ),
                    ),
                  ),
                  if (_shouldShowOutline())
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue,
                              width: _selectionBorderWidth,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.isSelected &&
                      !_isDragging &&
                      widget.actionsBuilder != null)
                    _buildActionBar(
                      t: t,
                      objectPos: widget.position,
                      objectNormalSize: normalSize,
                      expandedPos: expandedPos,
                      expandedSize: expandedSize,
                      currentX: currentX,
                      currentY: currentY,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: widget.child ?? const SizedBox.shrink(),
    );
  }
}
