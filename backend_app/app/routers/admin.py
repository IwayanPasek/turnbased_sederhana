from fastapi import APIRouter, HTTPException, Header
from typing import Optional
from app.core.database import get_db_connection
from app.core.security import verify_token, pwd_context
from app.models.schemas import (
    GiveCurrencyRequest, AdminUsersListResponse, AdminActionResponse,
    AdminResetPasswordRequest, AdminStatsResponse, PlayerInventoryResponse
)

router = APIRouter()

def verify_admin(authorization: str):
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")
        
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT is_admin FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player or not player.get("is_admin"):
                raise HTTPException(status_code=403, detail="Akses ditolak. Anda bukan Admin.")
            return username
    finally:
        conn.close()


@router.get("/admin/users", tags=["admin"], response_model=AdminUsersListResponse)
def get_all_users(search: Optional[str] = None, authorization: str = Header(None)):
    verify_admin(authorization)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            query = """
                SELECT p.id, p.username, p.coins, p.gems, p.is_banned, p.is_admin,
                       ps.mmr_score, ps.matches_played
                FROM players p
                LEFT JOIN player_stats ps ON p.id = ps.player_id
            """
            params = []
            if search:
                query += " WHERE p.username LIKE %s"
                params.append(f"%{search}%")
            query += " ORDER BY p.id DESC"
            
            cursor.execute(query, tuple(params))
            users = cursor.fetchall()
            
            # ensure boolean formats
            for u in users:
                u['is_banned'] = bool(u['is_banned'])
                u['is_admin'] = bool(u['is_admin'])
                
            return {"users": users}
    finally:
        conn.close()


@router.post("/admin/users/{user_id}/give", tags=["admin"], response_model=AdminActionResponse)
def give_currency(user_id: int, req: GiveCurrencyRequest, authorization: str = Header(None)):
    verify_admin(authorization)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE players SET coins = coins + %s, gems = gems + %s WHERE id = %s", 
                           (req.coins, req.gems, user_id))
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="User tidak ditemukan")
            conn.commit()
            return {"success": True, "message": f"Berhasil menambahkan {req.coins} Koin dan {req.gems} Gems"}
    finally:
        conn.close()


@router.post("/admin/users/{user_id}/ban", tags=["admin"], response_model=AdminActionResponse)
def toggle_ban(user_id: int, authorization: str = Header(None)):
    my_username = verify_admin(authorization)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Cegah admin mem-ban dirinya sendiri
            cursor.execute("SELECT username, is_banned, is_admin FROM players WHERE id = %s", (user_id,))
            target = cursor.fetchone()
            if not target:
                raise HTTPException(status_code=404, detail="User tidak ditemukan")
                
            if target['username'] == my_username:
                raise HTTPException(status_code=400, detail="Anda tidak bisa memblokir diri sendiri")
                
            if target['is_admin']:
                raise HTTPException(status_code=403, detail="Tidak bisa memblokir sesama Admin")
                
            new_ban_status = not bool(target['is_banned'])
            cursor.execute("UPDATE players SET is_banned = %s WHERE id = %s", (new_ban_status, user_id))
            conn.commit()
            
            action = "diblokir" if new_ban_status else "dibuka blokirnya"
            return {"success": True, "message": f"User {target['username']} berhasil {action}"}
    finally:
        conn.close()


@router.post("/admin/users/{user_id}/toggle_admin", tags=["admin"], response_model=AdminActionResponse)
def toggle_admin(user_id: int, authorization: str = Header(None)):
    my_username = verify_admin(authorization)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Cegah admin mengubah status dirinya sendiri
            cursor.execute("SELECT username, is_admin FROM players WHERE id = %s", (user_id,))
            target = cursor.fetchone()
            if not target:
                raise HTTPException(status_code=404, detail="User tidak ditemukan")
                
            if target['username'] == my_username:
                raise HTTPException(status_code=400, detail="Anda tidak bisa mengubah status admin diri sendiri")
                
            new_admin_status = not bool(target['is_admin'])
            cursor.execute("UPDATE players SET is_admin = %s WHERE id = %s", (new_admin_status, user_id))
            conn.commit()
            
            action = "dipromosikan menjadi Admin" if new_admin_status else "diturunkan menjadi Pemain Biasa"
            return {"success": True, "message": f"User {target['username']} berhasil {action}"}
    finally:
        conn.close()


@router.post("/admin/users/{user_id}/reset_stats", tags=["admin"], response_model=AdminActionResponse)
def reset_stats(user_id: int, authorization: str = Header(None)):
    verify_admin(authorization)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE player_stats SET mmr_score = 1000, wins = 0, losses = 0, matches_played = 0 WHERE player_id = %s", (user_id,))
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="User stats tidak ditemukan")
            conn.commit()
            return {"success": True, "message": "Statistik pemain berhasil direset ke nilai awal (MMR 1000)"}
    finally:
        conn.close()


@router.post("/admin/users/{user_id}/reset_password", tags=["admin"], response_model=AdminActionResponse)
def reset_password(user_id: int, req: AdminResetPasswordRequest, authorization: str = Header(None)):
    verify_admin(authorization)
    
    hashed = pwd_context.hash(req.new_password)
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE players SET password_hash = %s WHERE id = %s", (hashed, user_id))
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="User tidak ditemukan")
            conn.commit()
            return {"success": True, "message": "Kata sandi pemain berhasil direset"}
    finally:
        conn.close()


@router.get("/admin/stats", tags=["admin"], response_model=AdminStatsResponse)
def get_admin_stats(authorization: str = Header(None)):
    verify_admin(authorization)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_players,
                    SUM(CASE WHEN is_banned = TRUE THEN 1 ELSE 0 END) as total_banned,
                    SUM(CASE WHEN is_admin = TRUE THEN 1 ELSE 0 END) as total_admins,
                    COALESCE(SUM(coins), 0) as total_coins,
                    COALESCE(SUM(gems), 0) as total_gems
                FROM players
            """)
            stats = cursor.fetchone()
            return stats
    finally:
        conn.close()


@router.get("/admin/users/{user_id}/inventory", tags=["admin"], response_model=PlayerInventoryResponse)
def get_user_inventory(user_id: int, authorization: str = Header(None)):
    verify_admin(authorization)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Check if player exists
            cursor.execute("SELECT id FROM players WHERE id = %s", (user_id,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")
                
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
                (user_id,),
            )
            inventory = cursor.fetchall()
            return {"inventory": inventory, "player_id": user_id}
    finally:
        conn.close()



from app.models.schemas import GiveItemRequest, BroadcastRequest

@router.post("/admin/users/{user_id}/give-item", tags=["admin"], response_model=AdminActionResponse)
def give_item(user_id: int, req: GiveItemRequest, authorization: str = Header(None)):
    verify_admin(authorization)
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Check player
            cursor.execute("SELECT id, username FROM players WHERE id = %s", (user_id,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")
            
            # Check item
            cursor.execute("SELECT item_name FROM shop_items WHERE item_id = %s", (req.item_id,))
            item = cursor.fetchone()
            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan di shop_items")

            # Insert or update
            cursor.execute(
                """
                INSERT INTO player_inventory (player_id, item_id, current_level, quantity)
                VALUES (%s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE 
                    quantity = quantity + %s,
                    current_level = GREATEST(current_level, %s)
                """,
                (user_id, req.item_id, req.level, req.amount, req.amount, req.level)
            )
        conn.commit()
        return {"success": True, "message": f"Berhasil memberikan {req.amount}x {item['item_name']} (Lv {req.level}) ke {player['username']}"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@router.post("/admin/broadcast", tags=["admin"], response_model=AdminActionResponse)
def broadcast_message(req: BroadcastRequest, authorization: str = Header(None)):
    verify_admin(authorization)
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO system_config (config_key, config_value) 
                VALUES ('system_announcement', %s) 
                ON DUPLICATE KEY UPDATE config_value = %s
                """,
                (req.message, req.message)
            )
        conn.commit()
        return {"success": True, "message": "Pengumuman berhasil disebarkan ke seluruh sistem."}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
