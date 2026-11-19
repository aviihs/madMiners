import 'package:flutter_test/flutter_test.dart';
import 'package:mad_miners/features/game/data/datasources/local_game_session.dart';
import 'package:mad_miners/features/game/domain/entities/game_target.dart';
import 'package:mad_miners/features/game/presentation/controller/game_controller.dart';
import 'package:mad_miners_core/mad_miners_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline match: you + 7 bots, prediction and HUD update', () async {
    final session = LocalGameSession(
      const OfflineTarget(playerName: 'Tester', settings: MatchSettings(durationSeconds: 60)),
    );
    final controller = GameController(session);
    await controller.start();
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    expect(controller.ready, isTrue);
    expect(controller.miners.length, greaterThan(2), reason: 'miners trickle into the lobby');
    expect(controller.miners.values.any((m) => m.snap.isBot), isFalse, reason: 'everyone looks like a player');
    expect(controller.hud.value.me?.name, 'Tester');
    expect(controller.hud.value.warmup, greaterThan(0));

    controller.joyX = 1;
    for (var i = 0; i < 30; i++) {
      controller.update(1 / 60);
    }
    expect(controller.predX, greaterThan(controller.map!.spawn.x.toDouble() - 3));
    await controller.dispose();
  });
}
