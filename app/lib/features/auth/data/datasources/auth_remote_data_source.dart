import 'package:http/http.dart' as http;

import '../../../../core/config/server_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/player_profile_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);
  final ApiClient _api;

  Future<(String token, PlayerProfileModel profile)> registerGuest(String username) async {
    final data = await _api.post<Map<String, dynamic>>('/api/v1/auth/guest', body: {'username': username});
    return (data['accessToken'] as String, PlayerProfileModel.fromJson(data));
  }

  Future<(String token, PlayerProfileModel profile)> google(String idToken, {String? linkToken}) async {
    final data = await _api.post<Map<String, dynamic>>('/api/v1/auth/google', body: {'idToken': idToken}, token: linkToken);
    return (data['accessToken'] as String, PlayerProfileModel.fromJson(data));
  }

  Future<void> logout(String token) async {
    try {
      await _api.post<Map<String, dynamic>>('/api/v1/auth/logout', token: token);
    } catch (_) {}
  }

  /// True when `GET /health` answers 200 within [timeout].
  Future<bool> health(String baseUrl, {Duration timeout = ServerConfig.healthTimeout}) async {
    try {
      final res = await http.get(Uri.parse('${ServerConfig.trim(baseUrl)}/health')).timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<PlayerProfileModel> me(String token) async =>
      PlayerProfileModel.fromJson(await _api.get<Map<String, dynamic>>('/api/v1/players/me', token: token));
}
