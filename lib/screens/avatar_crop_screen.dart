import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Кадрирование аватарки до квадрата: фото двигается пальцем и приближается щипком,
/// круг показывает, что увидят другие в турнирной таблице. Возвращает квадрат
/// в пикселях исходника {x, y, size} — сервер режет по нему, уменьшает до 512 px
/// и проверяет фото (модерация).
class AvatarCropScreen extends StatefulWidget {
  final Uint8List bytes;
  const AvatarCropScreen({super.key, required this.bytes});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  ui.Image? _img;
  double _zoom = 1, _startZoom = 1;
  Offset _off = Offset.zero, _startOff = Offset.zero, _startFocal = Offset.zero;
  double _view = 300;

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.bytes, (img) {
      if (mounted) setState(() => _img = img);
    });
  }

  double get _base => math.max(_view / _img!.width, _view / _img!.height);

  void _clamp() {
    final s = _base * _zoom;
    final mx = math.max(0.0, (_img!.width * s - _view) / 2);
    final my = math.max(0.0, (_img!.height * s - _view) / 2);
    _off = Offset(_off.dx.clamp(-mx, mx), _off.dy.clamp(-my, my));
  }

  void _done() {
    final img = _img!;
    final s = _base * _zoom;
    final side = _view / s;
    final x = img.width / 2 - (_view / 2 + _off.dx) / s;
    final y = img.height / 2 - (_view / 2 + _off.dy) / s;
    Navigator.pop(context, {'x': x.round(), 'y': y.round(), 'size': side.round()});
  }

  @override
  Widget build(BuildContext context) {
    _view = math.min(MediaQuery.of(context).size.width - 48, 340);
    return Scaffold(
      backgroundColor: const Color(0xFF0A1418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1418),
        foregroundColor: Colors.white,
        title: const Text('Аватарка'),
      ),
      body: _img == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onScaleStart: (d) {
                    _startZoom = _zoom;
                    _startOff = _off;
                    _startFocal = d.focalPoint;
                  },
                  onScaleUpdate: (d) => setState(() {
                    _zoom = (_startZoom * d.scale).clamp(1.0, 4.0);
                    _off = _startOff + (d.focalPoint - _startFocal);
                    _clamp();
                  }),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: _view,
                      height: _view,
                      child: CustomPaint(painter: _CropPainter(_img!, _base * _zoom, _off)),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Slider(
                  value: _zoom,
                  min: 1,
                  max: 4,
                  onChanged: (v) => setState(() {
                    _zoom = v;
                    _clamp();
                  }),
                ),
              ),
              const Text('Двигайте фото и приближайте — в круге то, что увидят другие',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5BA89D), padding: const EdgeInsets.all(14)),
                    onPressed: _done,
                    child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ]),
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image img;
  final double scale;
  final Offset off;
  _CropPainter(this.img, this.scale, this.off);

  @override
  void paint(Canvas canvas, Size size) {
    final w = img.width * scale, h = img.height * scale;
    final dst = Rect.fromCenter(center: size.center(Offset.zero) + off, width: w, height: h);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst,
        Paint()..filterQuality = FilterQuality.medium);
    // затемнение вне круга
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Offset.zero & size);
    canvas.drawPath(path, Paint()..color = const Color(0x73000000));
    canvas.drawOval((Offset.zero & size).deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white70);
  }

  @override
  bool shouldRepaint(covariant _CropPainter o) => o.scale != scale || o.off != off;
}
