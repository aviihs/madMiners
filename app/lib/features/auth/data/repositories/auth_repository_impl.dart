import '../../../../core/config/server_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../../../core/network/server_discovery.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/google_auth_data_source.dart';
import '../datasources/session_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local, this._config, this._google) {
    final saved = _local.serverUrl;
    if (saved != null) _config.baseUrl = saved;
  }

  final AuthRemoteDataSource _remote;
  final SessionLocalDataSource _local;
  final ServerConfig _config;
  final GoogleAuthDataSource _google;

  @override
  String get lastServerUrl => _config.baseUrl;

  @override
  Future<Result<Session>> signInAsGuest({required String username, required String serverUrl}) async {
    _config.baseUrl = serverUrl;
    final result = await guard(() async {
      final (token, profile) = await _remote.registerGuest(username);
      await _local.save(token: token, serverUrl: serverUrl);
      return Session(profile: profile, token: token, serverUrl: serverUrl);
    });
    if (result case Err(failure: NetworkFailure())) {
      return Err(NetworkFailure('Can\'t reach $serverUrl. Is the server running, and is this device on the same Wi‑Fi?'));
    }
    return result;
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
  Future<Result<Session>> signInWithGoogle({required String serverUrl, Session? linkTo}) async {
    _config.baseUrl = serverUrl;
    final String idToken;
    try {
      idToken = await _google.obtainIdToken();
    } on GoogleSignInCancelled {
      return const Err(ServerFailure('Sign-in cancelled.', code: 'CANCELLED'));
    } on GoogleSignInUnavailable catch (e) {
      return Err(ServerFailure(e.reason, code: 'GOOGLE_UNAVAILABLE'));
    }
    final result = await guard(() async {
      final (token, profile) = await _remote.google(idToken, linkToken: linkTo?.token);
      await _local.save(token: token, serverUrl: serverUrl);
      return Session(profile: profile, token: token, serverUrl: serverUrl);
    });
    if (result case Err(failure: NetworkFailure())) {
      return Err(NetworkFailure('Can\'t reach $serverUrl. Is the server running?'));
    }
    return result;
  }

  @override
  Future<void> signOut([Session? session]) async {
    if (session?.token != null) await _remote.logout(session!.token!);
    await _google.signOut();
    await _local.clearToken();
  }

  @override
  Future<bool> isServerReachable(String serverUrl) => _remote.health(serverUrl);

  @override
  Future<String?> findServer(String preferred) async {
    final candidates = <String>{
      if (preferred.isNotEmpty) preferred,
      'http://localhost:8080',
      'http://127.0.0.1:8080',
      'http://10.0.2.2:8080', // Android emulator -> host
      'http://10.0.3.2:8080', // Genymotion -> host
    };
    final checks = await Future.wait(candidates.map((u) async => (u, await _remote.health(u))));
    for (final (url, ok) in checks) {
      if (ok) return url;
    }
    final lan = await listenForLanServer();
    if (lan != null && await _remote.health(lan)) return lan;
    return null;
  }
}
