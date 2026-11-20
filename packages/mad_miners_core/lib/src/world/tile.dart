import '../config/balance.dart';

/// Every cell of the mine grid. The index is the wire encoding, so only
/// append new values at the end.
enum TileType {
  empty,
  rock,
  hardRock,
  bedrock,
  copper,
  iron,
  gold,
  diamond,
  moneyBag,
  lava,
  gas,
  depot,
  treasure,

  /// Looks like hard rock. Break it and it erupts.
  volcano,

  /// Heavy loose rock. Falls when the tile below is dug out and crushes
  /// whoever is underneath.
  boulder,

  /// Soft topsoil: one hit.
  dirt,

  /// Floor trap: rusty spikes in an open tile. Hurts on touch.
  spikes,

  /// Explosive crate: blows up shortly after it's broken or caught in a blast.
  explosive,
  coal,
  silver,
  emerald,
  ruby,

  /// Volcanic glass: very slow to dig, no loot.
  obsidian,

  /// Glowing Mystery Bomb. Its rarity stays secret until it's opened.
  mystery,

  /// Water: slows you down, flows downhill, turns lava into obsidian.
  water,

  /// Pressure plate on a floor: springs a trap when stepped on.
  plate,

  /// Treasure chest: break it for coins.
  chest,

  /// Sealed door of the treasure chamber. Opens when a miner comes close.
  ancientDoor,

  // TNT variants (the plain one is [explosive]).
  tntPowerful,
  tntMining,
  tntChain,
  tntTreasure,
  tntUnstable,

  // Launcher pads: step on one and it throws you.
  launcherUp,
  launcherLeft,
  launcherRight,
  launcherUpLeft,
  launcherUpRight,
  launcherHeavy,
  launcherRandom;

  /// TNT kind of this tile, if it is TNT.
  TntKind? get tnt => switch (this) {
    explosive => TntKind.basic,
    tntPowerful => TntKind.powerful,
    tntMining => TntKind.mining,
    tntChain => TntKind.chain,
    tntTreasure => TntKind.treasure,
    tntUnstable => TntKind.unstable,
    _ => null,
  };

  bool get isLauncher => index >= launcherUp.index && index <= launcherRandom.index;

  /// Devices that sit on a cave floor (you walk over them).
  bool get isFloorDevice => this == spikes || this == plate || isLauncher;

  bool get isFluid => this == lava || this == water;

  LaunchKind? get launch => switch (this) {
    launcherUp => LaunchKind.up,
    launcherLeft => LaunchKind.left,
    launcherRight => LaunchKind.right,
    launcherUpLeft => LaunchKind.upLeft,
    launcherUpRight => LaunchKind.upRight,
    launcherHeavy => LaunchKind.heavy,
    launcherRandom => LaunchKind.random,
    _ => null,
  };

  static TileType forTnt(TntKind k) => switch (k) {
    TntKind.basic => explosive,
    TntKind.powerful => tntPowerful,
    TntKind.mining => tntMining,
    TntKind.chain => tntChain,
    TntKind.treasure => tntTreasure,
    TntKind.unstable => tntUnstable,
  };

  bool get isSolid => switch (this) {
    empty || lava || gas || depot || spikes || water || plate => false,
    _ when isLauncher => false,
    _ => true,
  };

  bool get isMinable => isSolid && this != bedrock && this != ancientDoor;

  OreType? get ore => switch (this) {
    copper => OreType.copper,
    iron => OreType.iron,
    gold => OreType.gold,
    diamond => OreType.diamond,
    moneyBag => OreType.moneyBag,
    coal => OreType.coal,
    silver => OreType.silver,
    emerald => OreType.emerald,
    ruby => OreType.ruby,
    _ => null,
  };

  int get maxHp => switch (this) {
    rock => Balance.rockHardness,
    hardRock => Balance.hardRockHardness,
    treasure => Balance.treasureHardness,
    volcano => Balance.hardRockHardness,
    boulder => Balance.boulderHardness,
    dirt => Balance.dirtHardness,
    explosive => Balance.crateHardness,
    obsidian => Balance.obsidianHardness,
    mystery => Balance.mysteryHardness,
    chest => Balance.chestHardness,
    _ when tnt != null => Balance.crateHardness,
    _ => ore != null ? oreDefs[ore]!.hardness : 0,
  };

  bool get isHazard => this == lava || this == gas || isFloorDevice;

  static TileType forOre(OreType o) => switch (o) {
    OreType.copper => copper,
    OreType.iron => iron,
    OreType.gold => gold,
    OreType.diamond => diamond,
    OreType.moneyBag => moneyBag,
    OreType.coal => coal,
    OreType.silver => silver,
    OreType.emerald => emerald,
    OreType.ruby => ruby,
  };
}
