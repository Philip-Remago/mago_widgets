import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MagoObjectLoader extends StatefulWidget {
  final String lightAsset;

  final String darkAsset;

  final double logoSize;

  final Color? backgroundColor;

  final double minOpacity;

  final double maxOpacity;

  final Duration pulseDuration;

  const MagoObjectLoader({
    super.key,
    this.lightAsset = 'assets/images/defaults/logo/pinecone.light.svg',
    this.darkAsset = 'assets/images/defaults/logo/pinecone.dark.svg',
    this.logoSize = 64,
    this.backgroundColor,
    this.minOpacity = 0.3,
    this.maxOpacity = 0.7,
    this.pulseDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<MagoObjectLoader> createState() => _MagoObjectLoaderState();
}

class _MagoObjectLoaderState extends State<MagoObjectLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.backgroundColor ?? Theme.of(context).colorScheme.surface;
    final asset = isDark ? widget.darkAsset : widget.lightAsset;

    return ColoredBox(
      color: bg,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: SvgPicture.asset(
            asset,
            width: widget.logoSize,
            height: widget.logoSize,
          ),
        ),
      ),
    );
  }
}
