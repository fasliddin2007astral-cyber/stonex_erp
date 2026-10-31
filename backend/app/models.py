"""stone_erp jadvallari.

Ombor qoldig'i alohida ustunda saqlanmaydi: u StockMovement yig'indisidan hisoblanadi.
Savdo, xarid, ishlab chiqarish, tuzatish — hammasi bitta harakatlar tizimi orqali o'tadi.
"""
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base

MONEY = Numeric(14, 2)
QTY = Numeric(14, 3)

# Ombor harakati turlari
MV_OPENING = "opening"
MV_PURCHASE = "purchase"
MV_SALE = "sale"
MV_PRODUCTION = "production"
MV_RETURN = "return"
MV_ADJUST = "adjustment"


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(128))
    password_hash: Mapped[str] = mapped_column(String(256))
    role: Mapped[str] = mapped_column(String(16))
    salary: Mapped[Decimal] = mapped_column(MONEY, default=Decimal(0))
    salary_type: Mapped[str] = mapped_column(String(16), default="monthly")  # monthly, daily, hourly
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Attendance(Base):
    __tablename__ = "attendance"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    date: Mapped[str] = mapped_column(String(10), index=True)  # YYYY-MM-DD
    check_in: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    check_out: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    worked_hours: Mapped[Decimal] = mapped_column(QTY, default=Decimal(0))
    status: Mapped[str] = mapped_column(String(16), default="present")  # present, late, absent, half_day
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    user: Mapped["User"] = relationship(lazy="joined")


class Product(Base):
    __tablename__ = "products"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(128), index=True)
    sku: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True)
    qr_code: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)
    unit: Mapped[str] = mapped_column(String(16))  # m2, dona, kg, m ...
    dona_m2: Mapped[Decimal | None] = mapped_column(QTY, nullable=True)  # faqat toshlar: 0.25
    thickness: Mapped[Decimal | None] = mapped_column(QTY, nullable=True)  # tosh qalinligi (sm, masalan: 2.0)
    price: Mapped[Decimal] = mapped_column(MONEY, default=0)  # bazaviy birlik uchun sotuv narxi
    cost_price: Mapped[Decimal] = mapped_column(MONEY, default=0)  # o'rtacha tannarx
    sort: Mapped[str | None] = mapped_column(String(16), nullable=True)  # 1, 1.5, 2, 3, oliy
    has_sorts: Mapped[bool] = mapped_column(Boolean, default=False)  # 1, 1.5, 2 sortlari mavjudmi
    price_sort1: Mapped[Decimal | None] = mapped_column(MONEY, nullable=True)  # 1-sort narxi
    price_sort1_5: Mapped[Decimal | None] = mapped_column(MONEY, nullable=True)  # 1.5-sort narxi
    price_sort2: Mapped[Decimal | None] = mapped_column(MONEY, nullable=True)  # 2-sort narxi
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class StockMovement(Base):
    __tablename__ = "stock_movements"
    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"), index=True)
    qty_delta: Mapped[Decimal] = mapped_column(QTY)  # kirim +, chiqim -
    kind: Mapped[str] = mapped_column(String(16))
    ref_type: Mapped[str | None] = mapped_column(String(16), nullable=True)
    ref_id: Mapped[int | None] = mapped_column(nullable=True)
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)

    product: Mapped["Product"] = relationship()
    user: Mapped["User | None"] = relationship()


class Customer(Base):
    __tablename__ = "customers"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(128), index=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    passport: Mapped[str | None] = mapped_column(String(64), nullable=True)
    photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    sales: Mapped[list["Sale"]] = relationship(back_populates="customer")


class Sale(Base):
    __tablename__ = "sales"
    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int | None] = mapped_column(ForeignKey("customers.id"), nullable=True)
    cashier_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    total: Mapped[Decimal] = mapped_column(MONEY)  # savdo summasi
    total_cost: Mapped[Decimal] = mapped_column(MONEY)  # tannarx (sotilgan paytdagi)
    paid: Mapped[Decimal] = mapped_column(MONEY, default=0)  # to'lovlar yig'indisi (kesh)
    status: Mapped[str] = mapped_column(String(20), default="completed")  # completed | order | cancelled
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)  # buyurtma izohi / muddat
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)

    items: Mapped[list["SaleItem"]] = relationship(cascade="all, delete-orphan")
    payments: Mapped[list["Payment"]] = relationship(cascade="all, delete-orphan")
    customer: Mapped["Customer | None"] = relationship(back_populates="sales")
    cashier: Mapped["User"] = relationship()

    @property
    def debt(self) -> Decimal:
        return self.total - self.paid


class SaleItem(Base):
    __tablename__ = "sale_items"
    id: Mapped[int] = mapped_column(primary_key=True)
    sale_id: Mapped[int] = mapped_column(ForeignKey("sales.id"), index=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    product_name: Mapped[str] = mapped_column(String(128))
    quantity: Mapped[Decimal] = mapped_column(QTY)  # bazaviy birlikda
    unit_price: Mapped[Decimal] = mapped_column(MONEY)
    unit_cost: Mapped[Decimal] = mapped_column(MONEY)
    line_total: Mapped[Decimal] = mapped_column(MONEY)


class Payment(Base):
    """Kassaga tushgan pul. Savdo summasi bilan aralashtirilmaydi."""
    __tablename__ = "payments"
    id: Mapped[int] = mapped_column(primary_key=True)
    sale_id: Mapped[int] = mapped_column(ForeignKey("sales.id"), index=True)
    amount: Mapped[Decimal] = mapped_column(MONEY)
    method: Mapped[str] = mapped_column(String(16), default="cash")
    received_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)


class Expense(Base):
    __tablename__ = "expenses"
    id: Mapped[int] = mapped_column(primary_key=True)
    category: Mapped[str] = mapped_column(String(32))  # salary, rent, utilities, other ...
    amount: Mapped[Decimal] = mapped_column(MONEY)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)


class ProductionTask(Base):
    __tablename__ = "production_tasks"
    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    assigned_to: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    planned_qty: Mapped[Decimal] = mapped_column(QTY)
    produced_qty: Mapped[Decimal] = mapped_column(QTY, default=0)
    status: Mapped[str] = mapped_column(String(16), default="open")  # open | done
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    product: Mapped["Product"] = relationship()
    worker: Mapped["User"] = relationship()


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(128))
    message: Mapped[str] = mapped_column(Text)
    kind: Mapped[str] = mapped_column(String(32), default="system")  # warning, payment, sale, production, system
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)

