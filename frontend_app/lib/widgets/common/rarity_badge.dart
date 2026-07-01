// lib/widgets/rarity_badge.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class RarityBadge extends StatefulWidget {
  final String rarity;
  final double size;
  final bool isSpecial; // override: true for Wrath of the Cow tier
  const RarityBadge({
    super.key,
    required this.rarity,
    this.size = 18,
    this.isSpecial = false,
  });

  @override
  State<RarityBadge> createState() => _RarityBadgeState();
}

class _RarityBadgeState extends State<RarityBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    if (_isLegendaryOrSpecial) {
      _ctrl.repeat();
    }
  }

  bool get _isLegendaryOrSpecial =>
      widget.isSpecial ||
      widget.rarity.toLowerCase() == 'legendary' ||
      widget.rarity.toLowerCase().contains('unmatched');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorForRarity(String r) {
    switch (r.toLowerCase()) {
      case 'common':
        return const Color(0xFF94A3B8);
      case 'uncommon':
        return AppColors.accent;
      case 'rare':
        return const Color(0xFF60A5FA); // blue
      case 'epic':
        return const Color(0xFFA855F7); // purple
      case 'legendary':
        return AppColors.warning; // amber/gold
      default:
        return AppColors.warning;
    }
  }

  String _labelForRarity(String r) {
    switch (r.toLowerCase()) {
      case 'common':
        return 'COMMON';
      case 'uncommon':
        return 'UNCOMMON';
      case 'rare':
        return 'RARE';
      case 'epic':
        return 'EPIC';
      case 'legendary':
        return 'LEGENDARY';
      default:
        // Handle 'unmatched_unrivaled_immeasured' or other long strings
        if (r.toLowerCase().contains('unmatched')) {
          return '✦ UNMATCHED ✦';
        }
        return r.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLegendaryOrSpecial) {
      return AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          // Rainbow-gold shimmer cycle
          final colors = [
            const Color(0xFFFFD700),
            const Color(0xFFFF8C00),
            const Color(0xFFFF4500),
            const Color(0xFFFF00FF),
            const Color(0xFF7B2FF7),
            const Color(0xFF00BFFF),
            const Color(0xFF00FF7F),
            const Color(0xFFFFD700),
          ];
          final gradStart = AlignmentDirectional(
            -1.5 + t * 3,
            -1,
          );
          final gradEnd = AlignmentDirectional(
            1.5 + t * 3,
            1,
          );
          final label = widget.rarity.toLowerCase().contains('unmatched')
              ? '✦ UNMATCHED ✦'
              : 'LEGENDARY';
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.size * 0.55,
              vertical: widget.size * 0.22,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: gradStart,
                end: gradEnd,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(widget.size * 0.7),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.55 + 0.3 * t),
                  blurRadius: 10 + 8 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: widget.size, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: widget.size * 0.58,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Normal rarity badge
    final color = _colorForRarity(widget.rarity);
    final label = _labelForRarity(widget.rarity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.size * 0.5,
        vertical: widget.size * 0.22,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(widget.size * 0.7),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_fix_high, size: widget.size, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: widget.size * 0.58,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
