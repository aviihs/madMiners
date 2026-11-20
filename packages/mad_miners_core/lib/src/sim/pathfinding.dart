import '../world/game_map.dart';
import '../world/tile.dart';

/// Dijkstra over the 4-connected tile grid where rock is "walkable" at the
/// cost of digging through it. Used by bots.
class DigPathfinder {
  DigPathfinder(this.map);

  final GameMap map;

  late final List<double> cost = List.filled(map.width * map.height, double.infinity);
  late final List<int> parent = List.filled(map.width * map.height, -1);

  /// Cost of entering a tile, given the bot's pickaxe [damage].
  double enterCost(TileType t, int hp, int damage) => switch (t) {
    TileType.bedrock => double.infinity,
    TileType.lava => double.infinity,
    TileType.gas => 25,
    TileType.empty || TileType.depot => 1,
    // Digging under a boulder is asking for a headache.
    TileType.boulder => 2 + (hp / damage).ceil() * 0.9,
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

  /// Fills [cost]/[parent] from [start], exploring at most [budget] nodes.
  void run(TilePos start, int damage, {int budget = 4000}) {
    cost.fillRange(0, cost.length, double.infinity);
    parent.fillRange(0, parent.length, -1);
    final s = map.indexOf(start.x, start.y);
    cost[s] = 0;
    final heap = _MinHeap()..push(s, 0);
    var visited = 0;
    while (heap.isNotEmpty && visited++ < budget) {
      final (node, d) = heap.pop();
      if (d > cost[node]) continue;
      final x = node % map.width, y = node ~/ map.width;
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        if (!map.inBounds(nx, ny)) continue;
        final ni = map.indexOf(nx, ny);
        final c = enterCost(map.tileAtIndex(ni), map.hpAtIndex(ni), damage) + moveCost(y, nx, ny);
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

  (int, double) pop() {
    final top = (_nodes[0], _keys[0]);
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
