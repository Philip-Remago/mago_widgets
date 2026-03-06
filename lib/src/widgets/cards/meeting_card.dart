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
    this.icon = Icons.phone,
    this.buttonText = 'Join',
    this.onButtonPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.all(16),
    this.glassProperties,
    this.iconColor,
  });

  final String topLabel;

  final String title;

  final String subtitle;

  final IconData icon;

  final String buttonText;

  final VoidCallback? onButtonPressed;

  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final GlassProperties? glassProperties;
  final Color? iconColor;

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
              Icon(
                icon,
                size: 20,
                color: iconColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleMedium,
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
              variant: MagoButtonVariant.outline,
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
