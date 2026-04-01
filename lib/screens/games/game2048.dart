import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';

class Game2048 extends StatefulWidget {
  const Game2048({super.key});
  @override
  State<Game2048> createState() => _Game2048State();
}

class _Game2048State extends State<Game2048> {
  static const int size = 4;

  late List<List<int>> board;
  int score = 0;
  int bestScore = 0;
  bool isGameOver = false;
  bool isWon = false;
  List<Map<String, dynamic>> leaderboard = [];
  int? lastRank;
  bool _scoreSent = false;
  final random = Random();

  @override
  void initState() {
    super.initState();
    _newGame();
    _loadLeaderboard();
  }

  void _newGame() {
    board = List.generate(size, (_) => List.filled(size, 0));
    score = 0;
    isGameOver = false;
    isWon = false;
    _scoreSent = false;
    lastRank = null;
    _addRandom();
    _addRandom();
  }

  void _addRandom() {
    final empties = <List<int>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] == 0) empties.add([r, c]);
      }
    }
    if (empties.isEmpty) return;
    final pos = empties[random.nextInt(empties.length)];
    board[pos[0]][pos[1]] = random.nextDouble() < 0.9 ? 2 : 4;
  }

  bool _canMove() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] == 0) return true;
        if (c < size - 1 && board[r][c] == board[r][c + 1]) return true;
        if (r < size - 1 && board[r][c] == board[r + 1][c]) return true;
      }
    }
    return false;
  }

  // Returns (newRow, addedScore)
  (List<int>, int) _mergeRow(List<int> row) {
    final filtered = row.where((v) => v != 0).toList();
    int added = 0;
    for (int i = 0; i < filtered.length - 1; i++) {
      if (filtered[i] == filtered[i + 1]) {
        filtered[i] *= 2;
        added += filtered[i];
        filtered.removeAt(i + 1);
      }
    }
    while (filtered.length < size) filtered.add(0);
    return (filtered, added);
  }

  bool _swipe(String dir) {
    final before = board.map((r) => List<int>.from(r)).toList();
    int added = 0;

    if (dir == 'left') {
      for (int r = 0; r < size; r++) {
        final (newRow, pts) = _mergeRow(board[r]);
        board[r] = newRow; added += pts;
      }
    } else if (dir == 'right') {
      for (int r = 0; r < size; r++) {
        final (newRow, pts) = _mergeRow(board[r].reversed.toList());
        board[r] = newRow.reversed.toList(); added += pts;
      }
    } else if (dir == 'up') {
      for (int c = 0; c < size; c++) {
        final col = [for (int r = 0; r < size; r++) board[r][c]];
        final (newCol, pts) = _mergeRow(col);
        for (int r = 0; r < size; r++) board[r][c] = newCol[r];
        added += pts;
      }
    } else if (dir == 'down') {
      for (int c = 0; c < size; c++) {
        final col = [for (int r = size - 1; r >= 0; r--) board[r][c]];
        final (newCol, pts) = _mergeRow(col);
        for (int r = size - 1; r >= 0; r--) board[r][c] = newCol[size - 1 - r];
        added += pts;
      }
    }

    // Check if board changed
    bool changed = false;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] != before[r][c]) { changed = true; break; }
      }
    }
    if (!changed) return false;

    score += added;
    if (added > 0) HapticFeedback.lightImpact();
    _addRandom();

    // Win check
    if (!isWon && board.any((row) => row.any((v) => v == 2048))) {
      isWon = true;
    }

    if (!_canMove()) {
      isGameOver = true;
      if (score > bestScore) bestScore = score;
      HapticFeedback.heavyImpact();
      if (!_scoreSent && score > 0) { _scoreSent = true; _submitScore(); }
    }
    return true;
  }

  static Color _tileColor(int v) {
    const colors = {
      0: Color(0xFFCDC1B4),
      2: Color(0xFFEEE4DA),
      4: Color(0xFFEDE0C8),
      8: Color(0xFFF2B179),
      16: Color(0xFFF59563),
      32: Color(0xFFF67C5F),
      64: Color(0xFFF65E3B),
      128: Color(0xFFEDCF72),
      256: Color(0xFFEDCC61),
      512: Color(0xFFEDC850),
      1024: Color(0xFFEDC53F),
      2048: Color(0xFFEDC22E),
    };
    return colors[v] ?? const Color(0xFF3C3A32);
  }

  static Color _textColor(int v) => v <= 4 ? const Color(0xFF776E65) : Colors.white;
  static double _fontSize(int v) => v < 100 ? 28 : v < 1000 ? 22 : 18;

  Future<void> _loadLeaderboard() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=2048');
      if (data is Map && data['scores'] is List && mounted) {
        setState(() { leaderboard = List<Map<String, dynamic>>.from(data['scores']); });
      }
    } catch (_) {}
  }

  Future<void> _submitScore() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiPost('/game/score', {'game': '2048', 'score': score});
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
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBBADA0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          const Text('2048', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
          const Spacer(),
          _scoreCard('СЧЁТ', score),
          const SizedBox(width: 8),
          _scoreCard('РЕКОРД', bestScore),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.leaderboard), onPressed: _showLeaderboard),
        ],
      ),
      body: Column(children: [
        if (isWon && !isGameOver)
          Container(
            color: const Color(0xFFEDC22E),
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🎉 2048! Продолжайте!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const Spacer(),
              TextButton(onPressed: () => setState(() { isWon = false; }), child: const Text('OK')),
            ]),
          ),
        if (isGameOver)
          Container(
            color: const Color(0xFF9E8A7C),
            padding: const EdgeInsets.all(12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Игра окончена! Счёт: $score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              if (lastRank != null) ...[
                const SizedBox(width: 8),
                Text(' #$lastRank', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900)),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => setState(() { _newGame(); }),
                child: const Text('Ещё раз', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > 200) setState(() { _swipe('right'); });
              if (v < -200) setState(() { _swipe('left'); });
            },
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > 200) setState(() { _swipe('down'); });
              if (v < -200) setState(() { _swipe('up'); });
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBADA0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: size * size,
                    itemBuilder: (_, idx) {
                      final r = idx ~/ size;
                      final c = idx % size;
                      final v = board[r][c];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        decoration: BoxDecoration(
                          color: _tileColor(v),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: v == 0 ? null : Text(
                            '$v',
                            style: TextStyle(
                              color: _textColor(v),
                              fontSize: _fontSize(v),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Свайп для управления', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => setState(() { _newGame(); }),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Новая'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _scoreCard(String label, int value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF8F7A66), borderRadius: BorderRadius.circular(6)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
      Text('$value', style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w900)),
    ]),
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
                Text('Рейтинг 2048', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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
