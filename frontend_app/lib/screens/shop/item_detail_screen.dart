// lib/screens/item_detail_screen.dart
import 'package:flutter/material.dart';
import '../../services/shop_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/rarity_badge.dart';

class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen>
    with SingleTickerProviderStateMixin {
  final ShopService _shop = ShopService();

  bool _isLoading = true;
  Map<String, dynamic>? _details;
  String _error = '';
  bool _isBuying = false;
  bool _descExpanded = false;

  late AnimationController _heroCtrl;
  late Animation<double> _heroPulse;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _heroPulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeInOut),
    );
    _loadDetails();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final det = await _shop.fetchItemDetails(widget.item['id'] as int);
      if (!mounted) return;
      setState(() {
        _details = det;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat detail item';
        _isLoading = false;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _isSpecialItem {
    final name = (widget.item['name'] ?? '').toString().toLowerCase();
    return name.contains('wrath') && name.contains('cow');
  }

  String get _rarity =>
      (widget.item['rarity'] ?? 'common').toString().toLowerCase();

  Color _rarityPrimaryColor() {
    switch (_rarity) {
      case 'common':
        return const Color(0xFF94A3B8);
      case 'uncommon':
        return AppColors.accent;
      case 'rare':
        return const Color(0xFF60A5FA);
      case 'epic':
        return const Color(0xFFA855F7);
      case 'legendary':
        return AppColors.warning;
      default:
        return AppColors.warning;
    }
  }

  List<Color> _rarityGradient() {
    if (_isSpecialItem) {
      return [
        const Color(0xFFFFD700),
        const Color(0xFFFF8C00),
        const Color(0xFFFF4500),
        const Color(0xFF7B2FF7),
      ];
    }
    final c = _rarityPrimaryColor();
    return [c, AppColors.primaryDark];
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'weapon':
        return AppColors.danger;
      case 'armor':
        return AppColors.primary;
      case 'accessory':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
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
        return Icons.circle;
    }
  }

  String _statLabel(String statType) {
    switch (statType.toLowerCase()) {
      case 'attack':
        return '⚔️ ATK';
      case 'defense':
        return '🛡️ DEF';
      case 'hp':
        return '❤️ HP';
      default:
        return statType.toUpperCase();
    }
  }

  String _formatNumber(dynamic n) {
    if (n == null) return '0';
    final val = (n is int) ? n : int.tryParse(n.toString()) ?? 0;
    if (val >= 1000000000) return '${(val / 1000000000).toStringAsFixed(2)}B';
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toString();
  }

  // ── Buy ────────────────────────────────────────────────────────────────────

  Future<void> _handleBuy() async {
    if (_isBuying) return;
    setState(() => _isBuying = true);

    final resp = await _shop.buyItem(widget.item['id'] as int);
    if (!mounted) return;
    setState(() => _isBuying = false);

    if (resp != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp['message'] ?? 'Berhasil membeli'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membeli item'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final itemType = (item['item_type'] ?? 'weapon').toString();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error.isNotEmpty
          ? _buildError()
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(item, itemType),
                SliverToBoxAdapter(child: _buildBody(item, itemType)),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(_error,
              style: const TextStyle(color: AppColors.danger, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDetails,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // ── Sliver AppBar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(Map<String, dynamic> item, String itemType) {
    final gradColors = _rarityGradient();
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8),
          child: RarityBadge(rarity: _rarity, isSpecial: _isSpecialItem),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradColors.first.withValues(alpha: 0.35),
                    AppColors.bgDark,
                  ],
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradColors.first.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradColors.last.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Hero icon with pulse
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  AnimatedBuilder(
                    animation: _heroPulse,
                    builder: (context, child) => Transform.scale(
                      scale: _heroPulse.value,
                      child: child,
                    ),
                    child: Hero(
                      tag: 'item-icon-${item['id']}',
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: gradColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gradColors.first.withValues(alpha: 0.55),
                              blurRadius: 28,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: _isSpecialItem
                            ? const Center(
                                child: Text(
                                  '🐄',
                                  style: TextStyle(fontSize: 46),
                                ),
                              )
                            : Icon(
                                _typeIcon(itemType),
                                color: Colors.white,
                                size: 50,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Hero(
                    tag: 'item-title-${item['id']}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        item['name'] ?? 'Item',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(Map<String, dynamic> item, String itemType) {
    final mergedItem = {
      ...item,
      ...?(_details?['item'] as Map<String, dynamic>?),
    };

    final baseStat =
        mergedItem['base_stat'] ?? mergedItem['base_stat_boost'] ?? 0;
    final maxLevel = mergedItem['max_level'] ?? 1;
    final baseCostCoins =
        mergedItem['base_cost_coins'] ?? item['base_cost_coins'] ?? 0;
    final baseCostGems =
        mergedItem['base_cost_gems'] ?? item['base_cost_gems'] ?? 0;
    final statType = (mergedItem['stat_type'] ?? 'attack').toString();
    final description = (mergedItem['description'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stat chips row ─────────────────────────────────────────
          _buildStatChips(itemType, baseStat, maxLevel, statType),
          const SizedBox(height: 20),

          // ── Description card ───────────────────────────────────────
          if (description.isNotEmpty) ...[
            _buildDescriptionCard(description),
            const SizedBox(height: 20),
          ],

          // ── Upgrade cost table ─────────────────────────────────────
          _buildUpgradeCostTable(),
          const SizedBox(height: 20),

          // ── Price & Buy ────────────────────────────────────────────
          _buildBuySection(baseCostCoins, baseCostGems, item),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Stat Chips ─────────────────────────────────────────────────────────────

  Widget _buildStatChips(
    String itemType,
    dynamic baseStat,
    dynamic maxLevel,
    String statType,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _statChip(
          icon: _typeIcon(itemType),
          label: itemType.toUpperCase(),
          color: _typeColor(itemType),
        ),
        _statChip(
          icon: Icons.bolt,
          label: '${_statLabel(statType)}: +${_formatNumber(baseStat)}/Lv',
          color: AppColors.accent,
        ),
        _statChip(
          icon: Icons.arrow_upward,
          label: 'Max Lv $maxLevel',
          color: AppColors.primary,
        ),
        if (_isSpecialItem)
          _statChip(
            icon: Icons.star,
            label: 'UNMATCHED TIER',
            color: AppColors.warning,
            bold: true,
          ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required Color color,
    bool bold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── Description ────────────────────────────────────────────────────────────

  Widget _buildDescriptionCard(String description) {
    const int previewLines = 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _isSpecialItem ? Icons.auto_stories : Icons.description_outlined,
              color: _isSpecialItem ? AppColors.warning : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _isSpecialItem ? 'Legenda & Kisah' : 'Deskripsi',
              style: TextStyle(
                color: _isSpecialItem ? AppColors.warning : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _isSpecialItem
                ? const Color(0xFF2A1A00).withValues(alpha: 0.85)
                : AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isSpecialItem
                  ? AppColors.warning.withValues(alpha: 0.45)
                  : AppColors.border,
              width: _isSpecialItem ? 1.5 : 1,
            ),
            boxShadow: _isSpecialItem
                ? [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSpecialItem) ...[
                  // Special gold-title banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '📜  Kisah Wrath of the Cow — Shikizima, The First Ruler of STIKOM',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                // Description text — expandable
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 350),
                  crossFadeState: _descExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Text(
                    description,
                    maxLines: previewLines,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color: _isSpecialItem
                          ? const Color(0xFFFFE0A0)
                          : AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                  secondChild: Text(
                    description,
                    style: TextStyle(
                      color: _isSpecialItem
                          ? const Color(0xFFFFE0A0)
                          : AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Expand / Collapse button
                GestureDetector(
                  onTap: () =>
                      setState(() => _descExpanded = !_descExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _descExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _isSpecialItem
                            ? AppColors.warning
                            : AppColors.primary,
                        size: 20,
                      ),
                      Text(
                        _descExpanded ? 'Sembunyikan' : 'Baca selengkapnya',
                        style: TextStyle(
                          color: _isSpecialItem
                              ? AppColors.warning
                              : AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Upgrade Cost Table ─────────────────────────────────────────────────────

  Widget _buildUpgradeCostTable() {
    final upgradeCosts =
        _details?['upgrade_costs'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.upgrade, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Tabel Biaya Upgrade',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${upgradeCosts.length} level',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (upgradeCosts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'Tidak ada data upgrade tersedia',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Level',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '🪙 Coins',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '💎 Gems',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // Table rows
                ...upgradeCosts.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value as Map<String, dynamic>;
                  final fromLv = e['from_level'] ?? i + 1;
                  final toLv = e['to_level'] ?? i + 2;
                  final coins = e['cost_coins'] ?? 0;
                  final gems = e['cost_gems'] ?? 0;
                  final isEven = i % 2 == 0;
                  final isLast = i == upgradeCosts.length - 1;

                  return Container(
                    decoration: BoxDecoration(
                      color: isEven
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: isLast
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(16))
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$fromLv→$toLv',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatNumber(coins),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            gems > 0 ? _formatNumber(gems) : '—',
                            style: TextStyle(
                              color: gems > 0
                                  ? const Color(0xFF60A5FA)
                                  : AppColors.border,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }

  // ── Buy Section ────────────────────────────────────────────────────────────

  Widget _buildBuySection(
    dynamic baseCostCoins,
    dynamic baseCostGems,
    Map<String, dynamic> item,
  ) {
    final coinsStr = _formatNumber(baseCostCoins);
    final gemsStr = _formatNumber(baseCostGems);
    final hasGems = (baseCostGems is int ? baseCostGems : 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shopping_cart_outlined,
                color: AppColors.accent, size: 18),
            SizedBox(width: 8),
            Text(
              'Pembelian',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Price display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isSpecialItem
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _priceTag(
                icon: Icons.monetization_on,
                label: '$coinsStr Coins',
                color: AppColors.warning,
              ),
              if (hasGems) ...[
                const SizedBox(width: 12),
                _priceTag(
                  icon: Icons.diamond,
                  label: '$gemsStr Gems',
                  color: const Color(0xFF60A5FA),
                ),
              ],
              const Spacer(),
              // Buy button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isBuying ? null : _handleBuy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSpecialItem
                        ? AppColors.warning
                        : AppColors.primary,
                    foregroundColor: _isSpecialItem ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    elevation: _isSpecialItem ? 8 : 4,
                    shadowColor: _isSpecialItem
                        ? AppColors.warning.withValues(alpha: 0.5)
                        : AppColors.primary.withValues(alpha: 0.4),
                  ),
                  icon: _isBuying
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _isSpecialItem ? Colors.black : Colors.white,
                          ),
                        )
                      : Icon(
                          _isSpecialItem ? Icons.star : Icons.shopping_cart,
                          size: 20,
                        ),
                  label: Text(
                    _isSpecialItem ? 'Dapatkan!' : 'Beli Item',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isSpecialItem) ...[
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '⚠️ Peringatan: Pembelian item ini dapat menyebabkan enlightenment mendadak.',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _priceTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
