import 'package:flutter/material.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../../../../app/theme.dart';

/// Depot shop. Purchases are only requests — the server validates them.
class ShopPanel extends StatelessWidget {
  const ShopPanel({super.key, required this.me, required this.onBuy});
  final PlayerSnapshot me;
  final ValueChanged<UpgradeKind> onBuy;

  static IconData _icon(UpgradeKind k) => switch (k) {
    UpgradeKind.pickaxe => Icons.hardware,
    UpgradeKind.backpack => Icons.backpack,
    UpgradeKind.oxygenTank => Icons.air,
    UpgradeKind.helmet => Icons.light_mode,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MMColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MMColors.amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: MMColors.amber, size: 18),
              const SizedBox(width: 6),
              const Text('DEPOT SHOP', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              Text('${me.coins} ¢', style: const TextStyle(color: MMColors.amber, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          for (final k in UpgradeKind.values) _row(k),
        ],
      ),
    );
  }

  Widget _row(UpgradeKind k) {
    final lvl = me.level(k);
    final maxed = lvl >= k.maxLevel;
    final next = maxed ? null : k.levels[lvl + 1];
    final affordable = next != null && me.coins >= next.cost;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(_icon(k), size: 18, color: MMColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.levels[lvl].name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(
                  maxed ? 'Max level' : 'Next: ${next!.name}',
                  style: const TextStyle(fontSize: 10, color: MMColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 30,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: affordable ? () => onBuy(k) : null,
              child: Text(maxed ? 'MAX' : '${next!.cost}', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
