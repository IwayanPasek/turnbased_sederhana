from fastapi import APIRouter, HTTPException, Header
from typing import Optional
from app.core.database import get_db_connection
from app.core.security import verify_token
from pydantic import BaseModel
from app.models.schemas import (
    CreateGuildRequest, GuildChatRequest, GuildMemberActionRequest,
    GuildsListResponse, MyGuildInfoResponse, GenericGuildActionResponse
)

router = APIRouter()

@router.post("/guilds", tags=["guild"], response_model=GenericGuildActionResponse)
def create_guild(req: CreateGuildRequest, authorization: str = Header(None)):
    """Membuat guild baru (Biaya: 1000 Koin)."""
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Dapatkan player id dan coins
            cursor.execute("SELECT id, coins FROM players WHERE username = %s FOR UPDATE", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]
            if player["coins"] < 1000:
                raise HTTPException(status_code=400, detail="Koin tidak cukup. Butuh 1000 koin untuk membuat Guild.")

            # Cek apakah sudah di dalam guild
            cursor.execute("SELECT guild_id FROM guild_members WHERE player_id = %s", (player_id,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Anda sudah bergabung dengan sebuah guild")

            # Cek nama guild duplikat
            cursor.execute("SELECT id FROM guilds WHERE name = %s", (req.name,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Nama guild sudah dipakai")

            # Potong koin
            cursor.execute("UPDATE players SET coins = coins - 1000 WHERE id = %s", (player_id,))

            # Insert guild
            cursor.execute(
                "INSERT INTO guilds (name, description, leader_id) VALUES (%s, %s, %s)",
                (req.name, req.description, player_id)
            )
            guild_id = cursor.lastrowid

            # Insert leader ke guild_members
            cursor.execute(
                "INSERT INTO guild_members (guild_id, player_id, role) VALUES (%s, %s, 'leader')",
                (guild_id, player_id)
            )

            conn.commit()
            return {"success": True, "message": "Guild berhasil dibuat!", "guild_id": guild_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()

@router.get("/guilds", tags=["guild"], response_model=GuildsListResponse)
def get_guilds(authorization: str = Header(None)):
    """Mendapatkan daftar semua guild."""
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT g.id, g.name, g.description, g.level, 
                       (SELECT COUNT(*) FROM guild_members WHERE guild_id = g.id) as member_count
                FROM guilds g
                ORDER BY g.level DESC, member_count DESC
            """)
            guilds = cursor.fetchall()
            return {"success": True, "guilds": guilds}
    finally:
        conn.close()

@router.get("/guilds/my_guild", tags=["guild"], response_model=MyGuildInfoResponse)
def get_my_guild(authorization: str = Header(None)):
    """Mendapatkan detail guild tempat pemain bernaung (termasuk member dan chat)."""
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")
            player_id = player["id"]

            cursor.execute("SELECT guild_id, role FROM guild_members WHERE player_id = %s", (player_id,))
            membership = cursor.fetchone()
            
            if not membership:
                return {"success": True, "has_guild": False}

            guild_id = membership["guild_id"]

            # Detail Guild
            cursor.execute("SELECT * FROM guilds WHERE id = %s", (guild_id,))
            guild = cursor.fetchone()

            # Members
            cursor.execute("""
                SELECT p.username, gm.role, gm.joined_at, p.mmr_score 
                FROM guild_members gm
                JOIN players p ON gm.player_id = p.id
                WHERE gm.guild_id = %s
                ORDER BY 
                  CASE WHEN gm.role = 'leader' THEN 1 WHEN gm.role = 'elder' THEN 2 ELSE 3 END, 
                  p.mmr_score DESC
            """, (guild_id,))
            members = cursor.fetchall()

            # Chat (last 50 messages)
            cursor.execute("""
                SELECT gc.message, gc.sent_at, p.username 
                FROM guild_chat gc
                JOIN players p ON gc.player_id = p.id
                WHERE gc.guild_id = %s
                ORDER BY gc.sent_at DESC
                LIMIT 50
            """, (guild_id,))
            chats = cursor.fetchall()

            return {
                "success": True, 
                "has_guild": True,
                "guild": guild,
                "my_role": membership["role"],
                "members": members,
                "chats": chats
            }
    finally:
        conn.close()

@router.post("/guilds/{guild_id}/join", tags=["guild"], response_model=GenericGuildActionResponse)
def join_guild(guild_id: int, authorization: str = Header(None)):
    """Bergabung ke sebuah guild."""
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player_id = cursor.fetchone()["id"]

            cursor.execute("SELECT guild_id FROM guild_members WHERE player_id = %s", (player_id,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Anda sudah bergabung dengan sebuah guild")

            cursor.execute("SELECT id FROM guilds WHERE id = %s", (guild_id,))
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="Guild tidak ditemukan")

            cursor.execute(
                "INSERT INTO guild_members (guild_id, player_id, role) VALUES (%s, %s, 'member')",
                (guild_id, player_id)
            )
            conn.commit()
            return {"success": True, "message": "Berhasil bergabung ke Guild!"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()

@router.post("/guilds/leave", tags=["guild"], response_model=GenericGuildActionResponse)
def leave_guild(authorization: str = Header(None)):
    """Keluar dari guild."""
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player_id = cursor.fetchone()["id"]

            cursor.execute("SELECT guild_id, role FROM guild_members WHERE player_id = %s", (player_id,))
            membership = cursor.fetchone()
            if not membership:
                raise HTTPException(status_code=400, detail="Anda tidak berada dalam guild")

            guild_id = membership["guild_id"]
            role = membership["role"]

            if role == 'leader':
                raise HTTPException(status_code=400, detail="Leader tidak bisa keluar. Harap bubarkan guild atau transfer kepemimpinan (Coming Soon).")

            cursor.execute("DELETE FROM guild_members WHERE player_id = %s", (player_id,))
            conn.commit()
            return {"success": True, "message": "Berhasil keluar dari Guild"}
    finally:
        conn.close()

@router.post("/guilds/chat", tags=["guild"], response_model=GenericGuildActionResponse)
def send_chat(req: GuildChatRequest, authorization: str = Header(None)):
    """Mengirim pesan chat ke guild."""
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player_id = cursor.fetchone()["id"]

            cursor.execute("SELECT guild_id FROM guild_members WHERE player_id = %s", (player_id,))
            membership = cursor.fetchone()
            if not membership:
                raise HTTPException(status_code=400, detail="Anda tidak berada dalam guild")

            guild_id = membership["guild_id"]

            cursor.execute(
                "INSERT INTO guild_chat (guild_id, player_id, message) VALUES (%s, %s, %s)",
                (guild_id, player_id, req.message)
            )
            conn.commit()
            return {"success": True, "message": "Pesan terkirim"}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()

def _get_membership_info(cursor, username: str):
    cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
    player = cursor.fetchone()
    if not player:
        raise HTTPException(status_code=404, detail="Player tidak ditemukan")
    
    cursor.execute("SELECT guild_id, role FROM guild_members WHERE player_id = %s", (player["id"],))
    membership = cursor.fetchone()
    if not membership:
        raise HTTPException(status_code=400, detail="Anda tidak berada dalam guild")
    
    return player["id"], membership["guild_id"], membership["role"]

def _get_target_membership(cursor, target_username: str, guild_id: int):
    cursor.execute("SELECT id FROM players WHERE username = %s", (target_username,))
    target = cursor.fetchone()
    if not target:
        raise HTTPException(status_code=404, detail="Target tidak ditemukan")
        
    cursor.execute("SELECT role FROM guild_members WHERE player_id = %s AND guild_id = %s", (target["id"], guild_id))
    target_membership = cursor.fetchone()
    if not target_membership:
        raise HTTPException(status_code=400, detail="Target tidak berada di guild ini")
        
    return target["id"], target_membership["role"]

@router.post("/guilds/kick", tags=["guild"], response_model=GenericGuildActionResponse)
def kick_member(req: GuildMemberActionRequest, authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username: raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            my_id, my_guild_id, my_role = _get_membership_info(cursor, username)
            if my_role not in ["leader", "elder"]:
                raise HTTPException(status_code=403, detail="Hanya Leader dan Elder yang bisa kick")
                
            target_id, target_role = _get_target_membership(cursor, req.target_username, my_guild_id)
            
            if my_id == target_id:
                raise HTTPException(status_code=400, detail="Tidak bisa kick diri sendiri")
                
            if target_role == "leader":
                raise HTTPException(status_code=403, detail="Tidak bisa kick Leader")
                
            if my_role == "elder" and target_role == "elder":
                raise HTTPException(status_code=403, detail="Elder tidak bisa kick sesama Elder")
                
            cursor.execute("DELETE FROM guild_members WHERE player_id = %s AND guild_id = %s", (target_id, my_guild_id))
            conn.commit()
            return {"success": True, "message": f"{req.target_username} dikeluarkan dari Guild"}
    finally:
        conn.close()

@router.post("/guilds/promote", tags=["guild"], response_model=GenericGuildActionResponse)
def promote_member(req: GuildMemberActionRequest, authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username: raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            my_id, my_guild_id, my_role = _get_membership_info(cursor, username)
            if my_role != "leader":
                raise HTTPException(status_code=403, detail="Hanya Leader yang bisa promote")
                
            target_id, target_role = _get_target_membership(cursor, req.target_username, my_guild_id)
            
            if target_role != "member":
                raise HTTPException(status_code=400, detail="Hanya Member yang bisa dipromosikan ke Elder")
                
            cursor.execute("UPDATE guild_members SET role = 'elder' WHERE player_id = %s AND guild_id = %s", (target_id, my_guild_id))
            conn.commit()
            return {"success": True, "message": f"{req.target_username} dipromosikan menjadi Elder"}
    finally:
        conn.close()

@router.post("/guilds/demote", tags=["guild"], response_model=GenericGuildActionResponse)
def demote_member(req: GuildMemberActionRequest, authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username: raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            my_id, my_guild_id, my_role = _get_membership_info(cursor, username)
            if my_role != "leader":
                raise HTTPException(status_code=403, detail="Hanya Leader yang bisa demote")
                
            target_id, target_role = _get_target_membership(cursor, req.target_username, my_guild_id)
            
            if target_role != "elder":
                raise HTTPException(status_code=400, detail="Hanya Elder yang bisa diturunkan jabatannya")
                
            cursor.execute("UPDATE guild_members SET role = 'member' WHERE player_id = %s AND guild_id = %s", (target_id, my_guild_id))
            conn.commit()
            return {"success": True, "message": f"{req.target_username} diturunkan menjadi Member"}
    finally:
        conn.close()

@router.post("/guilds/transfer", tags=["guild"], response_model=GenericGuildActionResponse)
def transfer_leadership(req: GuildMemberActionRequest, authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username: raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            my_id, my_guild_id, my_role = _get_membership_info(cursor, username)
            if my_role != "leader":
                raise HTTPException(status_code=403, detail="Hanya Leader yang bisa mentransfer kepemimpinan")
                
            target_id, target_role = _get_target_membership(cursor, req.target_username, my_guild_id)
            
            if my_id == target_id:
                raise HTTPException(status_code=400, detail="Anda sudah menjadi leader")
                
            # Update target to leader
            cursor.execute("UPDATE guild_members SET role = 'leader' WHERE player_id = %s AND guild_id = %s", (target_id, my_guild_id))
            # Update self to elder
            cursor.execute("UPDATE guild_members SET role = 'elder' WHERE player_id = %s AND guild_id = %s", (my_id, my_guild_id))
            # Update guilds table leader_id
            cursor.execute("UPDATE guilds SET leader_id = %s WHERE id = %s", (target_id, my_guild_id))
            conn.commit()
            return {"success": True, "message": f"Kepemimpinan ditransfer ke {req.target_username}"}
    finally:
        conn.close()

@router.post("/guilds/disband", tags=["guild"], response_model=GenericGuildActionResponse)
def disband_guild(authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username: raise HTTPException(status_code=401, detail="Token tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            my_id, my_guild_id, my_role = _get_membership_info(cursor, username)
            if my_role != "leader":
                raise HTTPException(status_code=403, detail="Hanya Leader yang bisa membubarkan guild")
                
            cursor.execute("DELETE FROM guilds WHERE id = %s", (my_guild_id,))
            conn.commit()
            return {"success": True, "message": "Guild berhasil dibubarkan"}
    finally:
        conn.close()

class GuildDonateRequest(BaseModel):
    coins: int = 0
    gems: int = 0

@router.post("/guilds/donate", tags=["guild"], response_model=GenericGuildActionResponse)
def donate_guild(req: GuildDonateRequest, authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username: raise HTTPException(status_code=401, detail="Token tidak valid")

    if req.coins <= 0 and req.gems <= 0:
        raise HTTPException(status_code=400, detail="Jumlah donasi tidak valid")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            my_id, my_guild_id, my_role = _get_membership_info(cursor, username)
            
            cursor.execute("SELECT coins, gems FROM players WHERE id = %s FOR UPDATE", (my_id,))
            player = cursor.fetchone()
            if player['coins'] < req.coins or player['gems'] < req.gems:
                raise HTTPException(status_code=400, detail="Saldo tidak cukup")
                
            cursor.execute("UPDATE players SET coins = coins - %s, gems = gems - %s WHERE id = %s",
                           (req.coins, req.gems, my_id))
                           
            added_exp = (req.coins // 10) + (req.gems * 20)
            
            cursor.execute("SELECT level, exp FROM guilds WHERE id = %s FOR UPDATE", (my_guild_id,))
            guild = cursor.fetchone()
            new_exp = guild['exp'] + added_exp
            new_level = guild['level']
            
            level_up_threshold = new_level * 1000
            while new_exp >= level_up_threshold:
                new_exp -= level_up_threshold
                new_level += 1
                level_up_threshold = new_level * 1000
                
            cursor.execute("UPDATE guilds SET level = %s, exp = %s WHERE id = %s",
                           (new_level, new_exp, my_guild_id))
            
            conn.commit()
            return {
                "success": True, 
                "message": f"Berhasil donasi! Guild mendapat {added_exp} EXP.",
                "new_level": new_level,
                "new_exp": new_exp
            }
    finally:
        conn.close()
