from fastapi import WebSocket
from app.core.database import get_db_connection
from app.game.mechanics import MAX_HP, MAX_RAGE, RAGE_PER_ATTACK


class PlayerStateLoader:
    @staticmethod
    def load(username: str, ws: WebSocket) -> dict:
        skills = ["attack", "heal", "ultimate"]
        bonus_hp = 0
        bonus_attack = 0
        bonus_defense = 0  # flat damage reduction per hit
        active_title = ""
        avatar_style = "default"

        conn = get_db_connection()
        try:
            with conn.cursor() as cursor:
                # 1. Load Equipment Skills and Stats
                cursor.execute(
                    """
                    SELECT si.granted_skill, si.stat_type,
                           si.base_stat_boost, pi.current_level
                    FROM player_inventory pi
                    JOIN shop_items si ON pi.item_id = si.item_id
                    JOIN players p ON pi.player_id = p.id
                    WHERE p.username = %s AND pi.is_equipped = TRUE
                """,
                    (username,),
                )
                for row in cursor.fetchall():
                    skill = row["granted_skill"]
                    if skill and skill not in skills:
                        skills.append(skill)

                    boost = (row["base_stat_boost"] or 0) * (row["current_level"] or 1)
                    stat = row["stat_type"]
                    if stat == "hp":
                        bonus_hp += boost
                    elif stat == "attack":
                        bonus_attack += boost
                    elif stat == "defense":
                        bonus_defense += boost

                # 2. Load Profile (Title, Avatar)
                cursor.execute("SELECT active_title, avatar_style FROM players WHERE username = %s", (username,))
                player_row = cursor.fetchone()
                if player_row:
                    active_title = player_row["active_title"] or ""
                    avatar_style = player_row["avatar_style"] or "default"

                # 3. Load Attributes (STR, AGI, INT)
                cursor.execute("""
                    SELECT pa.strength, pa.agility, pa.intelligence
                    FROM player_attributes pa
                    JOIN players p ON pa.player_id = p.id
                    WHERE p.username = %s
                """, (username,))
                attr_row = cursor.fetchone()
                
                attr_strength = attr_row["strength"] or 0 if attr_row else 0
                attr_agility = attr_row["agility"] or 0 if attr_row else 0
                attr_intelligence = attr_row["intelligence"] or 0 if attr_row else 0

                bonus_attack += (attr_strength * 2)
                bonus_hp += (attr_strength * 5)
                
                dodge_chance = attr_agility * 0.005  # 0.5% per point
                crit_chance = attr_agility * 0.005
                
                bonus_max_rage = attr_intelligence * 10
                bonus_rage_gen = attr_intelligence * 2
                
                # 4. Load Guild Buffs
                cursor.execute("""
                    SELECT g.level
                    FROM guild_members gm
                    JOIN guilds g ON gm.guild_id = g.id
                    JOIN players p ON gm.player_id = p.id
                    WHERE p.username = %s
                """, (username,))
                guild_row = cursor.fetchone()
                if guild_row:
                    g_level = guild_row["level"] or 1
                    bonus_hp += (g_level * 10)
                    bonus_attack += (g_level * 2)
                    
        except Exception as e:
            print(f"Error loading player data for {username}: {e}")
        finally:
            conn.close()

        # Defense: setiap 10 poin defense = 1% damage reduction, maks 50%
        damage_reduction = min(0.50, bonus_defense / 1000)
        effective_hp = MAX_HP + bonus_hp

        return {
            "ws": ws,
            "hp": effective_hp,
            "max_hp": effective_hp,
            "rage": 0,
            "max_rage": MAX_RAGE + bonus_max_rage,
            "rage_gen": RAGE_PER_ATTACK + bonus_rage_gen,
            "status_effects": [],
            "cooldowns": {},
            "streak": 0,
            "momentum_stacks": 0,
            "granted_skills": skills,
            "bonus_attack": bonus_attack,
            "damage_reduction": damage_reduction,
            "dodge_chance": dodge_chance,
            "crit_chance": crit_chance,
            "ultimates_used": 0,
            "status_applied_count": 0,
            "title": active_title,
            "avatar_style": avatar_style,
            "best_streak": 0,
        }
