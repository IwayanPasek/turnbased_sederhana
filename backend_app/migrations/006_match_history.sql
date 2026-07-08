CREATE TABLE IF NOT EXISTS match_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    player1_username VARCHAR(255) NOT NULL,
    player2_username VARCHAR(255) NOT NULL,
    winner_username VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
