"""Boshlang'ich ma'lumotlar:  python -m app.seed
Admin akkaunti (.env dagi ADMIN_*) va namunaviy mahsulotlar yaratiladi. Qayta ishga tushirsa
mavjudlarini o'zgartirmaydi."""
from decimal import Decimal

from sqlalchemy import select

from . import models as m
from . import roles
from .config import settings
from .database import Base, SessionLocal, engine
from .security import hash_password
from .services.stock import add_movement

SAMPLE = [  # nomi, birlik, dona_m2, narx, tannarx, boshlang'ich qoldiq
    ("Angola", "m2", "0.25", 180000, 120000, 200),
    ("Miramir", "m2", "0.25", 170000, 110000, 150),
    ("Tan Brown", "m2", "0.25", 190000, 130000, 120),
    ("Metalogranit", "m2", None, 150000, 95000, 80),
    ("Kley", "dona", None, 45000, 30000, 100),
    ("Sim", "m", None, 12000, 7000, 500),
    ("Disk", "dona", None, 250000, 170000, 30),
]


def main() -> None:
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        if not db.scalar(select(m.User).where(m.User.username == settings.admin_username)):
            db.add(m.User(username=settings.admin_username, full_name="Xo'jayin",
                          role=roles.ADMIN, password_hash=hash_password(settings.admin_password)))
            print(f"Admin yaratildi: {settings.admin_username}")
        if not db.scalar(select(m.User).where(m.User.username == "kassir")):
            db.add(m.User(username="kassir", full_name="Kassir Aziz",
                          role=roles.CASHIER, password_hash=hash_password("kassir123")))
            print("Kassir yaratildi: kassir")
        if not db.scalar(select(m.User).where(m.User.username == "ishchi")):
            db.add(m.User(username="ishchi", full_name="Ishchi Bobur",
                          role=roles.WORKER, password_hash=hash_password("ishchi123")))
            print("Ishchi yaratildi: ishchi")
        for name, unit, dona, price, cost, stock in SAMPLE:
            if db.scalar(select(m.Product).where(m.Product.name == name)):
                continue
            p = m.Product(name=name, unit=unit, dona_m2=Decimal(dona) if dona else None,
                          price=price, cost_price=cost, qr_code=f"STX-{name.upper().replace(' ', '')}")
            db.add(p)
            db.flush()
            add_movement(db, product_id=p.id, qty_delta=stock, kind=m.MV_OPENING,
                         note="Boshlang'ich qoldiq")
        db.commit()
    print("Seed tayyor.")


if __name__ == "__main__":
    main()
