import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import 'games/pacman_game.dart';
import 'games/snake_game.dart';
import 'games/tetris_game.dart';
import 'games/minesweeper_game.dart';
import 'games/game2048.dart';
import 'games/breakout_game.dart';
import 'games/flappy_game.dart';
import 'games/helicopter_game.dart';

class _GameDef {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final Color bg;
  final Widget Function() builder;

  const _GameDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.bg,
    required this.builder,
  });
}

final _games = [
  _GameDef(
    id: 'pacman', name: 'Pacman', emoji: '👻',
    color: const Color(0xFFF1C40F), bg: const Color(0xFF1a1a2e),
    builder: () => const PacmanGame(),
  ),
  _GameDef(
    id: 'snake', name: 'Snake', emoji: '🐍',
    color: const Color(0xFF2ECC71), bg: const Color(0xFF1B5E20),
    builder: () => const SnakeGame(),
  ),
  _GameDef(
    id: 'tetris', name: 'Tetris', emoji: '🧱',
    color: const Color(0xFF3498DB), bg: const Color(0xFF0F0F23),
    builder: () => const TetrisGame(),
  ),
  _GameDef(
    id: 'minesweeper', name: 'Сапёр', emoji: '💣',
    color: const Color(0xFFE74C3C), bg: const Color(0xFFC0C0C0),
    builder: () => const MinesweeperGame(),
  ),
  _GameDef(
    id: '2048', name: '2048', emoji: '🔢',
    color: const Color(0xFFEDCF72), bg: const Color(0xFFBBADA0),
    builder: () => const Game2048(),
  ),
  _GameDef(
    id: 'breakout', name: 'Breakout', emoji: '🎯',
    color: const Color(0xFFE74C3C), bg: const Color(0xFF1a1a2e),
    builder: () => const BreakoutGame(),
  ),
  _GameDef(
    id: 'flappy', name: 'Flappy Bird', emoji: '🐦',
    color: const Color(0xFFF39C12), bg: const Color(0xFF4DC9F6),
    builder: () => const FlappyGame(),
  ),
  _GameDef(
    id: 'helicopter', name: 'Helicopter', emoji: '🚁',
    color: const Color(0xFF9B59B6), bg: const Color(0xFF0a0a2e),
    builder: () => const HelicopterGame(),
  ),
];

class GameHub extends StatefulWidget {
  const GameHub({super.key});
  @override
  State<GameHub> createState() => _GameHubState();
}

class _GameHubState extends State<GameHub> {
  // personal bests: game_id → score
  Map<String, int> _bests = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBests();
  }

  Future<void> _loadBests() async {
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=all');
      if (data is Map && data['games'] is Map && mounted) {
        final bests = <String, int>{};
        final games = data['games'] as Map;
        for (final entry in games.entries) {
          final scores = entry.value['scores'] as List? ?? [];
          for (final s in scores) {
            if (s['is_me'] == true) {
              bests[entry.key as String] = s['score'] as int;
              break;
            }
          }
        }
        setState(() { _bests = bests; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Row(children: [
          Text('🕹️', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Text('Игры', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Общий рейтинг',
            onPressed: _showOverallLeaderboard,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBests,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: _games.length,
                itemBuilder: (_, i) => _GameCard(
                  game: _games[i],
                  best: _bests[_games[i].id],
                  onTap: () => _launch(_games[i]),
                ),
              ),
            ),
    );
  }

  void _launch(_GameDef game) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => game.builder()));
  }

  void _showOverallLeaderboard() async {
    Map<String, dynamic>? overall;
    try {
      final acc = context.read<AccountProvider>();
      final data = await acc.apiGet('/game/leaderboard?game=all');
      if (data is Map) overall = Map<String, dynamic>.from(data);
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4,
        builder: (_, ctrl) => DefaultTabController(
          length: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Text('🏆', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Text('Турнирная таблица', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ]),
              ),
              const TabBar(tabs: [
                Tab(text: 'Общий зачёт'),
                Tab(text: 'По играм'),
              ]),
              Expanded(
                child: TabBarView(
                  children: [
                    // Overall tab
                    _OverallTab(entries: (overall?['overall'] as List?)?.cast<Map>() ?? []),
                    // Per-game tab
                    _PerGameTab(games: _games, gamesData: overall?['games'] as Map? ?? {}),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final _GameDef game;
  final int? best;
  final VoidCallback onTap;
  const _GameCard({required this.game, required this.onTap, this.best});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [game.bg, Color.lerp(game.bg, Colors.black, 0.3)!],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: game.color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: game.color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.emoji, style: const TextStyle(fontSize: 32)),
              const Spacer(),
              Text(game.name, style: TextStyle(color: game.color, fontWeight: FontWeight.w900, fontSize: 16)),
              if (best != null) ...[
                const SizedBox(height: 2),
                Text('Рекорд: $best', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ] else ...[
                const SizedBox(height: 2),
                Text('Нет рекорда', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallTab extends StatelessWidget {
  final List<Map> entries;
  const _OverallTab({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('Пока нет результатов', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        final isMe = e['is_me'] == true;
        final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
        return ListTile(
          tileColor: isMe ? Colors.amber.withOpacity(0.08) : null,
          leading: SizedBox(width: 36, child: Center(child: Text(medal, style: TextStyle(fontSize: i < 3 ? 24 : 16)))),
          title: Text(e['name'] ?? '???', style: TextStyle(fontWeight: isMe ? FontWeight.w900 : FontWeight.w600)),
          trailing: Text('${e['total']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: i < 3 ? Colors.amber[700] : null)),
        );
      },
    );
  }
}

class _PerGameTab extends StatelessWidget {
  final List<_GameDef> games;
  final Map gamesData;
  const _PerGameTab({required this.games, required this.gamesData});

  @override
  Widget build(BuildContext context) {
    if (gamesData.isEmpty) {
      return const Center(child: Text('Пока нет результатов', style: TextStyle(color: Colors.grey)));
    }
    return DefaultTabController(
      length: games.length,
      child: Column(children: [
        TabBar(
          isScrollable: true,
          tabs: games.map((g) => Tab(text: g.emoji)).toList(),
          labelStyle: const TextStyle(fontSize: 20),
        ),
        Expanded(
          child: TabBarView(
            children: games.map((g) {
              final scores = (gamesData[g.id]?['scores'] as List?)?.cast<Map>() ?? [];
              if (scores.isEmpty) {
                return Center(child: Text('Нет рекордов для ${g.name}', style: const TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                itemCount: scores.length,
                itemBuilder: (_, i) {
                  final e = scores[i];
                  final isMe = e['is_me'] == true;
                  final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
                  return ListTile(
                    tileColor: isMe ? Colors.amber.withOpacity(0.08) : null,
                    leading: SizedBox(width: 36, child: Center(child: Text(medal, style: TextStyle(fontSize: i < 3 ? 24 : 16)))),
                    title: Text(e['name'] ?? '???', style: TextStyle(fontWeight: isMe ? FontWeight.w900 : FontWeight.w600)),
                    trailing: Text('${e['score']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: i < 3 ? Colors.amber[700] : null)),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
