-- Add avatar_style column to players table
ALTER TABLE players ADD COLUMN avatar_style VARCHAR(50) NOT NULL DEFAULT 'default';
