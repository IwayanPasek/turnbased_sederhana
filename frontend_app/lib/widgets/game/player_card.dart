// lib/widgets/game/player_card.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/player_state.dart';
import 'hp_bar.dart';
import 'rage_bar.dart';
import 'status_badges.dart';
import 'momentum_display.dart';

class PlayerCard extends StatelessWidget {
  final String name;
  final PlayerState state;
  final bool isMe;
  final bool isCurrentTurn;

  const PlayerCard({
    super.key,
    required this.name,
    required this.state,
    required this.isMe,
    required this.isCurrentTurn,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentTurn ? Colors.white10 : Colors.black38,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? (isMe ? AppColors.gold : AppColors.danger) : AppColors.border,
          width: isCurrentTurn ? 2 : 1,
        ),
        boxShadow: isCurrentTurn ? [BoxShadow(
          color: (isMe ? AppColors.gold : AppColors.danger).withValues(alpha: 0.15),
          blurRadius: 12, spreadRadius: 1,
        )] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                isMe ? '\u{1F9D9} $name (Kamu)' : '\u{1F479} $name',
                style: TextStyle(color: isMe ? AppColors.gold : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (isCurrentTurn) ...[const SizedBox(width: 5), const Text('\u25b6', style: TextStyle(color: Colors.greenAccent, fontSize: 11))],
              const Spacer(),
              MomentumDisplay(streak: state.streak, stacks: state.momentumStacks),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('\u2764\ufe0f ', style: TextStyle(fontSize: 11)),
              Expanded(child: HpBar(hp: state.hp, maxHp: state.maxHp)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Text('\u{1F300} ', style: TextStyle(fontSize: 11)),
              Expanded(child: RageBar(rage: state.rage, maxRage: state.maxRage)),
            ],
          ),
          if (state.statusEffects.isNotEmpty) ...[const SizedBox(height: 6), StatusBadges(effects: state.statusEffects)],
        ],
      ),
    );
  }
}
