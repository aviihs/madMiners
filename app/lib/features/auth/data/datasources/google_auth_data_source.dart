import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/google_config.dart';

class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}

class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable(this.reason);
  final String reason;
}

/// Wraps the platform Google sign-in and returns an ID token for the server.
class GoogleAuthDataSource {
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: GoogleConfig.appleClientId.isEmpty ? null : GoogleConfig.appleClientId,
      serverClientId: GoogleConfig.serverClientId,
    );
    _initialized = true;
  }

  Future<String> obtainIdToken() async {
    if (!GoogleConfig.platformSupported) {
      throw const GoogleSignInUnavailable('Google sign-in isn\'t available on this device.');
    }
    if (!GoogleConfig.isConfigured) {
      throw const GoogleSignInUnavailable('Google sign-in isn\'t set up in this build yet.');
    }
    await _init();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleSignInUnavailable('Google sign-in isn\'t available on this device.');
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const GoogleSignInUnavailable('Google did not return an ID token.');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const GoogleSignInCancelled();
      throw GoogleSignInUnavailable(e.description ?? 'Google sign-in failed.');
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
