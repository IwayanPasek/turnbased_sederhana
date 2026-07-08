import os
import jwt
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException
from app.models.schemas import UserAuth, RegisterResponse, LoginResponse
from app.core.database import get_db_connection
from app.core.security import pwd_context

router = APIRouter()


@router.post("/register", status_code=201, response_model=RegisterResponse)
def register_user(user: UserAuth):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT id FROM players WHERE username = %s", (user.username,)
            )
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Username sudah terdaftar")

            hashed_password = pwd_context.hash(user.password)
            cursor.execute(
                "INSERT INTO players (username, password_hash, avatar_style, level, exp) VALUES (%s, %s, 'meme', 1, 0)",
                (user.username, hashed_password),
            )
            player_id = cursor.lastrowid

            cursor.execute(
                "INSERT INTO player_stats (player_id, mmr_score) VALUES (%s, 1000)",
                (player_id,),
            )
            cursor.execute(
                "INSERT INTO player_attributes (player_id, available_points) VALUES (%s, 10)",
                (player_id,),
            )
            conn.commit()
            return {"message": "Registrasi berhasil"}
    finally:
        conn.close()


@router.post("/login", response_model=LoginResponse)
def login_user(user: UserAuth):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT id, username, password_hash, is_banned, is_admin FROM players WHERE username = %s",
                (user.username,),
            )
            player = cursor.fetchone()

            if not player or not pwd_context.verify(
                user.password, player["password_hash"]
            ):
                raise HTTPException(
                    status_code=401, detail="Username atau password salah"
                )
                
            if player.get("is_banned"):
                raise HTTPException(
                    status_code=403, detail="Akun Anda telah diblokir (Banned)"
                )

            expiration = datetime.utcnow() + timedelta(days=7)
            payload = {
                "sub": str(player["id"]),
                "username": player["username"],
                "is_admin": bool(player.get("is_admin")),
                "exp": expiration,
            }

            secret_key = os.getenv(
                "JWT_SECRET", "fallback_secret_jangan_dipakai_di_produksi"
            )
            token = jwt.encode(payload, secret_key, algorithm="HS256")
            return {
                "access_token": token,
                "token_type": "bearer",
                "is_admin": bool(player.get("is_admin"))
            }
    finally:
        conn.close()
