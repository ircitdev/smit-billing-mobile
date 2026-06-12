import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../providers/auth_provider.dart';

/// Экран «Интерактивное ТВ» (build 1079).
/// Витрина пакетов + текущий пакет + заказ/переход + встроенный плеер
/// (если абонент в сети СмИТ и IPTV активно). Источник: /mobile-api/v1/iptv/packages.
class IptvScreen extends StatefulWidget {
  const IptvScreen({super.key});

  @override
  State<IptvScreen> createState() => _IptvScreenState();
}

class _IptvScreenState extends State<IptvScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  bool _busy = false;

  VideoPlayerController? _player;
  bool _playerLoading = false;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthProvider>().api;
      final d = await api.get('/iptv/packages');
      if (d is Map && d['available'] == true) {
        setState(() { _data = Map<String, dynamic>.from(d); _loading = false; });
        _maybeInitPlayer();
      } else {
        setState(() { _error = 'Раздел ТВ недоступен'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Не удалось загрузить'; _loading = false; });
    }
  }

  void _maybeInitPlayer() {
    final watch = (_data['watch'] as Map?) ?? {};
    final url = (watch['playlist_url'] ?? '').toString();
    if (watch['can_watch'] == true && url.isNotEmpty) {
      _initPlayer(url);
    }
  }

  Future<void> _initPlayer(String url) async {
    setState(() { _playerLoading = true; _playerError = null; });
    await _player?.dispose();
    _player = null;
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _player = c;
      await c.initialize();
      await c.play();
      if (mounted) setState(() => _playerLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() { _playerLoading = false; _playerError = 'Поток недоступен'; });
      }
    }
  }

  Future<void> _connect(int uslugaId, bool isSwitch) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = context.read<AuthProvider>().api;
      final d = await api.post('/iptv/connect', {'usluga_id': uslugaId});
      if (d['ok'] == true) {
        messenger.showSnackBar(SnackBar(
            content: Text(isSwitch ? 'Пакет изменён' : 'Пакет подключён')));
        await _load();
      } else {
        messenger.showSnackBar(SnackBar(
            content: Text(d['error']?.toString() ?? 'Ошибка подключения')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Ошибка подключения')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отключить ТВ?'),
        content: const Text('Просмотр телевидения прекратится.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Отключить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AuthProvider>().api;
    try {
      final d = await api.post('/iptv/disconnect', {});
      if (d['ok'] == true) {
        messenger.showSnackBar(const SnackBar(content: Text('ТВ отключено')));
        await _load();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(d['error']?.toString() ?? 'Ошибка')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Ошибка')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text((_data['title'] ?? 'Интерактивное ТВ').toString())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildBody(cs),
                  ),
                ),
    );
  }

  List<Widget> _buildBody(ColorScheme cs) {
    final out = <Widget>[];
    final current = _data['current'] as Map?;
    final watch = (_data['watch'] as Map?) ?? {};
    final packages = (_data['items'] as List?) ?? [];
    final hasInternet = _data['has_internet'] == true;
    final subtitle = (_data['subtitle'] ?? '').toString();

    if (subtitle.isNotEmpty) {
      out.add(Text(subtitle, style: TextStyle(color: cs.outline)));
      out.add(const SizedBox(height: 14));
    }

    // текущий пакет
    if (current != null) {
      out.add(Card(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        child: ListTile(
          leading: Icon(Icons.live_tv, color: cs.primary),
          title: Text('Текущий пакет: ${current['name']}'),
          subtitle: current['price'] != null
              ? Text('${(current['price'] as num).toStringAsFixed(0)} ₽/мес')
              : null,
          trailing: TextButton(
            onPressed: _busy ? null : _disconnect,
            child: const Text('Отключить'),
          ),
        ),
      ));
      out.add(const SizedBox(height: 12));

      // плеер просмотра
      if (watch['can_watch'] == true) {
        out.add(_buildPlayer(cs));
        out.add(const SizedBox(height: 16));
      } else if (watch['watch_enabled'] == true) {
        out.add(_watchOff(watch, cs));
        out.add(const SizedBox(height: 16));
      }
    }

    // витрина пакетов
    out.add(Text(current != null ? 'Сменить тариф' : 'Тарифы и цены',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
    out.add(const SizedBox(height: 10));

    if (!hasInternet) {
      out.add(Card(
        color: Colors.orange.withValues(alpha: 0.1),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Интерактивное ТВ доступно только в пакете с интернетом.'),
        ),
      ));
      out.add(const SizedBox(height: 10));
    }

    for (final p in packages) {
      final pm = p as Map;
      final isCurrent = pm['is_current'] == true;
      out.add(Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCurrent ? cs.primary : cs.outlineVariant,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: ListTile(
          title: Text(pm['name']?.toString() ?? ''),
          subtitle: (pm['subtitle'] ?? '').toString().isNotEmpty
              ? Text(pm['subtitle'].toString())
              : null,
          trailing: isCurrent
              ? Chip(label: const Text('Подключён'), backgroundColor: cs.primaryContainer)
              : FilledButton(
                  onPressed: (_busy || !hasInternet)
                      ? null
                      : () => _connect(pm['id'] as int, current != null),
                  child: Text('${(pm['price_rub'] ?? pm['price'] ?? 0)} ₽'),
                ),
        ),
      ));
      out.add(const SizedBox(height: 8));
    }
    return out;
  }

  Widget _buildPlayer(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.play_circle, color: cs.primary, size: 20),
          const SizedBox(width: 6),
          const Text('Смотреть ТВ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.antiAlias,
            child: _playerLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _playerError != null
                    ? Center(child: Text(_playerError!, style: const TextStyle(color: Colors.white70)))
                    : (_player != null && _player!.value.isInitialized)
                        ? Stack(alignment: Alignment.bottomCenter, children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: _player!.value.aspectRatio == 0 ? 16 / 9 : _player!.value.aspectRatio,
                                child: VideoPlayer(_player!),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() =>
                                  _player!.value.isPlaying ? _player!.pause() : _player!.play()),
                              child: AnimatedOpacity(
                                opacity: _player!.value.isPlaying ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  color: Colors.black26,
                                  child: const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 56)),
                                ),
                              ),
                            ),
                          ])
                        : const Center(child: Icon(Icons.tv, color: Colors.white38, size: 44)),
          ),
        ),
        const SizedBox(height: 6),
        Text('Прямой эфир каналов вашего пакета. Доступно в сети СмИТ.',
            style: TextStyle(fontSize: 12, color: cs.outline)),
      ],
    );
  }

  Widget _watchOff(Map watch, ColorScheme cs) {
    final reason = (watch['reason'] ?? '').toString();
    String text;
    if (reason == 'offline') {
      text = 'Просмотр доступен только в сети СмИТ (подключитесь к интернету СмИТ).';
    } else if (reason == 'no_playlist') {
      text = 'Плеер каналов настраивается.';
    } else {
      text = 'Просмотр временно недоступен.';
    }
    final appUrl = (watch['app_url'] ?? '').toString();
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.info_outline, color: cs.outline, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          if (appUrl.isNotEmpty)
            TextButton(onPressed: () {}, child: const Text('Приложение')),
        ]),
      ),
    );
  }
}
