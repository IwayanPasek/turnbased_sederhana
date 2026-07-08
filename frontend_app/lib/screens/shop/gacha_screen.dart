// lib/screens/shop/gacha_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../services/shop_service.dart';
import '../../providers/profile_provider.dart';

class GachaScreen extends StatefulWidget {
  final VoidCallback onBalanceChanged;

  const GachaScreen({super.key, required this.onBalanceChanged});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> with TickerProviderStateMixin {
  final _shopService = ShopService();
  bool _isOpening = false;
  String? _openingChestType;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 15.0, end: -15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -15.0, end: 15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 15.0, end: -15.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -15.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _openChest(String type, {bool multi = false}) async {
    if (_isOpening) return;
    
    setState(() {
      _isOpening = true;
      _openingChestType = type;
    });

    // Start shaking
    _shakeController.repeat();

    final result = multi ? await _shopService.openGachaMulti(type) : await _shopService.openGacha(type);

    // Stop shaking after 1.5 seconds minimum for effect
    await Future.delayed(const Duration(milliseconds: 1500));
    _shakeController.stop();
    _shakeController.reset();

    if (!mounted) return;

    setState(() {
      _isOpening = false;
      _openingChestType = null;
    });

    if (result != null) {
      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: AppColors.danger,
          ),
        );
      } else {
        widget.onBalanceChanged();
        if (multi) {
          _showMultiItemDialog(result['results']);
        } else {
          _showItemDialog(result['item'], result['message'], result['status']);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal terhubung ke server'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  IconData _getIconForItemType(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'weapon': return Icons.colorize; // Sword-like
      case 'armor': return Icons.shield;
      case 'potion': return Icons.science;
      case 'accessory': return Icons.diamond;
      case 'title': return Icons.badge;
      default: return Icons.star;
    }
  }

  void _showItemDialog(Map<String, dynamic> item, String message, String status) {
    Color rarityColor;
    switch (item['rarity']) {
      case 'common': rarityColor = Colors.grey; break;
      case 'uncommon': rarityColor = Colors.green; break;
      case 'rare': rarityColor = Colors.blue; break;
      case 'epic': rarityColor = Colors.purple; break;
      case 'legendary': rarityColor = AppColors.gold; break;
      default: rarityColor = Colors.white;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rarityColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: rarityColor.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 10,
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selamat! Anda mendapatkan:',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Icon(
                _getIconForItemType(item['item_type']?.toString() ?? ''),
                size: 80,
                color: rarityColor,
              ),
              const SizedBox(height: 10),
              Text(
                item['item_name'],
                style: TextStyle(
                  color: rarityColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (status != "new") 
                Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: status == "upgrade" ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Text(
                '+${item['base_stat_boost']} ${item['stat_type'].toString().toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Keren!', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMultiItemDialog(List<dynamic> results) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.3),
                blurRadius: 20,
              )
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selamat! Anda mendapatkan 10 item:',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (ctx, index) {
                    final res = results[index];
                    final item = res['item'];
                    final status = res['status'];
                    final rarity = (item['rarity'] ?? 'common').toString();
                    
                    Color rColor;
                    switch (rarity) {
                      case 'common': rColor = Colors.grey; break;
                      case 'uncommon': rColor = Colors.green; break;
                      case 'rare': rColor = Colors.blue; break;
                      case 'epic': rColor = Colors.purple; break;
                      case 'legendary': rColor = AppColors.gold; break;
                      default: rColor = Colors.white;
                    }

                    return ListTile(
                      leading: Icon(_getIconForItemType(item['item_type']?.toString() ?? ''), color: rColor),
                      title: Text(item['item_name'], style: TextStyle(color: rColor, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        status == "upgrade" ? "Level Up!" : status == "refund" ? "Max Level (Refund)" : "Item Baru",
                        style: TextStyle(color: status == "upgrade" ? Colors.greenAccent : Colors.white70, fontSize: 12),
                      ),
                      trailing: Text('+${item['base_stat_boost']} ${item['stat_type']}', style: const TextStyle(color: Colors.white)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChest({
    required String type,
    required String name,
    required String icon,
    required String costText,
    required Color glowColor,
    required List<String> drops,
  }) {
    final isThisOpening = _isOpening && _openingChestType == type;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        return Transform.translate(
          offset: isThisOpening ? Offset(_shakeAnimation.value, 0) : Offset.zero,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: glowColor.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.1),
              blurRadius: 20,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                color: glowColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Drops: ${drops.join(", ")}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isThisOpening ? Colors.grey : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  ),
                  onPressed: _isOpening ? null : () => _openChest(type),
                  child: isThisOpening
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          '1x ($costText)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isThisOpening ? Colors.grey : Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  ),
                  onPressed: _isOpening ? null : () => _openChest(type, multi: true),
                  child: isThisOpening
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          '10x (Multi)',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: profileNotifier,
      builder: (context, _) {
        final profileState = profileNotifier.state;
        int pityCounter = 0;
        if (profileState.hasValue && profileState.value != null) {
          pityCounter = profileState.value!['gacha_pity_counter'] ?? 0;
        }
        final int pullsToPity = 10 - pityCounter;

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Uji Keberuntunganmu!',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text(
                  pullsToPity <= 0 
                    ? 'Pity Aktif! Tarikan berikutnya Guaranteed Max Rarity!' 
                    : '$pullsToPity Tarikan lagi menuju Guaranteed Max Rarity!',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              _buildChest(
                type: 'bronze',
                name: 'Peti Perunggu',
                icon: '📦',
                costText: '50 Koin',
                glowColor: const Color(0xFFCD7F32), // Bronze
                drops: ['Common (70%)', 'Uncommon (25%)', 'Rare (5%)'],
              ),
              _buildChest(
                type: 'silver',
                name: 'Peti Perak',
                icon: '🧰',
                costText: '150 Koin',
                glowColor: const Color(0xFFC0C0C0), // Silver
                drops: ['Uncommon (50%)', 'Rare (40%)', 'Epic (10%)'],
              ),
              _buildChest(
                type: 'gold',
                name: 'Peti Emas',
                icon: '🎁',
                costText: '20 Gems',
                glowColor: AppColors.gold,
                drops: ['Rare (50%)', 'Epic (35%)', 'Legendary (15%)'],
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
