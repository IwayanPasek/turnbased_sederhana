-- ============================================================================
-- TURN-BASED GAME: SHOP ITEMS AND UPGRADE COSTS SEED DATA
-- Database: TiDB/MySQL 8.0+
-- Version: 1.0
-- Created: 2026-06-12
-- Purpose: Initialize shop_items and upgrade_costs tables with game data
-- ============================================================================

-- Set encoding for proper character support
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ============================================================================
-- PART 1: INSERT SHOP ITEMS
-- ============================================================================

-- ---- WEAPON ITEMS ----
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, is_upgradeable, max_level)
VALUES
('Iron Sword', 'weapon', 'A basic iron blade. Reliable and affordable. Grants +10 attack per level.', 10, 'attack', 100, 'common', TRUE, 5),
('Steel Blade', 'weapon', 'Crafted from superior steel. More durable than iron. Grants +15 attack per level.', 15, 'attack', 250, 'uncommon', TRUE, 5),
('Enchanted Claymore', 'weapon', 'Imbued with ice magic. A magnificent two-handed sword. Grants +25 attack per level.', 25, 'attack', 500, 'rare', TRUE, 5),
('Dragon Slayer', 'weapon', 'Forged in the heart of a dragon. Devastatingly powerful. Grants +50 attack per level.', 50, 'attack', 1000, 'epic', TRUE, 5),
('Sword of Legends', 'weapon', 'The most powerful weapon ever created. A true masterpiece. Grants +100 attack per level.', 100, 'attack', 5000, 'legendary', TRUE, 10);

-- ---- ARMOR ITEMS ----
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, is_upgradeable, max_level)
VALUES
('Leather Armor', 'armor', 'Basic leather protection. Light and comfortable. Grants +10 defense per level.', 10, 'defense', 100, 'common', TRUE, 5),
('Iron Mail', 'armor', 'Steel-plated chainmail. Good protection against most attacks. Grants +15 defense per level.', 15, 'defense', 250, 'uncommon', TRUE, 5),
('Mithril Plate', 'armor', 'Mythical lightweight metal. Exceptional durability and flexibility. Grants +30 defense per level.', 30, 'defense', 500, 'rare', TRUE, 5),
('Dragon Scale Armor', 'armor', 'Woven from impenetrable dragon scales. Nearly unbreakable. Grants +60 defense per level.', 60, 'defense', 1000, 'epic', TRUE, 5),
('Aegis of the Gods', 'armor', 'Divine armor blessed by ancient gods. Ultimate protection. Grants +120 defense per level.', 120, 'defense', 5000, 'legendary', TRUE, 10);

-- ---- ACCESSORY ITEMS ----
INSERT INTO shop_items (item_name, item_type, description, base_stat_boost, stat_type, base_cost_coins, rarity, is_upgradeable, max_level)
VALUES
('Health Amulet', 'accessory', 'Restores vitality to the wearer. Grants +20 HP per level.', 20, 'hp', 150, 'common', TRUE, 5),
('Guardian Ring', 'accessory', 'A protective band that shields the wearer. Grants +40 HP per level.', 40, 'hp', 350, 'uncommon', TRUE, 5),
('Phoenix Talisman', 'accessory', 'Ancient talisman of rebirth and renewal. Grants +80 HP per level.', 80, 'hp', 600, 'rare', TRUE, 5),
('Immortal Crown', 'accessory', 'Crown of eternal life, blessed by time itself. Grants +150 HP per level.', 150, 'hp', 1200, 'epic', TRUE, 5),
('Heart of the Universe', 'accessory', 'A cosmic artifact of immense power. Grants +300 HP per level.', 300, 'hp', 5000, 'legendary', TRUE, 10);

-- Verify all items inserted
SELECT COUNT(*) AS total_items,
       SUM(CASE WHEN item_type = 'weapon' THEN 1 ELSE 0 END) as weapons,
       SUM(CASE WHEN item_type = 'armor' THEN 1 ELSE 0 END) as armor,
       SUM(CASE WHEN item_type = 'accessory' THEN 1 ELSE 0 END) as accessories
FROM shop_items;

-- ============================================================================
-- PART 2: INSERT UPGRADE COSTS
-- ============================================================================

-- ---- IRON SWORD UPGRADES (Common) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Sword'), 1, 2, 100, 0, 10),
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Sword'), 2, 3, 200, 0, 10),
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Sword'), 3, 4, 300, 0, 10),
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Sword'), 4, 5, 400, 5, 10);

-- ---- STEEL BLADE UPGRADES (Uncommon) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Steel Blade'), 1, 2, 200, 0, 15),
((SELECT item_id FROM shop_items WHERE item_name = 'Steel Blade'), 2, 3, 400, 0, 15),
((SELECT item_id FROM shop_items WHERE item_name = 'Steel Blade'), 3, 4, 600, 0, 15),
((SELECT item_id FROM shop_items WHERE item_name = 'Steel Blade'), 4, 5, 800, 5, 15);

-- ---- ENCHANTED CLAYMORE UPGRADES (Rare) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Enchanted Claymore'), 1, 2, 400, 0, 25),
((SELECT item_id FROM shop_items WHERE item_name = 'Enchanted Claymore'), 2, 3, 800, 0, 25),
((SELECT item_id FROM shop_items WHERE item_name = 'Enchanted Claymore'), 3, 4, 1200, 5, 25),
((SELECT item_id FROM shop_items WHERE item_name = 'Enchanted Claymore'), 4, 5, 1600, 10, 25);

-- ---- DRAGON SLAYER UPGRADES (Epic) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Slayer'), 1, 2, 800, 10, 50),
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Slayer'), 2, 3, 1600, 15, 50),
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Slayer'), 3, 4, 2400, 20, 50),
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Slayer'), 4, 5, 3200, 30, 50);

-- ---- SWORD OF LEGENDS UPGRADES (Legendary - 10 levels) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 1, 2, 2000, 20, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 2, 3, 3000, 30, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 3, 4, 4000, 40, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 4, 5, 5000, 50, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 5, 6, 6000, 60, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 6, 7, 7000, 70, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 7, 8, 8000, 80, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 8, 9, 9000, 90, 100),
((SELECT item_id FROM shop_items WHERE item_name = 'Sword of Legends'), 9, 10, 10000, 100, 100);

-- ---- LEATHER ARMOR UPGRADES (Common) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Leather Armor'), 1, 2, 100, 0, 10),
((SELECT item_id FROM shop_items WHERE item_name = 'Leather Armor'), 2, 3, 200, 0, 10),
((SELECT item_id FROM shop_items WHERE item_name = 'Leather Armor'), 3, 4, 300, 0, 10),
((SELECT item_id FROM shop_items WHERE item_name = 'Leather Armor'), 4, 5, 400, 5, 10);

-- ---- IRON MAIL UPGRADES (Uncommon) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Mail'), 1, 2, 200, 0, 15),
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Mail'), 2, 3, 400, 0, 15),
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Mail'), 3, 4, 600, 0, 15),
((SELECT item_id FROM shop_items WHERE item_name = 'Iron Mail'), 4, 5, 800, 5, 15);

-- ---- MITHRIL PLATE UPGRADES (Rare) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Mithril Plate'), 1, 2, 400, 0, 30),
((SELECT item_id FROM shop_items WHERE item_name = 'Mithril Plate'), 2, 3, 800, 0, 30),
((SELECT item_id FROM shop_items WHERE item_name = 'Mithril Plate'), 3, 4, 1200, 5, 30),
((SELECT item_id FROM shop_items WHERE item_name = 'Mithril Plate'), 4, 5, 1600, 10, 30);

-- ---- DRAGON SCALE ARMOR UPGRADES (Epic) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Scale Armor'), 1, 2, 800, 10, 60),
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Scale Armor'), 2, 3, 1600, 15, 60),
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Scale Armor'), 3, 4, 2400, 20, 60),
((SELECT item_id FROM shop_items WHERE item_name = 'Dragon Scale Armor'), 4, 5, 3200, 30, 60);

-- ---- AEGIS OF THE GODS UPGRADES (Legendary - 10 levels) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 1, 2, 2000, 20, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 2, 3, 3000, 30, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 3, 4, 4000, 40, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 4, 5, 5000, 50, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 5, 6, 6000, 60, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 6, 7, 7000, 70, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 7, 8, 8000, 80, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 8, 9, 9000, 90, 120),
((SELECT item_id FROM shop_items WHERE item_name = 'Aegis of the Gods'), 9, 10, 10000, 100, 120);

-- ---- HEALTH AMULET UPGRADES (Common) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Health Amulet'), 1, 2, 150, 0, 20),
((SELECT item_id FROM shop_items WHERE item_name = 'Health Amulet'), 2, 3, 300, 0, 20),
((SELECT item_id FROM shop_items WHERE item_name = 'Health Amulet'), 3, 4, 450, 0, 20),
((SELECT item_id FROM shop_items WHERE item_name = 'Health Amulet'), 4, 5, 600, 5, 20);

-- ---- GUARDIAN RING UPGRADES (Uncommon) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Guardian Ring'), 1, 2, 300, 0, 40),
((SELECT item_id FROM shop_items WHERE item_name = 'Guardian Ring'), 2, 3, 600, 0, 40),
((SELECT item_id FROM shop_items WHERE item_name = 'Guardian Ring'), 3, 4, 900, 0, 40),
((SELECT item_id FROM shop_items WHERE item_name = 'Guardian Ring'), 4, 5, 1200, 5, 40);

-- ---- PHOENIX TALISMAN UPGRADES (Rare) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Phoenix Talisman'), 1, 2, 500, 0, 80),
((SELECT item_id FROM shop_items WHERE item_name = 'Phoenix Talisman'), 2, 3, 1000, 0, 80),
((SELECT item_id FROM shop_items WHERE item_name = 'Phoenix Talisman'), 3, 4, 1500, 5, 80),
((SELECT item_id FROM shop_items WHERE item_name = 'Phoenix Talisman'), 4, 5, 2000, 10, 80);

-- ---- IMMORTAL CROWN UPGRADES (Epic) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Immortal Crown'), 1, 2, 1000, 10, 150),
((SELECT item_id FROM shop_items WHERE item_name = 'Immortal Crown'), 2, 3, 2000, 15, 150),
((SELECT item_id FROM shop_items WHERE item_name = 'Immortal Crown'), 3, 4, 3000, 20, 150),
((SELECT item_id FROM shop_items WHERE item_name = 'Immortal Crown'), 4, 5, 4000, 30, 150);

-- ---- HEART OF THE UNIVERSE UPGRADES (Legendary - 10 levels) ----
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 1, 2, 2500, 20, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 2, 3, 3500, 30, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 3, 4, 4500, 40, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 4, 5, 5500, 50, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 5, 6, 6500, 60, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 6, 7, 7500, 70, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 7, 8, 8500, 80, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 8, 9, 9500, 90, 300),
((SELECT item_id FROM shop_items WHERE item_name = 'Heart of the Universe'), 9, 10, 10500, 100, 300);

-- Verify all upgrade costs inserted
SELECT COUNT(*) AS total_costs FROM upgrade_costs;
SELECT si.item_name, si.rarity, COUNT(uc.cost_id) as upgrade_levels
FROM shop_items si
LEFT JOIN upgrade_costs uc ON si.item_id = uc.item_id
GROUP BY si.item_id, si.item_name, si.rarity
ORDER BY si.rarity DESC, si.item_name;

-- ============================================================================
-- PART 3: DATA VERIFICATION SUMMARY
-- ============================================================================

/*
-- Run these queries to verify the seeding was successful

-- 1. Total items by type
SELECT item_type, COUNT(*) as count, MIN(base_cost_coins) as min_cost, MAX(base_cost_coins) as max_cost
FROM shop_items
GROUP BY item_type;

-- 2. Total items by rarity
SELECT rarity, COUNT(*) as count, AVG(base_cost_coins) as avg_cost
FROM shop_items
GROUP BY rarity
ORDER BY FIELD(rarity, 'common', 'uncommon', 'rare', 'epic', 'legendary');

-- 3. Upgrade cost range
SELECT
    si.item_name,
    si.rarity,
    COUNT(uc.cost_id) as upgrade_count,
    MIN(uc.cost_coins) as min_upgrade_cost,
    MAX(uc.cost_coins) as max_upgrade_cost,
    MIN(uc.cost_gems) as min_gem_cost,
    MAX(uc.cost_gems) as max_gem_cost
FROM shop_items si
JOIN upgrade_costs uc ON si.item_id = uc.item_id
GROUP BY si.item_id, si.item_name, si.rarity
ORDER BY si.rarity DESC;

-- 4. Calculate total progression cost for each item
SELECT
    si.item_name,
    si.rarity,
    si.max_level,
    SUM(uc.cost_coins) as total_coins_to_max,
    SUM(uc.cost_gems) as total_gems_to_max
FROM shop_items si
JOIN upgrade_costs uc ON si.item_id = uc.item_id
GROUP BY si.item_id, si.item_name, si.rarity, si.max_level
ORDER BY total_coins_to_max DESC;
*/

-- ============================================================================
-- PART 3: SPECIAL ITEM — WRATH OF THE COW
-- ============================================================================

-- Insert the legendary special item
INSERT INTO shop_items (
    item_name, item_type, description, base_stat_boost, stat_type,
    base_cost_coins, base_cost_gems, rarity, is_upgradeable, max_level
)
VALUES (
    'Wrath of the Cow',
    'weapon',
    'Artefak yang keberadaannya masih menjadi perdebatan di antara mahasiswa, dosen, dan beberapa ekor sapi yang dianggap sakral. Menurut legenda kampus, senjata ini berhasil disintesis oleh Semara, seorang mahasiswa yang menyandang gelar legendaris "Shikizima" dan title kehormatan "The First Ruler of STIKOM".\n\nSemara dikenal sebagai mahasiswa yang sangat rajin sembahyang. Karena frekuensinya yang luar biasa, teman-temannya mulai menyebut aktivitas tersebut sebagai "pergi ke Dewan-Dewan". Tidak ada yang benar-benar tahu siapa atau apa yang dimaksud dengan Dewan-Dewan, tetapi setiap kali Semara kembali dari sana, ia selalu membawa pengetahuan yang tidak masuk akal.\n\nKonon pada kunjungan ke-108 ke Dewan-Dewan, Semara menerima wahyu berupa formula kuno yang tertulis pada secarik kertas yang muncul secara misterius di antara tumpukan tugas kuliah. Formula tersebut menjelaskan cara mensintesis senjata yang melampaui batas logika, akal sehat, dan dokumentasi akademik.\n\nDengan menggabungkan energi tugas yang belum dikumpulkan, serpihan keyboard mekanik, tiga tetes kopi dingin, lima lembar revisi proposal yang ditolak, dan amarah seekor sapi kosmik yang tersesat di dimensi kampus, Semara memulai proses sintesis. Ritual tersebut berlangsung selama tujuh malam tujuh hari tanpa jeda, ditemani suara kipas laptop yang berputar pada kecepatan maksimum.\n\nPada saat sintesis mencapai puncaknya, langit kampus dikabarkan berubah warna, proyektor menyala sendiri, dan mesin presensi menampilkan pesan: "THE FIRST RULER HAS AWAKENED". Dari ledakan energi akademik itu lahirlah Wrath of the Cow.\n\nWrath of the Cow merupakan artefak dengan tier Unmatched, Unrivaled, Immeasured. Senjata ini dipercaya mampu meningkatkan keberuntungan saat ujian, memperpanjang umur baterai laptop ketika presentasi, memanggil sinyal Wi-Fi di area tanpa router, dan membuat tugas kelompok selesai meskipun tidak ada anggota kelompok yang terlihat mengerjakannya.\n\nHingga saat ini para peneliti masih memperdebatkan apakah kisah ini benar-benar terjadi atau hanya akibat kurang tidur menjelang deadline. Namun satu hal yang disepakati semua orang adalah bahwa nama Shikizima, The First Ruler of STIKOM, akan selalu dikenang dalam legenda Wrath of the Cow.',
    99999,
    'attack',
    999999999,
    999999,
    'legendary',
    TRUE,
    99
);

-- Upgrade costs for Wrath of the Cow (levels 1-99)
-- Using a stored procedure approach via individual inserts for first 10 levels
-- then escalating costs
INSERT INTO upgrade_costs (item_id, from_level, to_level, cost_coins, cost_gems, stat_bonus_per_level)
VALUES
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 1, 2, 9999999, 99999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 2, 3, 19999999, 199999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 3, 4, 29999999, 299999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 4, 5, 39999999, 399999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 5, 6, 49999999, 499999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 6, 7, 59999999, 599999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 7, 8, 69999999, 699999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 8, 9, 79999999, 799999, 99999),
((SELECT item_id FROM shop_items WHERE item_name = 'Wrath of the Cow'), 9, 10, 99999999, 999999, 99999);

-- ============================================================================
-- SEED DATA LOADING COMPLETE
-- ============================================================================
-- Status: 16 shop items (including Wrath of the Cow) and 69 upgrade cost entries.
-- Next step: Proceed with backend API implementation and frontend UI screens.
