# backend/main.py
import os
import pymysql
import jwt
import random  # Ditambahkan: Untuk kalkulasi damage dan heal
from datetime import datetime, timedelta
# Ditambahkan: Import WebSocket dan WebSocketDisconnect
from fastapi import FastAPI, HTTPException, Depends, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from passlib.context import CryptContext
from dotenv import load_dotenv

# Keamanan & Efisiensi: Memuat variabel lingkungan dari file .env di awal
load_dotenv()

app = FastAPI()

# Konfigurasi Keamanan: Password Hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Skema Validasi Input
class UserAuth(BaseModel):
    username: str
    password: str

# -----------------------------------------------------------------------------
# Manajemen Koneksi Database
# -----------------------------------------------------------------------------
def get_db_connection():
    try:
        connection = pymysql.connect(
            host=os.getenv("DB_HOST"),
            port=int(os.getenv("DB_PORT", 4000)),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME"),
            cursorclass=pymysql.cursors.DictCursor,
            # Efisiensi Jaringan: Batas waktu timeout 10 detik
            connect_timeout=10,
            # Keamanan Kritis: Enkripsi TLS/SSL untuk TiDB
            ssl={"ssl": {}} 
        )
        return connection
    except pymysql.MySQLError as e:
        print(f"ERROR DATABASE TiDB: {e}") 
        raise HTTPException(status_code=500, detail="Gagal terhubung ke database cloud")

# -----------------------------------------------------------------------------
# Endpoint: Registrasi
# -----------------------------------------------------------------------------
@app.post("/register", status_code=201)
def register_user(user: UserAuth):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM players WHERE username = %s", (user.username,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Username sudah terdaftar")

            hashed_password = pwd_context.hash(user.password)

            cursor.execute(
                "INSERT INTO players (username, password_hash) VALUES (%s, %s)",
                (user.username, hashed_password)
            )
            player_id = cursor.lastrowid

            cursor.execute(
                "INSERT INTO player_stats (player_id, mmr_score) VALUES (%s, 1000)",
                (player_id,)
            )
            
            conn.commit()
            return {"message": "Registrasi berhasil"}
    finally:
        conn.close()

# -----------------------------------------------------------------------------
# Endpoint: Login & Generate JWT
# -----------------------------------------------------------------------------
@app.post("/login")
def login_user(user: UserAuth):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, username, password_hash FROM players WHERE username = %s", (user.username,))
            player = cursor.fetchone()

            if not player or not pwd_context.verify(user.password, player['password_hash']):
                raise HTTPException(status_code=401, detail="Username atau password salah")

            expiration = datetime.utcnow() + timedelta(days=7)
            payload = {
                "sub": str(player['id']),      
                "username": player['username'],
                "exp": expiration              
            }
            
            secret_key = os.getenv("JWT_SECRET", "fallback_secret_jangan_dipakai_di_produksi")
            token = jwt.encode(payload, secret_key, algorithm="HS256")

            return {"access_token": token, "token_type": "bearer"}
    finally:
        conn.close()

# -----------------------------------------------------------------------------
# Keamanan: Helper Validasi Token JWT untuk WebSocket
# -----------------------------------------------------------------------------
def verify_ws_token(token: str):
    try:
        # Perbaikan: Menggunakan secret key yang sama persis dengan endpoint login
        secret_key = os.getenv("JWT_SECRET", "fallback_secret_jangan_dipakai_di_produksi")
        payload = jwt.decode(token, secret_key, algorithms=["HS256"])
        return payload.get("username") 
    except jwt.ExpiredSignatureError:
        print("ERROR WS: Token sudah kadaluarsa")
        return None
    except jwt.PyJWTError as e:
        # Efisiensi Debugging: Mencetak error detail jika token gagal divalidasi
        print(f"ERROR WS: Token tidak valid -> {e}")
        return None

# -----------------------------------------------------------------------------
# Core Engine: Manajemen State Game Sederhana
# -----------------------------------------------------------------------------
class GameRoom:
    def __init__(self, player1: str, player1_ws: WebSocket, player2: str, player2_ws: WebSocket):
        self.players = {
            player1: {"ws": player1_ws, "hp": 100},
            player2: {"ws": player2_ws, "hp": 100}
        }
        self.player_names = [player1, player2]
        self.turn = player1 
        self.is_active = True

    async def broadcast_state(self, message: str = ""):
        state = {
            "type": "game_state",
            "turn": self.turn,
            "players": {p: {"hp": data["hp"]} for p, data in self.players.items()},
            "message": message
        }
        for data in self.players.values():
            await data["ws"].send_json(state)

    async def process_action(self, player: str, action: str):
        if not self.is_active or player != self.turn:
            return 

        opponent = self.player_names[1] if player == self.player_names[0] else self.player_names[0]
        msg = ""

        if action == "attack":
            damage = random.randint(10, 20)
            self.players[opponent]["hp"] -= damage
            msg = f"{player} menyerang {opponent} sebesar {damage} DMG!"
        elif action == "heal":
            heal = random.randint(10, 15)
            self.players[player]["hp"] += heal
            msg = f"{player} memulihkan {heal} HP!"

        if self.players[opponent]["hp"] <= 0:
            self.players[opponent]["hp"] = 0
            self.is_active = False
            msg = f"GAME OVER! {player} MENANG!"
            await self.broadcast_state(msg)
            return

        self.turn = opponent
        await self.broadcast_state(msg)

class ConnectionManager:
    def __init__(self):
        self.waiting_player_ws: WebSocket = None
        self.waiting_player_name: str = None
        self.active_games: dict = {} 

    async def connect_and_match(self, websocket: WebSocket, username: str):
        # Perbaikan: websocket.accept() dihapus dari sini, dipindah ke rute utama
        if self.waiting_player_ws is None:
            self.waiting_player_ws = websocket
            self.waiting_player_name = username
            await websocket.send_json({"type": "waiting", "message": "Mencari lawan..."})
        else:
            p1_ws, p1_name = self.waiting_player_ws, self.waiting_player_name
            p2_ws, p2_name = websocket, username
            
            self.waiting_player_ws = None
            self.waiting_player_name = None

            room = GameRoom(p1_name, p1_ws, p2_name, p2_ws)
            self.active_games[p1_ws] = room
            self.active_games[p2_ws] = room

            await room.broadcast_state("Game Dimulai!")

    def disconnect(self, websocket: WebSocket):
        if self.waiting_player_ws == websocket:
            self.waiting_player_ws = None
        elif websocket in self.active_games:
            room = self.active_games[websocket]
            room.is_active = False
            del self.active_games[websocket]

manager = ConnectionManager()

# -----------------------------------------------------------------------------
# Endpoint WebSocket untuk Arena Game
# -----------------------------------------------------------------------------
@app.websocket("/ws/arena")
async def arena_endpoint(websocket: WebSocket, token: str = None):
    # Perbaikan Keamanan: Terima koneksi HTTP handshake di awal untuk menghindari raw 403
    await websocket.accept()

    # Validasi keberadaan token
    if not token:
        print("ERROR WS: Token tidak disisipkan dalam request")
        await websocket.close(code=1008, reason="Token kosong")
        return

    # Validasi keaslian token
    username = verify_ws_token(token)
    if not username:
        await websocket.close(code=1008, reason="Sesi tidak valid")
        return

    # Jika valid, masukkan ke logika matchmaking
    await manager.connect_and_match(websocket, username)

    try:
        while True:
            data = await websocket.receive_text()
            payload = json.loads(data)
            
            if websocket in manager.active_games:
                room = manager.active_games[websocket]
                await room.process_action(username, payload.get("action"))

    except WebSocketDisconnect:
        manager.disconnect(websocket)