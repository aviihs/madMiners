import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/session_event.dart';

/// A short-lived headline, e.g. "MYSTERY BOMB DISCOVERED!".
class HudBanner {
  const HudBanner(this.title, this.subtitle, this.color, this.id);
  final String title;
  final String subtitle;
  final int color;

  /// Changes for every new banner so the UI can re-animate.
  final int id;
}

class ScoreLine {
  const ScoreLine({
    required this.id,
    required this.name,
    required this.score,
    required this.isBot,
    required this.isYou,
    required this.team,
    required this.connected,
    required this.depth,
  });
  final String id;
  final String name;
  final int score;
  final bool isBot;
  final bool isYou;
  final int team;
  final bool connected;
  final int depth;
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
    this.mode = GameMode.treasureHunt,
    this.mapName = '',
    this.lavaDepth = 0,
    this.warmup = 0,
    this.lobbyTarget = 8,
    this.hint = TreasureHint.none,
    this.banner,
    this.worldEvent,
    this.worldEventLeft = 0,
    this.deathCause,
    this.deathLost = 0,
  });

  /// Why you last died, and how many match coins you dropped.
  final String? deathCause;
  final int deathLost;

  /// Big centre-screen announcement (Mystery Bomb, world event…).
  final HudBanner? banner;
  final WorldEventKind? worldEvent;
  final double worldEventLeft;

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
  final int lavaDepth;

  /// Seconds until digging starts.
  final double warmup;

  /// How many miners the room fills up to.
  final int lobbyTarget;

  /// Your private treasure sense.
  final TreasureHint hint;

  bool get ready => me != null;
  /// Your current depth in tiles below the surface.
  int get depth => me == null ? 0 : (me!.y.floor() - MapGenerator.surfaceRows + 1).clamp(0, 9999);

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
    int? lavaDepth,
    double? warmup,
    int? lobbyTarget,
    TreasureHint? hint,
    HudBanner? banner,
    bool clearBanner = false,
    WorldEventKind? worldEvent,
    bool clearEvent = false,
    double? worldEventLeft,
    String? deathCause,
    int? deathLost,
  }) => HudState(
    deathCause: deathCause ?? this.deathCause,
    deathLost: deathLost ?? this.deathLost,
    banner: clearBanner ? null : (banner ?? this.banner),
    worldEvent: clearEvent ? null : (worldEvent ?? this.worldEvent),
    worldEventLeft: worldEventLeft ?? this.worldEventLeft,
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
    lavaDepth: lavaDepth ?? this.lavaDepth,
    warmup: warmup ?? this.warmup,
    lobbyTarget: lobbyTarget ?? this.lobbyTarget,
    hint: hint ?? this.hint,
  );
}
