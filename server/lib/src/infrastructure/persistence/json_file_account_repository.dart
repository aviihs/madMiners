import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/entities/player_account.dart';
import '../../domain/repositories/account_repository.dart';

/// Development adapter: keeps accounts in memory and flushes them to a JSON
/// file (atomic write via temp file + rename). Replace with a PostgreSQL
/// adapter for production — the [AccountRepository] port stays the same.
class JsonFileAccountRepository implements AccountRepository {
  JsonFileAccountRepository._(this._file);

  /// Pass `null` for a purely in-memory repository (tests).
  static Future<JsonFileAccountRepository> open(String? path) async {
    final repo = JsonFileAccountRepository._(path == null ? null : File(path));
    await repo._load();
    return repo;
  }

  final File? _file;
  final Map<String, PlayerAccount> _byId = {};
  final Map<String, String> _idByToken = {};
  Future<void> _writeChain = Future.value();

  Future<void> _load() async {
    final f = _file;
    if (f == null || !await f.exists()) return;
    final list = jsonDecode(await f.readAsString()) as List;
    for (final j in list) {
      _index(PlayerAccount.fromJson(j as Map<String, dynamic>));
    }
  }

  void _index(PlayerAccount a) {
    _byId[a.id] = a;
    _idByToken[a.tokenHash] = a.id;
  }

  Future<void> _flush() {
    final f = _file;
    if (f == null) return Future.value();
    // Serialise writes so concurrent saves can't interleave.
    return _writeChain = _writeChain.then((_) async {
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(_byId.values.map((a) => a.toJson()).toList()));
      await tmp.rename(f.path);
    });
  }

  @override
  Future<PlayerAccount?> findById(String id) async => _byId[id];

  @override
  Future<PlayerAccount?> findByTokenHash(String tokenHash) async {
    final id = _idByToken[tokenHash];
    return id == null ? null : _byId[id];
  }

  @override
  Future<bool> usernameTaken(String username) async =>
      _byId.values.any((a) => a.username.toLowerCase() == username.toLowerCase());

  @override
  Future<void> save(PlayerAccount account) {
    _index(account);
    return _flush();
  }

  @override
  Future<void> saveAll(Iterable<PlayerAccount> accounts) {
    accounts.forEach(_index);
    return _flush();
  }

  @override
  Future<List<PlayerAccount>> topByCoins(int limit) async =>
      (_byId.values.toList()..sort((a, b) => b.totalCoins.compareTo(a.totalCoins))).take(limit).toList();
}
