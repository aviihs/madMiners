import '../config/balance.dart';

enum GameMode {
  treasureHunt('Treasure Hunt', 'Dig down. First miner to break the hidden treasure wins.'),
  teamHunt('Team Hunt', 'Two crews race for the treasure. The finder\'s crew wins.');

  const GameMode(this.label, this.description);
  final String label;
  final String description;

  static GameMode parse(String? v) =>
      GameMode.values.firstWhere((m) => m.name == v, orElse: () => GameMode.treasureHunt);
}

class MapDef {
  const MapDef({
    required this.id,
    required this.name,
    required this.description,
    required this.height,
    required this.lavaRows,
    required this.lavaPockets,
    required this.gasPockets,
    required this.lootBoost,
    required this.volcanoes,
    this.boulders = 0.006,
    this.mysteryBombs = 6,
    this.monsters = 4,
  });

  final MapId id;
  final String name;
  final String description;

  /// Total mine depth in tiles.
  final int height;

  /// Solid lava sea at the very bottom.
  final int lavaRows;

  /// Extra lava pockets in the deepest quarter.
  final int lavaPockets;
  final int gasPockets;
  final double lootBoost;

  /// Hidden volcano tiles in the deep half.
  final int volcanoes;

  /// Chance that a rock tile is a loose boulder.
  final double boulders;

  /// Mystery Bombs hidden in the rock at the start.
  final int mysteryBombs;

  /// Monsters lurking in caves at the start.
  final int monsters;
}

enum MapId {
  starterMine,
  crystalCave,
  lavaMine;

  MapDef get def => switch (this) {
    MapId.starterMine => const MapDef(
      id: MapId.starterMine,
      name: 'Starter Mine',
      description: 'Shallow and soft. A quick race to the treasure.',
      height: 60,
      lavaRows: 3,
      lavaPockets: 2,
      gasPockets: 2,
      lootBoost: 1.0,
      volcanoes: 8,
    ),
    MapId.crystalCave => const MapDef(
      id: MapId.crystalCave,
      name: 'Diamond Cave',
      description: 'Deeper, full of diamonds and money bags.',
      height: 80,
      lavaRows: 3,
      lavaPockets: 5,
      gasPockets: 5,
      lootBoost: 1.8,
      volcanoes: 16,
      boulders: 0.008,
      mysteryBombs: 9,
      monsters: 6,
    ),
    MapId.lavaMine => const MapDef(
      id: MapId.lavaMine,
      name: 'Lava Mine',
      description: 'The deepest mine. Lava pockets everywhere near the bottom.',
      height: 95,
      lavaRows: 4,
      lavaPockets: 12,
      gasPockets: 4,
      lootBoost: 1.4,
      volcanoes: 28,
      boulders: 0.01,
      mysteryBombs: 11,
      monsters: 8,
    ),
  };

  static MapId parse(String? v) =>
      MapId.values.firstWhere((m) => m.name == v, orElse: () => MapId.starterMine);
}

class MatchSettings {
  const MatchSettings({
    this.mapId = MapId.starterMine,
    this.mode = GameMode.treasureHunt,
    this.maxPlayers = Balance.maxPlayers,
    this.minPlayers = Balance.minPlayers,
    this.durationSeconds = Balance.defaultMatchSeconds,
    this.fillWithBots = true,
  }) : assert(minPlayers <= maxPlayers);

  final MapId mapId;
  final GameMode mode;

  /// Room capacity, 8–12.
  final int maxPlayers;

  /// Bots top the room up to this many miners.
  final int minPlayers;
  final int durationSeconds;
  final bool fillWithBots;

  MatchSettings copyWith({
    MapId? mapId,
    GameMode? mode,
    int? maxPlayers,
    int? minPlayers,
    int? durationSeconds,
    bool? fillWithBots,
  }) => MatchSettings(
    mapId: mapId ?? this.mapId,
    mode: mode ?? this.mode,
    maxPlayers: maxPlayers ?? this.maxPlayers,
    minPlayers: minPlayers ?? this.minPlayers,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    fillWithBots: fillWithBots ?? this.fillWithBots,
  );

  /// Clamps untrusted input (e.g. from an API request) into legal values.
  factory MatchSettings.sanitized({
    String? mapId,
    String? mode,
    int? maxPlayers,
    int? durationSeconds,
    bool fillWithBots = true,
  }) {
    final max = (maxPlayers ?? Balance.maxPlayers).clamp(Balance.minPlayers, Balance.maxPlayers);
    return MatchSettings(
      mapId: MapId.parse(mapId),
      mode: GameMode.parse(mode),
      maxPlayers: max,
      minPlayers: Balance.minPlayers.clamp(0, max),
      durationSeconds: (durationSeconds ?? Balance.defaultMatchSeconds).clamp(60, 1200),
      fillWithBots: fillWithBots,
    );
  }

  Map<String, dynamic> toJson() => {
    'mapId': mapId.name,
    'mode': mode.name,
    'maxPlayers': maxPlayers,
    'minPlayers': minPlayers,
    'durationSeconds': durationSeconds,
    'fillWithBots': fillWithBots,
  };

  factory MatchSettings.fromJson(Map<String, dynamic> j) => MatchSettings(
    mapId: MapId.parse(j['mapId'] as String?),
    mode: GameMode.parse(j['mode'] as String?),
    maxPlayers: (j['maxPlayers'] as num?)?.toInt() ?? Balance.maxPlayers,
    minPlayers: (j['minPlayers'] as num?)?.toInt() ?? Balance.minPlayers,
    durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? Balance.defaultMatchSeconds,
    fillWithBots: j['fillWithBots'] as bool? ?? true,
  );
}

/// How many bots a room needs for a given number of humans.
///
/// Bots fill the room up to [MatchSettings.minPlayers] but never push the room
/// past [MatchSettings.maxPlayers]. A human joining a bot-filled room replaces
/// a bot.
int botsNeeded(MatchSettings s, int humans) {
  if (!s.fillWithBots || humans <= 0) return 0;
  final want = s.minPlayers - humans;
  final room = s.maxPlayers - humans;
  if (want <= 0 || room <= 0) return 0;
  return want < room ? want : room;
}
