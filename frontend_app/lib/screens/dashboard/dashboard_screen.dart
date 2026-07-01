// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';
import '../../services/server_config.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';
import '../game/game_screen.dart';
import '../practice/practice_screen.dart';
import '../shop/shop_screen.dart';
import '../inventory/inventory_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = AuthService();
  Map<String, dynamic> _stats = {};
  String _username = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final username = await _auth.getUsername();
    final stats    = await _auth.getPlayerStats();
    if (!mounted) return;
    setState(() {
      _username = username ?? 'Player';
      _stats = stats ?? {};
      _loading = false;
    });
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

  void _nav(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : CustomScrollView(
              slivers: [
                // ─ Header SliverAppBar ─────────────────────────────────
                SliverAppBar(
                  expandedHeight: 240,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.black87,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                              Text('Selamat datang, $_username!', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _statChip('🏆', 'MMR', '${_stats['mmr'] ?? 1000}'),
                                  const SizedBox(width: 10),
                                  _statChip('✅', 'Menang', '${_stats['wins'] ?? 0}'),
                                  const SizedBox(width: 10),
                                  _statChip('❌', 'Kalah', '${_stats['losses'] ?? 0}'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statChip('🪙', 'Koin', '${_stats['coins'] ?? 0}'),
                                  const SizedBox(width: 10),
                                  _statChip('💎', 'Gems', '${_stats['gems'] ?? 0}'),
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
                      onPressed: () { setState(() => _loading = true); _load(); },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      onPressed: _logout,
                    ),
                  ],
                ),

                // ─ Menu Grid ──────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
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
      emoji: '\u{1F6CD}\uFE0F',
      label: 'Shop',
      desc: 'Beli item & perlengkapan',
      gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      onTap: () => _nav(const ShopScreen()),
    ),
    _menuCard(
      emoji: '\u{1F392}',
      label: 'Inventory',
      desc: 'Kelola & upgrade item',
      gradient: [const Color(0xFFEC4899), const Color(0xFFDB2777)],
      onTap: () => _nav(const InventoryScreen()),
    ),
  ];

  Widget _menuCard({
    required String emoji,
    required String label,
    required String desc,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
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
