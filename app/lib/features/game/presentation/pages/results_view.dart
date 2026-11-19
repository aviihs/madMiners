import 'package:flutter/cupertino.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';

/// End-of-match screen, drawn over the frozen mine.
class ResultsView extends StatefulWidget {
  const ResultsView({super.key, required this.result, required this.youId, required this.onLobby, required this.onPlayAgain});
  final MatchResult result;
  final String? youId;
  final VoidCallback onLobby;
  final VoidCallback onPlayAgain;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final you = r.players.where((p) => p.playerId == widget.youId).firstOrNull;
    final winner = r.players.where((p) => p.playerId == r.winnerId).firstOrNull;
    final youWon = winner != null && winner.playerId == widget.youId;
    final crewWon = r.winningTeam >= 0 && you != null && you.team == r.winningTeam;

    final (headline, sub) = switch (winner) {
      _ when youWon => ('You found it!', 'The treasure is yours. +${Balance.treasureBonus} coins'),
      final w? when r.winningTeam >= 0 => (crewWon ? 'Your crew wins!' : 'Your crew lost', '${w.name} broke the treasure'),
      final w? => ('${w.name} found it', 'So close. Dig faster next time!'),
      null => ('Time\'s up', 'Nobody reached the treasure. Most coins wins.'),
    };
    final good = youWon || crewWon;

    return ColoredBox(
      color: const Color(0xCC0C0A09),
      child: SafeArea(
        child: FadeTransition(
          opacity: _anim,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                children: [
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _anim, curve: Curves.elasticOut),
                    child: Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: good ? MMColors.accentGradient : null,
                          color: good ? null : MMColors.glassStrong,
                          boxShadow: good ? const [BoxShadow(color: Color(0x88FFB340), blurRadius: 40)] : null,
                        ),
                        child: Icon(
                          winner == null ? CupertinoIcons.timer : (good ? CupertinoIcons.star_fill : CupertinoIcons.cube_box),
                          size: 46,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(headline, textAlign: TextAlign.center, style: MMText.largeTitle.copyWith(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(sub, textAlign: TextAlign.center, style: MMText.callout),
                  if (you != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _Stat(label: 'Rank', value: '#${you.rank}'),
                        const SizedBox(width: 10),
                        _Stat(label: 'Coins', value: '${you.score}'),
                        const SizedBox(width: 10),
                        _Stat(label: 'XP', value: '+${you.xp}'),
                      ],
                    ),
                  ],
                  if (r.teamScores.length == 2) ...[
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text('Crew A  ${r.teamScores[0]}', style: MMText.headline.copyWith(color: MMColors.teams[0])),
                          const Text('vs', style: MMText.footnote),
                          Text('Crew B  ${r.teamScores[1]}', style: MMText.headline.copyWith(color: MMColors.teams[1])),
                        ],
                      ),
                    ),
                  ],
                  const SectionHeader('Standings'),
                  GroupedList(
                    children: [
                      for (final p in r.players)
                        ListRow(
                          leading: p.playerId == r.winnerId
                              ? const IconTile(CupertinoIcons.star_fill, color: MMColors.gold, size: 32)
                              : Text('${p.rank}', style: MMText.headline.copyWith(color: p.rank <= 3 ? MMColors.amber : MMColors.muted)),
                          title: p.playerId == widget.youId ? '${p.name} (you)' : p.name,
                          subtitle: p.playerId == r.winnerId ? 'Found the treasure' : '${p.oresMined} finds',
                          trailing: Text('${p.score}', style: MMText.headline.merge(MMText.number)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Play Again', icon: CupertinoIcons.arrow_clockwise, onPressed: widget.onPlayAgain),
                  const SizedBox(height: 10),
                  SecondaryButton(label: 'Back to Lobby', onPressed: widget.onLobby),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      radius: 16,
      child: Column(
        children: [
          Text(value, style: MMText.title.merge(MMText.number)),
          const SizedBox(height: 2),
          Text(label, style: MMText.caption),
        ],
      ),
    ),
  );
}
