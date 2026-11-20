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
  mystery;

  bool get isSolid => switch (this) {
    empty || lava || gas || depot || spikes => false,
    _ => true,
  };

  bool get isMinable => isSolid && this != bedrock;

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
    _ => ore != null ? oreDefs[ore]!.hardness : 0,
  };

  bool get isHazard => this == lava || this == gas || this == spikes;

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
