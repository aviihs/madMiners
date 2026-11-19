import 'package:http/http.dart' as http;

import '../../../../core/network/api_client.dart';
import '../models/player_profile_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);
  final ApiClient _api;

  Future<(String token, PlayerProfileModel profile)> registerGuest(String username) async {
    final data = await _api.post<Map<String, dynamic>>('/api/v1/auth/guest', body: {'username': username});
    return (data['accessToken'] as String, PlayerProfileModel.fromJson(data));
  }

  Future<bool> health(String baseUrl) async {
    try {
      final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final res = await http.get(Uri.parse('$b/health')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<PlayerProfileModel> me(String token) async =>
      PlayerProfileModel.fromJson(await _api.get<Map<String, dynamic>>('/api/v1/players/me', token: token));
}
