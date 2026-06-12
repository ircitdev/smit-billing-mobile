import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_state.dart'; // build 1039: единый ErrorState
import 'video_screen.dart';
import 'iptv_screen.dart';
import 'guest_portal_screen.dart';
import 'services_tab.dart';
import 'sessions_screen.dart';
import 'speedtest_screen.dart';

/// Вкладка «Услуги» нижней панели. Показывает доступные абоненту разделы
/// (по флагам видимости из /account/services_menu), как слайд-меню в ЛК.
class ServicesHubTab extends StatefulWidget {
  const ServicesHubTab({super.key});

  @override
  State<ServicesHubTab> createState() => _ServicesHubTabState();
}

class _ServicesHubTabState extends State<ServicesHubTab> {
  bool _loading = true;
  bool _error = false; // build 1039: отличаем «нет услуг» от «сеть упала»
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false; // build 1039: сброс ошибки перед загрузкой
    });
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.get('/account/services_menu');
      if (!mounted) return;
      setState(() {
        _items = ((data['items'] ?? []) as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e['visible'] == true)
            .toList();
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      // build 1039: показываем ErrorState с retry вместо пустого состояния
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _open(String key) {
    Widget? screen;
    switch (key) {
      case 'guest_portal':
        screen = const GuestPortalScreen();
        break;
      case 'video':
        screen = const VideoScreen();
        break;
      case 'iptv':
        screen = const IptvScreen();
        break;
      case 'services':
        screen = const ServicesTab();
        break;
      case 'sessions':
        screen = const SessionsScreen();
        break;
      case 'speedtest':
        screen = const SpeedtestScreen();
        break;
    }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  static const _meta = {
    'guest_portal': (Icons.wifi, 'Гостевой Wi-Fi', 'Гости, рассылки, база'),
    'video': (Icons.videocam, 'Видеонаблюдение', 'Камеры, подписки, видео-счёт'),
    'iptv': (Icons.live_tv, 'Интерактивное ТВ', 'Пакеты каналов и просмотр'),
    'services': (Icons.layers_outlined, 'Дополнительные услуги', 'Тарифы и подключённые услуги'),
    'sessions': (Icons.wifi, 'Подключения', 'История сессий и трафик'),
    'speedtest': (Icons.speed, 'Тест скорости', 'Измерить скорость интернета'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Услуги')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            // build 1039: сеть упала → ErrorState с retry (не пустое состояние)
            : _error
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: ErrorState(
                          message: 'Не удалось загрузить услуги',
                          onRetry: _load,
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 160),
                    Center(
                      child: Icon(Icons.grid_view_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('Доступных услуг нет',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildGrouped(context),
                  ),
      ),
    );
  }

  /// Группировка пунктов: «Мои услуги» (видео, доп.услуги) и
  /// «Диагностика» (подключения, тест скорости).
  List<Widget> _buildGrouped(BuildContext context) {
    const servicesKeys = {'guest_portal', 'video', 'iptv', 'services'};
    const diagKeys = {'sessions', 'speedtest'};

    Widget? cardFor(String key) {
      final item = _items.firstWhere(
        (e) => e['key'] == key,
        orElse: () => const {},
      );
      if (item.isEmpty) return null;
      final m = _meta[key];
      if (m == null) return null;
      final count = item['count'] as int?;
      return _ServiceCard(
        icon: m.$1,
        title: m.$2,
        subtitle: m.$3,
        badge: (count != null && count > 0) ? '$count' : null,
        onTap: () => _open(key),
      );
    }

    final out = <Widget>[];
    final svc = servicesKeys.map(cardFor).whereType<Widget>().toList();
    final diag = diagKeys.map(cardFor).whereType<Widget>().toList();

    if (svc.isNotEmpty) {
      out.add(_sectionHeader(context, 'Мои услуги'));
      out.addAll(svc);
    }
    if (diag.isNotEmpty) {
      if (out.isNotEmpty) out.add(const SizedBox(height: 8));
      out.add(_sectionHeader(context, 'Диагностика'));
      out.addAll(diag);
    }
    return out;
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(badge!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}
