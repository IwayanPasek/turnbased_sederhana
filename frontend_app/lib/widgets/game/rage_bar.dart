// lib/widgets/game/rage_bar.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Progress bar RAGE dengan glow effect saat penuh.
class RageBar extends StatelessWidget {
  final int rage;
  final int maxRage;

  const RageBar({super.key, required this.rage, required this.maxRage});

  @override
  Widget build(BuildContext context) {
    final ratio  = maxRage > 0 ? (rage / maxRage).clamp(0.0, 1.0) : 0.0;
    final isFull = rage >= maxRage;
    final color  = isFull ? AppColors.rageReady : AppColors.rageFill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: isFull
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.rageGlow,
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ],
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: ratio, end: ratio),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              '$rage / $maxRage RAGE',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            if (isFull) ...[
              const SizedBox(width: 4),
              const Text(
                '💥 ULTIMATE SIAP!',
                style: TextStyle(
                  color: AppColors.rageReady,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
