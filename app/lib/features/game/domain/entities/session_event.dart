import 'package:mad_miners_core/mad_miners_core.dart';

enum LinkStatus { connecting, connected, reconnecting, lost }

sealed class SessionEvent {
  const SessionEvent();
}

class SessionJoined extends SessionEvent {
  const SessionJoined({
    required this.youId,
    required this.roomCode,
    required this.settings,
    required this.map,
    required this.reconnected,
  });
  final String youId;
  final String roomCode;
  final MatchSettings settings;
  final GameMap map;
  final bool reconnected;
}

class SessionSnapshot extends SessionEvent {
  const SessionSnapshot(this.snapshot);
  final WorldSnapshot snapshot;
}

class SessionEnded extends SessionEvent {
  const SessionEnded(this.result);
  final MatchResult result;
}

class SessionLink extends SessionEvent {
  const SessionLink(this.status, {this.message, this.rttMs});
  final LinkStatus status;
  final String? message;
  final int? rttMs;
}

/// Private treasure sense for this player.
class SessionHint extends SessionEvent {
  const SessionHint(this.hint);
  final TreasureHint hint;
}
