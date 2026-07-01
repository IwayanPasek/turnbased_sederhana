// lib/widgets/game/skill_button.dart
import 'package:flutter/material.dart';
import '../../core/constants/skill_constants.dart';

class SkillButton extends StatefulWidget {
  final SkillDef skill;
  final bool isEnabled;
  final int cooldownLeft;
  final bool rageReady;
  final VoidCallback? onTap;

  const SkillButton({
    super.key,
    required this.skill,
    required this.isEnabled,
    this.cooldownLeft = 0,
    this.rageReady = false,
    this.onTap,
  });

  @override
  State<SkillButton> createState() => _SkillButtonState();
}

class _SkillButtonState extends State<SkillButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool get _showCooldown => widget.cooldownLeft > 0;
  bool get _showRageWarn => widget.skill.requiresFullRage && !widget.rageReady && !_showCooldown;

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    final isEnabled = widget.isEnabled;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _pressCtrl.forward() : null,
      onTapUp: isEnabled ? (_) { _pressCtrl.reverse(); widget.onTap?.call(); } : null,
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isEnabled ? skill.color.withValues(alpha: 0.14) : Colors.black38,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled ? skill.color : Colors.white12,
              width: isEnabled ? 1.5 : 1,
            ),
            boxShadow: isEnabled ? [BoxShadow(color: skill.color.withValues(alpha: 0.28), blurRadius: 10, spreadRadius: 1)] : [],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(skill.emoji, style: TextStyle(fontSize: 24, color: isEnabled ? null : Colors.white30)),
                    const SizedBox(height: 3),
                    Text(skill.label, textAlign: TextAlign.center,
                      style: TextStyle(color: isEnabled ? Colors.white : Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(skill.description, textAlign: TextAlign.center,
                      style: TextStyle(color: isEnabled ? Colors.white54 : Colors.white24, fontSize: 8, height: 1.2),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              if (_showCooldown)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.68), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('\u23f3', style: TextStyle(fontSize: 16)),
                        Text('${widget.cooldownLeft}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('turn', style: TextStyle(color: Colors.white60, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              if (_showRageWarn)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.58), borderRadius: BorderRadius.circular(12)),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('\u{1F300}', style: TextStyle(fontSize: 16)),
                        Text('RAGE\nKURANG', textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFAA00FF), fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              if (skill.requiresFullRage)
                Positioned(
                  top: 4, right: 4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFAA00FF),
                      shape: BoxShape.circle,
                      boxShadow: widget.rageReady ? [const BoxShadow(color: Color(0x99AA00FF), blurRadius: 6, spreadRadius: 2)] : [],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
