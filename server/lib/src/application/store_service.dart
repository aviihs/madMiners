import 'package:mad_miners_core/mad_miners_core.dart';

import '../domain/entities/player_account.dart';
import '../domain/repositories/account_repository.dart';
import 'app_exception.dart';

/// Cosmetic store. Purchases are validated and applied in the database,
/// atomically and idempotently per `requestId` (SRS FR-038, §11.3).
class StoreService {
  StoreService(this._accounts);
  final AccountRepository _accounts;

  List<Map<String, dynamic>> catalog() => [
    for (final c in cosmeticCatalog)
      {
        'id': c.id,
        'slot': c.slot.name,
        'name': c.name,
        'price': c.price,
        'currency': c.currency.name,
        'premium': c.isPremium,
        'description': c.description,
        if (c.slot == CosmeticSlot.pickaxe) 'power': c.power,
      },
  ];

  Future<PlayerAccount> purchase(PlayerAccount acc, String itemId, String requestId) async {
    if (requestId.isEmpty || requestId.length > 64) {
      throw AppException.badRequest('INVALID_REQUEST_ID', 'A requestId is required.');
    }
    final item = cosmeticsById[itemId] ?? (throw AppException.notFound('Item'));
    try {
      return await _accounts.purchase(acc.id, item, requestId);
    } on PurchaseException catch (e) {
      throw switch (e.error) {
        PurchaseError.alreadyOwned => AppException.conflict('ALREADY_OWNED', 'You already own ${item.name}.'),
        PurchaseError.insufficientCoins => AppException.badRequest('INSUFFICIENT_COINS', 'Not enough coins.'),
        PurchaseError.insufficientGems => AppException.badRequest('INSUFFICIENT_GEMS', 'Not enough gems.'),
      };
    }
  }

  Future<PlayerAccount> equip(PlayerAccount acc, String itemId) async {
    final item = cosmeticsById[itemId] ?? (throw AppException.notFound('Item'));
    if (!acc.ownsItem(item.id)) throw const AppException(403, 'NOT_OWNED', 'Buy this item first.');
    return _accounts.equip(acc.id, item);
  }
}
