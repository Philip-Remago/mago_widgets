import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/dialogs/action_popup_dialog.dart';
import 'package:mago_widgets/src/widgets/dialogs/popup_dialog.dart';

class MagoLargeActionPopupDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    bool barrierDismissible = true,
    EdgeInsets padding = MagoPopupDialog.defaultPadding,
    double width = 560,
    Radius borderRadius = MagoPopupDialog.defaultBorderRadius,
    Color? backgroundColor,
    String? title,
    required Widget child,
    String cancelText = 'Cancel',
    String confirmText = 'OK',
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
    bool confirmEnabled = true,
    Color? cancelTextColor,
    Color? confirmTextColor,
    bool avoidKeyboard = false,
    MagoDialogValueBuilder<T>? confirmValueBuilder,
    MagoDialogValueBuilder<T>? cancelValueBuilder,
    double maxHeightFactor = 0.85,
    EdgeInsets contentPadding = const EdgeInsets.all(20),
    MagoDialogPosition anchorPosition = MagoDialogPosition.center,
  }) {
    return MagoPopupDialog.show<T>(
      context,
      barrierDismissible: barrierDismissible,
      padding: padding,
      width: width,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      anchorPosition: anchorPosition,
      child: _LargeActionDialogContent<T>(
        title: title,
        child: child,
        cancelText: cancelText,
        confirmText: confirmText,
        onCancel: onCancel,
        onConfirm: onConfirm,
        confirmEnabled: confirmEnabled,
        cancelTextColor: cancelTextColor,
        confirmTextColor: confirmTextColor,
        avoidKeyboard: avoidKeyboard,
        confirmValueBuilder: confirmValueBuilder,
        cancelValueBuilder: cancelValueBuilder,
        maxHeightFactor: maxHeightFactor,
        contentPadding: contentPadding,
      ),
    );
  }
}

class _LargeActionDialogContent<T> extends StatelessWidget {
  const _LargeActionDialogContent({
    required this.title,
    required this.child,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmEnabled,
    required this.cancelTextColor,
    required this.confirmTextColor,
    required this.avoidKeyboard,
    required this.confirmValueBuilder,
    required this.cancelValueBuilder,
    required this.maxHeightFactor,
    required this.contentPadding,
  });

  final String? title;
  final Widget child;

  final String cancelText;
  final String confirmText;

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  final bool confirmEnabled;

  final Color? cancelTextColor;
  final Color? confirmTextColor;

  final bool avoidKeyboard;

  final MagoDialogValueBuilder<T>? confirmValueBuilder;
  final MagoDialogValueBuilder<T>? cancelValueBuilder;

  final double maxHeightFactor;
  final EdgeInsets contentPadding;

  static const ButtonStyle _baseButtonStyle = ButtonStyle(
    shape: MaterialStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    minimumSize: MaterialStatePropertyAll(Size.fromHeight(52)),
    side: MaterialStatePropertyAll(BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cancelStyle = _baseButtonStyle.copyWith(
      foregroundColor: cancelTextColor == null
          ? null
          : MaterialStatePropertyAll(cancelTextColor),
    );

    final confirmStyle = _baseButtonStyle.copyWith(
      foregroundColor: confirmTextColor == null
          ? null
          : MaterialStatePropertyAll(confirmTextColor),
    );

    void cancel() {
      onCancel?.call();
      Navigator.of(context).pop(cancelValueBuilder?.call());
    }

    void confirm() {
      if (!confirmEnabled) return;
      onConfirm?.call();
      Navigator.of(context).pop(confirmValueBuilder?.call());
    }

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;

    final titleText = (title ?? '').trim();

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IntrinsicWidth(
                    child: OutlinedButton(
                      style: cancelStyle,
                      onPressed: cancel,
                      child: Text(cancelText),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IntrinsicWidth(
                    child: OutlinedButton(
                      style: confirmStyle,
                      onPressed: confirmEnabled ? confirm : null,
                      child: Text(confirmText),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: contentPadding,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ],
      ),
    );

    if (!avoidKeyboard) return content;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: content,
    );
  }
}
