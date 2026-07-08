from app.core.database import get_db_connection

def update_achievement_progress(player_id: int, achievement_type: str, increment: int = 1):
    """
    Increments progress for all achievements of a specific type for a player.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get all achievements of this type
            cursor.execute("SELECT id, target_value FROM achievements WHERE type = %s", (achievement_type,))
            achievements = cursor.fetchall()
            
            for ach in achievements:
                ach_id = ach['id']
                target = ach['target_value']
                
                # Check if player has progress for this achievement
                cursor.execute(
                    "SELECT id, current_progress, is_completed FROM player_achievements WHERE player_id = %s AND achievement_id = %s",
                    (player_id, ach_id)
                )
                prog = cursor.fetchone()
                
                if prog:
                    if not prog['is_completed']:
                        new_progress = prog['current_progress'] + increment
                        is_completed = 1 if new_progress >= target else 0
                        
                        cursor.execute(
                            """
                            UPDATE player_achievements 
                            SET current_progress = %s, 
                                is_completed = %s,
                                completed_at = CASE WHEN %s = 1 THEN CURRENT_TIMESTAMP ELSE NULL END
                            WHERE id = %s
                            """,
                            (new_progress, is_completed, is_completed, prog['id'])
                        )
                else:
                    new_progress = increment
                    is_completed = 1 if new_progress >= target else 0
                    
                    cursor.execute(
                        """
                        INSERT INTO player_achievements 
                        (player_id, achievement_id, current_progress, is_completed, completed_at)
                        VALUES (%s, %s, %s, %s, CASE WHEN %s = 1 THEN CURRENT_TIMESTAMP ELSE NULL END)
                        """,
                        (player_id, ach_id, new_progress, is_completed, is_completed)
                    )
            
            conn.commit()
    finally:
        conn.close()
