import 'package:flutter/cupertino.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

/// Small illustrated square for a mine.
class MapThumb extends StatelessWidget {
  const MapThumb(this.mapId, {super.key, this.size = 44});
  final MapId mapId;
  final double size;

  static List<Color> colorsFor(MapId m) => switch (m) {
    MapId.starterMine => const [Color(0xFFB98A5E), Color(0xFF5A3D27)],
    MapId.crystalCave => const [Color(0xFF6FD3FF), Color(0xFF2B3D6B)],
    MapId.lavaMine => const [Color(0xFFFF8A3D), Color(0xFF6B1A0C)],
  };

  static IconData iconFor(MapId m) => switch (m) {
    MapId.starterMine => CupertinoIcons.cube_box_fill,
    MapId.crystalCave => CupertinoIcons.sparkles,
    MapId.lavaMine => CupertinoIcons.flame_fill,
  };

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.26),
      gradient: LinearGradient(colors: colorsFor(mapId), begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Icon(iconFor(mapId), size: size * 0.5, color: const Color(0xEEFFFFFF)),
  );
}
