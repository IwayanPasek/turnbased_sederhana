// lib/screens/inventory_screen.dart
import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/rarity_badge.dart';
import '../../screens/shop/item_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ShopService _shopService = ShopService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _inventory = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'weapon':
        return Icons.flash_on;
      case 'armor':
        return Icons.shield;
      case 'accessory':
        return Icons.favorite;
      default:
        return Icons.extension;
    }
  }

  bool _isWrath(Map<String, dynamic> inv) {
    final name = (inv['name'] ?? '').toString().toLowerCase();
    return name.contains('wrath') && name.contains('cow');
  }

  String _formatNumber(dynamic n) {
    if (n == null) return '0';
    final val = (n is int) ? n : int.tryParse(n.toString()) ?? 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toString();
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return AppColors.accent;
      case 'rare':
        return AppColors.primary;
      case 'epic':
        return AppColors.primaryDark;
      case 'legendary':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final items = await _shopService.fetchInventory();
      if (!mounted) return;
      setState(() {
        _inventory = items ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat inventaris';
        _isLoading = false;
      });
    }
  }

  Future<void> _onUpgrade(Map<String, dynamic> invItem) async {
    final currentLevel = invItem['current_level'] as int? ?? 1;
    final maxLevel = invItem['max_level'] as int? ?? 1;
    if (currentLevel >= maxLevel) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sudah level maksimal')));
      return;
    }

    // Get next level cost
    final shopItemId = invItem['shop_item_id'] as int;
    final details = await _shopService.fetchItemDetails(shopItemId);
    final upgradeCosts = details?['upgrade_costs'] as List<dynamic>?;
    final nextLevel = currentLevel + 1;
    dynamic costEntry;
    if (upgradeCosts != null) {
      costEntry = upgradeCosts.firstWhere(
        (e) => e['level'] == nextLevel,
        orElse: () => null,
      );
    }

    final coins = costEntry != null ? (costEntry['cost_coins'] ?? 0) : 0;
    final gems = costEntry != null ? (costEntry['cost_gems'] ?? 0) : 0;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Upgrade'),
        content: Text(
          'Upgrade ke level $nextLevel? Biaya: $coins koin ${gems > 0 ? ' & $gems gems' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final resp = await _shopService.upgradeItem(invItem['id'] as int);
    if (!mounted) return;
    
    if (resp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? 'Upgrade berhasil')),
      );
      await _loadInventory();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal upgrade')));
    }
  }

  Future<void> _onEquip(Map<String, dynamic> invItem) async {
    final resp = await _shopService.equipItem(invItem['id'] as int);
    if (!mounted) return;
    
    if (resp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? 'Berhasil dilengkapi')),
      );
      await _loadInventory();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal melengkapi item')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventaris')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgDark, AppColors.primaryDark.withValues(alpha: 0.2)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
            ? Center(
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              )
            : RefreshIndicator(
                onRefresh: _loadInventory,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _inventory.length,
                  itemBuilder: (context, index) {
                    final inv = _inventory[index];
                    final shopName =
                        inv['name'] ??
                        inv['shop_item_id']?.toString() ??
                        'Item';
                    final level = inv['current_level'] ?? 1;
                    final maxLevel = inv['max_level'] ?? 1;
                    final equipped = inv['is_equipped'] == true || inv['is_equipped'] == 1;

                    final itemType = (inv['item_type'] ?? 'weapon').toString();
                    final rarity = (inv['rarity'] ?? 'common').toString();

                    return InkWell(
                      onTap: () async {
                        final item = {
                          'id': inv['shop_item_id'],
                          'name': inv['name'],
                          'description': inv['description'],
                          'item_type': inv['item_type'],
                          'rarity': inv['rarity'],
                          'base_stat': inv['base_stat'],
                          'max_level': inv['max_level'],
                        };

                        final route = PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ItemDetailScreen(item: item),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                final fade = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                );
                                final offset = Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(fade);
                                return FadeTransition(
                                  opacity: fade,
                                  child: SlideTransition(
                                    position: offset,
                                    child: child,
                                  ),
                                );
                              },
                          transitionDuration: const Duration(milliseconds: 360),
                        );

                        final changed = await Navigator.of(context).push(route);
                        if (changed == true) await _loadInventory();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        color: AppColors.bgCard,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Icon
                              Hero(
                                tag: 'item-icon-${inv['shop_item_id']}',
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        _rarityColor(rarity).withValues(alpha: 0.9),
                                        AppColors.primaryDark,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _rarityColor(
                                          rarity,
                                        ).withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: _isWrath(inv)
                                      ? const Center(
                                          child: Text('🐄',
                                              style: TextStyle(fontSize: 34)),
                                        )
                                      : Center(
                                          child: Icon(
                                            _typeIcon(itemType),
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Hero(
                                          tag:
                                              'item-title-${inv['shop_item_id']}',
                                          child: Material(
                                            color: Colors.transparent,
                                            child: Text(
                                              shopName,
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        RarityBadge(
                                          rarity: rarity,
                                          isSpecial: _isWrath(inv),
                                        ),
                                      ],
                                    ),
                                      const SizedBox(height: 6),
                                      if (inv['granted_skill'] != null && inv['granted_skill'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Skill: ${inv['granted_skill']}',
                                                style: const TextStyle(
                                                  color: AppColors.accent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    Text(
                                      'Level: $level / ${_formatNumber(maxLevel)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Progress bar for level
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value:
                                            (level /
                                                    (maxLevel == 0
                                                        ? 1
                                                        : maxLevel))
                                                .toDouble(),
                                        minHeight: 8,
                                        backgroundColor: AppColors.border,
                                        valueColor: AlwaysStoppedAnimation(
                                          _rarityColor(rarity),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (equipped)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'TERPASANG',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Actions
                              Column(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: ElevatedButton.icon(
                                        onPressed: equipped ? null : () => _onEquip(inv),
                                        icon: Icon(equipped ? Icons.check_circle : Icons.check),
                                        label: Text(equipped ? 'Terpasang' : 'Pasang'),
                                        style: ElevatedButton.styleFrom(
                                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                                          disabledForegroundColor: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 120,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _onUpgrade(inv),
                                        icon: const Icon(Icons.upgrade),
                                        label: const Text('Upgrade'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
