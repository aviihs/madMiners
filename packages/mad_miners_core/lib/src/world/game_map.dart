import 'tile.dart';

class TilePos {
  const TilePos(this.x, this.y);
  final int x;
  final int y;

  double get cx => x + 0.5;
  double get cy => y + 0.5;

  @override
  bool operator ==(Object other) => other is TilePos && other.x == x && other.y == y;

  @override
  int get hashCode => x * 73856093 ^ y * 19349663;

  @override
  String toString() => '($x,$y)';
}

/// Mutable tile grid with per-tile hit points.
class GameMap {
  GameMap(this.width, this.height, {required this.spawn})
    : _tiles = List.filled(width * height, TileType.rock),
      _hp = List.filled(width * height, TileType.rock.maxHp);

  final int width;
  final int height;

  /// Where miners appear (centre of the surface camp).
  final TilePos spawn;
  final List<TileType> _tiles;
  final List<int> _hp;

  static const _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;
  int indexOf(int x, int y) => y * width + x;

  TileType tileAt(int x, int y) => inBounds(x, y) ? _tiles[y * width + x] : TileType.bedrock;
  TileType tileAtIndex(int i) => _tiles[i];
  int hpAt(int x, int y) => inBounds(x, y) ? _hp[y * width + x] : 0;
  int hpAtIndex(int i) => _hp[i];

  bool isSolid(int x, int y) => tileAt(x, y).isSolid;

  void setTile(int x, int y, TileType t) {
    if (!inBounds(x, y)) return;
    final i = y * width + x;
    _tiles[i] = t;
    _hp[i] = t.maxHp;
  }

  /// Applies a server-authoritative tile state (client side).
  void applyTile(int index, TileType t, int hp) {
    if (index < 0 || index >= _tiles.length) return;
    _tiles[index] = t;
    _hp[index] = hp;
  }

  /// Deals [amount] damage. Returns the tile that was broken, or null.
  TileType? damage(int x, int y, int amount) {
    if (!inBounds(x, y)) return null;
    final i = y * width + x;
    final t = _tiles[i];
    if (!t.isMinable) return null;
    _hp[i] -= amount;
    if (_hp[i] > 0) return null;
    _tiles[i] = TileType.empty;
    _hp[i] = 0;
    return t;
  }

  /// Leaves a deposit at 1 hp (used when a backpack is full).
  void clampHp(int x, int y, int minHp) {
    if (!inBounds(x, y)) return;
    final i = y * width + x;
    if (_hp[i] < minHp) _hp[i] = minHp;
  }

  Iterable<TilePos> get depotTiles sync* {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_tiles[y * width + x] == TileType.depot) yield TilePos(x, y);
      }
    }
  }

  // ---- serialisation -----------------------------------------------------

  /// What clients may see at [i]: volcanoes always, and the treasure until
  /// revealed, look like hard rock.
  TileType publicTypeAt(int i, {required bool hideTreasure}) => switch (_tiles[i]) {
    TileType.volcano => TileType.hardRock,
    TileType.treasure when hideTreasure => TileType.hardRock,
    final t => t,
  };

  int publicHpAt(int i, {required bool hideTreasure}) {
    final t = publicTypeAt(i, hideTreasure: hideTreasure);
    return t == _tiles[i] ? _hp[i] : (_hp[i] < t.maxHp ? _hp[i] : t.maxHp);
  }

  String encodeTiles({bool hideTreasure = false}) => String.fromCharCodes([
    for (var i = 0; i < _tiles.length; i++) _alphabet.codeUnitAt(publicTypeAt(i, hideTreasure: hideTreasure).index),
  ]);

  /// Tiles whose hp is below their maximum, as `[index, hp]` pairs.
  List<List<int>> damagedTiles({bool hideTreasure = false}) {
    final out = <List<int>>[];
    for (var i = 0; i < _tiles.length; i++) {
      final t = publicTypeAt(i, hideTreasure: hideTreasure);
      final hp = publicHpAt(i, hideTreasure: hideTreasure);
      if (t.isMinable && hp < t.maxHp) out.add([i, hp]);
    }
    return out;
  }

  /// Set [hideTreasure] for anything sent to clients.
  Map<String, dynamic> toJson({bool hideTreasure = false}) => {
    'w': width,
    'h': height,
    'sx': spawn.x,
    'sy': spawn.y,
    't': encodeTiles(hideTreasure: hideTreasure),
    'd': damagedTiles(hideTreasure: hideTreasure),
  };

  TilePos? get treasure {
    final i = _tiles.indexOf(TileType.treasure);
    return i < 0 ? null : TilePos(i % width, i ~/ width);
  }

  factory GameMap.fromJson(Map<String, dynamic> j) {
    final map = GameMap(
      j['w'] as int,
      j['h'] as int,
      spawn: TilePos(j['sx'] as int, j['sy'] as int),
    );
    final encoded = j['t'] as String;
    for (var i = 0; i < encoded.length && i < map._tiles.length; i++) {
      final t = TileType.values[_alphabet.indexOf(encoded[i])];
      map._tiles[i] = t;
      map._hp[i] = t.maxHp;
    }
    for (final d in (j['d'] as List? ?? const [])) {
      final pair = (d as List).cast<int>();
      map._hp[pair[0]] = pair[1];
    }
    return map;
  }

  GameMap clone() => GameMap.fromJson(toJson());
}
