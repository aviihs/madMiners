import 'package:flutter/foundation.dart';

/// Google OAuth client IDs, passed at build time:
///   --dart-define=MM_GOOGLE_SERVER_CLIENT_ID=WEB_CLIENT_ID   (all platforms)
///   --dart-define=MM_GOOGLE_CLIENT_ID=IOS_CLIENT_ID   (Apple only)
abstract final class GoogleConfig {
  static const serverClientId = String.fromEnvironment('MM_GOOGLE_SERVER_CLIENT_ID');
  static const appleClientId = String.fromEnvironment('MM_GOOGLE_CLIENT_ID');

  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get isConfigured => serverClientId.isNotEmpty;
}
