import 'package:mad_miners_core/mad_miners_core.dart';

import '../entities/game_target.dart';
import '../entities/session_event.dart';

/// A live match. Presentation only talks to this interface, so it doesn't
/// know (or care) whether the server is remote or running on-device.
abstract interface class GameSession {
  Stream<SessionEvent> get events;
  Future<void> start();
  void sendInput(PlayerInput input);
  void buyUpgrade(UpgradeKind kind);
  void chat(String text);
  Future<void> leave();
}

abstract interface class GameSessionRepository {
  GameSession open(GameTarget target);
}
