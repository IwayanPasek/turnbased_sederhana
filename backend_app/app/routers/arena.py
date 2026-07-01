import asyncio
from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Header, HTTPException
from app.game.manager import ArenaManager
from app.core.security import verify_ws_token, verify_token
from app.models.schemas import PracticeSimRequest
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

@router.post("/simulate_practice")
def simulate_practice(req: PracticeSimRequest, authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    token = authorization.split(" ")[1]
    username = verify_token(token)
    if not username:
        raise HTTPException(status_code=401, detail="Invalid token")

    action = req.action
    p_name = req.player1
    b_name = req.player2

    p1_state = req.player1_state or {}
    p2_state = req.player2_state or {}

    p_hp = p1_state.get("hp", MAX_HP)
    p_rage = p1_state.get("rage", 0)
    p_status = p1_state.get("status_effects", [])
    p_cooldowns = p1_state.get("cooldowns", {})

    b_hp = p2_state.get("hp", MAX_HP)
    b_rage = p2_state.get("rage", 0)
    b_status = p2_state.get("status_effects", [])
    b_cooldowns = p2_state.get("cooldowns", {})

    # Decrement status & cooldowns for new turn
    p_hp, p_status = _sim_tick_status(p_status, p_hp)
    b_hp, b_status = _sim_tick_status(b_status, b_hp)
    
    for k in list(p_cooldowns.keys()):
        if p_cooldowns[k] > 0: p_cooldowns[k] -= 1
    for k in list(b_cooldowns.keys()):
        if b_cooldowns[k] > 0: b_cooldowns[k] -= 1

    messages = []
    messages.append(f"{p_name} menggunakan {action} pada {b_name}!")
    
    cfg = SKILL_CONFIG.get(action, {})
    if action == "attack":
        dmg = 15
        b_hp -= dmg
        messages.append(f"{b_name} menerima {dmg} damage.")
    elif action == "heal":
        heal = 20
        p_hp = min(MAX_HP, p_hp + heal)
        messages.append(f"{p_name} memulihkan {heal} HP.")
    elif action in ("fire_blast", "stun_bolt", "poison_dart", "frost_nova"):
        dmg = 12
        b_hp -= dmg
        st = cfg.get("apply_status")
        b_status = _sim_apply_status(b_status, st, STATUS_CONFIG)
        messages.append(f"{b_name} menerima {dmg} damage dan terkena {st}!")
    elif action == "heavy_strike":
        dmg = 35
        # Synergy test
        has_freeze = any(s["name"] == "FREEZE" for s in b_status)
        if has_freeze:
            b_status = [s for s in b_status if s["name"] != "FREEZE"]
            dmg = int(dmg * 2.5)
            messages.append("🧊💥 SHATTER! Es dihancurkan! (2.5x Critical Damage)")
        b_hp -= dmg
        messages.append(f"{b_name} menerima {dmg} damage.")
    elif action == "water_pulse":
        dmg = 16
        b_hp -= dmg
        has_burn = any(s["name"] == "BURN" for s in p_status)
        if has_burn:
            p_status = [s for s in p_status if s["name"] != "BURN"]
            p_status = _sim_apply_status(p_status, "REGEN", STATUS_CONFIG)
            messages.append("🌊♨️ STEAM RECOVERY! Air memadamkan api dan memberikan REGEN!")
        messages.append(f"{b_name} menerima {dmg} damage dari serangan air.")
    else:
        messages.append(f"{action} digunakan (efek simulasi sederhana).")

    if cfg.get("cooldown"): p_cooldowns[action] = cfg["cooldown"]

    if p_hp > 0 and b_hp > 0:
        # Bot turn
        b_action = _bot_choose_action(b_hp, b_rage, b_cooldowns, b_status, p_hp, p_status)
        messages.append(f"{b_name} (BOT) membalas dengan {b_action}!")
        
        b_cfg = SKILL_CONFIG.get(b_action, {})
        if b_cfg.get("cooldown"): b_cooldowns[b_action] = b_cfg["cooldown"]

        if b_action == "attack":
            dmg = 15
            p_hp -= dmg
            messages.append(f"{p_name} menerima {dmg} damage.")
        elif b_action == "heal":
            b_hp = min(MAX_HP, b_hp + 18)
            messages.append(f"{b_name} memulihkan HP.")
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

    return {
        "messages": messages,
        "player1": {
            "name": p_name,
            "hp": max(0, p_hp),
            "max_hp": MAX_HP,
            "rage": p_rage,
            "max_rage": MAX_RAGE,
            "status_effects": p_status,
            "cooldowns": p_cooldowns,
            "streak": 0,
            "momentum_stacks": 0
        },
        "player2": {
            "name": b_name,
            "hp": max(0, b_hp),
            "max_hp": MAX_HP,
            "rage": b_rage,
            "max_rage": MAX_RAGE,
            "status_effects": b_status,
            "cooldowns": b_cooldowns,
            "streak": 0,
            "momentum_stacks": 0
        }
    }

@router.get("/game/skills")
def get_skills_info():
    skills = []
    for skill_name, cfg in SKILL_CONFIG.items():
        is_ultimate = skill_name == "ultimate"
        skills.append({
            "id": skill_name,
            "name": skill_name.replace("_", " ").title(),
            "description": cfg.get("description", ""),
            "cooldown": cfg.get("cooldown", 0),
            "rage_required": cfg.get("rage_required", 0) if is_ultimate else 0,
            "is_ultimate": is_ultimate,
            "is_defensive": skill_name == "iron_shield",
            "is_heal": skill_name == "heal",
            "apply_status": cfg.get("apply_status")
        })
    return {"skills": skills}
