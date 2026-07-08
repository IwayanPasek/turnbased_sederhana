import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/mobile_glass_card.dart';

class AttributesScreen extends StatefulWidget {
  const AttributesScreen({super.key});

  @override
  State<AttributesScreen> createState() => _AttributesScreenState();
}

class _AttributesScreenState extends State<AttributesScreen> {
  final _auth = AuthService();
  bool _loading = true;
  int _availablePoints = 0;
  int _strength = 0;
  int _agility = 0;
  int _intelligence = 0;

  @override
  void initState() {
    super.initState();
    _loadAttributes();
  }

  Future<void> _loadAttributes() async {
    setState(() => _loading = true);
    final attrs = await _auth.getAttributes();
    if (attrs != null) {
      setState(() {
        _availablePoints = attrs['available_points'] ?? 0;
        _strength = attrs['strength'] ?? 0;
        _agility = attrs['agility'] ?? 0;
        _intelligence = attrs['intelligence'] ?? 0;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _allocate(String statName) async {
    if (_availablePoints <= 0) return;
    
    // Optimistic UI update
    setState(() {
      _availablePoints -= 1;
      if (statName == 'strength') _strength += 1;
      if (statName == 'agility') _agility += 1;
      if (statName == 'intelligence') _intelligence += 1;
    });

    final success = await _auth.allocateAttribute(statName);
    if (!success) {
      // Revert if failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengalokasikan poin!'), backgroundColor: AppColors.danger),
        );
      }
      _loadAttributes(); // Reload actual state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Atribut Karakter'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Poin Tersedia',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            '$_availablePoints',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Distribusi Atribut',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildAttributeRow(
                    'Strength (STR)', 
                    'Meningkatkan Physical Attack', 
                    _strength, 
                    'strength', 
                    Icons.sports_martial_arts, 
                    AppColors.danger
                  ),
                  const SizedBox(height: 12),
                  _buildAttributeRow(
                    'Agility (AGI)', 
                    'Meningkatkan Kecepatan & Hindaran', 
                    _agility, 
                    'agility', 
                    Icons.speed, 
                    AppColors.success
                  ),
                  const SizedBox(height: 12),
                  _buildAttributeRow(
                    'Intelligence (INT)', 
                    'Meningkatkan Magic Damage & Mana', 
                    _intelligence, 
                    'intelligence', 
                    Icons.psychology, 
                    AppColors.primary
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAttributeRow(
    String title, String desc, int value, String statName, IconData icon, Color color
  ) {
    return MobileGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _availablePoints > 0 ? () => _allocate(statName) : null,
              icon: const Icon(Icons.add_circle),
              color: AppColors.gold,
              iconSize: 32,
              disabledColor: Colors.white24,
            )
          ],
        ),
      ),
    );
  }
}
