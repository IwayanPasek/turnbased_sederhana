"""
============================================================================
BACKEND IMPLEMENTATION GUIDE: Shop & Upgrade System
============================================================================
Purpose: Complete guide to implement shop and upgrade APIs in FastAPI backend
Database: MySQL 5.7+ / TiDB
Framework: FastAPI + PyMySQL
============================================================================
"""

# Required imports (add to main.py)
from decimal import Decimal
from typing import List, Optional
import json

# ============================================================================
# 1. PYDANTIC MODELS (Request/Response Schemas)
# ============================================================================

class ShopItem(BaseModel):
    id: int
    name: str
    description: str
    item_type: str  # 'weapon', 'armor', 'accessory'
    rarity: str  # 'common', 'uncommon', 'rare', 'epic', 'legendary'
    base_stat: int
    max_level: int
    is_active: bool

class UpgradeCost(BaseModel):
    level: int
    coins_cost: int
    gems_cost: int

class PlayerInventoryItem(BaseModel):
    inventory_id: int
    item: ShopItem
    current_level: int
    is_equipped: bool
    acquired_at: str
    last_upgraded_at: Optional[str]

class PlayerProfile(BaseModel):
    player_id: int
    username: str
    coins: int
    gems: int
    equipped_weapon: Optional[PlayerInventoryItem]
    equipped_armor: Optional[PlayerInventoryItem]
    equipped_accessory: Optional[PlayerInventoryItem]

class BuyItemRequest(BaseModel):
    shop_item_id: int

class UpgradeItemRequest(BaseModel):
    inventory_item_id: int

class EquipItemRequest(BaseModel):
    inventory_item_id: int

# ============================================================================
# 2. HELPER FUNCTIONS
# ============================================================================

def verify_token(token: str) -> Optional[str]:
    \"\"\"Extract username from JWT token\"\"\"
    try:
        secret_key = os.getenv("JWT_SECRET", "fallback_secret_jangan_dipakai_di_produksi")
        payload = jwt.decode(token, secret_key, algorithms=["HS256"])
        return payload.get("username")
    except jwt.ExpiredSignatureError:
        return None
    except jwt.PyJWTError:
        return None

def get_player_id(connection, username: str) -> Optional[int]:
    \"\"\"Get player ID from username\"\"\"
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            result = cursor.fetchone()
            return result['id'] if result else None
    except Exception:
        return None

def get_player_currency(connection, player_id: int) -> dict:
    \"\"\"Get player's current coins and gems\"\"\"
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT coins, gems FROM players WHERE id = %s",
                (player_id,)
            )
            result = cursor.fetchone()
            if result:
                return {"coins": result['coins'], "gems": result['gems']}
            return {"coins": 0, "gems": 0}
    except Exception:
        return {"coins": 0, "gems": 0}

# ============================================================================
# 3. SHOP ENDPOINTS
# ============================================================================

@app.get("/shop/items", tags=["shop"])
def get_shop_items(item_type: Optional[str] = None, rarity: Optional[str] = None):
    \"\"\"Get all shop items, optionally filtered by type and rarity\"\"\"
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            query = "SELECT * FROM shop_items WHERE is_active = TRUE"
            params = []

            if item_type:
                query += " AND item_type = %s"
                params.append(item_type)

            if rarity:
                query += " AND rarity = %s"
                params.append(rarity)

            query += " ORDER BY rarity, name"
            cursor.execute(query, params)
            items = cursor.fetchall()
            return {"items": items}
    finally:
        conn.close()

@app.get("/shop/item/{item_id}", tags=["shop"])
def get_shop_item_details(item_id: int):
    \"\"\"Get detailed information about a specific item including upgrade costs\"\"\"
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get item details
            cursor.execute("SELECT * FROM shop_items WHERE id = %s", (item_id,))
            item = cursor.fetchone()

            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            # Get upgrade costs for this item
            cursor.execute(
                "SELECT level, coins_cost, gems_cost FROM upgrade_costs WHERE shop_item_id = %s ORDER BY level",
                (item_id,)
            )
            upgrade_costs = cursor.fetchall()

            return {
                "item": item,
                "upgrade_costs": upgrade_costs
            }
    finally:
        conn.close()

# ============================================================================
# 4. INVENTORY ENDPOINTS
# ============================================================================

@app.get("/inventory", tags=["inventory"])
def get_player_inventory(token: str = None):
    \"\"\"Get player's inventory\"\"\"
    if not token:
        raise HTTPException(status_code=401, detail="Token diperlukan")

    username = verify_token(token)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player ID
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player['id']

            # Get inventory items with shop details
            cursor.execute("""
                SELECT pi.id, pi.current_level, pi.is_equipped,
                       pi.acquired_at, pi.last_upgraded_at,
                       si.id as shop_item_id, si.name, si.description,
                       si.item_type, si.rarity, si.base_stat, si.max_level
                FROM player_inventory pi
                JOIN shop_items si ON pi.shop_item_id = si.id
                WHERE pi.player_id = %s
                ORDER BY si.item_type, si.rarity, si.name
            """, (player_id,))

            inventory = cursor.fetchall()
            return {"inventory": inventory, "player_id": player_id}
    finally:
        conn.close()

# ============================================================================
# 5. BUY/PURCHASE ENDPOINTS
# ============================================================================

@app.post("/shop/buy", tags=["shop"])
def buy_item(request: BuyItemRequest, token: str = None):
    \"\"\"Purchase an item from shop\"\"\"
    if not token:
        raise HTTPException(status_code=401, detail="Token diperlukan")

    username = verify_token(token)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute("SELECT id, coins FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player['id']
            current_coins = player['coins']

            # Get item
            cursor.execute("SELECT base_stat, max_level FROM shop_items WHERE id = %s", (request.shop_item_id,))
            item = cursor.fetchone()
            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            # Check if player already owns this item
            cursor.execute(
                "SELECT id FROM player_inventory WHERE player_id = %s AND shop_item_id = %s",
                (player_id, request.shop_item_id)
            )
            existing = cursor.fetchone()

            if existing:
                raise HTTPException(status_code=400, detail="Anda sudah memiliki item ini")

            # Get level 1 cost
            cursor.execute(
                "SELECT coins_cost, gems_cost FROM upgrade_costs WHERE shop_item_id = %s AND level = 1",
                (request.shop_item_id,)
            )
            cost = cursor.fetchone()

            if not cost:
                raise HTTPException(status_code=400, detail="Harga item tidak ditemukan")

            coins_required = cost['coins_cost']

            # Check if player has enough coins
            if current_coins < coins_required:
                raise HTTPException(status_code=400, detail="Koin tidak cukup")

            # Deduct coins
            new_coins = current_coins - coins_required
            cursor.execute(
                "UPDATE players SET coins = %s WHERE id = %s",
                (new_coins, player_id)
            )

            # Add to inventory
            cursor.execute(
                "INSERT INTO player_inventory (player_id, shop_item_id, current_level, is_equipped) VALUES (%s, %s, 1, FALSE)",
                (player_id, request.shop_item_id)
            )
            inventory_id = cursor.lastrowid

            # Log transaction
            cursor.execute(
                "INSERT INTO currency_transactions (player_id, transaction_type, currency_type, coins_change, reason, reference_id) VALUES (%s, %s, %s, %s, %s, %s)",
                (player_id, 'purchase', 'coins', -coins_required, f'Membeli item {request.shop_item_id}', request.shop_item_id)
            )

            conn.commit()

            return {
                "status": "success",
                "message": "Item berhasil dibeli",
                "inventory_id": inventory_id,
                "new_coins": new_coins
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# ============================================================================
# 6. UPGRADE ENDPOINTS
# ============================================================================

@app.post("/inventory/upgrade", tags=["inventory"])
def upgrade_item(request: UpgradeItemRequest, token: str = None):
    \"\"\"Upgrade an item to the next level\"\"\"
    if not token:
        raise HTTPException(status_code=401, detail="Token diperlukan")

    username = verify_token(token)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute("SELECT id, coins, gems FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player['id']
            current_coins = player['coins']
            current_gems = player['gems']

            # Get inventory item
            cursor.execute("""
                SELECT pi.id, pi.player_id, pi.shop_item_id, pi.current_level,
                       si.max_level
                FROM player_inventory pi
                JOIN shop_items si ON pi.shop_item_id = si.id
                WHERE pi.id = %s
            """, (request.inventory_item_id,))

            inv_item = cursor.fetchone()
            if not inv_item:
                raise HTTPException(status_code=404, detail="Item di inventory tidak ditemukan")

            if inv_item['player_id'] != player_id:
                raise HTTPException(status_code=403, detail="Item ini bukan milik Anda")

            # Check if already at max level
            current_level = inv_item['current_level']
            max_level = inv_item['max_level']

            if current_level >= max_level:
                raise HTTPException(status_code=400, detail="Item sudah mencapai level maksimal")

            # Get upgrade cost for next level
            next_level = current_level + 1
            cursor.execute(
                "SELECT coins_cost, gems_cost FROM upgrade_costs WHERE shop_item_id = %s AND level = %s",
                (inv_item['shop_item_id'], next_level)
            )

            cost = cursor.fetchone()
            if not cost:
                raise HTTPException(status_code=400, detail="Biaya upgrade tidak ditemukan")

            coins_required = cost['coins_cost']
            gems_required = cost['gems_cost']

            # Check resources
            if current_coins < coins_required or current_gems < gems_required:
                raise HTTPException(
                    status_code=400,
                    detail=f"Sumber daya tidak cukup. Butuh: {coins_required} koin, {gems_required} batu mulia"
                )

            # Perform upgrade
            new_coins = current_coins - coins_required
            new_gems = current_gems - gems_required

            cursor.execute(
                "UPDATE players SET coins = %s, gems = %s WHERE id = %s",
                (new_coins, new_gems, player_id)
            )

            cursor.execute(
                "UPDATE player_inventory SET current_level = %s, last_upgraded_at = NOW() WHERE id = %s",
                (next_level, request.inventory_item_id)
            )

            # Log upgrade
            cursor.execute(
                "INSERT INTO player_upgrades (player_id, inventory_item_id, from_level, to_level, coins_spent, gems_spent) VALUES (%s, %s, %s, %s, %s, %s)",
                (player_id, request.inventory_item_id, current_level, next_level, coins_required, gems_required)
            )

            # Log transaction
            cursor.execute(
                "INSERT INTO currency_transactions (player_id, transaction_type, currency_type, coins_change, gems_change, reason, reference_id) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (player_id, 'purchase', 'both', -coins_required, -gems_required, f'Upgrade item level {current_level} ke {next_level}', request.inventory_item_id)
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"Item berhasil di-upgrade ke level {next_level}",
                "new_level": next_level,
                "new_coins": new_coins,
                "new_gems": new_gems
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# ============================================================================
# 7. EQUIP/UNEQUIP ENDPOINTS
# ============================================================================

@app.post("/inventory/equip", tags=["inventory"])
def equip_item(request: EquipItemRequest, token: str = None):
    \"\"\"Equip an item in its corresponding slot\"\"\"
    if not token:
        raise HTTPException(status_code=401, detail="Token diperlukan")

    username = verify_token(token)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player['id']

            # Get inventory item with type info
            cursor.execute("""
                SELECT pi.id, pi.player_id, si.item_type
                FROM player_inventory pi
                JOIN shop_items si ON pi.shop_item_id = si.id
                WHERE pi.id = %s
            """, (request.inventory_item_id,))

            inv_item = cursor.fetchone()
            if not inv_item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            if inv_item['player_id'] != player_id:
                raise HTTPException(status_code=403, detail="Item bukan milik Anda")

            item_type = inv_item['item_type']

            # Determine equipment slot
            if item_type == 'weapon':
                slot_column = 'equipped_weapon_id'
            elif item_type == 'armor':
                slot_column = 'equipped_armor_id'
            elif item_type == 'accessory':
                slot_column = 'equipped_accessory_id'
            else:
                raise HTTPException(status_code=400, detail="Tipe item tidak valid")

            # Unequip old item in this slot
            cursor.execute(f"SELECT {slot_column} FROM players WHERE id = %s", (player_id,))
            old_equipped = cursor.fetchone()[slot_column]

            if old_equipped:
                cursor.execute(
                    "UPDATE player_inventory SET is_equipped = FALSE WHERE id = %s",
                    (old_equipped,)
                )

            # Equip new item
            cursor.execute(
                f"UPDATE players SET {slot_column} = %s WHERE id = %s",
                (request.inventory_item_id, player_id)
            )

            cursor.execute(
                "UPDATE player_inventory SET is_equipped = TRUE WHERE id = %s",
                (request.inventory_item_id,)
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"{item_type.capitalize()} berhasil dilengkapi"
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# ============================================================================
# 8. PROFILE ENDPOINT (Updated to include equipment)
# ============================================================================

@app.get("/stats", tags=["profile"])
def get_player_stats(token: str = None):
    \"\"\"Get player's stats including currency and equipped items\"\"\"
    if not token:
        raise HTTPException(status_code=401, detail="Token diperlukan")

    username = verify_token(token)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player with stats
            cursor.execute("""
                SELECT p.id, p.username, p.coins, p.gems, p.equipped_weapon_id,
                       p.equipped_armor_id, p.equipped_accessory_id,
                       ps.mmr_score, ps.wins, ps.losses
                FROM players p
                LEFT JOIN player_stats ps ON p.id = ps.player_id
                WHERE p.username = %s
            """, (username,))

            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            # Get equipped items details
            equipped = {}
            for slot_name, slot_id in [('weapon', player['equipped_weapon_id']),
                                        ('armor', player['equipped_armor_id']),
                                        ('accessory', player['equipped_accessory_id'])]:
                if slot_id:
                    cursor.execute("""
                        SELECT pi.current_level, si.name, si.base_stat
                        FROM player_inventory pi
                        JOIN shop_items si ON pi.shop_item_id = si.id
                        WHERE pi.id = %s
                    """, (slot_id,))
                    item = cursor.fetchone()
                    if item:
                        equipped[slot_name] = item

            return {
                "player_id": player['id'],
                "username": player['username'],
                "coins": player['coins'],
                "gems": player['gems'],
                "mmr": player['mmr_score'] or 1000,
                "wins": player['wins'] or 0,
                "losses": player['losses'] or 0,
                "equipped": equipped
            }
    finally:
        conn.close()

"""
============================================================================
INTEGRATION NOTES
============================================================================

1. Add these endpoints to your main.py after the existing endpoints

2. Dependencies already in requirements.txt:
   - PyMySQL
   - PyJWT
   - fastapi
   - pydantic

3. Test with endpoints:
   GET /shop/items
   GET /shop/item/{item_id}
   GET /inventory?token=<jwt_token>
   POST /shop/buy {"shop_item_id": 1}
   POST /inventory/upgrade {"inventory_item_id": 1}
   POST /inventory/equip {"inventory_item_id": 1}
   GET /stats?token=<jwt_token>

4. Currency earned from battles:
   - Add to GameRoom.process_action() after win:

   cursor.execute(
       "UPDATE players SET coins = coins + 50 WHERE username = %s",
       (winner_username,)
   )
   cursor.execute(
       "INSERT INTO currency_transactions (player_id, transaction_type, ...) VALUES (...)"
   )

============================================================================
"""
