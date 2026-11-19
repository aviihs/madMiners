import 'package:mad_miners_core/mad_miners_core.dart';

/// Where a match is played.
sealed class GameTarget {
  const GameTarget();
}

class OnlineTarget extends GameTarget {
  const OnlineTarget({required this.token, required this.wsPath, required this.roomCode});
  final String token;
  final String wsPath;
  final String roomCode;
}

/// Offline practice: the full simulation (incl. bots) runs on-device.
class OfflineTarget extends GameTarget {
  const OfflineTarget({required this.playerName, required this.settings});
  final String playerName;
  final MatchSettings settings;
}
