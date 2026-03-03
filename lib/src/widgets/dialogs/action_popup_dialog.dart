import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/dialogs/popup_dialog.dart';

typedef MagoDialogValueBuilder<T> = T Function();

class MagoActionPopupDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    bool barrierDismissible = true,
    EdgeInsets padding = MagoPopupDialog.defaultPadding,
    double width = 320,
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
  }) {
    return MagoPopupDialog.show<T>(
      context,
      barrierDismissible: barrierDismissible,
      padding: padding,
      width: width,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      child: _ActionDialogContent<T>(
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
      ),
    );
  }
}

class _ActionDialogContent<T> extends StatelessWidget {
  const _ActionDialogContent({
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
    final dividerColor = theme.colorScheme.outlineVariant;

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
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null && title!.trim().isNotEmpty) ...[
                  Text(title!, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                ],
                Flexible(
                  child: SingleChildScrollView(child: child),
                ),
              ],
            ),
          ),
          Container(width: double.infinity, height: 0.5, color: dividerColor),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: cancelStyle,
                    onPressed: cancel,
                    child: Text(cancelText),
                  ),
                ),
                VerticalDivider(
                    width: 0.5, thickness: 0.5, color: dividerColor),
                Expanded(
                  child: OutlinedButton(
                    style: confirmStyle,
                    onPressed: confirmEnabled ? confirm : null,
                    child: Text(confirmText),
                  ),
                ),
              ],
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
