import random
from typing import Dict, Optional, Tuple, Any

class CombatResolver:
    @staticmethod
    def resolve_action(
        action: str, 
        cfg: dict, 
        pdata: dict, 
        odata: dict, 
        opponent_has_poison: bool, 
        opponent_has_freeze: bool,
        player_has_burn: bool
    ) -> Tuple[int, int, Optional[str], bool, bool]:
        """
        Resolves the basic damage, healing, and synergies for an action.
        Returns:
            damage_dealt (int),
            heal_done (int),
            status_applied (str or None),
            is_attack_action (bool),
            track_status_applied (bool),
            remove_opponent_poison (bool),
            remove_opponent_freeze (bool),
            remove_player_burn (bool),
            apply_player_regen (bool)
        """
        damage_dealt = 0
        heal_done = 0
        status_applied = None
        is_attack_action = False
        track_status_applied = False
        
        remove_opponent_poison = False
        remove_opponent_freeze = False
        remove_player_burn = False
        apply_player_regen = False

        if action == "attack":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            is_attack_action = True
        elif action == "heal":
            heal_done = random.randint(*cfg["heal_range"])
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0
        elif action == "heavy_strike":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            status_applied = cfg.get("apply_status")
            is_attack_action = True
        elif action == "fire_blast":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            status_applied = cfg.get("apply_status")
            is_attack_action = True
            track_status_applied = True
        elif action == "stun_bolt":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            status_applied = cfg.get("apply_status")
            is_attack_action = True
            track_status_applied = True
        elif action == "poison_dart":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            status_applied = cfg.get("apply_status")
            is_attack_action = True
            track_status_applied = True
        elif action == "frost_nova":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            status_applied = cfg.get("apply_status")
            is_attack_action = True
        elif action == "water_pulse":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            is_attack_action = True
        elif action == "iron_shield":
            status_applied = "SHIELD"
            track_status_applied = True
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0
        elif action == "ultimate":
            base_dmg = random.randint(*cfg["damage_range"])
            damage_dealt = base_dmg + pdata.get("bonus_attack", 0)
            status_applied = cfg.get("apply_status")
            pdata["rage"] = 0
            pdata["ultimates_used"] = pdata.get("ultimates_used", 0) + 1
            is_attack_action = True

        # Synergy Combos
        if action == "fire_blast" and opponent_has_poison:
            remove_opponent_poison = True
            status_applied = None  # Burn is negated by explosion
            damage_dealt += 35

        if action == "heavy_strike" and opponent_has_freeze:
            remove_opponent_freeze = True
            damage_dealt = int(damage_dealt * 2.5)

        if action in ("water_pulse", "heal") and player_has_burn:
            remove_player_burn = True
            apply_player_regen = True

        return {
            "damage_dealt": damage_dealt,
            "heal_done": heal_done,
            "status_applied": status_applied,
            "is_attack_action": is_attack_action,
            "track_status_applied": track_status_applied,
            "remove_opponent_poison": remove_opponent_poison,
            "remove_opponent_freeze": remove_opponent_freeze,
            "remove_player_burn": remove_player_burn,
            "apply_player_regen": apply_player_regen
        }
