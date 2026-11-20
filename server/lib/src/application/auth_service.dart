import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../domain/entities/player_account.dart';
import '../domain/repositories/account_repository.dart';
import 'app_exception.dart';
import 'google_token_verifier.dart';

class AuthResult {
  const AuthResult(this.token, this.account, {this.isNew = false});
  final String token;
  final PlayerAccount account;
  final bool isNew;
}

/// Sign-in: guest accounts and Google. Issues opaque bearer tokens that are
/// stored hashed in `sessions`.
class AuthService {
  AuthService(this._accounts, this._google, {Random? random}) : _rng = random ?? Random.secure();

  final AccountRepository _accounts;
  final GoogleTokenVerifier _google;
  final Random _rng;

  static const sessionLifetime = Duration(days: 90);
  static final _validName = RegExp(r'^[A-Za-z0-9_ .\-]{3,16}$');

  static String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

  String _randomHex(int bytes) => List.generate(bytes, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  String _uuid() {
    final b = List.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<String> _uniqueName(String wanted) async {
    var base = wanted.replaceAll(RegExp(r'[^A-Za-z0-9_ .\-]'), '').trim();
    if (base.length < 3) base = 'Miner';
    if (base.length > 11) base = base.substring(0, 11);
    var name = base;
    var attempt = 0;
    while (await _accounts.usernameTaken(name)) {
      if (++attempt > 30) throw AppException.conflict('USERNAME_TAKEN', 'Username unavailable.');
      name = '$base${_rng.nextInt(9000) + 1000}';
    }
    return name;
  }

  Future<String> _newSession(String userId) async {
    final token = _randomHex(32);
    await _accounts.createSession(userId, hashToken(token), DateTime.now().add(sessionLifetime));
    return token;
  }

  Future<AuthResult> registerGuest(String rawName) async {
    final name = rawName.trim();
    if (!_validName.hasMatch(name)) {
      throw AppException.badRequest('INVALID_USERNAME', 'Use 3–16 letters, numbers, spaces, _ . or -.');
    }
    final id = _uuid();
    final account = await _accounts.createUser(
      id: id,
      username: await _uniqueName(name),
      identity: Identity('guest', id),
    );
    return AuthResult(await _newSession(id), account, isNew: true);
  }

  /// Signs in with Google. If [linkToToken] is a valid guest session, the
  /// Google identity is attached to that account instead (FR-005).
  Future<AuthResult> signInWithGoogle(String idToken, {String? linkToToken}) async {
    if (!_google.isConfigured) {
      throw const AppException(501, 'GOOGLE_NOT_CONFIGURED', 'Google sign-in is not set up on this server.');
    }
    final g = await _google.verify(idToken);
    if (g == null) throw const AppException(401, 'INVALID_GOOGLE_TOKEN', 'Google sign-in failed. Please try again.');

    final existing = await _accounts.findUserIdByIdentity('google', g.subject);
    if (existing != null) {
      final acc = (await _accounts.findById(existing))!;
      _ensureActive(acc);
      return AuthResult(await _newSession(existing), acc);
    }

    if (linkToToken != null) {
      final guest = await _accounts.findBySession(hashToken(linkToToken));
      if (guest != null) {
        await _accounts.linkIdentity(guest.id, Identity('google', g.subject, email: g.email));
        return AuthResult(await _newSession(guest.id), (await _accounts.findById(guest.id))!);
      }
    }

    final id = _uuid();
    final acc = await _accounts.createUser(
      id: id,
      username: await _uniqueName(g.name ?? g.email?.split('@').first ?? 'Miner'),
      identity: Identity('google', g.subject, email: g.email),
    );
    return AuthResult(await _newSession(id), acc, isNew: true);
  }

  /// Resolves a bearer token or throws 401/403.
  Future<PlayerAccount> authenticate(String? token) async {
    if (token == null || token.isEmpty) throw AppException.unauthorized;
    final account = await _accounts.findBySession(hashToken(token));
    if (account == null) throw AppException.unauthorized;
    _ensureActive(account);
    return account;
  }

  Future<void> signOut(String token) => _accounts.deleteSession(hashToken(token));

  void _ensureActive(PlayerAccount a) {
    if (a.status != AccountStatus.active) {
      throw const AppException(403, 'ACCOUNT_SUSPENDED', 'This account is suspended.');
    }
  }
}
