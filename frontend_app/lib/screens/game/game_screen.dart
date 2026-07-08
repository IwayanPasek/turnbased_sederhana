// lib/screens/game/game_screen.dart
// Game screen utama — orchestrator semua widget game
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_state.dart';
import '../../models/player_state.dart';
import '../../providers/game_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/game/battle_stage.dart';
import '../../widgets/game/turn_banner.dart';
import '../../widgets/game/battle_log.dart';
import '../../widgets/game/skill_grid.dart';
import '../../widgets/game/vfx_overlay.dart';
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
  void dispose() {
    gameNotifier.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameNotifier,
      builder: (context, _) {
        // Bug fix #10: isWaiting adalah primary flag — cek ini dulu
        // sebelum state.when agar tidak merender battle UI saat masih waiting
        if (gameNotifier.isWaiting) {
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

  String? _getAnimationTrigger(String playerName, GameState gs, List<String> logs) {
    if (gs.animationEvents.isEmpty) return null;
    
    for (var event in gs.animationEvents) {
      if (event['source'] == playerName) {
        String type = event['type'];
        if (type == 'ATTACK_PHYSICAL' || type == 'ATTACK_HEAVY' || type == 'ULTIMATE') {
          return 'attack_slash_${gs.turnNumber}';
        } else if (type == 'ATTACK_FIRE_BLAST' || type == 'ATTACK_MAGIC') {
          return 'attack_fire_${gs.turnNumber}';
        } else if (type == 'STUN' || type == 'ATTACK_STUN_BOLT') {
          return 'attack_stun_${gs.turnNumber}';
        } else if (type == 'FREEZE' || type == 'ATTACK_FROST_NOVA') {
          return 'attack_ice_${gs.turnNumber}';
        } else if (type == 'ATTACK_POISON_DART') {
          return 'attack_poison_${gs.turnNumber}';
        } else if (type == 'ATTACK_WATER_PULSE') {
          return 'attack_ice_${gs.turnNumber}'; // For water pulse, use ice/water
        } else if (type == 'SHIELD') {
          return 'attack_shield_${gs.turnNumber}';
        } else if (type == 'HEAL') {
          return 'attack_heal_${gs.turnNumber}';
        }
      }
      
      if (event['target'] == playerName) {
        String type = event['type'];
        if (type.startsWith('ATTACK_') || type == 'ULTIMATE' || type == 'STUN' || type == 'FREEZE') {
          return 'hit_${gs.turnNumber}';
        }
      }
    }
    return null;
  }

  List<VFXEffect> _getVfxEffects(String playerName, GameState gs, List<String> logs) {
    List<VFXEffect> effects = [];
    final turnId = gs.turnNumber.toString();
    
    for (var event in gs.animationEvents) {
      if (event['target'] == playerName && event['value'] != null && event['value'] > 0) {
        if (event['type'] == 'HEAL') {
          effects.add(VFXEffect(id: 'heal_$turnId', text: '+${event['value']}', color: Colors.greenAccent));
        } else if (event['type'].startsWith('ATTACK_') || event['type'] == 'ULTIMATE') {
          effects.add(VFXEffect(id: 'dmg_$turnId', text: '-${event['value']}', color: AppColors.danger));
          
          if (event['is_critical'] == true) {
            effects.add(VFXEffect(id: 'crit_$turnId', text: '💥', color: Colors.transparent, isIcon: true));
          }
        }
      }
      
      if (event['source'] == playerName && event['type'] == 'EVASION') {
         effects.add(VFXEffect(id: 'dodge_$turnId', text: 'DODGE!', color: Colors.grey));
      }
      
      if (event['target'] == playerName && event['type'] == 'STUN') {
         effects.add(VFXEffect(id: 'stun_$turnId', text: '⚡', color: Colors.transparent, isIcon: true));
      }
      
      if (event['target'] == playerName && event['type'] == 'FREEZE') {
         effects.add(VFXEffect(id: 'ice_$turnId', text: '🧊', color: Colors.transparent, isIcon: true));
      }
      
      if (event['source'] == playerName && event['type'] == 'SHIELD') {
         effects.add(VFXEffect(id: 'shield_$turnId', text: '🛡️', color: Colors.transparent, isIcon: true));
      }
    }

    return effects;
  }

  Widget _buildBattleUI(GameState gs, GameNotifier notifier) {
    final me = notifier.myUsername;
    final opName = gs.opponentOf(me) ?? 'Lawan';
    final myState = gs.playerOf(me) ?? PlayerState.initial();
    final opState = gs.playerOf(opName) ?? PlayerState.initial();
    final isMyTurn = gs.isMyTurn(me);
    final isGameOver = gs.isGameOver;
    final logs = notifier.battleLog;

    return Scaffold(
      appBar: _buildAppBar(gs.turnNumber, notifier, context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1a0f2e),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Row(
          children: [
            // Left side: The Battle Stage
            Expanded(
              flex: 3,
              child: BattleStage(
                myName: me,
                enemyName: opName,
                myTitle: myState.title,
                enemyTitle: opState.title,
                myState: myState,
                enemyState: opState,
                isMyTurn: isMyTurn && !isGameOver,
                myAnimationTrigger: _getAnimationTrigger(me, gs, logs),
                enemyAnimationTrigger: _getAnimationTrigger(opName, gs, logs),
                myVfxEffects: _getVfxEffects(me, gs, logs),
                enemyVfxEffects: _getVfxEffects(opName, gs, logs),
              ),
            ),
            
            // Right side: Log & Actions
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Turn banner
                  TurnBanner(isMyTurn: isMyTurn, isGameOver: isGameOver),

                  // Battle log
                  Expanded(
                    flex: 1,
                    child: BattleLog(logs: logs),
                  ),

                  // Skill grid or game-over
                  if (isGameOver)
                    Expanded(
                      flex: 1,
                      child: GameOverScreen(
                        message: gs.message,
                        myName: me,
                        onLeave: () => Navigator.pop(context),
                      ),
                    )
                  else
                    Expanded(
                      flex: 1,
                      child: SkillGrid(
                        myState: myState,
                        availableActions: gs.availableActions,
                        isMyTurn: isMyTurn,
                        onSkillTap: (skillId) => notifier.sendAction(skillId),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(int turnNumber, dynamic notifier, BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
          tooltip: 'Kirim Emote',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.bgDark,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) {
                final emotes = ['Halo!', 'GG!', 'Oops..', 'Wkwk', 'Nice!', 'Ampun Bang'];
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pilih Emote', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: emotes.map((e) => ActionChip(
                          label: Text(e),
                          backgroundColor: Colors.white12,
                          labelStyle: const TextStyle(color: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            notifier.sendAction('emote:$e');
                          },
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.flag, color: Colors.white70),
          tooltip: 'Menyerah',
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.bgDark,
                title: const Text('Menyerah?', style: TextStyle(color: Colors.white)),
                content: const Text('Apakah Anda yakin ingin menyerah? Anda akan otomatis kalah dan kehilangan poin MMR.', style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(ctx);
                      notifier.sendAction('surrender');
                    },
                    child: const Text('Menyerah', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚔️ ', style: TextStyle(fontSize: 18)),
          Text(
            'Arena',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (turnNumber > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Turn $turnNumber',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1a0f2e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❌', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(msg,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
