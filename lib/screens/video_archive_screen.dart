import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';

/// Нативный архив видеозаписей (build 1074) — без WebView.
/// Календарь даты → интервалы записи (таймлайн) → клик/выделение → MP4-фрагмент
/// через нативный video_player. JWT-доступ к mobile-api archive-endpoint'ам.
///
/// Если у объекта несколько камер — [cameras] позволяет переключаться.
class VideoArchiveScreen extends StatefulWidget {
  final int cameraId;
  final String title;
  final List<ArchiveCameraRef> cameras; // для селектора (если >1)

  const VideoArchiveScreen({
    super.key,
    required this.cameraId,
    required this.title,
    this.cameras = const [],
  });

  @override
  State<VideoArchiveScreen> createState() => _VideoArchiveScreenState();
}

class ArchiveCameraRef {
  final int id;
  final String label;
  const ArchiveCameraRef(this.id, this.label);
}

class _Interval {
  final DateTime start;
  final int duration; // секунды
  _Interval(this.start, this.duration);
  DateTime get end => start.add(Duration(seconds: duration));
}

class _VideoArchiveScreenState extends State<VideoArchiveScreen> {
  late int _camId;
  DateTime _date = DateTime.now();
  int _retentionDays = 7;

  bool _loadingIntervals = false;
  String? _intervalsError;
  List<_Interval> _intervals = [];

  // выделение участка [0..1] в координатах суток
  double? _selStart;
  double? _selEnd;

  // плеер фрагмента
  VideoPlayerController? _clip;
  bool _clipLoading = false;
  String? _clipError;

  static const int _clipPreviewSec = 300; // 5 мин при клике

  @override
  void initState() {
    super.initState();
    _camId = widget.cameraId;
    _loadIntervals();
  }

  @override
  void dispose() {
    _clip?.dispose();
    super.dispose();
  }

  ApiClient get _api => context.read<AuthProvider>().api;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _loadIntervals() async {
    setState(() {
      _loadingIntervals = true;
      _intervalsError = null;
      _intervals = [];
      _selStart = _selEnd = null;
    });
    try {
      final data = await _api.get(
          '/video/archive/$_camId/intervals?date=$_dateStr');
      if (data is Map && data['ok'] == true) {
        final list = (data['intervals'] as List? ?? []);
        final parsed = <_Interval>[];
        for (final iv in list) {
          final s = DateTime.tryParse(iv['start']?.toString() ?? '');
          if (s == null) continue;
          final d = (iv['duration'] is num)
              ? (iv['duration'] as num).toInt()
              : int.tryParse(iv['duration']?.toString() ?? '0') ?? 0;
          if (d > 0) parsed.add(_Interval(s.toUtc(), d));
        }
        setState(() {
          _intervals = parsed;
          _retentionDays = (data['retention_days'] is num)
              ? (data['retention_days'] as num).toInt()
              : _retentionDays;
        });
      } else {
        setState(() => _intervalsError =
            (data is Map ? data['error']?.toString() : null) ??
                'Архив недоступен');
      }
    } catch (e) {
      setState(() => _intervalsError = 'Ошибка загрузки интервалов');
    } finally {
      if (mounted) setState(() => _loadingIntervals = false);
    }
  }

  // начало выбранного дня в UTC (координаты таймлайна = сутки UTC)
  DateTime get _dayStartUtc =>
      DateTime.utc(_date.year, _date.month, _date.day);

  String _fracToIso(double frac) {
    final ms = _dayStartUtc.millisecondsSinceEpoch + (frac * 86400000).round();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
        .toIso8601String();
  }

  String _fracToHHMM(double frac) {
    final total = (frac * 86400).round();
    final h = (total ~/ 3600) % 24;
    final m = (total % 3600) ~/ 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _fmtDur(int sec) {
    if (sec < 60) return '$sec с';
    final m = sec ~/ 60, s = sec % 60;
    if (m < 60) return s > 0 ? '$m мин $s с' : '$m мин';
    final h = m ~/ 60;
    final mm = m % 60;
    return mm > 0 ? '$h ч $mm мин' : '$h ч';
  }

  Future<void> _playFromFrac(double frac) async {
    setState(() {
      _selStart = _selEnd = null;
    });
    await _playClip(_fracToIso(frac), _clipPreviewSec);
  }

  Future<void> _playSelection() async {
    if (_selStart == null || _selEnd == null) return;
    final a = _selStart! < _selEnd! ? _selStart! : _selEnd!;
    final b = _selStart! < _selEnd! ? _selEnd! : _selStart!;
    final dur = ((b - a) * 86400).round();
    if (dur < 5) {
      await _playFromFrac(a);
      return;
    }
    await _playClip(_fracToIso(a), dur);
  }

  Future<void> _playClip(String startIso, int duration) async {
    setState(() {
      _clipLoading = true;
      _clipError = null;
    });
    await _clip?.dispose();
    _clip = null;
    try {
      final info = await _api.get(
          '/video/archive/$_camId/clip_info?start=${Uri.encodeComponent(startIso)}&duration=$duration');
      if (info is! Map || info['ok'] != true) {
        setState(() {
          _clipLoading = false;
          _clipError =
              (info is Map ? info['error']?.toString() : null) ?? 'Фрагмент недоступен';
        });
        return;
      }
      final rawUrl = info['url']?.toString() ?? '';
      final proxied = info['proxied'] == true;
      final host = ApiClient.baseUrl.replaceFirst('/mobile-api/v1', '');
      // proxied → относительный mobile-api путь (нужен JWT-заголовок);
      // иначе публичный MediaMTX URL.
      final url = rawUrl.startsWith('http')
          ? rawUrl
          : (proxied ? '$host$rawUrl' : '$host$rawUrl');

      final headers = <String, String>{};
      if (proxied) {
        final tok = await _api.accessTokenForMedia();
        if (tok != null) headers['Authorization'] = 'Bearer $tok';
      }

      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _clip = c;
      await c.initialize();
      await c.play();
      if (mounted) setState(() => _clipLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _clipLoading = false;
          _clipError = 'Не удалось загрузить фрагмент';
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = now.subtract(Duration(days: _retentionDays));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: now,
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() => _date = picked);
      await _loadIntervals();
    }
  }

  void _switchCamera(int id) {
    if (id == _camId) return;
    setState(() {
      _camId = id;
      _clip?.dispose();
      _clip = null;
      _clipError = null;
    });
    _loadIntervals();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalSec =
        _intervals.fold<int>(0, (acc, iv) => acc + iv.duration);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── плеер фрагмента ──
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildClipArea(cs),
            ),
          ),
          const SizedBox(height: 14),

          // ── селектор камеры (если >1) ──
          if (widget.cameras.length > 1) ...[
            _CameraSelector(
              cameras: widget.cameras,
              current: _camId,
              onSelect: _switchCamera,
            ),
            const SizedBox(height: 12),
          ],

          // ── дата ──
          Row(
            children: [
              const Icon(Icons.event, size: 20),
              const SizedBox(width: 8),
              const Text('Дата:'),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(DateFormat('dd.MM.yyyy').format(_date)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Обновить',
                onPressed: _loadIntervals,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── таймлайн ──
          if (_loadingIntervals)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_intervalsError != null)
            _statusBox(_intervalsError!, isError: true)
          else ...[
            _Timeline(
              intervals: _intervals,
              dayStartUtc: _dayStartUtc,
              selStart: _selStart,
              selEnd: _selEnd,
              onTapFrac: _playFromFrac,
              onSelect: (a, b) => setState(() {
                _selStart = a;
                _selEnd = b;
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _intervals.isEmpty
                  ? 'За выбранный день записи нет.'
                  : 'Доступно записи: ${(totalSec / 60).round()} мин. '
                      'Нажмите на полосу — просмотр; выделите участок — фрагмент.',
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
          ],

          // ── панель выделения ──
          if (_selStart != null && _selEnd != null) ...[
            const SizedBox(height: 12),
            _buildSelectionBar(cs),
          ],
        ],
      ),
    );
  }

  Widget _buildClipArea(ColorScheme cs) {
    if (_clipLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_clipError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 40),
              const SizedBox(height: 8),
              Text(_clipError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    final c = _clip;
    if (c != null && c.value.isInitialized) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          VideoProgressIndicator(c, allowScrubbing: true),
          // кнопка play/pause по тапу
          GestureDetector(
            onTap: () => setState(() =>
                c.value.isPlaying ? c.pause() : c.play()),
            child: AnimatedOpacity(
              opacity: c.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 64),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // пусто
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, color: Colors.white38, size: 44),
          SizedBox(height: 8),
          Text('Выберите момент на таймлайне',
              style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(ColorScheme cs) {
    final a = _selStart! < _selEnd! ? _selStart! : _selEnd!;
    final b = _selStart! < _selEnd! ? _selEnd! : _selStart!;
    final dur = ((b - a) * 86400).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_fracToHHMM(a)} — ${_fracToHHMM(b)}  (${_fmtDur(dur)})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _playSelection,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Просмотр'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: _downloadSelection,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Скачать'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selStart = _selEnd = null),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Сбросить'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSelection() async {
    if (_selStart == null || _selEnd == null) return;
    final a = _selStart! < _selEnd! ? _selStart! : _selEnd!;
    final b = _selStart! < _selEnd! ? _selEnd! : _selStart!;
    final dur = ((b - a) * 86400).round();
    // скачивание открываем в браузере: clip?download=1 (нужен токен → через clip_info proxied)
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
        content: Text('Готовим фрагмент к скачиванию (${_fmtDur(dur)})…')));
    // Для нативного скачивания с JWT проще проиграть; полноценная выгрузка файла —
    // через системный download-менеджер требует доп. пакета. Пока — просмотр.
    await _playSelection();
  }

  Widget _statusBox(String text, {bool isError = false}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red.withValues(alpha: 0.06)
              : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline,
                color: isError ? Colors.red : Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

/// Полоса таймлайна суток: зелёные интервалы записи + клик/drag-выделение.
class _Timeline extends StatefulWidget {
  final List<_Interval> intervals;
  final DateTime dayStartUtc;
  final double? selStart;
  final double? selEnd;
  final void Function(double frac) onTapFrac;
  final void Function(double a, double b) onSelect;

  const _Timeline({
    required this.intervals,
    required this.dayStartUtc,
    required this.selStart,
    required this.selEnd,
    required this.onTapFrac,
    required this.onSelect,
  });

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  double? _dragStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const dayMs = 86400000.0;
    return Column(
      children: [
        // подписи часов
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('00', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('06', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('12', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('18', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('24', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (ctx, box) {
          final w = box.maxWidth;
          return GestureDetector(
            onTapDown: (d) {
              final frac = (d.localPosition.dx / w).clamp(0.0, 1.0);
              widget.onTapFrac(frac);
            },
            onHorizontalDragStart: (d) {
              _dragStart = (d.localPosition.dx / w).clamp(0.0, 1.0);
            },
            onHorizontalDragUpdate: (d) {
              if (_dragStart == null) return;
              final cur = (d.localPosition.dx / w).clamp(0.0, 1.0);
              widget.onSelect(_dragStart!, cur);
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // часовые риски
                  for (int h = 1; h < 24; h++)
                    Positioned(
                      left: w * h / 24,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: Colors.black12),
                    ),
                  // интервалы записи (зелёные)
                  for (final iv in widget.intervals)
                    _segment(iv, w, dayMs),
                  // выделение (оранжевое)
                  if (widget.selStart != null && widget.selEnd != null)
                    _selectionRect(w),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _segment(_Interval iv, double w, double dayMs) {
    final day0 = widget.dayStartUtc.millisecondsSinceEpoch;
    final st = iv.start.millisecondsSinceEpoch;
    final leftFrac = ((st - day0) / dayMs).clamp(0.0, 1.0);
    final widFrac = ((iv.duration * 1000) / dayMs).clamp(0.0, 1.0 - leftFrac);
    if (widFrac <= 0) return const SizedBox.shrink();
    return Positioned(
      left: w * leftFrac,
      top: 0,
      bottom: 0,
      width: (w * widFrac).clamp(2.0, w),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF43b77a), Color(0xFF2d9a5f)],
          ),
        ),
      ),
    );
  }

  Widget _selectionRect(double w) {
    final a = widget.selStart! < widget.selEnd! ? widget.selStart! : widget.selEnd!;
    final b = widget.selStart! < widget.selEnd! ? widget.selEnd! : widget.selStart!;
    return Positioned(
      left: w * a,
      top: 0,
      bottom: 0,
      width: w * (b - a),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.25),
          border: Border.symmetric(
            vertical: BorderSide(color: Colors.orange, width: 2),
          ),
        ),
      ),
    );
  }
}

class _CameraSelector extends StatelessWidget {
  final List<ArchiveCameraRef> cameras;
  final int current;
  final void Function(int id) onSelect;
  const _CameraSelector(
      {required this.cameras, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Icon(Icons.videocam, size: 18, color: Color(0xFF43b77a)),
          const SizedBox(width: 8),
          for (final c in cameras) ...[
            ChoiceChip(
              label: Text(c.label),
              selected: c.id == current,
              onSelected: (_) => onSelect(c.id),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
