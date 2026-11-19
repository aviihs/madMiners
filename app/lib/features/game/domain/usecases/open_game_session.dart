import '../entities/game_target.dart';
import '../repositories/game_session_repository.dart';

class OpenGameSession {
  const OpenGameSession(this._repo);
  final GameSessionRepository _repo;
  GameSession call(GameTarget target) => _repo.open(target);
}
