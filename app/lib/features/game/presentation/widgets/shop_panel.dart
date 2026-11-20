import 'package:flutter/cupertino.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/theme.dart';
import '../../../../app/ui/ui.dart';

/// Surface shop: equipment upgrades + bombs, paid with match coins.
/// Purchases are only requests — the server validates them.
class ShopPanel extends StatelessWidget {
  const ShopPanel({super.key, required this.me, required this.onUpgrade, required this.onBuyItem});
  final PlayerSnapshot me;
  final ValueChanged<UpgradeKind> onUpgrade;
  final ValueChanged<ItemKind> onBuyItem;

  static IconData upgradeIcon(UpgradeKind k) => switch (k) {
    UpgradeKind.pickaxe => CupertinoIcons.hammer_fill,
    UpgradeKind.helmet => CupertinoIcons.lightbulb_fill,
    UpgradeKind.boots => CupertinoIcons.hare_fill,
    UpgradeKind.armor => CupertinoIcons.shield_fill,
  };

  static String _hint(UpgradeKind k) => switch (k) {
    UpgradeKind.pickaxe => 'Dig faster',
    UpgradeKind.helmet => 'See & sense farther',
    UpgradeKind.boots => 'Run faster',
    UpgradeKind.armor => 'Less blast damage',
  };

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height - 140;
    return GlassCard(
      radius: 20,
      color: const Color(0xA6000000),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 316, maxHeight: maxH.clamp(160, 520)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(CupertinoIcons.bag_fill, size: 26),
                  const SizedBox(width: 8),
                  const Text('Shop', style: MMText.headline),
                  const Spacer(),
                  CurrencyPill(me.coins),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in UpgradeKind.values) _upgradeTile(k),
                  for (final k in ItemKind.values) _itemTile(k),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upgradeTile(UpgradeKind k) {
    final lvl = me.level(k);
    final maxed = lvl >= k.maxLevel;
    final next = maxed ? null : k.levels[lvl + 1];
    return _Tile(
      icon: upgradeIcon(k),
      color: MMColors.blue,
      title: maxed ? k.levels[lvl].name : next!.name,
      subtitle: maxed ? 'Maxed' : _hint(k),
      level: '${lvl + 1}/${k.maxLevel + 1}',
      price: maxed ? null : next!.cost,
      enabled: !maxed && me.coins >= next!.cost,
      onTap: () => onUpgrade(k),
    );
  }

  Widget _itemTile(ItemKind k) {
    final def = itemDefs[k]!;
    final have = me.itemCount(k);
    final full = have >= Balance.maxItemStack;
    return _Tile(
      icon: k == ItemKind.bomb ? CupertinoIcons.burst_fill : CupertinoIcons.flame_fill,
      color: MMColors.ember,
      title: def.name,
      subtitle: k == ItemKind.bomb ? 'Blasts 3×3' : 'Blasts 5×5',
      level: '×$have',
      price: full ? null : def.cost,
      enabled: !full && me.coins >= def.cost,
      onTap: () => onBuyItem(k),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.price,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String level;
  final int? price;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 142,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: MMColors.glass, borderRadius: BorderRadius.circular(14), border: Border.all(color: MMColors.hairline, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon, color: color, size: 26),
              const Spacer(),
              Text(level, style: MMText.caption),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: MMText.headline.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(subtitle, style: MMText.caption.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
              borderRadius: BorderRadius.circular(99),
              color: enabled ? MMColors.amber : MMColors.glassStrong,
              disabledColor: MMColors.glassStrong,
              onPressed: enabled ? onTap : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (price != null) ...[const CoinIcon(size: 13), const SizedBox(width: 4)],
                  Text(
                    price == null ? 'MAX' : '$price',
                    style: MMText.number.copyWith(fontSize: 14, color: enabled ? MMColors.onGold : MMColors.muted),
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
