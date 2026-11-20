/// Server-side balance configuration.
///
/// Every number that affects the economy or difficulty lives here so it can be
/// tuned without touching gameplay code (SRS §11.4).
library;

enum Rarity { common, rare, epic, legendary }

/// Loot found while digging. Coins are credited the moment it breaks.
/// Append only: the index is the wire encoding.
enum OreType { copper, iron, gold, diamond, moneyBag, coal, silver, emerald, ruby }

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
  OreType.coal: OreDef(type: OreType.coal, name: 'Coal', rarity: Rarity.common, value: 3, hardness: 2),
  OreType.silver: OreDef(type: OreType.silver, name: 'Silver', rarity: Rarity.rare, value: 18, hardness: 4),
  OreType.emerald: OreDef(type: OreType.emerald, name: 'Emerald', rarity: Rarity.epic, value: 55, hardness: 6),
  OreType.ruby: OreDef(type: OreType.ruby, name: 'Ruby', rarity: Rarity.epic, value: 65, hardness: 6),
};

// ---- depth zones ------------------------------------------------------------

/// Named layers of the mine, from the camp down to the lava.
enum Zone {
  starterMine('Starter Mine'),
  stoneCave('Stone Cave'),
  goldMine('Gold Mine'),
  diamondCave('Diamond Cave'),
  crystalCavern('Crystal Cavern'),
  lavaUnderground('Lava Underground');

  const Zone(this.label);
  final String label;

  /// Zone at depth fraction [d] (0 = surface, 1 = lava sea).
  static Zone at(double d) {
    if (d < 0.12) return starterMine;
    if (d < 0.30) return stoneCave;
    if (d < 0.48) return goldMine;
    if (d < 0.66) return diamondCave;
    if (d < 0.83) return crystalCavern;
    return lavaUnderground;
  }
}

// ---- mystery bombs ------------------------------------------------------------

/// Hidden until opened. Deeper bombs tend to be rarer.
enum MysteryRarity {
  common('Common', 1.0),
  rare('Rare', 1.6),
  epic('Epic', 2.5),
  legendary('Legendary', 4.0),
  mythic('Mythic', 7.0);

  const MysteryRarity(this.label, this.mult);
  final String label;

  /// Scales coin and gem rewards.
  final double mult;
}

/// What comes out of a Mystery Bomb. Rolled by the server only.
enum MysteryReward {
  goldShower('Gold Shower'),
  diamondBurst('Diamond Burst'),
  crystals('Crystal Reward'),
  jackpot('JACKPOT'),
  energy('Energy Refill'),
  explosives('Explosives Cache'),
  monster('Monster Surprise'),
  prank('Slime Prank'),
  cursed('Cursed Treasure');

  const MysteryReward(this.label);
  final String label;
}

// ---- monsters -----------------------------------------------------------------

enum MonsterKind { spider, golem }

class MonsterDef {
  const MonsterDef({
    required this.name,
    required this.hp,
    required this.speed,
    required this.damage,
    required this.attackEvery,
    required this.sense,
    required this.loot,
  });
  final String name;
  final double hp;
  final double speed;
  final double damage;
  final double attackEvery;

  /// Tiles at which it notices a miner.
  final double sense;

  /// Coins for the miner who lands the killing blow.
  final int loot;
}

const Map<MonsterKind, MonsterDef> monsterDefs = {
  MonsterKind.spider: MonsterDef(name: 'Cave Spider', hp: 30, speed: 3.6, damage: 9, attackEvery: 0.8, sense: 6, loot: 25),
  MonsterKind.golem: MonsterDef(name: 'Stone Golem', hp: 120, speed: 1.6, damage: 22, attackEvery: 1.6, sense: 4.5, loot: 90),
};

// ---- world events ---------------------------------------------------------------

/// Server-timed events that shake up a match.
enum WorldEventKind {
  goldRush('Gold Rush', 'All ore pays double!', 25),
  earthquake('Earthquake', 'Rocks are falling, watch your head!', 9),
  mysteryRain('Mystery Bomb Rain', 'New Mystery Bombs appeared in the rock!', 4),
  caveCollapse('Cave Collapse', 'The ceiling is coming down!', 4),
  lavaBreakthrough('Lava Breakthrough', 'Lava is breaking into the tunnels!', 6),
  rareOreSurge('Rare Ore Surge', 'Rare ore has surfaced nearby!', 5),
  monsterInvasion('Monster Invasion', 'Monsters are swarming the mine!', 5),
  tntChain('TNT Chain Reaction', 'Hidden TNT is going off!', 5),
  hiddenTreasure('Hidden Treasure', 'Treasure chests appeared in the rock!', 4);

  const WorldEventKind(this.label, this.blurb, this.seconds);
  final String label;
  final String blurb;
  final double seconds;
}

/// Equipment bought with match coins at the surface shop (SRS §3.6).
enum UpgradeKind { pickaxe, helmet, boots, armor }

class UpgradeLevel {
  const UpgradeLevel(this.name, this.cost, this.stat, [this.cooldown = 0]);

  final String name;

  /// Cost to buy this level (level 0 is starting gear).
  final int cost;

  /// Pickaxe: damage per hit. Helmet: light radius in tiles.
  /// Boots: speed multiplier. Armor: share of bomb/gas/volcano damage blocked.
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
  UpgradeKind.boots: [
    UpgradeLevel('Sneakers', 0, 1.0),
    UpgradeLevel('Work Boots', 70, 1.15),
    UpgradeLevel('Rocket Boots', 260, 1.32),
  ],
  UpgradeKind.armor: [
    UpgradeLevel('T-Shirt', 0, 0),
    UpgradeLevel('Leather Vest', 90, 0.25),
    UpgradeLevel('Blast Armor', 300, 0.5),
  ],
};

/// Consumables, bought at the shop and used anywhere.
enum ItemKind { bomb, dynamite }

class ItemDef {
  const ItemDef(this.name, this.cost, this.radius, this.damage, this.fuse);
  final String name;
  final int cost;

  /// Blast radius in tiles.
  final double radius;

  /// Damage to miners caught in the blast (before armor).
  final double damage;

  /// Seconds before it goes off.
  final double fuse;
}

const Map<ItemKind, ItemDef> itemDefs = {
  ItemKind.bomb: ItemDef('Bomb', 25, 1.5, 55, 2.0),
  ItemKind.dynamite: ItemDef('Dynamite', 70, 2.5, 90, 2.6),
};

/// What an explosive crate does when it goes off (not sold in the shop).
const ItemDef crateBlast = ItemDef('Explosive Crate', 0, 2.0, 70, 3.0);

/// Hidden TNT found in the rock. Every kind goes off exactly
/// [Balance.tntFuseTicks] server ticks (3 s) after it's activated.
enum TntKind {
  basic('TNT', ItemDef('TNT', 0, 2.0, 70, 3)),
  powerful('Powerful TNT', ItemDef('Powerful TNT', 0, 3.2, 110, 3)),
  /// Big blast for rock (even obsidian), gentle on miners.
  mining('Mining TNT', ItemDef('Mining TNT', 0, 2.6, 22, 3)),
  /// Sets off every other TNT within reach.
  chain('Chain TNT', ItemDef('Chain TNT', 0, 2.0, 70, 3)),
  /// Small blast that leaves rare ore behind.
  treasure('Treasure TNT', ItemDef('Treasure TNT', 0, 1.6, 30, 3)),
  /// Goes off if you even walk next to it.
  unstable('Unstable TNT', ItemDef('Unstable TNT', 0, 2.2, 80, 3));

  const TntKind(this.label, this.blast);
  final String label;
  final ItemDef blast;
}

/// Launcher pad directions: (vx, vy) in tiles / second.
enum LaunchKind {
  up('Vertical Launcher', 0, -17),
  left('Left Launcher', -16, -7),
  right('Right Launcher', 16, -7),
  upLeft('Diagonal Launcher', -11, -14),
  upRight('Diagonal Launcher', 11, -14),
  heavy('Heavy Launcher', 0, -23),
  random('Random Launcher', 0, 0);

  const LaunchKind(this.label, this.vx, this.vy);
  final String label;
  final double vx;
  final double vy;
}

/// What a pressure plate sets off.
enum PlateTrap { collapse, spikes, tnt }

extension UpgradeKindX on UpgradeKind {
  List<UpgradeLevel> get levels => upgradeTracks[this]!;
  int get maxLevel => levels.length - 1;
  String get label => switch (this) {
    UpgradeKind.pickaxe => 'Pickaxe',
    UpgradeKind.helmet => 'Helmet',
    UpgradeKind.boots => 'Boots',
    UpgradeKind.armor => 'Armor',
  };
}

/// Daily login reward for day [streak] of a run (1-based; repeats every 7).
/// Day 7 also pays gems.
({int coins, int gems}) dailyReward(int streak) {
  final day = (streak - 1) % 7 + 1;
  return (coins: 50 + (day - 1) * 25, gems: day == 7 ? 10 : 0);
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

  // ---- gravity (side-view physics) ----
  /// Downward acceleration, tiles / s².
  static const double gravity = 30;

  /// Take-off speed of a jump. Clears a 1-tile ledge (apex ≈ 1.4 tiles).
  static const double jumpSpeed = 9.2;
  static const double maxFallSpeed = 20;

  /// How quickly you reach running speed on the ground / steer in the air.
  static const double groundAccel = 42;
  static const double airAccel = 16;

  /// Bracing against both walls of a 1-wide shaft lets you climb it.
  static const double climbSpeed = 2.6;

  /// Landing faster than this hurts (≈ a 3.5-tile drop).
  static const double safeFallSpeed = 14.5;
  static const double fallDamagePerSpeed = 7;

  /// Loose boulders fall when nothing holds them up.
  static const int boulderHardness = 4;
  static const double boulderWobble = 0.45;
  static const double boulderStepSeconds = 0.13;
  static const double boulderDamage = 45;

  /// Explosions shove miners and bombs around.
  static const double blastKnockback = 13;

  /// Lit bombs one miner may have out at once.
  static const int maxActiveBombs = 3;

  /// Seconds between two throws.
  static const double throwCooldown = 0.7;

  // ---- jetpack ----
  static const double jetFuelMax = 100;
  static const double jetBurn = 55; // fuel / second while thrusting
  static const double jetRegen = 30; // fuel / second, only while standing
  static const double jetThrust = 52; // tiles / s² upward (beats gravity)
  static const double jetMaxRise = 6.5; // tiles / s

  // ---- mystery bombs, monsters, events ----
  static const int mysteryHardness = 3;
  static const int obsidianHardness = 12;

  /// Suspense before a found Mystery Bomb bursts open.
  static const double mysteryOpenSeconds = 1.8;
  static const int maxMonsters = 14;

  /// Pickaxe damage to monsters = base + pickaxe stat × perStat.
  static const double monsterHitBase = 8;
  static const double monsterHitPerStat = 4;

  /// Seconds between world events (random within the range).
  static const double eventGapMin = 60;
  static const double eventGapMax = 100;

  // ---- hidden hazards, TNT, launchers, fluids ----
  /// TNT fuse: exactly 3 s of server ticks.
  static const int tntFuseTicks = 3 * tickRate;
  static const double launcherWarning = 0.3;
  static const double launcherCooldown = 3;
  static const double plateCooldown = 10;

  /// Hitting a wall or ceiling faster than this hurts.
  static const double safeImpactSpeed = 11;
  static const double impactDamagePerSpeed = 6;

  /// Fluids move one tile per step.
  static const double fluidStepSeconds = 0.2;

  /// In water / lava you move slower and sink slowly.
  static const double fluidDrag = 0.6;
  static const double fluidGravity = 0.3;
  static const double fluidMaxSink = 3;
  static const double swimSpeed = 4.5;

  /// Hidden traps on cave floors show up when a miner comes this close.
  static const double revealRadius = 1.8;

  /// The sealed treasure chamber opens when someone gets this close.
  static const double chamberOpenRadius = 4.5;

  /// Treasure signal range in tiles (scaled by helmet), or anywhere below
  /// this depth fraction.
  static const double treasureSignalRange = 22;
  static const double treasureSignalDepth = 0.72;

  /// Share of your spendable match coins dropped when you die.
  static const double deathCoinLoss = 0.2;
  static const int chestHardness = 3;

  // ---- blocks and traps ----
  static const int dirtHardness = 1;
  static const int crateHardness = 2;
  static const double spikeDamage = 28;
  static const double spikeCooldown = 0.9;

  static const double maxHealth = 100;
  static const double maxStamina = 100;
  static const double staminaPerHit = 4;
  static const double staminaRegen = 16;

  /// Per second while touching lava: deadly if you stay in (~1.3 s).
  static const double lavaDamage = 75;
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

  /// Lobby phase before digging starts: miners gather at the surface and
  /// the room fills up.
  static const double warmupSeconds = 7;

  /// Max bombs/dynamite a miner can carry of each kind.
  static const int maxItemStack = 5;

  /// Hidden volcanoes: break one and you're toast.
  static const double volcanoSplashDamage = 45;
  static const double volcanoSplashRadius = 2.2;

  /// Erupted lava hardens into rock after this long.
  static const double lavaCoolSeconds = 25;

  /// Treasure "sense" ranges in tiles (scaled up by better helmets).
  static const double hintFaint = 15;
  static const double hintWarm = 9;
  static const double hintHot = 4.5;

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
