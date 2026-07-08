from fastapi import APIRouter, HTTPException, Header
from typing import Optional
from app.core.database import get_db_connection
from app.core.security import verify_token
from app.models.schemas import LeaderboardResponse

router = APIRouter()

@router.get("/leaderboard", tags=["leaderboard"], response_model=LeaderboardResponse)
def get_global_leaderboard(
    limit: int = 100, 
    authorization: Optional[str] = Header(None)
):
    """Mendapatkan daftar pemain terbaik secara global."""
    
    # Optional authorization, kita bisa membiarkannya terbuka untuk publik 
    # atau wajib login. Untuk sekarang, wajib login.
    if authorization:
        username = verify_token(None, authorization)
        if not username:
            raise HTTPException(status_code=401, detail="Token tidak valid")
    else:
        raise HTTPException(status_code=401, detail="Token diperlukan")

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Menggunakan index idx_players_mmr yang dibuat sebelumnya
            query = """
                SELECT 
                    p.id, 
                    p.username, 
                    ps.mmr_score, 
                    ps.wins, 
                    ps.losses, 
                    ps.matches_played 
                FROM players p
                LEFT JOIN player_stats ps ON p.id = ps.player_id
                ORDER BY ps.mmr_score DESC 
                LIMIT %s
            """
            cursor.execute(query, (limit,))
            players = cursor.fetchall()
            
            # Formatting data
            leaderboard_data = []
            for i, p in enumerate(players):
                mmr = p["mmr_score"] or 1000
                tier_name = "Bronze"
                if mmr >= 2500: tier_name = "Mythic"
                elif mmr >= 2000: tier_name = "Diamond"
                elif mmr >= 1500: tier_name = "Gold"
                elif mmr >= 1000: tier_name = "Silver"
                
                leaderboard_data.append({
                    "rank": i + 1,
                    "player_id": p["id"],
                    "username": p["username"],
                    "mmr_score": mmr,
                    "tier": tier_name,
                    "wins": p["wins"] or 0,
                    "losses": p["losses"] or 0,
                    "matches_played": p["matches_played"] or 0,
                })
                
            return {
                "success": True,
                "leaderboard": leaderboard_data
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail="Terjadi kesalahan internal pada server")
    finally:
        conn.close()
