// lib/screens/inventory_screen.dart
import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/rarity_badge.dart';
import '../../widgets/mobile_glass_card.dart';
import '../../screens/shop/item_detail_screen.dart';
import '../../providers/profile_provider.dart';

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

  Future<void> _loadInventory({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final items = await _shopService.fetchInventory();
      if (!mounted) return;
      setState(() {
        _inventory = items ?? [];
        if (showLoading) _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat inventaris';
        if (showLoading) _isLoading = false;
      });
    }
  }

  Future<void> _onUpgrade(Map<String, dynamic> invItem) async {
    final currentLevel = invItem['current_level'] as int? ?? 1;
    final maxLevel = invItem['max_level'] as int? ?? 1;
    if (currentLevel >= maxLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sudah level maksimal')),
      );
      return;
    }

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

    // BUG-5: Blokir upgrade gratis jika biaya tidak ada di DB
    if (costEntry == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data biaya upgrade tidak ditemukan. Hubungi admin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upgrade, size: 64, color: AppColors.accent),
              const SizedBox(height: 16),
              const Text(
                'Konfirmasi Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tingkatkan item ke Level $nextLevel?',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text('$coins Koin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (gems > 0) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.diamond, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('$gems Gems', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final resp = await _shopService.upgradeItem(invItem['id'] as int);
    if (!mounted) return;

    if (resp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? 'Upgrade berhasil')),
      );
      await _loadInventory(showLoading: false);
      // Update global profile stats (coins/gems) efficiently
      profileNotifier.load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal upgrade')),
      );
    }
  }

  Future<void> _onEquip(Map<String, dynamic> invItem) async {
    final resp = await _shopService.equipItem(invItem['id'] as int);
    if (!mounted) return;

    if (resp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? 'Berhasil dilengkapi')),
      );
      await _loadInventory(showLoading: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal melengkapi item')),
      );
    }
  }

  Future<void> _onSell(Map<String, dynamic> invItem) async {
    final resp = await _shopService.sellItem(invItem['id'] as int);
    if (!mounted) return;

    if (resp != null && resp['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? 'Item berhasil dijual')),
      );
      await _loadInventory(showLoading: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp?['error'] ?? 'Gagal menjual item')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '🎒 Inventaris',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1a1040)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(_error,
                            style: const TextStyle(color: AppColors.danger),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadInventory,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : _inventory.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📦', style: TextStyle(fontSize: 64)),
                            SizedBox(height: 16),
                            Text('Inventaris kosong',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16)),
                            SizedBox(height: 8),
                            Text('Beli item di toko terlebih dahulu',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInventory,
                        color: AppColors.gold,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _inventory.length,
                          itemBuilder: (context, index) {
                            final inv = _inventory[index];
                            return _buildInventoryCard(inv);
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> inv) {
    final shopName =
        inv['name'] ?? inv['shop_item_id']?.toString() ?? 'Item';
    final level = inv['current_level'] ?? 1;
    final maxLevel = inv['max_level'] ?? 1;
    final equipped = inv['is_equipped'] == true || inv['is_equipped'] == 1;
    final itemType = (inv['item_type'] ?? 'weapon').toString();
    final rarity = (inv['rarity'] ?? 'common').toString();
    final rarityColor = AppColors.fromRarity(rarity);

    return GestureDetector(
      onTap: () async {
        final item = {
          'id': inv['shop_item_id'],
          'name': inv['name'],
          'description': inv['description'],
          'item_type': inv['item_type'],
          'rarity': inv['rarity'],
          'base_stat': inv['base_stat'],
          'max_level': inv['max_level'],
          'is_owned': true,
        };

        final route = PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ItemDetailScreen(item: item, heroPrefix: 'inv-'),
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
              child: SlideTransition(position: offset, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 360),
        );

        final changed = await Navigator.of(context).push(route);
        if (changed == true) await _loadInventory(showLoading: false);
      },
      child: MobileGlassCard(
        borderRadius: 16,
        color: rarityColor.withValues(alpha: 0.07),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rarityColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Item icon ───────────────────────────────────────────
              Hero(
                tag: 'inv-item-icon-${inv['shop_item_id']}',
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          rarityColor.withValues(alpha: 0.85),
                          AppColors.primaryDark,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: rarityColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isWrath(inv)
                        ? const Center(
                            child: Text('🐄',
                                style: TextStyle(fontSize: 26)))
                        : Center(
                            child: Icon(_typeIcon(itemType),
                                color: Colors.white, size: 26)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Name & badge ─────────────────────────────────────────
              Hero(
                tag: 'inv-item-title-${inv['shop_item_id']}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    shopName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              RarityBadge(rarity: rarity, isSpecial: _isWrath(inv)),

              if (inv['granted_skill'] != null &&
                  inv['granted_skill'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 11, color: AppColors.accent),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        inv['granted_skill'],
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const Spacer(),

              // ── Level progress ─────────────────────────────────────
              Text(
                'Lv $level / ${_formatNumber(maxLevel)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (level / (maxLevel == 0 ? 1 : maxLevel))
                      .toDouble(),
                  minHeight: 5,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(rarityColor),
                ),
              ),
              const SizedBox(height: 8),

              // ── Equipped badge ─────────────────────────────────────
              if (equipped)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '✅ TERPASANG',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 6),

              // ── Action buttons ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed:
                            equipped ? null : () => _onEquip(inv),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: equipped
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          equipped ? 'Pasang ✓' : 'Pasang',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: () => _onUpgrade(inv),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          '⬆ Up',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: equipped ? null : () => _onSell(inv),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: equipped
                              ? AppColors.danger.withValues(alpha: 0.2)
                              : AppColors.danger,
                          disabledBackgroundColor:
                              AppColors.danger.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Jual',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
