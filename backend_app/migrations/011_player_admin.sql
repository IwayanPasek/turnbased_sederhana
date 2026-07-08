-- Add is_admin column to players table
ALTER TABLE players ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT FALSE;
