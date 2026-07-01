# backend/main.py
import os
import random
import traceback
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import jwt
import pymysql
from dotenv import load_dotenv
from fastapi import (
    FastAPI,
    Header,
    HTTPException,
    Request,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from passlib.context import CryptContext
from pydantic import BaseModel

# Keamanan & Efisiensi: Memuat variabel lingkungan di awal siklus aplikasi
load_dotenv()

app = FastAPI()


# Global Exception Handler for debugging 500 errors
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print("====== GLOBAL EXCEPTION HANDLER ======")
    print(f"Request: {request.method} {request.url}")
    print(f"Exception Type: {type(exc)}")
    print(f"Exception Message: {exc}")
    traceback.print_exc()
    print("======================================")
    return JSONResponse(
        status_code=500, content={"detail": f"Internal Server Error: {str(exc)}"}
    )


def run_sql_file(connection, file_path):
    if not os.path.exists(file_path):
        print(f"Migration file not found: {file_path}")
        return

    print(f"Running migration file: {file_path}")
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            sql_content = f.read()

        # Parse queries — split on semicolons, skip comments and empty lines
        queries = []
        current_query = []
        for line in sql_content.split("\n"):
            stripped = line.strip()
            if (
                not stripped
                or stripped.startswith("--")
                or stripped.startswith("/*")
                or stripped.startswith("*")
            ):
                continue
            current_query.append(line)
            if stripped.endswith(";"):
                queries.append("\n".join(current_query))
                current_query = []

        with connection.cursor() as cursor:
            cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")
            for query in queries:
                q_strip = query.strip()
                if not q_strip:
                    continue
                try:
                    cursor.execute(q_strip)
                except Exception as e:
                    # Ignore minor warnings or duplicate columns
                    print(f"Warning during query execution: {e}")
            cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")
        connection.commit()
        print(f"Migration file executed successfully: {file_path}")
    except Exception as e:
        print(f"Error running migration {file_path}: {e}")


@app.on_event("startup")
def startup_db_migration():
    """Ensure database exists and tables are fully initialized/migrated on startup."""
    print("====== STARTING DATABASE CHECK & AUTO-MIGRATION ======")
    try:
        host = os.getenv("DB_HOST", "127.0.0.1")
        port = int(os.getenv("DB_PORT", "3306"))
        user = os.getenv("DB_USER", "root")
        password = os.getenv("DB_PASSWORD", "")
        database = os.getenv("DB_NAME", "turnbased_db")

        # Connect without DB to create if missing
        conn_params = {
            "host": host,
            "port": port,
            "user": user,
            "password": password,
            "cursorclass": pymysql.cursors.DictCursor,
            "connect_timeout": 5,
        }

        use_ssl = (
            os.getenv("DB_USE_SSL", "0").lower() in ("1", "true", "yes")
            or "tidbcloud" in host
        )
        if use_ssl:
            conn_params["ssl"] = {"ssl": {}}

        try:
            temp_conn = pymysql.connect(**conn_params)
        except Exception as e:
            if use_ssl:
                print(
                    f"SSL connection failed on temp connect, retrying without SSL: {e}"
                )
                conn_params.pop("ssl", None)
                temp_conn = pymysql.connect(**conn_params)
            else:
                raise e

        try:
            with temp_conn.cursor() as cursor:
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS {database}")
            temp_conn.commit()
        finally:
            temp_conn.close()

        # Reconnect with DB
        conn = get_db_connection()
        try:
            # Check if core tables exist
            with conn.cursor() as cursor:
                cursor.execute("SHOW TABLES LIKE 'players'")
                has_players = cursor.fetchone()

                cursor.execute("SHOW TABLES LIKE 'shop_items'")
                has_shop = cursor.fetchone()

                cursor.execute("SHOW TABLES LIKE 'battle_logs'")
                has_battle_logs = cursor.fetchone()

            migrations_dir = os.path.join(os.path.dirname(__file__), "migrations")

            if not has_players:
                print("Tables not found, running schema migration (001)...")
                run_sql_file(
                    conn, os.path.join(migrations_dir, "001_shop_upgrade_system.sql")
                )

            if not has_shop:
                print("Table 'shop_items' not found, running seed migration (002)...")
                run_sql_file(
                    conn, os.path.join(migrations_dir, "002_seed_shop_items.sql")
                )

            if not has_battle_logs:
                print("Table 'battle_logs' not found, running gameplay mechanics migration (003)...")
                run_sql_file(
                    conn, os.path.join(migrations_dir, "003_gameplay_mechanics.sql")
                )

            print("Database check completed successfully.")
        finally:
            conn.close()

    except Exception as e:
        print(f"DATABASE AUTO-MIGRATION WARNING: {e}")
    print("======================================================")


# Efisiensi Jaringan: Mengizinkan akses dari semua origin agar Ngrok atau Web Client tidak diblokir oleh kebijakan CORS browser
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Konfigurasi Keamanan: Menggunakan bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# Skema Validasi Input API
class UserAuth(BaseModel):
    username: str
    password: str


# -----------------------------------------------------------------------------
# Manajemen Koneksi Database (TiDB / MySQL)
# -----------------------------------------------------------------------------
def get_db_connection():
    host = os.getenv("DB_HOST", "127.0.0.1")
    port = int(os.getenv("DB_PORT", "3306"))
    user = os.getenv("DB_USER", "root")
    password = os.getenv("DB_PASSWORD", "")
    database = os.getenv("DB_NAME", "turnbased_db")

    use_ssl = (
        os.getenv("DB_USE_SSL", "0").lower() in ("1", "true", "yes")
        or "tidbcloud" in host
    )

    try:
        conn_params = {
            "host": host,
            "port": port,
            "user": user,
            "password": password,
            "database": database,
            "cursorclass": pymysql.cursors.DictCursor,
            "connect_timeout": 10,
        }
        if use_ssl:
            conn_params["ssl"] = {"ssl": {}}

        try:
            return pymysql.connect(**conn_params)
        except pymysql.MySQLError as e:
            if use_ssl:
                print(f"SSL connection failed, retrying without SSL: {e}")
                if "ssl" in conn_params:
                    del conn_params["ssl"]
                return pymysql.connect(**conn_params)
            raise e
    except pymysql.MySQLError as e:
        print(f"ERROR DATABASE: {e}")
        raise HTTPException(status_code=500, detail="Gagal terhubung ke database")


# -----------------------------------------------------------------------------
# Endpoint: Registrasi Pemain Baru
# -----------------------------------------------------------------------------
@app.post("/register", status_code=201)
def register_user(user: UserAuth):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # 1. Mencegah duplikasi username
            cursor.execute(
                "SELECT id FROM players WHERE username = %s", (user.username,)
            )
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Username sudah terdaftar")

            # 2. Hashing password
            hashed_password = pwd_context.hash(user.password)

            # 3. Simpan kredensial pemain
            cursor.execute(
                "INSERT INTO players (username, password_hash) VALUES (%s, %s)",
                (user.username, hashed_password),
            )
            player_id = cursor.lastrowid

            # 4. Inisialisasi statistik default
            cursor.execute(
                "INSERT INTO player_stats (player_id, mmr_score) VALUES (%s, 1000)",
                (player_id,),
            )

            conn.commit()
            return {"message": "Registrasi berhasil"}
    finally:
        conn.close()


# -----------------------------------------------------------------------------
# Endpoint: Login & Generate JWT Token
# -----------------------------------------------------------------------------
@app.post("/login")
def login_user(user: UserAuth):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT id, username, password_hash FROM players WHERE username = %s",
                (user.username,),
            )
            player = cursor.fetchone()

            if not player or not pwd_context.verify(
                user.password, player["password_hash"]
            ):
                raise HTTPException(
                    status_code=401, detail="Username atau password salah"
                )

            # Token berlaku selama 7 hari
            expiration = datetime.utcnow() + timedelta(days=7)
            payload = {
                "sub": str(player["id"]),
                "username": player["username"],
                "exp": expiration,
            }

            secret_key = os.getenv(
                "JWT_SECRET", "fallback_secret_jangan_dipakai_di_produksi"
            )
            token = jwt.encode(payload, secret_key, algorithm="HS256")

            return {"access_token": token, "token_type": "bearer"}
    finally:
        conn.close()


# -----------------------------------------------------------------------------
# Keamanan: Helper Validasi Token JWT khusus jalur WebSocket
# -----------------------------------------------------------------------------
def verify_ws_token(token: str):
    try:
        secret_key = os.getenv(
            "JWT_SECRET", "fallback_secret_jangan_dipakai_di_produksi"
        )
        payload = jwt.decode(token, secret_key, algorithms=["HS256"])
        return payload.get("username")
    except jwt.ExpiredSignatureError:
        print("ERROR WS: Token sudah kadaluarsa")
        return None
    except jwt.PyJWTError as e:
        print(f"ERROR WS: Token tidak valid -> {e}")
        return None


# -----------------------------------------------------------------------------
# Core Engine: Manajemen Logika Pertarungan Turn-Based
# =============================================================================
# MEKANIK BARU:
#   1. Status Effects — BURN, POISON, STUN, SHIELD (diterapkan antar giliran)
#   2. Rage Meter     — 0-100, terisi saat kena damage, Ultimate saat penuh
#   3. Cooldown System— Skill kuat butuh beberapa turn sebelum bisa dipakai lagi
#   4. Momentum Streak— 3 hit beruntun mengaktifkan bonus damage +15%/stack
# =============================================================================

# Konfigurasi semua skill yang tersedia di arena
SKILL_CONFIG: Dict[str, dict] = {
    # --- Aksi Dasar (tanpa cooldown) ---
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
    # --- Skill Menengah ---
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
    # --- Skill Defensif ---
    "iron_shield": {
        "cooldown": 3,
        "apply_status": "SHIELD",
        "description": "Kurangi damage masuk 50% selama 1 turn",
    },
    # --- Ultimate (butuh rage penuh = 100) ---
    "ultimate": {
        "cooldown": 0,          # no cooldown, dibatasi oleh rage meter
        "rage_required": 100,
        "damage_range": (55, 75),
        "apply_status": "BURN",  # bonus: ikut BURN
        "description": "Ultimate — damage masif + BURN, drain rage",
    },
}

# Konfigurasi setiap status effect
STATUS_CONFIG: Dict[str, dict] = {
    "BURN":   {"duration": 3, "tick_damage": 6,  "emoji": "🔥"},
    "POISON": {"duration": 5, "tick_damage": 3,  "emoji": "☠️"},
    "STUN":   {"duration": 1, "tick_damage": 0,  "emoji": "⚡"},
    "SHIELD": {"duration": 1, "tick_damage": 0,  "emoji": "🛡️"},
}

# Konstanta mekanik
MAX_HP = 150            # HP awal lebih tinggi agar pertarungan lebih panjang
MAX_RAGE = 100
RAGE_PER_HIT_TAKEN = 18 # Rage yang didapat saat kena serangan
RAGE_PER_ATTACK = 8     # Rage yang didapat saat menyerang
MOMENTUM_THRESHOLD = 3  # Hit berturut-turut untuk aktifkan streak bonus
MOMENTUM_BONUS = 0.15   # +15% damage per stack momentum
MOMENTUM_MAX_STACKS = 3 # Maksimal 3 stack
SHIELD_REDUCTION = 0.5  # SHIELD kurangi damage 50%


class GameRoom:
    def __init__(
        self, player1: str, player1_ws: WebSocket, player2: str, player2_ws: WebSocket
    ):
        self.players = {
            player1: self._init_player_state(player1_ws),
            player2: self._init_player_state(player2_ws),
        }
        self.player_names = [player1, player2]
        self.turn = player1
        self.turn_number = 0
        self.is_active = True

    def _init_player_state(self, ws: WebSocket) -> dict:
        """Inisialisasi state pemain dengan semua field mekanik baru."""
        return {
            "ws": ws,
            "hp": MAX_HP,
            "rage": 0,               # 0-100 rage meter
            "status_effects": [],    # [{"name": str, "turns_left": int, "value": int}]
            "cooldowns": {},         # {skill_name: turns_remaining}
            "streak": 0,             # consecutive attack hits (momentum)
            "momentum_stacks": 0,    # aktif saat streak >= MOMENTUM_THRESHOLD
        }

    def _get_status(self, player: str, status_name: str) -> Optional[dict]:
        """Cari status effect aktif pada pemain."""
        for s in self.players[player]["status_effects"]:
            if s["name"] == status_name:
                return s
        return None

    def _apply_status(self, target: str, status_name: str):
        """Pasang status effect ke pemain target. Overwrite jika sudah ada."""
        cfg = STATUS_CONFIG[status_name]
        # Hapus status lama yang sama jika ada (refresh)
        self.players[target]["status_effects"] = [
            s for s in self.players[target]["status_effects"]
            if s["name"] != status_name
        ]
        self.players[target]["status_effects"].append({
            "name": status_name,
            "turns_left": cfg["duration"],
            "value": cfg["tick_damage"],
        })

    def _tick_status_effects(self, player: str) -> List[str]:
        """
        Proses semua status effect aktif pada pemain di awal gilirannya:
        - BURN/POISON: kurangi HP sesuai tick_damage
        - STUN: sudah ditangani sebelum aksi
        - SHIELD: habis setelah 1 turn (diurus di proses serangan)
        Kembalikan list pesan efek yang terjadi.
        """
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
                    f"{emoji} {player} terkena {name}: -{tick} HP "
                    f"({turns_left - 1} turn tersisa)"
                )

            new_turns = turns_left - 1
            if new_turns > 0:
                remaining.append({**effect, "turns_left": new_turns})
            # else: effect habis, tidak dimasukkan ke remaining

        self.players[player]["status_effects"] = remaining
        return messages

    def _decrement_cooldowns(self, player: str):
        """Kurangi semua cooldown aktif pada pemain sebesar 1 turn."""
        updated = {}
        for skill, turns in self.players[player]["cooldowns"].items():
            if turns > 1:
                updated[skill] = turns - 1
            # jika turns == 1 -> cooldown habis, tidak dimasukkan
        self.players[player]["cooldowns"] = updated

    def _compute_available_actions(self, player: str) -> List[str]:
        """
        Hitung aksi yang bisa dilakukan pemain saat ini:
        - Filter skill yang masih cooldown
        - Filter 'ultimate' jika rage belum 100
        """
        available = []
        cooldowns = self.players[player]["cooldowns"]
        rage = self.players[player]["rage"]

        for skill_name, cfg in SKILL_CONFIG.items():
            # Skip jika skill masih cooldown
            if cooldowns.get(skill_name, 0) > 0:
                continue
            # Ultimate hanya tersedia jika rage penuh
            if skill_name == "ultimate" and rage < SKILL_CONFIG["ultimate"]["rage_required"]:
                continue
            available.append(skill_name)

        return available

    def _build_public_state(self) -> dict:
        """Bangun dict state yang aman dikirim ke klien (tanpa WebSocket object)."""
        public_players = {}
        for name, data in self.players.items():
            public_players[name] = {
                "hp": data["hp"],
                "max_hp": MAX_HP,
                "rage": data["rage"],
                "max_rage": MAX_RAGE,
                "status_effects": data["status_effects"],
                "cooldowns": data["cooldowns"],
                "streak": data["streak"],
                "momentum_stacks": data["momentum_stacks"],
            }
        return public_players

    async def broadcast_state(self, message: str = "", extra: Optional[dict] = None):
        """Kirim state game lengkap ke semua pemain."""
        current_player = self.turn
        available_actions = (
            self._compute_available_actions(current_player)
            if self.is_active
            else []
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
                await data["ws"].send_json(state)
            except Exception as e:
                print(f"Gagal mengirim state ke {player_name}: {e}")

    async def process_action(self, player: str, action: str):
        """Proses satu aksi pemain dalam satu giliran."""
        if not self.is_active or player != self.turn:
            return

        opponent = (
            self.player_names[1]
            if player == self.player_names[0]
            else self.player_names[0]
        )

        self.turn_number += 1
        messages = []

        # ── 1. STUN CHECK ──────────────────────────────────────────────────────
        # Jika pemain di-STUN, skip giliran dan hapus stun
        stun_effect = self._get_status(player, "STUN")
        if stun_effect:
            self.players[player]["status_effects"] = [
                s for s in self.players[player]["status_effects"]
                if s["name"] != "STUN"
            ]
            self.players[player]["streak"] = 0
            self.players[player]["momentum_stacks"] = 0
            messages.append(f"⚡ {player} ter-STUN dan melewati giliran!")
            self._decrement_cooldowns(player)
            self.turn = opponent
            await self.broadcast_state(" | ".join(messages))
            return

        # ── 2. VALIDASI AKSI ───────────────────────────────────────────────────
        available = self._compute_available_actions(player)
        if action not in available:
            # Aksi tidak valid (cooldown atau rage kurang) — kirim notifikasi
            cooldown_left = self.players[player]["cooldowns"].get(action, 0)
            if cooldown_left > 0:
                err_msg = f"⏳ {action} masih cooldown {cooldown_left} turn!"
            elif action == "ultimate":
                rage_now = self.players[player]["rage"]
                err_msg = f"🌀 Rage belum penuh! ({rage_now}/{MAX_RAGE})"
            else:
                err_msg = f"❌ Aksi '{action}' tidak valid."
            # Kirim error hanya ke pemain yang bersangkutan tanpa ganti giliran
            try:
                await self.players[player]["ws"].send_json({
                    "type": "action_error",
                    "message": err_msg,
                    "available_actions": available,
                })
            except Exception:
                pass
            return

        cfg = SKILL_CONFIG.get(action, {})
        pdata = self.players[player]
        odata = self.players[opponent]

        # ── 3. EKSEKUSI AKSI ───────────────────────────────────────────────────
        damage_dealt = 0
        heal_done = 0
        status_applied = None
        is_attack_action = False  # untuk tracking streak

        if action == "attack":
            # Damage dasar + momentum bonus
            base_dmg = random.randint(*cfg["damage_range"])
            momentum_mult = 1.0 + (pdata["momentum_stacks"] * MOMENTUM_BONUS)
            damage_dealt = int(base_dmg * momentum_mult)
            is_attack_action = True

        elif action == "heal":
            heal_done = random.randint(*cfg["heal_range"])
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0

        elif action == "heavy_strike":
            base_dmg = random.randint(*cfg["damage_range"])
            momentum_mult = 1.0 + (pdata["momentum_stacks"] * MOMENTUM_BONUS)
            damage_dealt = int(base_dmg * momentum_mult)
            is_attack_action = True

        elif action in ("fire_blast", "stun_bolt", "poison_dart"):
            damage_dealt = random.randint(*cfg["damage_range"])
            status_applied = cfg.get("apply_status")
            is_attack_action = True

        elif action == "iron_shield":
            status_applied = "SHIELD"
            # SHIELD dipasang ke diri sendiri
            self._apply_status(player, "SHIELD")
            messages.append(f"🛡️ {player} memasang Iron Shield! (Damage -50% selama 1 turn)")
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0

        elif action == "ultimate":
            base_dmg = random.randint(*cfg["damage_range"])
            damage_dealt = base_dmg
            status_applied = cfg.get("apply_status")
            pdata["rage"] = 0  # drain semua rage
            is_attack_action = True
            messages.append(f"💥 {player} melepas ULTIMATE!")

        # ── 4. TERAPKAN DAMAGE KE LAWAN ────────────────────────────────────────
        if damage_dealt > 0:
            # Cek apakah lawan punya SHIELD aktif
            opponent_shield = self._get_status(opponent, "SHIELD")
            if opponent_shield:
                reduced = int(damage_dealt * SHIELD_REDUCTION)
                messages.append(
                    f"🛡️ SHIELD {opponent} menyerap serangan! "
                    f"Damage {damage_dealt} → {reduced}"
                )
                damage_dealt = reduced
                # Hapus SHIELD setelah menyerap satu serangan
                odata["status_effects"] = [
                    s for s in odata["status_effects"] if s["name"] != "SHIELD"
                ]

            odata["hp"] = max(0, odata["hp"] - damage_dealt)

            # Rage lawan naik karena kena serangan
            odata["rage"] = min(MAX_RAGE, odata["rage"] + RAGE_PER_HIT_TAKEN)
            # Rage penyerang juga naik sedikit
            pdata["rage"] = min(MAX_RAGE, pdata["rage"] + RAGE_PER_ATTACK)

            skill_label = {
                "attack": "menyerang",
                "heavy_strike": "menghantam keras",
                "fire_blast": "menembakkan Fire Blast ke",
                "stun_bolt": "meluncurkan Stun Bolt ke",
                "poison_dart": "melempar Poison Dart ke",
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
            pdata["hp"] = min(MAX_HP, pdata["hp"] + heal_done)
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
                        f"💢 MOMENTUM! {player} mendapatkan +{int(MOMENTUM_BONUS*100)}% "
                        f"bonus damage! (Stack {new_stacks}/{MOMENTUM_MAX_STACKS})"
                    )
        else:
            pdata["streak"] = 0
            pdata["momentum_stacks"] = 0

        # ── 8. SET COOLDOWN SKILL ──────────────────────────────────────────────
        cooldown_turns = cfg.get("cooldown", 0)
        if cooldown_turns > 0:
            pdata["cooldowns"][action] = cooldown_turns

        # ── 9. TICK STATUS EFFECT LAWAN (BURN/POISON berlaku di gilirannya) ────
        # Tidak tick di sini — tick dilakukan di awal giliran pemilik effect
        # (supaya STUN check konsisten)

        # ── 10. TICK STATUS EFFECT DIRI SENDIRI (pada akhir giliran penyerang) ─
        # Tick BURN/POISON pada pemain yang sedang jalan, di akhir turn-nya
        tick_msgs = self._tick_status_effects(player)
        messages.extend(tick_msgs)

        # ── 11. DECREMENT COOLDOWN ─────────────────────────────────────────────
        self._decrement_cooldowns(player)

        # ── 12. CEK KONDISI KEMENANGAN ─────────────────────────────────────────
        game_over = False
        if odata["hp"] <= 0:
            odata["hp"] = 0
            self.is_active = False
            game_over = True
            messages.append(f"💀 GAME OVER! {player} MENANG!")
        elif pdata["hp"] <= 0:
            # Penyerang mati karena status effect tick
            pdata["hp"] = 0
            self.is_active = False
            game_over = True
            messages.append(f"💀 GAME OVER! {opponent} MENANG! ({player} mati karena status effect!)")

        final_message = " | ".join(messages)
        await self.broadcast_state(final_message)

        if game_over:
            winner_name = player if odata["hp"] <= 0 else opponent
            loser_name = opponent if odata["hp"] <= 0 else player
            await self._finalize_battle(winner_name, loser_name)
            return

        # ── 13. PINDAH GILIRAN ─────────────────────────────────────────────────
        self.turn = opponent

    async def _finalize_battle(self, winner_name: str, loser_name: str):
        """Update statistik database setelah pertarungan selesai."""
        try:
            conn = get_db_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    """UPDATE player_stats ps
                       JOIN players p ON p.id = ps.player_id
                       SET ps.wins = ps.wins + 1,
                           ps.matches_played = ps.matches_played + 1,
                           ps.mmr_score = ps.mmr_score + 25
                       WHERE p.username = %s""",
                    (winner_name,),
                )
                cursor.execute(
                    """UPDATE player_stats ps
                       JOIN players p ON p.id = ps.player_id
                       SET ps.losses = ps.losses + 1,
                           ps.matches_played = ps.matches_played + 1,
                           ps.mmr_score = GREATEST(ps.mmr_score - 15, 0)
                       WHERE p.username = %s""",
                    (loser_name,),
                )
            conn.commit()
            conn.close()
        except Exception as e:
            print(f"Warning: failed to update player_stats after game: {e}")


# -----------------------------------------------------------------------------
# Manajemen Antrean & Koneksi (Matchmaking)
# -----------------------------------------------------------------------------
class ConnectionManager:
    def __init__(self):
        self.waiting_player_ws: Optional[WebSocket] = None
        self.waiting_player_name: Optional[str] = None
        self.active_games: dict = {}

    async def connect_and_match(self, websocket: WebSocket, username: str):
        if self.waiting_player_ws is None:
            self.waiting_player_ws = websocket
            self.waiting_player_name = username
            await websocket.send_json(
                {"type": "waiting", "message": "Mencari lawan..."}
            )
        else:
            p1_ws, p1_name = self.waiting_player_ws, self.waiting_player_name
            p2_ws, p2_name = websocket, username

            p1_name_str = p1_name or ""
            self.waiting_player_ws = None
            self.waiting_player_name = None

            room = GameRoom(p1_name_str, p1_ws, p2_name, p2_ws)
            self.active_games[p1_ws] = room
            self.active_games[p2_ws] = room

            await room.broadcast_state("Game Dimulai!")

    async def disconnect(self, websocket: WebSocket):
        if self.waiting_player_ws == websocket:
            self.waiting_player_ws = None
        elif websocket in self.active_games:
            room = self.active_games[websocket]
            room.is_active = False

            opponent_ws = None
            for ws in room.players.values():
                if ws["ws"] != websocket:
                    opponent_ws = ws["ws"]
                    break

            if opponent_ws:
                try:
                    await opponent_ws.send_json(
                        {
                            "type": "game_state",
                            "message": "GAME OVER! Lawan melarikan diri (Disconnect). ANDA MENANG!",
                            "turn": "",
                            "players": {
                                p: {"hp": d["hp"]} for p, d in room.players.items()
                            },
                        }
                    )
                except Exception:
                    pass

            del self.active_games[websocket]
            if opponent_ws in self.active_games:
                del self.active_games[opponent_ws]


manager = ConnectionManager()


# -----------------------------------------------------------------------------
# Endpoint: WebSocket Gateway untuk Arena
# -----------------------------------------------------------------------------
@app.websocket("/ws/arena")
async def arena_endpoint(websocket: WebSocket, token: Optional[str] = None):
    await websocket.accept()

    if not token:
        await websocket.close(code=1008, reason="Token kosong")
        return

    username = verify_ws_token(token)
    if not username:
        await websocket.close(code=1008, reason="Sesi tidak valid")
        return

    await manager.connect_and_match(websocket, username)

    try:
        while True:
            data = await websocket.receive_text()

            if websocket in manager.active_games:
                import json

                payload = json.loads(data)
                room = manager.active_games[websocket]
                await room.process_action(username, payload.get("action"))

    except WebSocketDisconnect:
        await manager.disconnect(websocket)


# -----------------------------------------------------------------------------
# Endpoint: Practice Simulation (Server-side)
# =============================================================================
# Sinkronkan dengan logika mekanik baru: Status Effects, Rage, Momentum Streak
# Bot menggunakan AI sederhana berbasis probabilitas:
#   - Memprioritaskan skill dengan damage tinggi jika rage mencukupi
#   - Healing jika HP di bawah 40%
#   - Menggunakan status effect secara acak
# =============================================================================


class PracticeSimRequest(BaseModel):
    seed: Optional[int] = None
    max_turns: int = 120
    player_start_hp: int = MAX_HP
    bot_start_hp: int = MAX_HP


def _sim_tick_status(effects: List[dict], hp: int) -> tuple:
    """
    Proses tick semua status effect untuk simulasi practice.
    Kembalikan (new_hp, remaining_effects, tick_log_messages).
    """
    remaining = []
    tick_msgs = []
    for effect in effects:
        name = effect["name"]
        turns_left = effect["turns_left"]
        value = effect["value"]
        if name in ("BURN", "POISON"):
            hp = max(0, hp - value)
            tick_msgs.append(f"{name} -{value}HP")
        new_turns = turns_left - 1
        if new_turns > 0:
            remaining.append({**effect, "turns_left": new_turns})
    return hp, remaining, tick_msgs


def _sim_apply_status(effects: List[dict], status_name: str) -> List[dict]:
    """Pasang status effect ke list, overwrite jika sudah ada."""
    cfg = STATUS_CONFIG[status_name]
    effects = [e for e in effects if e["name"] != status_name]
    effects.append({
        "name": status_name,
        "turns_left": cfg["duration"],
        "value": cfg["tick_damage"],
    })
    return effects


def _bot_choose_action(
    rnd: random.Random,
    bot_hp: int,
    player_hp: int,
    bot_rage: int,
    bot_cooldowns: dict,
    bot_effects: List[dict],
) -> str:
    """
    AI bot sederhana untuk practice mode.
    Strategi: defensive jika HP rendah, agresif jika HP aman.
    """
    available = []
    for skill_name, cfg in SKILL_CONFIG.items():
        if bot_cooldowns.get(skill_name, 0) > 0:
            continue
        if skill_name == "ultimate" and bot_rage < SKILL_CONFIG["ultimate"]["rage_required"]:
            continue
        available.append(skill_name)

    hp_ratio = bot_hp / MAX_HP

    # Prioritas ultimate jika tersedia
    if "ultimate" in available:
        return "ultimate"

    # Healing jika HP < 40% dan heal tersedia
    if hp_ratio < 0.40 and "heal" in available and rnd.random() < 0.80:
        return "heal"

    # Shield jika HP < 55% dan ada tekanan
    if hp_ratio < 0.55 and "iron_shield" in available and rnd.random() < 0.45:
        return "iron_shield"

    # Skill agresif — bobot berdasarkan potensi damage
    attack_skills = [
        ("heavy_strike",  3.0),
        ("fire_blast",    2.5),
        ("stun_bolt",     2.0),
        ("poison_dart",   1.8),
        ("attack",        1.0),
    ]
    weighted = [(s, w) for s, w in attack_skills if s in available]
    if not weighted:
        return "attack" if "attack" in available else (available[0] if available else "attack")

    total_weight = sum(w for _, w in weighted)
    roll = rnd.random() * total_weight
    cumulative = 0.0
    for skill, weight in weighted:
        cumulative += weight
        if roll <= cumulative:
            return skill
    return weighted[-1][0]


@app.post("/practice/simulate")
def simulate_practice(req: PracticeSimRequest, token: Optional[str] = None):
    """
    Simulasi pertarungan practice server-side dengan mekanik lengkap:
    Status Effects, Rage Meter, Cooldown, dan Momentum Streak.
    Endpoint ini practice-only dan TIDAK mengubah data persisten.
    Optional `token` dapat disertakan untuk menyertakan username pemain.
    """
    rnd = random.Random(req.seed) if req.seed is not None else random.Random()

    # State pemain
    player_hp   = int(req.player_start_hp)
    player_rage = 0
    player_effects: List[dict] = []
    player_cooldowns: dict = {}
    player_streak = 0
    player_momentum = 0

    # State bot
    bot_hp   = int(req.bot_start_hp)
    bot_rage = 0
    bot_effects: List[dict] = []
    bot_cooldowns: dict = {}
    bot_streak = 0
    bot_momentum = 0

    logs: List[Dict] = []
    turn = "player"
    winner = "draw"
    turn_num = 0

    for turn_num in range(1, req.max_turns + 1):
        # ── Pilih aksi & eksekusi sesuai giliran ────────────────────────────
        if turn == "player":
            action = "attack"  # player selalu attack dalam simulasi (bisa dikembangkan)
            actor_label = "player"

            # Cek STUN
            stun = next((e for e in player_effects if e["name"] == "STUN"), None)
            if stun:
                player_effects = [e for e in player_effects if e["name"] != "STUN"]
                player_streak = 0
                player_momentum = 0
                logs.append({
                    "round": turn_num, "actor": actor_label,
                    "action": "stunned", "value": 0,
                    "player_hp": player_hp, "bot_hp": bot_hp,
                    "status_note": "Player ter-STUN, skip giliran",
                })
                turn = "bot"
                continue

            # Tick status effect player
            player_hp, player_effects, tick_msgs = _sim_tick_status(player_effects, player_hp)
            if player_hp <= 0:
                winner = "bot"
                break

            cfg = SKILL_CONFIG[action]
            base_dmg = rnd.randint(*cfg["damage_range"])
            momentum_mult = 1.0 + (player_momentum * MOMENTUM_BONUS)
            damage = int(base_dmg * momentum_mult)

            # Shield bot
            bot_shield = next((e for e in bot_effects if e["name"] == "SHIELD"), None)
            if bot_shield:
                damage = int(damage * SHIELD_REDUCTION)
                bot_effects = [e for e in bot_effects if e["name"] != "SHIELD"]

            bot_hp = max(0, bot_hp - damage)
            bot_rage = min(MAX_RAGE, bot_rage + RAGE_PER_HIT_TAKEN)
            player_rage = min(MAX_RAGE, player_rage + RAGE_PER_ATTACK)

            player_streak += 1
            if player_streak >= MOMENTUM_THRESHOLD:
                player_momentum = min(MOMENTUM_MAX_STACKS, player_momentum + 1)

            # Decrement cooldowns
            player_cooldowns = {k: v-1 for k, v in player_cooldowns.items() if v > 1}

            logs.append({
                "round": turn_num, "actor": actor_label,
                "action": action, "value": damage,
                "player_hp": player_hp, "bot_hp": bot_hp,
                "player_rage": player_rage, "bot_rage": bot_rage,
                "player_momentum": player_momentum,
                "status_note": " | ".join(tick_msgs) if tick_msgs else None,
            })

            if bot_hp <= 0:
                winner = "player"
                break
            turn = "bot"

        else:
            # Bot memilih aksi
            action = _bot_choose_action(
                rnd, bot_hp, player_hp, bot_rage, bot_cooldowns, bot_effects
            )
            actor_label = "bot"

            # Cek STUN bot
            stun = next((e for e in bot_effects if e["name"] == "STUN"), None)
            if stun:
                bot_effects = [e for e in bot_effects if e["name"] != "STUN"]
                bot_streak = 0
                bot_momentum = 0
                logs.append({
                    "round": turn_num, "actor": actor_label,
                    "action": "stunned", "value": 0,
                    "player_hp": player_hp, "bot_hp": bot_hp,
                    "status_note": "Bot ter-STUN, skip giliran",
                })
                turn = "player"
                continue

            # Tick status effect bot
            bot_hp, bot_effects, tick_msgs = _sim_tick_status(bot_effects, bot_hp)
            if bot_hp <= 0:
                winner = "player"
                break

            cfg = SKILL_CONFIG[action]
            damage_dealt = 0
            heal_done = 0
            status_applied = None

            if action == "heal":
                heal_done = rnd.randint(*cfg["heal_range"])
                bot_hp = min(req.bot_start_hp, bot_hp + heal_done)
                bot_streak = 0
                bot_momentum = 0

            elif action == "iron_shield":
                bot_effects = _sim_apply_status(bot_effects, "SHIELD")
                bot_streak = 0
                bot_momentum = 0

            elif action == "ultimate":
                damage_dealt = rnd.randint(*cfg["damage_range"])
                status_applied = cfg.get("apply_status")
                bot_rage = 0
                bot_streak += 1

            else:
                base_dmg = rnd.randint(*cfg["damage_range"])
                momentum_mult = 1.0 + (bot_momentum * MOMENTUM_BONUS)
                damage_dealt = int(base_dmg * momentum_mult)
                status_applied = cfg.get("apply_status")
                bot_streak += 1

            if bot_streak >= MOMENTUM_THRESHOLD:
                bot_momentum = min(MOMENTUM_MAX_STACKS, bot_momentum + 1)

            # Terapkan damage ke player
            if damage_dealt > 0:
                player_shield = next((e for e in player_effects if e["name"] == "SHIELD"), None)
                if player_shield:
                    damage_dealt = int(damage_dealt * SHIELD_REDUCTION)
                    player_effects = [e for e in player_effects if e["name"] != "SHIELD"]

                player_hp = max(0, player_hp - damage_dealt)
                player_rage = min(MAX_RAGE, player_rage + RAGE_PER_HIT_TAKEN)
                bot_rage = min(MAX_RAGE, bot_rage + RAGE_PER_ATTACK)

            if heal_done > 0:
                pass  # sudah diupdate di atas

            if status_applied and status_applied != "SHIELD":
                player_effects = _sim_apply_status(player_effects, status_applied)

            # Set cooldown
            cooldown_turns = cfg.get("cooldown", 0)
            if cooldown_turns > 0:
                bot_cooldowns[action] = cooldown_turns

            # Decrement cooldowns
            bot_cooldowns = {k: v-1 for k, v in bot_cooldowns.items() if v > 1}

            logs.append({
                "round": turn_num, "actor": actor_label,
                "action": action,
                "value": damage_dealt if damage_dealt > 0 else heal_done,
                "player_hp": player_hp, "bot_hp": bot_hp,
                "player_rage": player_rage, "bot_rage": bot_rage,
                "bot_momentum": bot_momentum,
                "status_applied": status_applied,
                "status_note": " | ".join(tick_msgs) if tick_msgs else None,
            })

            if player_hp <= 0:
                winner = "bot"
                break
            turn = "player"

    else:
        winner = "player" if player_hp >= bot_hp else "bot"

    result = {
        "winner": winner,
        "rounds": turn_num,
        "player_hp": player_hp,
        "bot_hp": bot_hp,
        "player_rage": player_rage,
        "bot_rage": bot_rage,
        "logs": logs,
        "mechanics": {
            "max_hp": MAX_HP,
            "max_rage": MAX_RAGE,
            "available_skills": list(SKILL_CONFIG.keys()),
            "status_effects": list(STATUS_CONFIG.keys()),
        },
    }

    if token:
        player_name = verify_ws_token(token)
        if player_name:
            result["player"] = player_name

    return result


# -----------------------------------------------------------------------------
# Endpoint: Info Skill & Mekanik Game (untuk referensi frontend)
# -----------------------------------------------------------------------------
@app.get("/skills/info", tags=["gameplay"])
def get_skills_info():
    """
    Kembalikan informasi lengkap semua skill yang tersedia:
    nama, cooldown, damage range, status effect yang bisa diterapkan,
    dan deskripsi. Berguna untuk render UI tombol skill secara dinamis.
    """
    skills_out = []
    for skill_name, cfg in SKILL_CONFIG.items():
        skill_entry = {
            "name": skill_name,
            "cooldown": cfg.get("cooldown", 0),
            "description": cfg.get("description", ""),
            "damage_min": cfg["damage_range"][0] if "damage_range" in cfg else None,
            "damage_max": cfg["damage_range"][1] if "damage_range" in cfg else None,
            "heal_min": cfg["heal_range"][0] if "heal_range" in cfg else None,
            "heal_max": cfg["heal_range"][1] if "heal_range" in cfg else None,
            "apply_status": cfg.get("apply_status", None),
            "rage_required": cfg.get("rage_required", 0),
            "is_ultimate": skill_name == "ultimate",
            "is_defensive": skill_name == "iron_shield",
        }
        skills_out.append(skill_entry)

    return {
        "skills": skills_out,
        "status_effects": STATUS_CONFIG,
        "mechanics": {
            "max_hp": MAX_HP,
            "max_rage": MAX_RAGE,
            "rage_per_hit_taken": RAGE_PER_HIT_TAKEN,
            "rage_per_attack": RAGE_PER_ATTACK,
            "momentum_threshold": MOMENTUM_THRESHOLD,
            "momentum_bonus_pct": int(MOMENTUM_BONUS * 100),
            "momentum_max_stacks": MOMENTUM_MAX_STACKS,
            "shield_damage_reduction_pct": int(SHIELD_REDUCTION * 100),
        },
    }


# ============================================================================
# SHOP, INVENTORY & UPGRADE SYSTEM INTEGRATION
# ============================================================================


class ShopItem(BaseModel):
    item_id: int
    item_name: str
    description: str
    item_type: str  # 'weapon', 'armor', 'accessory'
    rarity: str  # 'common', 'uncommon', 'rare', 'epic', 'legendary'
    base_stat_boost: int
    max_level: int
    is_active: bool


class UpgradeCost(BaseModel):
    from_level: int
    to_level: int
    cost_coins: int
    cost_gems: int


class PlayerInventoryItem(BaseModel):
    inventory_id: int
    item_id: int
    current_level: int
    is_equipped: bool
    equipped_slot: Optional[str]
    acquired_date: str
    last_upgraded: Optional[str]


class PlayerProfile(BaseModel):
    player_id: int
    username: str
    coins: int
    gems: int
    equipped_weapon: Optional[dict]
    equipped_armor: Optional[dict]
    equipped_accessory: Optional[dict]


class BuyItemRequest(BaseModel):
    shop_item_id: int


class UpgradeItemRequest(BaseModel):
    inventory_item_id: int


class EquipItemRequest(BaseModel):
    inventory_item_id: int


# Token helper to extract and verify from query parameter or Authorization header
def verify_token(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
) -> Optional[str]:
    tok = token
    if not tok and authorization and authorization.startswith("Bearer "):
        tok = authorization.split(" ")[1]

    if not tok:
        return None

    try:
        secret_key = os.getenv(
            "JWT_SECRET", "fallback_secret_jangan_dipakai_di_produksi"
        )
        payload = jwt.decode(tok, secret_key, algorithms=["HS256"])
        return payload.get("username")
    except jwt.ExpiredSignatureError:
        print("ERROR API: Token sudah kadaluarsa")
        return None
    except jwt.PyJWTError as e:
        print(f"ERROR API: Token tidak valid -> {e}")
        return None


@app.get("/shop/items", tags=["shop"])
def get_shop_items(item_type: Optional[str] = None, rarity: Optional[str] = None):
    """Get all active shop items, optionally filtered by type and rarity.
    Returns items with aliased fields: id, name, base_stat for frontend compatibility.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            query = """
                SELECT
                    item_id   AS id,
                    item_name AS name,
                    item_type,
                    description,
                    base_stat_boost AS base_stat,
                    stat_type,
                    base_cost_coins,
                    base_cost_gems,
                    rarity,
                    is_upgradeable,
                    max_level,
                    icon_url,
                    is_active
                FROM shop_items
                WHERE is_active = TRUE
            """
            params = []

            if item_type:
                query += " AND item_type = %s"
                params.append(item_type)

            if rarity:
                query += " AND rarity = %s"
                params.append(rarity)

            query += " ORDER BY rarity, item_name"
            cursor.execute(query, params)
            items = cursor.fetchall()
            return {"items": items}
    finally:
        conn.close()


@app.get("/shop/item/{item_id}", tags=["shop"])
def get_shop_item_details(item_id: int):
    """Get detailed information about a specific item including upgrade costs."""
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get item details with aliased fields
            cursor.execute(
                """
                SELECT
                    item_id   AS id,
                    item_name AS name,
                    item_type,
                    description,
                    base_stat_boost AS base_stat,
                    stat_type,
                    base_cost_coins,
                    base_cost_gems,
                    rarity,
                    is_upgradeable,
                    max_level,
                    icon_url,
                    is_active
                FROM shop_items
                WHERE item_id = %s
                """,
                (item_id,),
            )
            item = cursor.fetchone()

            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            # Get upgrade costs — alias to_level as level for frontend compatibility
            cursor.execute(
                """
                SELECT
                    from_level,
                    to_level,
                    to_level AS level,
                    cost_coins,
                    cost_gems,
                    stat_bonus_per_level
                FROM upgrade_costs
                WHERE item_id = %s
                ORDER BY from_level
                """,
                (item_id,),
            )
            upgrade_costs = cursor.fetchall()

            return {"item": item, "upgrade_costs": upgrade_costs}
    finally:
        conn.close()


@app.get("/inventory", tags=["inventory"])
def get_player_inventory(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
):
    """Get player's inventory with full item details."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player ID
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]

            # Get inventory items with shop details — alias columns for frontend
            cursor.execute(
                """
                SELECT
                    pi.inventory_id       AS id,
                    pi.inventory_id,
                    pi.item_id            AS shop_item_id,
                    pi.current_level,
                    pi.quantity,
                    pi.is_equipped,
                    pi.equipped_slot,
                    pi.acquired_date      AS acquired_at,
                    pi.last_upgraded      AS last_upgraded_at,
                    si.item_id            AS si_item_id,
                    si.item_name          AS name,
                    si.description,
                    si.item_type,
                    si.rarity,
                    si.base_stat_boost    AS base_stat,
                    si.max_level,
                    si.base_cost_coins,
                    si.base_cost_gems,
                    si.stat_type
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.player_id = %s
                ORDER BY si.item_type, si.rarity, si.item_name
                """,
                (player_id,),
            )

            inventory = cursor.fetchall()
            return {"inventory": inventory, "player_id": player_id}
    finally:
        conn.close()


@app.post("/shop/buy", tags=["shop"])
def buy_item(
    request: BuyItemRequest,
    token: Optional[str] = None,
    authorization: Optional[str] = Header(None),
):
    """Purchase an item from the shop using base_cost_coins / base_cost_gems."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute(
                "SELECT id, coins, gems FROM players WHERE username = %s", (username,)
            )
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]
            current_coins = player["coins"]
            current_gems = player["gems"]

            # Get item — use item_id as PK
            cursor.execute(
                """
                SELECT item_id, item_name, base_cost_coins, base_cost_gems, max_level
                FROM shop_items
                WHERE item_id = %s AND is_active = TRUE
                """,
                (request.shop_item_id,),
            )
            item = cursor.fetchone()
            if not item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            # Check if player already owns this item
            cursor.execute(
                "SELECT inventory_id FROM player_inventory WHERE player_id = %s AND item_id = %s",
                (player_id, request.shop_item_id),
            )
            existing = cursor.fetchone()

            if existing:
                raise HTTPException(
                    status_code=400, detail="Anda sudah memiliki item ini"
                )

            # Purchase cost comes from shop_items.base_cost_coins / base_cost_gems
            coins_required = item["base_cost_coins"]
            gems_required = item["base_cost_gems"]

            # Check if player has enough currency
            if current_coins < coins_required:
                raise HTTPException(
                    status_code=400,
                    detail=f"Koin tidak cukup. Butuh {coins_required} koin, kamu punya {current_coins}",
                )
            if gems_required > 0 and current_gems < gems_required:
                raise HTTPException(
                    status_code=400,
                    detail=f"Gems tidak cukup. Butuh {gems_required} gems",
                )

            # Deduct currency
            new_coins = current_coins - coins_required
            new_gems = current_gems - gems_required
            cursor.execute(
                "UPDATE players SET coins = %s, gems = %s WHERE id = %s",
                (new_coins, new_gems, player_id),
            )

            # Add to inventory
            cursor.execute(
                """
                INSERT INTO player_inventory
                    (player_id, item_id, current_level, quantity, is_equipped)
                VALUES (%s, %s, 1, 1, FALSE)
                """,
                (player_id, request.shop_item_id),
            )
            inventory_id = cursor.lastrowid

            # Log currency transaction
            cursor.execute(
                """
                INSERT INTO currency_transactions
                    (player_id, transaction_type, coins_change, gems_change, reason, reference_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    player_id,
                    "shop_purchase",
                    -coins_required,
                    -gems_required if gems_required else 0,
                    f"Membeli item: {item['item_name']}",
                    inventory_id,
                ),
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"Item '{item['item_name']}' berhasil dibeli",
                "inventory_id": inventory_id,
                "new_coins": new_coins,
                "new_gems": new_gems,
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.post("/inventory/upgrade", tags=["inventory"])
def upgrade_item(
    request: UpgradeItemRequest,
    token: Optional[str] = None,
    authorization: Optional[str] = Header(None),
):
    """Upgrade an inventory item to the next level."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute(
                "SELECT id, coins, gems FROM players WHERE username = %s", (username,)
            )
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]
            current_coins = player["coins"]
            current_gems = player["gems"]

            # Get inventory item with shop details
            cursor.execute(
                """
                SELECT
                    pi.inventory_id,
                    pi.player_id,
                    pi.item_id,
                    pi.current_level,
                    si.max_level,
                    si.item_name
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.inventory_id = %s
                """,
                (request.inventory_item_id,),
            )

            inv_item = cursor.fetchone()
            if not inv_item:
                raise HTTPException(
                    status_code=404, detail="Item di inventory tidak ditemukan"
                )

            if inv_item["player_id"] != player_id:
                raise HTTPException(status_code=403, detail="Item ini bukan milik Anda")

            current_level = inv_item["current_level"]
            max_level = inv_item["max_level"]

            if current_level >= max_level:
                raise HTTPException(
                    status_code=400, detail="Item sudah mencapai level maksimal"
                )

            # Get upgrade cost for next level (from_level → to_level)
            next_level = current_level + 1
            cursor.execute(
                """
                SELECT cost_coins, cost_gems
                FROM upgrade_costs
                WHERE item_id = %s AND from_level = %s AND to_level = %s
                """,
                (inv_item["item_id"], current_level, next_level),
            )

            cost = cursor.fetchone()
            if not cost:
                raise HTTPException(
                    status_code=400,
                    detail=f"Biaya upgrade level {current_level} → {next_level} tidak ditemukan",
                )

            coins_required = cost["cost_coins"]
            gems_required = cost["cost_gems"]

            # Check resources
            if current_coins < coins_required or current_gems < gems_required:
                raise HTTPException(
                    status_code=400,
                    detail=f"Sumber daya tidak cukup. Butuh: {coins_required} koin, {gems_required} gems",
                )

            # Deduct currency
            new_coins = current_coins - coins_required
            new_gems = current_gems - gems_required

            cursor.execute(
                "UPDATE players SET coins = %s, gems = %s WHERE id = %s",
                (new_coins, new_gems, player_id),
            )

            # Upgrade inventory item — use last_upgraded (schema column name)
            cursor.execute(
                """
                UPDATE player_inventory
                SET current_level = %s, last_upgraded = NOW()
                WHERE inventory_id = %s
                """,
                (next_level, request.inventory_item_id),
            )

            # Audit log: player_upgrades — use schema columns item_id, cost_coins, cost_gems
            cursor.execute(
                """
                INSERT INTO player_upgrades
                    (player_id, item_id, from_level, to_level, cost_coins, cost_gems)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    player_id,
                    inv_item["item_id"],
                    current_level,
                    next_level,
                    coins_required,
                    gems_required,
                ),
            )

            # Log currency transaction — no currency_type column in schema
            cursor.execute(
                """
                INSERT INTO currency_transactions
                    (player_id, transaction_type, coins_change, gems_change, reason, reference_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    player_id,
                    "upgrade",
                    -coins_required,
                    -gems_required,
                    f"Upgrade {inv_item['item_name']} level {current_level} → {next_level}",
                    request.inventory_item_id,
                ),
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"Item berhasil di-upgrade ke level {next_level}",
                "new_level": next_level,
                "new_coins": new_coins,
                "new_gems": new_gems,
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.post("/inventory/equip", tags=["inventory"])
def equip_item(
    request: EquipItemRequest,
    token: Optional[str] = None,
    authorization: Optional[str] = Header(None),
):
    """Equip an item in its corresponding slot using player_inventory.is_equipped & equipped_slot."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player
            cursor.execute("SELECT id FROM players WHERE username = %s", (username,))
            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]

            # Get inventory item with type info
            cursor.execute(
                """
                SELECT pi.inventory_id, pi.player_id, pi.is_equipped,
                       pi.equipped_slot, si.item_type, si.item_name
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.inventory_id = %s
                """,
                (request.inventory_item_id,),
            )

            inv_item = cursor.fetchone()
            if not inv_item:
                raise HTTPException(status_code=404, detail="Item tidak ditemukan")

            if inv_item["player_id"] != player_id:
                raise HTTPException(status_code=403, detail="Item bukan milik Anda")

            item_type = inv_item["item_type"]

            # Validate item type is equippable
            if item_type not in ("weapon", "armor", "accessory"):
                raise HTTPException(
                    status_code=400,
                    detail=f"Tipe item '{item_type}' tidak dapat dilengkapi",
                )

            # Unequip any currently equipped item in the same slot for this player
            cursor.execute(
                """
                UPDATE player_inventory
                SET is_equipped = FALSE, equipped_slot = NULL
                WHERE player_id = %s AND equipped_slot = %s
                """,
                (player_id, item_type),
            )

            # Equip the new item
            cursor.execute(
                """
                UPDATE player_inventory
                SET is_equipped = TRUE, equipped_slot = %s
                WHERE inventory_id = %s
                """,
                (item_type, request.inventory_item_id),
            )

            conn.commit()

            return {
                "status": "success",
                "message": f"{inv_item['item_name']} berhasil dipasang di slot {item_type}",
            }
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/stats", tags=["profile"])
def get_player_stats(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
):
    """Get player's stats including currency, battle stats and equipped items."""
    username = verify_token(token, authorization)
    if not username:
        raise HTTPException(
            status_code=401, detail="Token tidak valid atau tidak disertakan"
        )

    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Get player with battle stats
            cursor.execute(
                """
                SELECT
                    p.id, p.username, p.coins, p.gems,
                    ps.mmr_score, ps.wins, ps.losses, ps.matches_played
                FROM players p
                LEFT JOIN player_stats ps ON p.id = ps.player_id
                WHERE p.username = %s
                """,
                (username,),
            )

            player = cursor.fetchone()
            if not player:
                raise HTTPException(status_code=404, detail="Player tidak ditemukan")

            player_id = player["id"]

            # Get all currently equipped items via player_inventory.is_equipped
            cursor.execute(
                """
                SELECT
                    pi.inventory_id,
                    pi.current_level,
                    pi.equipped_slot,
                    si.item_id,
                    si.item_name  AS name,
                    si.base_stat_boost AS base_stat,
                    si.stat_type,
                    si.item_type
                FROM player_inventory pi
                JOIN shop_items si ON pi.item_id = si.item_id
                WHERE pi.player_id = %s AND pi.is_equipped = TRUE
                """,
                (player_id,),
            )
            equipped_rows = cursor.fetchall()

            equipped = {}
            for row in equipped_rows:
                slot = row.get("equipped_slot") or row.get("item_type")
                if slot:
                    equipped[slot] = row

            return {
                "player_id": player["id"],
                "username": player["username"],
                "coins": player["coins"],
                "gems": player["gems"],
                "mmr": player["mmr_score"] or 1000,
                "wins": player["wins"] or 0,
                "losses": player["losses"] or 0,
                "matches_played": player["matches_played"] or 0,
                "equipped": equipped,
            }
    finally:
        conn.close()
