// lib/screens/shop_screen.dart
import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../core/constants/app_colors.dart';
import '../../screens/shop/item_detail_screen.dart';
import '../../widgets/common/rarity_badge.dart';

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

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final items = await _shopService.fetchShopItems();
      if (!mounted) return;
      setState(() {
        _items = items ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat item toko';
        _isLoading = false;
      });
    }
  }

  Future<void> _onBuy(Map<String, dynamic> item) async {
    // Purchase price comes from base_cost_coins / base_cost_gems on the shop item
    final int coins = (item['base_cost_coins'] ?? 0) as int;
    final int gems = (item['base_cost_gems'] ?? 0) as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Pembelian'),
        content: Text(
          '${item['name']}\nHarga: $coins koin ${gems > 0 ? ' & $gems gems' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Beli'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final resp = await _shopService.buyItem(item['id'] as int);
    if (resp != null) {
      final message = resp['message'] ?? 'Berhasil membeli item';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _loadItems();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membeli item')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toko')),
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
                onRefresh: _loadItems,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return InkWell(
                      onTap: () async {
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
                        if (changed == true) await _loadItems();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        color: AppColors.bgCard,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Hero(
                                          tag: 'item-title-${item['id']}',
                                          child: Material(
                                            color: Colors.transparent,
                                            child: Text(
                                              item['name'] ?? '',
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
                                          rarity: (item['rarity'] ?? 'common')
                                              .toString(),
                                          size: 14,
                                          isSpecial: _isWrath(item),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item['description'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item['granted_skill'] != null && item['granted_skill'].toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Skill: ${item['granted_skill']}',
                                              style: const TextStyle(
                                                color: AppColors.accent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.monetization_on,
                                          color: Color(0xFFF59E0B),
                                          size: 15,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatNumber(item['base_cost_coins']),
                                          style: const TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if ((item['base_cost_gems'] ?? 0) > 0) ...[
                                          const SizedBox(width: 10),
                                          const Icon(
                                            Icons.diamond,
                                            color: Color(0xFF60A5FA),
                                            size: 15,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatNumber(item['base_cost_gems']),
                                            style: const TextStyle(
                                              color: Color(0xFF60A5FA),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  // quick buy still supported
                                  await _onBuy(item);
                                  await _loadItems();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                child: const Text('Beli'),
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
