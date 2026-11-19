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
  volcano;

  bool get isSolid => switch (this) {
    empty || lava || gas || depot => false,
    _ => true,
  };

  bool get isMinable => isSolid && this != bedrock;

  OreType? get ore => switch (this) {
    copper => OreType.copper,
    iron => OreType.iron,
    gold => OreType.gold,
    diamond => OreType.diamond,
    moneyBag => OreType.moneyBag,
    _ => null,
  };

  int get maxHp => switch (this) {
    rock => Balance.rockHardness,
    hardRock => Balance.hardRockHardness,
    treasure => Balance.treasureHardness,
    volcano => Balance.hardRockHardness,
    _ => ore != null ? oreDefs[ore]!.hardness : 0,
  };

  bool get isHazard => this == lava || this == gas;

  static TileType forOre(OreType o) => switch (o) {
    OreType.copper => copper,
    OreType.iron => iron,
    OreType.gold => gold,
    OreType.diamond => diamond,
    OreType.moneyBag => moneyBag,
  };
}
