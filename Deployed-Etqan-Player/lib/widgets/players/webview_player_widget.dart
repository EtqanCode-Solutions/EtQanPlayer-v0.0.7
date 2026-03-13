import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/stream_data.dart';

/// مشغل WebView للفيديوهات الخارجية (VdoCipher, Vimeo)
class WebViewPlayerWidget extends StatefulWidget {
  final StreamData streamData;
  final VoidCallback? onReady;
  final VoidCallback? onEnded;
  final Function(String)? onError;

  const WebViewPlayerWidget({
    super.key,
    required this.streamData,
    this.onReady,
    this.onEnded,
    this.onError,
  });

  @override
  State<WebViewPlayerWidget> createState() => _WebViewPlayerWidgetState();
}

class _WebViewPlayerWidgetState extends State<WebViewPlayerWidget> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100 && _isLoading) {
              setState(() => _isLoading = false);
              widget.onReady?.call();
            }
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            widget.onError?.call(error.description);
          },
          onNavigationRequest: (NavigationRequest request) {
            // منع الانتقال لروابط خارجية
            final url = request.url;
            if (_isAllowedUrl(url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    // تحميل المحتوى حسب نوع المزود
    _loadContent();
  }

  bool _isAllowedUrl(String url) {
    final allowedDomains = [
      'youtube.com',
      'www.youtube.com',
      'youtu.be',
      'vimeo.com',
      'player.vimeo.com',
      'vdocipher.com',
      'dev.vdocipher.com',
      'player.vdocipher.com',
    ];

    try {
      final uri = Uri.parse(url);
      return allowedDomains.any((domain) => uri.host.contains(domain));
    } catch (_) {
      return false;
    }
  }

  void _loadContent() {
    switch (widget.streamData.provider) {
      case VideoProvider.vimeo:
        _loadVimeoPlayer();
        break;
      case VideoProvider.vdocipher:
        _loadVdoCipherPlayer();
        break;
      default:
        _loadGenericPlayer();
    }
  }

  void _loadVimeoPlayer() {
    final videoId = widget.streamData.videoId;
    if (videoId == null) {
      widget.onError?.call('Invalid Vimeo video ID');
      return;
    }

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe 
    src="https://player.vimeo.com/video/$videoId?autoplay=1&quality=auto&dnt=1&transparent=0"
    allow="autoplay; fullscreen; picture-in-picture"
    allowfullscreen>
  </iframe>
</body>
</html>
''';

    _controller.loadHtmlString(html);
  }

  void _loadVdoCipherPlayer() {
    final videoId = widget.streamData.videoId;
    if (videoId == null) {
      widget.onError?.call('Invalid VdoCipher video ID');
      return;
    }

    // VdoCipher يحتاج OTP و PlaybackInfo من الـ Backend
    // هنا نستخدم الـ embed URL البسيط
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
    #player { width: 100%; height: 100%; }
  </style>
  <script src="https://player.vdocipher.com/v2/api.js"></script>
</head>
<body>
  <div id="player"></div>
  <script>
    // VdoCipher player initialization
    // Note: In production, OTP and playbackInfo should come from backend
    var player = new VdoPlayer({
      container: document.getElementById("player"),
      video: "$videoId",
      autoplay: true,
    });
  </script>
</body>
</html>
''';

    _controller.loadHtmlString(html);
  }

  void _loadGenericPlayer() {
    final url = widget.streamData.playbackUrl;
    if (url == null) {
      widget.onError?.call('Invalid video URL');
      return;
    }

    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
