-- migrations/009_daily_quests.sql
-- Adds the Daily Quests System

DROP TABLE IF EXISTS player_daily_quests;
DROP TABLE IF EXISTS daily_quests_master;

-- 1. Create Daily Quests Master Table
CREATE TABLE IF NOT EXISTS daily_quests_master (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(50) NOT NULL, -- e.g., 'pvp_wins', 'gacha_opened', 'item_upgrades', 'ultimate_used', 'damage_dealt'
    name VARCHAR(100) NOT NULL,
    description TEXT,
    target_value INT NOT NULL,
    reward_type VARCHAR(50) NOT NULL, -- 'gems', 'coins'
    reward_amount INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create Player Daily Quests Table
CREATE TABLE IF NOT EXISTS player_daily_quests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    player_id BIGINT UNSIGNED NOT NULL,
    quest_id INT NOT NULL,
    current_progress INT DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    is_claimed BOOLEAN DEFAULT FALSE,
    assigned_date DATE NOT NULL,
    completed_at TIMESTAMP NULL,
    UNIQUE KEY uk_player_daily_quest (player_id, quest_id, assigned_date),
    FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
    FOREIGN KEY (quest_id) REFERENCES daily_quests_master(id) ON DELETE CASCADE
);

-- 3. Seed Basic Daily Quests
INSERT INTO daily_quests_master (type, name, description, target_value, reward_type, reward_amount) VALUES
('pvp_wins', 'Kemenangan Harian', 'Menangkan 3 pertandingan PvP hari ini', 3, 'coins', 300),
('pvp_wins', 'Pemanasan Arena', 'Menangkan 1 pertandingan PvP hari ini', 1, 'coins', 100),
('ultimate_used', 'Penguasa Ultimate', 'Gunakan skill Ultimate 3 kali dalam pertarungan', 3, 'gems', 10),
('ultimate_used', 'Unleash Power', 'Gunakan skill Ultimate 1 kali', 1, 'coins', 150),
('gacha_opened', 'Keberuntungan Harian', 'Buka 1 Peti Gacha hari ini', 1, 'gems', 15),
('gacha_opened', 'Pemburu Harta', 'Buka 3 Peti Gacha', 3, 'gems', 30),
('item_upgrades', 'Ahli Tempa Harian', 'Tingkatkan item sebanyak 1 kali hari ini', 1, 'coins', 250);
