import 'package:flutter/material.dart';
import 'package:mago_widgets/src/helpers/constants.dart';
import 'package:mago_widgets/src/widgets/buttons/text_button.dart';
import 'package:mago_widgets/src/widgets/buttons/button_style.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';

class MagoMeetingCard extends StatelessWidget {
  const MagoMeetingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.topLabel,
    this.icon,
    this.buttonText = 'Join',
    this.onButtonPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.all(16),
    this.glassProperties,
  });

  final String topLabel;

  final String title;

  final String subtitle;

  final Widget? icon;

  final String buttonText;

  final VoidCallback? onButtonPressed;

  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final GlassProperties? glassProperties;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lightStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return GlassContainer(
      borderRadius: borderRadius,
      glassProperties: glassProperties ?? const GlassProperties(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  topLabel,
                  style: lightStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) icon!,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: lightStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: MagoTextButton(
              text: buttonText,
              onPressed: onButtonPressed,
              variant: MagoButtonVariant.filled,
              backgroundColor: theme.colorScheme.scrim,
              foregroundColor: theme.colorScheme.onInverseSurface,
              boxShadow: const [],
              minHeight: 36,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
