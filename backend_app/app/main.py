from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import traceback

from app.core.database import startup_db_migration
from app.routers import auth, shop, arena

app = FastAPI()


@app.on_event("startup")
def on_startup():
    startup_db_migration()


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


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(shop.router)
app.include_router(arena.router)
