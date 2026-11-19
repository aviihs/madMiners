import '../../../../core/config/server_config.dart';
import '../../domain/entities/game_target.dart';
import '../../domain/repositories/game_session_repository.dart';
import '../datasources/local_game_session.dart';
import '../datasources/remote_game_session.dart';

class GameSessionRepositoryImpl implements GameSessionRepository {
  GameSessionRepositoryImpl(this._config);
  final ServerConfig _config;

  @override
  GameSession open(GameTarget target) => switch (target) {
    OnlineTarget t => RemoteGameSession(t, _config),
    OfflineTarget t => LocalGameSession(t),
  };
}
