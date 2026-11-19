import '../../../../core/error/result.dart';
import '../entities/session.dart';

abstract interface class AuthRepository {
  Future<Result<Session>> signInAsGuest({required String username, required String serverUrl});

  /// Restores a saved session and refreshes the profile from the server.
  Future<Result<Session>?> restore();
  Future<Result<Session>> refreshProfile(Session session);
  Future<void> signOut();
  String get lastServerUrl;

  /// Quick reachability probe for the login screen.
  Future<bool> isServerReachable(String serverUrl);

  /// Tries the given URL, common local addresses and LAN discovery.
  /// Returns a reachable server URL, or null.
  Future<String?> findServer(String preferred);
}
