# Shop & Upgrade System - Implementation Guide

## Quick Start

### 1. Database Setup (5 minutes)
```bash
# Run migration to create schema
mysql -u user -p database < migrations/001_shop_upgrade_system.sql

# Load initial shop items
mysql -u user -p database < migrations/002_seed_shop_items.sql

# Verify setup
mysql -u user -p database -e "SELECT COUNT(*) FROM shop_items;"
```

### 2. Backend Implementation (FastAPI)
See `backend_implementation.py` example endpoints

### 3. Frontend Implementation (Flutter)
See `flutter_implementation.dart` example screens

---

## System Architecture

```
┌─────────────────┐
│   Flutter App   │
│  (Frontend)     │
└────────┬────────┘
         │ HTTP/WebSocket
         │
┌────────▼────────┐
│   FastAPI       │
│   (Backend)     │
└────────┬────────┘
         │ SQL Queries
         │
┌────────▼────────┐
│  MySQL/TiDB     │
│  (Database)     │
└─────────────────┘
```

### Data Flow for Purchase
1. User selects item → Flutter sends POST to `/shop/purchase`
2. Backend validates player currency balance
3. Backend creates transaction record
4. Backend adds item to `player_inventory`
5. Backend deducts currency from `players` table
6. Backend logs transaction in `currency_transactions`
7. Response returns to Flutter with updated inventory

### Data Flow for Upgrade
1. User selects owned item → Flutter sends POST to `/shop/upgrade`
2. Backend fetches upgrade cost from `upgrade_costs` table
3. Backend validates player has enough currency
4. Backend updates `player_inventory.current_level`
5. Backend creates `player_upgrades` record
6. Backend logs currency transaction
7. Response returns with new item level

### Data Flow for Equip/Unequip
1. User clicks equip button → Flutter sends POST to `/inventory/equip`
2. Backend checks if player owns the item
3. Backend unequips any existing item in that slot
4. Backend sets `is_equipped = TRUE` and `equipped_slot = 'weapon'`
5. Backend recalculates player stats (attach bonus stats from equipped items)
6. Response returns with updated inventory and stats

---

## Key Implementation Details

### Currency System
- **Coins**: Soft currency (earned in-game)
  - Earned from battle victories
  - Can be spent on basic items and upgrades
  - No real money conversion

- **Gems**: Premium currency
  - Purchased with real money (implementation not included)
  - Required for expensive items and upgrades
  - Can be earned slowly through achievements

### Equipment Slots
Three mutually exclusive slots per player:
1. **weapon** - Increases attack stat
2. **armor** - Increases defense stat
3. **accessory** - Increases HP stat

Player can have unequipped items, but can only equip ONE per slot.

### Upgrade System
- Each item has a max level (5 for common/uncommon/rare/epic, 10 for legendary)
- Level 1 = base item (no upgrades)
- Upgrade costs increase with each level
- Legendary items require gems for high-level upgrades
- Each upgrade transaction is logged immutably

### Stat Calculation
```python
total_attack = base_attack + sum(equipped_items where stat_type='attack')
total_defense = base_defense + sum(equipped_items where stat_type='defense')
total_hp = base_hp + sum(equipped_items where stat_type='hp')
```

Where each item's contribution = `base_stat_boost * current_level`

Example:
- Base attack: 10
- Equipped: Iron Sword level 3 (+10*3=+30), Steel Blade level 2 (+15*2=+30)
- Total attack: 10 + 30 + 30 = 70

---

## Database Query Examples

### Get Player's Equipped Items with Stats
```sql
SELECT 
    pi.inventory_id,
    si.item_name,
    si.stat_type,
    si.base_stat_boost,
    pi.current_level,
    (si.base_stat_boost * pi.current_level) AS stat_contribution
FROM player_inventory pi
JOIN shop_items si ON pi.item_id = si.item_id
WHERE pi.player_id = 1 AND pi.is_equipped = TRUE;
```

### Get Player's Complete Inventory
```sql
SELECT 
    pi.inventory_id,
    si.item_name,
    si.item_type,
    si.rarity,
    pi.current_level,
    si.max_level,
    pi.is_equipped,
    pi.equipped_slot
FROM player_inventory pi
JOIN shop_items si ON pi.item_id = si.item_id
WHERE pi.player_id = 1
ORDER BY pi.is_equipped DESC, si.rarity DESC;
```

### Calculate Total Player Stats
```sql
SELECT 
    p.id,
    p.username,
    100 + COALESCE(SUM(CASE WHEN si.stat_type = 'hp' 
        THEN si.base_stat_boost * pi.current_level ELSE 0 END), 0) AS total_hp,
    10 + COALESCE(SUM(CASE WHEN si.stat_type = 'attack' 
        THEN si.base_stat_boost * pi.current_level ELSE 0 END), 0) AS total_attack,
    10 + COALESCE(SUM(CASE WHEN si.stat_type = 'defense' 
        THEN si.base_stat_boost * pi.current_level ELSE 0 END), 0) AS total_defense
FROM players p
LEFT JOIN player_inventory pi ON p.id = pi.player_id AND pi.is_equipped = TRUE
LEFT JOIN shop_items si ON pi.item_id = si.item_id
WHERE p.id = 1
GROUP BY p.id, p.username;
```

### Get Upgrade Cost for Specific Item
```sql
SELECT cost_coins, cost_gems
FROM upgrade_costs
WHERE item_id = 1 AND from_level = 2 AND to_level = 3;
```

### Get Affordable Items for Player
```sql
SELECT si.*
FROM shop_items si
WHERE si.base_cost_coins <= (SELECT coins FROM players WHERE id = 1)
  AND si.is_active = TRUE
ORDER BY si.rarity, si.base_cost_coins;
```

### Get Currency Audit Trail for Player
```sql
SELECT * FROM currency_transactions
WHERE player_id = 1
ORDER BY created_at DESC
LIMIT 50;
```

---

## Error Handling

### Purchase Validation
```python
def validate_purchase(player_id: int, item_id: int, currency_type: str):
    # 1. Check player exists
    player = get_player(player_id)
    if not player:
        raise PlayerNotFoundError()
    
    # 2. Check item exists
    item = get_shop_item(item_id)
    if not item:
        raise ItemNotFoundError()
    
    # 3. Check item is active
    if not item.is_active:
        raise ItemNotAvailableError()
    
    # 4. Check currency balance
    cost = item.base_cost_coins if currency_type == 'coins' else item.base_cost_gems
    if currency_type == 'coins' and player.coins < cost:
        raise InsufficientCoinsError(f"Need {cost}, have {player.coins}")
    if currency_type == 'gems' and player.gems < cost:
        raise InsufficientGemsError(f"Need {cost}, have {player.gems}")
    
    # 5. Check inventory space (optional)
    inventory_count = count_player_inventory(player_id)
    if inventory_count >= MAX_INVENTORY_SIZE:
        raise InventoryFullError()
    
    return True
```

### Upgrade Validation
```python
def validate_upgrade(player_id: int, inventory_id: int, target_level: int):
    # 1. Check inventory item exists
    inv_item = get_inventory_item(inventory_id)
    if not inv_item:
        raise InventoryItemNotFoundError()
    
    # 2. Check belongs to player
    if inv_item.player_id != player_id:
        raise UnauthorizedError()
    
    # 3. Check target level is valid
    if target_level <= inv_item.current_level:
        raise InvalidLevelError("Target level must be higher")
    if target_level > inv_item.max_level:
        raise InvalidLevelError(f"Max level is {inv_item.max_level}")
    
    # 4. Check upgrade costs for each level
    total_coins_needed = 0
    total_gems_needed = 0
    for level in range(inv_item.current_level, target_level):
        cost = get_upgrade_cost(inv_item.item_id, level, level + 1)
        total_coins_needed += cost.cost_coins
        total_gems_needed += cost.cost_gems
    
    # 5. Check currency balance
    if player.coins < total_coins_needed:
        raise InsufficientCoinsError()
    if player.gems < total_gems_needed:
        raise InsufficientGemsError()
    
    return (total_coins_needed, total_gems_needed)
```

---

## Testing Checklist

### Unit Tests
```python
# Test currency operations
test_purchase_success()
test_purchase_insufficient_coins()
test_purchase_insufficient_gems()
test_upgrade_success()
test_upgrade_max_level()

# Test inventory operations
test_equip_item()
test_unequip_item()
test_swap_items()
test_cannot_equip_unowned_item()

# Test stat calculations
test_calculate_player_stats_no_equipment()
test_calculate_player_stats_with_equipment()
test_calculate_player_stats_multiple_items()
```

### Integration Tests
```python
# Test complete workflows
test_purchase_and_equip_flow()
test_purchase_upgrade_equip_flow()
test_swap_equipped_items_flow()
test_multiple_players_independent()

# Test database constraints
test_unique_equipped_slot_constraint()
test_cannot_delete_item_while_owned()
test_cascade_delete_player_inventory()
```

### Performance Tests
```python
# Test query performance
test_get_inventory_under_100ms()
test_get_stats_under_50ms()
test_get_shop_items_under_200ms()

# Test under load
test_concurrent_purchases(10_players)
test_concurrent_upgrades(10_players)
test_bulk_item_updates()
```

---

## API Response Examples

### GET /inventory
```json
{
  "player_id": 1,
  "total_items": 3,
  "inventory": [
    {
      "inventory_id": 1,
      "item_id": 1,
      "item_name": "Iron Sword",
      "item_type": "weapon",
      "rarity": "common",
      "current_level": 3,
      "max_level": 5,
      "is_equipped": true,
      "equipped_slot": "weapon",
      "stat_contribution": 30
    },
    {
      "inventory_id": 2,
      "item_name": "Steel Blade",
      "current_level": 1,
      "max_level": 5,
      "is_equipped": false,
      "equipped_slot": null
    }
  ]
}
```

### GET /player/stats
```json
{
  "player_id": 1,
  "base_stats": {
    "hp": 100,
    "attack": 10,
    "defense": 10
  },
  "equipment_bonuses": {
    "hp": 0,
    "attack": 30,
    "defense": 0
  },
  "total_stats": {
    "hp": 100,
    "attack": 40,
    "defense": 10
  },
  "equipped_items": [
    {
      "slot": "weapon",
      "item_name": "Iron Sword",
      "level": 3,
      "bonus": 30
    }
  ]
}
```

### POST /shop/purchase
Request:
```json
{
  "item_id": 1,
  "currency_type": "coins"
}
```

Response (Success):
```json
{
  "success": true,
  "message": "Item purchased successfully",
  "inventory_id": 5,
  "player_balance": {
    "coins": 900,
    "gems": 100
  }
}
```

Response (Error):
```json
{
  "success": false,
  "error": "insufficient_coins",
  "message": "You need 100 coins but only have 50"
}
```

---

## Monitoring & Analytics

### Key Metrics to Track
1. **Purchase volume** - Items sold per day/week
2. **Average upgrade level** - How far players progress
3. **Currency distribution** - Player wealth inequality
4. **Item popularity** - Which items are most wanted
5. **Conversion funnel** - Signup → Purchase → Upgrade

### Queries for Analytics
```sql
-- Top 5 most purchased items
SELECT si.item_name, COUNT(pi.inventory_id) as purchases
FROM player_inventory pi
JOIN shop_items si ON pi.item_id = si.item_id
GROUP BY si.item_id, si.item_name
ORDER BY purchases DESC
LIMIT 5;

-- Average item level by rarity
SELECT si.rarity, AVG(pi.current_level) as avg_level
FROM player_inventory pi
JOIN shop_items si ON pi.item_id = si.item_id
GROUP BY si.rarity;

-- Total currency spent by players
SELECT player_id, 
       SUM(CASE WHEN coins_change < 0 THEN -coins_change ELSE 0 END) as total_coins_spent,
       SUM(CASE WHEN gems_change < 0 THEN -gems_change ELSE 0 END) as total_gems_spent
FROM currency_transactions
GROUP BY player_id
ORDER BY total_coins_spent DESC;
```

---

## Troubleshooting

### Issue: Player has negative currency
**Cause**: Race condition in concurrent purchases
**Solution**: Use database transactions with row-level locks
```python
@app.post("/shop/purchase")
async def purchase_item(token: str, item_id: int):
    try:
        with db.transaction():  # Start transaction
            # Lock player row
            player = db.query("SELECT * FROM players WHERE id = ? FOR UPDATE", (player_id,))
            
            # Check balance and purchase
            # ...
            
            # Commit if successful
    except IntegrityError:
        raise CurrencyError("Purchase failed")
```

### Issue: Inventory shows wrong items
**Cause**: Missing JOIN with shop_items or stale cache
**Solution**: Ensure queries JOIN correctly and invalidate cache on updates

### Issue: Upgrade costs incorrect
**Cause**: Wrong upgrade_costs entries or missing levels
**Solution**: Run verification query
```sql
SELECT * FROM upgrade_costs WHERE item_id = ? ORDER BY from_level;
```

### Issue: Player can equip multiple items to one slot
**Cause**: Missing UNIQUE constraint enforcement
**Solution**: Verify unique constraint exists
```sql
SHOW INDEX FROM player_inventory WHERE Column_name = 'equipped_slot';
```

---

## Future Enhancements

1. **Trading System** - Allow players to trade items with each other
2. **Auction House** - Sell items to other players for currency
3. **Daily Quests** - Earn bonus currency from daily challenges
4. **Battle Pass** - Time-limited progression rewards
5. **Crafting** - Combine items to create better ones
6. **Enchantments** - Add special abilities to items
7. **Set Bonuses** - Extra stats when wearing matching sets
8. **Item Durability** - Equipment wears out and needs repair
9. **Seasonal Items** - Limited-time exclusive items
10. **Leaderboards** - Sort by total stats/wealth

---

## File Reference

- **Design Document**: `SHOP_UPGRADE_SYSTEM_DESIGN.md`
- **Database Migration**: `migrations/001_shop_upgrade_system.sql`
- **Seed Data**: `migrations/002_seed_shop_items.sql`
- **Backend Example**: See next file
- **Frontend Example**: See next file
- **This Guide**: `IMPLEMENTATION_GUIDE.md`

---

## Support & Questions

For issues or questions:
1. Check this guide's Troubleshooting section
2. Review the database design document
3. Examine the API response examples
4. Run verification queries in the database
5. Check server logs for detailed errors

Happy coding! 🎮
