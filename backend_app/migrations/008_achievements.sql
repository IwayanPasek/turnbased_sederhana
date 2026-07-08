-- migrations/008_achievements.sql
-- Adds the Achievements and Titles System

DROP TABLE IF EXISTS player_achievements;
DROP TABLE IF EXISTS achievements;

-- 1. Create Achievements Table
CREATE TABLE IF NOT EXISTS achievements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(50) NOT NULL, -- e.g., 'pvp_wins', 'gacha_opened', 'weapon_upgrades'
    name VARCHAR(100) NOT NULL,
    description TEXT,
    target_value INT NOT NULL,
    reward_type VARCHAR(50) NOT NULL, -- 'gems', 'coins'
    reward_amount INT NOT NULL,
    reward_title VARCHAR(100), -- The title granted upon completion
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create Player Achievements Progress Table
CREATE TABLE IF NOT EXISTS player_achievements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    player_id BIGINT UNSIGNED NOT NULL,
    achievement_id INT NOT NULL,
    current_progress INT DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    is_claimed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP NULL,
    claimed_at TIMESTAMP NULL,
    UNIQUE KEY uk_player_achievement (player_id, achievement_id),
    FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE,
    FOREIGN KEY (achievement_id) REFERENCES achievements(id) ON DELETE CASCADE
);

-- 3. Add active_title to players table
-- This allows players to select a title they've unlocked to display on their profile
ALTER TABLE players ADD COLUMN active_title VARCHAR(100) DEFAULT NULL;

-- 4. Seed basic achievements
INSERT INTO achievements (type, name, description, target_value, reward_type, reward_amount, reward_title) VALUES
('pvp_wins', 'Pejuang Pemula', 'Menangkan 1 pertandingan PvP', 1, 'coins', 500, 'Pejuang Pemula'),
('pvp_wins', 'Gladiator', 'Menangkan 10 pertandingan PvP', 10, 'gems', 100, 'Gladiator'),
('pvp_wins', 'Dewa Perang', 'Menangkan 50 pertandingan PvP', 50, 'gems', 500, 'Dewa Perang'),
('gacha_opened', 'Uji Nasib', 'Buka 1 Peti Gacha jenis apa saja', 1, 'coins', 100, 'Pecandu Gacha'),
('gacha_opened', 'Kolektor Rarity', 'Buka 20 Peti Gacha', 20, 'gems', 200, 'Kolektor Sultan'),
('item_upgrades', 'Tukang Tempa', 'Tingkatkan level item sebanyak 5 kali (Dapatkan item duplikat)', 5, 'coins', 1000, 'Master Tempa');
