import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_status_colors.dart';

/// История подключений (RADIUS-сессии). Источник: GET /account/sessions.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];
  int _total = 0, _active = 0;
  int _inBytes = 0, _outBytes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.get('/account/sessions');
      if (!mounted) return;
      setState(() {
        _sessions = ((data['items'] ?? []) as List).cast<Map<String, dynamic>>();
        _total = data['total_count'] ?? 0;
        _active = data['active_count'] ?? 0;
        _inBytes = data['total_in_bytes'] ?? 0;
        _outBytes = data['total_out_bytes'] ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить данные';
      });
    }
  }

  static String _fmtBytes(int b) {
    if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1)} ГБ';
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} МБ';
    if (b >= 1 << 10) return '${(b / (1 << 10)).toStringAsFixed(1)} КБ';
    return '$b Б';
  }

  static String _fmtDuration(int sec) {
    if (sec <= 0) return '';
    final d = sec ~/ 86400;
    final h = (sec % 86400) ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (d > 0) return '$d д $h ч';
    if (h > 0) return '$h ч $m мин';
    return '$m мин';
  }

  static String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      String p(int n) => n.toString().padLeft(2, '0');
      return '${p(dt.day)}.${p(dt.month)}.${dt.year}  ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История подключений')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final st = AppStatusColors.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 160),
        Center(child: Icon(Icons.cloud_off, size: 56, color: cs.outline)),
        const SizedBox(height: 12),
        Center(child: Text(_error!)),
        const SizedBox(height: 16),
        Center(child: FilledButton.tonal(onPressed: _load, child: const Text('Повторить'))),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI 2x2
        Row(children: [
          Expanded(child: _kpi(Icons.format_list_numbered, 'Всего сессий', '$_total', cs.primary)),
          const SizedBox(width: 12),
          Expanded(child: _kpi(Icons.fiber_manual_record, 'Активных сейчас', '$_active', st.success)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kpi(Icons.arrow_downward, 'Скачано', _fmtBytes(_inBytes), cs.primary)),
          const SizedBox(width: 12),
          Expanded(child: _kpi(Icons.arrow_upward, 'Загружено', _fmtBytes(_outBytes), st.warning)),
        ]),
        const SizedBox(height: 16),
        if (_sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('Сессий пока нет',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          )
        else
          ..._sessions.map(_sessionCard),
      ],
    );
  }

  Widget _kpi(IconData icon, String label, String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      maxLines: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final cs = Theme.of(context).colorScheme;
    final st = AppStatusColors.of(context);
    final active = s['is_active'] == true;
    final inB = s['in_bytes'] as int? ?? 0;
    final outB = s['out_bytes'] as int? ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: active
            ? BorderSide(color: st.success.withValues(alpha: 0.6), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_fmtDate(s['start']),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: st.successContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fiber_manual_record, size: 10, color: st.onSuccessContainer),
                      const SizedBox(width: 4),
                      Text('онлайн',
                          style: TextStyle(fontSize: 12, color: st.onSuccessContainer)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.access_time, size: 15, color: cs.outline),
              const SizedBox(width: 4),
              Text(_fmtDuration(s['duration_sec'] ?? 0),
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const Spacer(),
              Icon(Icons.arrow_downward, size: 14, color: cs.primary),
              Text(' ${_fmtBytes(inB)}',
                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_upward, size: 14, color: st.warning),
              Text(' ${_fmtBytes(outB)}',
                  style: TextStyle(color: st.warning, fontWeight: FontWeight.w600)),
            ]),
            if ((s['ip'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.lan_outlined, size: 15, color: cs.outline),
                const SizedBox(width: 4),
                Text(s['ip'], style: TextStyle(color: cs.onSurfaceVariant)),
                if (s['vlan'] != null) ...[
                  const SizedBox(width: 12),
                  Text('VLAN ${s['vlan']}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
                if ((s['end_reason'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(s['end_reason'],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
