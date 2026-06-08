import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Просмотр видеопотока камеры через go2rtc (MSE/WebRTC-плеер в WebView).
/// [streamUrl] — URL вида https://rbill.smit34.ru/go2rtc/stream.html?src=cam_NN&media=mse
class VideoPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = true;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.streamUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const CircularProgressIndicator(color: Colors.white),
          if (_error)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off, color: Colors.white54, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Не удалось загрузить видео',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      setState(() {
                        _error = false;
                        _loading = true;
                      });
                      _controller.loadRequest(Uri.parse(widget.streamUrl));
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
