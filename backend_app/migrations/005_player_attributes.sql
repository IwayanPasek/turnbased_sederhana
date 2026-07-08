-- 005_player_attributes.sql
CREATE TABLE IF NOT EXISTS player_attributes (
    player_id BIGINT UNSIGNED PRIMARY KEY,
    strength INT UNSIGNED NOT NULL DEFAULT 0,
    agility INT UNSIGNED NOT NULL DEFAULT 0,
    intelligence INT UNSIGNED NOT NULL DEFAULT 0,
    available_points INT UNSIGNED NOT NULL DEFAULT 10,
    CONSTRAINT fk_attributes_player FOREIGN KEY (player_id)
        REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Stores player allocated attributes';
