import '../../../../core/error/result.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class SignInAsGuest {
  const SignInAsGuest(this._repo);
  final AuthRepository _repo;

  Future<Result<Session>> call({required String username, required String serverUrl}) =>
      _repo.signInAsGuest(username: username.trim(), serverUrl: serverUrl.trim());
}

class RestoreSession {
  const RestoreSession(this._repo);
  final AuthRepository _repo;
  Future<Result<Session>?> call() => _repo.restore();
}

class RefreshProfile {
  const RefreshProfile(this._repo);
  final AuthRepository _repo;
  Future<Result<Session>> call(Session s) => _repo.refreshProfile(s);
}

class SignOut {
  const SignOut(this._repo);
  final AuthRepository _repo;
  Future<void> call() => _repo.signOut();
}

class CheckServer {
  const CheckServer(this._repo);
  final AuthRepository _repo;
  Future<bool> call(String serverUrl) => _repo.isServerReachable(serverUrl.trim());
}

class FindServer {
  const FindServer(this._repo);
  final AuthRepository _repo;
  Future<String?> call(String preferred) => _repo.findServer(preferred.trim());
}
