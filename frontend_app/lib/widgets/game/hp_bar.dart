// lib/widgets/game/hp_bar.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Progress bar HP dengan warna dinamis berdasarkan rasio.
class HpBar extends StatelessWidget {
  final int hp;
  final int maxHp;
  final bool showLabel;
  final double height;

  const HpBar({
    super.key,
    required this.hp,
    required this.maxHp,
    this.showLabel = true,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final color = AppColors.fromHpRatio(ratio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                // Background
                Container(color: Colors.white12),
                
                // Trailing bar (slowly catches up to current ratio)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(color: Colors.white.withOpacity(0.4)),
                ),
                
                // Main bar (moves fast)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(color: color),
                ),
              ],
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 2),
          Text(
            '$hp / $maxHp HP',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ],
    );
  }
}
