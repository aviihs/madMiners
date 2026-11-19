import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/theme.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.result, required this.youId});
  final MatchResult result;
  final String? youId;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  @override
  void initState() {
    super.initState();
    // Server has credited rewards; pull the fresh profile.
    context.read<AuthCubit>().refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final you = r.players.where((p) => p.playerId == widget.youId).firstOrNull;
    final title = switch ((r.winningTeam, you)) {
      (>= 0, final y?) => y.team == r.winningTeam ? 'YOUR CREW WINS!' : 'YOUR CREW LOST',
      (_, final y?) when y.rank == 1 => 'TOP MINER!',
      (_, final y?) => 'You finished #${y.rank}',
      _ => 'Match over',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.emoji_events, size: 56, color: MMColors.amber),
                Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                if (you != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Text(
                      '${you.score} coins · ${you.oresMined} ores · +${you.xp} XP',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: MMColors.muted),
                    ),
                  ),
                if (r.teamScores.length == 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Crew A ${r.teamScores[0]}', style: TextStyle(color: MMColors.teams[0])),
                        const TextSpan(text: '   vs   '),
                        TextSpan(text: 'Crew B ${r.teamScores[1]}', style: TextStyle(color: MMColors.teams[1])),
                      ]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                Card(
                  child: Column(
                    children: [
                      for (final p in r.players)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: p.rank <= 3 ? MMColors.amber : MMColors.surfaceHi,
                            child: Text('${p.rank}', style: TextStyle(fontSize: 12, color: p.rank <= 3 ? MMColors.bg : MMColors.text)),
                          ),
                          title: Text(
                            p.isBot ? '${p.name}  [BOT]' : p.name,
                            style: TextStyle(
                              fontWeight: p.playerId == widget.youId ? FontWeight.w800 : null,
                              color: p.playerId == widget.youId ? MMColors.amber : null,
                            ),
                          ),
                          subtitle: Text('${p.oresMined} ores'),
                          trailing: Text('${p.score} ¢', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('BACK TO LOBBY')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
