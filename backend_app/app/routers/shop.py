from typing import Optional
from fastapi import APIRouter, Header, HTTPException
from app.core.database import get_db_connection
from app.core.security import verify_token
from app.models.schemas import (
    BuyItemRequest, UpgradeItemRequest, EquipItemRequest, AllocateAttributeRequest, 
    GachaRequest, UpdateAvatarRequest, ShopItemsListResponse, ShopItemDetailsResponse, 
    PlayerInventoryResponse, PlayerStatsResponse, PlayerAttributesResponse, 
    PlayerMatchHistoryResponse, PlayerProfileResponse
)
router = APIRouter()


@router.get("/shop/items", tags=["shop"], response_model=ShopItemsListResponse)
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


@router.get("/shop/item/{item_id}", tags=["shop"], response_model=ShopItemDetailsResponse)
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


@router.get("/inventory", tags=["inventory"], response_model=PlayerInventoryResponse)
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
                "SELECT id, coins, gems FROM players WHERE username = %s FOR UPDATE",
                (username,),
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
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
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
                "SELECT id, coins, gems FROM players WHERE username = %s FOR UPDATE",
                (username,),
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
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
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
            cursor.execute(
                "SELECT id FROM players WHERE username = %s FOR UPDATE", (username,)
            )
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
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()


@router.get("/stats", tags=["profile"], response_model=PlayerStatsResponse)
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
            cursor.execute(
                """
                SELECT
                    p.id, p.username, p.coins, p.gems, p.active_title, p.is_admin, p.gacha_pity_counter, p.level, p.exp,
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
            
            # Pastikan daily quests diassign
            from app.game.daily_quests_helper import ensure_daily_quests_assigned
            ensure_daily_quests_assigned(player_id)

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

            # Check unclaimed achievements
            cursor.execute(
                "SELECT 1 FROM player_achievements WHERE player_id = %s AND is_completed = TRUE AND is_claimed = FALSE LIMIT 1",
                (player_id,)
            )
            has_unclaimed_ach = bool(cursor.fetchone())
            
            # Check unclaimed daily quests
            cursor.execute(
                "SELECT 1 FROM player_daily_quests WHERE player_id = %s AND is_completed = TRUE AND is_claimed = FALSE LIMIT 1",
                (player_id,)
            )
            has_unclaimed_quest = bool(cursor.fetchone())

            has_unclaimed = has_unclaimed_ach or has_unclaimed_quest

            cursor.execute("SELECT config_value FROM system_config WHERE config_key = 'system_announcement'")
            sys_announcement = cursor.fetchone()
            announcement_text = sys_announcement["config_value"] if sys_announcement else ""

            mmr = player["mmr_score"] or 1000
            tier_name = "Bronze"
            if mmr >= 2500: tier_name = "Mythic"
            elif mmr >= 2000: tier_name = "Diamond"
            elif mmr >= 1500: tier_name = "Gold"
            elif mmr >= 1000: tier_name = "Silver"

            return {
                "player_id": player_id,
                "username": player["username"],
                "coins": player["coins"],
                "gems": player["gems"],
                "active_title": player.get("active_title", ""),
                "mmr": mmr,
                "tier": tier_name,
                "wins": player["wins"] or 0,
                "losses": player["losses"] or 0,
                "matches_played": player["matches_played"] or 0,
                "equipped": equipped,
                "has_unclaimed_rewards": has_unclaimed,
                "is_admin": bool(player.get("is_admin")),
                "gacha_pity_counter": player.get("gacha_pity_counter", 0),
                "level": player.get("level", 1),
                "exp": player.get("exp", 0),
                "announcement": announcement_text,
                "equipped_items": equipped,
            }
    finally:
        conn.close()

@router.get("/attributes", tags=["profile"], response_model=PlayerAttributesResponse)
def get_player_attributes(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
):
    """Get player's allocated attributes and available points."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            # Check if row exists, if not create default
            cursor.execute("SELECT * FROM player_attributes WHERE player_id = %s", (player["id"],))
            attrs = cursor.fetchone()
            
            if not attrs:
                cursor.execute(
                    "INSERT INTO player_attributes (player_id) VALUES (%s)", 
                    (player["id"],)
                )
                conn.commit()
                cursor.execute("SELECT * FROM player_attributes WHERE player_id = %s", (player["id"],))
                attrs = cursor.fetchone()
                
            return {
                "strength": attrs["strength"],
                "agility": attrs["agility"],
                "intelligence": attrs["intelligence"],
                "available_points": attrs["available_points"]
            }
    finally:
        conn.close()

@router.post("/attributes/allocate", tags=["profile"])
def allocate_player_attribute(
    req: AllocateAttributeRequest,
    token: Optional[str] = None, 
    authorization: Optional[str] = Header(None)
):
    """Allocate points to a specific attribute (strength, agility, intelligence)."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    VALID_STATS = {
        "strength": "strength",
        "agility": "agility",
        "intelligence": "intelligence"
    }
    
    col_name = VALID_STATS.get(req.stat_name)
    if not col_name:
        raise HTTPException(status_code=400, detail="Atribut tidak valid")

    if req.points <= 0:
        raise HTTPException(status_code=400, detail="Poin harus lebih dari 0")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            cursor.execute("SELECT * FROM player_attributes WHERE player_id = %s FOR UPDATE", (player["id"],))
            attrs = cursor.fetchone()
            
            # BUG-18 fix: lazy create if not exists
            if not attrs:
                cursor.execute(
                    "INSERT INTO player_attributes (player_id) VALUES (%s)", 
                    (player["id"],)
                )
                cursor.execute("SELECT * FROM player_attributes WHERE player_id = %s FOR UPDATE", (player["id"],))
                attrs = cursor.fetchone()
            
            if attrs["available_points"] < req.points:
                raise HTTPException(status_code=400, detail="Poin tidak cukup")

            # BUG-17 fix: secure column name via mapping, not direct user input
            query = f"UPDATE player_attributes SET {col_name} = {col_name} + %s, available_points = available_points - %s WHERE player_id = %s"
            cursor.execute(query, (req.points, req.points, player["id"]))
            conn.commit()
            
            # Return updated
            cursor.execute("SELECT * FROM player_attributes WHERE player_id = %s", (player["id"],))
            new_attrs = cursor.fetchone()
            
            return {
                "success": True,
                "message": f"Berhasil menambahkan {req.points} poin ke {req.stat_name}",
                "attributes": {
                    "strength": new_attrs["strength"],
                    "agility": new_attrs["agility"],
                    "intelligence": new_attrs["intelligence"],
                    "available_points": new_attrs["available_points"]
                }
            }
    finally:
        conn.close()

@router.get("/history", tags=["profile"], response_model=PlayerMatchHistoryResponse)
def get_match_history(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
):
    """Get player's battle history from battle_logs."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            # Fetch last 20 matches involving this player
            cursor.execute(
                """
                SELECT bl.battle_id, 
                       p1.username as player1, 
                       p2.username as player2, 
                       w.username as winner,
                       bl.total_rounds, 
                       bl.battle_type, 
                       bl.ended_at
                FROM battle_logs bl
                LEFT JOIN players p1 ON bl.player1_id = p1.id
                LEFT JOIN players p2 ON bl.player2_id = p2.id
                LEFT JOIN players w ON bl.winner_id = w.id
                WHERE bl.player1_id = %s OR bl.player2_id = %s
                ORDER BY bl.ended_at DESC
                LIMIT 20
                """,
                (player["id"], player["id"])
            )
            history_rows = cursor.fetchall()
            
            history = []
            for row in history_rows:
                # determine if the logged in player won
                is_winner = (row["winner"] == username)
                
                # determine opponent username
                opponent = row["player2"] if row["player1"] == username else row["player1"]
                
                history.append({
                    "battle_id": row["battle_id"],
                    "opponent": opponent,
                    "is_winner": is_winner,
                    "winner": row["winner"],
                    "total_rounds": row["total_rounds"],
                    "battle_type": row["battle_type"],
                    "ended_at": row["ended_at"].isoformat() if row["ended_at"] else None
                })

            return {"history": history}
    finally:
        conn.close()

@router.get("/profile", tags=["profile"], response_model=PlayerProfileResponse)
def get_player_profile(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
):
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT p.id, p.username, p.coins, p.gems, p.avatar_style, p.is_admin,
                       ps.mmr_score, ps.wins, ps.losses, ps.matches_played 
                FROM players p
                LEFT JOIN player_stats ps ON p.id = ps.player_id
                WHERE p.username = %s FOR UPDATE
            """, (username,))
            player = cursor.fetchone()
            
            # get equipped
            cursor.execute('''
                SELECT pi.inventory_id, si.item_name, si.base_stat_boost, si.stat_type, pi.current_level
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.player_id = %s AND pi.is_equipped = TRUE
            ''', (player["id"],))
            equipped = cursor.fetchall()

            # get guild info
            cursor.execute('''
                SELECT g.name as guild_name, g.level as guild_level, gm.role as guild_role
                FROM guild_members gm
                JOIN guilds g ON gm.guild_id = g.id
                WHERE gm.player_id = %s
            ''', (player["id"],))
            guild_info = cursor.fetchone()

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
                "guild_name": guild_info["guild_name"] if guild_info else None,
                "guild_level": guild_info["guild_level"] if guild_info else 0,
                "guild_role": guild_info["guild_role"] if guild_info else None,
                "avatar_style": player["avatar_style"],
                "is_admin": bool(player.get("is_admin")),
            }
    finally:
        conn.close()

@router.post("/profile/avatar", tags=["profile"])
def update_avatar(req: UpdateAvatarRequest, authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE players SET avatar_style = %s WHERE username = %s", (req.avatar_style, username))
            conn.commit()
            return {"success": True, "message": "Avatar berhasil diperbarui"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()

@router.post("/shop/gacha", tags=["shop"])
def open_gacha(req: GachaRequest, authorization: str = Header(None)):
    import random
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    return_data = None
    player_id = None
    is_upgrade = False
    
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, coins, gems, gacha_pity_counter FROM players WHERE username = %s FOR UPDATE", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]
            coins = player["coins"]
            gems = player["gems"]
            pity_counter = player.get("gacha_pity_counter", 0)

            cost_coins = 0
            cost_gems = 0
            probabilities = {}

            if req.chest_type == "bronze":
                cost_coins = 50
                probabilities = {"common": 0.7, "uncommon": 0.25, "rare": 0.05}
            elif req.chest_type == "silver":
                cost_coins = 150
                probabilities = {"uncommon": 0.5, "rare": 0.4, "epic": 0.1}
            elif req.chest_type == "gold":
                cost_gems = 20
                probabilities = {"rare": 0.5, "epic": 0.35, "legendary": 0.15}
            else:
                raise HTTPException(status_code=400, detail="Tipe peti tidak valid")

            if coins < cost_coins or gems < cost_gems:
                raise HTTPException(status_code=400, detail="Saldo tidak cukup")

            # Pity logic: Every 10th pull guarantees the max rarity of the chest
            max_rarity = list(probabilities.keys())[-1]
            chosen_rarity = None
            
            pity_counter += 1
            if pity_counter >= 10:
                chosen_rarity = max_rarity
                pity_counter = 0
            else:
                rand = random.random()
                cumulative = 0.0
                for rarity, prob in probabilities.items():
                    cumulative += prob
                    if rand <= cumulative:
                        chosen_rarity = rarity
                        break
                if not chosen_rarity:
                    chosen_rarity = max_rarity
                
                # Reset pity if they luckily hit max rarity early
                if chosen_rarity == max_rarity:
                    pity_counter = 0

            # Get random item of chosen rarity
            cursor.execute(
                "SELECT item_id, item_name, rarity, base_cost_coins, max_level, stat_type, base_stat_boost as base_stat FROM shop_items WHERE rarity = %s", 
                (chosen_rarity,)
            )
            items = cursor.fetchall()
            if not items:
                raise HTTPException(status_code=500, detail=f"Tidak ada item dengan rarity {chosen_rarity}")

            won_item = random.choice(items)
            item_id = won_item["item_id"]
            
            new_coins = coins - cost_coins
            new_gems = gems - cost_gems

            cursor.execute(
                "SELECT inventory_id, current_level FROM player_inventory WHERE player_id = %s AND item_id = %s",
                (player_id, item_id)
            )
            existing = cursor.fetchone()

            is_new = False
            is_refund = False
            refund_amount = 0

            if existing:
                current_level = existing["current_level"]
                max_level = won_item["max_level"]
                if current_level < max_level:
                    cursor.execute(
                        "UPDATE player_inventory SET current_level = current_level + 1 WHERE inventory_id = %s",
                        (existing["inventory_id"],)
                    )
                    is_upgrade = True
                else:
                    refund_amount = won_item["base_cost_coins"] // 2
                    new_coins += refund_amount
                    is_refund = True
            else:
                cursor.execute(
                    "INSERT INTO player_inventory (player_id, item_id, current_level, is_equipped) VALUES (%s, %s, 1, FALSE)",
                    (player_id, item_id)
                )
                is_new = True
            
            # Use won_item for response but we rename 'base_stat' to 'base_stat_boost' for frontend consistency
            won_item_dict = dict(won_item)
            won_item_dict['base_stat_boost'] = won_item_dict['base_stat']

            cursor.execute(
                "UPDATE players SET coins = %s, gems = %s, gacha_pity_counter = %s WHERE id = %s", 
                (new_coins, new_gems, pity_counter, player_id)
            )

            conn.commit()

            message = f"Berhasil mendapatkan {won_item['item_name']}!"
            if is_upgrade:
                message += " (Duplicate: Item Otomatis di-Upgrade!)"
            elif is_refund:
                message += f" (Maks Level: Refund {refund_amount} Koin)"

            return_data = {
                "success": True,
                "message": message,
                "item": won_item_dict,
                "status": "new" if is_new else "upgrade" if is_upgrade else "refund",
                "refund_amount": refund_amount,
                "pity_counter": pity_counter
            }
            
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()

    # Trigger achievements outside the try-finally to avoid connection conflicts
    try:
        if player_id:
            from app.game.achievements_helper import update_achievement_progress
            from app.game.daily_quests_helper import update_daily_quest_progress
            update_achievement_progress(player_id, 'gacha_opened', 1)
            update_daily_quest_progress(player_id, 'gacha_opened', 1)
            if is_upgrade:
                update_achievement_progress(player_id, 'item_upgrades', 1)
                update_daily_quest_progress(player_id, 'item_upgrades', 1)
    except Exception as e:
        print(f"Warning: Failed to update gacha achievement: {e}")

    return return_data


@router.post("/shop/gacha/multi", tags=["shop"])
def open_gacha_multi(req: GachaRequest, authorization: str = Header(None)):
    import random
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    return_data = None
    player_id = None
    upgrade_count = 0
    
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, coins, gems, gacha_pity_counter FROM players WHERE username = %s FOR UPDATE", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]
            coins = player["coins"]
            gems = player["gems"]
            pity_counter = player.get("gacha_pity_counter", 0)

            cost_coins = 0
            cost_gems = 0
            probabilities = {}

            if req.chest_type == "bronze":
                cost_coins = 50 * 10
                probabilities = {"common": 0.7, "uncommon": 0.25, "rare": 0.05}
            elif req.chest_type == "silver":
                cost_coins = 150 * 10
                probabilities = {"uncommon": 0.5, "rare": 0.4, "epic": 0.1}
            elif req.chest_type == "gold":
                cost_gems = 20 * 10
                probabilities = {"rare": 0.5, "epic": 0.35, "legendary": 0.15}
            else:
                raise HTTPException(status_code=400, detail="Tipe peti tidak valid")

            if coins < cost_coins or gems < cost_gems:
                raise HTTPException(status_code=400, detail="Saldo tidak cukup untuk 10x tarikan")

            max_rarity = list(probabilities.keys())[-1]
            
            # Fetch items first for all possible rarities
            rarities_needed = list(probabilities.keys())
            cursor.execute(
                f"SELECT item_id, item_name, rarity, base_cost_coins, max_level, stat_type, base_stat_boost as base_stat, item_type FROM shop_items WHERE rarity IN %s", 
                (tuple(rarities_needed),)
            )
            all_items = cursor.fetchall()
            items_by_rarity = {r: [i for i in all_items if i['rarity'] == r] for r in rarities_needed}

            new_coins = coins - cost_coins
            new_gems = gems - cost_gems
            
            results = []

            for i in range(10):
                pity_counter += 1
                chosen_rarity = None
                
                if pity_counter >= 10:
                    chosen_rarity = max_rarity
                    pity_counter = 0
                else:
                    rand = random.random()
                    cumulative = 0.0
                    for rarity, prob in probabilities.items():
                        cumulative += prob
                        if rand <= cumulative:
                            chosen_rarity = rarity
                            break
                    if not chosen_rarity:
                        chosen_rarity = max_rarity
                    if chosen_rarity == max_rarity:
                        pity_counter = 0

                items = items_by_rarity.get(chosen_rarity, [])
                if not items:
                    continue # Safety
                
                won_item = random.choice(items)
                item_id = won_item["item_id"]
                
                cursor.execute(
                    "SELECT inventory_id, current_level FROM player_inventory WHERE player_id = %s AND item_id = %s",
                    (player_id, item_id)
                )
                existing = cursor.fetchone()

                is_new = False
                is_upgrade = False
                is_refund = False
                refund_amount = 0

                if existing:
                    current_level = existing["current_level"]
                    max_level = won_item["max_level"]
                    if current_level < max_level:
                        cursor.execute(
                            "UPDATE player_inventory SET current_level = current_level + 1 WHERE inventory_id = %s",
                            (existing["inventory_id"],)
                        )
                        is_upgrade = True
                        upgrade_count += 1
                    else:
                        refund_amount = won_item["base_cost_coins"] // 2
                        new_coins += refund_amount
                        is_refund = True
                else:
                    cursor.execute(
                        "INSERT INTO player_inventory (player_id, item_id, current_level, is_equipped) VALUES (%s, %s, 1, FALSE)",
                        (player_id, item_id)
                    )
                    is_new = True

                won_item_dict = dict(won_item)
                won_item_dict['base_stat_boost'] = won_item_dict['base_stat']

                results.append({
                    "item": won_item_dict,
                    "status": "new" if is_new else "upgrade" if is_upgrade else "refund",
                    "refund_amount": refund_amount
                })

            cursor.execute(
                "UPDATE players SET coins = %s, gems = %s, gacha_pity_counter = %s WHERE id = %s", 
                (new_coins, new_gems, pity_counter, player_id)
            )
            conn.commit()

            return_data = {
                "success": True,
                "message": "Berhasil membuka 10 peti!",
                "results": results,
                "pity_counter": pity_counter
            }
            
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()

    try:
        if player_id:
            from app.game.achievements_helper import update_achievement_progress
            from app.game.daily_quests_helper import update_daily_quest_progress
            update_achievement_progress(player_id, 'gacha_opened', 10)
            update_daily_quest_progress(player_id, 'gacha_opened', 10)
            if upgrade_count > 0:
                update_achievement_progress(player_id, 'item_upgrades', upgrade_count)
                update_daily_quest_progress(player_id, 'item_upgrades', upgrade_count)
    except Exception as e:
        print(f"Warning: Failed to update gacha multi achievement: {e}")

    return return_data

@router.post("/inventory/sell/{inventory_id}", tags=["inventory"])
def sell_inventory_item(
    inventory_id: int, 
    token: Optional[str] = None, 
    authorization: Optional[str] = Header(None)
):
    """Jual item dari inventory untuk mendapatkan Koin (50 Koin per item)."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Pastikan item milik player
            cursor.execute(
                """
                SELECT pi.inventory_id, pi.is_equipped, p.id as player_id
                FROM player_inventory pi
                JOIN players p ON pi.player_id = p.id
                WHERE p.username = %s AND pi.inventory_id = %s
                FOR UPDATE
                """,
                (username, inventory_id)
            )
            item = cursor.fetchone()
            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan di inventory Anda")
            
            if item["is_equipped"]:
                raise HTTPException(status_code=400, detail="Tidak bisa menjual item yang sedang dipakai (equipped)")
            
            # Hapus item dari inventory
            cursor.execute("DELETE FROM player_inventory WHERE inventory_id = %s", (inventory_id,))
            
            # Berikan 50 koin ke player
            coins_reward = 50
            cursor.execute("UPDATE players SET coins = coins + %s WHERE id = %s", (coins_reward, item["player_id"]))
            
            conn.commit()
            return {"success": True, "message": f"Berhasil menjual item seharga {coins_reward} Koin!"}
    finally:
        conn.close()
