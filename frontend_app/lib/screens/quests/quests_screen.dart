import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/quest_service.dart';
import '../../providers/profile_provider.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  final QuestService _questService = QuestService();
  bool _isLoading = true;
  List<dynamic> _quests = [];

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    setState(() => _isLoading = true);
    try {
      final quests = await _questService.getDailyQuests();
      setState(() {
        _quests = quests;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _claimReward(int questId) async {
    try {
      final res = await _questService.claimQuest(questId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Berhasil klaim hadiah!'),
            backgroundColor: Colors.green,
          ),
        );
        profileNotifier.load(); // Refresh coins/gems
        _loadQuests(); // Refresh status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _buildQuestCard(Map<String, dynamic> quest) {
    final int current = quest['current_progress'] ?? 0;
    final int target = quest['target_value'] ?? 1;
    final bool isCompleted = quest['is_completed'] ?? false;
    final bool isClaimed = quest['is_claimed'] ?? false;
    final double progress = (current / target).clamp(0.0, 1.0);

    return Card(
      color: isCompleted && !isClaimed ? AppColors.gold.withOpacity(0.2) : Colors.black45,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quest['name'],
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              quest['description'],
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      color: isCompleted ? AppColors.gold : AppColors.primary,
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$current / $target',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      quest['reward_type'] == 'gems' ? '💎' : '🪙',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${quest['reward_amount']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (!isCompleted)
                  const ElevatedButton(
                    onPressed: null,
                    child: Text('Belum Selesai'),
                  )
                else if (!isClaimed)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                    onPressed: () => _claimReward(quest['id']),
                    child: const Text('Klaim Hadiah', style: TextStyle(color: Colors.black)),
                  )
                else
                  const Text(
                    'Diklaim ✓',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Misi Harian'),
        backgroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _quests.isEmpty
              ? const Center(child: Text('Belum ada misi harian'))
              : ListView.builder(
                  itemCount: _quests.length,
                  itemBuilder: (context, index) {
                    return _buildQuestCard(_quests[index]);
                  },
                ),
    );
  }
}
