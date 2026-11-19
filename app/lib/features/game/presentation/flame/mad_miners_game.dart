import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../controller/game_controller.dart';
import 'components/effects_components.dart';
import 'components/miners_component.dart';
import 'components/tile_map_component.dart';

/// Flame view of the match. Pure rendering — all game state comes from the
/// [GameController], which in turn comes from the authoritative simulation.
class MadMinersGame extends FlameGame {
  MadMinersGame(this.controller);

  final GameController controller;
  static const double tileSize = 32;

  /// Roughly how many tiles fit across the shorter screen edge.
  static const double tilesAcross = 15;

  @override
  Color backgroundColor() => const Color(0xFF0B0908);

  @override
  Future<void> onLoad() async {
    world.addAll([
      TileMapComponent(controller),
      MinersComponent(controller),
      DarknessComponent(controller),
    ]);
    camera.viewfinder.anchor = Anchor.center;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewfinder.zoom = (min(size.x, size.y) / (tilesAcross * tileSize)).clamp(0.6, 3.0);
  }

  @override
  void update(double dt) {
    final step = min(dt, 0.1); // avoid tunnelling after a hitch
    controller.update(step);
    final me = controller.me;
    if (me != null) {
      final target = Vector2(me.rx * tileSize, me.ry * tileSize);
      final pos = camera.viewfinder.position;
      camera.viewfinder.position = pos + (target - pos) * min(1, step * 10);
    }
    for (final fx in controller.drainFx()) {
      world.add(FloatingText(fx));
    }
    super.update(step);
  }
}
