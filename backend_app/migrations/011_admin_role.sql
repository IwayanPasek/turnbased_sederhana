-- 011_admin_role.sql
-- Adds admin role and ban status to players table

-- Add is_admin column
ALTER TABLE players ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;

-- Add is_banned column
ALTER TABLE players ADD COLUMN is_banned BOOLEAN DEFAULT FALSE;
