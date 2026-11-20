import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../../auth/domain/entities/session.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../game/domain/entities/game_target.dart';
import '../../../game/presentation/pages/game_page.dart';
import '../../../leaderboard/presentation/cubit/leaderboard_cubit.dart';
import '../../../leaderboard/presentation/pages/leaderboard_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../rewards/presentation/daily_reward_card.dart';
import '../../../settings/presentation/pages/settings_page.dart';
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
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) {
          final c = sl<LobbyCubit>();
          if (session.isOnline) c.refresh(session.token!);
          return c;
        },
      ),
      BlocProvider(
        create: (_) {
          final c = sl<LeaderboardCubit>();
          if (session.isOnline) c.load(session.token!, Board.today);
          return c;
        },
      ),
    ],
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

  Future<void> _refresh() async {
    if (!s.isOnline) return;
    await Future.wait([
      lobby.refresh(token),
      context.read<LeaderboardCubit>().load(token, Board.today),
      context.read<AuthCubit>().refreshProfile(),
    ]);
  }

  Future<void> _enter(RoomTicket t) async {
    lobby.ticketConsumed();
    final again = await Navigator.of(context).push<bool>(
      GamePage.route(OnlineTarget(token: token, wsPath: t.wsPath, roomCode: t.roomCode)),
    );
    if (!mounted) return;
    await _refresh();
    if (again == true) lobby.quickPlay(token);
  }

  Future<void> _practice({MapId map = MapId.starterMine, GameMode mode = GameMode.treasureHunt}) async {
    final again = await Navigator.of(context).push<bool>(
      GamePage.route(
        OfflineTarget(playerName: s.profile.username, settings: MatchSettings(mapId: map, mode: mode)),
      ),
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
        title: const Text('Join a private room', style: TextStyle(fontFamily: MMFonts.display, fontSize: 20)),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: code,
            autofocus: true,
            placeholder: 'MMAB12',
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontFamily: MMFonts.display, fontSize: 24, letterSpacing: 4, color: MMColors.text),
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

  void _open(Widget page) => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));

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
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                if (s.isOnline) CupertinoSliverRefreshControl(onRefresh: _refresh),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  sliver: SliverList.list(
                    children: [
                      _TopBar(
                        session: s,
                        onProfile: () => s.isOnline ? _open(ProfilePage(token: token)) : context.read<AuthCubit>().signOut(),
                      ),
                      const SizedBox(height: 18),
                      _PlayCard(
                        online: s.isOnline,
                        busy: st.busy,
                        onPlay: s.isOnline ? () => lobby.quickPlay(token) : () => _practice(),
                      ),
                      const SizedBox(height: 14),
                      if (s.isOnline) DailyRewardCard(token: token),
                      _Tile(
                        icon: CupertinoIcons.gear_alt_fill,
                        color: MMColors.muted,
                        title: 'Settings',
                        subtitle: 'Sound, vibration, controls',
                        wide: true,
                        onTap: () => _open(const SettingsPage()),
                      ),
                      const SizedBox(height: 12),
                      if (s.isOnline) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _Tile(
                                icon: CupertinoIcons.person_crop_square_fill,
                                color: MMColors.violet,
                                title: 'Locker',
                                subtitle: 'Miners & outfits',
                                onTap: () => _open(StorePage(token: token)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Tile(
                                icon: CupertinoIcons.chart_bar_alt_fill,
                                color: MMColors.gold,
                                title: 'Rankings',
                                subtitle: 'Today and all time',
                                onTap: () => _open(LeaderboardPage(token: token, youId: s.profile.id)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Tile(
                                icon: CupertinoIcons.add_circled_solid,
                                color: MMColors.sky,
                                title: 'Create',
                                subtitle: 'Your own room',
                                onTap: st.busy ? null : () => _create(offline: false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Tile(
                                icon: CupertinoIcons.number_circle_fill,
                                color: MMColors.gem,
                                title: 'Join Code',
                                subtitle: 'Play with friends',
                                onTap: st.busy ? null : _joinCode,
                              ),
                            ),
                          ],
                        ),
                        _TodayLeaders(youId: s.profile.id, onMore: () => _open(LeaderboardPage(token: token, youId: s.profile.id))),
                        SectionHeader(
                          'Live mines',
                          trailing: st.loading
                              ? const CupertinoActivityIndicator(radius: 8)
                              : CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(28, 28),
                                  onPressed: () => lobby.refresh(token),
                                  child: const Icon(CupertinoIcons.arrow_clockwise, size: 18, color: MMColors.muted),
                                ),
                        ),
                        if (st.rooms.isEmpty && !st.loading)
                          const GlassCard(
                            child: Row(
                              children: [
                                IconTile(CupertinoIcons.moon_stars_fill, color: MMColors.violet),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('No live mines right now', style: MMText.headline),
                                      SizedBox(height: 2),
                                      Text('Tap Play. You will be matched in seconds.', style: MMText.footnote),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (st.rooms.isNotEmpty)
                          GroupedList(
                            children: [
                              for (final r in st.rooms)
                                ListRow(
                                  leading: MapThumb(r.mapId, size: 40),
                                  title: r.mapId.def.name,
                                  subtitle: '${r.mode.label}  ·  ${_fmt(r.timeLeft)} left',
                                  trailing: Pill(
                                    '${r.humans + r.bots}/${r.maxPlayers}',
                                    icon: CupertinoIcons.person_2_fill,
                                    color: r.isFull ? MMColors.lava : MMColors.leaf,
                                  ),
                                  onTap: r.isFull || st.busy ? null : () => lobby.join(token, r.roomId),
                                ),
                            ],
                          ),
                        const SizedBox(height: 14),
                        _Tile(
                          icon: CupertinoIcons.game_controller_solid,
                          color: MMColors.leaf,
                          title: 'Practice offline',
                          subtitle: 'No internet needed',
                          onTap: () => _create(offline: true),
                          wide: true,
                        ),
                      ] else ...[
                        _Tile(
                          icon: CupertinoIcons.slider_horizontal_3,
                          color: MMColors.sky,
                          title: 'Custom practice',
                          subtitle: 'Choose mine and mode',
                          onTap: () => _create(offline: true),
                          wide: true,
                        ),
                        const SizedBox(height: 16),
                        GameButton(
                          label: 'Sign in to play online',
                          tone: ButtonTone.dark,
                          height: 50,
                          fontSize: 16,
                          onPressed: () => context.read<AuthCubit>().signOut(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(int t) => '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.onProfile});
  final Session session;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final p = session.profile;
    var need = 100, rem = p.xp;
    for (var l = 1; l < p.level; l++) {
      rem -= need;
      need = (need * 1.25).round();
    }
    final progress = (rem / need).clamp(0.0, 1.0);
    return Row(
      children: [
        PressableScale(
          onTap: onProfile,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF3A2F5C), MMColors.surface], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  border: Border.all(color: MMColors.gold, width: 2),
                ),
                child: ClipOval(
                  child: OverflowBox(maxWidth: 96, maxHeight: 96, child: AvatarPreview(look: p.look, seed: p.id, size: 96, animate: false)),
                ),
              ),
              if (session.isOnline)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: MMColors.gold, borderRadius: BorderRadius.circular(8), border: Border.all(color: MMColors.bg, width: 2)),
                    child: Text('${p.level}', style: const TextStyle(fontFamily: MMFonts.display, fontSize: 13, color: MMColors.onGold)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.username, style: MMText.title.copyWith(fontSize: 21), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              if (session.isOnline)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 7,
                    width: 120,
                    child: Stack(
                      children: [
                        Container(color: MMColors.surfaceHi),
                        FractionallySizedBox(widthFactor: progress, child: Container(decoration: const BoxDecoration(gradient: MMColors.accentGradient))),
                      ],
                    ),
                  ),
                )
              else
                const Text('Offline', style: MMText.caption),
            ],
          ),
        ),
        if (session.isOnline)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CurrencyPill(p.wallet),
              const SizedBox(height: 6),
              CurrencyPill(p.gems, kind: CurrencyKind.gems),
            ],
          ),
      ],
    );
  }
}

class _PlayCard extends StatelessWidget {
  const _PlayCard({required this.online, required this.busy, required this.onPlay});
  final bool online;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6A3FD9), Color(0xFF3B2580), Color(0xFF221548)],
      ),
      border: Border.all(color: const Color(0x40FFFFFF)),
      boxShadow: const [
        BoxShadow(color: Color(0x806A3FD9), blurRadius: 30, offset: Offset(0, 14)),
        BoxShadow(color: Color(0xFF1A0F3A), offset: Offset(0, 6)),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [MMColors.gold.withValues(alpha: 0.45), MMColors.gold.withValues(alpha: 0)]),
            ),
          ),
        ),
        const Positioned(
          right: 4,
          bottom: 60,
          child: AvatarPreview(
            look: Look(character: 'char_tinker', outfit: 'outfit_purple', helmet: 'helmet_yellow', pickaxe: 'pick_gold'),
            seed: 'p',
            size: 150,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pill(online ? 'ONLINE  ·  8-12 MINERS' : 'PRACTICE', color: MMColors.goldLight),
              const SizedBox(height: 10),
              const Text(
                'TREASURE\nHUNT',
                style: TextStyle(fontFamily: MMFonts.display, fontSize: 38, height: 0.95, color: CupertinoColors.white, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 190,
                child: Text(
                  'Break the rock, dodge the lava, and grab the hidden treasure first.',
                  style: TextStyle(fontFamily: MMFonts.body, fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xCCFFFFFF)),
                ),
              ),
              const SizedBox(height: 18),
              GameButton(label: online ? 'Play' : 'Play now', icon: CupertinoIcons.play_fill, loading: busy, onPressed: onPlay, height: 58, fontSize: 22),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap, this.wide = false});
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
        Text(title, style: MMText.title.copyWith(fontSize: 18)),
        const SizedBox(height: 2),
        Text(subtitle, style: MMText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GlassCard(
        onTap: onTap ?? () {},
        padding: const EdgeInsets.all(14),
        radius: 20,
        child: wide
            ? Row(
                children: [
                  IconTile(icon, color: color, size: 42),
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  const Icon(CupertinoIcons.chevron_forward, size: 16, color: MMColors.faint),
                ],
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [IconTile(icon, color: color, size: 42), const SizedBox(height: 12), text]),
      ),
    );
  }
}

/// Today's top three, straight from the daily leaderboard.
class _TodayLeaders extends StatelessWidget {
  const _TodayLeaders({required this.youId, required this.onMore});
  final String youId;
  final VoidCallback onMore;

  static const _medals = [MMColors.gold, Color(0xFFC9D1E0), Color(0xFFE09A5B)];

  @override
  Widget build(BuildContext context) => BlocBuilder<LeaderboardCubit, LeaderboardState>(
    builder: (context, st) {
      final top = st.entries.take(3).toList();
      return Column(
        children: [
          SectionHeader(
            "Today's top miners",
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              onPressed: onMore,
              child: const Text('See all', style: TextStyle(fontFamily: MMFonts.body, fontWeight: FontWeight.w800, fontSize: 13, color: MMColors.gold)),
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: st.loading
                ? const SizedBox(height: 90, child: Center(child: CupertinoActivityIndicator()))
                : top.isEmpty
                ? const SizedBox(
                    height: 70,
                    child: Center(
                      child: Text('No treasure found yet today.\nWin a match to take the top spot.', textAlign: TextAlign.center, style: MMText.footnote),
                    ),
                  )
                : Row(
                    children: [
                      for (final (i, e) in top.indexed)
                        Expanded(
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  SizedBox.square(
                                    dimension: 64,
                                    child: e.look == null
                                        ? Avatar(e.username, size: 56)
                                        : AvatarPreview(look: e.look!, seed: e.playerId, size: 64, animate: i == 0),
                                  ),
                                  Positioned(
                                    left: -2,
                                    top: -2,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _medals[i],
                                        shape: BoxShape.circle,
                                        border: Border.all(color: MMColors.surface, width: 2),
                                      ),
                                      child: Text('${i + 1}', style: const TextStyle(fontFamily: MMFonts.display, fontSize: 12, color: MMColors.onGold)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                e.playerId == youId ? 'You' : e.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MMText.headline.copyWith(fontSize: 14, color: e.playerId == youId ? MMColors.gold : null),
                              ),
                              Text('${e.todayWins} ${e.todayWins == 1 ? 'win' : 'wins'}', style: MMText.caption),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}
