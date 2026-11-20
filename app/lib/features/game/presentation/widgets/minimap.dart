import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

import '../controller/game_controller.dart';
import '../flame/palette.dart';

/// Fog-of-war mini-map: only tiles you've lit up are drawn. Shows you, other
/// miners, monsters you can see, Mystery Bombs you've found, the lava and an
/// arrow back to the surface shop.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, required this.controller, this.width = 132, this.height = 150});
  final GameController controller;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xCC0C0A09),
        border: Border.all(color: const Color(0x33FFFFFF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: controller.minimapTick,
        builder: (context, _, _) => CustomPaint(painter: _MiniMapPainter(controller)),
      ),
    ),
  );
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.c);
  final GameController c;

  @override
  void paint(Canvas canvas, Size size) {
    final map = c.map, me = c.me;
    if (map == null || me == null || c.explored.length != map.width * map.height) return;
    final cell = size.width / map.width;
    final rows = (size.height / cell).floor();
    final top = (c.predY - rows / 2).clamp(0.0, max(0.0, map.height - rows.toDouble())).floor();
    final p = Paint();
    final lavaTop = map.height - 1 - c.settings.mapId.def.lavaRows;

    for (var y = top; y < min(map.height, top + rows + 1); y++) {
      final d = ((y - MapGenerator.surfaceRows) / max(1, lavaTop - MapGenerator.surfaceRows)).clamp(0.0, 1.0);
      for (var x = 0; x < map.width; x++) {
        final i = map.indexOf(x, y);
        if (!c.explored[i]) continue;
        final t = map.tileAtIndex(i);
        p.color = switch (t) {
          TileType.empty || TileType.spikes => y < MapGenerator.surfaceRows ? const Color(0xFF3B4A6B) : MinePalette.tinted(const Color(0xFF4A3B30), d),
          TileType.lava => const Color(0xFFFF6A2A),
          TileType.gas => const Color(0xFF6FBF4A),
          TileType.depot => const Color(0xFF3DDC97),
          TileType.mystery => const Color(0xFFD08BFF),
          TileType.bedrock => const Color(0xFF050404),
          _ when t.ore != null => MinePalette.ore[t] ?? const Color(0xFF8A7F77),
          _ => MinePalette.tinted(const Color(0xFF7A6E66), d),
        };
        canvas.drawRect(Rect.fromLTWH(x * cell, (y - top) * cell, cell + 0.2, cell + 0.2), p);
      }
    }

    Offset at(double x, double y) => Offset(x * cell, (y - top) * cell);
    bool visible(double y) => y >= top && y <= top + rows;

    // Monsters you can actually see (in your light).
    final vision = me.snap.vision * 1.1;
    p.color = const Color(0xFFFF4D6A);
    for (final m in c.monsters) {
      if (!visible(m.y) || pow(m.x - c.predX, 2) + pow(m.y - c.predY, 2) > vision * vision) continue;
      canvas.drawCircle(at(m.x, m.y), 2.4, p);
    }
    for (final o in c.mysteries) {
      if (visible(o.y)) {
        p.color = const Color(0xFFE0B3FF);
        canvas.drawCircle(at(o.x, o.y), 3, p);
      }
    }
    for (final m in c.miners.values) {
      if (!m.snap.alive || m.snap.id == c.youId || !visible(m.ry)) continue;
      p.color = m.snap.isBot ? const Color(0xFF8FC8FF) : const Color(0xFFFFFFFF);
      canvas.drawCircle(at(m.rx, m.ry), 2, p);
    }
    // You: gold dot with a facing tick.
    final you = at(c.predX, c.predY);
    p.color = const Color(0xFFFFC233);
    canvas.drawCircle(you, 3.4, p);
    p
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(you, 3.4, p);
    p.style = PaintingStyle.fill;

    // Way back up: arrow to the shop when it's off the top of the map.
    if (top > MapGenerator.surfaceRows && c.depotXs.isNotEmpty) {
      final sx = (c.depotXs.first + c.depotXs.last + 1) / 2 * cell;
      p.color = const Color(0xFF3DDC97);
      canvas.drawPath(Path()..moveTo(sx, 3)..lineTo(sx - 5, 10)..lineTo(sx + 5, 10)..close(), p);
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => true;
}
