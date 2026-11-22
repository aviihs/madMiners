import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../controller/game_controller.dart';
import 'components/effects_components.dart';
import 'components/miners_component.dart';
import 'components/monsters_component.dart';
import 'components/tile_map_component.dart';
import 'components/treasure_arrow_component.dart';

/// Flame view of the match. Pure rendering — all game state comes from the
/// [GameController], which in turn comes from the authoritative simulation.
class MadMinersGame extends FlameGame {
  MadMinersGame(this.controller, {this.highQuality = true}) : particles = ParticlesComponent(highQuality: highQuality);

  /// Phones default to fewer lights/particles (Settings → High quality graphics).
  final bool highQuality;

  final GameController controller;
  static const double tileSize = 32;

  /// Roughly how many tiles fit across the shorter screen edge.
  static const double tilesAcross = 13;

  final ParticlesComponent particles;
  final _rng = Random();
  double _shake = 0;

  @override
  Color backgroundColor() => const Color(0xFF0C0A09);

  @override
  Future<void> onLoad() async {
    world.addAll([
      TileMapComponent(controller),
      particles,
      BombsComponent(controller),
      MonstersComponent(controller),
      MysteryOpeningsComponent(controller),
      MinersComponent(controller),
      DarknessComponent(controller, highQuality: highQuality),
      TreasureArrowComponent(controller),
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

    for (final fx in controller.drainFx()) {
      switch (fx.kind) {
        case FxKind.text:
          world.add(FloatingText(fx));
        case FxKind.chips:
          particles.chips(fx.x, fx.y, Color(fx.color), fx.amount.round());
        case FxKind.burst:
          particles.burst(fx.x, fx.y, Color(fx.color));
        case FxKind.shake:
          _shake = max(_shake, fx.amount);
      }
    }

    final me = controller.me;
    if (me != null) {
      final target = Vector2(me.rx * tileSize, me.ry * tileSize);
      final pos = camera.viewfinder.position;
      var next = pos + (target - pos) * min(1, step * 9);
      if (_shake > 0.2) {
        next += Vector2((_rng.nextDouble() - 0.5) * _shake, (_rng.nextDouble() - 0.5) * _shake);
        _shake *= pow(0.02, step).toDouble();
      }
      camera.viewfinder.position = next;
    }
    super.update(step);
  }
}
