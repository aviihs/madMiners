import 'dart:math';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/player_profile_model.dart';

class StoreRemoteDataSource {
  StoreRemoteDataSource(this._api);
  final ApiClient _api;
  final _rng = Random.secure();

  /// Unique per tap, so a retried request never charges twice.
  String _requestId() => List.generate(16, (_) => _rng.nextInt(16).toRadixString(16)).join();

  Future<PlayerProfileModel> purchase(String token, String itemId) async => PlayerProfileModel.fromJson(
    await _api.post<Map<String, dynamic>>('/api/v1/store/purchase', body: {'itemId': itemId, 'requestId': _requestId()}, token: token),
  );

  Future<PlayerProfileModel> equip(String token, String itemId) async => PlayerProfileModel.fromJson(
    await _api.post<Map<String, dynamic>>('/api/v1/players/me/equip', body: {'itemId': itemId}, token: token),
  );
}
