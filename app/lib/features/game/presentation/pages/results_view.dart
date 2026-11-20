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
      color: const Color(0xE6120E1F),
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
                          color: good ? null : MMColors.surfaceHi,
                          border: Border.all(color: const Color(0x40FFFFFF), width: 2),
                          boxShadow: good ? [BoxShadow(color: MMColors.gold.withValues(alpha: 0.55), blurRadius: 44)] : null,
                        ),
                        child: Icon(
                          winner == null ? CupertinoIcons.timer : (good ? CupertinoIcons.star_fill : CupertinoIcons.cube_box),
                          size: 46,
                          color: good ? MMColors.onGold : MMColors.text,
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
                        _Stat(label: 'Coins', value: formatAmount(you.score), icon: const CoinIcon(size: 18)),
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
                          title: p.playerId == widget.youId ? '${p.name} (you)' : (p.isBot ? '${p.name} · BOT' : p.name),
                          subtitle: [
                            if (p.playerId == r.winnerId) 'Found the treasure' else '${p.oresMined} finds',
                            if (p.mysteriesOpened > 0) '${p.mysteriesOpened} mystery',
                            if (p.monstersKilled > 0) '${p.monstersKilled} monsters',
                            if (p.bonusGems > 0) '+${p.bonusGems} gems',
                          ].join(' · '),
                          highlight: p.playerId == widget.youId,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [const CoinIcon(size: 15), const SizedBox(width: 5), Text(formatAmount(p.score), style: MMText.number.copyWith(fontSize: 16, color: MMColors.text))],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GameButton(label: 'Play Again', icon: CupertinoIcons.arrow_clockwise, onPressed: widget.onPlayAgain),
                  const SizedBox(height: 12),
                  GameButton(label: 'Lobby', tone: ButtonTone.dark, height: 52, fontSize: 17, onPressed: widget.onLobby),
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
  const _Stat({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      radius: 16,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [if (icon != null) ...[icon!, const SizedBox(width: 5)], Text(value, style: MMText.title.merge(MMText.number))],
          ),
          const SizedBox(height: 2),
          Text(label, style: MMText.caption),
        ],
      ),
    ),
  );
}
