// lib/screens/game/game_over_screen.dart
import 'package:flutter/material.dart';

/// Ditampilkan di bagian bawah battle screen saat game selesai.
class GameOverScreen extends StatelessWidget {
  final String message;
  final String myName;
  final VoidCallback onLeave;

  const GameOverScreen({
    super.key,
    required this.message,
    required this.myName,
    required this.onLeave,
  });

  bool get _iWon => message.contains(myName) && message.contains('MENANG');

  @override
  Widget build(BuildContext context) {
    final iWon = _iWon;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: iWon
              ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
              : [const Color(0xFF880000), const Color(0xFF4A0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (iWon ? Colors.amber : Colors.red).withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            iWon ? '\ud83c\udfc6 KAMU MENANG!' : '\ud83d\udc80 KAMU KALAH',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message.split('!').first,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onLeave,
            icon: const Icon(Icons.home_rounded),
            label: const Text('Kembali ke Lobby'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
