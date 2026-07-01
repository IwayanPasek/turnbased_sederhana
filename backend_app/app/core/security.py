import os
import jwt
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

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

from typing import Optional
from fastapi import Header

def verify_token(
    token: Optional[str] = None, authorization: Optional[str] = Header(None)
) -> Optional[str]:
    tok = token
    if not tok and authorization and authorization.startswith("Bearer "):
        tok = authorization.split(" ")[1]

    if not tok:
        return None
        
    return verify_ws_token(tok)
