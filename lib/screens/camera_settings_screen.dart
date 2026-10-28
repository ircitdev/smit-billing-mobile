import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_object.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'camera_events_screen.dart';

/// Настройки камеры — как окно настроек камеры в ЛК: Запись / Изображение / Голос / PTZ / События.
/// Чего камера не умеет — недоступно с пояснением. Каждое изменение сразу уходит в камеру.
/// Источник: /mobile-api/v1/video/cameras/<id>/settings | control | voice | events
class CameraSettingsScreen extends StatelessWidget {
  final VideoObjectModel object;
  final VideoCameraModel camera;
  final int initialTab;

  const CameraSettingsScreen({super.key, required this.object, required this.camera, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(camera.label),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.history, size: 20), text: 'Запись'),
              Tab(icon: Icon(Icons.image_outlined, size: 20), text: 'Изображение'),
              Tab(icon: Icon(Icons.campaign_outlined, size: 20), text: 'Голос'),
              Tab(icon: Icon(Icons.open_with, size: 20), text: 'PTZ'),
              Tab(icon: Icon(Icons.notifications_outlined, size: 20), text: 'События'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _RecordTab(camera: camera),
          _ControlTabs(camera: camera, part: 'image'),
          _ControlTabs(camera: camera, part: 'voice'),
          _ControlTabs(camera: camera, part: 'ptz'),
          CameraEventsScreen(object: object, camera: camera, embedded: true),
        ]),
      ),
    );
  }
}

void _toast(BuildContext context, String t) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 2)));

Widget _note(BuildContext context, String text) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(Icons.info_outline, color: cs.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: cs.onSurfaceVariant))),
    ]),
  );
}

// ── Запись: режим, чувствительность, звук ──
class _RecordTab extends StatefulWidget {
  final VideoCameraModel camera;
  const _RecordTab({required this.camera});

  @override
  State<_RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<_RecordTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _st;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  ApiClient get _api => context.read<AuthProvider>().api;
  String get _url => '/video/cameras/${widget.camera.id}/settings';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final d = await _api.get(_url);
      if (mounted) setState(() => d['ok'] == true ? _st = Map<String, dynamic>.from(d) : _error = '${d['error'] ?? 'Ошибка'}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить настройки записи');
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    try {
      final d = await _api.post(_url, data);
      if (!mounted) return;
      if (d['ok'] == true) {
        setState(() => _st = Map<String, dynamic>.from(d));
        final w = (d['warning'] ?? '').toString();
        _toast(context, w.isNotEmpty ? 'Сохранено. $w' : 'Сохранено');
      } else {
        _toast(context, '${d['error'] ?? 'Не сохранилось'}');
      }
    } catch (_) {
      if (mounted) _toast(context, 'Ошибка связи');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    final st = _st;
    if (st == null) return const Center(child: CircularProgressIndicator());
    final arch = st['archive_enabled'] == true;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (!arch) _note(context, 'Запись архива для камеры не подключена — режим записи недоступен.'),
      DropdownButtonFormField<String>(
        initialValue: st['mode'],
        decoration: const InputDecoration(labelText: 'Запись в архив', border: OutlineInputBorder()),
        items: ((st['modes'] ?? []) as List)
            .map((m) => DropdownMenuItem<String>(value: m['code'], child: Text(m['name'] ?? '')))
            .toList(),
        onChanged: arch ? (v) => _save({'mode': v}) : null,
      ),
      const SizedBox(height: 6),
      Text(
        'По движению — в архиве остаются только фрагменты, где что-то происходило. '
        'По детектору камеры — только когда камера заметила человека или вторжение: тени и листва запись не держат.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (st['mode'] == 'motion') ...[
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: st['sensitivity'],
          decoration: const InputDecoration(labelText: 'Чувствительность', border: OutlineInputBorder()),
          items: ((st['sensitivities'] ?? []) as List)
              .map((m) => DropdownMenuItem<String>(value: m['code'], child: Text(m['name'] ?? '')))
              .toList(),
          onChanged: arch ? (v) => _save({'sensitivity': v}) : null,
        ),
      ],
      const Divider(height: 32),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.mic_none),
        title: const Text('Звук'),
        subtitle: const Text('Слушать в трансляции и записывать в архив звук с микрофона камеры'),
        value: st['audio'] == true,
        onChanged: (v) => _save({'audio': v}),
      ),
    ]);
  }
}

// ── Изображение / Голос / PTZ — по одному состоянию камеры (GET control) ──
class _ControlTabs extends StatefulWidget {
  final VideoCameraModel camera;
  final String part; // image | voice | ptz
  const _ControlTabs({required this.camera, required this.part});

  @override
  State<_ControlTabs> createState() => _ControlTabsState();
}

class _ControlTabsState extends State<_ControlTabs> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _st;
  String? _error;
  final _text = TextEditingController();
  Timer? _ptzTimer;
  String? _preset;
  final _presetName = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  ApiClient get _api => context.read<AuthProvider>().api;
  String get _base => '/video/cameras/${widget.camera.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _ptzTimer?.cancel();
    _text.dispose();
    _presetName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _api.get('$_base/control');
      if (mounted) setState(() => _st = Map<String, dynamic>.from(d));
    } catch (_) {
      if (mounted) setState(() => _error = 'Камера не отвечает');
    }
  }

  Future<void> _set(Map<String, dynamic> data, {String ok = 'Сохранено в камере'}) async {
    try {
      final d = await _api.post('$_base/control', data);
      if (!mounted) return;
      if (d['ok'] != true) {
        _toast(context, '${d['error'] ?? 'Камера не приняла настройку'}');
      } else if (ok.isNotEmpty) {
        _toast(context, ok);
      }
    } catch (_) {
      if (mounted) _toast(context, 'Ошибка связи');
    }
  }

  Future<void> _say(Map<String, dynamic> data) async {
    try {
      final d = await _api.post('$_base/voice', data);
      if (mounted) _toast(context, d['ok'] == true ? 'Камера произносит' : '${d['error'] ?? 'Не получилось'}');
    } catch (_) {
      if (mounted) _toast(context, 'Подождите несколько секунд');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    final st = _st;
    if (st == null) return const Center(child: CircularProgressIndicator());
    switch (widget.part) {
      case 'voice':
        return _voice(st);
      case 'ptz':
        return _ptz(st);
    }
    return _image(st);
  }

  Map<String, dynamic> _caps(Map<String, dynamic> st) => Map<String, dynamic>.from(st['caps'] ?? {});

  // ── Изображение ──
  Widget _image(Map<String, dynamic> st) {
    final caps = _caps(st);
    if (st['ok'] != true) {
      return ListView(padding: const EdgeInsets.all(16), children: [_note(context, '${st['error'] ?? 'Камера не поддерживает настройку изображения'}')]);
    }
    // ссылки на данные экрана, а не копии: переключатель не откатывается при перерисовке
    final img = (st['image'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final opts = Map<String, dynamic>.from(st['image_opts'] ?? {});
    final xm = (st['xm'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final labels = Map<String, dynamic>.from(st['labels'] ?? {});
    const names = {'brightness': 'Яркость', 'contrast': 'Контраст', 'saturation': 'Насыщенность', 'sharpness': 'Резкость'};
    final out = <Widget>[];
    for (final k in names.keys) {
      final r = opts[k];
      if (r is List && r.length == 2 && img[k] != null) {
        out.add(_Slider(
          label: names[k]!,
          min: (r[0] as num).toDouble(),
          max: (r[1] as num).toDouble(),
          value: (img[k] as num).toDouble(),
          onDone: (v) => _set({k: v.round()}),
        ));
      }
    }
    Widget sw(String key, String title, bool on) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          value: on,
          onChanged: (v) {
            setState(() {
              if (key == 'wdr' || key == 'blc') {
                img[key] = v;
              } else {
                xm[key] = v;
              }
            });
            _set({key: v});
          },
        );
    if (opts['wdr'] == 'bool') out.add(sw('wdr', 'Широкий динамический диапазон (WDR)', img['wdr'] == true));
    if (opts['blc'] == 'bool') out.add(sw('blc', 'Компенсация засветки', img['blc'] == true));
    Widget select(String key, String title, List items, String? cur) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DropdownButtonFormField<String>(
            initialValue: items.any((i) => i[0] == cur) ? cur : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: title, border: const OutlineInputBorder()),
            items: items.map((i) => DropdownMenuItem<String>(value: '${i[0]}', child: Text('${i[1]}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => _set({key: v}),
          ),
        );
    if (caps['daynight'] == true) out.add(select('daynight', 'День / ночь', (labels['daynight'] ?? []) as List, xm['daynight']));
    if (caps['light'] == true) out.add(select('light', 'Подсветка', (labels['light'] ?? []) as List, xm['light']));
    if (caps['flip'] == true) {
      out.add(const SizedBox(height: 8));
      out.add(sw('flip', 'Перевернуть кадр', xm['flip'] == true));
      out.add(sw('mirror', 'Отразить зеркально', xm['mirror'] == true));
    }
    if (caps['time'] == true) {
      out.add(const Divider(height: 28));
      if ((st['time'] ?? '').toString().isNotEmpty) out.add(Text('Время на камере: ${st['time']}'));
      out.add(Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _set({'action': 'sync_time'}, ok: 'Время синхронизировано'),
          icon: const Icon(Icons.schedule),
          label: const Text('Синхронизировать время'),
        ),
      ));
    }
    if (out.isEmpty) out.add(_note(context, 'Камера не поддерживает настройку изображения.'));
    return ListView(padding: const EdgeInsets.all(16), children: out);
  }

  // ── Голос: фразы, свой текст, сирена, громкость ──
  Widget _voice(Map<String, dynamic> st) {
    final caps = _caps(st);
    final on = st['ok'] == true && caps['talk'] == true;
    final xm = Map<String, dynamic>.from(st['xm'] ?? {});
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (!on) _note(context, '${st['talk_note'] ?? st['error'] ?? 'Камера не воспроизводит звук — голосовые команды недоступны'}'),
      Text('Готовые фразы', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      ...((st['phrases'] ?? []) as List).map((p) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p['text'] ?? ''),
            trailing: IconButton.filledTonal(
              tooltip: 'Произнести',
              onPressed: on ? () => _say({'phrase': p['key']}) : null,
              icon: const Icon(Icons.play_arrow),
            ),
          )),
      const SizedBox(height: 8),
      TextField(
        controller: _text,
        enabled: on,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: 'Свой текст',
          hintText: 'Текст, который произнесёт камера',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send),
            onPressed: on
                ? () {
                    final t = _text.text.trim();
                    if (t.isNotEmpty) _say({'text': t});
                  }
                : null,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: cs.error),
          onPressed: on ? () => _say({'siren': true}) : null,
          icon: const Icon(Icons.notifications_active),
          label: const Text('Сирена'),
        ),
      ),
      if (caps['volume'] == true) ...[
        const SizedBox(height: 12),
        _Slider(
          label: 'Громкость динамика',
          min: 0,
          max: 100,
          value: ((xm['volume'] ?? 50) as num).toDouble(),
          onDone: (v) => _set({'volume': v.round()}, ok: 'Громкость сохранена'),
        ),
      ],
    ]);
  }

  // ── PTZ: удержание — поворот, отпустил — стоп; позиции ──
  Widget _ptz(Map<String, dynamic> st) {
    final caps = _caps(st);
    final on = caps['ptz'] == true;
    final presets = ((st['ptz_presets'] ?? []) as List);
    void move(double x, double y, double z) {
      _set({'action': 'ptz_move', 'x': x, 'y': y, 'z': z}, ok: '');
      _ptzTimer?.cancel();
      _ptzTimer = Timer.periodic(const Duration(milliseconds: 800),
          (_) => _api.post('$_base/control', {'action': 'ptz_move', 'x': x, 'y': y, 'z': z}));
    }

    void stop() {
      if (_ptzTimer == null) return;
      _ptzTimer?.cancel();
      _ptzTimer = null;
      _api.post('$_base/control', {'action': 'ptz_stop'});
    }

    Widget btn(double x, double y, double z, IconData icon) => Listener(
          onPointerDown: on ? (_) => move(x, y, z) : null,
          onPointerUp: on ? (_) => stop() : null,
          onPointerCancel: on ? (_) => stop() : null,
          child: IconButton.outlined(onPressed: on ? () {} : null, icon: Icon(icon), iconSize: 28),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (!on) _note(context, '${st['ptz_note'] ?? 'Камера неповоротная — PTZ недоступен'}'),
      Center(
        child: Column(children: [
          btn(0, 0.5, 0, Icons.keyboard_arrow_up),
          Row(mainAxisSize: MainAxisSize.min, children: [
            btn(-0.5, 0, 0, Icons.keyboard_arrow_left),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: on ? () => _set({'action': 'ptz_home'}, ok: 'Камера возвращается в исходное положение') : null,
              icon: const Icon(Icons.home),
              iconSize: 28,
            ),
            const SizedBox(width: 8),
            btn(0.5, 0, 0, Icons.keyboard_arrow_right),
          ]),
          btn(0, -0.5, 0, Icons.keyboard_arrow_down),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            btn(0, 0, 0.5, Icons.zoom_in),
            const SizedBox(width: 16),
            btn(0, 0, -0.5, Icons.zoom_out),
          ]),
        ]),
      ),
      const SizedBox(height: 8),
      Text('Держите кнопку — камера поворачивается, отпустите — остановится.',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      const Divider(height: 28),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _preset,
            decoration: const InputDecoration(labelText: 'Сохранённые позиции', border: OutlineInputBorder()),
            items: presets.map((p) => DropdownMenuItem<String>(value: '${p['token']}', child: Text('${p['name']}'))).toList(),
            onChanged: on ? (v) => setState(() => _preset = v) : null,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: on && _preset != null ? () => _set({'action': 'ptz_goto', 'token': _preset}, ok: 'Камера переходит к позиции') : null,
          child: const Text('Перейти'),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _presetName,
            enabled: on,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Название текущей позиции', border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: on
              ? () async {
                  final n = _presetName.text.trim();
                  if (n.isEmpty) return;
                  await _set({'action': 'ptz_preset', 'name': n}, ok: 'Позиция сохранена');
                  _load();
                }
              : null,
          child: const Text('Запомнить'),
        ),
      ]),
    ]);
  }
}

/// Ползунок: значение видно сразу, в камеру уходит по отпусканию.
class _Slider extends StatefulWidget {
  final String label;
  final double min, max, value;
  final ValueChanged<double> onDone;
  const _Slider({required this.label, required this.min, required this.max, required this.value, required this.onDone});

  @override
  State<_Slider> createState() => _SliderState();
}

class _SliderState extends State<_Slider> {
  late double _v = widget.value.clamp(widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(widget.label)), Text('${_v.round()}')]),
      Slider(value: _v, min: widget.min, max: widget.max, onChanged: (v) => setState(() => _v = v), onChangeEnd: widget.onDone),
    ]);
  }
}
