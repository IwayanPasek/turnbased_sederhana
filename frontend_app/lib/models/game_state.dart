// lib/models/game_state.dart
import 'player_state.dart';

/// Representasi lengkap state game dari WebSocket
class GameState {
  final String turn;
  final int turnNumber;
  final Map<String, PlayerState> players;
  final List<String> availableActions;
  final String message;
  final bool isGameOver;

  const GameState({
    required this.turn,
    required this.turnNumber,
    required this.players,
    required this.availableActions,
    required this.message,
    required this.isGameOver,
  });

  factory GameState.initial() => const GameState(
        turn: '',
        turnNumber: 0,
        players: {},
        availableActions: [],
        message: '',
        isGameOver: false,
      );

  factory GameState.fromJson(Map<String, dynamic> json) {
    final playersRaw = json['players'] as Map<String, dynamic>? ?? {};
    final msg = json['message'] as String? ?? '';
    return GameState(
      turn:             json['turn'] as String? ?? '',
      turnNumber:       (json['turn_number'] as num?)?.toInt() ?? 0,
      players:          playersRaw.map(
        (k, v) => MapEntry(k, PlayerState.fromJson(v as Map<String, dynamic>)),
      ),
      availableActions: List<String>.from(
        json['available_actions'] as List<dynamic>? ?? [],
      ),
      message:   msg,
      isGameOver: msg.contains('GAME OVER'),
    );
  }

  PlayerState? playerOf(String username)  => players[username];

  String? opponentOf(String username) =>
      players.keys.firstWhere((k) => k != username, orElse: () => '');

  bool isMyTurn(String username) => turn == username;

  bool canUse(String username, String skillId) =>
      availableActions.contains(skillId);
}
