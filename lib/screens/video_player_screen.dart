import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Нативный плеер live-потока камеры (HLS через video_player, без WebView).
/// build 1074: на Android — ExoPlayer, на iOS — AVPlayer; оба тянут HLS.
///
/// [hlsUrl] — go2rtc HLS-поток (https://.../api/stream.m3u8?src=cam_NN).
/// [title]  — заголовок (метка камеры).
class VideoPlayerScreen extends StatefulWidget {
  final String hlsUrl;
  final String title;
  /// build 3662: камера — для кнопки «Сказать» (фразы и сирена в динамик)
  final int? cameraId;

  const VideoPlayerScreen({
    super.key,
    required this.hlsUrl,
    required this.title,
    this.cameraId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _error = false;
  String _errorText = 'Не удалось загрузить видео';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(widget.hlsUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = c;
      await c.initialize();
      await c.setLooping(false);
      await c.play();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
          _errorText = 'Поток недоступен. Камера может быть offline.';
        });
      }
    }
  }

  Future<void> _retry() async {
    await _controller?.dispose();
    _controller = null;
    await _init();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Закрыть',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.cameraId != null)
            IconButton(
              tooltip: 'Сказать в динамик камеры',
              icon: const Icon(Icons.campaign_outlined),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => VoiceSheet(cameraId: widget.cameraId!),
              ),
            ),
          // индикатор «прямой эфир»
          if (!_loading && !_error)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Row(children: [
                Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                SizedBox(width: 5),
                Text('Прямой эфир', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
        ],
      ),
      body: Center(
        child: _error
            ? _buildError()
            : (_loading || c == null || !c.value.isInitialized)
                ? const CircularProgressIndicator(color: Colors.white)
                : AspectRatio(
                    aspectRatio:
                        c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(c),
                        _PlayPauseOverlay(controller: c),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 56),
            const SizedBox(height: 12),
            Text(_errorText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _retry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
}

/// Тап по видео — пауза/воспроизведение (для live полезно «заморозить» кадр).
class _PlayPauseOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  const _PlayPauseOverlay({required this.controller});

  @override
  State<_PlayPauseOverlay> createState() => _PlayPauseOverlayState();
}

class _PlayPauseOverlayState extends State<_PlayPauseOverlay> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.controller.value.isPlaying
              ? widget.controller.pause()
              : widget.controller.play();
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: widget.controller.value.isPlaying
            ? const SizedBox.expand()
            : Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 72),
                ),
              ),
      ),
    );
  }
}


/// «Сказать» из плеера: готовые фразы, свой текст, сирена. Камера без динамика — пояснение.
class VoiceSheet extends StatefulWidget {
  final int cameraId;
  const VoiceSheet({super.key, required this.cameraId});

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  Map<String, dynamic>? _st;
  final _text = TextEditingController();
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final d = await context.read<AuthProvider>().api.get('/video/cameras/${widget.cameraId}/control');
        if (mounted) setState(() => _st = Map<String, dynamic>.from(d));
      } catch (_) {
        if (mounted) setState(() => _st = {'ok': false, 'talk_note': 'Камера не отвечает'});
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _say(Map<String, dynamic> data) async {
    setState(() => _status = 'Отправляю в камеру…');
    try {
      final d = await context.read<AuthProvider>().api.post('/video/cameras/${widget.cameraId}/voice', data);
      if (mounted) setState(() => _status = d['ok'] == true ? 'Камера произносит' : '${d['error'] ?? 'Не получилось'}');
    } catch (_) {
      if (mounted) setState(() => _status = 'Подождите несколько секунд');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _st;
    final cs = Theme.of(context).colorScheme;
    if (st == null) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    final on = st['ok'] == true && (st['caps'] ?? {})['talk'] == true;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Сказать в динамик камеры', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (!on)
          Text('${st['talk_note'] ?? 'У камеры нет динамика — голосовые команды недоступны'}',
              style: TextStyle(color: cs.onSurfaceVariant))
        else ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            ...((st['phrases'] ?? []) as List).map((p) => ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 16),
                  label: Text(p['text'] ?? '', overflow: TextOverflow.ellipsis),
                  onPressed: () => _say({'phrase': p['key']}),
                )),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Свой текст',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  final t = _text.text.trim();
                  if (t.isNotEmpty) _say({'text': t});
                },
              ),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: cs.error),
            onPressed: () => _say({'siren': true}),
            icon: const Icon(Icons.notifications_active),
            label: const Text('Сирена'),
          ),
        ],
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status)),
      ]),
    );
  }
}
