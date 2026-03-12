import 'package:flutter/material.dart';
import 'package:mago_widgets/src/widgets/components/glass_container.dart';

enum MagoToastType { success, error, info, warning }

const double _toastGap = 12;

const double _edgeMargin = 16;

class MagoToast {
  MagoToast._();

  static final List<_ToastEntry> _active = [];

  static void show(
    BuildContext context,
    String title, {
    String? description,
    MagoToastType type = MagoToastType.success,
    Duration displayDuration = const Duration(seconds: 3),
    Duration animationDuration = const Duration(milliseconds: 350),
    Brightness? brightness,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry overlayEntry;
    late final _ToastEntry record;

    final baseTheme = Theme.of(context);
    final effectiveTheme = brightness != null
        ? ThemeData(
            brightness: brightness,
            colorScheme: ColorScheme.fromSeed(
              seedColor: baseTheme.colorScheme.primary,
              brightness: brightness,
            ),
          )
        : null;

    void remove() {
      if (!overlayEntry.mounted) return;
      overlayEntry.remove();
      _active.remove(record);
      _repositionAll();
    }

    Widget toastWidget() => _ToastWidget(
          key: record.widgetKey,
          title: title,
          description: description,
          type: type,
          displayDuration: displayDuration,
          animationDuration: animationDuration,
          bottomOffset: _edgeMargin,
          onDismissed: remove,
        );

    overlayEntry = OverlayEntry(
      builder: (_) => effectiveTheme != null
          ? Theme(data: effectiveTheme, child: toastWidget())
          : toastWidget(),
    );

    record = _ToastEntry(
      overlayEntry: overlayEntry,
      widgetKey: GlobalKey<_ToastWidgetState>(),
    );

    _active.add(record);
    overlay.insert(overlayEntry);
    _repositionAll();
  }

  static void _repositionAll() {
    double offset = _edgeMargin;
    for (final entry in _active.reversed) {
      final state = entry.widgetKey.currentState;
      if (state != null && state.mounted) {
        state._setBottomOffset(offset);
      }
      final measured = state?._measuredHeight;
      offset += (measured ?? 68) + _toastGap;
    }
  }
}

class _ToastEntry {
  _ToastEntry({required this.overlayEntry, required this.widgetKey});
  final OverlayEntry overlayEntry;
  final GlobalKey<_ToastWidgetState> widgetKey;
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required super.key,
    required this.title,
    required this.type,
    required this.displayDuration,
    required this.animationDuration,
    required this.bottomOffset,
    required this.onDismissed,
    this.description,
  });

  final String title;
  final String? description;
  final MagoToastType type;
  final Duration displayDuration;
  final Duration animationDuration;
  final double bottomOffset;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _countdownCtrl;

  bool _dismissed = false;
  bool _hasAnimatedPosition = false;
  double _bottomOffset = 0;
  double? _measuredHeight;

  final GlobalKey _contentKey = GlobalKey();

  void _setBottomOffset(double offset) {
    if (!mounted) return;
    setState(() {
      _bottomOffset = offset;
      _hasAnimatedPosition = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _bottomOffset = widget.bottomOffset;

    _slideCtrl = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn);

    _countdownCtrl = AnimationController(
      vsync: this,
      duration: widget.displayDuration,
    );

    _slideCtrl.forward().then((_) {
      if (!mounted || _dismissed) return;
      _countdownCtrl.forward().then((_) {
        if (!_dismissed) _dismiss();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeight());
  }

  void _measureHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final h = box.size.height;
        if (h != _measuredHeight) {
          _measuredHeight = h;
          MagoToast._repositionAll();
        }
      }
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _countdownCtrl.stop();
    _slideCtrl.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _countdownCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  IconData _iconForType() => switch (widget.type) {
        MagoToastType.success => Icons.check_circle_outline,
        MagoToastType.error => Icons.error_outline,
        MagoToastType.info => Icons.info_outline,
        MagoToastType.warning => Icons.warning_amber_rounded,
      };

  Color _accentColor(ThemeData theme) => switch (widget.type) {
        MagoToastType.success => Colors.green,
        MagoToastType.error => theme.colorScheme.error,
        MagoToastType.info => theme.colorScheme.primary,
        MagoToastType.warning => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColor(theme);
    final fg = theme.colorScheme.onSurface;

    return AnimatedPositioned(
      duration: _hasAnimatedPosition
          ? const Duration(milliseconds: 200)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      bottom: _bottomOffset,
      right: _edgeMargin,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.startToEnd,
            onDismissed: (_) {
              _dismissed = true;
              widget.onDismissed();
            },
            child: Material(
              color: Colors.transparent,
              child: GlassContainer(
                key: _contentKey,
                width: 360,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        8,
                        widget.description != null ? 14 : 10,
                      ),
                      child: Row(
                        crossAxisAlignment: widget.description != null
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Icon(_iconForType(), color: accent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: widget.description != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.title,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(color: fg),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.description!,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: fg.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    widget.title,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(color: fg),
                                  ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              onPressed: _dismiss,
                              icon: Icon(
                                Icons.close,
                                size: 16,
                                color: fg.withValues(alpha: 0.5),
                              ),
                              padding: EdgeInsets.zero,
                              splashRadius: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _countdownCtrl,
                      builder: (context, _) {
                        return LinearProgressIndicator(
                          value: 1.0 - _countdownCtrl.value,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
