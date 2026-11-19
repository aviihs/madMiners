import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../../auth/domain/entities/session.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../game/domain/entities/game_target.dart';
import '../../../game/presentation/pages/game_page.dart';
import '../../../leaderboard/presentation/pages/leaderboard_page.dart';
import '../../../store/presentation/pages/store_page.dart';
import '../../../store/presentation/widgets/avatar_preview.dart';
import '../../domain/entities/room.dart';
import '../cubit/lobby_cubit.dart';
import '../widgets/create_room_sheet.dart';
import '../widgets/room_visuals.dart';

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
  Session get s => widget.session;
  String get token => s.token!;
  LobbyCubit get lobby => context.read<LobbyCubit>();

  Future<void> _enter(RoomTicket t) async {
    lobby.ticketConsumed();
    final again = await Navigator.of(context).push<bool>(
      GamePage.route(OnlineTarget(token: token, wsPath: t.wsPath, roomCode: t.roomCode)),
    );
    if (!mounted) return;
    context.read<AuthCubit>().refreshProfile();
    if (again == true) {
      lobby.quickPlay(token);
    } else {
      lobby.refresh(token);
    }
  }

  Future<void> _practice({MapId map = MapId.starterMine, GameMode mode = GameMode.treasureHunt}) async {
    final again = await Navigator.of(context).push<bool>(
      GamePage.route(OfflineTarget(playerName: s.profile.username, settings: MatchSettings(mapId: map, mode: mode))),
    );
    if (again == true && mounted) await _practice(map: map, mode: mode);
  }

  Future<void> _create({required bool offline}) async {
    final p = await showAppSheet<CreateRoomParams>(context, (_) => CreateRoomSheet(offline: offline));
    if (p == null || !mounted) return;
    if (offline) {
      await _practice(map: p.mapId, mode: p.mode);
    } else {
      await lobby.create(token, p);
    }
  }

  Future<void> _joinCode() async {
    final code = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Join private room'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: code,
            autofocus: true,
            placeholder: 'MMAB12',
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.w600, color: MMColors.text),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ],
      ),
    );
    if (ok == true && mounted) await lobby.joinByCode(token, code.text);
    code.dispose();
  }

  Future<void> _signOut() async {
    final yes = await showConfirm(context, title: 'Sign out?', message: 'You can sign back in any time.', confirm: 'Sign Out', destructive: true);
    if (yes && mounted) await context.read<AuthCubit>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LobbyCubit, LobbyState>(
      listenWhen: (a, b) => b.ticket != null || (b.error != null && a.error != b.error),
      listener: (context, st) {
        if (st.ticket != null) {
          _enter(st.ticket!);
        } else if (st.error != null) {
          showToast(context, st.error!, error: true);
        }
      },
      builder: (context, st) => Scaffold(
        body: AppBackground(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Mad Miners'),
                backgroundColor: const Color(0xB30C0A09),
                border: null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.isOnline)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(builder: (_) => LeaderboardPage(token: token, youId: s.profile.id)),
                        ),
                        child: const Icon(CupertinoIcons.chart_bar_alt_fill, size: 22),
                      ),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 8),
                      onPressed: _signOut,
                      child: const Icon(CupertinoIcons.person_crop_circle, size: 24),
                    ),
                  ],
                ),
              ),
              if (s.isOnline) CupertinoSliverRefreshControl(onRefresh: () => lobby.refresh(token)),
              SliverSafeArea(
                top: false,
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList.list(
                    children: [
                      _ProfileCard(session: s),
                      const SizedBox(height: 16),
                      _PlayCard(
                        online: s.isOnline,
                        busy: st.busy,
                        onPlay: s.isOnline ? () => lobby.quickPlay(token) : () => _practice(),
                      ),
                      const SizedBox(height: 12),
                      if (s.isOnline) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _ActionTile(
                                icon: CupertinoIcons.add,
                                color: MMColors.amber,
                                title: 'Create Room',
                                subtitle: 'Pick mine & rules',
                                onTap: st.busy ? null : () => _create(offline: false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: CupertinoIcons.number,
                                color: MMColors.blue,
                                title: 'Join Code',
                                subtitle: 'Play with friends',
                                onTap: st.busy ? null : _joinCode,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionTile(
                                icon: CupertinoIcons.person_crop_square_fill,
                                color: const Color(0xFFBF5AF2),
                                title: 'Locker',
                                subtitle: 'Outfits & skins',
                                onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => StorePage(token: token))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionTile(
                                icon: CupertinoIcons.game_controller_solid,
                                color: MMColors.stamina,
                                title: 'Practice',
                                subtitle: 'Offline match',
                                onTap: () => _create(offline: true),
                              ),
                            ),
                          ],
                        ),
                        SectionHeader(
                          'Live mines',
                          trailing: st.loading ? const CupertinoActivityIndicator(radius: 8) : Text('${st.rooms.length}', style: MMText.section),
                        ),
                        if (st.rooms.isEmpty && !st.loading)
                          const GlassCard(
                            child: Column(
                              children: [
                                Icon(CupertinoIcons.moon_zzz, color: MMColors.faint, size: 30),
                                SizedBox(height: 8),
                                Text('No live mines right now', style: MMText.headline),
                                SizedBox(height: 4),
                                Text('Tap Play — you\'ll be matched in seconds.', style: MMText.footnote, textAlign: TextAlign.center),
                              ],
                            ),
                          )
                        else if (st.rooms.isNotEmpty)
                          GroupedList(
                            children: [
                              for (final r in st.rooms)
                                ListRow(
                                  leading: MapThumb(r.mapId, size: 38),
                                  title: r.mapId.def.name,
                                  subtitle: '${r.mode.label} · ${_fmt(r.timeLeft)} left',
                                  trailing: Pill(
                                    '${r.humans + r.bots}/${r.maxPlayers}',
                                    icon: CupertinoIcons.person_2_fill,
                                    color: r.isFull ? MMColors.health : MMColors.stamina,
                                  ),
                                  onTap: r.isFull || st.busy ? null : () => lobby.join(token, r.roomId),
                                ),
                            ],
                          ),
                      ] else ...[
                        _ActionTile(
                          icon: CupertinoIcons.slider_horizontal_3,
                          color: MMColors.blue,
                          title: 'Custom practice',
                          subtitle: 'Choose mine and mode',
                          onTap: () => _create(offline: true),
                          wide: true,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'You\'re offline. Sign out and connect to a server to play online.',
                          style: MMText.footnote,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(int t) => '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    // XP progress inside the current level.
    var need = 100, rem = p.xp;
    for (var l = 1; l < p.level; l++) {
      rem -= need;
      need = (need * 1.25).round();
    }
    final progress = need == 0 ? 0.0 : (rem / need).clamp(0.0, 1.0);
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: MMColors.glassStrong),
            child: ClipOval(child: OverflowBox(maxWidth: 90, maxHeight: 90, child: AvatarPreview(look: p.look, seed: p.id, size: 90, animate: false))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.username, style: MMText.title.copyWith(fontSize: 20)),
                const SizedBox(height: 6),
                if (session.isOnline) ...[
                  Row(
                    children: [
                      Text('Level ${p.level}', style: MMText.footnote.copyWith(color: MMColors.amber, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 5,
                            child: Stack(
                              children: [
                                Container(color: MMColors.glassStrong),
                                FractionallySizedBox(widthFactor: progress, child: Container(decoration: const BoxDecoration(gradient: MMColors.accentGradient))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${p.wins} treasures · ${p.todayWins} today', style: MMText.caption),
                ] else
                  const Text('Offline profile', style: MMText.footnote),
              ],
            ),
          ),
          if (session.isOnline) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Pill('${p.wallet}', icon: CupertinoIcons.money_dollar_circle_fill, color: MMColors.gold),
                const SizedBox(height: 6),
                Pill('${p.gems}', icon: CupertinoIcons.suit_diamond_fill, color: const Color(0xFF64D2FF)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayCard extends StatelessWidget {
  const _PlayCard({required this.online, required this.busy, required this.onPlay});
  final bool online;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: busy ? () {} : onPlay,
    child: Container(
      constraints: const BoxConstraints(minHeight: 172),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB340), Color(0xFFFF6B2C), Color(0xFF8A2A0C)],
          stops: [0, 0.55, 1],
        ),
        boxShadow: const [BoxShadow(color: Color(0x55FF6B2C), blurRadius: 28, offset: Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(right: -18, bottom: -26, child: Icon(Icons.hardware_rounded, size: 170, color: Color(0x26FFFFFF))),
          const Positioned(right: 70, top: 20, child: Icon(CupertinoIcons.sparkles, size: 28, color: Color(0x55FFFFFF))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(online ? 'TREASURE HUNT' : 'PRACTICE',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Color(0xCCFFFFFF))),
                const SizedBox(height: 4),
                Text(online ? 'Play Now' : 'Start Digging',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: CupertinoColors.white)),
                const SizedBox(height: 2),
                const Text('First to break the treasure wins.', style: TextStyle(fontSize: 14, color: Color(0xDDFFFFFF))),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(color: CupertinoColors.white, borderRadius: BorderRadius.circular(99)),
                  child: busy
                      ? const CupertinoActivityIndicator(color: Color(0xFFFF6B2C))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.play_fill, size: 16, color: Color(0xFFE2551F)),
                            const SizedBox(width: 6),
                            Text(online ? 'Find a match' : 'Play now',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE2551F))),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.wide = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: MMText.headline),
        const SizedBox(height: 2),
        Text(subtitle, style: MMText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GlassCard(
        onTap: onTap ?? () {},
        padding: const EdgeInsets.all(14),
        child: wide
            ? Row(children: [IconTile(icon, color: color), const SizedBox(width: 12), Expanded(child: text), const Icon(CupertinoIcons.chevron_forward, size: 16, color: MMColors.faint)])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [IconTile(icon, color: color), const SizedBox(height: 12), text]),
      ),
    );
  }
}
