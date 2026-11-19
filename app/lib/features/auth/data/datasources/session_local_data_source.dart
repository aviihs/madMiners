import 'package:shared_preferences/shared_preferences.dart';

/// Persists the access token + server URL on device.
class SessionLocalDataSource {
  SessionLocalDataSource(this._prefs);
  final SharedPreferences _prefs;

  static const _kToken = 'mm.token';
  static const _kServer = 'mm.server';

  String? get token => _prefs.getString(_kToken);
  String? get serverUrl => _prefs.getString(_kServer);

  Future<void> save({required String token, required String serverUrl}) async {
    await _prefs.setString(_kToken, token);
    await _prefs.setString(_kServer, serverUrl);
  }

  Future<void> saveServer(String serverUrl) => _prefs.setString(_kServer, serverUrl);
  Future<void> clearToken() => _prefs.remove(_kToken);
}
