import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Игра с сервера (оболочка SmitGame) во весь экран.
///
/// Адрес с одноразовым токеном выдаёт `POST /game/web-url`; счёт такой партии
/// пересчитывает сервер — только такие результаты идут в «Игру месяца».
class WebGameScreen extends StatefulWidget {
  final String url;
  final String title;
  const WebGameScreen({super.key, required this.url, required this.title});

  @override
  State<WebGameScreen> createState() => _WebGameScreenState();
}

class _WebGameScreenState extends State<WebGameScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  static const _bg = Color(0xFF0A1418);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_bg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame == true && mounted) {
            setState(() { _loading = false; _failed = true; });
          }
        },
        // Только сама игра; любые другие ссылки не открываем внутри
        onNavigationRequest: (r) {
          final u = Uri.parse(r.url);
          final own = Uri.parse(widget.url);
          return u.host == own.host && u.path.startsWith('/lk/games/app/')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Stack(children: [
          if (!_failed) WebViewWidget(controller: _controller),
          if (_failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off, color: Color(0xFF5BA89D), size: 48),
                  const SizedBox(height: 12),
                  const Text('Не удалось открыть игру. Проверьте интернет и попробуйте ещё раз.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5BA89D)),
                    onPressed: () {
                      setState(() { _failed = false; _loading = true; });
                      _controller.loadRequest(Uri.parse(widget.url));
                    },
                    child: const Text('Повторить'),
                  ),
                ]),
              ),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF5BA89D))),
        ]),
      ),
    );
  }
}
