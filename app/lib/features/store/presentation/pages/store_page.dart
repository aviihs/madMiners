import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';
import '../../../auth/domain/entities/player_profile.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../cubit/store_cubit.dart';
import '../widgets/avatar_preview.dart';

/// Locker: try on and buy miners, outfits, helmets and pickaxes (pickaxes add dig power).
class StorePage extends StatelessWidget {
  const StorePage({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context) => BlocProvider(create: (_) => sl<StoreCubit>(), child: _StoreView(token: token));
}

class _StoreView extends StatelessWidget {
  const _StoreView({required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    return BlocListener<StoreCubit, StoreState>(
      listenWhen: (a, b) => b.error != null || b.message != null,
      listener: (context, s) => showToast(context, s.error ?? s.message!, error: s.error != null),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, auth) {
          if (auth is! AuthSignedIn) return const SizedBox();
          final profile = auth.session.profile;
          return BlocBuilder<StoreCubit, StoreState>(
            builder: (context, st) {
              final look = st.preview == null ? profile.look : profile.look.withItem(st.preview!);
              final items = cosmeticCatalog.where((c) => c.slot == st.slot).toList();
              return Scaffold(
                body: AppBackground(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      CupertinoSliverNavigationBar(
                        largeTitle: const Text('Locker'),
                        previousPageTitle: 'Lobby',
                        backgroundColor: const Color(0xE6120E1F),
                        border: null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CurrencyPill(profile.wallet),
                            const SizedBox(width: 6),
                            CurrencyPill(profile.gems, kind: CurrencyKind.gems),
                          ],
                        ),
                      ),
                      SliverSafeArea(
                        top: false,
                        sliver: SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          sliver: SliverList.list(
                            children: [
                              GlassCard(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF3B2580), Color(0xFF1E1832)],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(colors: [MMColors.gold.withValues(alpha: 0.3), MMColors.gold.withValues(alpha: 0)]),
                                      ),
                                      child: AvatarPreview(look: look, seed: profile.id, size: 200),
                                    ),
                                    Text(
                                      st.preview?.name ?? look.def(CosmeticSlot.character).name,
                                      style: MMText.title,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      st.preview == null
                                          ? look.def(CosmeticSlot.character).description
                                          : [
                                              if (st.preview!.description.isNotEmpty) st.preview!.description,
                                              profile.owns(st.preview!) ? 'Owned. Tap Wear to put it on.' : 'Trying it on. Buy to keep it.',
                                            ].join('\n'),
                                      style: MMText.footnote,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (st.slot == CosmeticSlot.pickaxe || st.preview?.slot == CosmeticSlot.pickaxe) ...[
                                      const SizedBox(height: 10),
                                      PickPower(item: st.preview ?? look.def(CosmeticSlot.pickaxe), large: true),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppSegmented<CosmeticSlot>(
                                value: st.slot,
                                items: {for (final s in CosmeticSlot.values) s: s.label},
                                onChanged: context.read<StoreCubit>().selectSlot,
                              ),
                              const SizedBox(height: 14),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                                itemBuilder: (context, i) => _ItemCard(
                                  item: items[i],
                                  profile: profile,
                                  selected: st.preview?.id == items[i].id,
                                  busy: st.busyItem == items[i].id,
                                  onTap: () => context.read<StoreCubit>().tryOn(items[i]),
                                  onAction: () => _act(context, profile, items[i]),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Earn coins in every match. Find the treasure to earn gems.\n'
                                'Pickaxes are real gear: you start every match already at their dig level.\n'
                                'Miners, outfits and helmets change how you look.',
                                textAlign: TextAlign.center,
                                style: MMText.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _act(BuildContext context, PlayerProfile profile, CosmeticDef item) async {
    final store = context.read<StoreCubit>();
    final auth = context.read<AuthCubit>();
    PlayerProfile? updated;
    if (profile.owns(item)) {
      updated = await store.equip(token, item);
    } else {
      final currency = item.currency == Currency.gems ? 'gems' : 'coins';
      final ok = await showConfirm(
        context,
        title: 'Buy ${item.name}?',
        message: 'This costs ${item.price} $currency.',
        confirm: 'Buy',
      );
      if (!ok) return;
      updated = await store.buy(token, item);
    }
    if (updated != null) auth.profileUpdated(updated);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.profile,
    required this.selected,
    required this.busy,
    required this.onTap,
    required this.onAction,
  });
  final CosmeticDef item;
  final PlayerProfile profile;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final owned = profile.owns(item);
    final equipped = profile.look.of(item.slot) == item.id;
    final gems = item.currency == Currency.gems;
    final affordable = gems ? profile.gems >= item.price : profile.wallet >= item.price;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: item.isPremium ? const [Color(0xFF173F45), Color(0xFF1C1630)] : const [Color(0xFF2A2246), Color(0xFF1C1630)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? MMColors.gold : (item.isPremium ? MMColors.gem.withValues(alpha: 0.55) : MMColors.hairline),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (item.isPremium) const Pill('PREMIUM', color: MMColors.gem) else if (!item.isFree && !owned) const Pill('NEW', color: MMColors.gold),
                const Spacer(),
                if (equipped) const Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: MMColors.leaf),
              ],
            ),
            Expanded(
              child: AvatarPreview(look: profile.look.withItem(item), seed: profile.id, size: 110, animate: false),
            ),
            Text(item.name, style: MMText.title.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (item.slot == CosmeticSlot.pickaxe) ...[const SizedBox(height: 4), PickPower(item: item)],
            const SizedBox(height: 8),
            if (equipped)
              Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: MMColors.leaf.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                child: Text('EQUIPPED', style: MMText.button.copyWith(fontSize: 14, color: MMColors.leaf)),
              )
            else if (owned)
              GameButton(label: 'Wear', tone: ButtonTone.dark, height: 40, fontSize: 15, loading: busy, onPressed: onAction)
            else
              GameButton(
                label: formatAmount(item.price),
                tone: gems ? ButtonTone.gem : ButtonTone.gold,
                leading: gems ? const GemIcon(size: 16) : const CoinIcon(size: 16),
                height: 40,
                fontSize: 15,
                loading: busy,
                onPressed: affordable ? onAction : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Dig power of a Locker pickaxe: pips plus the in-match level it starts at.
class PickPower extends StatelessWidget {
  const PickPower({super.key, required this.item, this.large = false});
  final CosmeticDef item;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final level = UpgradeKind.pickaxe.levels[item.power.clamp(0, UpgradeKind.pickaxe.maxLevel)];
    final pip = large ? 10.0 : 7.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.hammer_fill, size: pip + 4, color: MMColors.gold),
            const SizedBox(width: 4),
            for (var i = 0; i <= UpgradeKind.pickaxe.maxLevel; i++)
              Container(
                width: pip,
                height: pip,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= item.power ? MMColors.gold : MMColors.glassStrong,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          large ? 'Starts as ${level.name} · ${level.stat.toInt()} dmg per hit' : '${level.stat.toInt()} dmg / hit',
          style: MMText.caption.copyWith(fontSize: large ? 12 : 10.5, color: MMColors.gold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
