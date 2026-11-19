import 'package:flutter/foundation.dart';

/// Where the game server lives. Editable from the login screen.
class ServerConfig {
  ServerConfig({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  String baseUrl;

  /// Android emulators reach the host machine via 10.0.2.2.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('MM_SERVER');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  Uri httpUri(String path) => Uri.parse('${_trimmed()}$path');

  Uri wsUri(String pathAndQuery) {
    final base = Uri.parse(_trimmed());
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri.parse('$scheme://${base.authority}$pathAndQuery');
  }

  String _trimmed() => baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
}
