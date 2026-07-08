from typing import Optional, List
from app.game.mechanics import STATUS_CONFIG


class StatusManager:
    @staticmethod
    def get_status(player_data: dict, status_name: str) -> Optional[dict]:
        for s in player_data["status_effects"]:
            if s["name"] == status_name:
                return s
        return None

    @staticmethod
    def apply_status(player_data: dict, status_name: str):
        cfg = STATUS_CONFIG[status_name]
        player_data["status_effects"] = [
            s for s in player_data["status_effects"] if s["name"] != status_name
        ]
        player_data["status_effects"].append(
            {
                "name": status_name,
                "turns_left": cfg["duration"],
                "value": cfg["tick_damage"],
            }
        )

    @staticmethod
    def remove_status(player_data: dict, status_name: str):
        player_data["status_effects"] = [
            s for s in player_data["status_effects"] if s["name"] != status_name
        ]

    @staticmethod
    def tick_status_effects(player_data: dict, player_name: str) -> List[str]:
        messages = []
        remaining = []
        for effect in player_data["status_effects"]:
            name = effect["name"]
            turns_left = effect["turns_left"]
            value = effect["value"]

            if name in ("BURN", "POISON"):
                tick = value
                player_data["hp"] = max(0, player_data["hp"] - tick)
                emoji = STATUS_CONFIG[name]["emoji"]
                messages.append(
                    f"{emoji} {player_name} terkena {name}: -{tick} HP ({turns_left - 1} turn tersisa)"
                )
            elif name == "REGEN":
                tick = abs(value)  # value is negative in config
                player_data["hp"] = min(
                    player_data["max_hp"], player_data["hp"] + tick
                )
                emoji = STATUS_CONFIG[name]["emoji"]
                messages.append(
                    f"{emoji} {player_name} REGEN: +{tick} HP ({turns_left - 1} turn tersisa)"
                )

            new_turns = turns_left - 1
            if new_turns > 0:
                remaining.append({**effect, "turns_left": new_turns})

        player_data["status_effects"] = remaining
        return messages
