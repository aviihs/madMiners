import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../domain/entities/player_account.dart';
import '../domain/repositories/account_repository.dart';
import 'app_exception.dart';

class AuthResult {
  const AuthResult(this.token, this.account);
  final String token;
  final PlayerAccount account;
}

/// Guest accounts with opaque bearer tokens. Email/password, EOS or platform
/// login can be added as further methods without changing callers.
class AuthService {
  AuthService(this._accounts, {Random? random}) : _rng = random ?? Random.secure();

  final AccountRepository _accounts;
  final Random _rng;

  static final _validName = RegExp(r'^[A-Za-z0-9_ \-]{3,16}$');

  static String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

  String _randomHex(int bytes) =>
      List.generate(bytes, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<AuthResult> registerGuest(String rawName) async {
    final name = rawName.trim();
    if (!_validName.hasMatch(name)) {
      throw AppException.badRequest('INVALID_USERNAME', 'Use 3–16 letters, numbers, spaces, _ or -.');
    }
    var username = name;
    var attempt = 0;
    while (await _accounts.usernameTaken(username)) {
      if (++attempt > 20) throw AppException.conflict('USERNAME_TAKEN', 'Username unavailable.');
      username = '$name#${_rng.nextInt(9000) + 1000}';
    }
    final token = _randomHex(32);
    final account = PlayerAccount(
      id: _uuid(),
      username: username,
      tokenHash: hashToken(token),
      createdAt: DateTime.now().toUtc(),
    );
    await _accounts.save(account);
    return AuthResult(token, account);
  }

  /// Resolves a bearer token or throws 401/403.
  Future<PlayerAccount> authenticate(String? token) async {
    if (token == null || token.isEmpty) throw AppException.unauthorized;
    final account = await _accounts.findByTokenHash(hashToken(token));
    if (account == null) throw AppException.unauthorized;
    if (account.status != AccountStatus.active) {
      throw const AppException(403, 'ACCOUNT_SUSPENDED', 'This account is suspended.');
    }
    return account;
  }

  String _uuid() {
    final b = List.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
