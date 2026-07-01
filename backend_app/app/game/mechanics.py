from typing import Dict

# -----------------------------------------------------------------------------
# Core Engine: Manajemen Logika Pertarungan Turn-Based (Dengan Kombinasi Elemen)
# -----------------------------------------------------------------------------

SKILL_CONFIG: Dict[str, dict] = {
    "attack": {
        "cooldown": 0,
        "damage_range": (10, 20),
        "description": "Serangan dasar",
    },
    "heal": {
        "cooldown": 0,
        "heal_range": (15, 22),
        "description": "Pulihkan HP diri sendiri",
    },
    "heavy_strike": {
        "cooldown": 2,
        "damage_range": (28, 42),
        "description": "Hantaman berat, damage tinggi",
    },
    "fire_blast": {
        "cooldown": 3,
        "damage_range": (15, 22),
        "apply_status": "BURN",
        "description": "Ledakan api + BURN 3 turn",
    },
    "stun_bolt": {
        "cooldown": 4,
        "damage_range": (12, 18),
        "apply_status": "STUN",
        "description": "Kilatan listrik, stun lawan 1 turn",
    },
    "poison_dart": {
        "cooldown": 3,
        "damage_range": (8, 12),
        "apply_status": "POISON",
        "description": "Serang + POISON 5 turn",
    },
    "iron_shield": {
        "cooldown": 3,
        "apply_status": "SHIELD",
        "description": "Kurangi damage masuk 50% selama 1 turn",
    },
    "ultimate": {
        "cooldown": 0,
        "rage_required": 100,
        "damage_range": (55, 75),
        "apply_status": "BURN",
        "description": "Ultimate — damage masif + BURN, drain rage",
    },
    # --- New Skills (Elemental Synergy) ---
    "frost_nova": {
        "cooldown": 3,
        "damage_range": (10, 15),
        "apply_status": "FREEZE",
        "description": "Membekukan lawan selama 2 turn",
    },
    "water_pulse": {
        "cooldown": 2,
        "damage_range": (12, 20),
        "description": "Serangan air. Jika punya BURN, ubah jadi REGEN",
    },
}

STATUS_CONFIG: Dict[str, dict] = {
    "BURN": {"duration": 3, "tick_damage": 6, "emoji": "🔥"},
    "POISON": {"duration": 5, "tick_damage": 3, "emoji": "☠️"},
    "STUN": {"duration": 1, "tick_damage": 0, "emoji": "⚡"},
    "SHIELD": {"duration": 1, "tick_damage": 0, "emoji": "🛡️"},
    # --- New Status (Elemental Synergy) ---
    "FREEZE": {"duration": 2, "tick_damage": 0, "emoji": "🧊"},
    "REGEN": {
        "duration": 2,
        "tick_damage": -10,
        "emoji": "💖",
    },  # Negatif damage = heal
}

MAX_HP = 150
MAX_RAGE = 100
RAGE_PER_HIT_TAKEN = 18
RAGE_PER_ATTACK = 8
MOMENTUM_THRESHOLD = 3
MOMENTUM_BONUS = 0.15
MOMENTUM_MAX_STACKS = 3
SHIELD_REDUCTION = 0.5
