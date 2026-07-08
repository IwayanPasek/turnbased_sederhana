import random
from typing import Optional, List
from fastapi import WebSocket
from app.game.mechanics import (
    SKILL_CONFIG,
    STATUS_CONFIG,
    MAX_HP,
    MAX_RAGE,
    RAGE_PER_HIT_TAKEN,
    RAGE_PER_ATTACK,
    MOMENTUM_THRESHOLD,
    MOMENTUM_BONUS,
    MOMENTUM_MAX_STACKS,
    SHIELD_REDUCTION,
)
from app.core.database import get_db_connection


class GameRoom:
    def __init__(
        self, player1: str, player1_ws: WebSocket, player2: str, player2_ws: WebSocket
    ):
        self.players = {
            player1: self._init_player_state(player1_ws, player1),
            player2: self._init_player_state(player2_ws, player2),
        }
        self.player_names = [player1, player2]
        self.turn = player1
        self.turn_number = 0
        self.is_active = True

    def _init_player_state(self, ws: WebSocket, username: str) -> dict:
        skills = ["attack", "heal", "ultimate"]

        bonus_hp = 0
        bonus_attack = 0
        crit_chance = 0.0
        dodge_chance = 0.0
        
        strength = 0
        agility = 0
        intelligence = 0

        conn = get_db_connection()
        try:
            with conn.cursor() as cursor:
                # 1. Get Attributes
                cursor.execute(
                    """
                    SELECT pa.strength, pa.agility, pa.intelligence
                    FROM player_attributes pa
                    JOIN players p ON pa.player_id = p.id
                    WHERE p.username = %s
                    """,
                    (username,),
                )
                attr_row = cursor.fetchone()
                if attr_row:
                    strength = attr_row["strength"]
                    agility = attr_row["agility"]
                    intelligence = attr_row["intelligence"]
                
                # 2. Get Item Stats & Skills
                cursor.execute(
                    """
                    SELECT si.granted_skill, si.stat_type, si.base_stat_boost, pi.current_level
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
                    
                    stat_type = row["stat_type"]
                    base_boost = row["base_stat_boost"] or 0
                    level = row["current_level"] or 1
                    
                    if stat_type == "hp":
                        bonus_hp += base_boost * level
                    elif stat_type == "attack":
                        bonus_attack += base_boost * level
                    elif stat_type == "crit":
                        crit_chance += (base_boost * level) / 100.0
                    elif stat_type == "dodge":
                        dodge_chance += (base_boost * level) / 100.0

        except Exception as e:
            print(f"Error loading stats for {username}: {e}")
        finally:
            conn.close()

        final_max_hp = MAX_HP + bonus_hp + (strength * 10)
        final_bonus_attack = bonus_attack + (strength * 2)
        final_crit_chance = crit_chance + (agility * 0.01)
        final_dodge_chance = dodge_chance + (agility * 0.01)
        final_max_rage = MAX_RAGE + (intelligence * 10)

        return {
            "ws": ws,
            "hp": final_max_hp,
            "max_hp": final_max_hp,
            "bonus_attack": final_bonus_attack,
            "crit_chance": final_crit_chance,
            "dodge_chance": final_dodge_chance,
            "max_rage": final_max_rage,
            "rage_gen": RAGE_PER_ATTACK,
            "rage": 0,
            "status_effects": [],
            "cooldowns": {},
            "streak": 0,
            "momentum_stacks": 0,
            "granted_skills": skills,
        }

    def _get_status(self, player: str, status_name: str) -> Optional[dict]:
        for s in self.players[player]["status_effects"]:
            if s["name"] == status_name:
                return s
        return None

    def _apply_status(self, target: str, status_name: str):
        cfg = STATUS_CONFIG[status_name]
        self.players[target]["status_effects"] = [
            s
            for s in self.players[target]["status_effects"]
            if s["name"] != status_name
        ]
        self.players[target]["status_effects"].append(
            {
                "name": status_name,
                "turns_left": cfg["duration"],
                "value": cfg["tick_damage"],
            }
        )

    def _remove_status(self, target: str, status_name: str):
        self.players[target]["status_effects"] = [
            s
            for s in self.players[target]["status_effects"]
            if s["name"] != status_name
        ]

    def _tick_status_effects(self, player: str) -> List[str]:
        messages = []
        remaining = []
        for effect in self.players[player]["status_effects"]:
            name = effect["name"]
            turns_left = effect["turns_left"]
            value = effect["value"]

            if name in ("BURN", "POISON"):
                tick = value
                self.players[player]["hp"] = max(0, self.players[player]["hp"] - tick)
                emoji = STATUS_CONFIG[name]["emoji"]
                messages.append(
                    f"{emoji} {player} terkena {name}: -{tick} HP ({turns_left - 1} turn tersisa)"
                )
            elif name == "REGEN":
                tick = abs(value)  # value is negative in config
                self.players[player]["hp"] = min(
                    self.players[player].get("max_hp", MAX_HP), self.players[player]["hp"] + tick
                )
                emoji = STATUS_CONFIG[name]["emoji"]
                messages.append(
                    f"{emoji} {player} REGEN: +{tick} HP ({turns_left - 1} turn tersisa)"
                )

            new_turns = turns_left - 1
            if new_turns > 0:
                remaining.append({**effect, "turns_left": new_turns})

        self.players[player]["status_effects"] = remaining
        return messages

    def _decrement_cooldowns(self, player: str):
        updated = {}
        for skill, turns in self.players[player]["cooldowns"].items():
            if turns > 1:
                updated[skill] = turns - 1
        self.players[player]["cooldowns"] = updated

    def _compute_available_actions(self, player: str) -> List[str]:
        available = []
        cooldowns = self.players[player]["cooldowns"]
        rage = self.players[player]["rage"]
        skills = self.players[player].get(
            "granted_skills", ["attack", "heal", "ultimate"]
        )

        for skill_name in skills:
            cfg = SKILL_CONFIG.get(skill_name)
            if not cfg:
                continue

            # Cooldown check
            if cooldowns.get(skill_name, 0) > 0:
                continue

            # Rage check
            if cfg.get("requires_full_rage") and rage < self.players[player].get("max_rage", MAX_RAGE):
                continue

            available.append(skill_name)
        return available

    def _build_public_state(self) -> dict:
        public_players = {}
        for name, data in self.players.items():
            public_players[name] = {
                "hp": data["hp"],
                "max_hp": data.get("max_hp", MAX_HP),
                "rage": data["rage"],
                "max_rage": data.get("max_rage", MAX_RAGE),
                "status_effects": data["status_effects"],
                "cooldowns": data["cooldowns"],
                "streak": data["streak"],
                "momentum_stacks": data["momentum_stacks"],
                "bonus_attack": data.get("bonus_attack", 0),
                "crit_chance": data.get("crit_chance", 0.0),
                "dodge_chance": data.get("dodge_chance", 0.0),
                "rage_gen": data.get("rage_gen", 8),
                "granted_skills": data.get("granted_skills", ["attack", "heal", "ultimate"]),
            }
        return public_players

    async def broadcast_state(self, message: str = "", extra: Optional[dict] = None):
        if extra is None: extra = {}
        if "animation_events" not in extra:
            extra["animation_events"] = []
        current_player = self.turn
        available_actions = (
            self._compute_available_actions(current_player) if self.is_active else []
        )

        state = {
            "type": "game_state",
            "turn": self.turn,
            "turn_number": self.turn_number,
            "players": self._build_public_state(),
            "available_actions": available_actions,
            "message": message,
        }
        if extra:
            state.update(extra)

        for player_name, data in self.players.items():
            try:
                if data["ws"]:
                    await data["ws"].send_json(state)
            except Exception as e:
                print(f"Gagal mengirim state ke {player_name}: {e}")

    async def process_action(self, player: str, action: str):
        if not self.is_active or player != self.turn:
            return
        
        animation_events = []

        opponent = (
            self.player_names[1]
            if player == self.player_names[0]
            else self.player_names[0]
        )
        self.turn_number += 1
        messages = []

        # ── 1. STUN & FREEZE CHECK ──────────────────────────────────────────────────────
        stun_effect = self._get_status(player, "STUN")
        freeze_effect = self._get_status(player, "FREEZE")

        if stun_effect or freeze_effect:
            eff_name = "STUN" if stun_effect else "FREEZE"
            emoji = "⚡" if stun_effect else "🧊"
            self._remove_status(player, "STUN")
            # FREEZE stays for 2 turns, let tick handler remove it, but it skips turn
            if stun_effect:
                self.players[player]["status_effects"] = [
                    s
                    for s in self.players[player]["status_effects"]
                    if s["name"] != "STUN"
                ]
            else:
                # Deduct FREEZE turn
                for s in self.players[player]["status_effects"]:
                    if s["name"] == "FREEZE":
                        s["turns_left"] -= 1
                        if s["turns_left"] <= 0:
                            self._remove_status(player, "FREEZE")
                        break

            self.players[player]["streak"] = 0
            self.players[player]["momentum_stacks"] = 0
            messages.append(f"{emoji} {player} ter-{eff_name} dan melewati giliran!")
            self._decrement_cooldowns(player)

            # TICK STATUS SEBELUM PINDAH GILIRAN JIKA SKIP
            tick_msgs = self._tick_status_effects(player)
            messages.extend(tick_msgs)

            self.turn = opponent
            await self.broadcast_state(" | ".join(messages), extra={"animation_events": animation_events})
            return

        # ── 2. VALIDASI AKSI ───────────────────────────────────────────────────
        available = self._compute_available_actions(player)
        if action not in available:
            cooldown_left = self.players[player]["cooldowns"].get(action, 0)
            if cooldown_left > 0:
                err_msg = f"⏳ {action} masih cooldown {cooldown_left} turn!"
            elif action == "ultimate":
                rage_now = self.players[player]["rage"]
                err_msg = f"🌀 Rage belum penuh! ({rage_now}/{self.players[player].get('max_rage', MAX_RAGE)})"
            else:
                err_msg = f"❌ Aksi '{action}' tidak valid."

            try:
                if self.players[player]["ws"]:
                    await self.players[player]["ws"].send_json(
                        {
                            "type": "action_error",
                            "message": err_msg,
                            "available_actions": available,
                        }
                    )
            except Exception:
                pass
            return

        cfg = SKILL_CONFIG.get(action, {})
        pdata = self.players[player]
        odata = self.players[opponent]

        damage_dealt = 0
        heal_done = 0
        status_applied = None
        is_attack_action = False

        # --- Base Damage/Heal Calculation ---
        if action == "attack":
            base_dmg = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            momentum_mult = 1.0 + (pdata["momentum_stacks"] * MOMENTUM_BONUS)
            damage_dealt = int(base_dmg * momentum_mult)
            is_attack_action = True
            animation_events.append({"type": "ATTACK_PHYSICAL", "source": player, "target": opponent, "value": damage_dealt})
        elif action == "heal":
            heal_done = random.randint(*cfg["heal_range"])
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0
            animation_events.append({"type": "HEAL", "source": player, "target": player, "value": heal_done})
        elif action == "heavy_strike":
            base_dmg = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            momentum_mult = 1.0 + (pdata["momentum_stacks"] * MOMENTUM_BONUS)
            damage_dealt = int(base_dmg * momentum_mult)
            is_attack_action = True
            animation_events.append({"type": "ATTACK_HEAVY", "source": player, "target": opponent, "value": damage_dealt})
        elif action in ("fire_blast", "stun_bolt", "poison_dart", "frost_nova"):
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            status_applied = cfg.get("apply_status")
            is_attack_action = True
            event_type = f"ATTACK_{action.upper()}"
            animation_events.append({"type": event_type, "source": player, "target": opponent, "value": damage_dealt})
        elif action == "water_pulse":
            damage_dealt = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            is_attack_action = True
            animation_events.append({"type": "ATTACK_WATER_PULSE", "source": player, "target": opponent, "value": damage_dealt})
        elif action == "iron_shield":
            status_applied = "SHIELD"
            self._apply_status(player, "SHIELD")
            messages.append(
                f"🛡️ {player} memasang Iron Shield! (Damage -50% selama 1 turn)"
            )
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0
            animation_events.append({"type": "SHIELD", "source": player, "target": player, "value": 0})
        elif action == "ultimate":
            base_dmg = random.randint(*cfg["damage_range"]) + pdata.get("bonus_attack", 0)
            damage_dealt = base_dmg
            status_applied = cfg.get("apply_status")
            pdata["rage"] = 0
            is_attack_action = True
            messages.append(f"💥 {player} melepas ULTIMATE!")
            animation_events.append({"type": "ULTIMATE", "source": player, "target": opponent, "value": damage_dealt})

        # ── 3. SYNERGY COMBO CHECK ─────────────────────────────────────────────
        # Toxic Explosion: Opponent has POISON + we use fire_blast
        if action == "fire_blast" and self._get_status(opponent, "POISON"):
            self._remove_status(opponent, "POISON")
            status_applied = None  # Burn is negated by explosion
            damage_dealt += 35
            messages.append(
                "💥 TOXIC EXPLOSION! Api menyulut racun lawan! (+35 Bonus Damage)"
            )

        # Shatter: Opponent has FREEZE + we use heavy_strike
        if action == "heavy_strike" and self._get_status(opponent, "FREEZE"):
            self._remove_status(opponent, "FREEZE")
            damage_dealt = int(damage_dealt * 2.5)
            messages.append("🧊💥 SHATTER! Es dihancurkan! (2.5x Critical Damage)")

        # Steam Recovery: We have BURN + we use water_pulse or heal
        if action in ("water_pulse", "heal") and self._get_status(player, "BURN"):
            self._remove_status(player, "BURN")
            self._apply_status(player, "REGEN")
            messages.append(
                "🌊♨️ STEAM RECOVERY! Air memadamkan api dan memberikan efek REGEN!"
            )

        
        # --- Dodge & Crit Check ---
        is_critical = False
        if is_attack_action and damage_dealt > 0:
            if random.random() < odata.get("dodge_chance", 0.0):
                damage_dealt = 0
                status_applied = None
                messages.append(f"💨 {opponent} berhasil menghindari serangan!")
                animation_events.append({"type": "EVASION", "source": opponent, "target": opponent, "value": 0})
                # Remove attack animation event if evaded? Or let it be?
                # Evasion means the attack misses.
            elif random.random() < pdata.get("crit_chance", 0.0):
                is_critical = True
                damage_dealt = int(damage_dealt * 1.5)
                messages.append(f"💥 CRITICAL HIT!")
        
        # Update animation events with final damage and critical flag
        for event in animation_events:
            if event["type"].startswith("ATTACK_") or event["type"] == "ULTIMATE":
                event["value"] = damage_dealt
                if is_critical:
                    event["is_critical"] = True

        # ── 4. TERAPKAN DAMAGE KE LAWAN ────────────────────────────────────────
        if damage_dealt > 0:
            opponent_shield = self._get_status(opponent, "SHIELD")
            if opponent_shield:
                reduced = int(damage_dealt * SHIELD_REDUCTION)
                messages.append(
                    f"🛡️ SHIELD {opponent} menyerap serangan! Damage {damage_dealt} → {reduced}"
                )
                damage_dealt = reduced
                self._remove_status(opponent, "SHIELD")

            odata["hp"] = max(0, odata["hp"] - damage_dealt)
            odata["rage"] = min(odata.get("max_rage", MAX_RAGE), odata["rage"] + RAGE_PER_HIT_TAKEN)
            pdata["rage"] = min(pdata.get("max_rage", MAX_RAGE), pdata["rage"] + pdata.get("rage_gen", RAGE_PER_ATTACK))

            skill_label = {
                "attack": "menyerang",
                "heavy_strike": "menghantam keras",
                "fire_blast": "menembakkan Fire Blast ke",
                "stun_bolt": "meluncurkan Stun Bolt ke",
                "poison_dart": "melempar Poison Dart ke",
                "frost_nova": "membekukan",
                "water_pulse": "menyerang dengan gelombang air ke",
                "ultimate": "menghancurkan",
            }.get(action, "menyerang")

            momentum_info = ""
            if pdata["momentum_stacks"] > 0 and action in ("attack", "heavy_strike"):
                momentum_info = f" (💢 Momentum x{pdata['momentum_stacks']})"

            messages.append(
                f"{player} {skill_label} {opponent} -{damage_dealt} HP!{momentum_info}"
            )

        # ── 5. TERAPKAN HEAL ───────────────────────────────────────────────────
        if heal_done > 0:
            pdata["hp"] = min(pdata.get("max_hp", MAX_HP), pdata["hp"] + heal_done)
            messages.append(f"💚 {player} memulihkan +{heal_done} HP!")

        # ── 6. TERAPKAN STATUS EFFECT KE LAWAN ────────────────────────────────
        if status_applied and status_applied != "SHIELD":
            self._apply_status(opponent, status_applied)
            emoji = STATUS_CONFIG[status_applied]["emoji"]
            dur = STATUS_CONFIG[status_applied]["duration"]
            messages.append(
                f"{emoji} {opponent} terkena {status_applied} ({dur} turn)!"
            )

        # ── 7. UPDATE MOMENTUM STREAK ──────────────────────────────────────────
        if is_attack_action:
            pdata["streak"] += 1
            if pdata["streak"] >= MOMENTUM_THRESHOLD:
                new_stacks = min(MOMENTUM_MAX_STACKS, pdata["momentum_stacks"] + 1)
                if new_stacks > pdata["momentum_stacks"]:
                    pdata["momentum_stacks"] = new_stacks
                    messages.append(
                        f"💢 MOMENTUM! {player} bonus damage! (Stack {new_stacks}/{MOMENTUM_MAX_STACKS})"
                    )
        else:
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0

        # ── 8. SET COOLDOWN SKILL ──────────────────────────────────────────────
        cooldown_turns = cfg.get("cooldown", 0)
        if cooldown_turns > 0:
            pdata["cooldowns"][action] = cooldown_turns

        # ── 9. TICK STATUS EFFECT DIRI SENDIRI ─────────────────────────────────
        tick_msgs = self._tick_status_effects(player)
        messages.extend(tick_msgs)

        # ── 10. DECREMENT COOLDOWN ─────────────────────────────────────────────
        self._decrement_cooldowns(player)

        # ── 11. CEK KONDISI KEMENANGAN ─────────────────────────────────────────
        game_over = False
        if odata["hp"] <= 0:
            odata["hp"] = 0
            self.is_active = False
            game_over = True
            messages.append(f"💀 GAME OVER! {player} MENANG!")
        elif pdata["hp"] <= 0:
            pdata["hp"] = 0
            self.is_active = False
            game_over = True
            messages.append(
                f"💀 GAME OVER! {opponent} MENANG! ({player} mati karena status effect!)"
            )

        final_message = " | ".join(messages)

        if not game_over:
            self.turn = opponent

        await self.broadcast_state(final_message, extra={"animation_events": animation_events})

        if game_over:
            winner_name = player if odata["hp"] <= 0 else opponent
            loser_name = opponent if odata["hp"] <= 0 else player
            await self._finalize_battle(winner_name, loser_name)
            return

    async def _finalize_battle(self, winner_name: str, loser_name: str):
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    """UPDATE player_stats ps
                       JOIN players p ON p.id = ps.player_id
                       SET ps.wins = ps.wins + 1,
                           ps.matches_played = ps.matches_played + 1,
                           ps.mmr_score = ps.mmr_score + 25,
                           p.coins = p.coins + 50
                       WHERE p.username = %s""",
                    (winner_name,),
                )
                cursor.execute(
                    """UPDATE player_stats ps
                       JOIN players p ON p.id = ps.player_id
                       SET ps.losses = ps.losses + 1,
                           ps.matches_played = ps.matches_played + 1,
                           ps.mmr_score = GREATEST(ps.mmr_score - 15, 0),
                           p.coins = p.coins + 15
                       WHERE p.username = %s""",
                    (loser_name,),
                )
                cursor.execute(
                    """INSERT INTO battle_logs (player1_id, player2_id, winner_id)
                       VALUES (
                           (SELECT id FROM players WHERE username=%s),
                           (SELECT id FROM players WHERE username=%s),
                           (SELECT id FROM players WHERE username=%s)
                       )""",
                    (winner_name, loser_name, winner_name),
                )
            conn.commit()
            conn.close()
        except Exception as e:
            print(f"Gagal mencatat statistik pertarungan: {e}")
