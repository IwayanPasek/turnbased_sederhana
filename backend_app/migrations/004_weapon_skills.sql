-- ============================================================================
-- MIGRATION 004: WEAPON SKILLS
-- Menambahkan fitur skill khusus yang diberikan oleh item
-- ============================================================================

-- 1. Tambahkan kolom granted_skill ke tabel shop_items jika belum ada
SET @dbname = DATABASE();
SET @tablename = 'shop_items';
SET @columnname = 'granted_skill';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      (table_name = @tablename)
      AND (table_schema = @dbname)
      AND (column_name = @columnname)
  ) > 0,
  "SELECT 1",
  "ALTER TABLE shop_items ADD COLUMN granted_skill VARCHAR(50) NULL COMMENT 'Skill ID granted when equipped'"
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- 2. Update item yang sudah ada atau tambahkan item baru
-- Fire Staff
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, granted_skill)
VALUES ('Tongkat Api', 'weapon', 'Tongkat yang dialiri sihir api. Memberikan skill Fire Blast yang dapat membakar musuh.', 25, 'attack', 2000, 'rare', 'fire_blast')
ON DUPLICATE KEY UPDATE granted_skill = 'fire_blast', description = 'Tongkat yang dialiri sihir api. Memberikan skill Fire Blast yang dapat membakar musuh.';

-- Frost Lance
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, granted_skill)
VALUES ('Tombak Es', 'weapon', 'Tombak kristal es abadi. Memberikan skill Frost Nova yang membekukan musuh.', 30, 'attack', 2500, 'epic', 'frost_nova')
ON DUPLICATE KEY UPDATE granted_skill = 'frost_nova', description = 'Tombak kristal es abadi. Memberikan skill Frost Nova yang membekukan musuh.';

-- Aqua Blade
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, granted_skill)
VALUES ('Pedang Air', 'weapon', 'Pedang yang ditempa dari palung laut dalam. Memberikan skill Water Pulse.', 28, 'attack', 2200, 'rare', 'water_pulse')
ON DUPLICATE KEY UPDATE granted_skill = 'water_pulse', description = 'Pedang yang ditempa dari palung laut dalam. Memberikan skill Water Pulse.';

-- Venom Dagger
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, granted_skill)
VALUES ('Belati Racun', 'weapon', 'Belati kecil dengan racun mematikan. Memberikan skill Poison Dart.', 22, 'attack', 1800, 'uncommon', 'poison_dart')
ON DUPLICATE KEY UPDATE granted_skill = 'poison_dart', description = 'Belati kecil dengan racun mematikan. Memberikan skill Poison Dart.';

-- Heavy Hammer
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, granted_skill)
VALUES ('Palu Godam', 'weapon', 'Palu raksasa yang lambat namun menghancurkan armor. Memberikan skill Heavy Strike.', 40, 'attack', 3000, 'epic', 'heavy_strike')
ON DUPLICATE KEY UPDATE granted_skill = 'heavy_strike', description = 'Palu raksasa yang lambat namun menghancurkan armor. Memberikan skill Heavy Strike.';

-- Shield (Armor)
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, granted_skill)
VALUES ('Perisai Besi', 'armor', 'Perisai tebal. Memberikan skill Iron Shield untuk bertahan mutlak selama 1 giliran.', 20, 'defense', 1500, 'uncommon', 'iron_shield')
ON DUPLICATE KEY UPDATE granted_skill = 'iron_shield', description = 'Perisai tebal. Memberikan skill Iron Shield untuk bertahan mutlak selama 1 giliran.';
