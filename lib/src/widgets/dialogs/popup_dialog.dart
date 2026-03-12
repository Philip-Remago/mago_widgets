import 'package:flutter/material.dart';
import 'package:mago_widgets/src/helpers/constants.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';

class MagoPopupDialog extends StatelessWidget {
  static const EdgeInsets defaultPadding =
      EdgeInsets.symmetric(horizontal: 2, vertical: 8);
  static const double defaultWidth = 100;
  static const Radius defaultBorderRadius = Radius.circular(8);

  final EdgeInsets padding;
  final double width;
  final Radius borderRadius;
  final Color? backgroundColor;
  final Widget child;

  const MagoPopupDialog({
    super.key,
    this.padding = defaultPadding,
    this.width = defaultWidth,
    this.borderRadius = defaultBorderRadius,
    this.backgroundColor,
    this.child = const SizedBox(height: 200),
  });

  // Guard duration for iOS phantom-tap workaround.
  // See: https://github.com/flutter/flutter/issues/177992
  static const _iosBarrierGuard = Duration(milliseconds: 500);

  static Future<T?> show<T>(
    BuildContext context, {
    bool barrierDismissible = true,
    EdgeInsets padding = defaultPadding,
    double width = defaultWidth,
    Radius borderRadius = defaultBorderRadius,
    Color? backgroundColor,
    Widget child = const SizedBox(height: 200),
    Duration transitionDuration = const Duration(milliseconds: 280),
  }) {
    final openedAt = DateTime.now();

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: transitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        Widget dialog = SafeArea(
          child: Center(
            child: MagoPopupDialog(
              padding: padding,
              width: width,
              borderRadius: borderRadius,
              backgroundColor: backgroundColor,
              child: child,
            ),
          ),
        );

        if (!barrierDismissible) return dialog;

        return TapRegion(
          onTapOutside: (_) {
            if (DateTime.now().difference(openedAt) < _iosBarrierGuard) return;
            if (Navigator.canPop(dialogContext)) {
              Navigator.pop(dialogContext);
            }
          },
          child: dialog,
        );
      },
      transitionBuilder:
          (dialogContext, animation, secondaryAnimation, dialogChild) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final slide = Tween<Offset>(
          begin: const Offset(0, 2.0),
          end: Offset.zero,
        ).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: slide,
            child: dialogChild,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Dialog(
        insetPadding: padding,
        backgroundColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(borderRadius),
        ),
        child: GlassContainer(
          borderRadius: BorderRadius.all(borderRadius),
          glassProperties: GlassProperties(backgroundColor: backgroundColor),
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: width),
            child: child,
          ),
        ),
      ),
    );
  }
}
