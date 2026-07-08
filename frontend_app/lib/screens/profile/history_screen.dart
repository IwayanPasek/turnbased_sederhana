import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/mobile_glass_card.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final _auth = AuthService();
  bool _loading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final hist = await _auth.getMatchHistory();
    if (hist != null) {
      setState(() => _history = hist);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Riwayat Pertarungan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _history.isEmpty
              ? const Center(
                  child: Text('Belum ada riwayat pertarungan.', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final isWinner = item['is_winner'] == true;
                    final opponent = item['opponent'] ?? 'Unknown';
                    final battleType = item['battle_type']?.toString().toUpperCase() ?? 'PVP';
                    final rounds = item['total_rounds'] ?? 0;
                    
                    // Parse Date
                    String dateStr = '';
                    if (item['ended_at'] != null) {
                      try {
                        final dt = DateTime.parse(item['ended_at']);
                        dateStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      } catch (_) {}
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MobileGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isWinner ? AppColors.success.withOpacity(0.2) : AppColors.danger.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isWinner ? AppColors.success : AppColors.danger,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    isWinner ? Icons.emoji_events : Icons.close,
                                    color: isWinner ? AppColors.success : AppColors.danger,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isWinner ? 'VICTORY' : 'DEFEAT',
                                      style: TextStyle(
                                        color: isWinner ? AppColors.success : AppColors.danger,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'vs $opponent',
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$battleType • $rounds Rounds • $dateStr',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
