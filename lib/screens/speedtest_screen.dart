import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../theme/app_status_colors.dart';

/// Нативный тест скорости интернета. Замер через Cloudflare speed-эндпоинты
/// (download/upload) на чистом Dart http. Данные тарифа/сети — GET /account/speedtest_info.
class SpeedtestScreen extends StatefulWidget {
  const SpeedtestScreen({super.key});

  @override
  State<SpeedtestScreen> createState() => _SpeedtestScreenState();
}

enum _Phase { idle, ping, download, upload, done }

class _SpeedtestScreenState extends State<SpeedtestScreen> {
  // Данные о тарифе/сети
  bool _loadingInfo = true;
  String? _tariffName;
  num _tariffSpeed = 0;
  bool _inNetwork = false;
  bool _balanceBlocked = false;
  String _clientIp = '';

  // Состояние теста
  _Phase _phase = _Phase.idle;
  double _downMbit = 0, _upMbit = 0;
  int _pingMs = 0;
  double _gauge = 0; // текущее значение на круге

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInfo());
  }

  Future<void> _loadInfo() async {
    try {
      final api = context.read<AuthProvider>().api;
      final d = await api.get('/account/speedtest_info');
      if (!mounted) return;
      setState(() {
        _tariffName = d['tariff_name'];
        _tariffSpeed = (d['tariff_speed_mbit'] ?? 0) as num;
        _inNetwork = d['in_network'] == true;
        _balanceBlocked = d['balance_blocked'] == true;
        _clientIp = d['client_ip'] ?? '';
        _loadingInfo = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  bool get _testDisabled => _balanceBlocked;

  Future<void> _runTest() async {
    setState(() {
      _phase = _Phase.ping;
      _downMbit = 0;
      _upMbit = 0;
      _pingMs = 0;
      _gauge = 0;
    });
    try {
      // 1. Ping — медиана 5 быстрых запросов
      final pings = <int>[];
      for (var i = 0; i < 5; i++) {
        final sw = Stopwatch()..start();
        try {
          await http
              .get(Uri.parse('https://speed.cloudflare.com/__down?bytes=1000'))
              .timeout(const Duration(seconds: 5));
          sw.stop();
          pings.add(sw.elapsedMilliseconds);
        } catch (_) {}
      }
      if (pings.isNotEmpty) {
        pings.sort();
        _pingMs = pings[pings.length ~/ 2];
      }

      // 2. Download — 10 МБ
      if (!mounted) return;
      setState(() => _phase = _Phase.download);
      _downMbit = await _measureDownload(10 * 1024 * 1024);

      // 3. Upload — 5 МБ
      if (!mounted) return;
      setState(() => _phase = _Phase.upload);
      _upMbit = await _measureUpload(5 * 1024 * 1024);

      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _gauge = _downMbit;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  Future<double> _measureDownload(int bytes) async {
    final sw = Stopwatch()..start();
    final req = http.Request(
        'GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=$bytes'));
    final resp = await req.send().timeout(const Duration(seconds: 30));
    var received = 0;
    await for (final chunk in resp.stream) {
      received += chunk.length;
      final secs = sw.elapsedMilliseconds / 1000.0;
      if (secs > 0) {
        final mbit = (received * 8) / (secs * 1000000);
        if (mounted) setState(() => _gauge = mbit);
      }
    }
    sw.stop();
    final secs = sw.elapsedMilliseconds / 1000.0;
    return secs > 0 ? (received * 8) / (secs * 1000000) : 0;
  }

  Future<double> _measureUpload(int bytes) async {
    final payload = List<int>.filled(bytes, 0);
    final sw = Stopwatch()..start();
    try {
      await http
          .post(Uri.parse('https://speed.cloudflare.com/__up'), body: payload)
          .timeout(const Duration(seconds: 30));
    } catch (_) {}
    sw.stop();
    final secs = sw.elapsedMilliseconds / 1000.0;
    return secs > 0 ? (bytes * 8) / (secs * 1000000) : 0;
  }

  String get _phaseLabel {
    switch (_phase) {
      case _Phase.idle:
        return 'готов к тесту';
      case _Phase.ping:
        return 'пинг…';
      case _Phase.download:
        return 'скачивание…';
      case _Phase.upload:
        return 'загрузка…';
      case _Phase.done:
        return 'Мбит/с';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тест скорости интернета')),
      body: _loadingInfo
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _tariffHero(),
                if (!_inNetwork) ...[
                  const SizedBox(height: 12),
                  _warningExternal(),
                ],
                if (_balanceBlocked) ...[
                  const SizedBox(height: 12),
                  _warningBlocked(),
                ],
                const SizedBox(height: 20),
                _gaugeCard(),
              ],
            ),
    );
  }

  Widget _tariffHero() {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.bolt, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('ВАШ ТАРИФ',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text(_tariffName ?? '—',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            if (_tariffSpeed > 0) ...[
              const SizedBox(height: 12),
              Row(children: [
                _heroSpeed(Icons.arrow_downward, _tariffSpeed, 'скачивание'),
                const SizedBox(width: 28),
                _heroSpeed(Icons.arrow_upward, _tariffSpeed, 'отдача'),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroSpeed(IconData icon, num value, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$value',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold)),
                  const Text(' Мбит/с',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _warningExternal() {
    final st = AppStatusColors.of(context);
    return Card(
      color: st.warningContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.public, color: st.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Вы подключены не из сети оператора',
                  style: TextStyle(fontWeight: FontWeight.bold, color: st.onWarningContainer)),
              const SizedBox(height: 4),
              Text(
                'Ваш текущий IP $_clientIp не относится к нашей сети. Тест измерит '
                'скорость другого провайдера — не покажет реальную скорость вашего '
                'тарифа. Для корректного теста подключитесь к нашей сети напрямую.',
                style: TextStyle(color: st.onWarningContainer, fontSize: 13),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _warningBlocked() {
    final st = AppStatusColors.of(context);
    return Card(
      color: st.dangerContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(Icons.block, color: st.onDangerContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Услуги заблокированы (отрицательный баланс). '
                'Пополните счёт, чтобы тестировать скорость.',
                style: TextStyle(color: st.onDangerContainer)),
          ),
        ]),
      ),
    );
  }

  Widget _gaugeCard() {
    final cs = Theme.of(context).colorScheme;
    final running = _phase != _Phase.idle && _phase != _Phase.done;
    final gaugeValue = _phase == _Phase.done ? _downMbit : _gauge;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: running ? null : (gaugeValue > 0 ? 1 : 0),
                    strokeWidth: 8,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(gaugeValue > 0 ? gaugeValue.toStringAsFixed(1) : '0',
                      style: const TextStyle(
                          fontSize: 44, fontWeight: FontWeight.bold)),
                  Text(_phaseLabel,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            if (_phase == _Phase.done) _results(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_testDisabled || running) ? null : _runTest,
                icon: Icon(_testDisabled ? Icons.block : Icons.play_arrow),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: Text(_testDisabled
                    ? 'Тест недоступен'
                    : running
                        ? 'Идёт тест…'
                        : 'Начать тест'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Тест займёт около 30 секунд. Для точности закройте другие '
              'приложения, отключите VPN и тестируйте через провод (если есть).',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _resultItem(Icons.arrow_downward, _downMbit.toStringAsFixed(1), 'Мбит/с ↓',
            Theme.of(context).colorScheme.primary),
        _resultItem(Icons.arrow_upward, _upMbit.toStringAsFixed(1), 'Мбит/с ↑',
            AppStatusColors.of(context).warning),
        _resultItem(Icons.network_ping, '$_pingMs', 'мс пинг',
            Theme.of(context).colorScheme.secondary),
      ],
    );
  }

  Widget _resultItem(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: TextStyle(
              fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}
