import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  static const int rows = 20;
  static const int cols = 20;
  static const Duration tickSpeed = Duration(milliseconds: 150);

  List<Point<int>> snake = [];
  Point<int> food = const Point(10, 10);
  Point<int> direction = const Point(1, 0);
  Point<int> nextDirection = const Point(1, 0);
  Timer? timer;
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int bestScore = 0;
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  final random = Random();

  @override
  void initState() {
    super.initState();
    _reset();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _reset() {
    snake = [const Point(5, 10), const Point(4, 10), const Point(3, 10)];
    direction = const Point(1, 0);
    nextDirection = const Point(1, 0);
    score = 0;
    isGameOver = false;
    lastRank = null;
    _spawnFood();
  }

  void _spawnFood() {
    Point<int> p;
    do {
      p = Point(random.nextInt(cols), random.nextInt(rows));
    } while (snake.contains(p));
    food = p;
  }

  void _start() {
    if (isGameOver) _reset();
    isPlaying = true;
    timer?.cancel();
    timer = Timer.periodic(tickSpeed, (_) => _tick());
    setState(() {});
  }

  void _pause() {
    isPlaying = false;
    timer?.cancel();
    setState(() {});
  }

  void _tick() {
    direction = nextDirection;
    final head = snake.first;
    final newHead = Point(
      (head.x + direction.x) % cols,
      (head.y + direction.y) % rows,
    );

    if (snake.contains(newHead)) {
      timer?.cancel();
      isPlaying = false;
      isGameOver = true;
      if (score > bestScore) bestScore = score;
      HapticFeedback.heavyImpact();
      if (score > 0) _submitScore();
      setState(() {});
      return;
    }

    snake.insert(0, newHead);
    if (newHead == food) {
      score++;
      HapticFeedback.lightImpact();
      _spawnFood();
    } else {
      snake.removeLast();
    }
    setState(() {});
  }

  void _setDirection(Point<int> dir) {
    if (dir.x == -direction.x && dir.y == -direction.y) return;
    nextDirection = dir;
  }

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=snake');
      if (data is Map && data['scores'] is List && mounted) {
        setState(() {
          leaderboard = List<Map<String, dynamic>>.from(data['scores']);
        });
      }
    } catch (_) {}
  }

  Future<void> _submitScore() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiPost('/game/score', {'game': 'snake', 'score': score});
      if (data is Map && mounted) {
        setState(() {
          lastRank = data['rank'];
          if (data['board'] is List) {
            leaderboard = List<Map<String, dynamic>>.from(data['board']);
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text('🐍', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('Snake', style: TextStyle(fontWeight: FontWeight.w900)),
            const Spacer(),
            _scoreBadge(score),
            if (bestScore > 0) ...[
              const SizedBox(width: 8),
              Text('best: $bestScore',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Таблица лидеров',
            onPressed: () => _showLeaderboard(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: (d) {
                if (d.delta.dy > 3) _setDirection(const Point(0, 1));
                if (d.delta.dy < -3) _setDirection(const Point(0, -1));
              },
              onHorizontalDragUpdate: (d) {
                if (d.delta.dx > 3) _setDirection(const Point(1, 0));
                if (d.delta.dx < -3) _setDirection(const Point(-1, 0));
              },
              onTap: () {
                if (!isPlaying) _start(); else _pause();
              },
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final cellW = constraints.maxWidth / cols;
                      final cellH = constraints.maxHeight / rows;
                      return Stack(
                        children: [
                          CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: _GridPainter(rows: rows, cols: cols, color: Colors.white.withOpacity(0.05)),
                          ),
                          // Food
                          Positioned(
                            left: food.x * cellW, top: food.y * cellH,
                            child: SizedBox(
                              width: cellW - 1, height: cellH - 1,
                              child: Center(child: Text('🍎', style: TextStyle(fontSize: cellW * 0.7))),
                            ),
                          ),
                          // Snake
                          for (int i = 0; i < snake.length; i++)
                            Positioned(
                              left: snake[i].x * cellW, top: snake[i].y * cellH,
                              child: Container(
                                width: cellW - 1, height: cellH - 1,
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? const Color(0xFF66BB6A)
                                      : Color.lerp(const Color(0xFF43A047), const Color(0xFF2E7D32), i / snake.length),
                                  borderRadius: BorderRadius.circular(i == 0 ? cellW / 3 : cellW / 5),
                                ),
                                child: i == 0
                                    ? Center(child: Container(width: cellW * 0.3, height: cellW * 0.3,
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))
                                    : null,
                              ),
                            ),
                          // Overlay
                          if (!isPlaying)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isGameOver) ...[
                                      const Text('Game Over',
                                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 8),
                                      Text('Очки: $score',
                                          style: const TextStyle(color: Colors.white70, fontSize: 18)),
                                      if (lastRank != null) ...[
                                        const SizedBox(height: 4),
                                        Text('Место в рейтинге: #$lastRank',
                                            style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.w700)),
                                      ],
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _overlayButton('Ещё раз', Icons.refresh, () => _start()),
                                          const SizedBox(width: 12),
                                          _overlayButton('Рейтинг', Icons.leaderboard, () => _showLeaderboard()),
                                        ],
                                      ),
                                    ] else ...[
                                      const Text('🐍', style: TextStyle(fontSize: 48)),
                                      const SizedBox(height: 12),
                                      Text('Нажмите чтобы начать',
                                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          // D-pad
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 140,
                child: Column(
                  children: [
                    _DpadButton(icon: Icons.keyboard_arrow_up, onTap: () => _setDirection(const Point(0, -1))),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DpadButton(icon: Icons.keyboard_arrow_left, onTap: () => _setDirection(const Point(-1, 0))),
                        const SizedBox(width: 48),
                        _DpadButton(icon: Icons.keyboard_arrow_right, onTap: () => _setDirection(const Point(1, 0))),
                      ],
                    ),
                    _DpadButton(icon: Icons.keyboard_arrow_down, onTap: () => _setDirection(const Point(0, 1))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(int s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: Text('$s', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
      );

  Widget _overlayButton(String label, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 8),
                    Text('Таблица лидеров', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Expanded(
                child: leaderboard.isEmpty
                    ? const Center(child: Text('Пока нет рекордов.\nБудьте первым!', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: leaderboard.length,
                        itemBuilder: (_, i) {
                          final e = leaderboard[i];
                          final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
                          return ListTile(
                            leading: SizedBox(
                              width: 36,
                              child: Center(child: Text(medal, style: TextStyle(fontSize: i < 3 ? 24 : 16))),
                            ),
                            title: Text(e['name'] ?? '???', style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Text(
                              '${e['score']}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: i < 3 ? Colors.amber[700] : null,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DpadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DpadButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        width: 48, height: 44,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white70, size: 32),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final int rows, cols;
  final Color color;
  _GridPainter({required this.rows, required this.cols, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.5;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    for (int i = 0; i <= cols; i++) canvas.drawLine(Offset(i * cellW, 0), Offset(i * cellW, size.height), paint);
    for (int i = 0; i <= rows; i++) canvas.drawLine(Offset(0, i * cellH), Offset(size.width, i * cellH), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
