import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_event.dart';
import '../models/video_object.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'video_archive_screen.dart';

/// Лента событий камер объекта (как вкладка «События» в ЛК).
/// Фильтры: камера, период, типы (со счётчиками), «скрыть не тревогу».
/// Кадр — в лайтбоксе: листать, приблизить, скачать, открыть запись.
/// Источник: GET /mobile-api/v1/video/objects/<id>/events
class VideoEventsScreen extends StatefulWidget {
  final VideoObjectModel object;
  final int? cameraId;

  const VideoEventsScreen({super.key, required this.object, this.cameraId});

  @override
  State<VideoEventsScreen> createState() => _VideoEventsScreenState();
}

const _periods = [
  ['today', 'Сегодня'],
  ['yesterday', 'Вчера'],
  ['7d', '7 дней'],
  ['30d', '30 дней'],
  ['', 'Все'],
];

class _VideoEventsScreenState extends State<VideoEventsScreen> {
  final _scroll = ScrollController();
  final List<VideoEventModel> _events = [];
  Map<String, int> _counts = {};
  Set<String>? _labels; // null — все типы
  int? _camera;
  String _period = '7d';
  bool _hideFalse = false;
  bool _loading = false;
  bool _more = false;
  int? _cursor;
  String? _error;
  String? _token;

  ApiClient get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _camera = widget.cameraId;
    _scroll.addListener(() {
      if (_more && !_loading && _scroll.position.extentAfter < 600) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false, bool keepCounts = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _events.clear();
        _cursor = null;
      }
    });
    final q = <String, String>{
      'period': _period,
      if (_camera != null) 'camera': '$_camera',
      if (_hideFalse) 'hide_false': '1',
      if (_labels != null) 'labels': _labels!.join(','),
      if (_cursor != null) 'before': '$_cursor',
    };
    final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    try {
      final data = await _api.get('/video/objects/${widget.object.id}/events?$qs');
      // токен для кадров — после запроса: запрос мог обновить просроченный токен
      _token = await _api.accessTokenForMedia();
      if (!mounted) return;
      final list = ((data['events'] ?? []) as List)
          .map((e) => VideoEventModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _events.addAll(list);
        _more = data['more'] == true;
        _cursor = data['cursor'];
        if (data['counts'] is Map && !keepCounts) {
          _counts = (data['counts'] as Map).map((k, v) => MapEntry('$k', (v as num).toInt()));
          // выбранные типы, которых за новый период нет, — снимаем
          if (_labels != null) {
            _labels = _labels!.where(_counts.containsKey).toSet();
            if (_labels!.isEmpty) _labels = null;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить события');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleLabel(String code) {
    final avail = EventLabels.codes.where(_counts.containsKey).toSet();
    final cur = _labels ?? avail;
    final next = Set<String>.from(cur);
    if (next.contains(code)) {
      if (next.length <= 1) return; // последний не гасим: пустой фильтр выглядит как «ничего нет»
      next.remove(code);
    } else {
      next.add(code);
    }
    setState(() => _labels = next.length == avail.length ? null : next);
    _load(reset: true, keepCounts: true);
  }

  Future<void> _toggleFalse(VideoEventModel e) async {
    final value = e.isFalse ? '' : 'false';
    try {
      final r = await _api.post('/video/events/${e.id}/feedback', {'value': value});
      if (r['ok'] == true && mounted) setState(() => e.feedback = value);
    } catch (_) {}
  }

  void _openArchive(VideoEventModel e) {
    final cams = widget.object.cameras
        .where((c) => c.hasArchive)
        .map((c) => ArchiveCameraRef(c.id, c.label))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoArchiveScreen(
          cameraId: e.cameraId,
          title: 'Архив: ${e.cameraLabel}',
          cameras: cams,
          startAt: e.startedAt,
        ),
      ),
    );
  }

  void _openLightbox(VideoEventModel e) {
    final withThumb = _events.where((x) => x.thumb.isNotEmpty).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EventLightbox(
          events: withThumb,
          initial: withThumb.indexOf(e),
          token: _token,
          onArchive: _openArchive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('События · ${widget.object.name}')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _filters(cs)),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    FilledButton.tonal(onPressed: () => _load(reset: true), child: const Text('Повторить')),
                  ]),
                ),
              )
            else if (_events.isEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.notifications_none, size: 56, color: cs.outline),
                    const SizedBox(height: 12),
                    const Text('За этот период событий нет', textAlign: TextAlign.center),
                  ]),
                ),
              )
            else
              SliverList(delegate: SliverChildListDelegate(_rows(cs))),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _filters(ColorScheme cs) {
    final avail = EventLabels.codes.where(_counts.containsKey).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.object.cameras.length > 1)
            DropdownButtonFormField<int?>(
              initialValue: _camera,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Камера',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Все камеры')),
                ...widget.object.cameras.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.label))),
              ],
              onChanged: (v) {
                setState(() => _camera = v);
                _load(reset: true);
              },
            ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periods
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(p[1]),
                          selected: _period == p[0],
                          onSelected: (_) {
                            setState(() => _period = p[0]);
                            _load(reset: true);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (avail.length > 1) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: avail
                  .map((code) => FilterChip(
                        showCheckmark: false,
                        avatar: Icon(_labelIcon(code), size: 16),
                        label: Text('${EventLabels.names[code] ?? code} ${_counts[code]}'),
                        selected: _labels == null || _labels!.contains(code),
                        onSelected: (_) => _toggleLabel(code),
                      ))
                  .toList(),
            ),
          ],
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Скрыть отмеченные «не тревога»'),
            value: _hideFalse,
            onChanged: (v) {
              setState(() => _hideFalse = v);
              _load(reset: true);
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(ColorScheme cs) {
    final out = <Widget>[];
    String? day;
    for (final e in _events) {
      if (e.day != day) {
        day = e.day;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(e.dayLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ));
      }
      out.add(_EventCard(
        event: e,
        token: _token,
        onImage: () => _openLightbox(e),
        onArchive: e.hasArchive ? () => _openArchive(e) : null,
        onFalse: () => _toggleFalse(e),
      ));
    }
    return out;
  }
}

IconData _labelIcon(String code) {
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

/// Кадр события по ссылке API (с JWT в заголовке).
class EventThumb extends StatelessWidget {
  final VideoEventModel event;
  final String? token;
  final BoxFit fit;

  const EventThumb({super.key, required this.event, required this.token, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (event.thumb.isEmpty) {
      return Container(color: cs.surfaceContainerHighest, child: Icon(Icons.image_not_supported, color: cs.outline));
    }
    return Image.network(
      ApiClient.absUrl(event.thumb),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          Container(color: cs.surfaceContainerHighest, child: Icon(Icons.broken_image, color: cs.outline)),
    );
  }
}

class _EventCard extends StatelessWidget {
  final VideoEventModel event;
  final String? token;
  final VoidCallback onImage;
  final VoidCallback? onArchive;
  final VoidCallback onFalse;

  const _EventCard({
    required this.event,
    required this.token,
    required this.onImage,
    required this.onArchive,
    required this.onFalse,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: event.isFalse ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: onImage,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  EventThumb(event: event, token: token),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _Badge(icon: _labelIcon(event.label), text: event.labelRu,
                        color: event.alarm ? cs.error : Colors.black54),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _Badge(text: event.time, color: Colors.black54),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.cameraLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [event.when, if (event.durationText.isNotEmpty) event.durationText].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (onArchive != null)
                    IconButton(
                      tooltip: 'Запись',
                      onPressed: onArchive,
                      icon: Icon(Icons.play_circle_outline, color: cs.primary),
                    ),
                  IconButton(
                    tooltip: event.isFalse ? 'Отмечено: не тревога' : 'Это не тревога',
                    onPressed: onFalse,
                    icon: Icon(event.isFalse ? Icons.thumb_down : Icons.thumb_down_outlined,
                        color: event.isFalse ? cs.primary : cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;

  const _Badge({this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: Colors.white), const SizedBox(width: 4)],
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Лайтбокс кадров: листать свайпом, приближать щипком, скачать, открыть запись.
class EventLightbox extends StatefulWidget {
  final List<VideoEventModel> events;
  final int initial;
  final String? token;
  final void Function(VideoEventModel) onArchive;

  const EventLightbox({
    super.key,
    required this.events,
    required this.initial,
    required this.token,
    required this.onArchive,
  });

  @override
  State<EventLightbox> createState() => _EventLightboxState();
}

class _EventLightboxState extends State<EventLightbox> {
  late final PageController _pc;
  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx = widget.initial < 0 ? 0 : widget.initial;
    _pc = PageController(initialPage: _idx);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _download(VideoEventModel e) async {
    if (e.downloadUrl.isEmpty) return;
    final ok = await launchUrl(Uri.parse(ApiClient.absUrl(e.downloadUrl)), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть загрузку')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.events.isEmpty ? null : widget.events[_idx];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(e == null ? '' : '${e.labelRu} · ${e.cameraLabel}', style: const TextStyle(fontSize: 16)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('${_idx + 1} из ${widget.events.length}', style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
      body: e == null
          ? const SizedBox()
          : PageView.builder(
              controller: _pc,
              itemCount: widget.events.length,
              onPageChanged: (i) => setState(() => _idx = i),
              itemBuilder: (_, i) => InteractiveViewer(
                maxScale: 4,
                child: Center(child: EventThumb(event: widget.events[i], token: widget.token, fit: BoxFit.contain)),
              ),
            ),
      bottomNavigationBar: e == null
          ? null
          : SafeArea(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${e.dayLabel} ${e.time}', style: const TextStyle(color: Colors.white70)),
                    ),
                    if (e.downloadUrl.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _download(e),
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text('Скачать', style: TextStyle(color: Colors.white)),
                      ),
                    if (e.hasArchive)
                      FilledButton.icon(
                        onPressed: () => widget.onArchive(e),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Запись'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
