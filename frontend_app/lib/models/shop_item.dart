// lib/models/shop_item.dart

class ShopItem {
  final int id;
  final String name;
  final String itemType;
  final String description;
  final int baseStat;
  final String statType;
  final int baseCostCoins;
  final int baseCostGems;
  final String rarity;
  final bool isUpgradeable;
  final int maxLevel;
  final String? iconUrl;
  final bool isActive;

  const ShopItem({
    required this.id,
    required this.name,
    required this.itemType,
    required this.description,
    required this.baseStat,
    required this.statType,
    required this.baseCostCoins,
    required this.baseCostGems,
    required this.rarity,
    required this.isUpgradeable,
    required this.maxLevel,
    this.iconUrl,
    required this.isActive,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id:            (json['id'] as num?)?.toInt() ?? (json['item_id'] as num?)?.toInt() ?? 0,
        name:          json['name'] as String? ?? json['item_name'] as String? ?? '',
        itemType:      json['item_type'] as String? ?? '',
        description:   json['description'] as String? ?? '',
        baseStat:      (json['base_stat'] as num?)?.toInt() ?? (json['base_stat_boost'] as num?)?.toInt() ?? 0,
        statType:      json['stat_type'] as String? ?? '',
        baseCostCoins: (json['base_cost_coins'] as num?)?.toInt() ?? 0,
        baseCostGems:  (json['base_cost_gems'] as num?)?.toInt() ?? 0,
        rarity:        json['rarity'] as String? ?? 'common',
        isUpgradeable: (json['is_upgradeable'] as bool?) ?? true,
        maxLevel:      (json['max_level'] as num?)?.toInt() ?? 5,
        iconUrl:       json['icon_url'] as String?,
        isActive:      (json['is_active'] as bool?) ?? true,
      );
}
