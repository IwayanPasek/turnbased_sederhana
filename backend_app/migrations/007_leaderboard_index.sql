-- Menambahkan index untuk mempercepat query leaderboard (pengurutan berdasarkan mmr_score DESC)
CREATE INDEX IF NOT EXISTS idx_player_stats_mmr_desc ON player_stats(mmr_score DESC);
