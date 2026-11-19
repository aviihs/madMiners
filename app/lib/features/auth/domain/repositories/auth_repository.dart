import '../../../../core/error/result.dart';
import '../entities/session.dart';

abstract interface class AuthRepository {
  Future<Result<Session>> signInAsGuest({required String username, required String serverUrl});

  /// Restores a saved session and refreshes the profile from the server.
  Future<Result<Session>?> restore();
  Future<Result<Session>> refreshProfile(Session session);
  Future<void> signOut();
  String get lastServerUrl;
}
