import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

class BreakoutGame extends StatefulWidget {
  const BreakoutGame({super.key});
  @override
  State<BreakoutGame> createState() => _BreakoutGameState();
}

class _BreakoutGameState extends State<BreakoutGame> with SingleTickerProviderStateMixin {
  // Game area in virtual units 300×500
  static const double W = 300;
  static const double H = 500;
  static const double paddleW = 60;
  static const double paddleH = 12;
  static const double ballR = 8;
  static const double brickW = 34;
  static const double brickH = 14;
  static const int brickCols = 8;
  static const int brickRows = 5;
  static const double brickOffX = (W - brickCols * brickW) / 2;
  static const double brickOffY = 60;
  static const double brickGap = 2;

  double paddleX = W / 2 - paddleW / 2;
  double ballX = W / 2;
  double ballY = H - 80;
  double ballVX = 2.5;
  double ballVY = -4.0;
  late List<List<bool>> bricks; // [row][col] = alive
  int score = 0;
  int lives = 3;
  int level = 1;
  bool isPlaying = false;
  bool isGameOver = false;
  bool isWon = false;
  bool ballOnPaddle = true; // waiting for launch

  late AnimationController _anim;
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  bool _scoreSent = false;
  double _scaleX = 1; // widget to virtual coords

  @override
  void initState() {
    super.initState();
    _initBricks();
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

  void _initBricks() {
    bricks = List.generate(brickRows, (_) => List.filled(brickCols, true));
  }

  void _resetBall() {
    ballX = paddleX + paddleW / 2;
    ballY = H - 80;
    ballVX = 2.5 + (level - 1) * 0.3;
    ballVY = -(4.0 + (level - 1) * 0.3);
    ballOnPaddle = true;
  }

  int get _bricksLeft => bricks.fold(0, (sum, row) => sum + row.where((b) => b).length);

  static const _brickColors = [
    Color(0xFFF44336), // row 0 red
    Color(0xFFFF9800), // row 1 orange
    Color(0xFFFFEB3B), // row 2 yellow
    Color(0xFF4CAF50), // row 3 green
    Color(0xFF2196F3), // row 4 blue
  ];

  void _tick() {
    if (!isPlaying || isGameOver || isWon || ballOnPaddle) return;

    setState(() {
      ballX += ballVX;
      ballY += ballVY;

      // Wall bounces
      if (ballX - ballR < 0) { ballX = ballR; ballVX = ballVX.abs(); }
      if (ballX + ballR > W) { ballX = W - ballR; ballVX = -ballVX.abs(); }
      if (ballY - ballR < 0) { ballY = ballR; ballVY = ballVY.abs(); }

      // Paddle collision
      final paddleTop = H - paddleH - 20;
      if (ballY + ballR >= paddleTop && ballY + ballR <= paddleTop + paddleH + 4 &&
          ballX >= paddleX - 4 && ballX <= paddleX + paddleW + 4 && ballVY > 0) {
        ballVY = -ballVY.abs();
        // Angle based on hit position
        final rel = (ballX - paddleX) / paddleW - 0.5; // -0.5 to 0.5
        ballVX = rel * 6;
        HapticFeedback.selectionClick();
      }

      // Ball lost
      if (ballY - ballR > H) {
        lives--;
        HapticFeedback.heavyImpact();
        if (lives <= 0) {
          isGameOver = true;
          isPlaying = false;
          if (!_scoreSent && score > 0) { _scoreSent = true; _submitScore(); }
        } else {
          _resetBall();
        }
      }

      // Brick collisions
      for (int r = 0; r < brickRows; r++) {
        for (int c = 0; c < brickCols; c++) {
          if (!bricks[r][c]) continue;
          final bx = brickOffX + c * (brickW + brickGap);
          final by = brickOffY + r * (brickH + brickGap);
          if (ballX + ballR > bx && ballX - ballR < bx + brickW &&
              ballY + ballR > by && ballY - ballR < by + brickH) {
            bricks[r][c] = false;
            score += 10 * (brickRows - r); // higher rows = more points
            HapticFeedback.lightImpact();

            // Determine bounce direction
            final overlapTop = (ballY + ballR) - by;
            final overlapBottom = (by + brickH) - (ballY - ballR);
            final overlapLeft = (ballX + ballR) - bx;
            final overlapRight = (bx + brickW) - (ballX - ballR);
            final minOverlap = [overlapTop, overlapBottom, overlapLeft, overlapRight].reduce(min);
            if (minOverlap == overlapTop || minOverlap == overlapBottom) {
              ballVY = -ballVY;
            } else {
              ballVX = -ballVX;
            }

            if (_bricksLeft == 0) {
              level++;
              _initBricks();
              _resetBall();
              if (level > 3) {
                isWon = true;
                isPlaying = false;
                if (!_scoreSent) { _scoreSent = true; _submitScore(); }
              }
            }
            return; // one brick per tick
          }
        }
      }
    });
  }

  void _movePaddleTo(double widgetX) {
    final vx = widgetX / _scaleX;
    setState(() {
      paddleX = (vx - paddleW / 2).clamp(0, W - paddleW);
      if (ballOnPaddle) {
        ballX = paddleX + paddleW / 2;
      }
    });
  }

  void _launch() {
    if (!isPlaying) {
      isPlaying = true;
      if (isGameOver || isWon) {
        _initBricks();
        score = 0; lives = 3; level = 1; isGameOver = false; isWon = false; _scoreSent = false; lastRank = null;
        _resetBall();
      }
    }
    if (ballOnPaddle) {
      ballOnPaddle = false;
      ballVX = 2.5 + (level - 1) * 0.3;
      ballVY = -(4.0 + (level - 1) * 0.3);
    }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=breakout');
      if (data is Map && data['scores'] is List && mounted) {
        setState(() { leaderboard = List<Map<String, dynamic>>.from(data['scores']); });
      }
    } catch (_) {}
  }

  Future<void> _submitScore() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiPost('/game/score', {'game': 'breakout', 'score': score});
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
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0,
        title: Row(children: [
          const Text('🎯', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Breakout', style: TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          _badge('$score', Colors.red),
          const SizedBox(width: 6),
          ...List.generate(lives, (_) => const Text('❤️', style: TextStyle(fontSize: 18))),
          const SizedBox(width: 6),
          _badge('Lv$level', Colors.blue),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.leaderboard), onPressed: _showLeaderboard),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        _scaleX = box.maxWidth / W;
        final scale = min(box.maxWidth / W, box.maxHeight / H);
        return GestureDetector(
          onHorizontalDragUpdate: (d) => _movePaddleTo(d.localPosition.dx),
          onPanUpdate: (d) => _movePaddleTo(d.localPosition.dx),
          onTap: _launch,
          child: Center(
            child: SizedBox(
              width: W * scale,
              height: H * scale,
              child: CustomPaint(
                painter: _BreakoutPainter(
                  paddleX: paddleX, paddleY: H - paddleH - 20,
                  ballX: ballX, ballY: ballY,
                  bricks: bricks, brickColors: _brickColors,
                  isGameOver: isGameOver, isWon: isWon,
                  ballOnPaddle: ballOnPaddle, score: score,
                  lastRank: lastRank, level: level,
                  scale: scale,
                ),
              ),
            ),
          ),
        );
      }),
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
                Text('Рейтинг Breakout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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

class _BreakoutPainter extends CustomPainter {
  final double paddleX, paddleY, ballX, ballY, scale;
  final List<List<bool>> bricks;
  final List<Color> brickColors;
  final bool isGameOver, isWon, ballOnPaddle;
  final int score, level;
  final int? lastRank;

  _BreakoutPainter({
    required this.paddleX, required this.paddleY,
    required this.ballX, required this.ballY,
    required this.bricks, required this.brickColors,
    required this.isGameOver, required this.isWon,
    required this.ballOnPaddle, required this.score,
    required this.lastRank, required this.level, required this.scale,
  });

  static const double W = _BreakoutGameState.W;
  static const double brickW = _BreakoutGameState.brickW;
  static const double brickH = _BreakoutGameState.brickH;
  static const double brickOffX = _BreakoutGameState.brickOffX;
  static const double brickOffY = _BreakoutGameState.brickOffY;
  static const double brickGap = _BreakoutGameState.brickGap;
  static const int brickCols = _BreakoutGameState.brickCols;
  static const int brickRows = _BreakoutGameState.brickRows;
  static const double paddleW = _BreakoutGameState.paddleW;
  static const double paddleH = _BreakoutGameState.paddleH;
  static const double ballR = _BreakoutGameState.ballR;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale, scale);

    // Bricks
    for (int r = 0; r < brickRows; r++) {
      for (int c = 0; c < brickCols; c++) {
        if (!bricks[r][c]) continue;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            brickOffX + c * (brickW + brickGap),
            brickOffY + r * (brickH + brickGap),
            brickW, brickH,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, Paint()..color = brickColors[r]);
        canvas.drawRRect(rect, Paint()..color = Colors.white.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 1);
      }
    }

    // Paddle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(paddleX, paddleY, paddleW, paddleH),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white,
    );

    // Ball
    canvas.drawCircle(
      Offset(ballX, ballY),
      ballR,
      Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(ballX, ballY), ballR, Paint()..color = Colors.white);

    // Launch hint
    if (ballOnPaddle && !isGameOver && !isWon) {
      final tp = TextPainter(
        text: const TextSpan(text: 'Нажмите для запуска', style: TextStyle(color: Colors.white54, fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(W / 2 - tp.width / 2, paddleY - 30));
    }

    // Overlay
    if (isGameOver || isWon) {
      canvas.drawRect(Rect.fromLTWH(0, 0, W, _BreakoutGameState.H), Paint()..color = Colors.black54);
      final lines = isWon
          ? ['🎉 Победа!', 'Счёт: $score', if (lastRank != null) '#$lastRank в рейтинге', 'Нажмите для рестарта']
          : ['Game Over', 'Счёт: $score', if (lastRank != null) '#$lastRank в рейтинге', 'Нажмите для рестарта'];
      double y = _BreakoutGameState.H / 2 - 50;
      for (final line in lines) {
        final tp = TextPainter(
          text: TextSpan(text: line, style: TextStyle(
            color: line.startsWith('#') ? Colors.amberAccent : Colors.white,
            fontSize: line.contains('Счёт') ? 20 : 26,
            fontWeight: FontWeight.w900,
          )),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(W / 2 - tp.width / 2, y));
        y += 36;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BreakoutPainter old) => true;
}
