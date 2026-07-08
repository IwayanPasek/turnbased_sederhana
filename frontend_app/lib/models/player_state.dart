// lib/models/player_state.dart

/// Representasi immutable state pemain dalam satu turn.
/// Diparsing dari WebSocket game_state JSON.
class StatusEffect {
  final String name;
  final int turnsLeft;
  final int value;

  const StatusEffect({
    required this.name,
    required this.turnsLeft,
    required this.value,
  });

  factory StatusEffect.fromJson(Map<String, dynamic> json) => StatusEffect(
        name:      json['name'] as String,
        turnsLeft: (json['turns_left'] as num).toInt(),
        value:     (json['value'] as num?)?.toInt() ?? 0,
      );
}

class PlayerState {
  final int hp;
  final int maxHp;
  final int rage;
  final int maxRage;
  final List<StatusEffect> statusEffects;
  final Map<String, int> cooldowns; // {skill_id: turns_remaining}
  final int streak;
  final int momentumStacks;
  final String title;
  final String avatarStyle;
  
  // Stats tambahan untuk practice mode
  final int bonusAttack;
  final double critChance;
  final double dodgeChance;
  final int rageGen;
  final List<String> grantedSkills;

  const PlayerState({
    required this.hp,
    required this.maxHp,
    required this.rage,
    required this.maxRage,
    required this.statusEffects,
    required this.cooldowns,
    required this.streak,
    required this.momentumStacks,
    this.title = "",
    this.avatarStyle = "default",
    this.bonusAttack = 0,
    this.critChance = 0.0,
    this.dodgeChance = 0.0,
    this.rageGen = 8,
    this.grantedSkills = const [],
  });

  factory PlayerState.initial() => const PlayerState(
        hp: 150,
        maxHp: 150,
        rage: 0,
        maxRage: 100,
        statusEffects: [],
        cooldowns: {},
        streak: 0,
        momentumStacks: 0,
        avatarStyle: "default",
        bonusAttack: 0,
        critChance: 0.0,
        dodgeChance: 0.0,
        rageGen: 8,
        grantedSkills: const [],
      );

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        hp:             (json['hp'] as num?)?.toInt() ?? 0,
        maxHp:          (json['max_hp'] as num?)?.toInt() ?? 150,
        rage:           (json['rage'] as num?)?.toInt() ?? 0,
        maxRage:        (json['max_rage'] as num?)?.toInt() ?? 100,
        statusEffects:  (json['status_effects'] as List<dynamic>? ?? [])
            .map((e) => StatusEffect.fromJson(e as Map<String, dynamic>))
            .toList(),
        cooldowns: (json['cooldowns'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
        streak:         (json['streak'] as num?)?.toInt() ?? 0,
        momentumStacks: (json['momentum_stacks'] as num?)?.toInt() ?? 0,
        title:          json['title'] as String? ?? "",
        avatarStyle:    json['avatar_style'] as String? ?? "default",
        bonusAttack:    (json['bonus_attack'] as num?)?.toInt() ?? 0,
        critChance:     (json['crit_chance'] as num?)?.toDouble() ?? 0.0,
        dodgeChance:    (json['dodge_chance'] as num?)?.toDouble() ?? 0.0,
        rageGen:        (json['rage_gen'] as num?)?.toInt() ?? 8,
        grantedSkills:  (json['granted_skills'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );

  double get hpRatio  => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
  double get rageRatio => maxRage > 0 ? (rage / maxRage).clamp(0.0, 1.0) : 0.0;
  bool get isRageFull => rage >= maxRage;

  bool hasStatus(String name) =>
      statusEffects.any((e) => e.name.toUpperCase() == name.toUpperCase());

  int cooldownOf(String skillId) => cooldowns[skillId] ?? 0;
}
