import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mago_widgets/src/helpers/border_radius_calculator.dart';
import 'package:mago_widgets/src/helpers/constants.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';
import 'package:mago_widgets/src/widgets/components/object_loader.dart';

class MagoCard extends StatelessWidget {
  const MagoCard({
    super.key,
    required this.title,
    required this.onTap,
    this.onLongPress,
    this.imageUrl,
    this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.glassProperties,
    this.inset = 4.0,
  });

  final String title;
  final String? imageUrl;

  final Widget? child;

  final BorderRadius borderRadius;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  final GlassProperties? glassProperties;

  final double inset;

  bool get _hasUrl => imageUrl?.trim().isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final innerRadius = MagoBorderRadiusCalculator().calculate(
      borderRadius,
      inset,
      Directionality.of(context),
    );

    return GlassContainer(
      borderRadius: borderRadius,
      glassProperties: glassProperties?.copyWith(
        boxShadow: glassProperties?.boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 8,
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, inset, inset, 0),
                child: ClipRRect(
                  borderRadius: innerRadius,
                  child: child != null
                      ? child!
                      : _hasUrl
                          ? _NetworkImageWithLoader(
                              url: imageUrl!.trim(),
                              isDark: isDark,
                            )
                          : _PineconeFallback(isDark: isDark),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PineconeFallback extends StatelessWidget {
  const _PineconeFallback({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final asset = isDark
        ? 'assets/images/defaults/logo/pinecone.dark.svg'
        : 'assets/images/defaults/logo/pinecone.light.svg';

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Opacity(
          opacity: 0.7,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 0.5,
            child: SvgPicture.asset(asset),
          ),
        ),
      ),
    );
  }
}

class _NetworkImageWithLoader extends StatelessWidget {
  const _NetworkImageWithLoader({
    required this.url,
    required this.isDark,
  });

  final String url;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const MagoObjectLoader(backgroundColor: Colors.transparent),
      errorWidget: (context, url, error) => _PineconeFallback(isDark: isDark),
    );
  }
}
