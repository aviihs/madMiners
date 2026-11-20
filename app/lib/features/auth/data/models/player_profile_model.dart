import 'package:mad_miners_core/mad_miners_core.dart';

import '../../domain/entities/player_profile.dart';

class PlayerProfileModel extends PlayerProfile {
  const PlayerProfileModel({
    required super.id,
    required super.username,
    super.level,
    super.xp,
    super.totalCoins,
    super.wallet,
    super.gems,
    super.gamesPlayed,
    super.wins,
    super.bestScore,
    super.bestDepth,
    super.oresMined,
    super.todayWins,
    super.providers,
    super.email,
    super.owned,
    super.look,
  });

  factory PlayerProfileModel.fromJson(Map<String, dynamic> j) => PlayerProfileModel(
    id: j['playerId'] as String,
    username: j['username'] as String,
    level: (j['level'] as num?)?.toInt() ?? 1,
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    totalCoins: (j['totalCoins'] as num?)?.toInt() ?? 0,
    wallet: (j['wallet'] as num?)?.toInt() ?? 0,
    gems: (j['gems'] as num?)?.toInt() ?? 0,
    gamesPlayed: (j['gamesPlayed'] as num?)?.toInt() ?? 0,
    wins: (j['wins'] as num?)?.toInt() ?? 0,
    bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
    bestDepth: (j['bestDepth'] as num?)?.toInt() ?? 0,
    oresMined: (j['oresMined'] as num?)?.toInt() ?? 0,
    todayWins: (j['todayWins'] as num?)?.toInt() ?? 0,
    providers: (j['providers'] as List? ?? const []).cast<String>(),
    email: j['email'] as String?,
    owned: {...(j['owned'] as List? ?? const []).cast<String>()},
    look: Look.fromJson(j['look']),
  );
}
