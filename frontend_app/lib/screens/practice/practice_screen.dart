import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/practice_service.dart';
import '../../services/shop_service.dart';
import '../../models/player_state.dart';
import '../../widgets/game/skill_grid.dart';
import '../../widgets/game/battle_stage.dart';
import '../../widgets/game/battle_log.dart';
import '../../widgets/game/vfx_overlay.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final _auth = AuthService();
  final _practice = PracticeService();
  final _shop = ShopService();

  String _username = 'Pemain';
  final String _botName = 'Bot Latihan';

  PlayerState _myState = PlayerState.initial();
  PlayerState _botState = PlayerState.initial();
  List<String> _battleLogs = [];
  List<String> _unlockedSkills = ['attack', 'heal', 'ultimate'];

  bool _isMyTurn = true;
  bool _actionLocked = false;
  bool _isGameOver = false;
  String _statusMessage = 'Giliran Anda';

  @override
  void initState() {
    super.initState();
    _loadUserAndSkills();
  }

  void _loadUserAndSkills() async {
    final name = await _auth.getUsername();
    if (name != null && mounted) {
      setState(() {
        _username = name;
      });
    }

    // Load inventory to determine granted skills AND stat boosts
    final invList = await _shop.fetchInventory();
    if (invList != null && mounted) {
      final Set<String> newSkills = {'attack', 'heal', 'ultimate'};
      int bonusHp = 0;

      for (final item in invList) {
        final equipped = item['is_equipped'] == true || item['is_equipped'] == 1;
        if (!equipped) continue;

        // Kumpulkan skill dari item
        if (item['granted_skill'] != null && item['granted_skill'].toString().isNotEmpty) {
          newSkills.add(item['granted_skill'].toString());
        }

        // BUG-11 fix: hitung HP bonus dari item yang di-equip
        final statType = item['stat_type'] as String? ?? '';
        final baseBoost = (item['base_stat'] as num?)?.toInt() ?? (item['base_stat_boost'] as num?)?.toInt() ?? 0;
        final level = (item['current_level'] as num?)?.toInt() ?? 1;
        if (statType == 'hp') {
          bonusHp += baseBoost * level;
        }
      }

      final initialHp = 150 + bonusHp; // kMaxHp + bonus dari item hp
      setState(() {
        _unlockedSkills = newSkills.toList();
        _myState = PlayerState(
          hp: initialHp,
          maxHp: initialHp,
          rage: 0,
          maxRage: 100,
          statusEffects: const [],
          cooldowns: const {},
          streak: 0,
          momentumStacks: 0,
        );
      });
    }
  }

  void _resetMatch() {
    // Pertahankan maxHp yang sudah dihitung dari item — jangan reset ke 150
    final correctMaxHp = _myState.maxHp;
    setState(() {
      _myState = PlayerState(
        hp: correctMaxHp,
        maxHp: correctMaxHp,
        rage: 0,
        maxRage: 100,
        statusEffects: const [],
        cooldowns: const {},
        streak: 0,
        momentumStacks: 0,
      );
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
      'max_hp': state.maxHp,
      'rage': state.rage,
      'max_rage': state.maxRage,
      'status_effects': state.statusEffects.map((e) => {
        'name': e.name,
        'turns_left': e.turnsLeft,
        'value': e.value,
      }).toList(),
      'cooldowns': state.cooldowns,
      'bonus_attack': state.bonusAttack,
      'crit_chance': state.critChance,
      'dodge_chance': state.dodgeChance,
      'rage_gen': state.rageGen,
      'granted_skills': state.grantedSkills,
    };
  }

  List<Map<String, dynamic>> _lastAnimationEvents = [];
  int _turnCounter = 0;

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
      final events = List<Map<String, dynamic>>.from(resp['animation_events'] ?? []);

      setState(() {
        _myState = PlayerState.fromJson(p1Map);
        _botState = PlayerState.fromJson(p2Map);
        _battleLogs.insertAll(0, msgs.reversed);
        _lastAnimationEvents = events;
        _turnCounter++;
        _actionLocked = false;

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
        _actionLocked = false;
      });
    }
  }

  String? _getAnimationTrigger(String playerName) {
    if (_lastAnimationEvents.isEmpty) return null;
    
    for (var event in _lastAnimationEvents) {
      if (event['source'] == playerName) {
        String type = event['type'];
        if (type == 'ATTACK_PHYSICAL' || type == 'ATTACK_HEAVY' || type == 'ULTIMATE') {
          return 'attack_slash_$_turnCounter';
        } else if (type == 'ATTACK_MAGIC') {
          return 'attack_fire_$_turnCounter';
        } else if (type == 'STUN') {
          return 'attack_stun_$_turnCounter';
        } else if (type == 'FREEZE') {
          return 'attack_ice_$_turnCounter';
        }
      }
      
      if (event['target'] == playerName) {
        String type = event['type'];
        if (type.startsWith('ATTACK_') || type == 'ULTIMATE' || type == 'STUN' || type == 'FREEZE') {
          return 'hit_$_turnCounter';
        }
      }
    }
    return null;
  }

  List<VFXEffect> _getVfxEffects(String playerName) {
    List<VFXEffect> effects = [];
    final turnId = _turnCounter.toString();
    
    for (var event in _lastAnimationEvents) {
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

  @override
  Widget build(BuildContext context) {
    // Generate available actions just like backend would
    final availableActions = _unlockedSkills.where((skill) {
      if (_myState.cooldownOf(skill) > 0) return false;
      if (skill == 'ultimate' && !_myState.isRageFull) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Mode Latihan (Simulasi)'),
        backgroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isGameOver)
            IconButton(
              icon: const Icon(Icons.flag, color: Colors.white70),
              tooltip: 'Menyerah',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.bgDark,
                    title: const Text('Menyerah?', style: TextStyle(color: Colors.white)),
                    content: const Text('Apakah Anda yakin ingin menyerah dalam mode latihan?', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _myState = PlayerState(
                              hp: 0,
                              maxHp: _myState.maxHp,
                              rage: _myState.rage,
                              maxRage: _myState.maxRage,
                              statusEffects: _myState.statusEffects,
                              cooldowns: _myState.cooldowns,
                              streak: _myState.streak,
                              momentumStacks: _myState.momentumStacks,
                              title: _myState.title,
                              avatarStyle: _myState.avatarStyle,
                            );
                            _isGameOver = true;
                            _statusMessage = 'GAME OVER - Anda Menyerah!';
                          });
                        },
                        child: const Text('Menyerah', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            // Left side: The Battle Stage
            Expanded(
              flex: 3,
              child: BattleStage(
                myName: _username,
                enemyName: _botName,
                myTitle: _myState.title,
                enemyTitle: _botState.title,
                myState: _myState,
                enemyState: _botState,
                isMyTurn: _isMyTurn && !_isGameOver,
                myAnimationTrigger: _getAnimationTrigger(_username),
                enemyAnimationTrigger: _getAnimationTrigger(_botName),
                myVfxEffects: _getVfxEffects(_username),
                enemyVfxEffects: _getVfxEffects(_botName),
              ),
            ),

            // Right side: Log & Actions
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Turn info
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    width: double.infinity,
                    color: Colors.black45,
                    child: Center(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Battle log
                  Expanded(
                    child: BattleLog(logs: _battleLogs),
                  ),

                  // Skill grid or controls
                  if (_isGameOver)
                    Container(
                      padding: const EdgeInsets.all(20),
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
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              ),
                              onPressed: _resetMatch,
                              child: const Text('Ulangi Latihan'),
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
          ],
        ),
      ),
    );
  }
}
