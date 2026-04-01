import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

class FlappyGame extends StatefulWidget {
  const FlappyGame({super.key});
  @override
  State<FlappyGame> createState() => _FlappyGameState();
}

class _FlappyGameState extends State<FlappyGame> with SingleTickerProviderStateMixin {
  // Virtual coords 300×500
  static const double W = 300;
  static const double H = 500;
  static const double birdX = 70;
  static const double birdR = 16;
  static const double pipeW = 52;
  static const double gapH = 130;
  static const double gravity = 0.4;
  static const double flapVY = -8.0;

  double birdY = H / 2;
  double birdVY = 0;
  double birdAngle = 0;
  // Pipes: each = {x, topH}
  List<Map<String, double>> pipes = [];
  double pipeSpeedX = 2.5;
  int score = 0;
  int bestScore = 0;
  bool isPlaying = false;
  bool isGameOver = false;
  bool started = false;

  late AnimationController _anim;
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  bool _scoreSent = false;
  double _scale = 1;
  final random = Random();

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
    birdY = H / 2;
    birdVY = 0;
    birdAngle = 0;
    pipes = [];
    score = 0;
    isGameOver = false;
    started = false;
    _scoreSent = false;
    lastRank = null;
    _spawnPipe();
  }

  void _spawnPipe() {
    final topH = 80.0 + random.nextDouble() * (H - gapH - 160);
    pipes.add({'x': W + 10, 'topH': topH});
  }

  void _flap() {
    if (isGameOver) {
      setState(() {
        isPlaying = false;
        _reset();
      });
      return;
    }
    if (!started) {
      started = true;
      isPlaying = true;
    }
    setState(() {
      birdVY = flapVY;
      HapticFeedback.lightImpact();
    });
  }

  void _tick() {
    if (!isPlaying || isGameOver) return;
    setState(() {
      // Bird physics
      birdVY += gravity;
      birdY += birdVY;
      birdAngle = (birdVY / 10).clamp(-0.5, 1.0);

      // Ceiling / floor
      if (birdY - birdR < 0 || birdY + birdR > H) {
        _die();
        return;
      }

      // Move pipes
      for (final pipe in pipes) {
        pipe['x'] = pipe['x']! - pipeSpeedX;
      }

      // Remove old pipes and spawn new
      if (pipes.isNotEmpty && pipes.first['x']! < -pipeW - 10) {
        pipes.removeAt(0);
        _spawnPipe();
      }
      if (pipes.length < 3 && (pipes.isEmpty || pipes.last['x']! < W - 160)) {
        _spawnPipe();
      }

      // Score + collision
      for (final pipe in pipes) {
        final px = pipe['x']!;
        final topH = pipe['topH']!;
        // Score when bird passes pipe center
        if (px + pipeW / 2 < birdX && px + pipeW / 2 > birdX - pipeSpeedX) {
          score++;
          pipeSpeedX = 2.5 + score * 0.08;
          HapticFeedback.mediumImpact();
        }
        // Collision
        if (birdX + birdR > px && birdX - birdR < px + pipeW) {
          if (birdY - birdR < topH || birdY + birdR > topH + gapH) {
            _die();
            return;
          }
        }
      }
    });
  }

  void _die() {
    isGameOver = true;
    isPlaying = false;
    if (score > bestScore) bestScore = score;
    HapticFeedback.heavyImpact();
    if (!_scoreSent && score > 0) { _scoreSent = true; _submitScore(); }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=flappy');
      if (data is Map && data['scores'] is List && mounted) {
        setState(() { leaderboard = List<Map<String, dynamic>>.from(data['scores']); });
      }
    } catch (_) {}
  }

  Future<void> _submitScore() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiPost('/game/score', {'game': 'flappy', 'score': score});
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
      backgroundColor: const Color(0xFF4DC9F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E9AC8), foregroundColor: Colors.white, elevation: 0,
        title: Row(children: [
          const Text('🐦', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Flappy Bird', style: TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          _badge('$score', Colors.white),
          if (bestScore > 0) ...[const SizedBox(width: 8), _badge('best: $bestScore', Colors.yellow)],
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.leaderboard), onPressed: _showLeaderboard),
        ],
      ),
      body: GestureDetector(
        onTap: _flap,
        child: LayoutBuilder(builder: (context, box) {
          _scale = min(box.maxWidth / W, box.maxHeight / H);
          return Center(
            child: SizedBox(
              width: W * _scale,
              height: H * _scale,
              child: CustomPaint(
                painter: _FlappyPainter(
                  birdY: birdY, birdAngle: birdAngle,
                  pipes: pipes, score: score,
                  isGameOver: isGameOver, started: started,
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
    decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
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
                Text('Рейтинг Flappy Bird', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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

class _FlappyPainter extends CustomPainter {
  final double birdY, birdAngle;
  final List<Map<String, double>> pipes;
  final int score;
  final bool isGameOver, started;
  final int? lastRank;

  _FlappyPainter({
    required this.birdY, required this.birdAngle,
    required this.pipes, required this.score,
    required this.isGameOver, required this.started,
    required this.lastRank,
  });

  static const double W = _FlappyGameState.W;
  static const double H = _FlappyGameState.H;
  static const double birdX = _FlappyGameState.birdX;
  static const double birdR = _FlappyGameState.birdR;
  static const double pipeW = _FlappyGameState.pipeW;
  static const double gapH = _FlappyGameState.gapH;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / W;
    canvas.scale(scale, scale);

    // Ground
    canvas.drawRect(
      Rect.fromLTWH(0, H - 40, W, 40),
      Paint()..color = const Color(0xFF8B6914),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, H - 40, W, 8),
      Paint()..color = const Color(0xFF5DB025),
    );

    // Pipes
    for (final pipe in pipes) {
      final px = pipe['x']!;
      final topH = pipe['topH']!;
      final pipePaint = Paint()..color = const Color(0xFF4CAF50);
      final capPaint = Paint()..color = const Color(0xFF388E3C);
      // Top pipe
      canvas.drawRect(Rect.fromLTWH(px + 4, 0, pipeW - 8, topH - 14), pipePaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(px, topH - 14, pipeW, 14), const Radius.circular(3)), capPaint);
      // Bottom pipe
      final botY = topH + gapH;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(px, botY, pipeW, 14), const Radius.circular(3)), capPaint);
      canvas.drawRect(Rect.fromLTWH(px + 4, botY + 14, pipeW - 8, H - botY - 14 - 40), pipePaint);
    }

    // Bird
    canvas.save();
    canvas.translate(birdX, birdY);
    canvas.rotate(birdAngle);
    // Body
    canvas.drawCircle(Offset.zero, birdR, Paint()..color = const Color(0xFFF39C12));
    // Eye
    canvas.drawCircle(const Offset(6, -4), 5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(7, -4), 2.5, Paint()..color = Colors.black);
    // Beak
    final beakPath = Path()..moveTo(birdR - 2, 0)..lineTo(birdR + 8, -3)..lineTo(birdR + 8, 3)..close();
    canvas.drawPath(beakPath, Paint()..color = Colors.orange[700]!);
    // Wing
    canvas.drawOval(Rect.fromCenter(center: const Offset(-3, 4), width: 14, height: 8),
        Paint()..color = const Color(0xFFE67E22));
    canvas.restore();

    // Score text
    _drawText(canvas, '$score', const Offset(W / 2, 40), 36, Colors.white,
        shadow: true, weight: FontWeight.w900);

    // Hint / overlay
    if (!started && !isGameOver) {
      _drawText(canvas, 'Нажмите для старта', Offset(W / 2, H / 2 + 50), 18, Colors.white,
          shadow: true);
    }

    if (isGameOver) {
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.black45);
      _drawText(canvas, 'Game Over', Offset(W / 2, H / 2 - 50), 32, Colors.white,
          shadow: true, weight: FontWeight.w900);
      _drawText(canvas, 'Пролетело труб: $score', Offset(W / 2, H / 2 - 10), 20, Colors.white70);
      if (lastRank != null) {
        _drawText(canvas, '#$lastRank в рейтинге', Offset(W / 2, H / 2 + 24), 18, Colors.amberAccent,
            weight: FontWeight.w900);
      }
      _drawText(canvas, 'Нажмите для повтора', Offset(W / 2, H / 2 + 56), 16, Colors.white70);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize, Color color,
      {bool shadow = false, FontWeight weight = FontWeight.normal}) {
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
  bool shouldRepaint(covariant _FlappyPainter old) => true;
}
