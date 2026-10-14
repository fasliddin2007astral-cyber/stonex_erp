from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import Base, engine
from .routers import auth, customers, finance, production, products, sales, stock, users


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Jadvallarni yaratish va boshlang'ich foydalanuvchilarni seed qilish
    Base.metadata.create_all(engine)
    try:
        from .seed import main as seed_db
        seed_db()
    except Exception as e:
        print(f"Boshlang'ich seed xabari: {e}")
    yield


app = FastAPI(title="STONEX ERP API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
                   allow_methods=["*"], allow_headers=["*"])

for r in (auth, users, products, stock, customers, sales, production, finance):
    app.include_router(r.router)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ping")
def ping():
    return {"status": "awake"}
