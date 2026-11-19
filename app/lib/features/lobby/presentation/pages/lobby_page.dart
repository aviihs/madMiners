import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../auth/domain/entities/session.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../game/domain/entities/game_target.dart';
import '../../../game/presentation/pages/game_page.dart';
import '../../../leaderboard/presentation/pages/leaderboard_page.dart';
import '../../domain/entities/room.dart';
import '../cubit/lobby_cubit.dart';
import '../widgets/create_room_sheet.dart';

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final c = sl<LobbyCubit>();
      if (session.isOnline) c.refresh(session.token!);
      return c;
    },
    child: _LobbyView(session: session),
  );
}

class _LobbyView extends StatefulWidget {
  const _LobbyView({required this.session});
  final Session session;

  @override
  State<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<_LobbyView> {
  final _code = TextEditingController();

  Session get s => widget.session;
  String get token => s.token!;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _enter(RoomTicket t) async {
    context.read<LobbyCubit>().ticketConsumed();
    await Navigator.of(context).push(GamePage.route(OnlineTarget(token: token, wsPath: t.wsPath, roomCode: t.roomCode)));
    if (!mounted) return;
    context.read<LobbyCubit>().refresh(token);
    context.read<AuthCubit>().refreshProfile();
  }

  Future<void> _practice() async {
    final p = await showModalBottomSheet<CreateRoomParams>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateRoomSheet(offline: true),
    );
    if (p == null || !mounted) return;
    await Navigator.of(context).push(
      GamePage.route(
        OfflineTarget(playerName: s.profile.username, settings: MatchSettings(mapId: p.mapId, mode: p.mode)),
      ),
    );
  }

  Future<void> _create() async {
    final p = await showModalBottomSheet<CreateRoomParams>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateRoomSheet(),
    );
    if (p != null && mounted) context.read<LobbyCubit>().create(token, p);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LobbyCubit, LobbyState>(
      listenWhen: (a, b) => b.ticket != null || (b.error != null && a.error != b.error),
      listener: (context, st) {
        if (st.ticket != null) {
          _enter(st.ticket!);
        } else if (st.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(st.error!)));
        }
      },
      builder: (context, st) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('MAD MINERS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: MMColors.amber)),
            actions: [
              if (s.isOnline)
                IconButton(
                  tooltip: 'Leaderboard',
                  icon: const Icon(Icons.leaderboard),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LeaderboardPage(token: token, youId: s.profile.id)),
                  ),
                ),
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthCubit>().signOut(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => s.isOnline ? context.read<LobbyCubit>().refresh(token) : null,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileCard(session: s),
                const SizedBox(height: 16),
                if (s.isOnline) ...[
                  FilledButton.icon(
                    onPressed: st.busy ? null : () => context.read<LobbyCubit>().quickPlay(token),
                    icon: st.busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: const Text('QUICK PLAY'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: st.busy ? null : _create,
                          icon: const Icon(Icons.add),
                          label: const Text('CREATE ROOM'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: _practice,
                          icon: const Icon(Icons.smart_toy_outlined),
                          label: const Text('PRACTICE'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Private room code', isDense: true),
                          onSubmitted: (v) => context.read<LobbyCubit>().joinByCode(token, v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: st.busy ? null : () => context.read<LobbyCubit>().joinByCode(token, _code.text),
                        child: const Text('JOIN'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Public rooms', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (st.loading)
                        const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(onPressed: () => context.read<LobbyCubit>().refresh(token), icon: const Icon(Icons.refresh)),
                    ],
                  ),
                  if (st.rooms.isEmpty && !st.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No open rooms yet. Hit Quick Play — bots will keep you company until others join.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MMColors.muted),
                      ),
                    ),
                  for (final r in st.rooms) _RoomTile(room: r, onJoin: st.busy ? null : () => context.read<LobbyCubit>().join(token, r.roomId)),
                ] else ...[
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Offline mode: the whole mine (and 7 bot miners) runs on your device. '
                        'Sign out and connect to a server to play online.',
                        style: TextStyle(color: MMColors.muted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(onPressed: _practice, icon: const Icon(Icons.smart_toy_outlined), label: const Text('START PRACTICE')),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: MMColors.amber,
              child: Text('${p.level}', style: const TextStyle(color: MMColors.bg, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(
                    session.isOnline ? 'Level ${p.level} · ${p.gamesPlayed} matches · ${p.wins} wins' : 'Offline',
                    style: const TextStyle(color: MMColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (session.isOnline)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${p.totalCoins} ¢', style: const TextStyle(color: MMColors.amber, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('best ${p.bestScore}', style: const TextStyle(color: MMColors.muted, fontSize: 11)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onJoin});
  final RoomSummary room;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final t = room.timeLeft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.landscape, color: MMColors.amber),
          title: Text('${room.mapId.def.name} · ${room.mode.label}'),
          subtitle: Text(
            '${room.humans} players + ${room.bots} bots · max ${room.maxPlayers} · ${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')} left',
          ),
          trailing: FilledButton(onPressed: room.isFull ? null : onJoin, child: Text(room.isFull ? 'FULL' : 'JOIN')),
        ),
      ),
    );
  }
}
