import '../../../../core/config/server_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/session_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local, this._config) {
    final saved = _local.serverUrl;
    if (saved != null) _config.baseUrl = saved;
  }

  final AuthRemoteDataSource _remote;
  final SessionLocalDataSource _local;
  final ServerConfig _config;

  @override
  String get lastServerUrl => _config.baseUrl;

  @override
  Future<Result<Session>> signInAsGuest({required String username, required String serverUrl}) {
    _config.baseUrl = serverUrl;
    return guard(() async {
      final (token, profile) = await _remote.registerGuest(username);
      await _local.save(token: token, serverUrl: serverUrl);
      return Session(profile: profile, token: token, serverUrl: serverUrl);
    });
  }

  @override
  Future<Result<Session>?> restore() async {
    final token = _local.token;
    if (token == null) return null;
    final result = await guard(() async {
      final profile = await _remote.me(token);
      return Session(profile: profile, token: token, serverUrl: _config.baseUrl);
    });
    if (result case Err(failure: UnauthorizedFailure())) await _local.clearToken();
    return result;
  }

  @override
  Future<Result<Session>> refreshProfile(Session session) => guard(() async {
    final profile = await _remote.me(session.token!);
    return session.copyWith(profile: profile);
  });

  @override
  Future<void> signOut() => _local.clearToken();
}
