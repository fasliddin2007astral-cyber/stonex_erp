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
        admin = db.scalar(select(m.User).where(m.User.username == settings.admin_username))
        if not admin:
            db.add(m.User(username=settings.admin_username, full_name="Xo'jayin",
                          role=roles.ADMIN, password_hash=hash_password(settings.admin_password)))
            print(f"Admin yaratildi: {settings.admin_username}")
        else:
            admin.password_hash = hash_password(settings.admin_password)
            db.commit()
            print(f"Admin paroli yangilandi: {settings.admin_username}")
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

        # Namunaviy bildirishnomalar
        SAMPLE_NOTIFICATIONS = [
            ("Ombor ogohlantirishi", "Metalogranit zaxirasi 80 m² qoldi. Yangi partiya xaridini rejalashtiring.", "warning"),
            ("Qarz to‘lovi qabul qilindi", "Mijoz Akmal aka 300 000 so‘m qarzini naqd to‘ladi.", "payment"),
            ("Yangi savdo amalga oshirildi", "Kassir Aziz tomonidan 1 850 000 so‘mlik savdo qilindi.", "sale"),
            ("Ishlab chiqarish topshirig‘i", "Ishchi Bobur 50 m² Angola toshini qayta ishlashni yakunladi.", "production"),
            ("Tizim ma’lumoti", "NTM — Namuna Tosh Markazi tizimi barcha xodimlar va modullar uchun faol holatda.", "system"),
        ]
        for title, msg, kind in SAMPLE_NOTIFICATIONS:
            if not db.scalar(select(m.Notification).where(m.Notification.title == title)):
                db.add(m.Notification(title=title, message=msg, kind=kind))

        # Namunaviy savdolar
        if not db.scalar(select(m.Sale).limit(1)):
            kassir = db.scalar(select(m.User).where(m.User.username == "kassir"))
            if kassir:
                from datetime import datetime, timedelta
                from .schemas import SaleIn, SaleItemIn
                from .services import sales as svc_sales
                now = datetime.utcnow()
                prods = {p.name: p for p in db.scalars(select(m.Product)).all()}
                sales_to_seed = [
                    (now - timedelta(days=6), [("Angola", 10)], 1800000, "Sardor Qodirov", "+998 90 999 11 22"),
                    (now - timedelta(days=4), [("Kley", 20)], 900000, "Farhod Usta", "+998 91 888 22 33"),
                    (now - timedelta(days=3), [("Metalogranit", 10)], 1000000, "Javohir Toshkent", "+998 93 777 33 44"),
                    (now - timedelta(days=2), [("Disk", 2), ("Sim", 1)], 512000, "Botir Qurilish", "+998 94 666 44 55"),
                    (now - timedelta(days=1), [("Miramir", 5)], 600000, "Akmal aka", "+998 90 123 45 67"),
                    (now, [("Tan Brown", 10)], 1900000, "Sobirjon", "+998 99 555 12 34"),
                ]
                for sale_time, items, paid_val, c_name, c_phone in sales_to_seed:
                    s_items = []
                    for p_name, qty in items:
                        if p_name in prods:
                            s_items.append(SaleItemIn(product_id=prods[p_name].id, quantity=Decimal(qty), unit="base"))
                    if s_items:
                        try:
                            s_obj = svc_sales.create_sale(db, kassir, SaleIn(
                                items=s_items, paid_amount=Decimal(paid_val),
                                customer_name=c_name, customer_phone=c_phone
                            ))
                            s_obj.created_at = sale_time
                            db.flush()
                        except Exception as e:
                            print(f"Sample sale error: {e}")

        db.commit()
    print("Seed tayyor.")


if __name__ == "__main__":
    main()
