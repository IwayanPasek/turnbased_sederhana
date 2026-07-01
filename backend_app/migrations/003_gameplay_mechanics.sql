-- ============================================================================
-- TURN-BASED GAME: GAMEPLAY MECHANICS MIGRATION
-- Version: 3.0
-- Updated: 2026-07-01
-- Purpose: Add battle_logs table and skill_usage_logs for new combat mechanics
--          (Status Effects, Rage Meter, Cooldown System, Momentum Streak)
-- ============================================================================

SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ============================================================================
-- PHASE 1: BATTLE LOGS TABLE
-- Menyimpan ringkasan setiap pertarungan yang selesai
-- ============================================================================

CREATE TABLE IF NOT EXISTS battle_logs (
    battle_id       INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                      COMMENT 'Unique battle identifier',
    player1_id      INT UNSIGNED NOT NULL
                      COMMENT 'FK to players.id — first player',
    player2_id      INT UNSIGNED NOT NULL
                      COMMENT 'FK to players.id — second player (or NULL for vs bot)',
    winner_id       INT UNSIGNED
                      COMMENT 'FK to players.id — NULL means draw/disconnect',
    total_rounds    INT UNSIGNED NOT NULL DEFAULT 0
                      COMMENT 'How many turns the battle lasted',
    battle_type     ENUM('pvp', 'practice') NOT NULL DEFAULT 'pvp'
                      COMMENT 'Type of battle',
    started_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                      COMMENT 'When the battle started',
    ended_at        TIMESTAMP NULL
                      COMMENT 'When the battle ended (NULL = still ongoing)',
    CONSTRAINT fk_battle_p1 FOREIGN KEY (player1_id)
        REFERENCES players(id) ON DELETE CASCADE,
    CONSTRAINT fk_battle_p2 FOREIGN KEY (player2_id)
        REFERENCES players(id) ON DELETE CASCADE,
    KEY idx_player1 (player1_id),
    KEY idx_player2 (player2_id),
    KEY idx_winner (winner_id),
    KEY idx_battle_type (battle_type),
    KEY idx_started_at (started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Summary log for each completed battle';

-- ============================================================================
-- PHASE 2: SKILL USAGE LOGS TABLE
-- Menyimpan setiap aksi/skill yang dipakai dalam pertarungan
-- ============================================================================

CREATE TABLE IF NOT EXISTS skill_usage_logs (
    log_id          INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                      COMMENT 'Unique log entry',
    battle_id       INT UNSIGNED
                      COMMENT 'FK to battle_logs.battle_id (NULL for practice)',
    player_id       INT UNSIGNED NOT NULL
                      COMMENT 'FK to players.id — who used the skill',
    turn_number     INT UNSIGNED NOT NULL
                      COMMENT 'Which turn this action occurred',
    skill_name      VARCHAR(50) NOT NULL
                      COMMENT 'Skill used (attack, heal, heavy_strike, fire_blast, stun_bolt, shield, ultimate)',
    damage_dealt    INT NOT NULL DEFAULT 0
                      COMMENT 'Damage dealt this action (negative = self-heal)',
    status_applied  VARCHAR(50)
                      COMMENT 'Status effect applied, if any (BURN, STUN, SHIELD, POISON)',
    rage_before     INT UNSIGNED NOT NULL DEFAULT 0
                      COMMENT 'Rage value before this action',
    rage_after      INT UNSIGNED NOT NULL DEFAULT 0
                      COMMENT 'Rage value after this action',
    streak_count    INT UNSIGNED NOT NULL DEFAULT 0
                      COMMENT 'Momentum streak at time of action',
    was_stunned     BOOLEAN NOT NULL DEFAULT FALSE
                      COMMENT 'Whether actor was stunned and skipped this turn',
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_battle (battle_id),
    KEY idx_player (player_id),
    KEY idx_skill (skill_name),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Granular action log for every skill used in battle';

-- ============================================================================
-- PHASE 3: PLAYER BATTLE STATS EXTENSION
-- Tambahkan kolom statistik mekanik baru pada player_stats
-- ============================================================================

-- Total ultimates used
ALTER TABLE player_stats
    ADD COLUMN IF NOT EXISTS total_ultimates_used INT UNSIGNED NOT NULL DEFAULT 0
        COMMENT 'Total ultimate skills fired across all battles';

-- Total status effects applied
ALTER TABLE player_stats
    ADD COLUMN IF NOT EXISTS total_status_applied INT UNSIGNED NOT NULL DEFAULT 0
        COMMENT 'Total status effects (BURN/STUN/POISON/SHIELD) applied';

-- Highest streak ever achieved in a single battle
ALTER TABLE player_stats
    ADD COLUMN IF NOT EXISTS highest_streak INT UNSIGNED NOT NULL DEFAULT 0
        COMMENT 'Personal best momentum streak in a single battle';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- Tables created:
--   3. battle_logs        - per-battle summary (battle_id, player1_id, winner_id, ...)
--   4. skill_usage_logs   - per-action granular log (log_id, skill_name, damage, status, ...)
-- Columns added to player_stats:
--   - total_ultimates_used
--   - total_status_applied
--   - highest_streak
