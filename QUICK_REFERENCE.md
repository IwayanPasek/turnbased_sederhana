# ⚡ QUICK REFERENCE GUIDE - SHOP & UPGRADE SYSTEM

## 📂 All Files Created

### Backend SQL Migrations
```
backend_app/migrations/
├── 001_shop_upgrade_system.sql    (256 lines) - Database schema
├── 002_seed_shop_items.sql        (254 lines) - Shop data
└── 999_rollback.sql               (67 lines)  - Emergency rollback
```

### Backend API Code
```
backend_app/
├── SHOP_UPGRADE_API.py            (590 lines) - All 8 endpoints
└── main.py                        (INTEGRATE API code here)
```

### Documentation
```
app/
├── SHOP_UPGRADE_SYSTEM_README.md  (472 lines) - Complete guide
└── IMPLEMENTATION_SUMMARY.md      (281 lines) - This summary
```

---

## 🚀 Quick Start (Copy & Paste Commands)

### Step 1: Database Setup (5 minutes)

```bash
# Navigate to database directory
cd backend_app/migrations

# Backup existing database first!
mysqldump -u root -p your_database > backup_before_shop.sql

# Run schema migration
mysql -u root -p your_database < 001_shop_upgrade_system.sql

# Seed shop items
mysql -u root -p your_database < 002_seed_shop_items.sql

# Verify (should show 15)
mysql -u root -p your_database -e "SELECT COUNT(*) as items FROM shop_items;"
```

### Step 2: Backend Integration (30 minutes)

1. Open `backend_app/main.py`
2. Copy ALL content from `backend_app/SHOP_UPGRADE_API.py`
3. Paste after existing endpoints
4. Add to `GameRoom.process_action()` after GAME OVER:
   ```python
   cursor.execute("UPDATE players SET coins = coins + 50 WHERE username = %s", (player,))
   ```
5. Test with: `uvicorn main:app --reload`

### Step 3: API Testing (10 minutes)

```bash
# Get all shop items
curl http://localhost:8000/shop/items

# Get specific item (replace 1 with item ID)
curl http://localhost:8000/shop/item/1

# Get player inventory (replace token)
curl "http://localhost:8000/inventory?token=YOUR_JWT_TOKEN"

# Buy an item (replace token and item_id)
curl -X POST http://localhost:8000/shop/buy \
  -H "Content-Type: application/json" \
  -d '{"shop_item_id": 1}' \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 📊 System Overview

### Database Tables (6 Total)
| Table | Purpose | Records |
|-------|---------|---------|
| players | User accounts + currency | Existing + coins/gems |
| shop_items | Available items | 15 items |
| upgrade_costs | Item upgrade costs | 60 entries |
| player_inventory | Player's items | Variable |
| player_upgrades | Audit log | Variable |
| currency_transactions | Audit log | Variable |

### Shop Items (15 Total)
- **5 Weapons** (Attack): Iron Sword → Infinity Blade
- **5 Armor** (Defense): Leather Armor → God Armor  
- **5 Accessories** (HP): Copper Ring → Heart of the Eternal

### Equipment Slots (3)
- Weapon slot (mutually exclusive)
- Armor slot (mutually exclusive)
- Accessory slot (mutually exclusive)

---

## 🔌 API Endpoints (8 Total)

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/shop/items` | GET | ❌ | List all items |
| `/shop/item/{id}` | GET | ❌ | Get item details |
| `/inventory` | GET | ✅ | Get player inventory |
| `/shop/buy` | POST | ✅ | Buy item |
| `/inventory/upgrade` | POST | ✅ | Upgrade item |
| `/inventory/equip` | POST | ✅ | Equip item |
| `/stats` | GET | ✅ | Get player profile |

---

## 💰 Economy

### Currency Types
- **Coins** (Soft): Earned 50 per win, starting 1000
- **Gems** (Premium): Starting 100

### Cost Examples
| Item | Level 1 Cost | Level 5 Cost |
|------|---------|---------|
| Iron Sword | 0 coins | 350 coins + 20 gems |
| Infinity Blade | 2000 coins + 50 gems | 24800 coins + 650 gems |
| Copper Ring | 0 coins | 150 coins + 12 gems |

---

## 🔄 Migration Safety Checklist

- [ ] Backup database: `mysqldump -u user -p db > backup.sql`
- [ ] Run 001_shop_upgrade_system.sql
- [ ] Check tables exist: `SHOW TABLES LIKE 'shop%'`
- [ ] Run 002_seed_shop_items.sql
- [ ] Verify data: `SELECT COUNT(*) FROM shop_items` → 15
- [ ] Test API endpoints
- [ ] Monitor logs for errors

### If Something Goes Wrong

```bash
# Rollback (will DELETE shop system data)
mysql -u root -p your_database < 999_rollback.sql

# OR restore from backup
mysql -u root -p your_database < backup_before_shop.sql
```

---

## 📝 Data Models (Request/Response)

### Buy Item Request
```json
{
  "shop_item_id": 1
}
```

### Buy Item Response
```json
{
  "status": "success",
  "message": "Item berhasil dibeli",
  "inventory_id": 42,
  "new_coins": 950
}
```

### Upgrade Item Request
```json
{
  "inventory_item_id": 1
}
```

### Upgrade Item Response
```json
{
  "status": "success",
  "message": "Item berhasil di-upgrade ke level 2",
  "new_level": 2,
  "new_coins": 1900,
  "new_gems": 95
}
```

### Equip Item Request
```json
{
  "inventory_item_id": 1
}
```

### Equip Item Response
```json
{
  "status": "success",
  "message": "Weapon berhasil dilengkapi"
}
```

---

## 🎯 Implementation Timeline

| Phase | Duration | Task |
|-------|----------|------|
| **Database** | 1 hour | Run migrations, verify |
| **Backend** | 4 hours | Integrate API, test endpoints |
| **Frontend** | 2 days | Create UI screens |
| **Testing** | 1 day | End-to-end testing |
| **Deploy** | 2 hours | Production deployment |

---

## 🔍 Troubleshooting

### "Table already exists" error
- Normal! Migration has built-in safety. Just continue.
- Script uses `CREATE TABLE IF NOT EXISTS`

### "Duplicate key error"
- Run migration on fresh database only
- Or use 999_rollback.sql first

### "Foreign key constraint fails"
- Check that all tables are created
- Run 001 before 002

### API returns 401 Unauthorized
- Make sure JWT token is valid
- Check token hasn't expired (7 day expiry)

### Can't buy item
- Check player has enough coins
- Check item hasn't been purchased already
- Check shop_item_id is valid (1-15)

---

## 📞 Support Resources

1. **Schema Questions** → Check `001_shop_upgrade_system.sql` comments
2. **API Questions** → Check `SHOP_UPGRADE_API.py` docstrings
3. **Integration Help** → Read `SHOP_UPGRADE_SYSTEM_README.md`
4. **Migration Issues** → Use `999_rollback.sql` and restore backup

---

## ✅ Verification Checklist

```bash
# After running migrations, verify this succeeds:

# Check tables exist
mysql -e "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='your_db' AND TABLE_NAME IN ('shop_items', 'upgrade_costs', 'player_inventory');"

# Check shop items (should be 15)
mysql -e "SELECT COUNT(*) FROM shop_items;"

# Check upgrade costs (should be 60)
mysql -e "SELECT COUNT(*) FROM upgrade_costs;"

# Check player columns added
mysql -e "DESC players;" | grep -E "coins|gems|equipped"
```

---

## 🎮 Test Scenario

1. Create account (already works)
2. Login & get JWT token (already works)
3. **NEW:** GET /shop/items → See 15 items
4. **NEW:** POST /shop/buy → Purchase Iron Sword (costs 0 coins)
5. **NEW:** GET /inventory → See purchased item
6. **NEW:** POST /inventory/upgrade → Upgrade to level 2 (costs 50 coins)
7. **NEW:** POST /inventory/equip → Equip the sword
8. **NEW:** GET /stats → See equipped weapon in response

---

## 📊 Performance Expectations

- GET /shop/items: < 100ms
- GET /inventory: < 200ms
- POST /shop/buy: < 500ms
- POST /inventory/upgrade: < 500ms
- POST /inventory/equip: < 300ms

---

**Version**: 1.0  
**Last Updated**: 2026-06-12  
**Status**: ✅ Ready for Implementation

Good luck! 🚀
