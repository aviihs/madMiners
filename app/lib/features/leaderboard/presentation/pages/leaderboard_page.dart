import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../../store/presentation/widgets/avatar_preview.dart';
import '../cubit/leaderboard_cubit.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key, required this.token, required this.youId});
  final String token;
  final String youId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<LeaderboardCubit>()..load(token),
    child: Scaffold(
      body: AppBackground(
        child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
          builder: (context, s) => CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              const CupertinoSliverNavigationBar(
                largeTitle: Text('Leaderboard'),
                previousPageTitle: 'Lobby',
                backgroundColor: Color(0xB30C0A09),
                border: null,
              ),
              CupertinoSliverRefreshControl(onRefresh: () => context.read<LeaderboardCubit>().load(token)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: CupertinoSlidingSegmentedControl<Board>(
                    groupValue: s.board,
                    thumbColor: MMColors.surfaceHi,
                    backgroundColor: MMColors.glass,
                    children: const {
                      Board.today: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Today', style: MMText.headline)),
                      Board.allTime: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('All Time', style: MMText.headline)),
                    },
                    onValueChanged: (b) => context.read<LeaderboardCubit>().load(token, b),
                  ),
                ),
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList.list(
                    children: [
                      if (s.loading)
                        const Padding(padding: EdgeInsets.only(top: 80), child: CupertinoActivityIndicator(radius: 14))
                      else if (s.error != null)
                        Padding(padding: const EdgeInsets.only(top: 80), child: Text(s.error!, textAlign: TextAlign.center, style: MMText.callout))
                      else if (s.entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Text('Nobody has found a treasure yet today.\nBe the first — win a match to take #1!', textAlign: TextAlign.center, style: MMText.callout),
                        )
                      else ...[
                        _Podium(entries: s.entries.take(3).toList(), youId: youId, today: s.board == Board.today),
                        if (s.entries.length > 3) ...[
                          const SectionHeader('Top miners'),
                          GroupedList(
                            children: [
                              for (final e in s.entries.skip(3))
                                ListRow(
                                  leading: Text('${e.rank}', style: MMText.headline.copyWith(color: MMColors.muted)),
                                  title: e.playerId == youId ? '${e.username} (you)' : e.username,
                                  subtitle: s.board == Board.today
                                      ? '${e.todayWins} wins today · ${e.todayCoins} coins'
                                      : 'Level ${e.level} · ${e.wins} treasures',
                                  trailing: s.board == Board.today
                                      ? Pill('${e.todayWins}', icon: CupertinoIcons.star_fill, color: MMColors.gold)
                                      : Pill('${e.totalCoins}', icon: CupertinoIcons.money_dollar_circle_fill, color: MMColors.gold),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.youId, required this.today});
  final List<LeaderboardEntry> entries;
  final String youId;
  final bool today;

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd, 1st, 3rd.
    final order = [if (entries.length > 1) entries[1], entries[0], if (entries.length > 2) entries[2]];
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in order)
            Expanded(
              child: Column(
                children: [
                  if (e.rank == 1) const Icon(CupertinoIcons.star_fill, color: MMColors.gold, size: 22),
                  const SizedBox(height: 6),
                  SizedBox.square(
                    dimension: e.rank == 1 ? 76 : 60,
                    child: e.look == null
                        ? Avatar(e.username, size: e.rank == 1 ? 64 : 50)
                        : AvatarPreview(look: e.look!, seed: e.playerId, size: e.rank == 1 ? 76 : 60, animate: e.rank == 1),
                  ),
                  const SizedBox(height: 8),
                  Text(e.username, style: MMText.headline.copyWith(fontSize: 15, color: e.playerId == youId ? MMColors.amber : null), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(today ? '${e.todayWins} wins today' : '${e.totalCoins} coins', style: MMText.caption),
                  const SizedBox(height: 8),
                  Container(
                    height: switch (e.rank) { 1 => 54.0, 2 => 38.0, _ => 26.0 },
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      gradient: e.rank == 1 ? MMColors.accentGradient : null,
                      color: e.rank == 1 ? null : MMColors.glassStrong,
                    ),
                    alignment: Alignment.center,
                    child: Text('${e.rank}', style: MMText.title.copyWith(fontSize: 20)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
