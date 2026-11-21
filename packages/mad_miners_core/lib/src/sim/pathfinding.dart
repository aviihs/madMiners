import 'dart:typed_data';

import '../world/game_map.dart';
import '../world/tile.dart';

/// Dijkstra over the 4-connected tile grid where rock is "walkable" at the
/// cost of digging through it. Used by bots.
///
/// Runs often (every bot replans every second or two), so it avoids
/// allocating per node: typed arrays, a per-tile-type cost table, and one
/// reusable instance per map.
class DigPathfinder {
  DigPathfinder(this.map)
    : cost = Float64List(map.width * map.height),
      parent = Int32List(map.width * map.height);

  /// The shared pathfinder for [map] (bots plan one at a time).
  factory DigPathfinder.forMap(GameMap map) => _shared[map] ??= DigPathfinder(map);
  static final _shared = Expando<DigPathfinder>();

  final GameMap map;
  final Float64List cost;
  final Int32List parent;

  // Per tile type: how entering it is priced.
  static const _blocked = 0, _fixed = 1, _dig = 2, _digBoulder = 3;
  static final List<int> _kind = [for (final t in TileType.values) _kindOf(t)];
  static final Float64List _fixedCost = Float64List.fromList([for (final t in TileType.values) _fixedOf(t)]);

  static int _kindOf(TileType t) => switch (t) {
    TileType.bedrock || TileType.lava || TileType.ancientDoor => _blocked,
    _ when t.isLauncher => _blocked,
    TileType.gas || TileType.spikes || TileType.water || TileType.plate || TileType.empty || TileType.depot => _fixed,
    _ when t.tnt != null => _fixed,
    TileType.boulder => _digBoulder,
    _ => _dig,
  };

  static double _fixedOf(TileType t) => switch (t) {
    TileType.gas => 25,
    TileType.spikes => 18,
    TileType.water => 3,
    TileType.plate => 15,
    _ when t.tnt != null => 40,
    _ => 1,
  };

  /// Cost of entering a tile, given the bot's pickaxe [damage].
  double enterCost(TileType t, int hp, int damage) => switch (_kind[t.index]) {
    _blocked => double.infinity,
    _fixed => _fixedCost[t.index],
    // Digging under a boulder is asking for a headache.
    _digBoulder => 2 + (hp / damage).ceil() * 0.9,
    _ => 1 + (hp / damage).ceil() * 0.9,
  };

  /// Gravity: going up is slow (dig, jump, climb); never stand over lava;
  /// don't dig right under a boulder.
  double moveCost(int fromY, int nx, int ny) {
    var c = 0.0;
    if (ny < fromY) c += 4;
    final below = map.tileAt(nx, ny + 1);
    if (below == TileType.lava) return double.infinity;
    if (map.tileAt(nx, ny - 1) == TileType.boulder) c += 6;
    return c;
  }

  static const _dx = [1, -1, 0, 0];
  static const _dy = [0, 0, 1, -1];

  /// Fills [cost]/[parent] from [start], exploring at most [budget] nodes.
  void run(TilePos start, int damage, {int budget = 4000}) {
    cost.fillRange(0, cost.length, double.infinity);
    parent.fillRange(0, parent.length, -1);
    final w = map.width;
    final s = map.indexOf(start.x, start.y);
    cost[s] = 0;
    final heap = _heap..clear();
    heap.push(s, 0);
    var visited = 0;
    while (heap.isNotEmpty && visited++ < budget) {
      final node = heap.pop();
      final d = heap.poppedKey;
      if (d > cost[node]) continue;
      final x = node % w, y = node ~/ w;
      for (var k = 0; k < 4; k++) {
        final nx = x + _dx[k], ny = y + _dy[k];
        if (!map.inBounds(nx, ny)) continue;
        final ni = ny * w + nx;
        final enter = enterCost(map.tileAtIndex(ni), map.hpAtIndex(ni), damage);
        if (enter == double.infinity) continue;
        final c = enter + moveCost(y, nx, ny);
        if (c == double.infinity) continue;
        final nd = d + c;
        if (nd < cost[ni]) {
          cost[ni] = nd;
          parent[ni] = node;
          heap.push(ni, nd);
        }
      }
    }
  }

  final _heap = _MinHeap();

  /// Path from the last [run] start to [goal], excluding the start tile.
  List<TilePos> pathTo(TilePos goal) {
    final out = <TilePos>[];
    var i = map.indexOf(goal.x, goal.y);
    if (cost[i] == double.infinity) return out;
    while (parent[i] != -1) {
      out.add(TilePos(i % map.width, i ~/ map.width));
      i = parent[i];
    }
    return out.reversed.toList();
  }
}

class _MinHeap {
  final List<int> _nodes = [];
  final List<double> _keys = [];

  bool get isNotEmpty => _nodes.isNotEmpty;

  void push(int node, double key) {
    _nodes.add(node);
    _keys.add(key);
    var i = _nodes.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_keys[p] <= _keys[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  void clear() {
    _nodes.clear();
    _keys.clear();
  }

  /// Key of the node returned by the last [pop].
  double poppedKey = 0;

  int pop() {
    final top = _nodes[0];
    poppedKey = _keys[0];
    final lastN = _nodes.removeLast();
    final lastK = _keys.removeLast();
    if (_nodes.isNotEmpty) {
      _nodes[0] = lastN;
      _keys[0] = lastK;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _nodes.length && _keys[l] < _keys[m]) m = l;
        if (r < _nodes.length && _keys[r] < _keys[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final n = _nodes[a];
    _nodes[a] = _nodes[b];
    _nodes[b] = n;
    final k = _keys[a];
    _keys[a] = _keys[b];
    _keys[b] = k;
  }
}
