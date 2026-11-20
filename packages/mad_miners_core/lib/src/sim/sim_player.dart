import '../config/balance.dart';
import '../config/cosmetics.dart';
import '../model/snapshot.dart';

/// Authoritative, mutable miner state. Lives only inside [GameSimulation].
class SimPlayer {
  SimPlayer({
    required this.id,
    required this.name,
    required this.isBot,
    required this.team,
    required this.x,
    required this.y,
  });

  final String id;
  final String name;
  final bool isBot;
  final int team;

  double x;
  double y;
  double vx = 0;
  double vy = 0;
  bool onGround = false;
  double fx = 0;
  double fy = 1;
  PlayerInput input = PlayerInput.idle;

  double hp = Balance.maxHealth;
  double stamina = Balance.maxStamina;

  final List<int> upgrades = List.filled(UpgradeKind.values.length, 0);
  final List<int> items = List.filled(ItemKind.values.length, 0);
  Look look = Look.standard;

  int coins = 0;
  int score = 0;
  int xp = 0;
  int oresMined = 0;
  int maxDepth = 0;

  /// Deepest point this match (survives respawns).
  int bestDepth = 0;

  double mineCooldown = 0;
  double respawnIn = 0;
  double miningFlash = 0;

  /// Brief immunity after a boulder hit, so one rock doesn't hit twice.
  double crushCooldown = 0;
  bool connected = true;
  bool inDepot = false;

  bool get alive => respawnIn <= 0;
  UpgradeLevel gear(UpgradeKind k) => k.levels[upgrades[k.index]];
  double get vision => gear(UpgradeKind.helmet).stat;
  double get boots => gear(UpgradeKind.boots).stat;
  double get armor => gear(UpgradeKind.armor).stat;

  /// With [disguise], bots look exactly like human players on the wire.
  PlayerSnapshot snapshot({bool disguise = false}) => PlayerSnapshot(
    id: id,
    name: name,
    isBot: isBot && !disguise,
    team: team,
    x: x,
    y: y,
    fx: fx,
    fy: fy,
    hp: hp,
    stamina: stamina,
    alive: alive,
    mining: miningFlash > 0,
    connected: connected,
    score: score,
    coins: coins,
    maxDepth: maxDepth,
    upgrades: List.of(upgrades),
    respawnIn: respawnIn,
    inDepot: inDepot,
    items: List.of(items),
    look: look,
    vx: vx,
    vy: vy,
  );
}
