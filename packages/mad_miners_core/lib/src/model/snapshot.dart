import '../config/balance.dart';
import '../config/cosmetics.dart';

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// What a client asks its miner to do this tick. Untrusted: the server clamps it.
class PlayerInput {
  const PlayerInput({this.seq = 0, this.dx = 0, this.dy = 0, this.fx = 0, this.fy = 1, this.mine = false, this.jump = false, this.jet = false});

  static const idle = PlayerInput();

  final int seq;
  final double dx;
  final double dy;
  final double fx;
  final double fy;
  final bool mine;

  /// Jump (when standing on something).
  final bool jump;

  /// Fire the jetpack (while it has fuel).
  final bool jet;

  /// Holding up: climbs a 1-wide shaft by bracing against both walls.
  bool get up => dy < -0.5;

  PlayerInput sanitized() {
    double c(double v) => v.isFinite ? v.clamp(-1.0, 1.0) : 0.0;
    return PlayerInput(seq: seq, dx: c(dx), dy: c(dy), fx: c(fx), fy: c(fy), mine: mine, jump: jump, jet: jet);
  }

  Map<String, dynamic> toJson() => {
    's': seq,
    'dx': _r2(dx),
    'dy': _r2(dy),
    'fx': _r2(fx),
    'fy': _r2(fy),
    'm': mine,
    if (jump) 'j': true,
    if (jet) 'jt': true,
  };

  factory PlayerInput.fromJson(Map<String, dynamic> j) => PlayerInput(
    seq: (j['s'] as num?)?.toInt() ?? 0,
    dx: (j['dx'] as num?)?.toDouble() ?? 0,
    dy: (j['dy'] as num?)?.toDouble() ?? 0,
    fx: (j['fx'] as num?)?.toDouble() ?? 0,
    fy: (j['fy'] as num?)?.toDouble() ?? 1,
    mine: j['m'] == true,
    jump: j['j'] == true,
    jet: j['jt'] == true,
  ).sanitized();
}

class PlayerSnapshot {
  const PlayerSnapshot({
    required this.id,
    required this.name,
    required this.isBot,
    required this.team,
    required this.x,
    required this.y,
    required this.fx,
    required this.fy,
    required this.hp,
    required this.stamina,
    required this.alive,
    required this.mining,
    required this.connected,
    required this.score,
    required this.coins,
    required this.maxDepth,
    required this.upgrades,
    required this.respawnIn,
    required this.inDepot,
    this.items = const [0, 0],
    this.look = Look.standard,
    this.vx = 0,
    this.vy = 0,
    this.fuel = Balance.jetFuelMax,
    this.jetting = false,
    this.effects = 0,
  });

  final String id;
  final String name;
  final bool isBot;

  /// -1 when the mode has no teams.
  final int team;
  final double x;
  final double y;
  final double fx;
  final double fy;
  final double hp;
  final double stamina;
  final bool alive;
  final bool mining;
  final bool connected;

  /// Total coins earned this match (ranking).
  final int score;

  /// Spendable coins this match.
  final int coins;

  /// Deepest row reached this life (for the race standings).
  final int maxDepth;

  /// Levels indexed by [UpgradeKind.index].
  final List<int> upgrades;
  final double respawnIn;
  final bool inDepot;

  /// Carried consumables indexed by [ItemKind.index].
  final List<int> items;

  /// Equipped Locker items (the pickaxe also sets your starting dig power).
  final Look look;

  /// Velocity in tiles / second (used by client prediction and animation).
  final double vx;
  final double vy;

  /// Jetpack fuel (0..[Balance.jetFuelMax]) and whether it's firing now.
  final double fuel;
  final bool jetting;

  /// Status effects bitmask: [Effect.slimed], [Effect.cursed].
  final int effects;
  bool has(int effect) => effects & effect != 0;

  int itemCount(ItemKind k) => k.index < items.length ? items[k.index] : 0;

  int level(UpgradeKind k) => upgrades[k.index];
  UpgradeLevel gear(UpgradeKind k) => k.levels[level(k)];
  double get vision => gear(UpgradeKind.helmet).stat;

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    'b': isBot,
    'tm': team,
    'x': _r2(x),
    'y': _r2(y),
    'fx': _r2(fx),
    'fy': _r2(fy),
    'hp': hp.round(),
    'st': stamina.round(),
    'al': alive,
    'mn': mining,
    'cn': connected,
    'sc': score,
    'co': coins,
    'md': maxDepth,
    'up': upgrades,
    'rs': _r2(respawnIn),
    'dp': inDepot,
    'it': items,
    'lk': look.toJson(),
    'vx': _r2(vx),
    'vy': _r2(vy),
    'fu': fuel.round(),
    if (jetting) 'jt': true,
    if (effects != 0) 'ef': effects,
  };

  factory PlayerSnapshot.fromJson(Map<String, dynamic> j) => PlayerSnapshot(
    id: j['id'] as String,
    name: j['n'] as String,
    isBot: j['b'] as bool,
    team: (j['tm'] as num).toInt(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    fx: (j['fx'] as num).toDouble(),
    fy: (j['fy'] as num).toDouble(),
    hp: (j['hp'] as num).toDouble(),
    stamina: (j['st'] as num).toDouble(),
    alive: j['al'] as bool,
    mining: j['mn'] as bool,
    connected: j['cn'] as bool,
    score: (j['sc'] as num).toInt(),
    coins: (j['co'] as num).toInt(),
    maxDepth: (j['md'] as num).toInt(),
    upgrades: (j['up'] as List).cast<num>().map((e) => e.toInt()).toList(),
    respawnIn: (j['rs'] as num).toDouble(),
    inDepot: j['dp'] as bool,
    items: (j['it'] as List? ?? const [0, 0]).cast<num>().map((e) => e.toInt()).toList(),
    look: Look.fromJson(j['lk']),
    vx: (j['vx'] as num?)?.toDouble() ?? 0,
    vy: (j['vy'] as num?)?.toDouble() ?? 0,
    fuel: (j['fu'] as num?)?.toDouble() ?? Balance.jetFuelMax,
    jetting: j['jt'] == true,
    effects: (j['ef'] as num?)?.toInt() ?? 0,
  );
}

class TileChange {
  const TileChange(this.index, this.typeIndex, this.hp);
  final int index;
  final int typeIndex;
  final int hp;

  List<int> toJson() => [index, typeIndex, hp];
  factory TileChange.fromJson(List<dynamic> l) =>
      TileChange((l[0] as num).toInt(), (l[1] as num).toInt(), (l[2] as num).toInt());
}

/// Append only: the index is the wire encoding.
enum GameEventKind {
  oreMined, treasureFound, treasureRevealed, died, respawned, upgraded, joined, left, botJoined, botLeft, chat, explosion, volcano, itemBought,
  /// A Mystery Bomb was cracked open (x,y); rarity still unknown.
  mysteryFound,
  /// Burst open: value = rarity.index * 100 + reward.index, text = what you got.
  mysteryOpened,
  /// value = MonsterKind index, playerId = who landed the last hit.
  monsterKilled,
  /// value = WorldEventKind index.
  worldEvent,
  worldEventEnded,
}

class GameEvent {
  const GameEvent(this.kind, {this.playerId, this.value = 0, this.text, this.x, this.y});

  final GameEventKind kind;
  final String? playerId;

  /// Ore index, coins, upgrade kind… depends on [kind].
  final int value;
  final String? text;

  /// World position for explosions / eruptions.
  final double? x;
  final double? y;

  Map<String, dynamic> toJson() => {
    'k': kind.index,
    'p': ?playerId,
    if (value != 0) 'v': value,
    't': ?text,
    if (x != null) 'x': _r2(x!),
    if (y != null) 'y': _r2(y!),
  };

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
    GameEventKind.values[(j['k'] as num).toInt()],
    playerId: j['p'] as String?,
    value: (j['v'] as num?)?.toInt() ?? 0,
    text: j['t'] as String?,
    x: (j['x'] as num?)?.toDouble(),
    y: (j['y'] as num?)?.toDouble(),
  );
}

class WorldSnapshot {
  const WorldSnapshot({
    required this.tick,
    required this.timeLeft,
    required this.players,
    required this.tiles,
    required this.events,
    required this.teamScores,
    this.warmup = 0,
    this.bombs = const [],
    this.monsters = const [],
    this.mysteries = const [],
    this.worldEvent,
    this.worldEventLeft = 0,
  });

  final List<MonsterSnapshot> monsters;

  /// Mystery Bombs currently bursting open.
  final List<MysterySnapshot> mysteries;

  /// Active world event, if any, and its seconds left.
  final WorldEventKind? worldEvent;
  final double worldEventLeft;

  final int tick;

  /// Lit bombs on the ground.
  final List<BombSnapshot> bombs;

  /// Seconds until digging starts (0 once the match is live).
  final double warmup;
  final double timeLeft;
  final List<PlayerSnapshot> players;
  final List<TileChange> tiles;
  final List<GameEvent> events;
  final List<int> teamScores;

  Map<String, dynamic> toJson() => {
    'tk': tick,
    'tl': _r2(timeLeft),
    'p': players.map((p) => p.toJson()).toList(),
    if (tiles.isNotEmpty) 'ti': tiles.map((t) => t.toJson()).toList(),
    if (events.isNotEmpty) 'ev': events.map((e) => e.toJson()).toList(),
    if (teamScores.isNotEmpty) 'ts': teamScores,
    if (warmup > 0) 'wu': _r2(warmup),
    if (bombs.isNotEmpty) 'bm': bombs.map((b) => b.toJson()).toList(),
    if (monsters.isNotEmpty) 'mo': monsters.map((m) => m.toJson()).toList(),
    if (mysteries.isNotEmpty) 'my': mysteries.map((m) => m.toJson()).toList(),
    if (worldEvent != null) 'we': [worldEvent!.index, _r2(worldEventLeft)],
  };

  factory WorldSnapshot.fromJson(Map<String, dynamic> j) => WorldSnapshot(
    tick: (j['tk'] as num).toInt(),
    timeLeft: (j['tl'] as num).toDouble(),
    players: (j['p'] as List).map((e) => PlayerSnapshot.fromJson(e as Map<String, dynamic>)).toList(),
    tiles: (j['ti'] as List? ?? const []).map((e) => TileChange.fromJson(e as List)).toList(),
    events: (j['ev'] as List? ?? const []).map((e) => GameEvent.fromJson(e as Map<String, dynamic>)).toList(),
    teamScores: (j['ts'] as List? ?? const []).cast<num>().map((e) => e.toInt()).toList(),
    warmup: (j['wu'] as num?)?.toDouble() ?? 0,
    bombs: (j['bm'] as List? ?? const []).map((e) => BombSnapshot.fromJson(e as List)).toList(),
    monsters: (j['mo'] as List? ?? const []).map((e) => MonsterSnapshot.fromJson(e as List)).toList(),
    mysteries: (j['my'] as List? ?? const []).map((e) => MysterySnapshot.fromJson(e as List)).toList(),
    worldEvent: j['we'] == null ? null : WorldEventKind.values[((j['we'] as List)[0] as num).toInt()],
    worldEventLeft: j['we'] == null ? 0 : ((j['we'] as List)[1] as num).toDouble(),
  );
}

class PlayerResult {
  const PlayerResult({
    required this.playerId,
    required this.name,
    required this.isBot,
    required this.team,
    required this.rank,
    required this.score,
    required this.oresMined,
    required this.xp,
    this.maxDepth = 0,
    this.bonusGems = 0,
    this.monstersKilled = 0,
    this.mysteriesOpened = 0,
  });

  /// Gems won from Mystery Bombs this match (credited by the server).
  final int bonusGems;
  final int monstersKilled;
  final int mysteriesOpened;

  final String playerId;
  final String name;
  final bool isBot;
  final int team;
  final int rank;
  final int score;
  final int oresMined;
  final int xp;

  /// Deepest point reached during the match.
  final int maxDepth;

  Map<String, dynamic> toJson() => {
    'md': maxDepth,
    if (bonusGems > 0) 'bg': bonusGems,
    if (monstersKilled > 0) 'mk': monstersKilled,
    if (mysteriesOpened > 0) 'mb': mysteriesOpened,
    'id': playerId,
    'n': name,
    'b': isBot,
    'tm': team,
    'r': rank,
    'sc': score,
    'om': oresMined,
    'xp': xp,
  };

  factory PlayerResult.fromJson(Map<String, dynamic> j) => PlayerResult(
    playerId: j['id'] as String,
    name: j['n'] as String,
    isBot: j['b'] as bool,
    team: (j['tm'] as num).toInt(),
    rank: (j['r'] as num).toInt(),
    score: (j['sc'] as num).toInt(),
    oresMined: (j['om'] as num).toInt(),
    xp: (j['xp'] as num).toInt(),
    maxDepth: (j['md'] as num?)?.toInt() ?? 0,
    bonusGems: (j['bg'] as num?)?.toInt() ?? 0,
    monstersKilled: (j['mk'] as num?)?.toInt() ?? 0,
    mysteriesOpened: (j['mb'] as num?)?.toInt() ?? 0,
  );
}

class MatchResult {
  const MatchResult({required this.players, required this.teamScores, required this.winningTeam, this.winnerId});

  final List<PlayerResult> players;
  final List<int> teamScores;

  /// -1 for non-team modes or a draw.
  final int winningTeam;

  /// Who broke the treasure (null if time ran out).
  final String? winnerId;

  Map<String, dynamic> toJson() => {
    'p': players.map((e) => e.toJson()).toList(),
    'ts': teamScores,
    'wt': winningTeam,
    'w': ?winnerId,
  };

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
    players: (j['p'] as List).map((e) => PlayerResult.fromJson(e as Map<String, dynamic>)).toList(),
    teamScores: (j['ts'] as List? ?? const []).cast<num>().map((e) => e.toInt()).toList(),
    winningTeam: (j['wt'] as num?)?.toInt() ?? -1,
    winnerId: j['w'] as String?,
  );
}

class BombSnapshot {
  const BombSnapshot(this.x, this.y, this.kind, this.fuse);

  final double x;
  final double y;
  final ItemKind kind;
  final double fuse;

  List<Object> toJson() => [_r2(x), _r2(y), kind.index, _r2(fuse)];
  factory BombSnapshot.fromJson(List<dynamic> l) =>
      BombSnapshot((l[0] as num).toDouble(), (l[1] as num).toDouble(), ItemKind.values[(l[2] as num).toInt()], (l[3] as num).toDouble());
}

/// Status effect bits on [PlayerSnapshot.effects].
abstract final class Effect {
  /// Slime prank: slower running for a few seconds. Harmless.
  static const slimed = 1;

  /// Cursed treasure: slower digging for a while.
  static const cursed = 2;
}

class MonsterSnapshot {
  const MonsterSnapshot({required this.id, required this.kind, required this.x, required this.y, required this.hp, required this.left, required this.attacking});
  final int id;
  final MonsterKind kind;
  final double x;
  final double y;

  /// 0..1 of max health.
  final double hp;
  final bool left;
  final bool attacking;

  List<Object> toJson() => [id, kind.index, _r2(x), _r2(y), _r2(hp), left ? 1 : 0, attacking ? 1 : 0];
  factory MonsterSnapshot.fromJson(List<dynamic> l) => MonsterSnapshot(
    id: (l[0] as num).toInt(),
    kind: MonsterKind.values[(l[1] as num).toInt()],
    x: (l[2] as num).toDouble(),
    y: (l[3] as num).toDouble(),
    hp: (l[4] as num).toDouble(),
    left: l[5] == 1,
    attacking: l[6] == 1,
  );
}

/// A Mystery Bomb shaking before it bursts. [t] = seconds left.
class MysterySnapshot {
  const MysterySnapshot(this.x, this.y, this.t);
  final double x;
  final double y;
  final double t;
  List<Object> toJson() => [_r2(x), _r2(y), _r2(t)];
  factory MysterySnapshot.fromJson(List<dynamic> l) => MysterySnapshot((l[0] as num).toDouble(), (l[1] as num).toDouble(), (l[2] as num).toDouble());
}

/// Private "treasure sense" for one miner. Never broadcast to others.
class TreasureHint {
  const TreasureHint(this.level, this.side);
  static const none = TreasureHint(0, 0);

  /// 0 nothing, 1 faint, 2 warm, 3 hot.
  final int level;

  /// Rough horizontal direction at level 2: -1 left, 1 right, 0 straight down/up.
  final int side;

  @override
  bool operator ==(Object other) => other is TreasureHint && other.level == level && other.side == side;
  @override
  int get hashCode => level * 3 + side;
}
