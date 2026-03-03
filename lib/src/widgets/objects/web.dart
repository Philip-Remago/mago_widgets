import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MagoWeb extends StatefulWidget {
  final String url;

  final double virtualWidth;
  final double virtualHeight;

  final bool useDesktopUserAgent;

  const MagoWeb({
    super.key,
    required this.url,
    this.virtualWidth = 1920,
    this.virtualHeight = 1080,
    this.useDesktopUserAgent = false,
  });

  @override
  State<MagoWeb> createState() => _MagoWebState();
}

class _MagoWebState extends State<MagoWeb> {
  InAppWebViewController? _controller;

  bool _pageLoaded = false;
  Size? _lastSize;

  Future<void> _forceWebWidth(
      InAppWebViewController controller, Size size) async {
    final scale = size.width / 1920;

    final js = '''
      (function() {
        var head = document.head || document.getElementsByTagName('head')[0];
        if (head) {
          var meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            head.appendChild(meta);
          }
          meta.setAttribute('content', 'width=1920, initial-scale=$scale, maximum-scale=$scale, minimum-scale=$scale, user-scalable=no');
        }
        
        var style = document.querySelector('#forceWidth1920');
        if (!style) {
          style = document.createElement('style');
          style.id = 'forceWidth1920';
          document.head.appendChild(style);
        }
        
        style.textContent = 
          'html, body { min-width: 1920px !important; width: 1920px !important; overflow-x: hidden !important; }' +
          'body * { max-width: none !important; }';
      })();
    ''';

    await controller.evaluateJavascript(source: js);
  }

  void _maybeApplyOnResize(Size size) {
    if (_lastSize == size) return;
    _lastSize = size;

    if (!_pageLoaded) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller == null) return;
      _forceWebWidth(_controller!, size);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _maybeApplyOnResize(size);

        final scale = constraints.maxWidth / 1920;

        return FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1920,
            height: constraints.maxHeight / scale,
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                useWideViewPort: true,
                loadWithOverviewMode: true,
                supportZoom: false,
                builtInZoomControls: false,
                displayZoomControls: false,
                layoutAlgorithm: LayoutAlgorithm.NORMAL,
                minimumLogicalFontSize: 1,
                initialScale: 100,
                userAgent: widget.useDesktopUserAgent
                    ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
                    : null,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onLoadStart: (controller, url) {
                _pageLoaded = false;
              },
              onLoadStop: (controller, url) async {
                _pageLoaded = true;
                await _forceWebWidth(controller, size);
              },
            ),
          ),
        );
      },
    );
  }
}
