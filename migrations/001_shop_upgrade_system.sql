-- ============================================================================
-- TURN-BASED GAME: FULL SCHEMA MIGRATION
-- Database: TiDB (MySQL 8.0 compatible)
-- Version: 2.0
-- Updated: 2026-06-12
-- Purpose: Create full schema for players, stats, shop, inventory, upgrades
-- ============================================================================

SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ============================================================================
-- PHASE 1: CORE PLAYER TABLES
-- ============================================================================

-- Players table: stores account information
CREATE TABLE IF NOT EXISTS players (
    id           INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                   COMMENT 'Unique player identifier',
    username     VARCHAR(50) NOT NULL UNIQUE
                   COMMENT 'Unique login name',
    password_hash VARCHAR(255) NOT NULL
                   COMMENT 'Bcrypt hashed password',
    coins        INT UNSIGNED NOT NULL DEFAULT 1000
                   COMMENT 'Soft currency - earned from battles',
    gems         INT UNSIGNED NOT NULL DEFAULT 100
                   COMMENT 'Premium currency',
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                   COMMENT 'Account creation time',
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                   COMMENT 'Last profile update time',
    KEY idx_username (username),
    KEY idx_coins (coins),
    KEY idx_gems (gems),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Stores player account information';


-- Player stats table: stores gameplay statistics
CREATE TABLE IF NOT EXISTS player_stats (
    player_id     INT UNSIGNED PRIMARY KEY
                    COMMENT 'FK to players.id',
    matches_played INT UNSIGNED NOT NULL DEFAULT 0
                    COMMENT 'Total matches played',
    wins          INT UNSIGNED NOT NULL DEFAULT 0
                    COMMENT 'Total wins',
    losses        INT UNSIGNED NOT NULL DEFAULT 0
                    COMMENT 'Total losses',
    mmr_score     INT NOT NULL DEFAULT 1000
                    COMMENT 'Matchmaking rating score',
    CONSTRAINT fk_stats_player FOREIGN KEY (player_id)
        REFERENCES players(id) ON DELETE CASCADE,
    KEY idx_mmr_score (mmr_score)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Stores player gameplay statistics';

-- ============================================================================
-- PHASE 2: SHOP ITEMS TABLE
-- ============================================================================

-- Master items catalog - defines all items available in the shop
CREATE TABLE IF NOT EXISTS shop_items (
    item_id          INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                       COMMENT 'Unique item identifier',
    item_name        VARCHAR(100) NOT NULL UNIQUE
                       COMMENT 'Display name (e.g., "Iron Sword")',
    item_type        ENUM('weapon', 'armor', 'accessory', 'consumable') NOT NULL
                       COMMENT 'Equipment slot type',
    description      TEXT
                       COMMENT 'Item description and gameplay effects',
    base_stat_boost  INT UNSIGNED NOT NULL DEFAULT 0
                       COMMENT 'Base stat bonus per level (e.g., +10 attack)',
    stat_type        ENUM('attack', 'defense', 'hp') NOT NULL
                       COMMENT 'Which stat this item modifies',
    base_cost_coins  INT UNSIGNED NOT NULL
                       COMMENT 'Price in soft currency for base level',
    base_cost_gems   INT UNSIGNED NOT NULL DEFAULT 0
                       COMMENT 'Price in premium currency (0 = coins only)',
    rarity           ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') NOT NULL DEFAULT 'common'
                       COMMENT 'Item rarity tier',
    is_upgradeable   BOOLEAN NOT NULL DEFAULT TRUE
                       COMMENT 'Whether this item can be leveled up',
    max_level        INT UNSIGNED NOT NULL DEFAULT 5
                       COMMENT 'Maximum upgrade level',
    icon_url         VARCHAR(255)
                       COMMENT 'URL to item icon/image for frontend display',
    is_active        BOOLEAN NOT NULL DEFAULT TRUE
                       COMMENT 'Soft delete flag - inactive items hidden from shop',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                       COMMENT 'When item was added to shop',
    updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                       COMMENT 'Last modification time',
    KEY idx_item_type (item_type),
    KEY idx_rarity (rarity),
    KEY idx_stat_type (stat_type),
    KEY idx_is_active (is_active),
    KEY idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Master catalog of all purchasable items and equipment';

-- ============================================================================
-- PHASE 3: PLAYER INVENTORY TABLE
-- ============================================================================

-- Player inventory - tracks what items each player owns
CREATE TABLE IF NOT EXISTS player_inventory (
    inventory_id   INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                     COMMENT 'Unique inventory entry ID',
    player_id      INT UNSIGNED NOT NULL
                     COMMENT 'FK to players.id',
    item_id        INT UNSIGNED NOT NULL
                     COMMENT 'FK to shop_items.item_id',
    current_level  INT UNSIGNED NOT NULL DEFAULT 1
                     COMMENT 'Current upgrade level (1 = base)',
    quantity       INT UNSIGNED NOT NULL DEFAULT 1
                     COMMENT 'Stack count (for consumable items)',
    is_equipped    BOOLEAN NOT NULL DEFAULT FALSE
                     COMMENT 'Whether this item is currently equipped',
    equipped_slot  ENUM('weapon', 'armor', 'accessory')
                     COMMENT 'Which equipment slot this item occupies (NULL if not equipped)',
    acquired_date  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                     COMMENT 'When player obtained this item',
    last_upgraded  TIMESTAMP NULL
                     COMMENT 'When item was last upgraded (NULL if never upgraded)',
    CONSTRAINT fk_inventory_player FOREIGN KEY (player_id)
        REFERENCES players(id) ON DELETE CASCADE,
    CONSTRAINT fk_inventory_item FOREIGN KEY (item_id)
        REFERENCES shop_items(item_id) ON DELETE RESTRICT,
    UNIQUE KEY uk_player_item (player_id, item_id)
      COMMENT 'Player can only own one of each item',
    KEY idx_player_id (player_id),
    KEY idx_item_id (item_id),
    KEY idx_is_equipped (is_equipped),
    KEY idx_acquired_date (acquired_date),
    KEY idx_player_equipped (player_id, is_equipped)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Tracks player inventory and currently equipped items';

-- ============================================================================
-- PHASE 4: UPGRADE COSTS TABLE
-- ============================================================================

-- Upgrade costs matrix - defines costs for each level transition
CREATE TABLE IF NOT EXISTS upgrade_costs (
    cost_id            INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                         COMMENT 'Unique cost entry ID',
    item_id            INT UNSIGNED NOT NULL
                         COMMENT 'FK to shop_items.item_id',
    from_level         INT UNSIGNED NOT NULL
                         COMMENT 'Upgrade FROM this level',
    to_level           INT UNSIGNED NOT NULL
                         COMMENT 'Upgrade TO this level (always > from_level)',
    cost_coins         INT UNSIGNED NOT NULL
                         COMMENT 'Soft currency cost for this upgrade',
    cost_gems          INT UNSIGNED NOT NULL DEFAULT 0
                         COMMENT 'Premium currency cost (0 = coins only)',
    stat_bonus_per_level FLOAT NOT NULL DEFAULT 5.0
                         COMMENT 'Stat increase per level (e.g., 5.0 = +5 per level)',
    CONSTRAINT fk_upgrade_costs_item FOREIGN KEY (item_id)
        REFERENCES shop_items(item_id) ON DELETE CASCADE,
    UNIQUE KEY uk_item_level_transition (item_id, from_level, to_level)
      COMMENT 'Define cost once per level transition',
    KEY idx_item_id (item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Defines upgrade costs for each item level progression';

-- ============================================================================
-- PHASE 5: PLAYER UPGRADES TABLE
-- ============================================================================

-- Upgrade audit log - tracks all upgrade transactions
CREATE TABLE IF NOT EXISTS player_upgrades (
    upgrade_id  INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                  COMMENT 'Unique upgrade transaction ID',
    player_id   INT UNSIGNED NOT NULL
                  COMMENT 'FK to players.id',
    item_id     INT UNSIGNED NOT NULL
                  COMMENT 'FK to shop_items.item_id',
    from_level  INT UNSIGNED NOT NULL
                  COMMENT 'Level before upgrade',
    to_level    INT UNSIGNED NOT NULL
                  COMMENT 'Level after upgrade',
    cost_coins  INT UNSIGNED NOT NULL DEFAULT 0
                  COMMENT 'Coins spent on upgrade',
    cost_gems   INT UNSIGNED NOT NULL DEFAULT 0
                  COMMENT 'Gems spent on upgrade',
    upgraded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                  COMMENT 'When upgrade was performed',
    CONSTRAINT fk_upgrades_player FOREIGN KEY (player_id)
        REFERENCES players(id) ON DELETE CASCADE,
    CONSTRAINT fk_upgrades_item FOREIGN KEY (item_id)
        REFERENCES shop_items(item_id) ON DELETE RESTRICT,
    KEY idx_player_id (player_id),
    KEY idx_item_id (item_id),
    KEY idx_upgraded_at (upgraded_at),
    KEY idx_player_upgraded_at (player_id, upgraded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Immutable audit log of all upgrade transactions';

-- ============================================================================
-- PHASE 6: CURRENCY TRANSACTIONS TABLE
-- ============================================================================

-- Currency transaction audit log
CREATE TABLE IF NOT EXISTS currency_transactions (
    transaction_id   INT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                       COMMENT 'Unique transaction ID',
    player_id        INT UNSIGNED NOT NULL
                       COMMENT 'FK to players.id',
    transaction_type ENUM(
        'purchase',
        'upgrade',
        'reward',
        'refund',
        'shop_purchase',
        'battle_reward',
        'achievement_reward',
        'admin_adjustment'
    ) NOT NULL
                       COMMENT 'Type of currency transaction',
    coins_change     INT NOT NULL DEFAULT 0
                       COMMENT 'Positive or negative coins change',
    gems_change      INT NOT NULL DEFAULT 0
                       COMMENT 'Positive or negative gems change',
    reason           VARCHAR(255) NOT NULL
                       COMMENT 'Human-readable reason for transaction',
    reference_id     INT UNSIGNED
                       COMMENT 'Links to inventory_id or upgrade_id for reference',
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                       COMMENT 'When transaction occurred',
    CONSTRAINT fk_transaction_player FOREIGN KEY (player_id)
        REFERENCES players(id) ON DELETE CASCADE,
    KEY idx_player_id (player_id),
    KEY idx_transaction_type (transaction_type),
    KEY idx_created_at (created_at),
    KEY idx_player_type_date (player_id, transaction_type, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Immutable audit log of all currency transactions';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- Tables created:
--   1. players             - account info (id, username, password_hash, coins, gems, ...)
--   2. player_stats        - gameplay stats (player_id, wins, losses, mmr_score, ...)
--   3. shop_items          - item catalog (item_id, item_name, base_stat_boost, ...)
--   4. player_inventory    - owned items  (inventory_id, player_id, item_id, is_equipped, ...)
--   5. upgrade_costs       - upgrade cost matrix (cost_id, item_id, from_level, to_level, ...)
--   6. player_upgrades     - upgrade history (upgrade_id, player_id, item_id, ...)
--   7. currency_transactions - transaction log (transaction_id, player_id, coins_change, ...)
