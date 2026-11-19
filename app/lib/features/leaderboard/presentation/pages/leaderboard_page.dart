import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../cubit/leaderboard_cubit.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key, required this.token, required this.youId});
  final String token;
  final String youId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<LeaderboardCubit>()..load(token),
    child: Scaffold(
      appBar: AppBar(title: const Text('Global Leaderboard')),
      body: BlocBuilder<LeaderboardCubit, LeaderboardState>(
        builder: (context, s) {
          if (s.loading) return const Center(child: CircularProgressIndicator());
          if (s.error != null) return Center(child: Text(s.error!));
          if (s.entries.isEmpty) return const Center(child: Text('No miners ranked yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: s.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final e = s.entries[i];
              final you = e.playerId == youId;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: e.rank <= 3 ? MMColors.amber : MMColors.surfaceHi,
                    child: Text('${e.rank}', style: TextStyle(color: e.rank <= 3 ? MMColors.bg : MMColors.text)),
                  ),
                  title: Text(e.username, style: TextStyle(color: you ? MMColors.amber : null, fontWeight: you ? FontWeight.w800 : null)),
                  subtitle: Text('Level ${e.level} · ${e.wins} wins'),
                  trailing: Text('${e.totalCoins} ¢', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
