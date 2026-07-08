// lib/widgets/game/turn_banner.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Banner yang menampilkan giliran siapa sekarang.
class TurnBanner extends StatefulWidget {
  final bool isMyTurn;
  final bool isGameOver;

  const TurnBanner({super.key, required this.isMyTurn, required this.isGameOver});

  @override
  State<TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<TurnBanner> with SingleTickerProviderStateMixin {
  late AnimationController _bumpController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bumpController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant TurnBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMyTurn != widget.isMyTurn) {
      _bumpController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _bumpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGameOver) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: widget.isMyTurn
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isMyTurn ? AppColors.gold : AppColors.danger,
            width: 1.5,
          ),
        ),
        child: Text(
          widget.isMyTurn ? '🎯 Giliran kamu — pilih aksi!' : '⏳ Giliran lawan...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.isMyTurn ? AppColors.gold : AppColors.danger,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
