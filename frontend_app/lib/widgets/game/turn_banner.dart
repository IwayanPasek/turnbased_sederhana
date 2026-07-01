// lib/widgets/game/turn_banner.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Banner yang menampilkan giliran siapa sekarang.
class TurnBanner extends StatelessWidget {
  final bool isMyTurn;
  final bool isGameOver;

  const TurnBanner({super.key, required this.isMyTurn, required this.isGameOver});

  @override
  Widget build(BuildContext context) {
    if (isGameOver) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: isMyTurn
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMyTurn ? AppColors.gold : AppColors.danger,
          width: 1.5,
        ),
      ),
      child: Text(
        isMyTurn ? '🎯 Giliran kamu — pilih aksi!' : '⏳ Giliran lawan...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isMyTurn ? AppColors.gold : AppColors.danger,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
