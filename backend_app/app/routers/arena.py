from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Header, HTTPException
from app.game.manager import ArenaManager
from app.core.security import verify_ws_token, verify_token
from app.models.schemas import PracticeSimRequest, PracticeSimResponse
from app.game.mechanics import SKILL_CONFIG, STATUS_CONFIG, MAX_HP, MAX_RAGE
from app.game.bot import _sim_tick_status, _sim_apply_status, _bot_choose_action

router = APIRouter()
arena_manager = ArenaManager()


@router.websocket("/ws/arena")
async def arena_endpoint(websocket: WebSocket, token: Optional[str] = None):
    if not token:
        await websocket.close(code=1008)
        return
    username = verify_ws_token(token)
    if not username:
        await websocket.close(code=1008)
        return

    await arena_manager.connect_and_match(websocket, username)
    try:
        while True:
            data = await websocket.receive_text()
            await arena_manager.handle_action(websocket, data)
    except WebSocketDisconnect:
        await arena_manager.disconnect(websocket)
    except Exception as e:
        print(f"Error WS: {e}")
        await arena_manager.disconnect(websocket)


@router.post("/simulate_practice", response_model=PracticeSimResponse)
def simulate_practice(
    req: PracticeSimRequest, authorization: Optional[str] = Header(None)
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    token = authorization.split(" ")[1]
    username = verify_token(token)
    if not username:
        raise HTTPException(status_code=401, detail="Invalid token")

    action = req.action
    p_name = username
    b_name = req.player2

    p1_state = req.player1_state or {}
    p2_state = req.player2_state or {}

    # Calculate stats from DB every turn
    try:
        from app.core.database import get_db_connection
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT si.stat_type, si.base_stat_boost, pi.current_level, si.granted_skill
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                JOIN players p ON pi.player_id = p.id
                WHERE p.username = %s AND pi.is_equipped = TRUE
            """, (username,))
            bonus_attack = 0
            bonus_hp = 0
            bonus_defense = 0
            skills = ["attack", "heal", "ultimate"]
            
            for row in cursor.fetchall():
                skill = row["granted_skill"]
                if skill and skill not in skills:
                    skills.append(skill)
                
                boost = (row["base_stat_boost"] or 0) * (row["current_level"] or 1)
                stat = row["stat_type"]
                if stat == "hp": bonus_hp += boost
                elif stat == "attack": bonus_attack += boost
                elif stat == "defense": bonus_defense += boost

            cursor.execute("""
                SELECT pa.strength, pa.agility, pa.intelligence
                FROM player_attributes pa
                JOIN players p ON pa.player_id = p.id
                WHERE p.username = %s
            """, (username,))
            attr_row = cursor.fetchone()
            if attr_row:
                bonus_attack += (attr_row["strength"] or 0) * 2
                bonus_hp += (attr_row["strength"] or 0) * 10
                
                p1_state["dodge_chance"] = (attr_row["agility"] or 0) * 0.005
                p1_state["crit_chance"] = (attr_row["agility"] or 0) * 0.005
                
                p1_state["max_rage"] = MAX_RAGE + (attr_row["intelligence"] or 0) * 10
                p1_state["rage_gen"] = 15 + (attr_row["intelligence"] or 0) * 2
            
            backend_max_hp = MAX_HP + bonus_hp
            frontend_max_hp = p1_state.get("max_hp", MAX_HP)
            
            if frontend_max_hp != backend_max_hp:
                diff = backend_max_hp - frontend_max_hp
                if "hp" in p1_state:
                    p1_state["hp"] = p1_state["hp"] + diff
            
            p1_state["max_hp"] = backend_max_hp
            p1_state["bonus_attack"] = bonus_attack
            p1_state["granted_skills"] = skills
            
            if "hp" not in p1_state:
                p1_state["hp"] = p1_state["max_hp"]
    except Exception as e:
        print("Error initializing practice stats:", e)
    finally:
        conn.close()

    p_hp = p1_state.get("hp", p1_state.get("max_hp", MAX_HP))
    p_rage = p1_state.get("rage", 0)
    p_status = p1_state.get("status_effects", [])
    p_cooldowns = p1_state.get("cooldowns", {})
    p_streak = p1_state.get("streak", 0)
    p_momentum = p1_state.get("momentum_stacks", 0)
    
    p_bonus_atk = p1_state.get("bonus_attack", 0)
    p_dodge = p1_state.get("dodge_chance", 0.0)
    p_crit = p1_state.get("crit_chance", 0.0)
    p_max_rage = p1_state.get("max_rage", MAX_RAGE)
    p_rage_gen = p1_state.get("rage_gen", 15)

    b_hp = p2_state.get("hp", MAX_HP)
    b_rage = p2_state.get("rage", 0)
    b_status = p2_state.get("status_effects", [])
    b_cooldowns = p2_state.get("cooldowns", {})
    
    b_dodge = p2_state.get("dodge_chance", 0.0)
    b_crit = p2_state.get("crit_chance", 0.0)
    b_max_rage = p2_state.get("max_rage", MAX_RAGE)
    b_rage_gen = p2_state.get("rage_gen", 15)

    # Decrement status & cooldowns for new turn
    p_hp, p_status = _sim_tick_status(p_status, p_hp)
    b_hp, b_status = _sim_tick_status(b_status, b_hp)

    for k in list(p_cooldowns.keys()):
        if p_cooldowns[k] > 0:
            p_cooldowns[k] -= 1
    for k in list(b_cooldowns.keys()):
        if b_cooldowns[k] > 0:
            b_cooldowns[k] -= 1

    messages = []
    messages.append(f"{p_name} menggunakan {action} pada {b_name}!")

    cfg = SKILL_CONFIG.get(action, {})
    if action == "attack":
        dmg = 15 + p_bonus_atk
        b_hp -= dmg
        messages.append(f"{b_name} menerima {dmg} damage.")
    elif action == "heal":
        heal = 20
        p_hp = min(p1_state.get("max_hp", MAX_HP), p_hp + heal)
        messages.append(f"{p_name} memulihkan {heal} HP.")
    elif action == "ultimate":
        import random
        dmg = random.randint(55, 75) + p_bonus_atk
        p_rage = 0
        b_hp -= dmg
        b_status = _sim_apply_status(b_status, "BURN", STATUS_CONFIG)
        messages.append(f"💥 {p_name} melepas ULTIMATE!")
        messages.append(f"{b_name} menerima {dmg} damage dan terkena BURN!")
    elif action in ("fire_blast", "stun_bolt", "poison_dart", "frost_nova"):
        dmg = 12 + p_bonus_atk
        st = cfg.get("apply_status")
        has_toxic_explosion = False
        if action == "fire_blast":
            has_poison = any(s["name"] == "POISON" for s in b_status)
            if has_poison:
                b_status = [s for s in b_status if s["name"] != "POISON"]
                dmg += 35
                has_toxic_explosion = True
                messages.append("💥 TOXIC EXPLOSION! Api menyulut racun lawan! (+35 Bonus Damage)")
        b_hp -= dmg
        if not has_toxic_explosion and st:
            b_status = _sim_apply_status(b_status, st, STATUS_CONFIG)
            messages.append(f"{b_name} menerima {dmg} damage dan terkena {st}!")
        else:
            messages.append(f"{b_name} menerima {dmg} damage.")
    elif action == "heavy_strike":
        dmg = 35 + p_bonus_atk
        # Synergy test
        has_freeze = any(s["name"] == "FREEZE" for s in b_status)
        if has_freeze:
            b_status = [s for s in b_status if s["name"] != "FREEZE"]
            dmg = int(dmg * 2.5)
            messages.append("🧊💥 SHATTER! Es dihancurkan! (2.5x Critical Damage)")
        b_hp -= dmg
        messages.append(f"{b_name} menerima {dmg} damage.")
    elif action == "water_pulse":
        dmg = 16 + p_bonus_atk
        b_hp -= dmg
        has_burn = any(s["name"] == "BURN" for s in p_status)
        if has_burn:
            p_status = [s for s in p_status if s["name"] != "BURN"]
            p_status = _sim_apply_status(p_status, "REGEN", STATUS_CONFIG)
            messages.append(
                "🌊♨️ STEAM RECOVERY! Air memadamkan api dan memberikan REGEN!"
            )
        messages.append(f"{b_name} menerima {dmg} damage dari serangan air.")
    else:
        messages.append(f"{action} digunakan (efek simulasi sederhana).")

    if cfg.get("cooldown"):
        p_cooldowns[action] = cfg["cooldown"]
        
    p_rage = min(p_max_rage, p_rage + p_rage_gen)

    if p_hp > 0 and b_hp > 0:
        # Bot turn
        b_action = _bot_choose_action(
            b_hp, b_rage, b_cooldowns, b_status, p_hp, p_status
        )
        messages.append(f"{b_name} (BOT) membalas dengan {b_action}!")

        b_cfg = SKILL_CONFIG.get(b_action, {})
        if b_cfg.get("cooldown"):
            b_cooldowns[b_action] = b_cfg["cooldown"]
            
        b_rage = min(b_max_rage, b_rage + b_rage_gen)

        if b_action == "attack":
            dmg = 15
            p_hp -= dmg
            messages.append(f"{p_name} menerima {dmg} damage.")
        elif b_action == "heal":
            b_hp = min(MAX_HP, b_hp + 18)
            messages.append(f"{b_name} memulihkan HP.")
        elif b_action == "ultimate":
            import random
            dmg = random.randint(55, 75)
            b_rage = 0
            p_hp -= dmg
            p_status = _sim_apply_status(p_status, "BURN", STATUS_CONFIG)
            messages.append(f"💥 {b_name} melepas ULTIMATE!")
            messages.append(f"{p_name} menerima {dmg} damage dan terkena BURN!")
        elif b_action in ("fire_blast", "stun_bolt", "poison_dart", "frost_nova"):
            dmg = 10
            p_hp -= dmg
            st = b_cfg.get("apply_status")
            p_status = _sim_apply_status(p_status, st, STATUS_CONFIG)
            messages.append(f"{p_name} menerima {dmg} damage dan terkena {st}!")
        elif b_action == "heavy_strike":
            dmg = 25
            p_hp -= dmg
            messages.append(f"{p_name} menerima {dmg} damage.")
            
    if p_hp <= 0:
        messages.append(f"💀 GAME OVER! {b_name} MENANG!")
    elif b_hp <= 0:
        messages.append(f"💀 GAME OVER! {p_name} MENANG!")

    return {
        "messages": messages,
        "player1": {
            "name": p_name,
            "hp": max(0, p_hp),
            "max_hp": p1_state.get("max_hp", MAX_HP),
            "rage": p_rage,
            "max_rage": p_max_rage,
            "status_effects": p_status,
            "cooldowns": p_cooldowns,
            "streak": p_streak,
            "momentum_stacks": p_momentum,
            "bonus_attack": p_bonus_atk,
            "crit_chance": p_crit,
            "dodge_chance": p_dodge,
            "rage_gen": p_rage_gen,
            "granted_skills": p1_state.get("granted_skills", ["attack", "heal", "ultimate"]),
        },
        "player2": {
            "name": b_name,
            "hp": max(0, b_hp),
            "max_hp": MAX_HP,
            "rage": b_rage,
            "max_rage": b_max_rage,
            "status_effects": b_status,
            "cooldowns": b_cooldowns,
            "streak": 0,
            "momentum_stacks": 0,
            "bonus_attack": 0,
            "crit_chance": b_crit,
            "dodge_chance": b_dodge,
            "rage_gen": b_rage_gen,
            "granted_skills": ["attack", "heal", "ultimate"],
        },
    }


@router.get("/game/skills")
def get_skills_info():
    skills = []
    for skill_name, cfg in SKILL_CONFIG.items():
        is_ultimate = skill_name == "ultimate"
        skills.append(
            {
                "id": skill_name,
                "name": skill_name.replace("_", " ").title(),
                "description": cfg.get("description", ""),
                "cooldown": cfg.get("cooldown", 0),
                "rage_required": cfg.get("rage_required", 0) if is_ultimate else 0,
                "is_ultimate": is_ultimate,
                "is_defensive": skill_name == "iron_shield",
                "is_heal": skill_name == "heal",
                "apply_status": cfg.get("apply_status"),
            }
        )
    return {"skills": skills}
