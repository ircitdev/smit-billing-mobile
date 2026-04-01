import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

class PacmanGame extends StatefulWidget {
  const PacmanGame({super.key});

  @override
  State<PacmanGame> createState() => _PacmanGameState();
}

class _PacmanGameState extends State<PacmanGame> with SingleTickerProviderStateMixin {
  static const int rows = 21;
  static const int cols = 21;
  static const Duration tickSpeed = Duration(milliseconds: 180);

  // Maze: 0=wall, 1=dot, 2=empty, 3=power pellet, 4=gate
  late List<List<int>> maze;
  // Pacman
  Point<int> pacman = const Point(10, 15);
  Point<int> direction = const Point(0, 0);
  Point<int> nextDirection = const Point(0, 0);
  int mouthAngle = 0; // 0-2 animation frame
  // Ghosts
  late List<_Ghost> ghosts;
  // State
  Timer? timer;
  Timer? mouthTimer;
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int bestScore = 0;
  int dotsLeft = 0;
  bool powerMode = false;
  Timer? powerTimer;
  int lives = 3;
  int level = 1;
  // Leaderboard
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  final random = Random();

  // Classic maze layout (symmetric)
  static const _mazeTemplate = [
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0],
    [0,1,0,0,1,0,0,0,0,1,0,1,0,0,0,0,1,0,0,1,0],
    [0,3,0,0,1,0,0,0,0,1,0,1,0,0,0,0,1,0,0,3,0],
    [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
    [0,1,0,0,1,0,1,0,0,0,0,0,0,0,1,0,1,0,0,1,0],
    [0,1,1,1,1,0,1,1,1,0,0,0,1,1,1,0,1,1,1,1,0],
    [0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,0],
    [0,0,0,0,1,0,2,2,2,2,2,2,2,2,2,0,1,0,0,0,0],
    [0,0,0,0,1,0,2,0,0,4,4,4,0,0,2,0,1,0,0,0,0],
    [2,2,2,2,1,2,2,0,2,2,2,2,2,0,2,2,1,2,2,2,2],
    [0,0,0,0,1,0,2,0,0,0,0,0,0,0,2,0,1,0,0,0,0],
    [0,0,0,0,1,0,2,2,2,2,2,2,2,2,2,0,1,0,0,0,0],
    [0,0,0,0,1,0,2,0,0,0,0,0,0,0,2,0,1,0,0,0,0],
    [0,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,0],
    [0,1,0,0,1,0,0,0,0,1,0,1,0,0,0,0,1,0,0,1,0],
    [0,3,1,0,1,1,1,1,1,1,2,1,1,1,1,1,1,0,1,3,0],
    [0,0,1,0,1,0,1,0,0,0,0,0,0,0,1,0,1,0,1,0,0],
    [0,1,1,1,1,0,1,1,1,0,0,0,1,1,1,0,1,1,1,1,0],
    [0,1,0,0,0,0,0,0,1,1,0,1,1,0,0,0,0,0,0,1,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
  ];

  static const _ghostColors = [
    Color(0xFFFF0000), // Blinky (red)
    Color(0xFFFFB8FF), // Pinky (pink)
    Color(0xFF00FFFF), // Inky (cyan)
    Color(0xFFFFB852), // Clyde (orange)
  ];

  static const _ghostStarts = [
    Point(10, 9),
    Point(9, 10),
    Point(10, 10),
    Point(11, 10),
  ];

  @override
  void initState() {
    super.initState();
    _reset();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    timer?.cancel();
    mouthTimer?.cancel();
    powerTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    maze = _mazeTemplate.map((row) => List<int>.from(row)).toList();
    pacman = const Point(10, 15);
    direction = const Point(0, 0);
    nextDirection = const Point(0, 0);
    mouthAngle = 0;
    score = 0;
    dotsLeft = 0;
    powerMode = false;
    isGameOver = false;
    lives = 3;
    level = 1;
    lastRank = null;
    powerTimer?.cancel();

    // Count dots
    for (var row in maze) {
      for (var cell in row) {
        if (cell == 1 || cell == 3) dotsLeft++;
      }
    }

    // Init ghosts
    ghosts = List.generate(4, (i) => _Ghost(
      pos: Point(_ghostStarts[i].x, _ghostStarts[i].y),
      color: _ghostColors[i],
      dir: const Point(0, -1),
      home: _ghostStarts[i],
    ));
  }

  void _start() {
    if (isGameOver) _reset();
    isPlaying = true;
    timer?.cancel();
    timer = Timer.periodic(tickSpeed, (_) => _tick());
    mouthTimer?.cancel();
    mouthTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) setState(() => mouthAngle = (mouthAngle + 1) % 3);
    });
    setState(() {});
  }

  void _pause() {
    isPlaying = false;
    timer?.cancel();
    mouthTimer?.cancel();
    setState(() {});
  }

  bool _canMove(Point<int> pos, Point<int> dir) {
    int nx = (pos.x + dir.x) % cols;
    int ny = (pos.y + dir.y) % rows;
    if (nx < 0) nx += cols;
    if (ny < 0) ny += rows;
    final cell = maze[ny][nx];
    return cell != 0; // can walk on 1,2,3,4
  }

  void _tick() {
    // Try next direction first
    if (nextDirection != const Point(0, 0) && _canMove(pacman, nextDirection)) {
      direction = nextDirection;
    }

    if (direction == const Point(0, 0) || !_canMove(pacman, direction)) {
      _moveGhosts();
      _checkGhostCollision();
      setState(() {});
      return;
    }

    // Move pacman
    int nx = (pacman.x + direction.x) % cols;
    int ny = (pacman.y + direction.y) % rows;
    if (nx < 0) nx += cols;
    if (ny < 0) ny += rows;
    pacman = Point(nx, ny);

    // Eat dot
    final cell = maze[ny][nx];
    if (cell == 1) {
      maze[ny][nx] = 2;
      score += 10;
      dotsLeft--;
      HapticFeedback.selectionClick();
    } else if (cell == 3) {
      maze[ny][nx] = 2;
      score += 50;
      dotsLeft--;
      _activatePowerMode();
      HapticFeedback.mediumImpact();
    }

    // Level clear
    if (dotsLeft <= 0) {
      _nextLevel();
      return;
    }

    // Move ghosts
    _moveGhosts();
    _checkGhostCollision();
    setState(() {});
  }

  void _activatePowerMode() {
    powerMode = true;
    for (var g in ghosts) g.scared = true;
    powerTimer?.cancel();
    powerTimer = Timer(Duration(seconds: max(3, 8 - level)), () {
      if (mounted) {
        setState(() {
          powerMode = false;
          for (var g in ghosts) g.scared = false;
        });
      }
    });
  }

  void _moveGhosts() {
    for (var ghost in ghosts) {
      if (ghost.eaten) {
        // Return to home
        if (ghost.pos == ghost.home) {
          ghost.eaten = false;
          ghost.scared = powerMode;
          continue;
        }
        // Move toward home
        _moveGhostToward(ghost, ghost.home);
        continue;
      }

      // Possible directions (exclude reverse)
      final reverse = Point(-ghost.dir.x, -ghost.dir.y);
      final dirs = [
        const Point(0, -1), const Point(0, 1),
        const Point(-1, 0), const Point(1, 0),
      ].where((d) => d != reverse && _canMoveGhost(ghost.pos, d)).toList();

      if (dirs.isEmpty) {
        // Try reverse
        if (_canMoveGhost(ghost.pos, reverse)) {
          dirs.add(reverse);
        } else {
          continue;
        }
      }

      if (ghost.scared) {
        // Run away from pacman
        dirs.sort((a, b) {
          final da = _dist(Point(ghost.pos.x + a.x, ghost.pos.y + a.y), pacman);
          final db = _dist(Point(ghost.pos.x + b.x, ghost.pos.y + b.y), pacman);
          return db.compareTo(da); // farthest first
        });
      } else {
        // Chase pacman (with some randomness)
        if (random.nextDouble() < 0.7) {
          dirs.sort((a, b) {
            final da = _dist(Point(ghost.pos.x + a.x, ghost.pos.y + a.y), pacman);
            final db = _dist(Point(ghost.pos.x + b.x, ghost.pos.y + b.y), pacman);
            return da.compareTo(db); // closest first
          });
        } else {
          dirs.shuffle(random);
        }
      }

      final chosen = dirs.first;
      ghost.dir = chosen;
      int gx = (ghost.pos.x + chosen.x) % cols;
      int gy = (ghost.pos.y + chosen.y) % rows;
      if (gx < 0) gx += cols;
      if (gy < 0) gy += rows;
      ghost.pos = Point(gx, gy);
    }
  }

  bool _canMoveGhost(Point<int> pos, Point<int> dir) {
    int nx = (pos.x + dir.x) % cols;
    int ny = (pos.y + dir.y) % rows;
    if (nx < 0) nx += cols;
    if (ny < 0) ny += rows;
    final cell = maze[ny][nx];
    return cell != 0; // ghosts can walk on dots, empty, gate, power
  }

  void _moveGhostToward(_Ghost ghost, Point<int> target) {
    final dirs = [
      const Point(0, -1), const Point(0, 1),
      const Point(-1, 0), const Point(1, 0),
    ].where((d) => _canMoveGhost(ghost.pos, d)).toList();
    if (dirs.isEmpty) return;
    dirs.sort((a, b) {
      final da = _dist(Point(ghost.pos.x + a.x, ghost.pos.y + a.y), target);
      final db = _dist(Point(ghost.pos.x + b.x, ghost.pos.y + b.y), target);
      return da.compareTo(db);
    });
    final chosen = dirs.first;
    ghost.dir = chosen;
    int gx = (ghost.pos.x + chosen.x) % cols;
    int gy = (ghost.pos.y + chosen.y) % rows;
    if (gx < 0) gx += cols;
    if (gy < 0) gy += rows;
    ghost.pos = Point(gx, gy);
  }

  double _dist(Point<int> a, Point<int> b) =>
      sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2).toDouble());

  void _checkGhostCollision() {
    for (var ghost in ghosts) {
      if (ghost.pos == pacman && !ghost.eaten) {
        if (ghost.scared) {
          // Eat ghost
          ghost.eaten = true;
          score += 200;
          HapticFeedback.heavyImpact();
        } else {
          // Lose life
          lives--;
          HapticFeedback.heavyImpact();
          if (lives <= 0) {
            _gameOver();
          } else {
            // Reset positions
            pacman = const Point(10, 15);
            direction = const Point(0, 0);
            nextDirection = const Point(0, 0);
            for (int i = 0; i < ghosts.length; i++) {
              ghosts[i].pos = Point(_ghostStarts[i].x, _ghostStarts[i].y);
              ghosts[i].dir = const Point(0, -1);
              ghosts[i].scared = false;
              ghosts[i].eaten = false;
            }
            powerMode = false;
            powerTimer?.cancel();
          }
          return;
        }
      }
    }
  }

  void _nextLevel() {
    level++;
    timer?.cancel();
    // Reset maze with dots
    maze = _mazeTemplate.map((row) => List<int>.from(row)).toList();
    dotsLeft = 0;
    for (var row in maze) {
      for (var cell in row) {
        if (cell == 1 || cell == 3) dotsLeft++;
      }
    }
    pacman = const Point(10, 15);
    direction = const Point(0, 0);
    nextDirection = const Point(0, 0);
    for (int i = 0; i < ghosts.length; i++) {
      ghosts[i].pos = Point(_ghostStarts[i].x, _ghostStarts[i].y);
      ghosts[i].dir = const Point(0, -1);
      ghosts[i].scared = false;
      ghosts[i].eaten = false;
    }
    powerMode = false;
    powerTimer?.cancel();
    // Restart with faster speed
    final speed = Duration(milliseconds: max(80, 180 - (level - 1) * 15));
    timer = Timer.periodic(speed, (_) => _tick());
    setState(() {});
  }

  void _gameOver() {
    timer?.cancel();
    mouthTimer?.cancel();
    powerTimer?.cancel();
    isPlaying = false;
    isGameOver = true;
    if (score > bestScore) bestScore = score;
    if (score > 0) _submitScore();
    setState(() {});
  }

  void _setDirection(Point<int> dir) {
    nextDirection = dir;
  }

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=pacman');
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
      final data = await acc.apiPost('/game/score', {'game': 'pacman', 'score': score});
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
      backgroundColor: const Color(0xFF000020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.yellow,
        elevation: 0,
        title: Row(
          children: [
            const Text('PAC-MAN', style: TextStyle(
              fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2,
            )),
            const Spacer(),
            _scoreBadge(score),
            const SizedBox(width: 8),
            // Lives
            for (int i = 0; i < lives; i++)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text('ᗧ', style: TextStyle(color: Colors.yellow, fontSize: 16)),
              ),
          ],
        ),
        actions: [
          if (level > 1)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text('LV$level',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Рейтинг',
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
                          // Maze
                          CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: _MazePainter(maze: maze, rows: rows, cols: cols),
                          ),
                          // Dots & power pellets
                          for (int y = 0; y < rows; y++)
                            for (int x = 0; x < cols; x++)
                              if (maze[y][x] == 1)
                                Positioned(
                                  left: x * cellW + cellW * 0.35,
                                  top: y * cellH + cellH * 0.35,
                                  child: Container(
                                    width: cellW * 0.3, height: cellH * 0.3,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFB8AE),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              else if (maze[y][x] == 3)
                                Positioned(
                                  left: x * cellW + cellW * 0.15,
                                  top: y * cellH + cellH * 0.15,
                                  child: Container(
                                    width: cellW * 0.7, height: cellH * 0.7,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(
                                          mouthAngle == 0 ? 1.0 : 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                          // Ghosts
                          for (var ghost in ghosts)
                            if (!ghost.eaten)
                              Positioned(
                                left: ghost.pos.x * cellW,
                                top: ghost.pos.y * cellH,
                                child: SizedBox(
                                  width: cellW, height: cellH,
                                  child: Center(
                                    child: Text(
                                      ghost.scared ? '👻' : '👾',
                                      style: TextStyle(
                                        fontSize: cellW * 0.75,
                                        color: ghost.scared
                                            ? const Color(0xFF2121FF)
                                            : ghost.color,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Positioned(
                                left: ghost.pos.x * cellW,
                                top: ghost.pos.y * cellH,
                                child: SizedBox(
                                  width: cellW, height: cellH,
                                  child: Center(
                                    child: Text('👀',
                                      style: TextStyle(fontSize: cellW * 0.5)),
                                  ),
                                ),
                              ),
                          // Pacman
                          Positioned(
                            left: pacman.x * cellW,
                            top: pacman.y * cellH,
                            child: SizedBox(
                              width: cellW, height: cellH,
                              child: CustomPaint(
                                painter: _PacmanPainter(
                                  direction: direction,
                                  mouthAngle: mouthAngle,
                                  powerMode: powerMode,
                                ),
                              ),
                            ),
                          ),
                          // Overlay
                          if (!isPlaying)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.yellow.withOpacity(0.5)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isGameOver) ...[
                                      const Text('GAME OVER',
                                          style: TextStyle(color: Colors.red, fontSize: 28, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 8),
                                      Text('Очки: $score',
                                          style: const TextStyle(color: Colors.yellow, fontSize: 18)),
                                      if (lastRank != null) ...[
                                        const SizedBox(height: 4),
                                        Text('Место: #$lastRank',
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
                                      const Text('ᗧ···', style: TextStyle(
                                        color: Colors.yellow, fontSize: 42,
                                      )),
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
        decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: Text('$s', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.yellow)),
      );

  Widget _overlayButton(String label, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.yellow, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w600)),
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

class _Ghost {
  Point<int> pos;
  Color color;
  Point<int> dir;
  Point<int> home;
  bool scared;
  bool eaten;

  _Ghost({
    required this.pos,
    required this.color,
    required this.dir,
    required this.home,
    this.scared = false,
    this.eaten = false,
  });
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
        decoration: BoxDecoration(
          color: Colors.yellow.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.yellow.withOpacity(0.7), size: 32),
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  final List<List<int>> maze;
  final int rows, cols;

  _MazePainter({required this.maze, required this.rows, required this.cols});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final wallPaint = Paint()..color = const Color(0xFF2121DE);
    final gatePaint = Paint()
      ..color = const Color(0xFFFFB8FF)
      ..strokeWidth = 2;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (maze[y][x] == 0) {
          // Draw wall with rounded edges
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x * cellW + 0.5, y * cellH + 0.5, cellW - 1, cellH - 1),
            const Radius.circular(2),
          );
          canvas.drawRRect(rect, wallPaint);
        } else if (maze[y][x] == 4) {
          // Gate
          canvas.drawLine(
            Offset(x * cellW, y * cellH + cellH / 2),
            Offset(x * cellW + cellW, y * cellH + cellH / 2),
            gatePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => false;
}

class _PacmanPainter extends CustomPainter {
  final Point<int> direction;
  final int mouthAngle;
  final bool powerMode;

  _PacmanPainter({
    required this.direction,
    required this.mouthAngle,
    required this.powerMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    final paint = Paint()
      ..color = powerMode ? const Color(0xFFFFFF00) : const Color(0xFFFFFF00);

    // Mouth opening angles
    final mouth = [0.15, 0.35, 0.15][mouthAngle];

    // Rotation based on direction
    double startAngle = 0;
    if (direction.x == 1) startAngle = 0;
    else if (direction.x == -1) startAngle = pi;
    else if (direction.y == -1) startAngle = -pi / 2;
    else if (direction.y == 1) startAngle = pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + mouth * pi,
      (2 - 2 * mouth) * pi,
      true,
      paint,
    );

    // Eye
    final eyeOffset = Offset(
      center.dx + cos(startAngle - 0.5) * radius * 0.4,
      center.dy + sin(startAngle - 0.5) * radius * 0.4,
    );
    canvas.drawCircle(eyeOffset, radius * 0.12,
        Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant _PacmanPainter old) =>
      old.mouthAngle != mouthAngle || old.direction != direction || old.powerMode != powerMode;
}
