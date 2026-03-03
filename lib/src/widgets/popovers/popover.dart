import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';

enum MagoPopoverPosition {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleCenter,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
  rightTop,
  rightBottom,
  leftTop,
  leftBottom,
}

enum _ArrowSide { top, bottom, left, right }

_ArrowSide _arrowSideFor(MagoPopoverPosition pos) {
  switch (pos) {
    case MagoPopoverPosition.topLeft:
    case MagoPopoverPosition.topCenter:
    case MagoPopoverPosition.topRight:
      return _ArrowSide.bottom;
    case MagoPopoverPosition.bottomLeft:
    case MagoPopoverPosition.bottomCenter:
    case MagoPopoverPosition.bottomRight:
      return _ArrowSide.top;
    case MagoPopoverPosition.middleLeft:
    case MagoPopoverPosition.leftTop:
    case MagoPopoverPosition.leftBottom:
      return _ArrowSide.right;
    case MagoPopoverPosition.middleRight:
    case MagoPopoverPosition.rightTop:
    case MagoPopoverPosition.rightBottom:
      return _ArrowSide.left;
    case MagoPopoverPosition.middleCenter:
      return _ArrowSide.top;
  }
}

class MagoPopoverHandle {
  final VoidCallback dismiss;
  final void Function(bool enabled) setBarrierEnabled;

  const MagoPopoverHandle({
    required this.dismiss,
    required this.setBarrierEnabled,
  });
}

class MagoPopoverAnchor extends StatefulWidget {
  const MagoPopoverAnchor({
    super.key,
    required this.child,
    required this.popoverBuilder,
    this.position = MagoPopoverPosition.bottomCenter,
    this.barrierDismissible = true,
    this.gap = 8,
    this.viewportPadding = const EdgeInsets.all(12),
    this.maxWidth,
    this.maxHeightFactor = 0.6,
    this.autoFlip = true,
    this.popoverPadding = const EdgeInsets.all(8),
    this.popoverBackgroundColor,
    this.popoverBorderRadius = const BorderRadius.all(Radius.circular(12)),
    this.elevation = 6,
    this.showArrow = true,
    this.arrowSize = 6,
    this.arrowBaseWidth = 22,
    this.onShown,
    this.onDismissed,
  });

  final Widget child;

  final Widget Function(MagoPopoverHandle handle) popoverBuilder;

  final MagoPopoverPosition position;
  final bool barrierDismissible;

  final double gap;

  final EdgeInsets viewportPadding;

  final double? maxWidth;

  final double maxHeightFactor;

  final bool autoFlip;

  final EdgeInsets popoverPadding;
  final Color? popoverBackgroundColor;
  final BorderRadius popoverBorderRadius;
  final double elevation;

  final bool showArrow;
  final double arrowSize;
  final double arrowBaseWidth;

  final VoidCallback? onShown;
  final VoidCallback? onDismissed;

  @override
  State<MagoPopoverAnchor> createState() => _MagoPopoverAnchorState();
}

class _MagoPopoverAnchorState extends State<MagoPopoverAnchor>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _entry;
  bool _barrierEnabled = true;

  MagoPopoverPosition? _resolvedPosition;
  Offset? _resolvedOffset;
  Size? _resolvedChildSize;

  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  static const _duration = Duration(milliseconds: 180);

  bool get _isShown => _entry != null;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: _duration);
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _removeImmediate();
    _animCtrl.dispose();
    super.dispose();
  }

  void _removeImmediate() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    _resolvedPosition = null;
    _resolvedOffset = null;
    _resolvedChildSize = null;
    entry.remove();
    widget.onDismissed?.call();
  }

  void _remove() {
    if (_entry == null) return;
    _animCtrl.reverse().then((_) {
      if (_entry != null) _removeImmediate();
    });
  }

  void _setBarrierEnabled(bool enabled) {
    if (_barrierEnabled == enabled) return;
    _barrierEnabled = enabled;
    _entry?.markNeedsBuild();
  }

  void toggle() {
    if (_isShown) {
      _remove();
    } else {
      _show();
    }
  }

  void _show() {
    if (_entry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    final handle = MagoPopoverHandle(
      dismiss: _remove,
      setBarrierEnabled: _setBarrierEnabled,
    );

    _entry = OverlayEntry(
      builder: (overlayContext) {
        return LayoutBuilder(
          builder: (overlayContext, constraints) {
            final overlayBox = overlayContext.findRenderObject() as RenderBox?;
            final targetBox = context.findRenderObject() as RenderBox?;

            if (overlayBox == null || targetBox == null || !targetBox.hasSize) {
              return const SizedBox.shrink();
            }

            final targetTopLeft =
                targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
            final targetRect = targetTopLeft & targetBox.size;

            final maxH = constraints.maxHeight * widget.maxHeightFactor;

            _ArrowSide? arrowSide;
            double arrowOffset = 0;
            if (widget.showArrow &&
                _resolvedOffset != null &&
                _resolvedChildSize != null) {
              final rPos = _resolvedPosition ?? widget.position;
              arrowSide = _arrowSideFor(rPos);
              final popoverRect = _resolvedOffset! & _resolvedChildSize!;

              final edgeMargin = widget.arrowBaseWidth / 2 + 4;
              switch (arrowSide) {
                case _ArrowSide.top:
                case _ArrowSide.bottom:
                  final ideal = targetRect.center.dx - popoverRect.left;
                  arrowOffset =
                      ideal.clamp(edgeMargin, popoverRect.width - edgeMargin);
                  break;
                case _ArrowSide.left:
                case _ArrowSide.right:
                  final ideal = targetRect.center.dy - popoverRect.top;
                  arrowOffset =
                      ideal.clamp(edgeMargin, popoverRect.height - edgeMargin);
                  break;
              }
            }

            final popover = Material(
              color: Colors.transparent,
              child: _PopoverGlass(
                borderRadius: widget.popoverBorderRadius,
                backgroundColor: widget.popoverBackgroundColor,
                padding: widget.popoverPadding,
                arrowSide: arrowSide,
                arrowOffset: arrowOffset,
                arrowSize: widget.arrowSize,
                arrowBaseWidth: widget.arrowBaseWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.maxWidth ?? constraints.maxWidth,
                    maxHeight: maxH,
                  ),
                  child: SingleChildScrollView(
                    child: widget.popoverBuilder(handle),
                  ),
                ),
              ),
            );

            Alignment scaleOrigin;
            if (arrowSide != null && _resolvedChildSize != null) {
              final w = _resolvedChildSize!.width;
              final h = _resolvedChildSize!.height;
              switch (arrowSide!) {
                case _ArrowSide.top:
                  scaleOrigin = Alignment(
                    w > 0 ? (arrowOffset / w) * 2 - 1 : 0,
                    -1,
                  );
                  break;
                case _ArrowSide.bottom:
                  scaleOrigin = Alignment(
                    w > 0 ? (arrowOffset / w) * 2 - 1 : 0,
                    1,
                  );
                  break;
                case _ArrowSide.left:
                  scaleOrigin = Alignment(
                    -1,
                    h > 0 ? (arrowOffset / h) * 2 - 1 : 0,
                  );
                  break;
                case _ArrowSide.right:
                  scaleOrigin = Alignment(
                    1,
                    h > 0 ? (arrowOffset / h) * 2 - 1 : 0,
                  );
                  break;
              }
            } else {
              scaleOrigin = Alignment.center;
            }

            final animatedPopover = FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                alignment: scaleOrigin,
                child: popover,
              ),
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: widget.barrierDismissible
                      ? IgnorePointer(
                          ignoring: !_barrierEnabled,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _remove,
                            child: const SizedBox.expand(),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
                CustomSingleChildLayout(
                  delegate: _MagoPopoverViewportDelegate(
                    targetRect: targetRect,
                    preferred: widget.position,
                    gap: widget.gap,
                    viewportPadding: widget.viewportPadding,
                    autoFlip: widget.autoFlip,
                    popoverPadding: widget.popoverPadding,
                    onLayout: (pos, offset, childSize) {
                      if (_resolvedPosition == pos &&
                          _resolvedOffset == offset &&
                          _resolvedChildSize == childSize) return;
                      _resolvedPosition = pos;
                      _resolvedOffset = offset;
                      _resolvedChildSize = childSize;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_entry != null && mounted) {
                          _entry!.markNeedsBuild();
                        }
                      });
                    },
                  ),
                  child: animatedPopover,
                ),
              ],
            );
          },
        );
      },
    );

    overlay.insert(_entry!);
    _animCtrl.forward(from: 0);
    widget.onShown?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggle,
      behavior: HitTestBehavior.opaque,
      child: AbsorbPointer(child: widget.child),
    );
  }
}

class _MagoPopoverViewportDelegate extends SingleChildLayoutDelegate {
  _MagoPopoverViewportDelegate({
    required this.targetRect,
    required this.preferred,
    required this.gap,
    required this.viewportPadding,
    required this.autoFlip,
    required this.popoverPadding,
    this.onLayout,
  });

  final Rect targetRect;
  final MagoPopoverPosition preferred;
  final double gap;
  final EdgeInsets viewportPadding;
  final bool autoFlip;
  final EdgeInsets popoverPadding;
  final void Function(MagoPopoverPosition pos, Offset offset, Size childSize)?
      onLayout;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final deflated = constraints.deflate(viewportPadding);
    return BoxConstraints(
      minWidth: 0,
      minHeight: 0,
      maxWidth: deflated.maxWidth,
      maxHeight: deflated.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final leftPad = viewportPadding.left;
    final topPad = viewportPadding.top;
    final rightPad = viewportPadding.right;
    final bottomPad = viewportPadding.bottom;

    MagoPopoverPosition pos = preferred;

    Offset place(MagoPopoverPosition p) {
      double x;
      double y;

      switch (p) {
        case MagoPopoverPosition.topLeft:
          x = targetRect.left;
          y = targetRect.top - childSize.height - gap;
          break;
        case MagoPopoverPosition.topCenter:
          x = targetRect.center.dx - childSize.width / 2;
          y = targetRect.top - childSize.height - gap;
          break;
        case MagoPopoverPosition.topRight:
          x = targetRect.right - childSize.width;
          y = targetRect.top - childSize.height - gap;
          break;

        case MagoPopoverPosition.middleLeft:
          x = targetRect.left - childSize.width - gap;
          y = targetRect.center.dy - childSize.height / 2;
          break;
        case MagoPopoverPosition.middleCenter:
          x = targetRect.center.dx - childSize.width / 2;
          y = targetRect.center.dy - childSize.height / 2;
          break;
        case MagoPopoverPosition.middleRight:
          x = targetRect.right + gap;
          y = targetRect.center.dy - childSize.height / 2;
          break;

        case MagoPopoverPosition.bottomLeft:
          x = targetRect.left;
          y = targetRect.bottom + gap;
          break;
        case MagoPopoverPosition.bottomCenter:
          x = targetRect.center.dx - childSize.width / 2;
          y = targetRect.bottom + gap;
          break;
        case MagoPopoverPosition.bottomRight:
          x = targetRect.right - childSize.width;
          y = targetRect.bottom + gap;
          break;
        case MagoPopoverPosition.rightTop:
          x = targetRect.right + gap;
          y = targetRect.top;
          break;
        case MagoPopoverPosition.rightBottom:
          x = targetRect.right + gap;
          y = targetRect.bottom - childSize.height + popoverPadding.bottom;
          break;
        case MagoPopoverPosition.leftTop:
          x = targetRect.left - childSize.width - gap;
          y = targetRect.top;
          break;
        case MagoPopoverPosition.leftBottom:
          x = targetRect.left - childSize.width - gap;
          y = targetRect.bottom - childSize.height + popoverPadding.bottom;
          break;
      }

      return Offset(x, y);
    }

    bool overflows(Offset o) {
      final r = Rect.fromLTWH(o.dx, o.dy, childSize.width, childSize.height);
      return r.left < leftPad ||
          r.top < topPad ||
          r.right > size.width - rightPad ||
          r.bottom > size.height - bottomPad;
    }

    bool overflowsH(Offset o) {
      return o.dx < leftPad || o.dx + childSize.width > size.width - rightPad;
    }

    var offset = place(pos);

    if (autoFlip && overflows(offset)) {
      if (_isSidePosition(pos)) {
        if (overflowsH(offset)) {
          final hFlipped = _flipSideHorizontal(pos);
          final oH = place(hFlipped);
          if (!overflowsH(oH)) {
            pos = hFlipped;
            offset = oH;
          } else {
            final fallbacks = _fallbacksFor(pos);
            for (final fb in fallbacks) {
              final o = place(fb);
              if (!overflows(o)) {
                pos = fb;
                offset = o;
                break;
              }
            }
          }
        }
      } else {
        final fallbacks = _fallbacksFor(pos);
        for (final fb in fallbacks) {
          final o = place(fb);
          if (!overflows(o)) {
            pos = fb;
            offset = o;
            break;
          }
        }
      }
    }
    double clampedX = offset.dx.clamp(
      leftPad,
      (size.width - rightPad - childSize.width).clamp(leftPad, double.infinity),
    );

    double clampedY;
    if (_isSidePosition(pos)) {
      final viewportBottom = size.height - bottomPad;
      final popoverBottom = offset.dy + childSize.height;

      if (popoverBottom > viewportBottom) {
        clampedY = targetRect.bottom - childSize.height + popoverPadding.bottom;
      } else if (offset.dy < topPad) {
        clampedY = targetRect.top;
      } else {
        clampedY = offset.dy;
      }
      clampedY = clampedY.clamp(
        topPad,
        (size.height - bottomPad - childSize.height)
            .clamp(topPad, double.infinity),
      );
    } else {
      clampedY = offset.dy.clamp(
        topPad,
        (size.height - bottomPad - childSize.height)
            .clamp(topPad, double.infinity),
      );
    }

    final result = Offset(clampedX, clampedY);
    onLayout?.call(pos, result, childSize);
    return result;
  }

  bool _isSidePosition(MagoPopoverPosition p) {
    return p == MagoPopoverPosition.rightTop ||
        p == MagoPopoverPosition.rightBottom ||
        p == MagoPopoverPosition.leftTop ||
        p == MagoPopoverPosition.leftBottom ||
        p == MagoPopoverPosition.middleRight ||
        p == MagoPopoverPosition.middleLeft;
  }

  MagoPopoverPosition _flipSideVertical(MagoPopoverPosition p) {
    switch (p) {
      case MagoPopoverPosition.rightTop:
        return MagoPopoverPosition.rightBottom;
      case MagoPopoverPosition.rightBottom:
        return MagoPopoverPosition.rightTop;
      case MagoPopoverPosition.leftTop:
        return MagoPopoverPosition.leftBottom;
      case MagoPopoverPosition.leftBottom:
        return MagoPopoverPosition.leftTop;
      default:
        return p;
    }
  }

  MagoPopoverPosition _flipSideHorizontal(MagoPopoverPosition p) {
    switch (p) {
      case MagoPopoverPosition.rightTop:
        return MagoPopoverPosition.leftTop;
      case MagoPopoverPosition.rightBottom:
        return MagoPopoverPosition.leftBottom;
      case MagoPopoverPosition.leftTop:
        return MagoPopoverPosition.rightTop;
      case MagoPopoverPosition.leftBottom:
        return MagoPopoverPosition.rightBottom;
      case MagoPopoverPosition.middleLeft:
        return MagoPopoverPosition.middleRight;
      case MagoPopoverPosition.middleRight:
        return MagoPopoverPosition.middleLeft;
      default:
        return p;
    }
  }

  List<MagoPopoverPosition> _fallbacksFor(MagoPopoverPosition p) {
    switch (p) {
      case MagoPopoverPosition.rightTop:
        return const [
          MagoPopoverPosition.rightBottom,
          MagoPopoverPosition.leftTop,
          MagoPopoverPosition.leftBottom,
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.bottomRight,
          MagoPopoverPosition.topLeft,
          MagoPopoverPosition.topRight,
        ];
      case MagoPopoverPosition.rightBottom:
        return const [
          MagoPopoverPosition.rightTop,
          MagoPopoverPosition.leftBottom,
          MagoPopoverPosition.leftTop,
          MagoPopoverPosition.bottomRight,
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.topRight,
          MagoPopoverPosition.topLeft,
        ];
      case MagoPopoverPosition.leftTop:
        return const [
          MagoPopoverPosition.leftBottom,
          MagoPopoverPosition.rightTop,
          MagoPopoverPosition.rightBottom,
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.bottomRight,
          MagoPopoverPosition.topLeft,
          MagoPopoverPosition.topRight,
        ];
      case MagoPopoverPosition.leftBottom:
        return const [
          MagoPopoverPosition.leftTop,
          MagoPopoverPosition.rightBottom,
          MagoPopoverPosition.rightTop,
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.bottomRight,
          MagoPopoverPosition.topLeft,
          MagoPopoverPosition.topRight,
        ];

      case MagoPopoverPosition.middleLeft:
        return const [
          MagoPopoverPosition.middleRight,
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.topLeft,
        ];
      case MagoPopoverPosition.middleRight:
        return const [
          MagoPopoverPosition.middleLeft,
          MagoPopoverPosition.bottomRight,
          MagoPopoverPosition.topRight,
        ];

      case MagoPopoverPosition.topLeft:
        return const [
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.topRight,
          MagoPopoverPosition.bottomRight,
        ];
      case MagoPopoverPosition.topCenter:
        return const [
          MagoPopoverPosition.bottomCenter,
          MagoPopoverPosition.topLeft,
          MagoPopoverPosition.topRight,
        ];
      case MagoPopoverPosition.topRight:
        return const [
          MagoPopoverPosition.bottomRight,
          MagoPopoverPosition.topLeft,
          MagoPopoverPosition.bottomLeft,
        ];

      case MagoPopoverPosition.bottomLeft:
        return const [
          MagoPopoverPosition.topLeft,
          MagoPopoverPosition.bottomRight,
          MagoPopoverPosition.topRight,
        ];
      case MagoPopoverPosition.bottomCenter:
        return const [
          MagoPopoverPosition.topCenter,
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.bottomRight,
        ];
      case MagoPopoverPosition.bottomRight:
        return const [
          MagoPopoverPosition.topRight,
          MagoPopoverPosition.bottomLeft,
          MagoPopoverPosition.topLeft,
        ];

      case MagoPopoverPosition.middleCenter:
        return const [];
    }
  }

  @override
  bool shouldRelayout(covariant _MagoPopoverViewportDelegate oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        preferred != oldDelegate.preferred ||
        gap != oldDelegate.gap ||
        viewportPadding != oldDelegate.viewportPadding ||
        autoFlip != oldDelegate.autoFlip;
  }
}

Path _buildPopoverPath({
  required Size size,
  required BorderRadius borderRadius,
  _ArrowSide? arrowSide,
  double arrowOffset = 0,
  double arrowSize = 6,
  double arrowBaseWidth = 22,
}) {
  if (arrowSide == null) {
    return Path()
      ..addRRect(borderRadius
          .resolve(TextDirection.ltr)
          .toRRect(Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  final halfBase = arrowBaseWidth / 2;
  final r = borderRadius.resolve(TextDirection.ltr);
  final rect = Rect.fromLTWH(0, 0, size.width, size.height);
  final rrect = r.toRRect(rect);
  final path = Path();

  final joinR = halfBase * 0.75;

  final tipR = arrowSize * 0.55;

  switch (arrowSide) {
    case _ArrowSide.top:
      path.moveTo(rrect.left + rrect.tlRadiusX, rrect.top);
      path.lineTo(arrowOffset - halfBase, rrect.top);

      path.cubicTo(
        arrowOffset - halfBase + joinR,
        rrect.top,
        arrowOffset - tipR,
        rrect.top - arrowSize,
        arrowOffset,
        rrect.top - arrowSize,
      );

      path.cubicTo(
        arrowOffset + tipR,
        rrect.top - arrowSize,
        arrowOffset + halfBase - joinR,
        rrect.top,
        arrowOffset + halfBase,
        rrect.top,
      );
      path.lineTo(rrect.right - rrect.trRadiusX, rrect.top);
      path.arcToPoint(Offset(rrect.right, rrect.top + rrect.trRadiusY),
          radius: Radius.elliptical(rrect.trRadiusX, rrect.trRadiusY));
      path.lineTo(rrect.right, rrect.bottom - rrect.brRadiusY);
      path.arcToPoint(Offset(rrect.right - rrect.brRadiusX, rrect.bottom),
          radius: Radius.elliptical(rrect.brRadiusX, rrect.brRadiusY));
      path.lineTo(rrect.left + rrect.blRadiusX, rrect.bottom);
      path.arcToPoint(Offset(rrect.left, rrect.bottom - rrect.blRadiusY),
          radius: Radius.elliptical(rrect.blRadiusX, rrect.blRadiusY));
      path.lineTo(rrect.left, rrect.top + rrect.tlRadiusY);
      path.arcToPoint(Offset(rrect.left + rrect.tlRadiusX, rrect.top),
          radius: Radius.elliptical(rrect.tlRadiusX, rrect.tlRadiusY));
      break;

    case _ArrowSide.bottom:
      path.moveTo(rrect.left + rrect.tlRadiusX, rrect.top);
      path.lineTo(rrect.right - rrect.trRadiusX, rrect.top);
      path.arcToPoint(Offset(rrect.right, rrect.top + rrect.trRadiusY),
          radius: Radius.elliptical(rrect.trRadiusX, rrect.trRadiusY));
      path.lineTo(rrect.right, rrect.bottom - rrect.brRadiusY);
      path.arcToPoint(Offset(rrect.right - rrect.brRadiusX, rrect.bottom),
          radius: Radius.elliptical(rrect.brRadiusX, rrect.brRadiusY));

      path.lineTo(arrowOffset + halfBase, rrect.bottom);
      path.cubicTo(
        arrowOffset + halfBase - joinR,
        rrect.bottom,
        arrowOffset + tipR,
        rrect.bottom + arrowSize,
        arrowOffset,
        rrect.bottom + arrowSize,
      );
      path.cubicTo(
        arrowOffset - tipR,
        rrect.bottom + arrowSize,
        arrowOffset - halfBase + joinR,
        rrect.bottom,
        arrowOffset - halfBase,
        rrect.bottom,
      );
      path.lineTo(rrect.left + rrect.blRadiusX, rrect.bottom);
      path.arcToPoint(Offset(rrect.left, rrect.bottom - rrect.blRadiusY),
          radius: Radius.elliptical(rrect.blRadiusX, rrect.blRadiusY));
      path.lineTo(rrect.left, rrect.top + rrect.tlRadiusY);
      path.arcToPoint(Offset(rrect.left + rrect.tlRadiusX, rrect.top),
          radius: Radius.elliptical(rrect.tlRadiusX, rrect.tlRadiusY));
      break;

    case _ArrowSide.left:
      path.moveTo(rrect.left + rrect.tlRadiusX, rrect.top);
      path.lineTo(rrect.right - rrect.trRadiusX, rrect.top);
      path.arcToPoint(Offset(rrect.right, rrect.top + rrect.trRadiusY),
          radius: Radius.elliptical(rrect.trRadiusX, rrect.trRadiusY));
      path.lineTo(rrect.right, rrect.bottom - rrect.brRadiusY);
      path.arcToPoint(Offset(rrect.right - rrect.brRadiusX, rrect.bottom),
          radius: Radius.elliptical(rrect.brRadiusX, rrect.brRadiusY));
      path.lineTo(rrect.left + rrect.blRadiusX, rrect.bottom);
      path.arcToPoint(Offset(rrect.left, rrect.bottom - rrect.blRadiusY),
          radius: Radius.elliptical(rrect.blRadiusX, rrect.blRadiusY));

      path.lineTo(rrect.left, arrowOffset + halfBase);
      path.cubicTo(
        rrect.left,
        arrowOffset + halfBase - joinR,
        rrect.left - arrowSize,
        arrowOffset + tipR,
        rrect.left - arrowSize,
        arrowOffset,
      );
      path.cubicTo(
        rrect.left - arrowSize,
        arrowOffset - tipR,
        rrect.left,
        arrowOffset - halfBase + joinR,
        rrect.left,
        arrowOffset - halfBase,
      );
      path.lineTo(rrect.left, rrect.top + rrect.tlRadiusY);
      path.arcToPoint(Offset(rrect.left + rrect.tlRadiusX, rrect.top),
          radius: Radius.elliptical(rrect.tlRadiusX, rrect.tlRadiusY));
      break;

    case _ArrowSide.right:
      path.moveTo(rrect.left + rrect.tlRadiusX, rrect.top);
      path.lineTo(rrect.right - rrect.trRadiusX, rrect.top);
      path.arcToPoint(Offset(rrect.right, rrect.top + rrect.trRadiusY),
          radius: Radius.elliptical(rrect.trRadiusX, rrect.trRadiusY));

      path.lineTo(rrect.right, arrowOffset - halfBase);
      path.cubicTo(
        rrect.right,
        arrowOffset - halfBase + joinR,
        rrect.right + arrowSize,
        arrowOffset - tipR,
        rrect.right + arrowSize,
        arrowOffset,
      );
      path.cubicTo(
        rrect.right + arrowSize,
        arrowOffset + tipR,
        rrect.right,
        arrowOffset + halfBase - joinR,
        rrect.right,
        arrowOffset + halfBase,
      );
      path.lineTo(rrect.right, rrect.bottom - rrect.brRadiusY);
      path.arcToPoint(Offset(rrect.right - rrect.brRadiusX, rrect.bottom),
          radius: Radius.elliptical(rrect.brRadiusX, rrect.brRadiusY));
      path.lineTo(rrect.left + rrect.blRadiusX, rrect.bottom);
      path.arcToPoint(Offset(rrect.left, rrect.bottom - rrect.blRadiusY),
          radius: Radius.elliptical(rrect.blRadiusX, rrect.blRadiusY));
      path.lineTo(rrect.left, rrect.top + rrect.tlRadiusY);
      path.arcToPoint(Offset(rrect.left + rrect.tlRadiusX, rrect.top),
          radius: Radius.elliptical(rrect.tlRadiusX, rrect.tlRadiusY));
      break;

    case null:
      break;
  }

  path.close();
  return path;
}

class _PopoverClipper extends CustomClipper<Path> {
  _PopoverClipper({
    required this.borderRadius,
    this.arrowSide,
    this.arrowOffset = 0,
    this.arrowSize = 6,
    this.arrowBaseWidth = 22,
  });

  final BorderRadius borderRadius;
  final _ArrowSide? arrowSide;
  final double arrowOffset;
  final double arrowSize;
  final double arrowBaseWidth;

  @override
  Path getClip(Size size) => _buildPopoverPath(
        size: size,
        borderRadius: borderRadius,
        arrowSide: arrowSide,
        arrowOffset: arrowOffset,
        arrowSize: arrowSize,
        arrowBaseWidth: arrowBaseWidth,
      );

  @override
  bool shouldReclip(_PopoverClipper old) =>
      borderRadius != old.borderRadius ||
      arrowSide != old.arrowSide ||
      arrowOffset != old.arrowOffset ||
      arrowSize != old.arrowSize ||
      arrowBaseWidth != old.arrowBaseWidth;
}

class _PopoverShapePainter extends CustomPainter {
  _PopoverShapePainter({
    required this.borderRadius,
    required this.bgColor,
    required this.borderWidth,
    required this.borderGradient,
    this.arrowSide,
    this.arrowOffset = 0,
    this.arrowSize = 6,
    this.arrowBaseWidth = 22,
  });

  final BorderRadius borderRadius;
  final Color bgColor;
  final double borderWidth;
  final Gradient borderGradient;
  final _ArrowSide? arrowSide;
  final double arrowOffset;
  final double arrowSize;
  final double arrowBaseWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPopoverPath(
      size: size,
      borderRadius: borderRadius,
      arrowSide: arrowSide,
      arrowOffset: arrowOffset,
      arrowSize: arrowSize,
      arrowBaseWidth: arrowBaseWidth,
    );

    canvas.drawPath(path, Paint()..color = bgColor);

    final borderPaint = Paint()
      ..shader = borderGradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_PopoverShapePainter old) =>
      borderRadius != old.borderRadius ||
      bgColor != old.bgColor ||
      borderWidth != old.borderWidth ||
      arrowSide != old.arrowSide ||
      arrowOffset != old.arrowOffset ||
      arrowSize != old.arrowSize ||
      arrowBaseWidth != old.arrowBaseWidth;
}

class _PopoverGlass extends StatelessWidget {
  const _PopoverGlass({
    required this.borderRadius,
    this.backgroundColor,
    this.padding,
    this.arrowSide,
    this.arrowOffset = 0,
    this.arrowSize = 6,
    this.arrowBaseWidth = 22,
    this.child,
  });

  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final _ArrowSide? arrowSide;
  final double arrowOffset;
  final double arrowSize;
  final double arrowBaseWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgBase = backgroundColor ??
        (isDark
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surface);
    final brdBase = theme.colorScheme.onSurface;

    const bgOpacity = 0.2;
    const borderOpacity = 0.3;
    const borderWidth = 0.5;
    const blurSigma = 10.0;

    final resolvedBg = bgBase.withValues(alpha: bgOpacity);
    final lightEdge =
        brdBase.withValues(alpha: (borderOpacity * 1.8).clamp(0.0, 1.0));
    final darkEdge =
        brdBase.withValues(alpha: (borderOpacity * 0.2).clamp(0.0, 1.0));
    final midEdge = brdBase.withValues(alpha: borderOpacity);

    final gradient = SweepGradient(
      center: Alignment.center,
      colors: [
        midEdge,
        lightEdge,
        midEdge,
        darkEdge,
        midEdge,
        lightEdge,
        midEdge,
        darkEdge,
        midEdge,
      ],
      stops: const [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1],
    );

    final clipper = _PopoverClipper(
      borderRadius: borderRadius,
      arrowSide: arrowSide,
      arrowOffset: arrowOffset,
      arrowSize: arrowSize,
      arrowBaseWidth: arrowBaseWidth,
    );

    Widget content = child ?? const SizedBox.shrink();
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return ClipPath(
      clipper: clipper,
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: CustomPaint(
          painter: _PopoverShapePainter(
            borderRadius: borderRadius,
            bgColor: resolvedBg,
            borderWidth: borderWidth,
            borderGradient: gradient,
            arrowSide: arrowSide,
            arrowOffset: arrowOffset,
            arrowSize: arrowSize,
            arrowBaseWidth: arrowBaseWidth,
          ),
          child: content,
        ),
      ),
    );
  }
}
