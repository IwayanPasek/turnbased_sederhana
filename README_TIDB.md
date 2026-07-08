# TiDB Cloud Integration & Setup Guide

This project is configured to use **TiDB Cloud (Serverless)** as its primary relational database. This document serves as a guide for developers and AI agents to understand the database setup, connection configuration, and migration architecture.

---

## 1. Database Configuration (.env)

The backend is configured via `backend_app/.env`. Here is the reference setup for TiDB Cloud Serverless:

```env
# Database Credentials
DB_HOST=gateway01.ap-southeast-1.prod.alicloud.tidbcloud.com # Use your TiDB host
DB_PORT=4000                                               # TiDB Serverless standard port
DB_USER=2TFDS4i8ZzsHqvF.root                                # TiDB username format (often prefix.root)
DB_PASSWORD=pVm7xA6tM18t2g9m                                # Secure password
DB_NAME=turnbased_db

# SSL Configuration (Mandatory for TiDB Cloud Serverless in production)
DB_USE_SSL=1

# Security Key for JWT Session Tokens
JWT_SECRET=af085de29c8e072596d8fd1ac399c7c6833421743dc9bb0f138406dfdb2af057
```

---

## 2. TiDB Connection Logic (PyMySQL + SSL Fallback)

In `backend_app/main.py`, the connection helper automatically detects if the connection is targeting TiDB Cloud or requires SSL:

- TiDB Cloud Serverless requires SSL encryption by default.
- If `DB_USE_SSL=1` or `"tidbcloud"` is present in the `DB_HOST`, PyMySQL is configured to use SSL (`ssl={"ssl": {}}`).
- A fallback block is implemented: if SSL handshakes fail (e.g. during local tests on standard MySQL), it automatically retries without SSL.

---

## 3. Database Schema Layout

TiDB stores the following tables defined in `migrations/001_shop_upgrade_system.sql`:

1. **`players`**: Account information, coins, gems.
2. **`player_stats`**: Matches, wins, losses, and matchmaking rating (MMR).
3. **`shop_items`**: Upgradable gear catalog (weapons, armor, accessories).
4. **`player_inventory`**: Link table representing items purchased by players, including equipped slots.
5. **`upgrade_costs`**: Progression rules defining coin/gem costs for level transitions.
6. **`player_upgrades`**: Immutable audit logs of upgrades.
7. **`currency_transactions`**: Audit logs of all purchases and upgrades.

---

## 4. Auto-Migration & Boot Sequence

When the FastAPI server starts up (`startup_db_migration` hook):
1. It attempts to connect to the host and ensures `CREATE DATABASE IF NOT EXISTS turnbased_db` is executed.
2. It checks for the existence of the `players` table. If missing, it runs the schema migration:
   - `migrations/001_shop_upgrade_system.sql`
3. It checks for the existence of the `shop_items` table. If missing, it runs the initial seed:
   - `migrations/002_seed_shop_items.sql` (Inserts initial items, including the legendary *Wrath of the Cow* special weapon).

---

## 5. Developer Notes for TiDB Compatibility

When modifying queries or schemas:
- **`ADD COLUMN IF NOT EXISTS`**: TiDB supports this syntax, allowing safe schema rollouts.
- **Constraints**: Use InnoDB compatibility settings.
- **Unsigned Floats**: TiDB does not support `FLOAT UNSIGNED` natively. `FLOAT` is used instead in the migration files.
- **Auto-Commit / Transactions**: Ensure transactions are explicitly committed using `conn.commit()` as PyMySQL does not auto-commit statement executions by default.
