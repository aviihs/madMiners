import '../config/balance.dart';

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// What a client asks its miner to do this tick. Untrusted: the server clamps it.
class PlayerInput {
  const PlayerInput({this.seq = 0, this.dx = 0, this.dy = 0, this.fx = 0, this.fy = 1, this.mine = false});

  static const idle = PlayerInput();

  final int seq;
  final double dx;
  final double dy;
  final double fx;
  final double fy;
  final bool mine;

  PlayerInput sanitized() {
    double c(double v) => v.isFinite ? v.clamp(-1.0, 1.0) : 0.0;
    return PlayerInput(seq: seq, dx: c(dx), dy: c(dy), fx: c(fx), fy: c(fy), mine: mine);
  }

  Map<String, dynamic> toJson() => {
    's': seq,
    'dx': _r2(dx),
    'dy': _r2(dy),
    'fx': _r2(fx),
    'fy': _r2(fy),
    'm': mine,
  };

  factory PlayerInput.fromJson(Map<String, dynamic> j) => PlayerInput(
    seq: (j['s'] as num?)?.toInt() ?? 0,
    dx: (j['dx'] as num?)?.toDouble() ?? 0,
    dy: (j['dy'] as num?)?.toDouble() ?? 0,
    fx: (j['fx'] as num?)?.toDouble() ?? 0,
    fy: (j['fy'] as num?)?.toDouble() ?? 1,
    mine: j['m'] == true,
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

enum GameEventKind { oreMined, treasureFound, treasureRevealed, died, respawned, upgraded, joined, left, botJoined, botLeft, chat }

class GameEvent {
  const GameEvent(this.kind, {this.playerId, this.value = 0, this.text});

  final GameEventKind kind;
  final String? playerId;

  /// Ore index, coins, upgrade kind… depends on [kind].
  final int value;
  final String? text;

  Map<String, dynamic> toJson() => {
    'k': kind.index,
    'p': ?playerId,
    if (value != 0) 'v': value,
    't': ?text,
  };

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
    GameEventKind.values[(j['k'] as num).toInt()],
    playerId: j['p'] as String?,
    value: (j['v'] as num?)?.toInt() ?? 0,
    text: j['t'] as String?,
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
  });

  final int tick;
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
  };

  factory WorldSnapshot.fromJson(Map<String, dynamic> j) => WorldSnapshot(
    tick: (j['tk'] as num).toInt(),
    timeLeft: (j['tl'] as num).toDouble(),
    players: (j['p'] as List).map((e) => PlayerSnapshot.fromJson(e as Map<String, dynamic>)).toList(),
    tiles: (j['ti'] as List? ?? const []).map((e) => TileChange.fromJson(e as List)).toList(),
    events: (j['ev'] as List? ?? const []).map((e) => GameEvent.fromJson(e as Map<String, dynamic>)).toList(),
    teamScores: (j['ts'] as List? ?? const []).cast<num>().map((e) => e.toInt()).toList(),
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
  });

  final String playerId;
  final String name;
  final bool isBot;
  final int team;
  final int rank;
  final int score;
  final int oresMined;
  final int xp;

  Map<String, dynamic> toJson() => {
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
