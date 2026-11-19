/// Server-side balance configuration.
///
/// Every number that affects the economy or difficulty lives here so it can be
/// tuned without touching gameplay code (SRS §11.4).
library;

enum Rarity { common, rare, epic, legendary }

/// Loot found while digging. Coins are credited the moment it breaks.
enum OreType { copper, iron, gold, diamond, moneyBag }

class OreDef {
  const OreDef({
    required this.type,
    required this.name,
    required this.rarity,
    required this.value,
    required this.hardness,
  });

  final OreType type;
  final String name;
  final Rarity rarity;

  /// Coins credited when mined.
  final int value;

  /// Hit points of the deposit.
  final int hardness;
}

const Map<OreType, OreDef> oreDefs = {
  OreType.copper: OreDef(type: OreType.copper, name: 'Copper', rarity: Rarity.common, value: 5, hardness: 3),
  OreType.iron: OreDef(type: OreType.iron, name: 'Iron', rarity: Rarity.common, value: 10, hardness: 4),
  OreType.gold: OreDef(type: OreType.gold, name: 'Gold', rarity: Rarity.rare, value: 30, hardness: 5),
  OreType.diamond: OreDef(type: OreType.diamond, name: 'Diamond', rarity: Rarity.epic, value: 80, hardness: 7),
  OreType.moneyBag: OreDef(type: OreType.moneyBag, name: 'Money Bag', rarity: Rarity.epic, value: 120, hardness: 2),
};

/// Purchasable at the surface depot (SRS §3.6).
enum UpgradeKind { pickaxe, helmet }

class UpgradeLevel {
  const UpgradeLevel(this.name, this.cost, this.stat, [this.cooldown = 0]);

  final String name;

  /// Cost to buy this level (level 0 is starting gear).
  final int cost;

  /// Pickaxe: damage per hit. Helmet: light radius in tiles.
  final double stat;

  /// Pickaxe only: seconds between hits.
  final double cooldown;
}

const Map<UpgradeKind, List<UpgradeLevel>> upgradeTracks = {
  UpgradeKind.pickaxe: [
    UpgradeLevel('Basic Pickaxe', 0, 1, 0.40),
    UpgradeLevel('Iron Pickaxe', 40, 2, 0.36),
    UpgradeLevel('Steel Pickaxe', 120, 3, 0.32),
    UpgradeLevel('Diamond Pickaxe', 280, 5, 0.28),
    UpgradeLevel('Laser Drill', 600, 8, 0.22),
  ],
  UpgradeKind.helmet: [
    UpgradeLevel('Cap', 0, 5),
    UpgradeLevel('Mining Helmet', 60, 7),
    UpgradeLevel('Floodlight Helmet', 200, 9.5),
  ],
};

extension UpgradeKindX on UpgradeKind {
  List<UpgradeLevel> get levels => upgradeTracks[this]!;
  int get maxLevel => levels.length - 1;
  String get label => switch (this) {
    UpgradeKind.pickaxe => 'Pickaxe',
    UpgradeKind.helmet => 'Helmet',
  };
}

/// Gameplay tuning constants.
abstract final class Balance {
  /// Bots fill a room until it has at least this many miners.
  static const int minPlayers = 8;

  /// Hard cap per room (humans + bots).
  static const int maxPlayers = 12;

  static const int tickRate = 30;
  static const int snapshotEvery = 2; // => 15 snapshots / second

  static const double playerRadius = 0.32;
  static const double moveSpeed = 4.2; // tiles / second
  static const double tiredSpeedFactor = 0.7;

  static const double maxHealth = 100;
  static const double maxStamina = 100;
  static const double staminaPerHit = 4;
  static const double staminaRegen = 16;

  static const double lavaDamage = 250; // basically instant
  static const double gasDamage = 12;
  static const double depotHeal = 20;

  static const double respawnSeconds = 3;
  static const double mineReach = 1.6;
  static const int rockHardness = 2;
  static const int hardRockHardness = 3;

  /// The hidden treasure: whoever breaks it wins the match.
  static const int treasureHardness = 6;
  static const int treasureBonus = 500;
  static const String treasureName = 'Lost Treasure';

  static const int reconnectWindowSeconds = 60;
  static const int defaultMatchSeconds = 360;

  /// Teams in Team mode.
  static const int teamCount = 2;

  static int levelForXp(int xp) {
    var level = 1;
    var needed = 100;
    var remaining = xp;
    while (remaining >= needed) {
      remaining -= needed;
      level++;
      needed = (needed * 1.25).round();
    }
    return level;
  }
}
