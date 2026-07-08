from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
import traceback
import os

from app.core.database import startup_db_migration
from app.routers import auth, shop, arena, leaderboard, guild, daily_quests, admin


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan handler: jalankan DB migration saat startup."""
    startup_db_migration()
    yield


is_prod = os.getenv("ENV", "development").lower() == "production"

app = FastAPI(
    lifespan=lifespan,
    docs_url=None if is_prod else "/docs",
    redoc_url=None if is_prod else "/redoc",
    openapi_url=None if is_prod else "/openapi.json"
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print("====== GLOBAL EXCEPTION HANDLER ======")
    print(f"Request: {request.method} {request.url}")
    print(f"Exception Type: {type(exc)}")
    print(f"Exception Message: {exc}")
    traceback.print_exc()
    print("======================================")
    return JSONResponse(
        status_code=500, content={"detail": "Terjadi kesalahan internal pada server"}
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    if not errors:
        return JSONResponse(status_code=422, content={"detail": "Format data tidak valid"})
        
    error = errors[0]
    error_type = error.get("type", "")
    loc = error.get("loc", [])
    field = str(loc[-1]) if loc else "Input"
    
    # Translasi field name agar lebih enak dibaca (opsional, tapi bagus)
    field_map = {
        "username": "Username",
        "password": "Password",
        "coins": "Koin",
        "gems": "Gems",
        "name": "Nama",
        "description": "Deskripsi"
    }
    field_name = field_map.get(field, field.capitalize())
    
    ctx = error.get("ctx", {})
    
    if error_type == "string_too_short":
        min_length = ctx.get("min_length", 0)
        msg = f"{field_name} minimal terdiri dari {min_length} karakter."
    elif error_type == "string_too_long":
        max_length = ctx.get("max_length", 0)
        msg = f"{field_name} maksimal terdiri dari {max_length} karakter."
    elif error_type == "string_pattern_mismatch":
        msg = f"Format {field_name} tidak valid. Hanya gunakan huruf dan angka."
    elif error_type == "missing":
        msg = f"{field_name} wajib diisi."
    elif error_type == "greater_than" or error_type == "greater_than_equal":
        limit = ctx.get("gt") or ctx.get("ge") or 0
        msg = f"Nilai {field_name} harus lebih dari {limit}."
    else:
        msg = f"Format {field_name} tidak valid."

    return JSONResponse(
        status_code=422,
        content={"detail": msg}
    )


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(shop.router)
app.include_router(arena.router)
app.include_router(leaderboard.router)
app.include_router(guild.router)
# Achievement removed
app.include_router(daily_quests.router)
app.include_router(admin.router)
