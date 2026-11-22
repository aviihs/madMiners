import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/server_config.dart';
import 'api_exception.dart';

/// Thin JSON client for the `/api/v1` envelope `{success, data | error}`.
class ApiClient {
  ApiClient(this._config, {http.Client? client}) : _http = client ?? http.Client();

  final ServerConfig _config;
  final http.Client _http;

  Future<T> get<T>(String path, {String? token}) => _send<T>('GET', path, token: token);

  Future<T> post<T>(String path, {Object? body, String? token}) => _send<T>('POST', path, body: body, token: token);

  Future<T> _send<T>(String method, String path, {Object? body, String? token}) async {
    final req = http.Request(method, _config.httpUri(path))..headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(ServerConfig.requestTimeout));
    } on TimeoutException catch (e) {
      throw OfflineException(e);
    } on http.ClientException catch (e) {
      throw OfflineException(e);
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(res.statusCode, 'BAD_RESPONSE', 'Unexpected server response.');
    }
    if (json['success'] == true) return json['data'] as T;
    final err = (json['error'] as Map?) ?? const {};
    throw ApiException(res.statusCode, err['code'] as String? ?? 'UNKNOWN', err['message'] as String? ?? 'Request failed.');
  }
}
