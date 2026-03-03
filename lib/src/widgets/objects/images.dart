import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:mago_widgets/src/widgets/components/object_loader.dart';

class MagoImages extends StatefulWidget {
  final List<String> imageUrls;

  final int initialIndex;

  final TransformationController? externalController;

  final ValueChanged<int>? onPageChanged;

  final void Function(
    Map<String, double> xData,
    Map<String, double> yData,
    Map<String, double> scaleData,
  )? onZoomChanged;

  final ValueChanged<VoidCallback>? onNextPageCallback;
  final ValueChanged<VoidCallback>? onPrevPageCallback;

  final BoxFit fit;

  final double minScale;
  final double maxScale;

  const MagoImages({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.externalController,
    this.onPageChanged,
    this.onZoomChanged,
    this.onNextPageCallback,
    this.onPrevPageCallback,
    this.fit = BoxFit.contain,
    this.minScale = 1.0,
    this.maxScale = 6.0,
  });

  @override
  State<MagoImages> createState() => MagoImagesState();
}

class MagoImagesState extends State<MagoImages>
    with SingleTickerProviderStateMixin {
  final TransformationController _internalCtrl = TransformationController();
  TransformationController get _ctrl =>
      widget.externalController ?? _internalCtrl;

  late final PageController _pageCtrl;
  late AnimationController _animCtrl;
  Animation<Matrix4>? _resetAnim;

  late List<String> _pages;
  int _currentIndex = 0;

  int _pointerCount = 0;
  bool _isInteracting = false;
  bool _isPageScrolling = false;
  ScrollPhysics _frozenPhysics = const PageScrollPhysics();

  Size? _maxImageSize;

  final Map<String, Size> _imageSizes = {};
  bool _preloaded = false;

  static const double _eps = 1e-6;

  @override
  void initState() {
    super.initState();
    _pages = List.of(widget.imageUrls);
    _currentIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    _pageCtrl = PageController(initialPage: _currentIndex);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_resetAnim != null) _ctrl.value = _resetAnim!.value;
      });

    _internalCtrl.addListener(_onTransformChanged);
    widget.externalController?.addListener(_onTransformChanged);

    _preloadImages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNextPageCallback?.call(_nextPage);
      widget.onPrevPageCallback?.call(_prevPage);
    });
  }

  @override
  void didUpdateWidget(covariant MagoImages oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_listEq(widget.imageUrls, _pages)) {
      _pages = List.of(widget.imageUrls);
      final target = widget.initialIndex.clamp(0, _pages.length - 1);
      _currentIndex = target;
      if (_pageCtrl.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageCtrl.hasClients) _pageCtrl.jumpToPage(target);
        });
      }
      _ctrl.value = Matrix4.identity();
      _imageSizes.clear();
      _maxImageSize = null;
      _preloaded = false;
      _preloadImages();
      setState(() {});
    }

    if (oldWidget.externalController != widget.externalController) {
      oldWidget.externalController?.removeListener(_onTransformChanged);
      widget.externalController?.addListener(_onTransformChanged);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _internalCtrl.removeListener(_onTransformChanged);
    _internalCtrl.dispose();
    widget.externalController?.removeListener(_onTransformChanged);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _preloadImages() {
    if (_pages.isEmpty) {
      _preloaded = true;
      return;
    }

    int resolved = 0;
    final total = _pages.length;

    for (final url in _pages) {
      final provider = CachedNetworkImageProvider(url);
      final stream = provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool sync) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          _imageSizes[url] = Size(w, h);
          info.dispose();
          stream.removeListener(listener);
          resolved++;
          if (resolved == total) {
            _recalcMaxSize();
            if (mounted) setState(() => _preloaded = true);
          }
        },
        onError: (exception, stackTrace) {
          stream.removeListener(listener);
          resolved++;
          if (resolved == total) {
            _recalcMaxSize();
            if (mounted) setState(() => _preloaded = true);
          }
        },
      );
      stream.addListener(listener);
    }
  }

  void _recalcMaxSize() {
    if (_imageSizes.isEmpty) {
      _maxImageSize = null;
      return;
    }
    double maxW = 0, maxH = 0;
    for (final s in _imageSizes.values) {
      if (s.width > maxW) maxW = s.width;
      if (s.height > maxH) maxH = s.height;
    }
    _maxImageSize = Size(maxW, maxH);
  }

  void updatePage(int index) {
    if (_pages.isEmpty) return;
    final target = index.clamp(0, _pages.length - 1);
    if (_currentIndex == target) return;
    _currentIndex = target;
    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(target);
    _ctrl.value = Matrix4.identity();
    setState(() {});
    widget.onPageChanged?.call(_currentIndex);
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) updatePage(_currentIndex + 1);
  }

  void _prevPage() {
    if (_currentIndex > 0) updatePage(_currentIndex - 1);
  }

  int get pageCount => _pages.length;

  double get _scale => _ctrl.value.getMaxScaleOnAxis();
  bool get _isZoomed => _scale > widget.minScale + _eps;

  void _resetZoom() {
    _resetAnim = Matrix4Tween(
      begin: _ctrl.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward(from: 0);
  }

  void _snapToIdentityIfNeeded() {
    final s = _scale;
    if (s <= widget.minScale + _eps) {
      final m = _ctrl.value;
      final hasTranslation = m.storage[12] != 0.0 || m.storage[13] != 0.0;
      if (hasTranslation || (s - 1.0).abs() > 1e-9) {
        _ctrl.value = Matrix4.identity();
      }
    }
  }

  void _onTransformChanged() {
    _snapToIdentityIfNeeded();
    _emitZoom();
    if (!_isPageScrolling && mounted) setState(() {});
  }

  void _emitZoom() {
    final cb = widget.onZoomChanged;
    if (cb == null) return;
    final m = _ctrl.value;
    final t = m.getTranslation();
    cb({'x': t.x}, {'y': t.y}, {'scale': m.getMaxScaleOnAxis()});
  }

  bool get _shouldLockPageView =>
      _isInteracting || _isZoomed || _pointerCount >= 2;

  ScrollPhysics _pagePhysics() {
    if (_isPageScrolling) return _frozenPhysics;
    final next = _shouldLockPageView
        ? const NeverScrollableScrollPhysics()
        : const PageScrollPhysics();
    _frozenPhysics = next;
    return next;
  }

  void _handleScroll(PointerScrollEvent event) {
    final delta = event.scrollDelta.dy;
    final scaleFactor = delta > 0 ? 0.9 : 1.1;
    final currentScale = _scale;
    final newScale =
        (currentScale * scaleFactor).clamp(widget.minScale, widget.maxScale);
    if (newScale == currentScale) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final localFocal = box.globalToLocal(event.position);

    final ratio = newScale / currentScale;
    final fx = localFocal.dx, fy = localFocal.dy;
    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, ratio);
    matrix.setEntry(1, 1, ratio);
    matrix.setEntry(0, 3, fx - fx * ratio);
    matrix.setEntry(1, 3, fy - fy * ratio);

    _ctrl.value = matrix * _ctrl.value;

    if (_scale < widget.minScale + 0.02) {
      _resetZoom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Center(child: Text('No images'));
    }

    if (!_preloaded) {
      return const MagoObjectLoader();
    }

    Widget content;

    if (_pages.length == 1) {
      content = _buildSingle(_pages.first);
    } else {
      content = Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.horizontal) {
                if (n is ScrollStartNotification) {
                  _isPageScrolling = true;
                  _frozenPhysics = _pagePhysics();
                } else if (n is ScrollEndNotification ||
                    (n is UserScrollNotification &&
                        n.direction == ScrollDirection.idle)) {
                  _isPageScrolling = false;
                }
                if (mounted) setState(() {});
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageCtrl,
              physics: _pagePhysics(),
              itemCount: _pages.length,
              onPageChanged: (i) {
                _currentIndex = i;
                _ctrl.value = Matrix4.identity();
                setState(() {});
                widget.onPageChanged?.call(i);
              },
              itemBuilder: (_, i) =>
                  ClipRect(child: Center(child: _buildSingle(_pages[i]))),
            ),
          ),
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(child: _buildDots(context)),
          ),
        ],
      );
    }

    if (_maxImageSize != null) {
      final ratio = _maxImageSize!.width / _maxImageSize!.height;
      content = Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildSingle(String url) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        _pointerCount++;
        if (mounted) setState(() {});
      },
      onPointerUp: (_) {
        _pointerCount = (_pointerCount - 1).clamp(0, 99);
        if (mounted) setState(() {});
      },
      onPointerCancel: (_) {
        _pointerCount = (_pointerCount - 1).clamp(0, 99);
        if (mounted) setState(() {});
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _handleScroll(event);
      },
      child: InteractiveViewer(
        transformationController: _ctrl,
        panEnabled: _isZoomed,
        scaleEnabled: true,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        constrained: true,
        boundaryMargin: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        onInteractionStart: (_) {
          _animCtrl.stop();
          _isInteracting = true;
          if (mounted) setState(() {});
        },
        onInteractionUpdate: (_) {
          if (mounted) setState(() {});
        },
        onInteractionEnd: (_) {
          _isInteracting = false;
          if (_scale < widget.minScale + 0.05) _resetZoom();
          if (mounted) setState(() {});
        },
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: widget.fit,
            filterQuality: FilterQuality.medium,
            placeholder: (context, url) => const MagoObjectLoader(),
            errorWidget: (context, url, error) {
              return const Center(child: Text('Failed to load image'));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDots(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withAlpha(200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_pages.length, (i) {
            final active = i == _currentIndex;
            return Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(80),
              ),
            );
          }),
        ),
      ),
    );
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
