import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_event.dart';
import '../models/video_object.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'video_events_screen.dart';

/// События камеры: что ловить, что делать, когда, детектор в камере, последние события.
/// Тот же смысл, что вкладка «События» в настройках камеры ЛК.
/// Источник: GET/POST /mobile-api/v1/video/cameras/<id>/events
class CameraEventsScreen extends StatefulWidget {
  final VideoObjectModel object;
  final VideoCameraModel camera;
  /// Встроен во вкладку «События» экрана настроек камеры — без своей шапки.
  final bool embedded;

  const CameraEventsScreen({super.key, required this.object, required this.camera, this.embedded = false});

  @override
  State<CameraEventsScreen> createState() => _CameraEventsScreenState();
}

const _presets = [
  ['all', 'Круглосуточно', '', ''],
  ['night', 'Ночью 22–07', '22:00', '07:00'],
  ['day', 'Днём 08–20', '08:00', '20:00'],
];

class _CameraEventsScreenState extends State<CameraEventsScreen> {
  Map<String, dynamic>? _st;
  Map<String, dynamic> _rule = {};
  String? _error;
  String? _token;
  bool _saving = false;

  ApiClient get _api => context.read<AuthProvider>().api;
  String get _url => '/video/cameras/${widget.camera.id}/events';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final d = await _api.get(_url);
      _token = await _api.accessTokenForMedia(); // после запроса — токен мог обновиться
      if (!mounted) return;
      if (d['ok'] != true) {
        setState(() => _error = d['error']?.toString() ?? 'Камера недоступна');
        return;
      }
      setState(() {
        _st = Map<String, dynamic>.from(d);
        _rule = Map<String, dynamic>.from(d['rule'] ?? {});
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить настройки');
    }
  }

  void _toast(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 2)));

  Future<void> _save() async {
    final labels = List<String>.from(_rule['labels'] ?? []);
    if (_st?['enabled'] == true && labels.isEmpty) {
      _toast('Отметьте, какие события ловить');
      return;
    }
    setState(() => _saving = true);
    try {
      final d = await _api.post(_url, {
        'enabled': _st?['enabled'] == true,
        'labels': labels,
        'telegram': _rule['telegram'] == true,
        'push': _rule['push'] == true,
        'alarm': _rule['alarm'] == true,
        'say': _rule['say'] == true,
        'phrase': _rule['phrase'] ?? 'notice',
        'siren': _rule['siren'] == true,
        'time_from': _rule['time_from'] ?? '',
        'time_to': _rule['time_to'] ?? '',
      });
      if (d['ok'] == true && mounted) {
        setState(() {
          _st = Map<String, dynamic>.from(d);
          _rule = Map<String, dynamic>.from(d['rule'] ?? {});
        });
        _toast('Сохранено');
      } else {
        _toast(d['error']?.toString() ?? 'Не сохранилось');
      }
    } catch (_) {
      _toast('Ошибка связи');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDetector(String key, dynamic value) async {
    try {
      final d = await _api.post(_url, {'detector': {key: value}});
      _toast(d['ok'] == true ? 'Сохранено в камере' : (d['error']?.toString() ?? 'Камера не приняла настройку'));
      if (d['ok'] == true && mounted) setState(() => _st = Map<String, dynamic>.from(d));
    } catch (_) {
      _toast('Ошибка связи');
    }
  }

  String get _preset {
    final f = _rule['time_from'] ?? '', t = _rule['time_to'] ?? '';
    for (final p in _presets) {
      if (p[2] == f && p[3] == t) return p[0];
    }
    return 'custom';
  }

  Future<void> _pickTime(String key) async {
    final cur = (_rule[key] ?? '') as String;
    final parts = cur.split(':');
    final init = parts.length == 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 22, minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 22, minute: 0);
    final t = await showTimePicker(context: context, initialTime: init);
    if (t == null) return;
    setState(() => _rule[key] =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final content = _error != null
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
        : _st == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _load, child: _body());
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text('События · ${widget.camera.label}')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : _st == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          ...children,
        ]),
      ),
    );
  }

  Widget _body() {
    final st = _st!;
    final cs = Theme.of(context).colorScheme;
    final off = st['direct'] != true;
    final voiceOff = off || st['has_speaker'] != true;
    final labels = List<String>.from(_rule['labels'] ?? []);
    final events = ((st['events'] ?? []) as List)
        .map((e) => VideoEventModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final det = st['detector'] is Map ? Map<String, dynamic>.from(st['detector']) : null;

    Widget actSwitch(String key, IconData icon, String label, {bool disabled = false, String? hint}) => SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: disabled ? cs.outline : cs.primary),
          title: Text(label),
          subtitle: hint != null ? Text(hint) : null,
          value: _rule[key] == true,
          onChanged: disabled
              ? null
              : (v) {
                  setState(() => _rule[key] = v);
                  _save();
                },
        );

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        if (off && (st['note'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(st['note'], style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SwitchListTile(
            title: const Text('Принимать события камеры', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Камера сама распознаёт движение, человека и саботаж'),
            value: st['enabled'] == true,
            onChanged: off
                ? null
                : (v) {
                    setState(() => _st!['enabled'] = v);
                    _save();
                  },
          ),
        ),
        _section('Что ловить', Icons.center_focus_strong, [
          Wrap(
            spacing: 6,
            children: ((st['labels'] ?? []) as List).map((l) {
              final code = l['code'] as String;
              final avail = l['available'] == true && !off;
              return FilterChip(
                showCheckmark: false,
                avatar: Icon(_labelIconOf(code), size: 16),
                label: Text(l['name'] ?? code),
                selected: labels.contains(code),
                onSelected: avail
                    ? (sel) {
                        setState(() {
                          final next = List<String>.from(labels);
                          sel ? next.add(code) : next.remove(code);
                          _rule['labels'] = next;
                        });
                        _save();
                      }
                    : null,
              );
            }).toList(),
          ),
          if (st['labels_known'] != true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Камера не сообщила список своих событий — доступно всё.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
        ]),
        _section('Что делать', Icons.bolt, [
          actSwitch('telegram', Icons.send, 'Telegram с кадром', disabled: off),
          actSwitch('push', Icons.notifications_active_outlined, 'Push в приложение', disabled: off),
          actSwitch('alarm', Icons.warning_amber, 'Пометить тревогой', disabled: off),
          actSwitch('say', Icons.campaign_outlined, 'Фраза в динамик',
              disabled: voiceOff, hint: voiceOff ? 'У камеры нет динамика' : null),
          if (_rule['say'] == true && !voiceOff)
            DropdownButtonFormField<String>(
              initialValue: _rule['phrase'] ?? 'notice',
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: ((st['phrases'] ?? []) as List)
                  .map((p) => DropdownMenuItem<String>(value: p['code'], child: Text(p['text'] ?? '', overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                setState(() => _rule['phrase'] = v);
                _save();
              },
            ),
          actSwitch('siren', Icons.notifications, 'Сирена',
              disabled: voiceOff, hint: voiceOff ? 'У камеры нет динамика' : null),
        ]),
        _section('Когда', Icons.schedule, [
          Wrap(spacing: 6, children: [
            ..._presets.map((p) => ChoiceChip(
                  label: Text(p[1]),
                  selected: _preset == p[0],
                  onSelected: off
                      ? null
                      : (_) {
                          setState(() {
                            _rule['time_from'] = p[2];
                            _rule['time_to'] = p[3];
                          });
                          _save();
                        },
                )),
            ChoiceChip(
              label: const Text('Своё время'),
              selected: _preset == 'custom',
              onSelected: off ? null : (_) => _pickTime('time_from'),
            ),
          ]),
          if (_preset == 'custom')
            Row(children: [
              TextButton(onPressed: () => _pickTime('time_from'), child: Text('с ${_rule['time_from'] ?? '--:--'}')),
              TextButton(onPressed: () => _pickTime('time_to'), child: Text('по ${_rule['time_to'] ?? '--:--'}')),
            ]),
          Text('Уведомление — не чаще раза в 5 минут на тип события, до 50 в сутки.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        if (det != null && (det['motion'] != null || det['human'] != null || det['sound'] != null || det['tamper'] != null))
          Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ExpansionTile(
              leading: Icon(Icons.tune, color: cs.primary),
              title: const Text('Детектор в камере', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Чувствительность, распознавание человека'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              children: [
                if (det['motion'] != null)
                  _DetSlider(
                      label: 'Чувствительность к движению',
                      hint: 'Ниже — меньше ложных событий от теней и листвы',
                      value: (det['motion']['sensitivity'] as num).toDouble(),
                      onDone: (v) => _saveDetector('motion_sensitivity', v.round())),
                if (det['human'] != null) ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Распознавать человека'),
                    value: det['human']['enabled'] == true,
                    onChanged: (v) {
                      setState(() => det['human']['enabled'] = v);
                      _saveDetector('human_enabled', v);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: '${det['human']['sensitivity']}',
                    decoration: const InputDecoration(labelText: 'Чувствительность', border: OutlineInputBorder(), isDense: true),
                    items: ((det['human_levels'] ?? []) as List)
                        .map((l) => DropdownMenuItem<String>(value: '${l['code']}', child: Text(l['name'] ?? '')))
                        .toList(),
                    onChanged: (v) => _saveDetector('human_sensitivity', v),
                  ),
                  const SizedBox(height: 8),
                ],
                if (det['sound'] != null) ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Детектор громкого звука'),
                    value: det['sound']['enabled'] == true,
                    onChanged: (v) {
                      setState(() => det['sound']['enabled'] = v);
                      _saveDetector('sound_enabled', v);
                    },
                  ),
                  _DetSlider(
                      label: 'Порог громкости',
                      hint: 'Выше — нужен звук громче',
                      value: (det['sound']['threshold'] as num).toDouble(),
                      onDone: (v) => _saveDetector('sound_threshold', v.round())),
                ],
                if (det['tamper'] != null)
                  _DetSlider(
                      label: 'Чувствительность к закрытию объектива',
                      value: (det['tamper']['sensitivity'] as num).toDouble(),
                      onDone: (v) => _saveDetector('tamper_sensitivity', v.round())),
              ],
            ),
          ),
        _section('Последние события', Icons.history, [
          if (events.isEmpty)
            Text('Событий пока не было — камера сообщит, когда что-то заметит.',
                style: TextStyle(color: cs.onSurfaceVariant))
          else
            Row(
              children: events.take(3).map((e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AspectRatio(aspectRatio: 16 / 9, child: EventThumb(event: e, token: _token)),
                        ),
                        const SizedBox(height: 3),
                        Text(e.labelRu, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        Text(e.time, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                  )).toList(),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VideoEventsScreen(object: widget.object, cameraId: widget.camera.id)),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Все события камеры'),
          ),
        ]),
        if (_saving) const LinearProgressIndicator(),
      ],
    );
  }
}

IconData _labelIconOf(String code) {
  switch (code) {
    case 'person':
      return Icons.person;
    case 'motion':
      return Icons.directions_run;
    case 'intrusion':
      return Icons.login;
    case 'line':
      return Icons.straighten;
    case 'tamper':
      return Icons.visibility_off;
    case 'sound':
      return Icons.volume_up;
  }
  return Icons.notifications;
}

/// Ползунок 0–100: значение видно сразу, в камеру уходит по отпусканию.
class _DetSlider extends StatefulWidget {
  final String label;
  final String? hint;
  final double value;
  final ValueChanged<double> onDone;

  const _DetSlider({required this.label, this.hint, required this.value, required this.onDone});

  @override
  State<_DetSlider> createState() => _DetSliderState();
}

class _DetSliderState extends State<_DetSlider> {
  late double _v = widget.value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(widget.label)),
        Text('${_v.round()}', style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
      Slider(value: _v, min: 0, max: 100, divisions: 20, onChanged: (v) => setState(() => _v = v), onChangeEnd: widget.onDone),
      if (widget.hint != null)
        Text(widget.hint!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
    ]);
  }
}
