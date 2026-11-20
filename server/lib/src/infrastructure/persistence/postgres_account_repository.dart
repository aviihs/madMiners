import 'dart:io';

import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

import '../../domain/entities/match_record.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/repositories/account_repository.dart';

/// PostgreSQL adapter (SRS §7). All money-moving writes run in one
/// transaction and lock the wallet row first.
class PostgresAccountRepository implements AccountRepository {
  PostgresAccountRepository._(this._db);

  final Pool<void> _db;

  /// Opens a pool and applies pending migrations from [migrationsDir].
  static Future<PostgresAccountRepository> open(String url, {required String migrationsDir}) async {
    final pool = Pool<void>.withUrl(url);
    final repo = PostgresAccountRepository._(pool);
    await repo._migrate(migrationsDir);
    return repo;
  }

  Future<void> close() => _db.close();

  // ---- migrations ------------------------------------------------------------

  Future<void> _migrate(String dir) async {
    await _db.execute('CREATE TABLE IF NOT EXISTS schema_migrations (version varchar(64) PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
    final applied = {for (final r in await _db.execute('SELECT version FROM schema_migrations')) r[0] as String};
    final files = Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.sql')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final version = p.basenameWithoutExtension(f.path);
      if (applied.contains(version)) continue;
      final sql = await f.readAsString();
      await _db.runTx((tx) async {
        for (final stmt in _splitStatements(sql)) {
          await tx.execute(stmt);
        }
        await tx.execute(Sql.named('INSERT INTO schema_migrations (version) VALUES (@v)'), parameters: {'v': version});
      });
      stdout.writeln('   Migrated: $version');
    }
  }

  static Iterable<String> _splitStatements(String sql) => sql
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);

  // ---- reads -----------------------------------------------------------------

  static const _accountSelect = '''
    SELECT u.id, u.username, u.status, u.created_at,
           s.xp, s.games_played, s.wins, s.best_score, s.best_depth, s.ores_mined, s.total_coins,
           w.coins, w.gems,
           COALESCE(d.wins, 0) AS today_wins, COALESCE(d.coins, 0) AS today_coins,
           (SELECT array_agg(item_id) FROM owned_cosmetics o WHERE o.user_id = u.id) AS owned,
           (SELECT json_object_agg(slot, item_id) FROM equipped_cosmetics e WHERE e.user_id = u.id) AS equipped,
           (SELECT array_agg(provider ORDER BY id) FROM auth_identities a WHERE a.user_id = u.id) AS providers,
           (SELECT email FROM auth_identities a WHERE a.user_id = u.id AND email IS NOT NULL LIMIT 1) AS email
      FROM users u
      JOIN player_stats s ON s.user_id = u.id
      JOIN wallets w ON w.user_id = u.id
      LEFT JOIN daily_stats d ON d.user_id = u.id AND d.day = current_date
  ''';

  PlayerAccount _toAccount(Map<String, dynamic> r) {
    final equipped = (r['equipped'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const <String, String>{};
    return PlayerAccount(
      id: r['id'] as String,
      username: r['username'] as String,
      createdAt: r['created_at'] as DateTime,
      status: AccountStatus.values.asNameMap()[r['status']] ?? AccountStatus.active,
      stats: PlayerStats(
        xp: r['xp'] as int,
        gamesPlayed: r['games_played'] as int,
        wins: r['wins'] as int,
        bestScore: r['best_score'] as int,
        bestDepth: r['best_depth'] as int,
        oresMined: r['ores_mined'] as int,
        totalCoins: r['total_coins'] as int,
      ),
      coins: r['coins'] as int,
      gems: r['gems'] as int,
      todayWins: r['today_wins'] as int,
      todayCoins: r['today_coins'] as int,
      owned: {...(r['owned'] as List? ?? const []).cast<String>()},
      look: Look.fromSlots(equipped),
      providers: (r['providers'] as List? ?? const []).cast<String>(),
      email: r['email'] as String?,
    );
  }

  Future<PlayerAccount?> _one(Session s, String where, Map<String, dynamic> params) async {
    final rows = await s.execute(Sql.named('$_accountSelect WHERE $where'), parameters: params);
    return rows.isEmpty ? null : _toAccount(rows.first.toColumnMap());
  }

  @override
  Future<PlayerAccount?> findById(String id) => _one(_db, 'u.id = @id:uuid', {'id': id});

  @override
  Future<PlayerAccount?> findBySession(String tokenHash) async {
    final rows = await _db.execute(
      Sql.named('UPDATE sessions SET last_used_at = now() WHERE token_hash = @h AND expires_at > now() RETURNING user_id'),
      parameters: {'h': tokenHash},
    );
    if (rows.isEmpty) return null;
    return findById(rows.first[0] as String);
  }

  @override
  Future<String?> findUserIdByIdentity(String provider, String subject) async {
    final rows = await _db.execute(
      Sql.named('SELECT user_id FROM auth_identities WHERE provider = @p AND subject = @s'),
      parameters: {'p': provider, 's': subject},
    );
    return rows.isEmpty ? null : rows.first[0] as String;
  }

  @override
  Future<bool> usernameTaken(String username) async {
    final rows = await _db.execute(Sql.named('SELECT 1 FROM users WHERE lower(username) = lower(@u)'), parameters: {'u': username});
    return rows.isNotEmpty;
  }

  // ---- identity & sessions ------------------------------------------------------

  @override
  Future<PlayerAccount> createUser({required String id, required String username, required Identity identity}) async {
    await _db.runTx((tx) async {
      await tx.execute(Sql.named('INSERT INTO users (id, username) VALUES (@id:uuid, @u)'), parameters: {'id': id, 'u': username});
      await tx.execute(Sql.named('INSERT INTO player_stats (user_id) VALUES (@id:uuid)'), parameters: {'id': id});
      await tx.execute(Sql.named('INSERT INTO wallets (user_id) VALUES (@id:uuid)'), parameters: {'id': id});
      await _insertIdentity(tx, id, identity);
    });
    return (await findById(id))!;
  }

  Future<void> _insertIdentity(Session s, String userId, Identity i) => s.execute(
    Sql.named('INSERT INTO auth_identities (user_id, provider, subject, email) VALUES (@id:uuid, @p, @s, @e)'),
    parameters: {'id': userId, 'p': i.provider, 's': i.subject, 'e': i.email},
  );

  @override
  Future<void> linkIdentity(String userId, Identity identity) => _insertIdentity(_db, userId, identity);

  @override
  Future<void> createSession(String userId, String tokenHash, DateTime expiresAt) => _db.execute(
    Sql.named('INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (@h, @id:uuid, @exp:timestamptz)'),
    parameters: {'h': tokenHash, 'id': userId, 'exp': expiresAt.toUtc()},
  );

  @override
  Future<void> deleteSession(String tokenHash) =>
      _db.execute(Sql.named('DELETE FROM sessions WHERE token_hash = @h'), parameters: {'h': tokenHash});

  // ---- matches -----------------------------------------------------------------

  @override
  Future<void> recordMatch(MatchRecord m) => _db.runTx((tx) async {
    await tx.execute(
      Sql.named('''
        INSERT INTO matches (id, room_code, map_id, mode, started_at, duration_seconds, player_count, winner_user_id, winner_name)
        VALUES (@id:uuid, @code, @map, @mode, @start:timestamptz, @dur, @n, @wid:uuid, @wname)'''),
      parameters: {
        'id': m.id,
        'code': m.roomCode,
        'map': m.mapId.name,
        'mode': m.mode.name,
        'start': m.startedAt.toUtc(),
        'dur': m.durationSeconds,
        'n': m.playerCount,
        'wid': m.winnerUserId,
        'wname': m.winnerName,
      },
    );
    for (final pr in m.players) {
      final r = pr.result;
      final params = {
        'm': m.id,
        'u': pr.userId,
        'rank': r.rank,
        'score': r.score,
        'ores': r.oresMined,
        'xp': pr.reward.xp,
        'depth': r.maxDepth,
        'found': pr.foundTreasure,
        'coins': pr.reward.coins,
        'gems': pr.reward.gems,
      };
      await tx.execute(
        Sql.named('''
          INSERT INTO match_players (match_id, user_id, rank, score, ores, xp, max_depth, found_treasure, coins_awarded, gems_awarded)
          VALUES (@m:uuid, @u:uuid, @rank, @score, @ores, @xp, @depth, @found, @coins, @gems)'''),
        parameters: params,
      );
      await tx.execute(
        Sql.named('''
          UPDATE player_stats SET
            xp = xp + @xp, games_played = games_played + 1,
            wins = wins + CASE WHEN @found THEN 1 ELSE 0 END,
            best_score = GREATEST(best_score, @score), best_depth = GREATEST(best_depth, @depth),
            ores_mined = ores_mined + @ores, total_coins = total_coins + @coins
          WHERE user_id = @u:uuid'''),
        parameters: _pick(params, ['xp', 'found', 'score', 'depth', 'ores', 'coins', 'u']),
      );
      await tx.execute(
        Sql.named('''
          INSERT INTO daily_stats (user_id, day, wins, coins, games)
          VALUES (@u:uuid, current_date, CASE WHEN @found THEN 1 ELSE 0 END, @coins, 1)
          ON CONFLICT (user_id, day) DO UPDATE SET
            wins = daily_stats.wins + EXCLUDED.wins, coins = daily_stats.coins + EXCLUDED.coins, games = daily_stats.games + 1'''),
        parameters: _pick(params, ['u', 'found', 'coins']),
      );
      if (pr.reward.coins > 0) await _credit(tx, pr.userId, 'coins', pr.reward.coins, 'match_reward', 'match:${m.id}');
      if (pr.reward.gems > 0) await _credit(tx, pr.userId, 'gems', pr.reward.gems, 'match_reward', 'match:${m.id}');
    }
  });

  static Map<String, dynamic> _pick(Map<String, dynamic> all, List<String> keys) => {for (final k in keys) k: all[k]};

  Future<int> _credit(Session tx, String userId, String currency, int amount, String kind, String reference, {String? requestId}) async {
    final rows = await tx.execute(
      Sql.named('UPDATE wallets SET $currency = $currency + @a WHERE user_id = @u:uuid RETURNING $currency'),
      parameters: {'a': amount, 'u': userId},
    );
    final balance = rows.first[0] as int;
    await tx.execute(
      Sql.named('''
        INSERT INTO transactions (user_id, kind, currency, amount, balance_after, reference, request_id)
        VALUES (@u:uuid, @k, @c, @a, @b, @ref, @req)'''),
      parameters: {'u': userId, 'k': kind, 'c': currency, 'a': amount, 'b': balance, 'ref': reference, 'req': requestId},
    );
    return balance;
  }

  // ---- store -------------------------------------------------------------------

  @override
  Future<PlayerAccount> purchase(String userId, CosmeticDef item, String requestId) async {
    await _db.runTx((tx) async {
      // Lock the wallet so concurrent purchases serialise.
      final w = await tx.execute(Sql.named('SELECT coins, gems FROM wallets WHERE user_id = @u:uuid FOR UPDATE'), parameters: {'u': userId});
      final dup = await tx.execute(
        Sql.named('SELECT 1 FROM transactions WHERE user_id = @u:uuid AND request_id = @r'),
        parameters: {'u': userId, 'r': requestId},
      );
      if (dup.isNotEmpty) return; // retry of an already-applied purchase
      final owned = await tx.execute(
        Sql.named('SELECT 1 FROM owned_cosmetics WHERE user_id = @u:uuid AND item_id = @i'),
        parameters: {'u': userId, 'i': item.id},
      );
      if (owned.isNotEmpty || item.isFree) throw const PurchaseException(PurchaseError.alreadyOwned);
      final gems = item.currency == Currency.gems;
      final balance = (gems ? w.first[1] : w.first[0]) as int;
      if (balance < item.price) {
        throw PurchaseException(gems ? PurchaseError.insufficientGems : PurchaseError.insufficientCoins);
      }
      await _credit(tx, userId, gems ? 'gems' : 'coins', -item.price, 'purchase', 'item:${item.id}', requestId: requestId);
      await tx.execute(
        Sql.named('INSERT INTO owned_cosmetics (user_id, item_id) VALUES (@u:uuid, @i)'),
        parameters: {'u': userId, 'i': item.id},
      );
    });
    return (await findById(userId))!;
  }

  @override
  Future<PlayerAccount> equip(String userId, CosmeticDef item) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO equipped_cosmetics (user_id, slot, item_id) VALUES (@u:uuid, @s, @i)
        ON CONFLICT (user_id, slot) DO UPDATE SET item_id = EXCLUDED.item_id'''),
      parameters: {'u': userId, 's': item.slot.name, 'i': item.id},
    );
    return (await findById(userId))!;
  }

  // ---- daily reward ----------------------------------------------------------------

  static String _date(DateTime d) => DateTime.utc(d.year, d.month, d.day).toIso8601String().substring(0, 10);

  Future<DailyStatus> _status(Session s, String userId, DateTime today, {bool lock = false}) async {
    final rows = await s.execute(
      Sql.named('SELECT last_day, streak FROM daily_rewards WHERE user_id = @u:uuid${lock ? ' FOR UPDATE' : ''}'),
      parameters: {'u': userId},
    );
    if (rows.isEmpty) return DailyStatus.compute(null, 0, today);
    final last = rows.first[0] as DateTime;
    return DailyStatus.compute(DateTime.utc(last.year, last.month, last.day), rows.first[1] as int, today);
  }

  @override
  Future<DailyStatus> dailyStatus(String userId, DateTime today) => _db.run((s) => _status(s, userId, today));

  @override
  Future<(PlayerAccount, DailyStatus)> claimDaily(String userId, DateTime today) async {
    final st = await _db.runTx((tx) async {
      // Lock the wallet first, like purchases, so claims serialise.
      await tx.execute(Sql.named('SELECT 1 FROM wallets WHERE user_id = @u:uuid FOR UPDATE'), parameters: {'u': userId});
      final st = await _status(tx, userId, today, lock: true);
      if (!st.available) throw const DailyClaimedException();
      final day = _date(today);
      await tx.execute(
        Sql.named('''
          INSERT INTO daily_rewards (user_id, last_day, streak) VALUES (@u:uuid, @d:date, @s)
          ON CONFLICT (user_id) DO UPDATE SET last_day = EXCLUDED.last_day, streak = EXCLUDED.streak'''),
        parameters: {'u': userId, 'd': DateTime.utc(today.year, today.month, today.day), 's': st.streak},
      );
      // The unique (user_id, request_id) index makes a second credit for the same day impossible.
      await _credit(tx, userId, 'coins', st.coins, 'daily_reward', 'daily:$day', requestId: 'daily-$day');
      if (st.gems > 0) await _credit(tx, userId, 'gems', st.gems, 'daily_reward', 'daily:$day', requestId: 'daily-gems-$day');
      return DailyStatus(available: false, streak: st.streak, coins: st.coins, gems: st.gems);
    });
    return ((await findById(userId))!, st);
  }

  // ---- leaderboards & history ----------------------------------------------------

  Future<List<PlayerAccount>> _many(String tail, int limit) async {
    final rows = await _db.execute(Sql.named('$_accountSelect $tail LIMIT @lim'), parameters: {'lim': limit});
    return [for (final r in rows) _toAccount(r.toColumnMap())];
  }

  @override
  Future<List<PlayerAccount>> topByCoins(int limit) =>
      _many("WHERE u.status = 'active' ORDER BY s.total_coins DESC, s.wins DESC", limit);

  @override
  Future<List<PlayerAccount>> topToday(int limit) =>
      _many("WHERE u.status = 'active' AND d.user_id IS NOT NULL ORDER BY d.wins DESC, d.coins DESC", limit);

  @override
  Future<List<MatchHistoryEntry>> matchHistory(String userId, {int limit = 20}) async {
    final rows = await _db.execute(
      Sql.named('''
        SELECT m.id, m.map_id, m.mode, m.ended_at, m.player_count, m.winner_name,
               mp.rank, mp.score, mp.max_depth, mp.found_treasure, mp.coins_awarded, mp.gems_awarded
          FROM match_players mp JOIN matches m ON m.id = mp.match_id
         WHERE mp.user_id = @u:uuid
         ORDER BY m.ended_at DESC LIMIT @lim'''),
      parameters: {'u': userId, 'lim': limit},
    );
    return [
      for (final row in rows)
        () {
          final r = row.toColumnMap();
          return MatchHistoryEntry(
            matchId: r['id'] as String,
            mapId: r['map_id'] as String,
            mode: r['mode'] as String,
            endedAt: r['ended_at'] as DateTime,
            rank: r['rank'] as int,
            score: r['score'] as int,
            maxDepth: r['max_depth'] as int,
            foundTreasure: r['found_treasure'] as bool,
            playerCount: r['player_count'] as int,
            winnerName: r['winner_name'] as String?,
            coinsAwarded: r['coins_awarded'] as int,
            gemsAwarded: r['gems_awarded'] as int,
          );
        }(),
    ];
  }

  @override
  Future<List<WalletTransaction>> transactions(String userId, {int limit = 30}) async {
    final rows = await _db.execute(
      Sql.named('''
        SELECT id, kind, currency, amount, balance_after, reference, created_at
          FROM transactions WHERE user_id = @u:uuid ORDER BY id DESC LIMIT @lim'''),
      parameters: {'u': userId, 'lim': limit},
    );
    return [
      for (final row in rows)
        () {
          final r = row.toColumnMap();
          return WalletTransaction(
            id: r['id'] as int,
            kind: r['kind'] as String,
            currency: r['currency'] as String,
            amount: r['amount'] as int,
            balanceAfter: r['balance_after'] as int,
            reference: r['reference'] as String?,
            createdAt: r['created_at'] as DateTime,
          );
        }(),
    ];
  }
}
