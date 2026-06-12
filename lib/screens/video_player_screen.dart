import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Нативный плеер live-потока камеры (HLS через video_player, без WebView).
/// build 1074: на Android — ExoPlayer, на iOS — AVPlayer; оба тянут HLS.
///
/// [hlsUrl] — go2rtc HLS-поток (https://.../api/stream.m3u8?src=cam_NN).
/// [title]  — заголовок (метка камеры).
class VideoPlayerScreen extends StatefulWidget {
  final String hlsUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.hlsUrl,
    required this.title,
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
