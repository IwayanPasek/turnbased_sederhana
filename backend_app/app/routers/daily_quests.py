from fastapi import APIRouter, HTTPException, Header
from app.core.database import get_db_connection
from app.core.security import verify_token
from app.models.schemas import DailyQuestsListResponse, DailyQuestClaimResponse
import random
from datetime import date

router = APIRouter()

@router.get("/daily_quests", tags=["daily_quests"], response_model=DailyQuestsListResponse)
def get_daily_quests(authorization: str = Header(None)):
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
                
            player_id = player['id']
            from app.game.daily_quests_helper import ensure_daily_quests_assigned
            ensure_daily_quests_assigned(player_id)
            
            # Check if player has quests for today
            today = date.today()
            cursor.execute(
                "SELECT * FROM player_daily_quests WHERE player_id = %s AND (assigned_date = %s OR (is_completed = TRUE AND is_claimed = FALSE))",
                (player_id, today)
            )
            current_quests = cursor.fetchall()
            
            # Construct response
            result = []
            for pq in current_quests:
                cursor.execute("SELECT * FROM daily_quests_master WHERE id = %s", (pq['quest_id'],))
                master_info = cursor.fetchone()
                
                current = pq['current_progress']
                target = master_info['target_value']
                
                if current > target:
                    current = target
                    
                result.append({
                    "id": pq['id'], # player_daily_quest id, used for claiming
                    "quest_id": master_info['id'],
                    "type": master_info['type'],
                    "name": master_info['name'],
                    "description": master_info['description'],
                    "target_value": target,
                    "reward_type": master_info['reward_type'],
                    "reward_amount": master_info['reward_amount'],
                    "current_progress": current,
                    "is_completed": bool(pq['is_completed']),
                    "is_claimed": bool(pq['is_claimed']),
                })
                
            return {"quests": result}
    finally:
        conn.close()

@router.post("/daily_quests/{quest_id}/claim", tags=["daily_quests"], response_model=DailyQuestClaimResponse)
def claim_daily_quest(quest_id: int, authorization: str = Header(None)):
    username = verify_token(None, authorization)
    if not username:
        raise HTTPException(status_code=401, detail="Token tidak valid")
        
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, coins, gems FROM players WHERE username = %s FOR UPDATE", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")
                
            player_id = player['id']
            
            # Get the player daily quest
            cursor.execute(
                "SELECT * FROM player_daily_quests WHERE id = %s AND player_id = %s FOR UPDATE", 
                (quest_id, player_id)
            )
            pq = cursor.fetchone()
            
            if not pq:
                raise HTTPException(status_code=404, detail="Misi tidak ditemukan")
            if not pq['is_completed']:
                raise HTTPException(status_code=400, detail="Misi belum selesai")
            if pq['is_claimed']:
                raise HTTPException(status_code=400, detail="Hadiah sudah diklaim")
                
            # Get master info
            cursor.execute("SELECT reward_type, reward_amount FROM daily_quests_master WHERE id = %s", (pq['quest_id'],))
            master_info = cursor.fetchone()
            
            if master_info['reward_type'] == 'gems':
                cursor.execute("UPDATE players SET gems = gems + %s WHERE id = %s", (master_info['reward_amount'], player_id))
            elif master_info['reward_type'] == 'coins':
                cursor.execute("UPDATE players SET coins = coins + %s WHERE id = %s", (master_info['reward_amount'], player_id))
                
            # Mark claimed
            cursor.execute(
                "UPDATE player_daily_quests SET is_claimed = TRUE WHERE id = %s", 
                (pq['id'],)
            )
            
            conn.commit()
            
            return {
                "success": True, 
                "message": f"Berhasil klaim hadiah misi harian! +{master_info['reward_amount']} {master_info['reward_type']}",
                "reward_type": master_info['reward_type'],
                "reward_amount": master_info['reward_amount']
            }
    finally:
        conn.close()
