import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mago_widgets/src/helpers/constants.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';
import 'package:mago_widgets/src/widgets/drawers/drawer_controller.dart';

enum MagoDrawerPlacement { top, bottom, left, right }

class MagoDrawer extends StatefulWidget {
  const MagoDrawer({
    super.key,
    this.controller,
    this.placement = MagoDrawerPlacement.bottom,
    required this.minExtent,
    required this.maxExtent,
    this.initialExtent = -1,
    this.backgroundColor,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.child,
    this.showHandle = true,
    this.handleThickness = 28,
    this.handleMainAxisSize = 48,
    this.snap = true,
    this.dragOnContent = false,
    this.closeOnContentSwipe = true,
    this.openOnlyWithHandleTap = false,
  })  : assert(minExtent >= 0 && minExtent <= 1),
        assert(maxExtent >= 0 && maxExtent <= 1),
        assert(maxExtent >= minExtent);

  final MagoDrawerController? controller;

  final MagoDrawerPlacement placement;

  final double minExtent;

  final double maxExtent;

  final double initialExtent;

  final Color? backgroundColor;

  final BorderRadius? borderRadius;

  final EdgeInsetsGeometry padding;

  final Widget? child;

  final bool showHandle;

  final double handleThickness;

  final double handleMainAxisSize;

  final bool snap;

  final bool dragOnContent;

  final bool closeOnContentSwipe;

  final bool openOnlyWithHandleTap;

  @override
  State<MagoDrawer> createState() => _MagoDrawerState();
}

class _MagoDrawerState extends State<MagoDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _minPx = 0;
  double _maxPx = 1;
  double _rangePx = 1;

  bool get _isVertical =>
      widget.placement == MagoDrawerPlacement.top ||
      widget.placement == MagoDrawerPlacement.bottom;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _normalizeExtent(double min, double max, double value) =>
      ((value - min) / (max - min)).clamp(0.0, 1.0);

  double _safeMax(double a, double b) => math.max(a, b + 1e-9);

  @override
  void initState() {
    super.initState();
    final minF = widget.minExtent;
    final maxF = _safeMax(widget.maxExtent, minF);
    final initialF = widget.initialExtent < 0
        ? minF
        : widget.initialExtent.clamp(minF, maxF);

    _controller = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: _normalizeExtent(minF, maxF, initialF),
    );

    _controller.addListener(_syncControllerValue);
    _attachExternalController();
  }

  @override
  void didUpdateWidget(covariant MagoDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onExternalControllerChanged);
      oldWidget.controller?.detach();
      _attachExternalController();
    }

    final oldMinF = oldWidget.minExtent;
    final oldMaxF = _safeMax(oldWidget.maxExtent, oldMinF);
    final newMinF = widget.minExtent;
    final newMaxF = _safeMax(widget.maxExtent, newMinF);

    if (oldMinF != newMinF || oldMaxF != newMaxF) {
      final currentF = _lerp(oldMinF, oldMaxF, _controller.value);
      _controller.value = _normalizeExtent(newMinF, newMaxF, currentF);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onExternalControllerChanged);
    widget.controller?.detach();
    _controller.removeListener(_syncControllerValue);
    _controller.dispose();
    super.dispose();
  }

  void _syncControllerValue() {
    widget.controller?.updateValue(_controller.value);
  }

  void _onExternalControllerChanged() {
    if (mounted) setState(() {});
  }

  void _attachExternalController() {
    widget.controller?.addListener(_onExternalControllerChanged);
    widget.controller?.attach(
      onOpen: () => _animateTo(1.0),
      onClose: () => _animateTo(0.0),
      onToggle: _toggle,
      onAnimateTo: _animateTo,
    );
    widget.controller?.updateValue(_controller.value);
  }

  Alignment get _alignment {
    return switch (widget.placement) {
      MagoDrawerPlacement.top => Alignment.topCenter,
      MagoDrawerPlacement.bottom => Alignment.bottomCenter,
      MagoDrawerPlacement.left => Alignment.centerLeft,
      MagoDrawerPlacement.right => Alignment.centerRight,
    };
  }

  Alignment get _clipAlignment {
    return switch (widget.placement) {
      MagoDrawerPlacement.top => Alignment.bottomCenter,
      MagoDrawerPlacement.bottom => Alignment.topCenter,
      MagoDrawerPlacement.left => Alignment.centerRight,
      MagoDrawerPlacement.right => Alignment.centerLeft,
    };
  }

  BorderRadius get _defaultBorderRadius {
    const r = Radius.circular(16);
    return switch (widget.placement) {
      MagoDrawerPlacement.top =>
        const BorderRadius.only(bottomLeft: r, bottomRight: r),
      MagoDrawerPlacement.bottom =>
        const BorderRadius.only(topLeft: r, topRight: r),
      MagoDrawerPlacement.left =>
        const BorderRadius.only(topRight: r, bottomRight: r),
      MagoDrawerPlacement.right =>
        const BorderRadius.only(topLeft: r, bottomLeft: r),
    };
  }

  double _outwardMultiplier(double primaryDelta) {
    return switch (widget.placement) {
      MagoDrawerPlacement.top || MagoDrawerPlacement.left => primaryDelta,
      MagoDrawerPlacement.bottom || MagoDrawerPlacement.right => -primaryDelta,
    };
  }

  void _toggle() {
    _animateTo(_controller.value >= 0.5 ? 0.0 : 1.0);
  }

  void _animateTo(double target) {
    _controller.animateTo(
      target.clamp(0.0, 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  double _deltaToControllerDelta(Offset delta) {
    final primaryDelta = _isVertical ? delta.dy : delta.dx;
    final outward = _outwardMultiplier(primaryDelta);
    return outward / _rangePx.clamp(1.0, double.infinity);
  }

  void _applyDragDelta(Offset delta, {bool closeOnly = false}) {
    final dc = _deltaToControllerDelta(delta);

    if ((widget.openOnlyWithHandleTap || closeOnly) && dc > 0) return;

    _controller.value = (_controller.value + dc).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details, {bool closeOnly = false}) {
    if (!widget.snap) return;

    final v = details.velocity.pixelsPerSecond;
    final primaryV = _isVertical ? v.dy : v.dx;
    final outwardV = _outwardMultiplier(primaryV);

    if ((widget.openOnlyWithHandleTap || closeOnly) && outwardV > 0) {
      _animateTo(_controller.value >= 0.5 ? 1.0 : 0.0);
      return;
    }

    const flingThreshold = 700.0;
    if (outwardV.abs() > flingThreshold) {
      _animateTo(outwardV > 0 ? 1.0 : 0.0);
      return;
    }

    _animateTo(_controller.value >= 0.5 ? 1.0 : 0.0);
  }

  Widget _buildHandle() {
    final theme = Theme.of(context);
    final grip = Center(
      child: Container(
        width: _isVertical ? widget.handleMainAxisSize : 6,
        height: _isVertical ? 6 : widget.handleMainAxisSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withAlpha(128),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

    final enableDrag = !widget.openOnlyWithHandleTap;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      onPanUpdate: enableDrag ? (d) => _applyDragDelta(d.delta) : null,
      onPanEnd: enableDrag ? (d) => _onDragEnd(d) : null,
      child: SizedBox(
        height: _isVertical ? widget.handleThickness : null,
        width: _isVertical ? null : widget.handleThickness,
        child: grip,
      ),
    );
  }

  Widget _wrapContentForGestures(Widget content) {
    final filled = SizedBox.expand(child: content);

    if (widget.dragOnContent) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _applyDragDelta(d.delta),
        onPanEnd: (d) => _onDragEnd(d),
        child: filled,
      );
    }

    if (widget.closeOnContentSwipe) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _applyDragDelta(d.delta, closeOnly: true),
        onPanEnd: (d) => _onDragEnd(d, closeOnly: true),
        child: filled,
      );
    }

    return filled;
  }

  Widget _buildBody(Widget contentArea) {
    final handle = widget.showHandle ? _buildHandle() : const SizedBox.shrink();
    final expandedContent = Expanded(child: contentArea);

    if (_isVertical) {
      final children = widget.placement == MagoDrawerPlacement.bottom
          ? [handle, expandedContent]
          : [expandedContent, handle];
      return Column(children: children);
    } else {
      final children = widget.placement == MagoDrawerPlacement.left
          ? [expandedContent, handle]
          : [handle, expandedContent];
      return Row(children: children);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBgColor =
        widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final radius = widget.borderRadius ?? _defaultBorderRadius;
    final screen = MediaQuery.sizeOf(context);

    final innerContent = widget.child ??
        Center(
          child: Text(
            'Drawer Widget',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        );

    final contentArea = _wrapContentForGestures(innerContent);
    final body = _buildBody(contentArea);

    return Align(
      alignment: _alignment,
      widthFactor: _isVertical ? null : 1.0,
      heightFactor: _isVertical ? 1.0 : null,
      child: Padding(
        padding: widget.padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableMain =
                _isVertical ? constraints.maxHeight : constraints.maxWidth;
            final mainSize = availableMain.isFinite
                ? availableMain
                : (_isVertical ? screen.height : screen.width);

            final handleSize = widget.showHandle ? widget.handleThickness : 0.0;
            final minPx = widget.minExtent <= 0
                ? 0.0
                : math.max(widget.minExtent * mainSize, handleSize);
            final maxPx = math.max(widget.maxExtent * mainSize, minPx + 1);

            _minPx = minPx;
            _maxPx = maxPx;
            _rangePx = (_maxPx - _minPx).clamp(1.0, double.infinity);

            final boundedMaxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : screen.width;
            final boundedMaxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : screen.height;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final extentPx = _lerp(_minPx, _maxPx, _controller.value)
                    .clamp(_minPx, _maxPx);
                final factor = _maxPx <= 0 ? 0.0 : (extentPx / _maxPx);

                final isHidden = widget.controller?.isHidden ?? false;
                if ((_minPx <= 0 || isHidden) && _controller.value < 0.001) {
                  return const SizedBox.shrink();
                }

                final panel = SizedBox(
                  width: _isVertical ? boundedMaxW : _maxPx,
                  height: _isVertical ? _maxPx : boundedMaxH,
                  child: GlassContainer(
                    borderRadius: radius,
                    glassProperties:
                        GlassProperties(backgroundColor: resolvedBgColor),
                    child: body,
                  ),
                );

                final revealed = Align(
                  alignment: _clipAlignment,
                  widthFactor: _isVertical ? null : factor,
                  heightFactor: _isVertical ? factor : null,
                  child: panel,
                );

                return ClipRRect(borderRadius: radius, child: revealed);
              },
            );
          },
        ),
      ),
    );
  }
}
