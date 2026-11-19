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

/// Locker: try on and buy outfits, helmets and pickaxe skins.
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
                        backgroundColor: const Color(0xB30C0A09),
                        border: null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Pill('${profile.wallet}', icon: CupertinoIcons.money_dollar_circle_fill, color: MMColors.gold),
                            const SizedBox(width: 6),
                            Pill('${profile.gems}', icon: CupertinoIcons.suit_diamond_fill, color: const Color(0xFF64D2FF)),
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
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(colors: [Color(0x40FFB340), Color(0x00FFB340)]),
                                      ),
                                      child: AvatarPreview(look: look, seed: profile.id, size: 190),
                                    ),
                                    Text(profile.username, style: MMText.title),
                                    const SizedBox(height: 4),
                                    Text(
                                      st.preview == null ? 'Tap an item to try it on' : 'Trying on: ${st.preview!.name}',
                                      style: MMText.footnote,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              CupertinoSlidingSegmentedControl<CosmeticSlot>(
                                groupValue: st.slot,
                                thumbColor: MMColors.surfaceHi,
                                backgroundColor: MMColors.glass,
                                children: {
                                  for (final s in CosmeticSlot.values)
                                    s: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.label, style: MMText.headline.copyWith(fontSize: 15))),
                                },
                                onValueChanged: (v) => context.read<StoreCubit>().selectSlot(v ?? st.slot),
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
                                  childAspectRatio: 0.78,
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
                                'Earn coins by playing. Find the treasure to earn 💎 gems.\nCosmetics never change gameplay.',
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
          color: selected ? MMColors.amber.withValues(alpha: 0.12) : MMColors.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? MMColors.amber : (item.isPremium ? const Color(0x8064D2FF) : MMColors.hairline),
            width: selected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (item.isPremium) const Pill('PREMIUM', color: Color(0xFF64D2FF)),
                const Spacer(),
                if (equipped) const Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: MMColors.stamina),
              ],
            ),
            Expanded(
              child: AvatarPreview(look: profile.look.withItem(item), seed: profile.id, size: 110, animate: false),
            ),
            Text(item.name, style: MMText.headline.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                borderRadius: BorderRadius.circular(99),
                color: equipped ? MMColors.glassStrong : (owned ? MMColors.blue : (affordable ? MMColors.amber : MMColors.glassStrong)),
                onPressed: equipped || busy ? null : onAction,
                disabledColor: MMColors.glassStrong,
                child: busy
                    ? const CupertinoActivityIndicator(radius: 8)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!owned) ...[
                            Icon(
                              gems ? CupertinoIcons.suit_diamond_fill : CupertinoIcons.money_dollar_circle_fill,
                              size: 14,
                              color: affordable ? CupertinoColors.white : MMColors.muted,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            equipped ? 'Wearing' : (owned ? 'Wear' : '${item.price}'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: equipped ? MMColors.muted : (owned || affordable ? CupertinoColors.white : MMColors.muted),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
