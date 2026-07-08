import 'package:flutter/material.dart';
import '../../services/leaderboard_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/mobile_glass_card.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  bool _isLoading = true;
  List<dynamic> _players = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    final data = await _leaderboardService.getLeaderboard();
    if (mounted) {
      setState(() {
        _players = data ?? [];
        _isLoading = false;
      });
    }
  }

  Widget _buildMedal(int rank) {
    if (rank == 1) {
      return const Text('🥇', style: TextStyle(fontSize: 28));
    } else if (rank == 2) {
      return const Text('🥈', style: TextStyle(fontSize: 28));
    } else if (rank == 3) {
      return const Text('🥉', style: TextStyle(fontSize: 28));
    }
    return Text(
      '#$rank',
      style: const TextStyle(
        color: Colors.white54,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.white10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '🏆 Global Leaderboard',
          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchLeaderboard,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1a1040)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _players.isEmpty
                ? const Center(
                    child: Text('Belum ada data',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _players.length,
                    itemBuilder: (context, index) {
                      final p = _players[index];
                      final rank = p['rank'] as int;
                      final isTop3 = rank <= 3;
                      final rankColor = _getRankColor(rank);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MobileGlassCard(
                          color: isTop3 
                              ? rankColor.withValues(alpha: 0.15) 
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: 16,
                          child: Container(
                            decoration: isTop3 
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: rankColor.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                )
                              : null,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Center(child: _buildMedal(rank)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['username'],
                                        style: TextStyle(
                                          color: isTop3 ? rankColor : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.emoji_events, size: 14, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text(
                                            'W: ${p["wins"]} | L: ${p["losses"]}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${p['tier'] ?? 'Bronze'}',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${p['mmr_score']}',
                                      style: TextStyle(
                                        color: isTop3 ? rankColor : AppColors.gold,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
