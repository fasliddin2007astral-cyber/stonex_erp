from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import settings
from .database import Base, engine, ensure_migrations
from .routers import (
    attendance,
    auth,
    customers,
    finance,
    notifications,
    production,
    products,
    sales,
    stock,
    users,
)

uploads_dir = Path(__file__).resolve().parent.parent / "uploads"
uploads_dir.mkdir(parents=True, exist_ok=True)


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Jadvallarni yaratish va yangi ustunlarni migratsiya qilish
    Base.metadata.create_all(engine)
    try:
        ensure_migrations()
    except Exception as e:
        print(f"Migratsiya xabari: {e}")
    try:
        from .seed import main as seed_db
        seed_db()
    except Exception as e:
        print(f"Boshlang'ich seed xabari: {e}")
    yield


app = FastAPI(title="NTM ERP API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
                   allow_methods=["*"], allow_headers=["*"])

app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

for r in (auth, users, products, stock, customers, sales, production, finance, notifications, attendance):
    app.include_router(r.router)


@app.get("/")
def root():
    return {
        "title": "NTM ERP API (Namuna Tosh Markazi)",
        "status": "online",
        "docs": "/docs",
        "ping": "/ping",
    }


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ping")
def ping():
    return {"status": "awake"}


@app.get("/setup-db")
def setup_db():
    try:
        Base.metadata.create_all(engine)
        from .seed import main as seed_db
        seed_db()
        return {
            "status": "success",
            "message": "Baza va namunaviy foydalanuvchilar muvaffaqiyatli tayyorlandi!",
            "accounts": {
                "admin": settings.admin_password,
                "kassir": "kassir123",
                "ishchi": "ishchi123",
            },
        }
    except Exception as e:
        import traceback
        return {
            "status": "error",
            "error": str(e),
            "trace": traceback.format_exc(),
        }

