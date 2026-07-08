import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import '../../../core/constants/app_colors.dart';
import 'give_item_dialog.dart';
import 'give_specific_item_dialog.dart';
import 'reset_password_dialog.dart';
import 'inventory_dialog.dart';

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final AdminService adminService;
  final VoidCallback onRefresh;
  final Function(int, bool) onToggleBan;
  final Function(int) onToggleAdmin;
  final Function(int) onResetStats;

  const UserCard({
    super.key,
    required this.user,
    required this.adminService,
    required this.onRefresh,
    required this.onToggleBan,
    required this.onToggleAdmin,
    required this.onResetStats,
  });

  @override
  Widget build(BuildContext context) {
    final bool isBanned = user['is_banned'] == true;
    final bool isAdmin = user['is_admin'] == true;

    return Card(
      color: isBanned ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF2C1338),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? AppColors.gold : AppColors.primary,
          child: Icon(isAdmin ? Icons.star : Icons.person, color: Colors.white),
        ),
        title: Row(
          children: [
            Text(
              user['username'],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: isBanned ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: 8),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            if (isBanned) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'BANNED',
                  style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '🪙 ${user['coins']}  💎 ${user['gems']}  ⚔️ MMR: ${user['mmr_score'] ?? 1000}',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: AppColors.bgDark,
          onSelected: (value) {
            if (value == 'give_currency') {
              showGiveCurrencyDialog(context, user['id'], user['username'], adminService, onRefresh);
            } else if (value == 'give_item') {
              showGiveSpecificItemDialog(context, user['id'], user['username'], adminService, onRefresh);
            } else if (value == 'ban') {
              onToggleBan(user['id'], isBanned);
            } else if (value == 'admin') {
              onToggleAdmin(user['id']);
            } else if (value == 'stats') {
              onResetStats(user['id']);
            } else if (value == 'password') {
              showResetPasswordDialog(context, user['id'], user['username'], adminService);
            } else if (value == 'inventory') {
              showInventoryDialog(context, user['id'], user['username'], adminService);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'give_currency',
              child: ListTile(
                leading: Icon(Icons.card_giftcard, color: AppColors.gold),
                title: Text('Beri Koin/Gems', style: TextStyle(color: Colors.white)),
              ),
            ),
            const PopupMenuItem(
              value: 'give_item',
              child: ListTile(
                leading: Icon(Icons.shield, color: AppColors.primary),
                title: Text('Beri Item (Equip)', style: TextStyle(color: Colors.white)),
              ),
            ),
            PopupMenuItem(
              value: 'admin',
              child: ListTile(
                leading: Icon(isAdmin ? Icons.star_border : Icons.star, color: AppColors.gold),
                title: Text(isAdmin ? 'Turunkan Status Admin' : 'Jadikan Admin', style: const TextStyle(color: Colors.white)),
              ),
            ),
            const PopupMenuItem(
              value: 'stats',
              child: ListTile(
                leading: Icon(Icons.restart_alt, color: Colors.blue),
                title: Text('Reset Stats (MMR)', style: TextStyle(color: Colors.white)),
              ),
            ),
            const PopupMenuItem(
              value: 'password',
              child: ListTile(
                leading: Icon(Icons.vpn_key, color: Colors.purple),
                title: Text('Reset Password', style: TextStyle(color: Colors.white)),
              ),
            ),
            PopupMenuItem(
              value: 'ban',
              child: ListTile(
                leading: Icon(isBanned ? Icons.lock_open : Icons.block, color: isBanned ? Colors.green : Colors.red),
                title: Text(isBanned ? 'Buka Blokir' : 'Blokir (Ban)', style: const TextStyle(color: Colors.white)),
              ),
            ),
            const PopupMenuItem(
              value: 'inventory',
              child: ListTile(
                leading: Icon(Icons.backpack, color: Colors.teal),
                title: Text('Lihat Inventori', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
