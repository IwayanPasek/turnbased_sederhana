// lib/screens/practice/practice_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/skill_constants.dart';
import '../../services/auth_service.dart';
import '../../services/practice_service.dart';
import '../../models/player_state.dart';
import '../../widgets/game/skill_grid.dart';
import '../../widgets/game/player_card.dart';
import '../../widgets/game/battle_log.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _auth = AuthService();
  final _practice = PracticeService();

  String _username = 'Pemain';
  final String _botName = 'Bot Latihan';

  PlayerState _myState = PlayerState.initial();
  PlayerState _botState = PlayerState.initial();
  List<String> _battleLogs = [];

  bool _isMyTurn = true;
  bool _actionLocked = false;
  bool _isGameOver = false;
  String _statusMessage = 'Giliran Anda';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final name = await _auth.getUsername();
    if (name != null && mounted) {
      setState(() {
        _username = name;
      });
    }
  }

  void _resetMatch() {
    setState(() {
      _myState = PlayerState.initial();
      _botState = PlayerState.initial();
      _battleLogs = [];
      _isMyTurn = true;
      _actionLocked = false;
      _isGameOver = false;
      _statusMessage = 'Latihan Diulang. Giliran Anda!';
    });
  }

  Map<String, dynamic> _stateToMap(PlayerState state) {
    return {
      'hp': state.hp,
      'rage': state.rage,
      'status_effects': state.statusEffects.map((e) => {
        'name': e.name,
        'turns_left': e.turnsLeft,
        'value': e.value,
      }).toList(),
      'cooldowns': state.cooldowns,
    };
  }

  Future<void> _performAction(String actionId) async {
    if (!_isMyTurn || _actionLocked || _isGameOver) return;

    setState(() {
      _actionLocked = true;
      _statusMessage = 'Menjalankan aksi...';
    });

    final resp = await _practice.simulateTurn(
      action: actionId,
      player1State: _stateToMap(_myState),
      player2State: _stateToMap(_botState),
    );

    if (!mounted) return;

    if (resp != null) {
      final p1Map = resp['player1'] as Map<String, dynamic>;
      final p2Map = resp['player2'] as Map<String, dynamic>;
      final msgs = List<String>.from(resp['messages'] ?? []);

      setState(() {
        _myState = PlayerState.fromJson(p1Map);
        _botState = PlayerState.fromJson(p2Map);
        _battleLogs.insertAll(0, msgs.reversed);

        if (_myState.hp <= 0) {
          _isGameOver = true;
          _statusMessage = 'GAME OVER - Anda Kalah!';
        } else if (_botState.hp <= 0) {
          _isGameOver = true;
          _statusMessage = 'LATIHAN SELESAI - Anda Menang!';
        } else {
          _statusMessage = 'Giliran Anda';
        }
      });
    } else {
      setState(() {
        _statusMessage = 'Error memanggil server!';
      });
    }

    setState(() {
      _actionLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Generate available actions just like backend would (all keys in kSkillMap)
    final availableActions = kSkillMap.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Mode Latihan (Simulasi)'),
        backgroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Opponent card
            PlayerCard(
              name: _botName,
              state: _botState,
              isMe: false,
              isCurrentTurn: !_isMyTurn && !_isGameOver,
            ),

            // Turn banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppColors.bgCard,
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Battle log
            BattleLog(logs: _battleLogs),

            // My card
            PlayerCard(
              name: _username,
              state: _myState,
              isMe: true,
              isCurrentTurn: _isMyTurn && !_isGameOver,
            ),

            // Skill grid or controls
            if (_isGameOver)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Latihan Selesai',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _resetMatch,
                        child: const Text('ULANG LATIHAN'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('KEMBALI'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SkillGrid(
                  myState: _myState,
                  availableActions: availableActions,
                  isMyTurn: _isMyTurn && !_actionLocked,
                  onSkillTap: _performAction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
