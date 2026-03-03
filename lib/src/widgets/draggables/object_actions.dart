import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';

class MagoObjectActions extends StatelessWidget {
  const MagoObjectActions({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassContainer(
      borderRadius: BorderRadius.circular(8),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 0,
                  endIndent: 0,
                  color: theme.colorScheme.outlineVariant,
                ),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

class MagoObjectActionButton extends StatelessWidget {
  const MagoObjectActionButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 22,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
