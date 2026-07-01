// lib/core/constants/skill_constants.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Definisi setiap skill — sinkron dengan SKILL_CONFIG di backend main.py
class SkillDef {
  final String id;
  final String label;
  final String emoji;
  final String description;
  final int cooldown;
  final int? damageMin;
  final int? damageMax;
  final int? healMin;
  final int? healMax;
  final String? applyStatus;
  final bool requiresFullRage;
  final Color color;

  const SkillDef({
    required this.id,
    required this.label,
    required this.emoji,
    required this.description,
    required this.color,
    this.cooldown = 0,
    this.damageMin,
    this.damageMax,
    this.healMin,
    this.healMax,
    this.applyStatus,
    this.requiresFullRage = false,
  });

  bool get isAttack  => damageMin != null && !requiresFullRage;
  bool get isHeal    => healMin != null;
  bool get isUltimate => requiresFullRage;
  bool get hasStatus => applyStatus != null;

  String get damageRange => damageMin != null
      ? '$damageMin–$damageMax DMG'
      : '';

  String get healRange => healMin != null
      ? '+$healMin–$healMax HP'
      : '';
}

/// Definisi status effect — sinkron dengan STATUS_CONFIG di backend
class StatusEffectDef {
  final String name;
  final String emoji;
  final int duration;
  final int tickDamage;

  const StatusEffectDef({
    required this.name,
    required this.emoji,
    required this.duration,
    required this.tickDamage,
  });
}

/// Semua skill yang tersedia (urutan = urutan tampil di grid)
const List<SkillDef> kSkills = [
  SkillDef(
    id: 'attack',
    label: 'Serang',
    emoji: '⚔️',
    description: 'Serangan dasar',
    cooldown: 0,
    damageMin: 10,
    damageMax: 20,
    color: AppColors.skillAttack,
  ),
  SkillDef(
    id: 'heal',
    label: 'Pulih',
    emoji: '💚',
    description: 'Pulihkan HP sendiri',
    cooldown: 0,
    healMin: 15,
    healMax: 22,
    color: AppColors.skillHeal,
  ),
  SkillDef(
    id: 'heavy_strike',
    label: 'Heavy Strike',
    emoji: '🔨',
    description: 'Hantaman berat, damage tinggi',
    cooldown: 2,
    damageMin: 28,
    damageMax: 42,
    color: AppColors.skillHeavy,
  ),
  SkillDef(
    id: 'fire_blast',
    label: 'Fire Blast',
    emoji: '🔥',
    description: 'Ledakan api + BURN 3 turn',
    cooldown: 3,
    damageMin: 15,
    damageMax: 22,
    applyStatus: 'BURN',
    color: AppColors.skillFireBlast,
  ),
  SkillDef(
    id: 'stun_bolt',
    label: 'Stun Bolt',
    emoji: '⚡',
    description: 'Kilatan listrik + STUN',
    cooldown: 4,
    damageMin: 12,
    damageMax: 18,
    applyStatus: 'STUN',
    color: AppColors.skillStunBolt,
  ),
  SkillDef(
    id: 'poison_dart',
    label: 'Poison Dart',
    emoji: '☠️',
    description: 'Serangan + POISON 5 turn',
    cooldown: 3,
    damageMin: 8,
    damageMax: 12,
    applyStatus: 'POISON',
    color: AppColors.skillPoisonDart,
  ),
  SkillDef(
    id: 'iron_shield',
    label: 'Iron Shield',
    emoji: '🛡️',
    description: 'Blok 50% damage masuk 1 turn',
    cooldown: 3,
    color: AppColors.skillIronShield,
  ),
  SkillDef(
    id: 'ultimate',
    label: 'ULTIMATE',
    emoji: '💥',
    description: 'Damage masif + BURN. Butuh RAGE penuh!',
    cooldown: 0,
    damageMin: 55,
    damageMax: 75,
    applyStatus: 'BURN',
    requiresFullRage: true,
    color: AppColors.skillUltimate,
  ),
  SkillDef(
    id: 'frost_nova',
    label: 'Frost Nova',
    emoji: '🧊',
    description: 'Membekukan lawan selama 2 turn',
    cooldown: 3,
    damageMin: 10,
    damageMax: 15,
    applyStatus: 'FREEZE',
    color: AppColors.info, // Dummy color
  ),
  SkillDef(
    id: 'water_pulse',
    label: 'Water Pulse',
    emoji: '🌊',
    description: 'Serangan air. Jika punya BURN, ubah jadi REGEN',
    cooldown: 2,
    damageMin: 12,
    damageMax: 20,
    color: AppColors.primary, // Dummy color
  ),
];

/// Map untuk akses cepat skill berdasarkan id
final Map<String, SkillDef> kSkillMap = {
  for (final s in kSkills) s.id: s,
};

/// Semua status effect
const Map<String, StatusEffectDef> kStatusEffects = {
  'BURN':   StatusEffectDef(name: 'BURN',   emoji: '🔥', duration: 3, tickDamage: 6),
  'POISON': StatusEffectDef(name: 'POISON', emoji: '☠️', duration: 5, tickDamage: 3),
  'STUN':   StatusEffectDef(name: 'STUN',   emoji: '⚡', duration: 1, tickDamage: 0),
  'SHIELD': StatusEffectDef(name: 'SHIELD', emoji: '🛡️', duration: 1, tickDamage: 0),
  'FREEZE': StatusEffectDef(name: 'FREEZE', emoji: '🧊', duration: 2, tickDamage: 0),
  'REGEN':  StatusEffectDef(name: 'REGEN',  emoji: '💖', duration: 2, tickDamage: -10),
};

/// Konstanta numerik game — sinkron backend
const int kMaxHp   = 150;
const int kMaxRage  = 100;
const int kMomentumMaxStacks = 3;
