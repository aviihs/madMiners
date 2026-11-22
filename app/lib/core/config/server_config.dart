import 'package:flutter/foundation.dart';

/// Where the game server lives.
///
/// * Release builds always talk to [production].
/// * Local development: `flutter run --dart-define=MM_SERVER=http://192.168.1.10:8080`.
/// * Debug builds can also switch servers from the login screen
///   ([canChangeServer]) and find one on the local Wi-Fi.
class ServerConfig {
  ServerConfig({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  /// The live game server (Render, Singapore).
  static const production = 'https://madminers-server.onrender.com';

  static const _override = String.fromEnvironment('MM_SERVER');

  static String get defaultBaseUrl => _override.isNotEmpty ? _override : production;

  /// Picking another server (and LAN discovery) is a developer tool, never
  /// shown to players.
  static const bool canChangeServer = kDebugMode || bool.fromEnvironment('MM_SERVER_PICKER');

  /// A free Render instance sleeps when idle and takes up to ~50 s to wake,
  /// so the first request after a quiet spell needs a long timeout.
  static const requestTimeout = Duration(seconds: 25);
  static const healthTimeout = Duration(seconds: 25);

  String baseUrl;

  bool get isProduction => _trimmed() == production;

  Uri httpUri(String path) => Uri.parse('${_trimmed()}$path');

  /// `https` → `wss`, `http` → `ws`.
  Uri wsUri(String pathAndQuery) {
    final base = Uri.parse(_trimmed());
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri.parse('$scheme://${base.authority}$pathAndQuery');
  }

  String _trimmed() => trim(baseUrl);

  static String trim(String url) => url.trim().endsWith('/') ? url.trim().substring(0, url.trim().length - 1) : url.trim();
}
