from typing import Optional
from fastapi import APIRouter, Header, HTTPException
from app.core.database import get_db_connection
from app.core.security import verify_token
from app.models.schemas import BuyItemRequest, UpgradeItemRequest, EquipItemRequest
router = APIRouter()

@router.get("/shop/items", tags=["shop"])
def get_shop_items(item_type: Optional[str] = None, rarity: Optional[str] = None):
    """Get all active shop items, optionally filtered by type and rarity.
    Returns items with aliased fields: id, name, base_stat for frontend compatibility.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            query = """
                SELECT
                    item_id   AS id,
                    item_name AS name,
                    item_type,
                    description,
                    base_stat_boost AS base_stat,
                    stat_type,
                    base_cost_coins,
                    base_cost_gems,
                    rarity,
                    is_upgradeable,
                    max_level,
                    icon_url,
                    granted_skill,
                    is_active
                FROM shop_items
                WHERE is_active = TRUE
            """
            params = []

            if item_type:
                query += " AND item_type = %s"
                params.append(item_type)

            if rarity:
                query += " AND rarity = %s"
                params.append(rarity)

            query += " ORDER BY rarity, item_name"
            cursor.execute(query, params)
            items = cursor.fetchall()
            return {"items": items}
    finally:
        conn.close()


@router.get("/shop/item/{item_id}", tags=["shop"])
def get_shop_item_details(item_id: int):
    """Get detailed information about a specific item including upgrade costs."""
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get item details with aliased fields
            cursor.execute(
                """
                SELECT
                    item_id   AS id,
                    item_name AS name,
                    item_type,
                    description,
                    base_stat_boost AS base_stat,
                    stat_type,
                    base_cost_coins,
                    base_cost_gems,
                    rarity,
                    is_upgradeable,
                    max_level,
                    icon_url,
                    granted_skill,
                    is_active,
                    created_at,
                    updated_at
                FROM shop_items
                WHERE item_id = %s
                """,
                (item_id,),
            )
            item = cursor.fetchone()

            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            # Get upgrade costs — alias to_level as level for frontend compatibility
            cursor.execute(
                """
                SELECT
                    from_level,
                    to_level,
                    to_level AS level,
                    cost_coins,
                    cost_gems,
                    stat_bonus_per_level
                FROM upgrade_costs
                WHERE item_id = %s
                ORDER BY from_level
                """,
                (item_id,),
            )
            upgrade_costs = cursor.fetchall()

            return {"item": item, "upgrade_costs": upgrade_costs}
    finally:
        conn.close()


@router.get("/inventory", tags=["inventory"])
def get_player_inventory(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
):
    """Get player's inventory with full item details."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player ID
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]

            # Get inventory items with shop details — alias columns for frontend
            cursor.execute(
                """
                SELECT
                    pi.inventory_id       AS id,
                    pi.inventory_id,
                    pi.item_id            AS shop_item_id,
                    pi.current_level,
                    pi.quantity,
                    pi.is_equipped,
                    pi.equipped_slot,
                    pi.acquired_date      AS acquired_at,
                    pi.last_upgraded      AS last_upgraded_at,
                    si.item_id            AS si_item_id,
                    si.item_name          AS name,
                    si.description,
                    si.item_type,
                    si.rarity,
                    si.base_stat_boost    AS base_stat,
                    si.max_level,
                    si.base_cost_coins,
                    si.base_cost_gems,
                    si.stat_type,
                    si.granted_skill
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.player_id = %s
                ORDER BY si.item_type, si.rarity, si.item_name
                """,
                (player_id,),
            )

            inventory = cursor.fetchall()
            return {"inventory": inventory, "player_id": player_id}
    finally:
        conn.close()


@router.post("/shop/buy", tags=["shop"])
def buy_item(
    request: BuyItemRequest,
    token: Optional[str] = None,
    authorization: Optional[str] = Header(None),
):
    """Purchase an item from the shop using base_cost_coins / base_cost_gems."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute(
                "SELECT id, coins, gems FROM players WHERE username = %s", (username,)
            )
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]
            current_coins = player["coins"]
            current_gems = player["gems"]

            # Get item — use item_id as PK
            cursor.execute(
                """
                SELECT item_id, item_name, base_cost_coins, base_cost_gems, max_level
                FROM shop_items
                WHERE item_id = %s AND is_active = TRUE
                """,
                (request.shop_item_id,),
            )
            item = cursor.fetchone()
            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            # Check if player already owns this item
            cursor.execute(
                "SELECT inventory_id FROM player_inventory WHERE player_id = %s AND item_id = %s",
                (player_id, request.shop_item_id),
            )
            existing = cursor.fetchone()

            if existing:
                raise HTTPException(
                    status_code=400, detail="Anda sudah memiliki item ini"
                )

            # Purchase cost comes from shop_items.base_cost_coins / base_cost_gems
            coins_required = item["base_cost_coins"]
            gems_required = item["base_cost_gems"]

            # Check if player has enough currency
            if current_coins < coins_required:
                raise HTTPException(
                    status_code=400,
                    detail=f"Koin tidak cukup. Butuh {coins_required} koin, kamu punya {current_coins}",
                )
            if gems_required > 0 and current_gems < gems_required:
                raise HTTPException(
                    status_code=400,
                    detail=f"Gems tidak cukup. Butuh {gems_required} gems",
                )

            # Deduct currency
            new_coins = current_coins - coins_required
            new_gems = current_gems - gems_required
            cursor.execute(
                "UPDATE players SET coins = %s, gems = %s WHERE id = %s",
                (new_coins, new_gems, player_id),
            )

            # Add to inventory
            cursor.execute(
                """
                INSERT INTO player_inventory
                    (player_id, item_id, current_level, quantity, is_equipped)
                VALUES (%s, %s, 1, 1, FALSE)
                """,
                (player_id, request.shop_item_id),
            )
            inventory_id = cursor.lastrowid

            # Log currency transaction
            cursor.execute(
                """
                INSERT INTO currency_transactions
                    (player_id, transaction_type, coins_change, gems_change, reason, reference_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    player_id,
                    "shop_purchase",
                    -coins_required,
                    -gems_required if gems_required else 0,
                    f"Membeli item: {item['item_name']}",
                    inventory_id,
                ),
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"Item '{item['item_name']}' berhasil dibeli",
                "inventory_id": inventory_id,
                "new_coins": new_coins,
                "new_gems": new_gems,
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@router.post("/inventory/upgrade", tags=["inventory"])
def upgrade_item(
    request: UpgradeItemRequest,
    token: Optional[str] = None,
    authorization: Optional[str] = Header(None),
):
    """Upgrade an inventory item to the next level."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute(
                "SELECT id, coins, gems FROM players WHERE username = %s", (username,)
            )
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]
            current_coins = player["coins"]
            current_gems = player["gems"]

            # Get inventory item with shop details
            cursor.execute(
                """
                SELECT
                    pi.inventory_id,
                    pi.player_id,
                    pi.item_id,
                    pi.current_level,
                    si.max_level,
                    si.item_name
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.inventory_id = %s
                """,
                (request.inventory_item_id,),
            )

            inv_item = cursor.fetchone()
            if not inv_item:
                raise HTTPException(
                    status_code=404, detail="Item di inventory tidak ditemukan"
                )

            if inv_item["player_id"] != player_id:
                raise HTTPException(status_code=403, detail="Item ini bukan milik Anda")

            current_level = inv_item["current_level"]
            max_level = inv_item["max_level"]

            if current_level >= max_level:
                raise HTTPException(
                    status_code=400, detail="Item sudah mencapai level maksimal"
                )

            # Get upgrade cost for next level (from_level → to_level)
            next_level = current_level + 1
            cursor.execute(
                """
                SELECT cost_coins, cost_gems
                FROM upgrade_costs
                WHERE item_id = %s AND from_level = %s AND to_level = %s
                """,
                (inv_item["item_id"], current_level, next_level),
            )

            cost = cursor.fetchone()
            if not cost:
                raise HTTPException(
                    status_code=400,
                    detail=f"Biaya upgrade level {current_level} → {next_level} tidak ditemukan",
                )

            coins_required = cost["cost_coins"]
            gems_required = cost["cost_gems"]

            # Check resources
            if current_coins < coins_required or current_gems < gems_required:
                raise HTTPException(
                    status_code=400,
                    detail=f"Sumber daya tidak cukup. Butuh: {coins_required} koin, {gems_required} gems",
                )

            # Deduct currency
            new_coins = current_coins - coins_required
            new_gems = current_gems - gems_required

            cursor.execute(
                "UPDATE players SET coins = %s, gems = %s WHERE id = %s",
                (new_coins, new_gems, player_id),
            )

            # Upgrade inventory item — use last_upgraded (schema column name)
            cursor.execute(
                """
                UPDATE player_inventory
                SET current_level = %s, last_upgraded = NOW()
                WHERE inventory_id = %s
                """,
                (next_level, request.inventory_item_id),
            )

            # Audit log: player_upgrades — use schema columns item_id, cost_coins, cost_gems
            cursor.execute(
                """
                INSERT INTO player_upgrades
                    (player_id, item_id, from_level, to_level, cost_coins, cost_gems)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    player_id,
                    inv_item["item_id"],
                    current_level,
                    next_level,
                    coins_required,
                    gems_required,
                ),
            )

            # Log currency transaction — no currency_type column in schema
            cursor.execute(
                """
                INSERT INTO currency_transactions
                    (player_id, transaction_type, coins_change, gems_change, reason, reference_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    player_id,
                    "upgrade",
                    -coins_required,
                    -gems_required,
                    f"Upgrade {inv_item['item_name']} level {current_level} → {next_level}",
                    request.inventory_item_id,
                ),
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"Item berhasil di-upgrade ke level {next_level}",
                "new_level": next_level,
                "new_coins": new_coins,
                "new_gems": new_gems,
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@router.post("/inventory/equip", tags=["inventory"])
def equip_item(
    request: EquipItemRequest,
    token: Optional[str] = None,
    authorization: Optional[str] = Header(None),
):
    """Equip an item in its corresponding slot using player_inventory.is_equipped & equipped_slot."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]

            # Get inventory item with type info
            cursor.execute(
                """
                SELECT pi.inventory_id, pi.player_id, pi.is_equipped,
                       pi.equipped_slot, si.item_type, si.item_name
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.inventory_id = %s
                """,
                (request.inventory_item_id,),
            )

            inv_item = cursor.fetchone()
            if not inv_item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            if inv_item["player_id"] != player_id:
                raise HTTPException(status_code=403, detail="Item bukan milik Anda")

            item_type = inv_item["item_type"]

            # Validate item type is equippable
            if item_type not in ("weapon", "armor", "accessory"):
                raise HTTPException(
                    status_code=400,
                    detail=f"Tipe item '{item_type}' tidak dapat dilengkapi",
                )

            # Unequip any currently equipped item in the same slot for this player
            cursor.execute(
                """
                UPDATE player_inventory
                SET is_equipped = FALSE, equipped_slot = NULL
                WHERE player_id = %s AND equipped_slot = %s
                """,
                (player_id, item_type),
            )

            # Equip the new item
            cursor.execute(
                """
                UPDATE player_inventory
                SET is_equipped = TRUE, equipped_slot = %s
                WHERE inventory_id = %s
                """,
                (item_type, request.inventory_item_id),
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"{inv_item['item_name']} berhasil dipasang di slot {item_type}",
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@router.get("/stats", tags=["profile"])
def get_player_stats(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
):
    """Get player's stats including currency, battle stats and equipped items."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player with battle stats
            cursor.execute(
                """
                SELECT
                    p.id, p.username, p.coins, p.gems,
                    ps.mmr_score, ps.wins, ps.losses, ps.matches_played
                FROM players p
                LEFT JOIN player_stats ps ON p.id = ps.player_id
                WHERE p.username = %s
                """,
                (username,),
            )

            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]

            # Get all currently equipped items via player_inventory.is_equipped
            cursor.execute(
                """
                SELECT
                    pi.inventory_id,
                    pi.current_level,
                    pi.equipped_slot,
                    si.item_id,
                    si.item_name  AS name,
                    si.base_stat_boost AS base_stat,
                    si.stat_type,
                    si.item_type
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.player_id = %s AND pi.is_equipped = TRUE
                """,
                (player_id,),
            )
            equipped_rows = cursor.fetchall()

            equipped = {}
            for row in equipped_rows:
                slot = row.get("equipped_slot") or row.get("item_type")
                if slot:
                    equipped[slot] = row

            return {
                "player_id": player["id"],
                "username": player["username"],
                "coins": player["coins"],
                "gems": player["gems"],
                "mmr": player["mmr_score"] or 1000,
                "wins": player["wins"] or 0,
                "losses": player["losses"] or 0,
                "matches_played": player["matches_played"] or 0,
                "equipped": equipped,
            }
    finally:
        conn.close()
