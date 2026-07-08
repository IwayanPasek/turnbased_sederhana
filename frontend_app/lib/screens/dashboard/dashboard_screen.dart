// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/mobile_glass_card.dart';
import '../../services/auth_service.dart';
import '../../services/server_config.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';
import '../game/game_screen.dart';
import '../practice/practice_screen.dart';
import '../shop/shop_screen.dart';
import '../inventory/inventory_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../guild/guild_screen.dart';
import '../quests/quests_screen.dart';
import '../admin/admin_dashboard.dart';
import '../../providers/profile_provider.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int)? onNavigateTab;
  const DashboardScreen({super.key, this.onNavigateTab});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    // Fetch profile data once
    Future.microtask(() => profileNotifier.load());
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Logout?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Apakah Anda yakin ingin keluar?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Keluar', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _auth.logout();
    await const FlutterSecureStorage().delete(key: 'server_url');
    ServerConfig.baseUrl = '';
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _nav(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) profileNotifier.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: profileNotifier,
      builder: (context, _) {
        final state = profileNotifier.state;
        
        return Scaffold(
          backgroundColor: AppColors.bgDark,
          body: state is AsyncLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : CustomScrollView(
                  slivers: [
                    // ─ Header SliverAppBar ─────────────────────────────────
                    SliverAppBar(
                      expandedHeight: 160,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.black87,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/bg_dashboard.png'),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('\u2694\ufe0f Turn Based Arena', style: TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text('Selamat datang, ${profileNotifier.username}!', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _statChip('⭐', 'Level', '${state.value?['level'] ?? 1} (EXP: ${state.value?['exp'] ?? 0}/${(state.value?['level'] ?? 1) * 100})'),
                                      _statChip('🏆', 'MMR', '${state.value?['mmr'] ?? 1000}'),
                                      _statChip('✅', 'Menang', '${state.value?['wins'] ?? 0}'),
                                      _statChip('❌', 'Kalah', '${state.value?['losses'] ?? 0}'),
                                      _statChip('🪙', 'Koin', '${state.value?['coins'] ?? 0}'),
                                      _statChip('💎', 'Gems', '${state.value?['gems'] ?? 0}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          onPressed: () => profileNotifier.load(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          onPressed: _logout,
                        ),
                      ],
                    ),

                    // ─ Announcement Banner ────────────────────────────────────────
                    if (state.value?['announcement'] != null && state.value!['announcement'].toString().trim().isNotEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.campaign, color: Colors.redAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  state.value!['announcement'].toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ─ Menu Grid ──────────────────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildListDelegate(_menuItems()),
                      ),
                    ),
                  ],
                ),
        );
      }
    );
  }

  List<Widget> _menuItems() => [
    _menuCard(
      emoji: '\u2694\ufe0f',
      label: 'PvP Arena',
      desc: 'Bertarung melawan pemain lain',
      gradient: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      onTap: () => _nav(const GameScreen()),
    ),
    _menuCard(
      emoji: '\u{1F916}',
      label: 'Practice Mode',
      desc: 'Latihan melawan AI bot',
      gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
      onTap: () => _nav(const PracticeScreen()),
    ),
    _menuCard(
      emoji: '🛍️',
      label: 'Shop',
      desc: 'Beli item & perlengkapan',
      gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1);
        } else {
          _nav(const ShopScreen());
        }
      },
    ),
    _menuCard(
      emoji: '🎒',
      label: 'Inventory',
      desc: 'Kelola & upgrade item',
      gradient: [const Color(0xFFEC4899), const Color(0xFFDB2777)],
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(2);
        } else {
          _nav(const InventoryScreen());
        }
      },
    ),
    _menuCard(
      emoji: '🏆',
      label: 'Leaderboard',
      desc: 'Top 100 Pemain',
      gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      onTap: () => _nav(const LeaderboardScreen()),
    ),
    _menuCard(
      emoji: '🛡️',
      label: 'Guild',
      desc: 'Klan & Sosial',
      gradient: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      onTap: () => _nav(const GuildScreen()),
    ),
    _menuCard(
      emoji: '📜',
      label: 'Daily Quests',
      desc: 'Misi & Hadiah Harian',
      gradient: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
      onTap: () => _nav(const QuestsScreen()),
    ),
    if (profileNotifier.state.value?['is_admin'] == true)
      _menuCard(
        emoji: '🚨',
        label: 'Admin Panel',
        desc: 'Kelola pemain & ban',
        gradient: [const Color(0xFF991B1B), const Color(0xFF7F1D1D)],
        onTap: () => _nav(const AdminDashboard()),
      ),
  ];

  Widget _menuCard({
    required String emoji,
    required String label,
    required String desc,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return MobileGlassCard(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String emoji, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
