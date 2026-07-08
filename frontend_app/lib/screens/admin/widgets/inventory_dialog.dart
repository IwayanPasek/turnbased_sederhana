import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import '../../../core/constants/app_colors.dart';

class InventoryDialog extends StatefulWidget {
  final int userId;
  final String username;
  final AdminService adminService;

  const InventoryDialog({
    super.key,
    required this.userId,
    required this.username,
    required this.adminService,
  });

  @override
  State<InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<InventoryDialog> {
  late Future<List<dynamic>?> _inventoryFuture;

  @override
  void initState() {
    super.initState();
    _inventoryFuture = widget.adminService.getUserInventory(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgDark,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Inventori ${widget.username}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<List<dynamic>?>(
          future: _inventoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Text(
                  'Gagal mengambil data inventori pemain',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'Pemain tidak memiliki item apa pun',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isEquipped = item['is_equipped'] == true;
                final String rarity = item['rarity'] ?? 'Common';
                final String type = item['item_type'] ?? 'Equipment';
                final String statType = item['stat_type'] ?? 'HP';
                final int statVal = item['base_stat'] ?? 0;
                final int level = item['current_level'] ?? 1;

                Color rarityColor = Colors.grey;
                if (rarity.toLowerCase() == 'uncommon') {
                  rarityColor = Colors.green;
                } else if (rarity.toLowerCase() == 'rare') {
                  rarityColor = Colors.blue;
                } else if (rarity.toLowerCase() == 'epic') {
                  rarityColor = Colors.purple;
                } else if (rarity.toLowerCase() == 'legendary') {
                  rarityColor = AppColors.gold;
                }

                return Card(
                  color: const Color(0xFF2C1338),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: rarityColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] ?? 'Unknown Item',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            rarity.toUpperCase(),
                            style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Tipe: $type | Level: $level',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Stats: +$statVal $statType',
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    trailing: isEquipped
                        ? const Tooltip(
                            message: 'Equipped',
                            child: Icon(Icons.shield, color: Colors.green),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

void showInventoryDialog(BuildContext context, int userId, String username, AdminService adminService) {
  showDialog(
    context: context,
    builder: (context) => InventoryDialog(userId: userId, username: username, adminService: adminService),
  );
}
