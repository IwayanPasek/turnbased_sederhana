// lib/widgets/game/status_badges.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/player_state.dart';

/// Menampilkan row badge untuk setiap status effect aktif.
class StatusBadges extends StatelessWidget {
  final List<StatusEffect> effects;

  const StatusBadges({super.key, required this.effects});

  @override
  Widget build(BuildContext context) {
    if (effects.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: effects.map(_buildBadge).toList(),
    );
  }

  Widget _buildBadge(StatusEffect effect) {
    final color = AppColors.fromStatus(effect.name);
    final emoji = _emoji(effect.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$emoji ${effect.name} (${effect.turnsLeft})',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _emoji(String name) => switch (name.toUpperCase()) {
        'BURN'   => '🔥',
        'POISON' => '☠️',
        'STUN'   => '⚡',
        'SHIELD' => '🛡️',
        'FREEZE' => '🧊',
        'REGEN'  => '💖',
        _        => '❓',
      };
}
