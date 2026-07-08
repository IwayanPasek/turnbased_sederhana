CREATE TABLE IF NOT EXISTS system_config (
    config_key VARCHAR(50) PRIMARY KEY,
    config_value TEXT NOT NULL
);

INSERT IGNORE INTO system_config (config_key, config_value) VALUES ('system_announcement', '');
