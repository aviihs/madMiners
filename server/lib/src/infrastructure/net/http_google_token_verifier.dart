import 'dart:convert';
import 'dart:io';

import '../../application/google_token_verifier.dart';

/// Verifies Google ID tokens with Google's tokeninfo endpoint, then checks
/// the audience against our OAuth client IDs (MM_GOOGLE_CLIENT_IDS).
class HttpGoogleTokenVerifier implements GoogleTokenVerifier {
  HttpGoogleTokenVerifier(this.allowedClientIds);

  factory HttpGoogleTokenVerifier.fromEnvironment() => HttpGoogleTokenVerifier(
    (Platform.environment['MM_GOOGLE_CLIENT_IDS'] ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet(),
  );

  final Set<String> allowedClientIds;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 5);

  @override
  bool get isConfigured => allowedClientIds.isNotEmpty;

  @override
  Future<GoogleIdentity?> verify(String idToken) async {
    try {
      final uri = Uri.https('oauth2.googleapis.com', '/tokeninfo', {'id_token': idToken});
      final res = await (await _http.getUrl(uri)).close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final iss = j['iss'];
      if (iss != 'accounts.google.com' && iss != 'https://accounts.google.com') return null;
      if (!allowedClientIds.contains(j['aud'])) return null;
      final exp = int.tryParse('${j['exp']}') ?? 0;
      if (exp * 1000 < DateTime.now().millisecondsSinceEpoch) return null;
      final verified = j['email_verified'] == true || j['email_verified'] == 'true';
      return GoogleIdentity(subject: j['sub'] as String, email: verified ? j['email'] as String? : null, name: j['given_name'] as String? ?? j['name'] as String?);
    } catch (_) {
      return null;
    }
  }
}
