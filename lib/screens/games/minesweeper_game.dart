import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

enum _CellState { hidden, revealed, flagged }

class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key});
  @override
  State<MinesweeperGame> createState() => _MinesweeperState();
}

class _MinesweeperState extends State<MinesweeperGame> {
  static const int rows = 9;
  static const int cols = 9;
  static const int mines = 10;

  late List<List<bool>> isMine;
  late List<List<int>> adjCount;
  late List<List<_CellState>> cellState;
  bool firstTap = true;
  bool isGameOver = false;
  bool isWon = false;
  bool isPlaying = false;
  int flagsLeft = mines;
  int revealedCount = 0;
  int elapsedSeconds = 0;
  Timer? _timer;
  int? lastScore;
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  final random = Random();

  @override
  void initState() {
    super.initState();
    _init();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _init() {
    isMine = List.generate(rows, (_) => List.filled(cols, false));
    adjCount = List.generate(rows, (_) => List.filled(cols, 0));
    cellState = List.generate(rows, (_) => List.filled(cols, _CellState.hidden));
    firstTap = true;
    isGameOver = false;
    isWon = false;
    isPlaying = false;
    flagsLeft = mines;
    revealedCount = 0;
    elapsedSeconds = 0;
    lastScore = null;
    _timer?.cancel();
  }

  void _placeMines(int safeRow, int safeCol) {
    int placed = 0;
    while (placed < mines) {
      final r = random.nextInt(rows);
      final c = random.nextInt(cols);
      if ((r - safeRow).abs() <= 1 && (c - safeCol).abs() <= 1) continue;
      if (isMine[r][c]) continue;
      isMine[r][c] = true;
      placed++;
    }
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (isMine[r][c]) continue;
        int count = 0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && isMine[nr][nc]) count++;
          }
        }
        adjCount[r][c] = count;
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() { elapsedSeconds++; });
    });
  }

  void _reveal(int r, int c) {
    if (firstTap) {
      _placeMines(r, c);
      firstTap = false;
      isPlaying = true;
      _startTimer();
    }
    if (cellState[r][c] != _CellState.hidden) return;
    cellState[r][c] = _CellState.revealed;
    revealedCount++;

    if (isMine[r][c]) {
      _timer?.cancel();
      isGameOver = true;
      isPlaying = false;
      HapticFeedback.heavyImpact();
      // Reveal all mines
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
          if (isMine[i][j]) cellState[i][j] = _CellState.revealed;
        }
      }
      return;
    }

    if (adjCount[r][c] == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          final nr = r + dr; final nc = c + dc;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols &&
              cellState[nr][nc] == _CellState.hidden && !isMine[nr][nc]) {
            _reveal(nr, nc);
          }
        }
      }
    }

    // Win check
    if (revealedCount == rows * cols - mines) {
      _timer?.cancel();
      isWon = true;
      isPlaying = false;
      final sc = max(0, 1000 - elapsedSeconds * 5);
      lastScore = sc;
      HapticFeedback.mediumImpact();
      if (sc > 0) _submitScore(sc);
    }
  }

  void _toggleFlag(int r, int c) {
    if (cellState[r][c] == _CellState.revealed) return;
    if (cellState[r][c] == _CellState.flagged) {
      cellState[r][c] = _CellState.hidden;
      flagsLeft++;
    } else if (flagsLeft > 0) {
      cellState[r][c] = _CellState.flagged;
      flagsLeft--;
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=minesweeper');
      if (data is Map && data['scores'] is List && mounted) {
        setState(() {
          leaderboard = List<Map<String, dynamic>>.from(data['scores']);
        });
      }
    } catch (_) {}
  }

  Future<void> _submitScore(int sc) async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiPost('/game/score', {'game': 'minesweeper', 'score': sc});
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

  static const _numberColors = [
    Colors.transparent,
    Color(0xFF1565C0), // 1 blue
    Color(0xFF2E7D32), // 2 green
    Color(0xFFC62828), // 3 red
    Color(0xFF283593), // 4 dark blue
    Color(0xFFB71C1C), // 5 dark red
    Color(0xFF00838F), // 6 cyan
    Color(0xFF212121), // 7 black
    Color(0xFF9E9E9E), // 8 grey
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC0C0C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF808080),
        foregroundColor: Colors.black,
        elevation: 0,
        title: Row(children: [
          const Text('💣', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Сапёр', style: TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          _badge('🚩 $flagsLeft', Colors.red[700]!),
          const SizedBox(width: 8),
          _badge('⏱ $elapsedSeconds', Colors.black),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.leaderboard, color: Colors.black), onPressed: _showLeaderboard),
        ],
      ),
      body: Column(children: [
        // Status bar
        Container(
          color: const Color(0xFF808080),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (isWon)
              Text('🎉 Победа! Счёт: ${lastScore ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (isGameOver)
              const Text('💥 Игра окончена!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.red)),
            if (!isWon && !isGameOver) const Text('Тап — открыть, удержать — флаг', style: TextStyle(fontSize: 12)),
            const Spacer(),
            TextButton.icon(
              onPressed: () { setState(() { _init(); }); },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Новая игра'),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ]),
        ),
        if (isWon && lastRank != null)
          Container(
            color: Colors.amber[100],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Место в рейтинге: #$lastRank', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (ctx, box) {
              final cellSize = min(box.maxWidth / cols, box.maxHeight / rows) - 2;
              return GestureDetector(
                onTapUp: (details) {
                  if (isGameOver || isWon) return;
                  final localPos = details.localPosition;
                  final c = (localPos.dx / cellSize).floor();
                  final r = (localPos.dy / cellSize).floor();
                  if (r >= 0 && r < rows && c >= 0 && c < cols) {
                    setState(() { _reveal(r, c); });
                  }
                },
                onLongPressStart: (details) {
                  if (isGameOver || isWon) return;
                  final localPos = details.localPosition;
                  final c = (localPos.dx / cellSize).floor();
                  final r = (localPos.dy / cellSize).floor();
                  if (r >= 0 && r < rows && c >= 0 && c < cols) {
                    setState(() { _toggleFlag(r, c); });
                  }
                },
                child: Container(
                  width: cellSize * cols,
                  height: cellSize * rows,
                  child: CustomPaint(
                    painter: _MinesweeperPainter(
                      rows: rows, cols: cols,
                      isMine: isMine,
                      adjCount: adjCount,
                      cellState: cellState,
                      cellSize: cellSize,
                      isGameOver: isGameOver,
                      numberColors: _numberColors,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
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
                Text('Рейтинг Сапёра', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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

class _MinesweeperPainter extends CustomPainter {
  final int rows, cols;
  final List<List<bool>> isMine;
  final List<List<int>> adjCount;
  final List<List<_CellState>> cellState;
  final double cellSize;
  final bool isGameOver;
  final List<Color> numberColors;

  _MinesweeperPainter({
    required this.rows, required this.cols,
    required this.isMine, required this.adjCount,
    required this.cellState, required this.cellSize,
    required this.isGameOver, required this.numberColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hiddenPaint = Paint()..color = const Color(0xFFBDBDBD);
    final revealedPaint = Paint()..color = const Color(0xFFE0E0E0);
    final borderLight = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
    final borderDark = Paint()..color = const Color(0xFF757575)..strokeWidth = 2..style = PaintingStyle.stroke;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final left = c * cellSize;
        final top = r * cellSize;
        final rect = Rect.fromLTWH(left, top, cellSize - 1, cellSize - 1);
        final state = cellState[r][c];

        if (state == _CellState.revealed) {
          canvas.drawRect(rect, revealedPaint);
          if (isMine[r][c]) {
            // Draw mine
            final center = rect.center;
            canvas.drawCircle(center, cellSize * 0.3, Paint()..color = Colors.black);
            canvas.drawLine(Offset(center.dx - cellSize * 0.35, center.dy),
                Offset(center.dx + cellSize * 0.35, center.dy), Paint()..color = Colors.black..strokeWidth = 1.5);
            canvas.drawLine(Offset(center.dx, center.dy - cellSize * 0.35),
                Offset(center.dx, center.dy + cellSize * 0.35), Paint()..color = Colors.black..strokeWidth = 1.5);
          } else if (adjCount[r][c] > 0) {
            _drawText(canvas, '${adjCount[r][c]}', rect, numberColors[adjCount[r][c]]);
          }
        } else {
          canvas.drawRect(rect, hiddenPaint);
          // 3D border
          canvas.drawLine(Offset(left, top), Offset(left + cellSize - 1, top), borderLight);
          canvas.drawLine(Offset(left, top), Offset(left, top + cellSize - 1), borderLight);
          canvas.drawLine(Offset(left + cellSize - 1, top), Offset(left + cellSize - 1, top + cellSize - 1), borderDark);
          canvas.drawLine(Offset(left, top + cellSize - 1), Offset(left + cellSize - 1, top + cellSize - 1), borderDark);
          if (state == _CellState.flagged) {
            _drawText(canvas, '🚩', rect, Colors.red);
          }
        }
      }
    }
  }

  void _drawText(Canvas canvas, String text, Rect rect, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: cellSize * 0.55, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MinesweeperPainter old) => true;
}
