import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

// Tetromino definitions: each shape = list of [row, col] offsets from pivot
const _pieces = [
  // I
  [[-1,0],[0,0],[1,0],[2,0]],
  // O
  [[0,0],[0,1],[1,0],[1,1]],
  // T
  [[0,-1],[0,0],[0,1],[-1,0]],
  // S
  [[0,0],[0,1],[-1,-1],[-1,0]],
  // Z
  [[0,-1],[0,0],[-1,0],[-1,1]],
  // J
  [[0,-1],[0,0],[0,1],[-1,-1]],
  // L
  [[0,-1],[0,0],[0,1],[-1,1]],
];

const _pieceColors = [
  Color(0xFF00BCD4), // I - cyan
  Color(0xFFFFEB3B), // O - yellow
  Color(0xFF9C27B0), // T - purple
  Color(0xFF4CAF50), // S - green
  Color(0xFFF44336), // Z - red
  Color(0xFF2196F3), // J - blue
  Color(0xFFFF9800), // L - orange
];

class TetrisGame extends StatefulWidget {
  const TetrisGame({super.key});
  @override
  State<TetrisGame> createState() => _TetrisGameState();
}

class _TetrisGameState extends State<TetrisGame> {
  static const int rows = 20;
  static const int cols = 10;

  // Board: -1 = empty, 0-6 = piece color index
  late List<List<int>> board;
  // Current piece
  int pieceType = 0;
  int pieceColor = 0;
  int pieceRow = 0;
  int pieceCol = 5;
  List<List<int>> pieceCells = [];
  // Next piece
  int nextType = 0;
  // State
  Timer? timer;
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int bestScore = 0;
  int level = 1;
  int linesCleared = 0;
  // Leaderboard
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  final random = Random();

  @override
  void initState() {
    super.initState();
    _initBoard();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _initBoard() {
    board = List.generate(rows, (_) => List.filled(cols, -1));
    nextType = random.nextInt(_pieces.length);
  }

  Duration get _tickSpeed => Duration(milliseconds: max(100, 500 - (level - 1) * 40));

  List<List<int>> _rotatedCells(List<List<int>> cells) {
    // Rotate 90° clockwise: [r,c] → [c, -r]
    return cells.map((c) => [-c[1], c[0]]).toList();
  }

  bool _isValid(int pr, int pc, List<List<int>> cells) {
    for (final c in cells) {
      final r = pr + c[0];
      final col = pc + c[1];
      if (r < 0 || r >= rows || col < 0 || col >= cols) return false;
      if (r >= 0 && board[r][col] != -1) return false;
    }
    return true;
  }

  void _spawnPiece() {
    pieceType = nextType;
    pieceColor = pieceType;
    nextType = random.nextInt(_pieces.length);
    pieceCells = _pieces[pieceType].map((c) => List<int>.from(c)).toList();
    pieceRow = 0;
    pieceCol = cols ~/ 2;
    if (!_isValid(pieceRow, pieceCol, pieceCells)) {
      isGameOver = true;
      isPlaying = false;
      timer?.cancel();
      if (score > bestScore) bestScore = score;
      HapticFeedback.heavyImpact();
      if (score > 0) _submitScore();
    }
  }

  void _lockPiece() {
    for (final c in pieceCells) {
      final r = pieceRow + c[0];
      final col = pieceCol + c[1];
      if (r >= 0 && r < rows && col >= 0 && col < cols) {
        board[r][col] = pieceColor;
      }
    }
    _clearLines();
    _spawnPiece();
  }

  void _clearLines() {
    int cleared = 0;
    for (int r = rows - 1; r >= 0; r--) {
      if (board[r].every((c) => c != -1)) {
        board.removeAt(r);
        board.insert(0, List.filled(cols, -1));
        cleared++;
        r++; // re-check same row
      }
    }
    if (cleared > 0) {
      const pts = [0, 100, 300, 500, 800];
      score += (pts[min(cleared, 4)]) * level;
      linesCleared += cleared;
      level = (linesCleared ~/ 10) + 1;
      HapticFeedback.mediumImpact();
      _restartTimer();
    }
  }

  void _restartTimer() {
    timer?.cancel();
    timer = Timer.periodic(_tickSpeed, (_) => _tick());
  }

  void _tick() {
    if (!isPlaying) return;
    if (_isValid(pieceRow + 1, pieceCol, pieceCells)) {
      setState(() { pieceRow++; });
    } else {
      _lockPiece();
      setState(() {});
    }
  }

  void _start() {
    if (isGameOver) {
      _initBoard();
      score = 0;
      level = 1;
      linesCleared = 0;
      lastRank = null;
      isGameOver = false;
    }
    _spawnPiece();
    isPlaying = true;
    _restartTimer();
    setState(() {});
  }

  void _pause() {
    isPlaying = !isPlaying;
    if (isPlaying) {
      _restartTimer();
    } else {
      timer?.cancel();
    }
    setState(() {});
  }

  void _moveLeft() {
    if (!isPlaying) return;
    if (_isValid(pieceRow, pieceCol - 1, pieceCells)) {
      setState(() { pieceCol--; });
      HapticFeedback.selectionClick();
    }
  }

  void _moveRight() {
    if (!isPlaying) return;
    if (_isValid(pieceRow, pieceCol + 1, pieceCells)) {
      setState(() { pieceCol++; });
      HapticFeedback.selectionClick();
    }
  }

  void _rotate() {
    if (!isPlaying) return;
    final rotated = _rotatedCells(pieceCells);
    // Wall kick: try original, then ±1, ±2
    for (final kick in [0, 1, -1, 2, -2]) {
      if (_isValid(pieceRow, pieceCol + kick, rotated)) {
        setState(() {
          pieceCells = rotated;
          pieceCol += kick;
        });
        HapticFeedback.selectionClick();
        return;
      }
    }
  }

  void _softDrop() {
    if (!isPlaying) return;
    if (_isValid(pieceRow + 1, pieceCol, pieceCells)) {
      setState(() { pieceRow++; score++; });
    }
  }

  void _hardDrop() {
    if (!isPlaying) return;
    int dropped = 0;
    while (_isValid(pieceRow + 1, pieceCol, pieceCells)) {
      pieceRow++;
      dropped++;
    }
    score += dropped * 2;
    _lockPiece();
    setState(() {});
    HapticFeedback.mediumImpact();
  }

  // Ghost piece row
  int get _ghostRow {
    int gr = pieceRow;
    while (_isValid(gr + 1, pieceCol, pieceCells)) gr++;
    return gr;
  }

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=tetris');
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
      final data = await acc.apiPost('/game/score', {'game': 'tetris', 'score': score});
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
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          const Text('🧱', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Tetris', style: TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          _badge('$score', Colors.blue),
          const SizedBox(width: 8),
          _badge('Lv$level', Colors.purple),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.leaderboard), onPressed: _showLeaderboard),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx > 10) _moveRight();
              if (d.delta.dx < -10) _moveLeft();
            },
            onVerticalDragUpdate: (d) {
              if (d.delta.dy > 8) _softDrop();
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 600) _hardDrop();
            },
            onTap: _rotate,
            child: Row(children: [
              Expanded(child: _buildBoard()),
              _buildSidebar(),
            ]),
          ),
        ),
        _buildControls(),
      ]),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(builder: (context, box) {
      final cellSize = min(box.maxWidth / cols, box.maxHeight / rows);
      final boardW = cellSize * cols;
      final boardH = cellSize * rows;
      final ghost = _ghostRow;

      return Center(
        child: Container(
          width: boardW, height: boardH,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1),
            color: const Color(0xFF111125),
          ),
          child: Stack(children: [
            // Board cells
            for (int r = 0; r < rows; r++)
              for (int c = 0; c < cols; c++)
                if (board[r][c] != -1)
                  Positioned(
                    left: c * cellSize, top: r * cellSize,
                    child: _cell(cellSize, _pieceColors[board[r][c]], false),
                  ),
            // Ghost piece
            if (isPlaying && ghost != pieceRow)
              for (final cell in pieceCells)
                Positioned(
                  left: (pieceCol + cell[1]) * cellSize,
                  top: (ghost + cell[0]) * cellSize,
                  child: _cell(cellSize, _pieceColors[pieceColor].withOpacity(0.25), false),
                ),
            // Active piece
            if (isPlaying || (!isGameOver && pieceCells.isNotEmpty))
              for (final cell in pieceCells)
                Positioned(
                  left: (pieceCol + cell[1]) * cellSize,
                  top: (pieceRow + cell[0]) * cellSize,
                  child: _cell(cellSize, _pieceColors[pieceColor], true),
                ),
            // Overlay
            if (!isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (isGameOver) ...[
                      const Text('Game Over', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('Очки: $score', style: const TextStyle(color: Colors.white70, fontSize: 18)),
                      if (lastRank != null) ...[
                        const SizedBox(height: 4),
                        Text('#$lastRank в рейтинге', style: const TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(onPressed: _start, icon: const Icon(Icons.refresh), label: const Text('Ещё раз')),
                    ] else ...[
                      const Text('🧱', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      const Text('Нажмите старт', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _start, child: const Text('Играть')),
                    ],
                  ]),
                ),
              ),
          ]),
        ),
      );
    });
  }

  Widget _cell(double size, Color color, bool active) => Container(
    width: size - 1, height: size - 1,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
      boxShadow: active ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)] : null,
    ),
  );

  Widget _buildSidebar() {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Следующий', style: TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 6),
        _nextPiecePreview(),
        const SizedBox(height: 16),
        const Text('Линии', style: TextStyle(color: Colors.white54, fontSize: 10)),
        Text('$linesCleared', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (bestScore > 0) ...[
          const Text('Рекорд', style: TextStyle(color: Colors.white54, fontSize: 10)),
          Text('$bestScore', style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  Widget _nextPiecePreview() {
    final cells = _pieces[nextType];
    final color = _pieceColors[nextType];
    final minR = cells.map((c) => c[0]).reduce(min);
    final minC = cells.map((c) => c[1]).reduce(min);
    const cellSize = 12.0;
    final maxR = cells.map((c) => c[0]).reduce(max) - minR + 1;
    final maxC = cells.map((c) => c[1]).reduce(max) - minC + 1;
    return SizedBox(
      height: (maxR + 1) * cellSize,
      width: (maxC + 1) * cellSize + 4,
      child: Stack(
        children: cells.map((c) => Positioned(
          left: (c[1] - minC) * cellSize,
          top: (c[0] - minR) * cellSize,
          child: _cell(cellSize, color, false),
        )).toList(),
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _btn(Icons.arrow_back, _moveLeft),
          _btn(Icons.rotate_right, _rotate),
          _btn(Icons.arrow_downward, _softDrop),
          _btn(Icons.arrow_forward, _moveRight),
          _btn(isPlaying ? Icons.pause : Icons.play_arrow, isPlaying ? _pause : _start,
              color: isPlaying ? Colors.orange : Colors.green),
          _btn(Icons.vertical_align_bottom, _hardDrop, color: Colors.red),
        ]),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, {Color? color}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 44,
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color ?? Colors.white70, size: 26),
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
  );

  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                Text('Рейтинг Tetris', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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
