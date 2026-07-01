# Shop & Upgrade System - Complete Design Package

## 📦 Deliverables Summary

This comprehensive package contains everything needed to implement a complete shop and upgrade system for the Turn-Based Game application.

---

## 📁 Files Created

### 1. **SHOP_UPGRADE_SYSTEM_DESIGN.md** (980 lines)
   Complete technical design document covering:
   
   ✅ **Database Schema Design** (Section 1)
   - `players` table (modified) - Added currency fields
   - `shop_items` table - Master catalog of items
   - `player_inventory` table - Player inventory tracking
   - `player_upgrades` table - Upgrade audit log
   - `upgrade_costs` table - Cost matrix per level
   - `currency_transactions` table - Audit trail
   
   ✅ **Data Relationships** (Section 2)
   - Foreign key constraints with CASCADE/RESTRICT
   - Unique constraints for equipment slots
   - Referential integrity rules
   
   ✅ **Migration Guide** (Section 3)
   - Pre-migration checklist
   - Step-by-step migration procedure
   - Rollback strategy
   
   ✅ **Sample Data** (Section 4)
   - 15 shop items (5 weapons, 5 armor, 5 accessories)
   - 60 upgrade cost entries (4-9 levels per item)
   - Test player data examples
   
   ✅ **API Endpoints** (Section 5)
   - Shop endpoints (list, purchase, upgrade)
   - Inventory endpoints (equip, unequip, get items)
   - Currency endpoints (balance, transactions, admin)
   
   ✅ **Implementation Checklist** (Section 6)
   - Database layer tasks
   - Backend layer tasks
   - Frontend layer tasks
   - Testing procedures
   - Deployment steps
   
   ✅ **Performance & Security** (Sections 7-8)
   - Index strategy and query optimization
   - Data integrity and rollback procedures
   - Audit and verification queries

---

### 2. **IMPLEMENTATION_GUIDE.md** (525 lines)
   Practical implementation guide covering:
   
   ✅ **Quick Start** (Section 1)
   - Database setup commands
   - Verification steps
   
   ✅ **System Architecture** (Section 2)
   - System diagram (Frontend → Backend → Database)
   - Data flow for purchase, upgrade, equip operations
   
   ✅ **Key Implementation Details** (Section 3)
   - Currency system (coins vs gems)
   - Equipment slots (3 slots: weapon/armor/accessory)
   - Upgrade mechanics (levels and costs)
   - Stat calculation formulas
   
   ✅ **Database Queries** (Section 4)
   - Get player's equipped items
   - Get complete inventory
   - Calculate total stats
   - Get upgrade costs
   - Analytics queries
   
   ✅ **Error Handling** (Section 5)
   - Purchase validation logic
   - Upgrade validation logic
   - Exception handling
   
   ✅ **Testing Checklist** (Section 6)
   - Unit tests
   - Integration tests
   - Performance tests
   - Load tests
   
   ✅ **API Response Examples** (Section 7)
   - Complete JSON examples for all endpoints
   - Success and error responses
   
   ✅ **Monitoring & Analytics** (Section 8)
   - Key metrics to track
   - Analytics queries
   - Reporting views
   
   ✅ **Troubleshooting** (Section 9)
   - Common issues and solutions
   - Anti-cheat measures
   - Performance optimization

---

### 3. **migrations/001_shop_upgrade_system.sql** (335 lines)
   Main database migration script:
   
   ✅ **Phase 1: Alter Existing Tables**
   - Add `coins` column (default 1000)
   - Add `gems` column (default 100)
   - Add `created_at` and `updated_at` timestamps
   - Add performance indexes
   
   ✅ **Phase 2: Create New Tables**
   - `shop_items` - Master catalog
   - `player_inventory` - Player items
   - `player_upgrades` - Upgrade audit
   - `upgrade_costs` - Cost matrix
   - `currency_transactions` - Transaction log
   
   ✅ **Features**
   - Full comments on every table and column
   - Foreign key constraints with cascade/restrict rules
   - Performance indexes on all critical columns
   - Proper data types (INT UNSIGNED for IDs)
   - UTF8MB4 charset for internationalization

---

### 4. **migrations/002_seed_shop_items.sql** (247 lines)
   Initial data seeding script:
   
   ✅ **15 Shop Items Inserted**
   - 5 Weapons (Iron Sword → Sword of Legends)
   - 5 Armor (Leather Armor → Aegis of the Gods)
   - 5 Accessories (Health Amulet → Heart of the Universe)
   
   ✅ **60 Upgrade Cost Entries**
   - Common items: 4 upgrade levels
   - Uncommon items: 4 upgrade levels
   - Rare items: 4 upgrade levels
   - Epic items: 4 upgrade levels
   - Legendary items: 9 upgrade levels
   
   ✅ **Rarity Tier Pricing**
   - Common: 100-150 coins
   - Uncommon: 250-350 coins
   - Rare: 500-600 coins
   - Epic: 1000-1200 coins
   - Legendary: 5000 coins
   
   ✅ **Verification Queries**
   - Total items count
   - Items by type
   - Items by rarity
   - Upgrade costs by item
   - Total progression costs

---

## 📊 Database Schema Overview

### Table Summary
```
┌──────────────────────────────────────────────────────────────┐
│ players (MODIFIED)                                           │
├──────────────────────────────────────────────────────────────┤
│ ✓ id, username, password_hash (existing)                    │
│ ✓ coins (NEW) - INT UNSIGNED, default 1000                 │
│ ✓ gems (NEW) - INT UNSIGNED, default 100                   │
│ ✓ created_at, updated_at (NEW) - TIMESTAMP                │
│ Indexes: id (PK), username (UNIQUE), coins, gems, created_at│
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ shop_items (NEW)                                             │
├──────────────────────────────────────────────────────────────┤
│ PK: item_id (INT UNSIGNED AUTO_INCREMENT)                  │
│ item_name, item_type, stat_type, description               │
│ base_stat_boost, base_cost_coins, base_cost_gems           │
│ rarity, is_upgradeable, max_level, is_active               │
│ created_at, updated_at                                      │
│ Indexes: item_type, rarity, stat_type, is_active, created_at│
│ Unique: item_name                                           │
│ Total: 15 items loaded                                      │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ player_inventory (NEW)                                       │
├──────────────────────────────────────────────────────────────┤
│ PK: inventory_id (INT UNSIGNED AUTO_INCREMENT)             │
│ FK: player_id → players.id (CASCADE)                       │
│ FK: item_id → shop_items.item_id (RESTRICT)               │
│ current_level, quantity, is_equipped, equipped_slot        │
│ acquired_date, last_upgraded                               │
│ Unique: (player_id, item_id, equipped_slot)               │
│ Indexes: player_id, item_id, is_equipped, player_equipped  │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ upgrade_costs (NEW)                                          │
├──────────────────────────────────────────────────────────────┤
│ PK: cost_id (INT UNSIGNED AUTO_INCREMENT)                 │
│ FK: item_id → shop_items.item_id (CASCADE)                │
│ from_level, to_level, cost_coins, cost_gems               │
│ stat_bonus_per_level                                       │
│ Unique: (item_id, from_level, to_level)                   │
│ Indexes: item_id                                           │
│ Total: 60 cost entries loaded                              │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ player_upgrades (NEW)                                        │
├──────────────────────────────────────────────────────────────┤
│ PK: upgrade_id (INT UNSIGNED AUTO_INCREMENT)              │
│ FK: player_id → players.id (CASCADE)                       │
│ FK: item_id → shop_items.item_id (RESTRICT)               │
│ from_level, to_level, cost_coins, cost_gems               │
│ upgraded_at (immutable audit log)                          │
│ Indexes: player_id, item_id, upgraded_at                  │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ currency_transactions (NEW)                                  │
├──────────────────────────────────────────────────────────────┤
│ PK: transaction_id (INT UNSIGNED AUTO_INCREMENT)          │
│ FK: player_id → players.id (CASCADE)                       │
│ transaction_type (ENUM: purchase, upgrade, reward, etc.)   │
│ coins_change, gems_change, reason                          │
│ reference_id (optional link to inventory_id/upgrade_id)   │
│ created_at (immutable audit log)                           │
│ Indexes: player_id, transaction_type, created_at           │
└──────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Features

### Currency System
- **Coins**: Soft currency (earned in-game from battles)
  - Default: 1000 per new player
  - Used for common/uncommon items and upgrades
  
- **Gems**: Premium currency (purchased with real money)
  - Default: 100 per new player
  - Used for rare/epic/legendary items and upgrades
  - Limited availability (encourages monetization)

### Equipment Slots (3 Total)
1. **Weapon** → Increases Attack stat
2. **Armor** → Increases Defense stat
3. **Accessory** → Increases HP stat

Players can own multiple items but equip only one per slot.

### Upgrade System
- **Levels**: 1 (base) to 5-10 (max, varies by rarity)
- **Cost Model**: Exponential (level 1→2 costs less than 4→5)
- **Stat Progression**: Fixed bonus per level (e.g., +10 attack)
- **Mixed Costs**: Legendary upgrades require both coins AND gems

### Item Tiers (by Rarity)
```
Common (100 coins)
  ↓
Uncommon (250 coins)
  ↓
Rare (500 coins)
  ↓
Epic (1000 coins)
  ↓
Legendary (5000 coins)
```

---

## 🔒 Security & Data Integrity

### Constraints
1. **Foreign Key Constraints**
   - Player deletion cascades to inventory (cleanup)
   - Item deletion blocked if owned by players (RESTRICT)

2. **Unique Constraints**
   - One item per equipped slot (prevents bugs)
   - One cost entry per level transition (prevents duplicates)

3. **Immutable Audit Logs**
   - `player_upgrades` - Can't modify/delete upgrade history
   - `currency_transactions` - Can't modify/delete transaction history
   - Ensures accountability and anti-cheat

### Anti-Cheat Measures
1. **Server-Side Validation**
   - All currency operations validated on backend
   - Client can't directly modify currency

2. **Transaction Logging**
   - Every purchase logged with reason
   - Every upgrade logged with costs
   - Audit trail helps detect anomalies

3. **Database Transactions**
   - Atomic operations prevent partial updates
   - Row-level locks prevent race conditions
   - Consistent state guaranteed

---

## 🚀 Implementation Status

### ✅ Completed
- Database schema design (5 new tables, 1 modified)
- Migration scripts (safe, rollbackable)
- Seed data (15 items, 60 upgrade costs)
- Complete documentation (1500+ lines)
- API endpoint specifications
- Query examples
- Testing procedures

### ⏳ Ready for Implementation
- FastAPI backend endpoints
- Flutter UI screens
- Unit tests
- Integration tests
- Performance testing
- Deployment

---

## 📋 Quick Reference

### File Locations
```
app/
├── SHOP_UPGRADE_SYSTEM_DESIGN.md         (Design document)
├── IMPLEMENTATION_GUIDE.md               (Implementation guide)
└── migrations/
    ├── 001_shop_upgrade_system.sql       (Schema migration)
    └── 002_seed_shop_items.sql           (Initial data)
```

### Migration Steps
```bash
# 1. Backup current database
mysqldump -u user -p database > backup.sql

# 2. Run schema migration
mysql -u user -p database < migrations/001_shop_upgrade_system.sql

# 3. Load initial data
mysql -u user -p database < migrations/002_seed_shop_items.sql

# 4. Verify
mysql -u user -p database -e "SELECT COUNT(*) FROM shop_items;"
```

### Expected Results
- 15 shop items
- 60 upgrade cost entries
- Players table extended with coins/gems columns
- All foreign keys and indexes created
- Ready for API implementation

---

## 💡 Usage Examples

### Purchase Item
```python
POST /shop/purchase
{
    "item_id": 1,
    "currency_type": "coins"  # or "gems"
}
Response: { inventory_id: 5, player_balance: { coins: 900, gems: 100 } }
```

### Upgrade Item
```python
POST /shop/upgrade
{
    "inventory_id": 5,
    "target_level": 3
}
Response: { current_level: 3, costs_applied: { coins: 300, gems: 0 } }
```

### Equip Item
```python
POST /inventory/equip
{
    "inventory_id": 5,
    "slot": "weapon"
}
Response: { inventory: [...], player_stats: { attack: 40, defense: 10, hp: 100 } }
```

### Get Stats
```python
GET /player/stats
Response: {
    base_stats: { hp: 100, attack: 10, defense: 10 },
    equipment_bonuses: { hp: 0, attack: 30, defense: 0 },
    total_stats: { hp: 100, attack: 40, defense: 10 }
}
```

---

## 🎮 Game Design Notes

### Progression Loop
1. **Earn** coins from battles
2. **Save** coins for desired items
3. **Purchase** item from shop
4. **Equip** item to boost stats
5. **Upgrade** item to increase bonus
6. **Swap** items for different strategies
7. Repeat with next item

### Monetization (Optional)
- Gems purchased for real money
- Legendary items require gems
- Premium upgrades require gems
- Battle pass with gem rewards

### Balancing Tips
- Adjust upgrade costs if progression too fast/slow
- Increase gem requirements if gems not selling
- Add daily quests to reward coins
- Seasonal items to encourage return visits

---

## 📞 Support

For questions or issues:
1. Check **IMPLEMENTATION_GUIDE.md** troubleshooting section
2. Review database design in **SHOP_UPGRADE_SYSTEM_DESIGN.md**
3. Run verification queries from the guides
4. Check migration scripts for comments
5. Review sample data for format examples

---

## 📈 Future Roadmap

**Phase 2** (Optional Enhancements):
- Trading system between players
- Auction house
- Daily quests with currency rewards
- Battle pass system
- Crafting system
- Enchantments
- Set bonuses

**Phase 3** (Advanced):
- Trading marketplace
- Seasonal content
- Leaderboards by wealth
- Item durability
- Rarity tiers expansion
- Special events

---

## ✨ Summary

This comprehensive shop and upgrade system design provides:

✅ **Complete Database Schema** - Production-ready SQL with proper constraints
✅ **Safe Migration Path** - Backward compatible, easy rollback
✅ **Rich Game Mechanics** - Currency, items, upgrades, equipment
✅ **Security & Audit** - Anti-cheat measures, immutable logs
✅ **Extensible Design** - Foundation for trading, crafting, etc.
✅ **Performance Optimized** - Proper indexes, efficient queries
✅ **Well Documented** - 1500+ lines of specifications and guides
✅ **Ready to Implement** - All designs finalized, specs clear

**Total Development Time Estimate**:
- Backend APIs: 2-3 days
- Frontend screens: 2-3 days
- Testing: 1-2 days
- Deployment: 1 day
- **Total: 1-2 weeks** to full implementation

🎉 Ready to bring the shop system to life!
