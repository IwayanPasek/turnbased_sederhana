// lib/widgets/game/momentum_display.dart
import 'package:flutter/material.dart';

/// Menampilkan indikator momentum streak dan stack bonus.
class MomentumDisplay extends StatefulWidget {
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
  State<MomentumDisplay> createState() => _MomentumDisplayState();
}

class _MomentumDisplayState extends State<MomentumDisplay> with SingleTickerProviderStateMixin {
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
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.25), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bumpController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant MomentumDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streak > oldWidget.streak || widget.stacks > oldWidget.stacks) {
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
    if (widget.streak == 0 && widget.stacks == 0) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.streak > 0)
            Text(
              '🔥 Streak: ${widget.streak}',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
            ),
          if (widget.stacks > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                '💢 +${widget.stacks * 15}% DMG (x${widget.stacks})',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
