import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

class HelicopterGame extends StatefulWidget {
  const HelicopterGame({super.key});
  @override
  State<HelicopterGame> createState() => _HelicopterGameState();
}

class _HelicopterGameState extends State<HelicopterGame> with SingleTickerProviderStateMixin {
  static const double W = 300;
  static const double H = 400;
  static const double heliW = 40;
  static const double heliH = 20;
  static const double gravity = 0.35;
  static const double liftForce = 0.7;
  static const double maxVY = 7.0;
  static const double obstacleW = 28;

  double heliX = 60;
  double heliY = H / 2;
  double velY = 0;
  bool pressing = false;

  // Cave walls: list of {x, topH, botH}
  List<Map<String, double>> walls = [];
  // Obstacles inside cave
  List<Map<String, double>> obstacles = [];
  double scrollX = 0;
  double speed = 2.5;
  int score = 0; // frames survived
  int bestScore = 0;
  bool isPlaying = false;
  bool isGameOver = false;
  bool started = false;
  bool _scoreSent = false;

  late AnimationController _anim;
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  final random = Random();
  double _scale = 1;

  // Cave params
  double _caveTop = 60;
  double _caveBot = H - 60;
  double _nextWallX = W.toDouble();

  @override
  void initState() {
    super.initState();
    _reset();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_tick)
      ..repeat();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _reset() {
    heliY = H / 2;
    velY = 0;
    walls = [];
    obstacles = [];
    score = 0;
    isGameOver = false;
    started = false;
    _scoreSent = false;
    lastRank = null;
    pressing = false;
    _caveTop = 60;
    _caveBot = H - 60;
    _nextWallX = W.toDouble();
    speed = 2.5;
    // Pre-fill walls
    for (double x = 0; x < W + 60; x += 20) {
      _addWall(x);
    }
  }

  void _addWall(double x) {
    walls.add({'x': x, 'top': _caveTop, 'bot': _caveBot});
    // Gradually narrow/widen cave
    final delta = (random.nextDouble() - 0.5) * 16;
    _caveTop = (_caveTop + delta).clamp(20.0, H / 2 - 60);
    _caveBot = (_caveBot + delta).clamp(H / 2 + 60, H - 20);
  }

  void _tick() {
    if (!isPlaying || isGameOver) return;
    setState(() {
      score++;
      speed = 2.5 + score * 0.001;

      // Physics
      if (pressing) {
        velY -= liftForce;
      } else {
        velY += gravity;
      }
      velY = velY.clamp(-maxVY, maxVY);
      heliY += velY;

      // Scroll walls
      for (final w in walls) {
        w['x'] = w['x']! - speed;
      }
      for (final o in obstacles) {
        o['x'] = o['x']! - speed;
      }

      // Remove off-screen
      walls.removeWhere((w) => w['x']! < -30);
      obstacles.removeWhere((o) => o['x']! < -obstacleW - 10);

      // Add new walls
      while (walls.isEmpty || walls.last['x']! < W + 20) {
        _addWall(walls.isEmpty ? W.toDouble() : walls.last['x']! + 20);
      }

      // Add obstacles every ~150px
      if (score % 60 == 0 && score > 120) {
        // Find a wall near x=W+10
        final refWall = walls.firstWhere((w) => w['x']! > W, orElse: () => walls.last);
        final top = refWall['top']!;
        final bot = refWall['bot']!;
        final spaceH = bot - top;
        if (spaceH > 80) {
          final oy = top + 20 + random.nextDouble() * (spaceH - 60);
          obstacles.add({'x': W + 20, 'y': oy, 'h': 40.0 + random.nextDouble() * 20});
        }
      }

      // Collision check
      final hLeft = heliX - heliW / 2;
      final hRight = heliX + heliW / 2;
      final hTop = heliY - heliH / 2;
      final hBot = heliY + heliH / 2;

      // Cave walls
      for (final w in walls) {
        final wx = w['x']!;
        if (wx > hLeft - 10 && wx < hRight + 10) {
          if (hTop < w['top']! || hBot > w['bot']!) {
            _die();
            return;
          }
        }
      }

      // Obstacles
      for (final o in obstacles) {
        final ox = o['x']!;
        final oy = o['y']!;
        final oh = o['h']!;
        if (hRight > ox && hLeft < ox + obstacleW &&
            hBot > oy && hTop < oy + oh) {
          _die();
          return;
        }
      }
    });
  }

  void _die() {
    isGameOver = true;
    isPlaying = false;
    pressing = false;
    if (score > bestScore) bestScore = score;
    HapticFeedback.heavyImpact();
    if (!_scoreSent && score > 0) { _scoreSent = true; _submitScore(); }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=helicopter');
      if (data is Map && data['scores'] is List && mounted) {
        setState(() { leaderboard = List<Map<String, dynamic>>.from(data['scores']); });
      }
    } catch (_) {}
  }

  Future<void> _submitScore() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiPost('/game/score', {'game': 'helicopter', 'score': score});
      if (data is Map && mounted) {
        setState(() {
          lastRank = data['rank'];
          if (data['board'] is List) leaderboard = List<Map<String, dynamic>>.from(data['board']);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a2e),
      appBar: AppBar(
        backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0,
        title: Row(children: [
          const Text('🚁', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Helicopter', style: TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          _badge('$score', Colors.purple),
          if (bestScore > 0) ...[const SizedBox(width: 8), _badge('best: $bestScore', Colors.amber)],
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.leaderboard), onPressed: _showLeaderboard),
        ],
      ),
      body: GestureDetector(
        onTapDown: (_) {
          if (isGameOver) {
            setState(() { isPlaying = false; _reset(); });
            return;
          }
          if (!started) { started = true; isPlaying = true; }
          setState(() { pressing = true; });
        },
        onTapUp: (_) => setState(() { pressing = false; }),
        onTapCancel: () => setState(() { pressing = false; }),
        onPanStart: (_) {
          if (!started && !isGameOver) { started = true; isPlaying = true; }
          if (!isGameOver) setState(() { pressing = true; });
        },
        onPanEnd: (_) => setState(() { pressing = false; }),
        child: LayoutBuilder(builder: (context, box) {
          _scale = min(box.maxWidth / W, box.maxHeight / H);
          return Center(
            child: SizedBox(
              width: W * _scale,
              height: H * _scale,
              child: CustomPaint(
                painter: _HelicopterPainter(
                  heliX: heliX, heliY: heliY, pressing: pressing,
                  walls: walls, obstacles: obstacles,
                  score: score, isGameOver: isGameOver, started: started,
                  lastRank: lastRank,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
  );

  void _showLeaderboard() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5, maxChildSize: 0.85, minChildSize: 0.3,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Text('🏆', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('Рейтинг Helicopter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
            ),
            Expanded(
              child: leaderboard.isEmpty
                  ? const Center(child: Text('Пока нет рекордов.\nБудьте первым!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: leaderboard.length,
                      itemBuilder: (_, i) {
                        final e = leaderboard[i];
                        final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
                        return ListTile(
                          leading: SizedBox(width: 36, child: Center(child: Text(medal, style: TextStyle(fontSize: i < 3 ? 24 : 16)))),
                          title: Text(e['name'] ?? '???', style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text('${e['score']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: i < 3 ? Colors.amber[700] : null)),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HelicopterPainter extends CustomPainter {
  final double heliX, heliY;
  final bool pressing, started, isGameOver;
  final List<Map<String, double>> walls, obstacles;
  final int score;
  final int? lastRank;

  _HelicopterPainter({
    required this.heliX, required this.heliY,
    required this.pressing, required this.walls, required this.obstacles,
    required this.score, required this.isGameOver, required this.started,
    required this.lastRank,
  });

  static const double W = _HelicopterGameState.W;
  static const double H = _HelicopterGameState.H;
  static const double heliW = _HelicopterGameState.heliW;
  static const double heliH = _HelicopterGameState.heliH;
  static const double obstacleW = _HelicopterGameState.obstacleW;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / W;
    canvas.scale(scale, scale);

    // Sky gradient
    final bgPaint = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF0a0a2e), Color(0xFF1a1a4e)],
    ).createShader(Rect.fromLTWH(0, 0, W, H));
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), bgPaint);

    // Cave walls (fill region outside)
    if (walls.length >= 2) {
      for (int i = 0; i < walls.length - 1; i++) {
        final w = walls[i];
        final w2 = walls[i + 1];
        // Top wall
        final topPath = Path()
          ..moveTo(w['x']!, 0)
          ..lineTo(w2['x']!, 0)
          ..lineTo(w2['x']!, w2['top']!)
          ..lineTo(w['x']!, w['top']!)
          ..close();
        canvas.drawPath(topPath, Paint()..color = const Color(0xFF374151));

        // Bottom wall
        final botPath = Path()
          ..moveTo(w['x']!, w['bot']!)
          ..lineTo(w2['x']!, w2['bot']!)
          ..lineTo(w2['x']!, H)
          ..lineTo(w['x']!, H)
          ..close();
        canvas.drawPath(botPath, Paint()..color = const Color(0xFF374151));
      }
    }

    // Obstacles
    for (final o in obstacles) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o['x']!, o['y']!, obstacleW, o['h']!),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFEF4444),
      );
    }

    // Helicopter
    final hx = heliX, hy = heliY;
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hx - heliW / 2, hy - heliH / 2, heliW, heliH),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF9B59B6),
    );
    // Main rotor
    final rotorPaint = Paint()..color = Colors.white70..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(hx - heliW * 0.6, hy - heliH / 2 - 5), Offset(hx + heliW * 0.6, hy - heliH / 2 - 5), rotorPaint);
    // Tail
    canvas.drawLine(Offset(hx + heliW / 2, hy), Offset(hx + heliW / 2 + 12, hy - 6), Paint()..color = Colors.white54..strokeWidth = 2);
    // Window
    canvas.drawCircle(Offset(hx - 6, hy - 2), 5, Paint()..color = Colors.lightBlueAccent.withOpacity(0.6));

    // Thrust particles
    if (pressing) {
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(hx - heliW / 2 + 8 + i * 8, hy + heliH / 2 + 4),
          3,
          Paint()..color = Colors.orange.withOpacity(0.7 - i * 0.2),
        );
      }
    }

    // Score
    _drawText(canvas, '$score', Offset(W / 2, 24), 28, Colors.white, weight: FontWeight.w900, shadow: true);

    if (!started && !isGameOver) {
      _drawText(canvas, 'Удерживайте для взлёта', Offset(W / 2, H / 2 + 60), 16, Colors.white70);
    }

    if (isGameOver) {
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.black54);
      _drawText(canvas, 'Crash!', Offset(W / 2, H / 2 - 50), 36, Colors.redAccent, weight: FontWeight.w900, shadow: true);
      _drawText(canvas, 'Пройдено: $score', Offset(W / 2, H / 2 - 10), 20, Colors.white70);
      if (lastRank != null) {
        _drawText(canvas, '#$lastRank в рейтинге', Offset(W / 2, H / 2 + 24), 18, Colors.amberAccent, weight: FontWeight.w900);
      }
      _drawText(canvas, 'Нажмите для повтора', Offset(W / 2, H / 2 + 60), 15, Colors.white54);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize, Color color,
      {FontWeight weight = FontWeight.normal, bool shadow = false}) {
    if (shadow) {
      final sp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: Colors.black54, fontSize: fontSize + 1, fontWeight: weight)),
        textDirection: TextDirection.ltr,
      )..layout();
      sp.paint(canvas, Offset(center.dx - sp.width / 2 + 1, center.dy - sp.height / 2 + 1));
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _HelicopterPainter old) => true;
}
