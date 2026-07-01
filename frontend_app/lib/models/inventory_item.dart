// lib/models/inventory_item.dart

class InventoryItem {
  final int inventoryId;
  final int shopItemId;
  final String name;
  final String itemType;
  final String description;
  final String rarity;
  final int baseStat;
  final String statType;
  final int currentLevel;
  final int maxLevel;
  final bool isEquipped;
  final String? equippedSlot;
  final int quantity;
  final int baseCostCoins;
  final int baseCostGems;

  const InventoryItem({
    required this.inventoryId,
    required this.shopItemId,
    required this.name,
    required this.itemType,
    required this.description,
    required this.rarity,
    required this.baseStat,
    required this.statType,
    required this.currentLevel,
    required this.maxLevel,
    required this.isEquipped,
    this.equippedSlot,
    required this.quantity,
    required this.baseCostCoins,
    required this.baseCostGems,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        inventoryId:   (json['id'] as num?)?.toInt() ?? (json['inventory_id'] as num?)?.toInt() ?? 0,
        shopItemId:    (json['shop_item_id'] as num?)?.toInt() ?? (json['si_item_id'] as num?)?.toInt() ?? 0,
        name:          json['name'] as String? ?? '',
        itemType:      json['item_type'] as String? ?? '',
        description:   json['description'] as String? ?? '',
        rarity:        json['rarity'] as String? ?? 'common',
        baseStat:      (json['base_stat'] as num?)?.toInt() ?? 0,
        statType:      json['stat_type'] as String? ?? '',
        currentLevel:  (json['current_level'] as num?)?.toInt() ?? 1,
        maxLevel:      (json['max_level'] as num?)?.toInt() ?? 5,
        isEquipped:    (json['is_equipped'] as bool?) ?? false,
        equippedSlot:  json['equipped_slot'] as String?,
        quantity:      (json['quantity'] as num?)?.toInt() ?? 1,
        baseCostCoins: (json['base_cost_coins'] as num?)?.toInt() ?? 0,
        baseCostGems:  (json['base_cost_gems'] as num?)?.toInt() ?? 0,
      );

  int get effectiveStat => baseStat + ((currentLevel - 1) * 5);
  bool get isMaxLevel => currentLevel >= maxLevel;
}
