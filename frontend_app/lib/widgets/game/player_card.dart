// lib/widgets/game/player_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/player_state.dart';
import 'hp_bar.dart';
import 'rage_bar.dart';
import 'status_badges.dart';
import 'momentum_display.dart';
import 'vfx_overlay.dart';

class PlayerCard extends StatefulWidget {
  final String name;
  final PlayerState state;
  final bool isMe;
  final bool isCurrentTurn;
  final String? animationTrigger; // Format e.g., "hit_1", "attack_2"
  final List<VFXEffect> vfxEffects;

  const PlayerCard({
    super.key,
    required this.name,
    required this.state,
    required this.isMe,
    required this.isCurrentTurn,
    this.animationTrigger,
    this.vfxEffects = const [],
  });

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late AnimationController _dashController;
  late Animation<double> _dashAnimation;

  @override
  void initState() {
    super.initState();
    // Shake Animation (Hit)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    // Dash Animation (Attack)
    _dashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dashAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: widget.isMe ? -20.0 : 20.0), weight: 3),
      TweenSequenceItem(tween: Tween(begin: widget.isMe ? -20.0 : 20.0, end: 0.0), weight: 7),
    ]).animate(CurvedAnimation(parent: _dashController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(PlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationTrigger != oldWidget.animationTrigger && widget.animationTrigger != null) {
      if (widget.animationTrigger!.startsWith('hit')) {
        _shakeController.forward(from: 0);
      } else if (widget.animationTrigger!.startsWith('attack')) {
        _dashController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _dashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isCurrentTurn
        ? (widget.isMe ? AppColors.gold : AppColors.danger)
        : AppColors.border;
    final glowColor = widget.isMe ? AppColors.gold : AppColors.danger;

    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _dashController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _shakeAnimation.value,
            _dashAnimation.value,
          ),
          child: child,
        );
      },
      child: VFXOverlay(
        effects: widget.vfxEffects,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _shakeController.isAnimating ? AppColors.danger : borderColor,
              width: widget.isCurrentTurn || _shakeController.isAnimating ? 2 : 1,
            ),
            boxShadow: widget.isCurrentTurn
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _shakeController.isAnimating 
                      ? AppColors.danger.withValues(alpha: 0.3)
                      : (widget.isCurrentTurn
                          ? glowColor.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.isMe ? '🧙 ${widget.name} (Kamu)' : '👹 ${widget.name}',
                          style: TextStyle(
                            color: widget.isMe ? AppColors.gold : AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.isCurrentTurn) ...[
                          const SizedBox(width: 5),
                          const Text('▶',
                              style: TextStyle(
                                  color: Colors.greenAccent, fontSize: 11)),
                        ],
                        const Spacer(),
                        MomentumDisplay(
                            streak: widget.state.streak,
                            stacks: widget.state.momentumStacks),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('❤️ ', style: TextStyle(fontSize: 11)),
                        Expanded(
                            child: HpBar(hp: widget.state.hp, maxHp: widget.state.maxHp)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Text('🌀 ', style: TextStyle(fontSize: 11)),
                        Expanded(
                            child: RageBar(
                                rage: widget.state.rage, maxRage: widget.state.maxRage)),
                      ],
                    ),
                    if (widget.state.statusEffects.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      StatusBadges(effects: widget.state.statusEffects),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
