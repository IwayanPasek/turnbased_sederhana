from app.core.database import get_db_connection

def update_daily_quest_progress(player_id: int, quest_type: str, increment: int = 1):
    """
    Increments progress for daily quests of a specific type for a player, 
    but only for quests assigned TODAY.
    """
    # Ensure quests are assigned first so progress isn't lost if they haven't opened the UI yet
    ensure_daily_quests_assigned(player_id)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Check if player has any active daily quests of this type TODAY
            cursor.execute(
                """
                SELECT pq.id, pq.current_progress, pq.is_completed, m.target_value
                FROM player_daily_quests pq
                JOIN daily_quests_master m ON pq.quest_id = m.id
                WHERE pq.player_id = %s 
                  AND m.type = %s 
                  AND pq.assigned_date = CURRENT_DATE
                """,
                (player_id, quest_type)
            )
            quests = cursor.fetchall()
            
            for pq in quests:
                if not pq['is_completed']:
                    new_progress = pq['current_progress'] + increment
                    is_completed = 1 if new_progress >= pq['target_value'] else 0
                    
                    cursor.execute(
                        """
                        UPDATE player_daily_quests 
                        SET current_progress = %s, 
                            is_completed = %s,
                            completed_at = CASE WHEN %s = 1 THEN CURRENT_TIMESTAMP ELSE NULL END
                        WHERE id = %s
                        """,
                        (new_progress, is_completed, is_completed, pq['id'])
                    )
            
            conn.commit()
    finally:
        conn.close()

def ensure_daily_quests_assigned(player_id: int):
    """
    Ensures that a player has 3 daily quests assigned for today.
    If they don't, it assigns them automatically.
    """
    from datetime import date
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            today = date.today()
            # Check if player has quests for today
            cursor.execute(
                "SELECT id FROM player_daily_quests WHERE player_id = %s AND assigned_date = %s LIMIT 1",
                (player_id, today)
            )
            has_quests = cursor.fetchone()
            
            if not has_quests:
                # Assign 3 random quests
                cursor.execute("SELECT id FROM daily_quests_master ORDER BY RAND() LIMIT 3")
                master_quests = cursor.fetchall()
                
                if master_quests:
                    # Delete old quests, EXCEPT those that are completed but not yet claimed
                    cursor.execute(
                        "DELETE FROM player_daily_quests WHERE player_id = %s AND assigned_date != %s AND NOT (is_completed = TRUE AND is_claimed = FALSE)", 
                        (player_id, today)
                    )
                    
                    # Assign new quests
                    for mq in master_quests:
                        cursor.execute(
                            "INSERT INTO player_daily_quests (player_id, quest_id, assigned_date) VALUES (%s, %s, %s)",
                            (player_id, mq['id'], today)
                        )
                    conn.commit()
    finally:
        conn.close()
