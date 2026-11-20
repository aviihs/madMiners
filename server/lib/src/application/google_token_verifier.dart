/// Verified facts from a Google ID token.
class GoogleIdentity {
  const GoogleIdentity({required this.subject, required this.email, required this.name});
  final String subject;
  final String? email;
  final String? name;
}

/// Port: checks a Google ID token's signature, issuer, audience and expiry.
abstract interface class GoogleTokenVerifier {
  bool get isConfigured;

  /// Returns null when the token is invalid.
  Future<GoogleIdentity?> verify(String idToken);
}
