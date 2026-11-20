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
      _hp = List.filled(width * height, TileType.rock.maxHp),
      _disguise = List.filled(width * height, null);

  final int width;
  final int height;

  /// Where miners appear (centre of the surface camp).
  final TilePos spawn;
  final List<TileType> _tiles;
  final List<int> _hp;

  /// Hidden tiles: what clients see instead (null = not hidden).
  final List<TileType?> _disguise;

  bool isHidden(int i) => _disguise[i] != null;
  TileType? disguiseAt(int i) => _disguise[i];

  /// Hide tile [i] from clients; they see [as] until it's revealed.
  void hide(int i, TileType as) => _disguise[i] = as;

  /// Returns true if it was hidden.
  bool reveal(int i) {
    if (_disguise[i] == null) return false;
    _disguise[i] = null;
    return true;
  }

  /// One char per tile type (62 possible). Old types keep their old char.
  static const _alphabet = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

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
    _disguise[i] = null; // anything placed or changed is out in the open
  }

  /// Tile (x, y) just opened up: hidden neighbours that looked like rock
  /// come into view. A hidden open pocket (lava, water, a sealed room) is
  /// revealed all at once. Floor traps disguised as empty space stay hidden.
  /// Returns the newly revealed indices.
  List<int> exposeAround(int x, int y) {
    final out = <int>[];
    final queue = <int>[];
    void consider(int nx, int ny) {
      if (!inBounds(nx, ny)) return;
      final i = indexOf(nx, ny);
      final d = _disguise[i];
      if (d == null || !d.isSolid) return;
      _disguise[i] = null;
      out.add(i);
      if (!_tiles[i].isSolid) queue.add(i);
    }

    void around(int cx, int cy) {
      consider(cx + 1, cy);
      consider(cx - 1, cy);
      consider(cx, cy + 1);
      consider(cx, cy - 1);
    }

    around(x, y);
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      around(i % width, i ~/ width);
    }
    return out;
  }

  /// Hidden floor traps within [r] tiles of (x, y) — what a miner notices
  /// by walking past. Returns the newly revealed indices.
  List<int> revealNear(double x, double y, double r) {
    final out = <int>[];
    for (var ty = (y - r).floor(); ty <= (y + r).floor(); ty++) {
      for (var tx = (x - r).floor(); tx <= (x + r).floor(); tx++) {
        if (!inBounds(tx, ty)) continue;
        final i = indexOf(tx, ty);
        final d = _disguise[i];
        if (d == null || d.isSolid) continue;
        final dx = tx + 0.5 - x, dy = ty + 0.5 - y;
        if (dx * dx + dy * dy > r * r) continue;
        _disguise[i] = null;
        out.add(i);
      }
    }
    return out;
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
    _disguise[i] = null;
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
    _ when _disguise[i] != null => _disguise[i]!,
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
