import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/mobile_glass_card.dart';
import '../../providers/profile_provider.dart';
import 'attributes_screen.dart';
import 'history_screen.dart';
// Achievements removed
import '../admin/admin_dashboard.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  void initState() {
    super.initState();
    // Profile provider should already be loading/loaded from Dashboard
    // but just in case, we can ensure it's called
    if (profileNotifier.state.value == null && profileNotifier.state is! AsyncLoading) {
      Future.microtask(() => profileNotifier.load());
    }
  }

  Map<String, int> _calculateEquipmentStats(Map<String, dynamic> stats) {
    Map<String, int> totalStats = {};
    if (stats.containsKey('equipped') && stats['equipped'] is Map) {
      final equipped = stats['equipped'] as Map;
      for (var item in equipped.values) {
        if (item is Map) {
          final statType = item['stat_type']?.toString().toLowerCase() ?? 'unknown';
          final baseStat = (item['base_stat'] as num?)?.toInt() ?? 0;
          final currentLevel = (item['current_level'] as num?)?.toInt() ?? 1;
          
          final effectiveStat = baseStat * currentLevel;
          
          totalStats[statType] = (totalStats[statType] ?? 0) + effectiveStat;
        }
      }
    }
    return totalStats;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: profileNotifier,
      builder: (context, _) {
        final state = profileNotifier.state;
        
        if (state is AsyncLoading && state.value == null) {
          return const Scaffold(
            backgroundColor: AppColors.bgDark,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final stats = state.value ?? {};
        final equipmentStats = _calculateEquipmentStats(stats);

        return Scaffold(
          backgroundColor: AppColors.bgDark,
          body: CustomScrollView(
            slivers: [
              // Header Profile
              SliverAppBar(
                expandedHeight: 260,
                floating: false,
                pinned: true,
                backgroundColor: Colors.black87,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2C1338), Color(0xFF1F1029), Color(0xFF100B1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showAvatarSelection(context, stats['avatar_style']?.toString() ?? 'default'),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage: AssetImage('assets/avatars/${stats['avatar_style'] ?? 'default'}_idle.png'),
                                  onBackgroundImageError: (exception, stackTrace) {},
                                  child: stats['avatar_style'] == null 
                                      ? const Icon(Icons.person, size: 50, color: Colors.white) 
                                      : null, // If image fails, the background color shows. You could put icon here too.
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profileNotifier.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (stats['active_title'] != null && stats['active_title'].toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                              ),
                              child: Text(
                                stats['active_title'],
                                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            const SizedBox(height: 22), // placeholder spacing if no title
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _statChip('🪙', 'Koin', '${stats['coins'] ?? 0}'),
                              const SizedBox(width: 16),
                              _statChip('💎', 'Gems', '${stats['gems'] ?? 0}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (stats['is_admin'] == true)
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                      tooltip: 'Admin Panel',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminDashboard()),
                        );
                      },
                    ),
                  // Achievements removed per user request
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: () => profileNotifier.load(),
                  ),
                ],
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Match Stats
                    _buildSectionTitle('Statistik Pertandingan'),
                    MobileGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMatchStatItem('${stats['tier'] ?? 'Bronze'}', 'MMR ${stats['mmr'] ?? 1000}', Icons.emoji_events, AppColors.gold),
                                _buildMatchStatItem('Win Rate', _calculateWinRate(stats), Icons.pie_chart, AppColors.primary),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMatchStatItem('M', '${stats['wins'] ?? 0}', Icons.check_circle, AppColors.success),
                                _buildMatchStatItem('K', '${stats['losses'] ?? 0}', Icons.cancel, AppColors.danger),
                                _buildMatchStatItem('Total', '${stats['matches_played'] ?? 0}', Icons.sports_esports, Colors.white70),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                
                const SizedBox(height: 20),

                // Equipment Stats
                _buildSectionTitle('Total Status Equipment'),
                MobileGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: equipmentStats.isEmpty 
                      ? const Center(
                          child: Text(
                            'Tidak ada equipment terpasang', 
                            style: TextStyle(color: Colors.white54)
                          )
                        )
                      : Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: equipmentStats.entries.map((e) => _buildEquipStatItem(e.key, e.value)).toList(),
                        ),
                  ),
                ),

                const SizedBox(height: 20),

                // Extensible Features Placeholders
                _buildSectionTitle('Fitur Lainnya'),
                _buildFeatureListItem(
                  Icons.local_fire_department, 
                  'Attributes', 
                  'Alokasikan poin atribut karakter',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AttributesScreen()));
                  }
                ),
                const SizedBox(height: 12),
                _buildFeatureListItem(
                  Icons.history, 
                  'Riwayat Pertarungan', 
                  'Lihat detail match sebelumnya',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchHistoryScreen()));
                  }
                ),
                
                const SizedBox(height: 100), // Spacing for bottom navigation
              ]),
            ),
          ),
        ],
      ),
    );
      }
    );
  }

  String _calculateWinRate(Map<String, dynamic> stats) {
    final wins = (stats['wins'] as num?)?.toInt() ?? 0;
    final total = (stats['matches_played'] as num?)?.toInt() ?? 0;
    if (total == 0) return '0%';
    final wr = (wins / total) * 100;
    return '${wr.toStringAsFixed(1)}%';
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMatchStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildEquipStatItem(String statType, int value) {
    IconData icon;
    Color color;
    String label = statType.toUpperCase();

    if (statType == 'attack' || statType == 'damage') {
      icon = Icons.sports_martial_arts;
      color = AppColors.danger;
      label = 'Attack';
    } else if (statType == 'health' || statType == 'hp') {
      icon = Icons.favorite;
      color = AppColors.success;
      label = 'Health';
    } else if (statType == 'defense' || statType == 'armor') {
      icon = Icons.shield;
      color = AppColors.primary;
      label = 'Defense';
    } else {
      icon = Icons.star;
      color = AppColors.gold;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text('+$value', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureListItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white70),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fitur $title akan segera hadir!'),
              backgroundColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _statChip(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _showAvatarSelection(BuildContext context, String currentAvatar) {
    final List<String> availableAvatars = ['default', 'knight', 'mage', 'ninja'];
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        title: const Text('Pilih Avatar', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: availableAvatars.length,
            itemBuilder: (gridCtx, index) {
              final style = availableAvatars[index];
              final isSelected = style == currentAvatar;
              
              return GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  final success = await profileNotifier.updateAvatar(style);
                  if (success) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Avatar berhasil diperbarui!')),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Gagal memperbarui avatar')),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    border: Border.all(
                      color: isSelected ? AppColors.gold : Colors.white24,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/avatars/${style}_idle.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                          const Center(child: Icon(Icons.person, color: Colors.white)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
