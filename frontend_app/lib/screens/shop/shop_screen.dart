// lib/screens/shop_screen.dart
import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../core/constants/app_colors.dart';
import '../../screens/shop/item_detail_screen.dart';
import '../../widgets/common/rarity_badge.dart';
import '../../widgets/mobile_glass_card.dart';
import '../../providers/profile_provider.dart';
import '../../screens/shop/gacha_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ShopService _shopService = ShopService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  String _error = '';

  bool _isWrath(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString().toLowerCase();
    return name.contains('wrath') && name.contains('cow');
  }

  String _formatNumber(dynamic n) {
    if (n == null) return '0';
    final val = (n is int) ? n : int.tryParse(n.toString()) ?? 0;
    if (val >= 1000000000) return '${(val / 1000000000).toStringAsFixed(1)}B';
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final items = await _shopService.fetchShopItems();
      if (!mounted) return;
      setState(() {
        _items = items ?? [];
        if (showLoading) _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat item toko';
        if (showLoading) _isLoading = false;
      });
    }
  }

  Future<void> _onBuy(Map<String, dynamic> item) async {
    final int coins = (item['base_cost_coins'] ?? 0) as int;
    final int gems = (item['base_cost_gems'] ?? 0) as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_cart, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Konfirmasi Pembelian',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin membeli\n"${item['name']}"?',
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
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Beli', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final resp = await _shopService.buyItem(item['id'] as int);
    if (!mounted) return;

    if (resp != null && resp['error'] == null) {
      final message = resp['message'] ?? 'Berhasil membeli item';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      // Update global profile stats (coins/gems) efficiently
      profileNotifier.load();
    } else {
      final errMsg = resp?['error'] ?? 'Gagal membeli item';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '🛒 Toko',
            style: TextStyle(
                color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _loadItems,
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.shopping_bag), text: 'Item Reguler'),
              Tab(icon: Icon(Icons.card_giftcard), text: 'Gacha'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Item Reguler
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg_shop.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
                ),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚠️',
                            style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(_error,
                            style: const TextStyle(
                                color: AppColors.danger),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadItems,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadItems,
                    color: AppColors.gold,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _buildShopCard(item);
                      },
                    ),
                    ),
                  ),
            // Tab 2: Gacha
            GachaScreen(
              onBalanceChanged: () {
                // Refresh global balance after gacha
                profileNotifier.load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCard(Map<String, dynamic> item) {
    final rarity = (item['rarity'] ?? 'common').toString();
    final rarityColor = AppColors.fromRarity(rarity);
    final int coins = (item['base_cost_coins'] ?? 0) as int;
    final int gems = (item['base_cost_gems'] ?? 0) as int;

    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ItemDetailScreen(item: item, heroPrefix: 'shop-'),
        );
        if (result == true) {
          await _loadItems(showLoading: false);
        }
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
              // ── Item Icon ─────────────────────────────────────
              Center(
                child: Container(
                  width: 52,
                  height: 52,
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
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: _isWrath(item)
                      ? const Center(
                          child: Text('🐄',
                              style: TextStyle(fontSize: 24)))
                      : const Center(
                          child: Icon(Icons.auto_fix_high,
                              color: Colors.white, size: 24)),
                ),
              ),
              const SizedBox(height: 8),

              // ── Name ────────────────────────────────────────────
              Hero(
                tag: 'shop-item-title-${item['id']}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    item['name'] ?? '',
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

              // ── Rarity badge ────────────────────────────────────
              RarityBadge(
                rarity: rarity,
                size: 12,
                isSpecial: _isWrath(item),
              ),
              const SizedBox(height: 6),

              // ── Description ─────────────────────────────────────
              Expanded(
                child: Text(
                  item['description'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Granted skill ────────────────────────────────────
              if (item['granted_skill'] != null &&
                  item['granted_skill'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 11, color: AppColors.accent),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        item['granted_skill'],
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

              const SizedBox(height: 8),

              // ── Price ────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.monetization_on,
                      color: AppColors.warning, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    _formatNumber(coins),
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (gems > 0) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.diamond,
                        color: Color(0xFF60A5FA), size: 14),
                    const SizedBox(width: 3),
                    Text(
                      _formatNumber(gems),
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // ── Buy button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: () async {
                    await _onBuy(item);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('🛒 Beli',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
