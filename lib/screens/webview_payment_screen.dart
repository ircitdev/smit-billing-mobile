import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app WebView screen for YooKassa / W1 payments.
///
/// Accepts either:
/// - [url] — REST API v3 redirect URL (direct load)
/// - [formAction] + [formFields] — HTTP protocol (auto-submit form via JS)
///
/// Returns `true` via Navigator.pop when payment succeeds.
class WebViewPaymentScreen extends StatefulWidget {
  final String? url;
  final String? formAction;
  final Map<String, String>? formFields;

  const WebViewPaymentScreen({
    super.key,
    this.url,
    this.formAction,
    this.formFields,
  });

  @override
  State<WebViewPaymentScreen> createState() => _WebViewPaymentScreenState();
}

class _WebViewPaymentScreenState extends State<WebViewPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;
  String _title = 'Оплата';

  // Success URL patterns — payment completed
  static const _successPatterns = [
    '/lk/payments/result',
    'payment-success',
    'paymentAviso',
  ];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (url) {
          if (mounted) {
            setState(() => _isLoading = false);
            _controller.getTitle().then((t) {
              if (t != null && t.isNotEmpty && mounted) {
                setState(() => _title = t);
              }
            });
          }
          // Check for success URL
          if (_isSuccessUrl(url)) {
            _onPaymentSuccess();
          }
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onNavigationRequest: (request) {
          // Allow all HTTPS navigation
          return NavigationDecision.navigate;
        },
      ));

    _loadPayment();
  }

  void _loadPayment() {
    if (widget.url != null) {
      // REST API v3 — direct redirect
      _controller.loadRequest(Uri.parse(widget.url!));
    } else if (widget.formAction != null && widget.formFields != null) {
      // HTTP protocol — load a self-submitting HTML form
      final html = _buildFormHtml(widget.formAction!, widget.formFields!);
      _controller.loadHtmlString(html);
    }
  }

  bool _isSuccessUrl(String url) {
    final lower = url.toLowerCase();
    return _successPatterns.any((p) => lower.contains(p));
  }

  void _onPaymentSuccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Оплата прошла успешно!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop(true);
  }

  /// Build self-submitting HTML form for HTTP protocol payments.
  String _buildFormHtml(String action, Map<String, String> fields) {
    final inputs = fields.entries
        .map((e) =>
            '<input type="hidden" name="${_escapeHtml(e.key)}" value="${_escapeHtml(e.value)}">')
        .join('\n');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      background: #f5f5f5;
      color: #333;
    }
    .loader { text-align: center; }
    .spinner {
      width: 40px; height: 40px; margin: 0 auto 16px;
      border: 3px solid #e0e0e0;
      border-top: 3px solid #5BA89D;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="loader">
    <div class="spinner"></div>
    <div>Переход к оплате...</div>
  </div>
  <form id="payForm" method="POST" action="$action">
    $inputs
  </form>
  <script>document.getElementById('payForm').submit();</script>
</body>
</html>
''';
  }

  String _escapeHtml(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          if (context.mounted) Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: Column(
          children: [
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress / 100.0 : null,
                minHeight: 3,
              ),
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
