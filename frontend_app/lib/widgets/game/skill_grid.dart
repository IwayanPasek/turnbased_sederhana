// lib/widgets/game/skill_grid.dart
import 'package:flutter/material.dart';
import '../../core/constants/skill_constants.dart';
import '../../models/player_state.dart';
import 'skill_button.dart';

class SkillGrid extends StatelessWidget {
  final PlayerState myState;
  final List<String> availableActions;
  final bool isMyTurn;
  final void Function(String skillId) onSkillTap;

  const SkillGrid({
    super.key,
    required this.myState,
    required this.availableActions,
    required this.isMyTurn,
    required this.onSkillTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 0.74,
      children: kSkills.map((skill) {
        final cd = myState.cooldownOf(skill.id);
        final isAvail = availableActions.contains(skill.id);
        final enabled = isMyTurn && isAvail;
        return SkillButton(
          skill: skill,
          isEnabled: enabled,
          cooldownLeft: cd,
          rageReady: myState.isRageFull,
          onTap: enabled ? () => onSkillTap(skill.id) : null,
        );
      }).toList(),
    );
  }
}
