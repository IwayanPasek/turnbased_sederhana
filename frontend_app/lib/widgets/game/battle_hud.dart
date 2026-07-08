import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/player_state.dart';
import 'hp_bar.dart';
import 'rage_bar.dart';
import 'status_badges.dart';

class BattleHUD extends StatelessWidget {
  final String myName;
  final String enemyName;
  final String? myTitle;
  final String? enemyTitle;
  final PlayerState myState;
  final PlayerState enemyState;
  final bool isMyTurn;

  const BattleHUD({
    super.key,
    required this.myName,
    required this.enemyName,
    this.myTitle,
    this.enemyTitle,
    required this.myState,
    required this.enemyState,
    required this.isMyTurn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: const Border(
          bottom: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player 1 (Left)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  myName,
                  style: TextStyle(
                    color: isMyTurn ? AppColors.gold : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (myTitle != null && myTitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      myTitle!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                HpBar(hp: myState.hp, maxHp: myState.maxHp),
                const SizedBox(height: 4),
                RageBar(rage: myState.rage, maxRage: myState.maxRage),
                const SizedBox(height: 6),
                StatusBadges(effects: myState.statusEffects),
              ],
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Player 2 (Right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  enemyName,
                  style: TextStyle(
                    color: !isMyTurn ? AppColors.gold : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (enemyTitle != null && enemyTitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      enemyTitle!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                // Notice the Directionality widget to reverse the bars (wait, HpBar doesn't have isReversed by default)
                // We will wrap them in Directionality for right-to-left fill
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: HpBar(hp: enemyState.hp, maxHp: enemyState.maxHp),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: RageBar(rage: enemyState.rage, maxRage: enemyState.maxRage),
                ),
                const SizedBox(height: 6),
                StatusBadges(effects: enemyState.statusEffects),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
