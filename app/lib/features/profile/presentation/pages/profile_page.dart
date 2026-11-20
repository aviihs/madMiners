import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../../../core/config/google_config.dart';
import '../../../auth/domain/entities/player_profile.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../lobby/presentation/widgets/room_visuals.dart';
import '../../../store/presentation/widgets/avatar_preview.dart';
import '../../domain/entities/history.dart';
import '../cubit/profile_cubit.dart';

enum _Tab { matches, wallet }

/// Player records from the database: stats, match history, wallet history.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.token});
  final String token;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _tab = _Tab.matches;
  bool _linking = false;

  Future<void> _linkGoogle() async {
    setState(() => _linking = true);
    final err = await context.read<AuthCubit>().linkGoogle();
    if (!mounted) return;
    setState(() => _linking = false);
    if (err != null) {
      showToast(context, err, error: true);
    } else {
      showToast(context, 'Google account linked. Your progress is safe.');
    }
  }

  Future<void> _signOut() async {
    final yes = await showConfirm(context, title: 'Sign out?', message: 'You can sign back in any time.', confirm: 'Sign Out', destructive: true);
    if (!yes || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await context.read<AuthCubit>().signOut();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<ProfileCubit>()..load(widget.token),
    child: BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        if (auth is! AuthSignedIn) return const SizedBox();
        final p = auth.session.profile;
        return Scaffold(
          body: AppBackground(
            child: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, st) => CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  CupertinoSliverNavigationBar(
                    largeTitle: const Text('Profile'),
                    previousPageTitle: 'Lobby',
                    backgroundColor: const Color(0xE6120E1F),
                    border: null,
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _signOut,
                      child: const Icon(CupertinoIcons.square_arrow_right, color: MMColors.muted),
                    ),
                  ),
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      await Future.wait([context.read<ProfileCubit>().load(widget.token), context.read<AuthCubit>().refreshProfile()]);
                    },
                  ),
                  SliverSafeArea(
                    top: false,
                    sliver: SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      sliver: SliverList.list(
                        children: [
                          _Header(profile: p),
                          const SizedBox(height: 14),
                          _StatsGrid(profile: p),
                          if (!p.hasGoogle && GoogleConfig.platformSupported) ...[
                            const SizedBox(height: 14),
                            GlassCard(
                              borderColor: MMColors.sky.withValues(alpha: 0.4),
                              child: Row(
                                children: [
                                  const IconTile(CupertinoIcons.shield_lefthalf_fill, color: MMColors.sky, size: 42),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Protect your progress', style: MMText.headline),
                                        SizedBox(height: 2),
                                        Text('Link Google to keep coins and miners on any device.', style: MMText.caption),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 86,
                                    child: GameButton(label: 'Link', tone: ButtonTone.light, height: 42, fontSize: 15, loading: _linking, onPressed: _linkGoogle),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          AppSegmented<_Tab>(
                            value: _tab,
                            items: const {_Tab.matches: 'Matches', _Tab.wallet: 'Wallet'},
                            onChanged: (t) => setState(() => _tab = t),
                          ),
                          const SizedBox(height: 14),
                          if (st.loading)
                            const Padding(padding: EdgeInsets.only(top: 40), child: CupertinoActivityIndicator(radius: 13))
                          else if (st.error != null)
                            Padding(padding: const EdgeInsets.only(top: 30), child: Text(st.error!, textAlign: TextAlign.center, style: MMText.callout))
                          else if (_tab == _Tab.matches)
                            _MatchList(items: st.matches)
                          else
                            _WalletList(items: st.wallet),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
      child: Row(
        children: [
          AvatarPreview(look: p.look, seed: p.id, size: 120),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Text(p.username, style: MMText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill('LEVEL ${p.level}', color: MMColors.gold),
                    if (p.hasGoogle) const Pill('GOOGLE', color: MMColors.sky, icon: CupertinoIcons.checkmark_seal_fill) else const Pill('GUEST', color: MMColors.muted),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CurrencyPill(p.wallet),
                    const SizedBox(width: 6),
                    CurrencyPill(p.gems, kind: CurrencyKind.gems),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile});
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final stats = [
      (CupertinoIcons.star_fill, MMColors.gold, '${p.wins}', 'Treasures'),
      (CupertinoIcons.flame_fill, MMColors.lava, formatAmount(p.bestScore), 'Best score'),
      (CupertinoIcons.arrow_down_to_line, MMColors.sky, '${p.bestDepth}m', 'Deepest'),
      (CupertinoIcons.game_controller_solid, MMColors.violet, '${p.gamesPlayed}', 'Matches'),
      (CupertinoIcons.cube_box_fill, MMColors.gem, formatAmount(p.oresMined), 'Loot found'),
      (CupertinoIcons.money_dollar_circle_fill, MMColors.goldLight, formatAmount(p.totalCoins), 'Coins earned'),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final (icon, color, value, label) in stats)
          GlassCard(
            padding: const EdgeInsets.all(10),
            radius: 18,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 6),
                FittedBox(child: Text(value, style: MMText.title.copyWith(fontSize: 22))),
                const SizedBox(height: 2),
                Text(label, style: MMText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
      ],
    );
  }
}

String _when(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}

class _MatchList extends StatelessWidget {
  const _MatchList({required this.items});
  final List<MatchHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Empty(icon: CupertinoIcons.game_controller, text: 'No matches yet.\nPlay one to start your record.');
    }
    return GroupedList(
      children: [
        for (final m in items)
          ListRow(
            leading: MapThumb(m.mapId, size: 40),
            title: m.foundTreasure ? 'Found the treasure' : 'Finished #${m.rank} of ${m.playerCount}',
            subtitle: '${m.mapId.def.name}  ·  ${m.maxDepth}m deep  ·  ${_when(m.endedAt)}',
            highlight: m.foundTreasure,
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [const CoinIcon(size: 14), const SizedBox(width: 4), Text('+${m.coinsAwarded}', style: MMText.number.copyWith(fontSize: 15, color: MMColors.text))]),
                if (m.gemsAwarded > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [const GemIcon(size: 13), const SizedBox(width: 4), Text('+${m.gemsAwarded}', style: MMText.number.copyWith(fontSize: 13, color: MMColors.gem))]),
              ],
            ),
          ),
      ],
    );
  }
}

class _WalletList extends StatelessWidget {
  const _WalletList({required this.items});
  final List<WalletEntry> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Empty(icon: CupertinoIcons.creditcard, text: 'No coins or gems moved yet.');
    }
    return GroupedList(
      children: [
        for (final t in items)
          ListRow(
            leading: t.currency == WalletCurrency.coins ? const CoinIcon(size: 26) : const GemIcon(size: 26),
            title: t.label,
            subtitle: '${_when(t.createdAt)}  ·  balance ${formatAmount(t.balanceAfter)}',
            trailing: Text(
              '${t.amount > 0 ? '+' : ''}${formatAmount(t.amount)}',
              style: MMText.number.copyWith(fontSize: 17, color: t.amount >= 0 ? MMColors.leaf : MMColors.lava),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, color: MMColors.faint, size: 32),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: MMText.footnote),
      ],
    ),
  );
}
