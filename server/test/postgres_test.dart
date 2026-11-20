// Integration test against a real PostgreSQL (database: mad_miners_test).
// Skipped automatically if it can't connect.
import 'dart:io';

import 'package:mad_miners_core/mad_miners_core.dart';
import 'package:mad_miners_server/mad_miners_server.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

String get _url =>
    Platform.environment['TEST_DATABASE_URL'] ??
    'postgresql://${Platform.environment['USER'] ?? 'postgres'}@localhost:5432/mad_miners_test?sslmode=disable';

Future<bool> _reset() async {
  try {
    final c = await Connection.openFromUrl(_url);
    await c.execute('DROP SCHEMA public CASCADE');
    await c.execute('CREATE SCHEMA public');
    await c.close();
    return true;
  } catch (_) {
    return false;
  }
}

void main() async {
  final available = await _reset();
  late PostgresAccountRepository repo;

  setUpAll(() async {
    if (available) repo = await PostgresAccountRepository.open(_url, migrationsDir: 'database/migrations');
  });
  tearDownAll(() async {
    if (available) await repo.close();
  });

  test('full account lifecycle in PostgreSQL', skip: available ? false : 'PostgreSQL not reachable', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final acc = await repo.createUser(id: id, username: 'DbMiner', identity: const Identity('guest', id));
    expect(acc.coins, 0);
    expect(await repo.usernameTaken('dbminer'), isTrue, reason: 'case-insensitive');

    await repo.createSession(id, 'a' * 64, DateTime.now().add(const Duration(days: 1)));
    expect((await repo.findBySession('a' * 64))!.id, id);
    await repo.createSession(id, 'b' * 64, DateTime.now().subtract(const Duration(days: 1)));
    expect(await repo.findBySession('b' * 64), isNull, reason: 'expired session');

    const r = PlayerResult(playerId: id, name: 'DbMiner', isBot: false, team: -1, rank: 1, score: 720, oresMined: 14, xp: 300, maxDepth: 48);
    await repo.recordMatch(MatchRecord(
      id: '22222222-2222-4222-8222-222222222222',
      roomCode: 'MMDB01',
      mapId: MapId.lavaMine,
      mode: GameMode.treasureHunt,
      startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      durationSeconds: 180,
      playerCount: 8,
      winnerUserId: id,
      winnerName: 'DbMiner',
      players: [MatchPlayerRecord(userId: id, result: r, foundTreasure: true, reward: Reward.forResult(r, foundTreasure: true))],
    ));
    var a = (await repo.findById(id))!;
    expect(a.coins, 720);
    expect(a.gems, 10);
    expect(a.stats.wins, 1);
    expect(a.stats.bestDepth, 48);
    expect(a.todayWins, 1);
    expect((await repo.topToday(5)).first.id, id);
    expect((await repo.matchHistory(id)).single.mapId, 'lavaMine');

    // Purchases: atomic, idempotent, balance can't go negative.
    a = await repo.purchase(id, cosmeticsById['char_bahadur']!, 'req-1');
    a = await repo.purchase(id, cosmeticsById['char_bahadur']!, 'req-1');
    expect(a.coins, 320);
    expect(a.owned, contains('char_bahadur'));
    await expectLater(repo.purchase(id, cosmeticsById['char_bolt']!, 'req-2'), throwsA(isA<PurchaseException>()));
    a = await repo.equip(id, cosmeticsById['char_bahadur']!);
    expect(a.look.character, 'char_bahadur');

    final tx = await repo.transactions(id);
    expect(tx.map((t) => t.kind), containsAll(['match_reward', 'purchase']));
    expect(tx.first.balanceAfter, 320);
  });
}
