import 'package:mad_miners_core/mad_miners_core.dart';

import '../domain/entities/player_account.dart';
import '../domain/repositories/account_repository.dart';
import 'app_exception.dart';

/// Cosmetic store. Every purchase is validated and applied on the server,
/// atomically, and is idempotent per `requestId` (SRS FR-038, §11.3).
class StoreService {
  StoreService(this._accounts);
  final AccountRepository _accounts;

  static const _maxRemembered = 100;

  List<Map<String, dynamic>> catalog() => [
    for (final c in cosmeticCatalog)
      {
        'id': c.id,
        'slot': c.slot.name,
        'name': c.name,
        'price': c.price,
        'currency': c.currency.name,
        'premium': c.isPremium,
      },
  ];

  Future<PlayerAccount> purchase(PlayerAccount acc, String itemId, String requestId) async {
    if (requestId.isEmpty || requestId.length > 64) {
      throw AppException.badRequest('INVALID_REQUEST_ID', 'A requestId is required.');
    }
    // A retry of a request we already handled: return the same outcome.
    if (acc.processedRequests.contains(requestId)) return acc;

    final item = cosmeticsById[itemId] ?? (throw AppException.notFound('Item'));
    if (acc.ownsItem(item.id)) throw AppException.conflict('ALREADY_OWNED', 'You already own ${item.name}.');

    switch (item.currency) {
      case Currency.coins:
        if (acc.wallet < item.price) throw AppException.badRequest('INSUFFICIENT_COINS', 'Not enough coins.');
        acc.wallet -= item.price;
      case Currency.gems:
        if (acc.gems < item.price) throw AppException.badRequest('INSUFFICIENT_GEMS', 'Not enough gems.');
        acc.gems -= item.price;
    }
    acc.owned.add(item.id);
    acc.processedRequests.add(requestId);
    if (acc.processedRequests.length > _maxRemembered) acc.processedRequests.removeAt(0);
    await _accounts.save(acc);
    return acc;
  }

  Future<PlayerAccount> equip(PlayerAccount acc, String itemId) async {
    final item = cosmeticsById[itemId] ?? (throw AppException.notFound('Item'));
    if (!acc.ownsItem(item.id)) throw const AppException(403, 'NOT_OWNED', 'Buy this item first.');
    acc.look = acc.look.withItem(item);
    await _accounts.save(acc);
    return acc;
  }
}
