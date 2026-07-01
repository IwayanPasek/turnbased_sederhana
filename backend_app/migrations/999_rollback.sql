-- ============================================================================
-- Migration 999: Rollback Shop & Upgrade System (Emergency Use Only)
-- ============================================================================
-- Purpose: Safely rollback all shop and upgrade system changes
-- Version: 1.0
-- Date: 2026-06-12
-- Database: MySQL 5.7+ / TiDB
-- ============================================================================

-- ⚠️ WARNING: This migration should only be used in case of emergency
-- It will DELETE ALL SHOP, UPGRADE, AND INVENTORY DATA
-- Make sure you have backups before executing!

START TRANSACTION;

-- Step 1: Remove foreign key constraints from players table
ALTER TABLE players
DROP FOREIGN KEY IF EXISTS fk_equipped_weapon,
DROP FOREIGN KEY IF EXISTS fk_equipped_armor,
DROP FOREIGN KEY IF EXISTS fk_equipped_accessory;

-- Step 2: Drop new tables (in reverse order of creation to respect foreign keys)
DROP TABLE IF EXISTS currency_transactions;
DROP TABLE IF EXISTS player_upgrades;
DROP TABLE IF EXISTS player_inventory;
DROP TABLE IF EXISTS upgrade_costs;
DROP TABLE IF EXISTS shop_items;

-- Step 3: Remove currency columns from players table
ALTER TABLE players
DROP COLUMN IF EXISTS coins,
DROP COLUMN IF EXISTS gems,
DROP COLUMN IF EXISTS equipped_weapon_id,
DROP COLUMN IF EXISTS equipped_armor_id,
DROP COLUMN IF EXISTS equipped_accessory_id,
DROP COLUMN IF EXISTS created_at,
DROP COLUMN IF EXISTS updated_at;

-- Step 4: Drop indexes that were created
DROP INDEX IF EXISTS idx_username ON players;
DROP INDEX IF EXISTS idx_created_at ON players;

COMMIT;

/*
✅ ROLLBACK COMPLETE

This rollback has:
1. ✅ Removed all shop/upgrade system tables
2. ✅ Removed all currency columns from players
3. ✅ Restored players table to original state
4. ✅ Preserved player login and authentication data

⚠️ WARNING: The following data has been PERMANENTLY DELETED:
- All shop items
- All upgrade costs
- All player inventory
- All upgrade history
- All currency transactions

To restore from backup:
1. Stop the application
2. Restore database from backup taken before migration 001
3. Verify data integrity
4. Restart application

*/
