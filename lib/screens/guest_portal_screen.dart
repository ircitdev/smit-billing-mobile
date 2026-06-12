import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Экран «Гостевой Wi-Fi» для абонента-турбазы (зеркало /lk/guest-portal/).
/// Три вкладки: Обзор (статус портала + KPI + ссылка), Рассылки (ДР-рассылка +
/// история + разовая рассылка), База (список гостей).
/// Источник: /mobile-api/v1/guest-portal/{overview,broadcasts,guests}.
class GuestPortalScreen extends StatefulWidget {
  const GuestPortalScreen({super.key});

  @override
  State<GuestPortalScreen> createState() => _GuestPortalScreenState();
}

class _GuestPortalScreenState extends State<GuestPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Гостевой Wi-Fi'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Гостевой Wi-Fi'),
            Tab(text: 'Рассылки'),
            Tab(text: 'База гостей'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OverviewTab(),
          _BroadcastsTab(),
          _GuestsTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вкладка «Гостевой Wi-Fi» — обзор
// ---------------------------------------------------------------------------

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final d = await api.get('/guest-portal/overview');
      if (!mounted) return;
      if (d is Map && d['available'] == true) {
        setState(() {
          _data = Map<String, dynamic>.from(d);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Гостевой портал недоступен';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final stats = (_data['stats'] as Map?) ?? {};
    final bdays = (_data['upcoming_bdays'] as List?) ?? [];
    final isLive = _data['is_live'] == true;
    final url = (_data['portal_url'] ?? '').toString();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // статус
          Card(
            color: isLive
                ? Colors.green.withValues(alpha: 0.10)
                : Colors.orange.withValues(alpha: 0.10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(isLive ? Icons.check_circle : Icons.settings,
                      color: isLive ? Colors.green : Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isLive
                          ? 'Портал активен и принимает гостей.'
                          : 'Портал в режиме настройки — утвердите текст согласия в Личном кабинете, чтобы начать сбор.',
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // KPI
          Row(children: [
            _kpi(cs, '${stats['total_guests'] ?? 0}', 'Всего гостей'),
            const SizedBox(width: 10),
            _kpi(cs, '${stats['new_month'] ?? 0}', 'За 30 дней'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _kpi(cs, '${stats['broadcasts'] ?? 0}', 'Рассылок'),
            const SizedBox(width: 10),
            _kpi(cs, '${stats['sms'] ?? 0}', 'Отправлено SMS'),
          ]),
          const SizedBox(height: 18),

          // ссылка на портал
          Text('Ссылка на портал',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: cs.primary)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.qr_code_2, color: cs.primary),
              title: Text(url, style: const TextStyle(fontSize: 13)),
              subtitle: const Text(
                  'Гость открывает её при подключении к Wi-Fi или по QR-коду'),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Скопировать',
                onPressed: url.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ссылка скопирована')));
                      },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ближайшие ДР
          if (bdays.isNotEmpty) ...[
            Text('Скоро дни рождения',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.primary)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final b in bdays)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.cake_outlined, size: 20),
                      title: Text((b as Map)['phone']?.toString() ?? ''),
                      trailing: Text(b['date']?.toString() ?? '',
                          style: TextStyle(color: cs.outline)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // подсказка про настройку в ЛК
          Card(
            color: cs.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.info_outline, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Анкета, брендинг, текст согласия и свой домен настраиваются в Личном кабинете на сайте.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(ColorScheme cs, String num, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Text(num,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: cs.primary)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вкладка «Рассылки»
// ---------------------------------------------------------------------------

class _BroadcastsTab extends StatefulWidget {
  const _BroadcastsTab();

  @override
  State<_BroadcastsTab> createState() => _BroadcastsTabState();
}

class _BroadcastsTabState extends State<_BroadcastsTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final d = await api.get('/guest-portal/broadcasts');
      if (!mounted) return;
      if (d is Map && d['available'] == true) {
        setState(() {
          _data = Map<String, dynamic>.from(d);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Раздел недоступен';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить';
        _loading = false;
      });
    }
  }

  Future<void> _openManualSheet() async {
    final isLive = _data['is_live'] == true;
    if (!isLive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Портал не активирован — рассылка запрещена. Утвердите согласие в ЛК.')));
      return;
    }
    final textCtrl = TextEditingController();
    String channel = 'sms';
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Разовая рассылка гостям',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Отправится гостям с согласием на рекламу. {name}, {turbaza} — подстановки.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.outline)),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sms', label: Text('SMS')),
                  ButtonSegment(value: 'email', label: Text('Email')),
                ],
                selected: {channel},
                onSelectionChanged: (s) => setSt(() => channel = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Текст рассылки…',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Отправить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (sent != true || !mounted) return;
    final text = textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = context.read<AuthProvider>().api;
      final d = await api.post('/guest-portal/broadcasts/run',
          {'channel': channel, 'template_text': text});
      if (d['ok'] == true) {
        final st = (d['stats'] as Map?) ?? {};
        messenger.showSnackBar(SnackBar(
            content: Text('Отправлено: ${st['sent'] ?? st['ok'] ?? '—'}')));
        await _load();
      } else {
        messenger.showSnackBar(
            SnackBar(content: Text(d['error']?.toString() ?? 'Ошибка рассылки')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Ошибка рассылки')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final bday = (_data['birthday'] as Map?) ?? {};
    final stats = (_data['stats'] as Map?) ?? {};
    final campaigns = (_data['campaigns'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ДР-рассылка статус
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.cake, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Поздравления с ДР',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Chip(
                      label: Text(bday['enabled'] == true ? 'Вкл' : 'Выкл'),
                      backgroundColor: bday['enabled'] == true
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      visualDensity: VisualDensity.compact,
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'За ${bday['days_before'] ?? 3} дн. до ДР · канал ${(bday['channel'] ?? 'sms').toString().toUpperCase()}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  if ((bday['template_text'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('«${bday['template_text']}»',
                        style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: cs.outline)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Гостей с ДР: ${stats['with_bday'] ?? 0} · с согласием: ${stats['reachable'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // кнопка разовой рассылки
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _openManualSheet,
              icon: const Icon(Icons.send),
              label: const Text('Разовая рассылка'),
            ),
          ),
          const SizedBox(height: 18),

          // история кампаний
          Text('История рассылок',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: cs.primary)),
          const SizedBox(height: 8),
          if (campaigns.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text('Рассылок ещё не было',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ),
            )
          else
            for (final c in campaigns) _campaignCard(c as Map, cs),
        ],
      ),
    );
  }

  Widget _campaignCard(Map c, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(c['name']?.toString() ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5)),
              ),
              Text(c['date']?.toString() ?? '',
                  style: TextStyle(fontSize: 12, color: cs.outline)),
            ]),
            const SizedBox(height: 4),
            if ((c['text'] ?? '').toString().isNotEmpty)
              Text(c['text'].toString(),
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Chip(
                label: Text(c['channel']?.toString() ?? ''),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 15, color: Colors.green),
              const SizedBox(width: 3),
              Text('${c['sent'] ?? 0}', style: const TextStyle(fontSize: 12)),
              if ((c['failed'] ?? 0) != 0) ...[
                const SizedBox(width: 10),
                const Icon(Icons.error_outline, size: 15, color: Colors.red),
                const SizedBox(width: 3),
                Text('${c['failed']}', style: const TextStyle(fontSize: 12)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вкладка «База гостей»
// ---------------------------------------------------------------------------

class _GuestsTab extends StatefulWidget {
  const _GuestsTab();

  @override
  State<_GuestsTab> createState() => _GuestsTabState();
}

class _GuestsTabState extends State<_GuestsTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<dynamic> _rows = [];
  String _period = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final d = await api.get('/guest-portal/guests?period=$_period');
      if (!mounted) return;
      if (d is Map && d['available'] == true) {
        setState(() {
          _rows = (d['rows'] as List?) ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Раздел недоступен';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Все')),
                ButtonSegment(value: 'month', label: Text('За 30 дней')),
              ],
              selected: {_period},
              onSelectionChanged: (s) {
                setState(() => _period = s.first);
                _load();
              },
            ),
            const Spacer(),
            Text('${_rows.length}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.primary)),
            Text(' гост.', style: TextStyle(color: cs.outline)),
          ]),
        ),
        Expanded(
          child: _rows.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Icon(Icons.people_outline,
                          size: 52, color: cs.outline),
                    ),
                    const SizedBox(height: 10),
                    Center(
                        child: Text('Гостей пока нет',
                            style: TextStyle(color: cs.onSurfaceVariant))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final g = _rows[i] as Map;
                      final name = (g['name'] ?? '').toString();
                      final email = (g['email'] ?? '').toString();
                      final bday = (g['birthday'] ?? '').toString();
                      final sub = <String>[
                        if (email.isNotEmpty) email,
                        if (bday.isNotEmpty) 'ДР $bday',
                        'визитов ${g['visits'] ?? 0}',
                      ].join(' · ');
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.person,
                              color: cs.primary, size: 20),
                        ),
                        title: Text(
                            name.isNotEmpty
                                ? name
                                : (g['phone']?.toString() ?? ''),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          name.isNotEmpty
                              ? '${g['phone']} · $sub'
                              : sub,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                            (g['first_seen'] ?? '').toString().split(' ').first,
                            style: TextStyle(fontSize: 11, color: cs.outline)),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
