import 'dart:math';

/// Locker catalog. Characters, outfits and helmets are looks only.
/// Pickaxes are real gear: each one has a [CosmeticDef.power] that sets the
/// pickaxe level you start every match with.
enum CosmeticSlot {
  character('Miner'),
  outfit('Outfit'),
  helmet('Helmet'),
  pickaxe('Pickaxe');

  const CosmeticSlot(this.label);
  final String label;
}

/// Coins are earned by playing; gems are the premium currency
/// (earned by finding treasures, later purchasable in-app).
enum Currency { coins, gems }

class CosmeticDef {
  const CosmeticDef({
    required this.id,
    required this.slot,
    required this.name,
    required this.price,
    required this.currency,
    required this.primary,
    required this.secondary,
    this.style = 0,
    this.description = '',
    this.power = 0,
  });

  final String id;
  final CosmeticSlot slot;
  final String name;

  /// 0 = free / owned by everyone.
  final int price;
  final Currency currency;

  /// ARGB colours used by the renderer (character: skin, hair).
  final int primary;
  final int secondary;

  /// Shape variant. Character: face style. Helmet: 0 hard hat, 1 crown,
  /// 2 viking, 3 prospector hat, 4 beanie. Pickaxe: see [PickStyle].
  final int style;
  final String description;

  /// Pickaxes only: the in-match pickaxe level (index into the pickaxe
  /// upgrade track) you start with. 0 = Basic Pickaxe.
  final int power;

  bool get isFree => price == 0;
  bool get isPremium => currency == Currency.gems && price > 0;
}

/// Pickaxe head shapes.
abstract final class PickStyle {
  static const pick = 0;
  static const axe = 1;
  static const drill = 2;
  static const mattock = 3;
}

/// Character face styles.
abstract final class Face {
  static const rookie = 0;
  static const ponytail = 1;
  static const beard = 2;
  static const goggles = 3;
  static const ninja = 4;
  static const robot = 5;
  static const mole = 6;
  static const skeleton = 7;
}

const List<CosmeticDef> cosmeticCatalog = [
  // Characters (the miner themselves).
  CosmeticDef(id: 'char_rookie', slot: CosmeticSlot.character, name: 'Rookie', price: 0, currency: Currency.coins, primary: 0xFFF1C27D, secondary: 0xFF4A2F1B, style: Face.rookie, description: 'Fresh out of mining school.'),
  CosmeticDef(id: 'char_maya', slot: CosmeticSlot.character, name: 'Maya', price: 0, currency: Currency.coins, primary: 0xFFE0AC69, secondary: 0xFF2B1B12, style: Face.ponytail, description: 'Fast hands, faster feet.'),
  CosmeticDef(id: 'char_bahadur', slot: CosmeticSlot.character, name: 'Old Bahadur', price: 400, currency: Currency.coins, primary: 0xFFC68642, secondary: 0xFFE8E4DC, style: Face.beard, description: 'Forty years underground.'),
  CosmeticDef(id: 'char_tinker', slot: CosmeticSlot.character, name: 'Tinker', price: 650, currency: Currency.coins, primary: 0xFFFFDBAC, secondary: 0xFFB5651D, style: Face.goggles, description: 'Brass goggles, big ideas.'),
  CosmeticDef(id: 'char_shadow', slot: CosmeticSlot.character, name: 'Shadow', price: 900, currency: Currency.coins, primary: 0xFF8D5524, secondary: 0xFF1A1A22, style: Face.ninja, description: 'Digs in silence.'),
  CosmeticDef(id: 'char_bolt', slot: CosmeticSlot.character, name: 'Bolt-9', price: 1500, currency: Currency.coins, primary: 0xFFB8C4D0, secondary: 0xFF2FD4C4, style: Face.robot, description: 'Built for the deep.'),
  CosmeticDef(id: 'char_mole', slot: CosmeticSlot.character, name: 'Mr. Mole', price: 120, currency: Currency.gems, primary: 0xFF6B4E3D, secondary: 0xFFFF8FA3, style: Face.mole, description: 'Born to dig.'),
  CosmeticDef(id: 'char_bones', slot: CosmeticSlot.character, name: 'Bones', price: 160, currency: Currency.gems, primary: 0xFFEDE6D6, secondary: 0xFF1A1A1A, style: Face.skeleton, description: 'Never left the mine.'),
  // Outfits.
  CosmeticDef(id: 'outfit_orange', slot: CosmeticSlot.outfit, name: 'Classic Overalls', price: 0, currency: Currency.coins, primary: 0xFFE8742A, secondary: 0xFF2E3A59),
  CosmeticDef(id: 'outfit_denim', slot: CosmeticSlot.outfit, name: 'Denim Digger', price: 0, currency: Currency.coins, primary: 0xFF3E6FB0, secondary: 0xFF23324D),
  CosmeticDef(id: 'outfit_forest', slot: CosmeticSlot.outfit, name: 'Forest Ranger', price: 250, currency: Currency.coins, primary: 0xFF3F8F4A, secondary: 0xFF3B2A1A),
  CosmeticDef(id: 'outfit_plaid', slot: CosmeticSlot.outfit, name: 'Red Plaid', price: 400, currency: Currency.coins, primary: 0xFFC0392B, secondary: 0xFF2C2C2C),
  CosmeticDef(id: 'outfit_purple', slot: CosmeticSlot.outfit, name: 'Royal Purple', price: 650, currency: Currency.coins, primary: 0xFF7B4FD6, secondary: 0xFF2A1F45),
  CosmeticDef(id: 'outfit_mint', slot: CosmeticSlot.outfit, name: 'Mint Runner', price: 800, currency: Currency.coins, primary: 0xFF34D399, secondary: 0xFF134E4A),
  CosmeticDef(id: 'outfit_gold', slot: CosmeticSlot.outfit, name: 'Golden Suit', price: 60, currency: Currency.gems, primary: 0xFFFFC93C, secondary: 0xFF8A5A00),
  CosmeticDef(id: 'outfit_ice', slot: CosmeticSlot.outfit, name: 'Ice Crystal', price: 80, currency: Currency.gems, primary: 0xFF8BE0FF, secondary: 0xFF2B5C8A),
  CosmeticDef(id: 'outfit_lava', slot: CosmeticSlot.outfit, name: 'Magma Armor', price: 120, currency: Currency.gems, primary: 0xFFFF5A1F, secondary: 0xFF2A0F08),
  // Helmets.
  CosmeticDef(id: 'helmet_yellow', slot: CosmeticSlot.helmet, name: 'Hard Hat', price: 0, currency: Currency.coins, primary: 0xFFFFC53D, secondary: 0xFFFFF7D1),
  CosmeticDef(id: 'helmet_white', slot: CosmeticSlot.helmet, name: 'Foreman White', price: 150, currency: Currency.coins, primary: 0xFFF2F2F2, secondary: 0xFFFFF7D1),
  CosmeticDef(id: 'helmet_red', slot: CosmeticSlot.helmet, name: 'Fire Red', price: 200, currency: Currency.coins, primary: 0xFFE53935, secondary: 0xFFFFF7D1),
  CosmeticDef(id: 'helmet_beanie', slot: CosmeticSlot.helmet, name: 'Cozy Beanie', price: 300, currency: Currency.coins, primary: 0xFF2563EB, secondary: 0xFFF8FAFC, style: 4),
  CosmeticDef(id: 'helmet_cowboy', slot: CosmeticSlot.helmet, name: 'Prospector Hat', price: 500, currency: Currency.coins, primary: 0xFF8B5A2B, secondary: 0xFF5A3A1A, style: 3),
  CosmeticDef(id: 'helmet_viking', slot: CosmeticSlot.helmet, name: 'Viking Helm', price: 70, currency: Currency.gems, primary: 0xFFB0B7C0, secondary: 0xFFF5E6C8, style: 2),
  CosmeticDef(id: 'helmet_crown', slot: CosmeticSlot.helmet, name: 'Miner King Crown', price: 150, currency: Currency.gems, primary: 0xFFFFD34D, secondary: 0xFFE0115F, style: 1),
  // Pickaxes: real gear. You start each match at the pickaxe's power level.
  CosmeticDef(id: 'pick_wood', slot: CosmeticSlot.pickaxe, name: 'Trusty Pick', price: 0, currency: Currency.coins, primary: 0xFF8B5A2B, secondary: 0xFFC9D1D9, description: 'Gets the job done. Slowly.'),
  CosmeticDef(id: 'pick_steel', slot: CosmeticSlot.pickaxe, name: 'Steel Pick', price: 300, currency: Currency.coins, primary: 0xFF4A4A4A, secondary: 0xFFE6EEF5, power: 1, description: 'Double damage from the first swing.'),
  CosmeticDef(id: 'pick_ruby', slot: CosmeticSlot.pickaxe, name: 'Ruby Pick', price: 900, currency: Currency.coins, primary: 0xFF5A2A1A, secondary: 0xFFE0115F, power: 2, description: 'Cuts rock like butter.'),
  CosmeticDef(id: 'pick_emerald', slot: CosmeticSlot.pickaxe, name: 'Emerald Mattock', price: 1400, currency: Currency.coins, primary: 0xFF1F3A2A, secondary: 0xFF34D399, style: PickStyle.mattock, power: 2, description: 'Wide blade, heavy swing.'),
  CosmeticDef(id: 'pick_titan', slot: CosmeticSlot.pickaxe, name: 'Titan Axe', price: 2600, currency: Currency.coins, primary: 0xFF2E2E36, secondary: 0xFFFF9F1C, style: PickStyle.axe, power: 3, description: 'Two blades. Splits hard rock.'),
  CosmeticDef(id: 'pick_drill', slot: CosmeticSlot.pickaxe, name: 'Thunder Drill', price: 6000, currency: Currency.coins, primary: 0xFF3A3F4A, secondary: 0xFFFFD34D, style: PickStyle.drill, power: 4, description: 'Motorised. The fastest digger money can buy.'),
  CosmeticDef(id: 'pick_gold', slot: CosmeticSlot.pickaxe, name: 'Golden Pick', price: 60, currency: Currency.gems, primary: 0xFF8A5A00, secondary: 0xFFFFD34D, power: 2, description: 'Shiny and sharp.'),
  CosmeticDef(id: 'pick_crystal', slot: CosmeticSlot.pickaxe, name: 'Crystal Pick', price: 120, currency: Currency.gems, primary: 0xFF2B5C8A, secondary: 0xFF8AF0FF, power: 3, description: 'Harder than diamond.'),
  CosmeticDef(id: 'pick_plasma', slot: CosmeticSlot.pickaxe, name: 'Plasma Drill', price: 300, currency: Currency.gems, primary: 0xFF1C1630, secondary: 0xFFB06BFF, style: PickStyle.drill, power: 4, description: 'Glowing bit, top dig power.'),
];

final Map<String, CosmeticDef> cosmeticsById = {for (final c in cosmeticCatalog) c.id: c};

CosmeticDef defaultCosmetic(CosmeticSlot slot) => cosmeticCatalog.firstWhere((c) => c.slot == slot && c.isFree);

/// What a miner is wearing.
class Look {
  const Look({
    this.character = 'char_rookie',
    this.outfit = 'outfit_orange',
    this.helmet = 'helmet_yellow',
    this.pickaxe = 'pick_wood',
  });

  static const standard = Look();

  final String character;
  final String outfit;
  final String helmet;
  final String pickaxe;

  String of(CosmeticSlot slot) => switch (slot) {
    CosmeticSlot.character => character,
    CosmeticSlot.outfit => outfit,
    CosmeticSlot.helmet => helmet,
    CosmeticSlot.pickaxe => pickaxe,
  };

  Look withItem(CosmeticDef c) => Look(
    character: c.slot == CosmeticSlot.character ? c.id : character,
    outfit: c.slot == CosmeticSlot.outfit ? c.id : outfit,
    helmet: c.slot == CosmeticSlot.helmet ? c.id : helmet,
    pickaxe: c.slot == CosmeticSlot.pickaxe ? c.id : pickaxe,
  );

  CosmeticDef def(CosmeticSlot slot) => cosmeticsById[of(slot)] ?? defaultCosmetic(slot);

  /// Drops unknown ids (e.g. from an old client) back to defaults.
  Look sanitized() {
    String ok(String id, CosmeticSlot slot) => cosmeticsById[id]?.slot == slot ? id : defaultCosmetic(slot).id;
    return Look(
      character: ok(character, CosmeticSlot.character),
      outfit: ok(outfit, CosmeticSlot.outfit),
      helmet: ok(helmet, CosmeticSlot.helmet),
      pickaxe: ok(pickaxe, CosmeticSlot.pickaxe),
    );
  }

  List<String> toJson() => [outfit, helmet, pickaxe, character];

  factory Look.fromJson(Object? j) {
    if (j is! List || j.length < 3) return standard;
    return Look(
      outfit: j[0] as String,
      helmet: j[1] as String,
      pickaxe: j[2] as String,
      character: j.length > 3 ? j[3] as String : standard.character,
    ).sanitized();
  }

  /// From `slot -> itemId` rows (database).
  factory Look.fromSlots(Map<String, String> slots) => Look(
    character: slots['character'] ?? standard.character,
    outfit: slots['outfit'] ?? standard.outfit,
    helmet: slots['helmet'] ?? standard.helmet,
    pickaxe: slots['pickaxe'] ?? standard.pickaxe,
  ).sanitized();

  /// Random look for a bot — mostly free/coin items, sometimes premium.
  factory Look.random(Random rng) {
    String pick(CosmeticSlot slot) {
      var items = cosmeticCatalog.where((c) => c.slot == slot).toList();
      if (slot == CosmeticSlot.pickaxe) {
        // Most players haven't saved up for a drill yet.
        final cap = rng.nextDouble() < 0.8 ? 1 : 3;
        items = items.where((c) => c.power <= cap).toList();
      }
      final premium = rng.nextDouble() < 0.15;
      final pool = items.where((c) => c.isPremium == premium).toList();
      final from = pool.isEmpty ? items : pool;
      return from[rng.nextInt(from.length)].id;
    }

    return Look(
      character: pick(CosmeticSlot.character),
      outfit: pick(CosmeticSlot.outfit),
      helmet: pick(CosmeticSlot.helmet),
      pickaxe: pick(CosmeticSlot.pickaxe),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Look && other.character == character && other.outfit == outfit && other.helmet == helmet && other.pickaxe == pickaxe;

  @override
  int get hashCode => Object.hash(character, outfit, helmet, pickaxe);
}
