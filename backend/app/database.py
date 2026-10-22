import ssl

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import settings

_connect_args: dict = {}
if settings.database_url.startswith("sqlite"):
    _connect_args["check_same_thread"] = False
elif "aivencloud.com" in settings.database_url or "ssl" in settings.database_url.lower():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    _connect_args["ssl"] = ctx

engine = create_engine(settings.database_url, pool_pre_ping=True, connect_args=_connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_migrations():
    """Jadvallarga yangi ustunlarni xavfsiz qo'shish."""
    from sqlalchemy import inspect, text
    inspector = inspect(engine)
    if "products" in inspector.get_table_names():
        columns = [c["name"] for c in inspector.get_columns("products")]
        with engine.begin() as conn:
            if "image_url" not in columns:
                conn.execute(text("ALTER TABLE products ADD COLUMN image_url TEXT NULL"))

