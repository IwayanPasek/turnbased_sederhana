// lib/widgets/game/battle_log.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// Panel log pertarungan — menampilkan 3 event terbaru.
class BattleLog extends StatelessWidget {
  final List<String> logs;
  final int maxVisible;

  const BattleLog({super.key, required this.logs, this.maxVisible = 3});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    '⚔️ Pertarungan dimulai...',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: logs.length.clamp(0, maxVisible),
                  itemBuilder: (_, i) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      logs[i],
                      key: ValueKey<String>(logs[i]),
                      style: TextStyle(
                        color: i == 0 ? Colors.white : Colors.white54,
                        fontSize: i == 0 ? 11.5 : 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
