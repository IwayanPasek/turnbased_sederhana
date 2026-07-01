// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

/// Semua konstanta warna aplikasi terpusat di sini.
/// Perubahan warna cukup di satu tempat.
class AppColors {
  AppColors._();

  // ── Brand Colors ─────────────────────────────────────────────────────────
  static const Color primary        = Color(0xFF6366F1); // Indigo
  static const Color primaryDark    = Color(0xFF4F46E5);
  static const Color primaryLight   = Color(0xFFE0E7FF);

  // ── Accent ───────────────────────────────────────────────────────────────
  static const Color accent         = Color(0xFF10B981); // Emerald
  static const Color accentDark     = Color(0xFF059669);
  static const Color gold           = Color(0xFFFFD700);
  static const Color goldDark       = Color(0xFFFF8C00);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color danger         = Color(0xFFEF4444);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color success        = Color(0xFF10B981);
  static const Color info           = Color(0xFF3B82F6);

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color bgDark         = Color(0xFF0F172A);
  static const Color bgCard         = Color(0xFF1E293B);
  static const Color bgOverlay      = Color(0x99000000);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFF8FAFC);
  static const Color textSecondary  = Color(0xFFCBD5E1);
  static const Color textMuted      = Color(0xFF64748B);

  // ── Borders ──────────────────────────────────────────────────────────────
  static const Color border         = Color(0xFF334155);
  static const Color borderLight    = Color(0xFF475569);

  // ── HP Bar Colors ────────────────────────────────────────────────────────
  static const Color hpHigh         = Color(0xFF22C55E);
  static const Color hpMid          = Color(0xFFF59E0B);
  static const Color hpLow          = Color(0xFFEF4444);

  // ── Rage / Ultimate ──────────────────────────────────────────────────────
  static const Color rageFill       = Color(0xFFAB47BC);
  static const Color rageReady      = Color(0xFFAA00FF);
  static const Color rageGlow       = Color(0x66AA00FF);

  // ── Status Effects ───────────────────────────────────────────────────────
  static const Color burn           = Color(0xFFFF3D00);
  static const Color poison         = Color(0xFF7B1FA2);
  static const Color stun           = Color(0xFFFFD600);
  static const Color shield         = Color(0xFF1565C0);

  // ── Skill Button Colors ──────────────────────────────────────────────────
  static const Color skillAttack      = Color(0xFFE53935);
  static const Color skillHeal        = Color(0xFF43A047);
  static const Color skillHeavy       = Color(0xFFFF6F00);
  static const Color skillFireBlast   = Color(0xFFFF3D00);
  static const Color skillStunBolt    = Color(0xFFFFD600);
  static const Color skillPoisonDart  = Color(0xFF7B1FA2);
  static const Color skillIronShield  = Color(0xFF1565C0);
  static const Color skillUltimate    = Color(0xFFAA00FF);

  // ── Rarity Colors ────────────────────────────────────────────────────────
  static const Color rarityCommon     = Color(0xFF9E9E9E);
  static const Color rarityUncommon   = Color(0xFF66BB6A);
  static const Color rarityRare       = Color(0xFF42A5F5);
  static const Color rarityEpic       = Color(0xFFAB47BC);
  static const Color rarityLegendary  = Color(0xFFFFCA28);

  /// Dapatkan warna rarity berdasarkan string
  static Color fromRarity(String rarity) {
    return switch (rarity.toLowerCase()) {
      'common'    => rarityCommon,
      'uncommon'  => rarityUncommon,
      'rare'      => rarityRare,
      'epic'      => rarityEpic,
      'legendary' => rarityLegendary,
      _           => rarityCommon,
    };
  }

  /// Dapatkan warna HP berdasarkan rasio (0.0-1.0)
  static Color fromHpRatio(double ratio) {
    if (ratio > 0.5) return hpHigh;
    if (ratio > 0.25) return hpMid;
    return hpLow;
  }

  /// Dapatkan warna status effect
  static Color fromStatus(String status) {
    return switch (status.toUpperCase()) {
      'BURN'   => burn,
      'POISON' => poison,
      'STUN'   => stun,
      'SHIELD' => shield,
      _        => textMuted,
    };
  }
}
