from typing import List
from app.game.mechanics import SKILL_CONFIG, MAX_RAGE


def _sim_tick_status(effects: List[dict], hp: int) -> tuple:
    new_hp = hp
    rem = []
    for s in effects:
        val = s["value"]
        if s["name"] in ("BURN", "POISON"):
            new_hp = max(0, new_hp - val)
        elif s["name"] == "REGEN":
            new_hp += abs(val)

        new_t = s["turns_left"] - 1
        if new_t > 0:
            rem.append({**s, "turns_left": new_t})
    return new_hp, rem


def _sim_apply_status(
    effects: List[dict], status_name: str, config: dict
) -> List[dict]:
    res = [s for s in effects if s["name"] != status_name]
    res.append(
        {
            "name": status_name,
            "turns_left": config[status_name]["duration"],
            "value": config[status_name]["tick_damage"],
        }
    )
    return res


def _bot_choose_action(
    hp: int,
    rage: int,
    cooldowns: dict,
    status_effects: List[dict],
    opponent_hp: int,
    opponent_status: List[dict],
) -> str:
    # Kumpulkan opsi valid
    valid_options = []
    for skill_name, cfg in SKILL_CONFIG.items():
        if cooldowns.get(skill_name, 0) > 0:
            continue
        # Bug fix #5: gunakan rage_required (konsisten dengan engine) dan MAX_RAGE
        if cfg.get("rage_required") and rage < MAX_RAGE:
            continue
        valid_options.append(skill_name)

    # Prioritas: ULTIMATE jika bisa (kecuali hp sekarat)
    if "ultimate" in valid_options and hp > 30:
        return "ultimate"

    # Prioritas combo:
    has_freeze = any(s["name"] == "FREEZE" for s in opponent_status)
    if has_freeze and "heavy_strike" in valid_options:
        return "heavy_strike"

    has_poison = any(s["name"] == "POISON" for s in opponent_status)
    if has_poison and "fire_blast" in valid_options:
        return "fire_blast"

    has_burn = any(s["name"] == "BURN" for s in status_effects)
    if has_burn and "water_pulse" in valid_options:
        return "water_pulse"

    # Defensive
    if hp < 40 and "heal" in valid_options:
        return "heal"
    if hp < 60 and "iron_shield" in valid_options:
        return "iron_shield"

    # Attack priority
    atk_skills = [
        "fire_blast",
        "stun_bolt",
        "poison_dart",
        "frost_nova",
        "heavy_strike",
        "water_pulse",
        "attack",
    ]
    for skill in atk_skills:
        if skill in valid_options:
            return skill

    return "attack"
