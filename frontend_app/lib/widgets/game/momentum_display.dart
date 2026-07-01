// lib/widgets/game/momentum_display.dart
import 'package:flutter/material.dart';

/// Menampilkan indikator momentum streak dan stack bonus.
class MomentumDisplay extends StatelessWidget {
  final int streak;
  final int stacks;
  final int maxStacks;

  const MomentumDisplay({
    super.key,
    required this.streak,
    required this.stacks,
    this.maxStacks = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (streak == 0 && stacks == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (streak > 0)
          Text(
            '🔥 Streak: $streak',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
          ),
        if (stacks > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Text(
              '💢 +${stacks * 15}% DMG (x$stacks)',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
