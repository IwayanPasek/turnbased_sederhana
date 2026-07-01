// lib/screens/game/game_screen.dart
// Game screen utama — orchestrator semua widget game
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_state.dart';
import '../../models/player_state.dart';
import '../../providers/game_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/game/player_card.dart';
import '../../widgets/game/turn_banner.dart';
import '../../widgets/game/battle_log.dart';
import '../../widgets/game/skill_grid.dart';
import 'waiting_screen.dart';
import 'game_over_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    // Koneksi WebSocket saat screen dibuka
    Future.microtask(() => gameNotifier.connect());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameNotifier,
      builder: (context, _) {
        if (gameNotifier.isWaiting && !gameNotifier.state.hasError && !gameNotifier.state.hasValue) {
          return _buildWaitingScreen();
        }

        return gameNotifier.state.when(
          loading: () => _buildWaitingScreen(),
          error: (e, _) => _buildErrorScreen(e.toString()),
          data: (gs) => _buildBattleUI(gs, gameNotifier),
        );
      },
    );
  }

  Widget _buildWaitingScreen() {
    return const WaitingScreen();
  }

  Widget _buildBattleUI(GameState gs, GameNotifier notifier) {
    final me      = notifier.myUsername;
    final opName  = gs.opponentOf(me) ?? 'Lawan';
    final myState = gs.playerOf(me) ?? PlayerState.initial();
    final opState = gs.playerOf(opName) ?? PlayerState.initial();
    final isMyTurn  = gs.isMyTurn(me);
    final isGameOver = gs.isGameOver;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: _buildAppBar(gs.turnNumber),
      body: Column(
        children: [
          // Opponent card
          PlayerCard(
            name: opName,
            state: opState,
            isMe: false,
            isCurrentTurn: !isMyTurn && !isGameOver,
          ),

          // Turn banner
          TurnBanner(isMyTurn: isMyTurn, isGameOver: isGameOver),

          // Battle log
          BattleLog(logs: notifier.battleLog),

          // My card
          PlayerCard(
            name: me,
            state: myState,
            isMe: true,
            isCurrentTurn: isMyTurn && !isGameOver,
          ),

          // Skill grid or game-over
          if (isGameOver)
            GameOverScreen(
              message: gs.message,
              myName: me,
              onLeave: () => Navigator.pop(context),
            )
          else
            Expanded(
              child: SkillGrid(
                myState: myState,
                availableActions: gs.availableActions,
                isMyTurn: isMyTurn,
                onSkillTap: (skillId) =>
                    notifier.sendAction(skillId),
              ),
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(int turnNumber) {
    return AppBar(
      backgroundColor: Colors.black87,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u2694\ufe0f ', style: TextStyle(fontSize: 18)),
          Text(
            'Arena',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (turnNumber > 0) ...
            [
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Turn $turnNumber',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildErrorScreen(String msg) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('\u274c', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(msg, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
