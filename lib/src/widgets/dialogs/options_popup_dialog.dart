import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/dialogs/popup_dialog.dart';

class MagoActionOption {
  final VoidCallback onPressed;
  final Color? color;

  const MagoActionOption({
    required this.onPressed,
    this.color,
  });
}

class MagoOptionsPopupDialog {
  static Future<String?> show(
    BuildContext context, {
    bool barrierDismissible = true,
    EdgeInsets padding = MagoPopupDialog.defaultPadding,
    double width = 320,
    Radius borderRadius = MagoPopupDialog.defaultBorderRadius,
    Color? backgroundColor,
    required String title,
    required Map<String, MagoActionOption> options,
    Color? defaultTextColor,
  }) {
    return MagoPopupDialog.show<String>(
      context,
      barrierDismissible: barrierDismissible,
      padding: padding,
      width: width,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      child: _OptionsDialogContent(
        title: title,
        options: options,
        defaultTextColor: defaultTextColor,
      ),
    );
  }
}

class _OptionsDialogContent extends StatelessWidget {
  const _OptionsDialogContent({
    required this.title,
    required this.options,
    required this.defaultTextColor,
  });

  final String title;
  final Map<String, MagoActionOption> options;
  final Color? defaultTextColor;

  static const ButtonStyle _buttonStyle = ButtonStyle(
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
    final fallbackColor = defaultTextColor ?? theme.colorScheme.primary;

    final entries = options.entries.toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Container(width: double.infinity, height: 0.5, color: dividerColor),
        ...List.generate(entries.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(
              width: double.infinity,
              height: 0.5,
              color: dividerColor,
            );
          }

          final entry = entries[i ~/ 2];
          final label = entry.key;
          final option = entry.value;

          final style = _buttonStyle.copyWith(
            foregroundColor:
                MaterialStatePropertyAll(option.color ?? fallbackColor),
          );

          return OutlinedButton(
            style: style,
            onPressed: () {
              option.onPressed();
              Navigator.of(context).pop(label);
            },
            child: Text(label),
          );
        }),
      ],
    );
  }
}
