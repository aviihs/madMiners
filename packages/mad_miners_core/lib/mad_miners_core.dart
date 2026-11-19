/// Shared game domain for Mad Miners: balance config, world, authoritative
/// simulation (incl. bots) and the real-time network protocol.
library;

export 'src/config/balance.dart';
export 'src/model/match_settings.dart';
export 'src/model/snapshot.dart';
export 'src/protocol/messages.dart';
export 'src/sim/bot_brain.dart' show BotBrain, BotGoal, BotDecision;
export 'src/sim/game_simulation.dart';
export 'src/sim/physics.dart';
export 'src/sim/sim_player.dart';
export 'src/world/game_map.dart';
export 'src/world/map_generator.dart';
export 'src/world/tile.dart';
