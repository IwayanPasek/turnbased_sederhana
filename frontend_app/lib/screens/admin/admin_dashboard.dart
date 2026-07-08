import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/user_card.dart';
import 'widgets/broadcast_dialog.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _adminService = AdminService();
  List<dynamic> _users = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getUsers(search: _searchCtrl.text.trim());
      final stats = await _adminService.getStats();
      if (users != null) {
        setState(() {
          _users = users;
          _stats = stats;
          _isLoading = false;
        });
      } else {
        throw Exception('Gagal memuat data admin');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _toggleBan(int userId, bool currentBanStatus) async {
    try {
      final res = await _adminService.toggleBan(userId);
      if (res != null && res['success'] == true) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Status ban berhasil diubah')),
          );
        }
      } else {
        throw Exception(res?['detail'] ?? 'Gagal mengubah status ban');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _toggleAdmin(int userId) async {
    try {
      final res = await _adminService.toggleAdmin(userId);
      if (res != null && res['success'] == true) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Status admin berhasil diubah')),
          );
        }
      } else {
        throw Exception(res?['detail'] ?? 'Gagal mengubah status admin');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _resetStats(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        title: const Text('Reset Statistik', style: TextStyle(color: Colors.white)),
        content: const Text('Apakah Anda yakin ingin mereset MMR dan rekor tanding pemain ini?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _adminService.resetStats(userId);
      if (res != null && res['success'] == true) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Statistik berhasil direset')),
          );
        }
      } else {
        throw Exception(res?['detail'] ?? 'Gagal mereset statistik');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildOverviewStats() {
    if (_stats == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildOverviewCard('👥', 'Pemain', '${_stats!['total_players']}', Colors.blue),
          _buildOverviewCard('🚫', 'Banned', '${_stats!['total_banned']}', Colors.red),
          _buildOverviewCard('⭐', 'Admin', '${_stats!['total_admins']}', Colors.amber),
          _buildOverviewCard('🪙', 'Total Koin', '${_stats!['total_coins']}', AppColors.gold),
          _buildOverviewCard('💎', 'Total Gems', '${_stats!['total_gems']}', Colors.teal),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String emoji, String title, String value, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1338),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: 'Pengumuman Sistem',
            onPressed: () => showBroadcastDialog(context, _adminService),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                  child: _buildOverviewStats(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari pemain berdasarkan username...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadUsers();
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2C1338),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onSubmitted: (_) => _loadUsers(),
                  ),
                ),
                Expanded(
                  child: _users.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada pemain ditemukan',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final u = _users[index];
                            return UserCard(
                              user: u as Map<String, dynamic>,
                              adminService: _adminService,
                              onRefresh: _loadUsers,
                              onToggleBan: _toggleBan,
                              onToggleAdmin: _toggleAdmin,
                              onResetStats: _resetStats,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
