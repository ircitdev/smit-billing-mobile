import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'video_screen.dart';
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
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _open(String key) {
    Widget? screen;
    switch (key) {
      case 'video':
        screen = const VideoScreen();
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
    'video': (Icons.videocam, 'Видеонаблюдение', 'Камеры, подписки, видео-счёт'),
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
                              color: Theme.of(context).colorScheme.outline)),
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _items.map((item) {
                      final key = item['key'] as String;
                      final m = _meta[key];
                      if (m == null) return const SizedBox.shrink();
                      final count = item['count'] as int?;
                      return _ServiceCard(
                        icon: m.$1,
                        title: m.$2,
                        subtitle: m.$3,
                        badge: (count != null && count > 0) ? '$count' : null,
                        onTap: () => _open(key),
                      );
                    }).toList(),
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
                        style: TextStyle(color: cs.outline, fontSize: 13)),
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
