import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/session_event.dart';

class ScoreLine {
  const ScoreLine({
    required this.id,
    required this.name,
    required this.score,
    required this.isBot,
    required this.isYou,
    required this.team,
    required this.connected,
  });
  final String id;
  final String name;
  final int score;
  final bool isBot;
  final bool isYou;
  final int team;
  final bool connected;
}

/// Everything the Flutter HUD overlay renders. Rebuilt on each snapshot.
class HudState {
  const HudState({
    this.me,
    this.timeLeft = 0,
    this.scoreboard = const [],
    this.teamScores = const [],
    this.feed = const [],
    this.link = LinkStatus.connecting,
    this.linkMessage,
    this.rttMs,
    this.roomCode = '',
    this.mode = GameMode.competition,
    this.mapName = '',
    this.oxygenDepth = 0,
  });

  final PlayerSnapshot? me;
  final double timeLeft;
  final List<ScoreLine> scoreboard;
  final List<int> teamScores;
  final List<String> feed;
  final LinkStatus link;
  final String? linkMessage;
  final int? rttMs;
  final String roomCode;
  final GameMode mode;
  final String mapName;
  final int oxygenDepth;

  bool get ready => me != null;
  bool get deep => me != null && me!.y > oxygenDepth;

  HudState copyWith({
    PlayerSnapshot? me,
    double? timeLeft,
    List<ScoreLine>? scoreboard,
    List<int>? teamScores,
    List<String>? feed,
    LinkStatus? link,
    String? linkMessage,
    int? rttMs,
    String? roomCode,
    GameMode? mode,
    String? mapName,
    int? oxygenDepth,
  }) => HudState(
    me: me ?? this.me,
    timeLeft: timeLeft ?? this.timeLeft,
    scoreboard: scoreboard ?? this.scoreboard,
    teamScores: teamScores ?? this.teamScores,
    feed: feed ?? this.feed,
    link: link ?? this.link,
    linkMessage: linkMessage ?? this.linkMessage,
    rttMs: rttMs ?? this.rttMs,
    roomCode: roomCode ?? this.roomCode,
    mode: mode ?? this.mode,
    mapName: mapName ?? this.mapName,
    oxygenDepth: oxygenDepth ?? this.oxygenDepth,
  );
}
