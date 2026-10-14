from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- auth / users ----------
class LoginIn(BaseModel):
    username: str
    password: str
    role: str | None = None  # kirish ekranida tanlangan rol; backend haqiqiy rolni tekshiradi


class UserOut(ORM):
    id: int
    username: str
    full_name: str
    role: str
    is_active: bool


class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    full_name: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=8, max_length=128)
    role: Literal["admin", "kassir", "ishchi"]


class UserUpdate(BaseModel):
    full_name: str | None = None
    password: str | None = Field(default=None, min_length=8, max_length=128)
    role: Literal["admin", "kassir", "ishchi"] | None = None
    is_active: bool | None = None


# ---------- products ----------
class ProductIn(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    sku: str | None = None
    qr_code: str | None = None
    unit: str = Field(min_length=1, max_length=16)
    dona_m2: Decimal | None = Field(default=None, gt=0)
    price: Decimal = Field(ge=0)
    cost_price: Decimal = Field(default=Decimal(0), ge=0)
    initial_stock: Decimal = Field(default=Decimal(0), ge=0)  # faqat yaratishda


class ProductUpdate(BaseModel):
    name: str | None = None
    sku: str | None = None
    qr_code: str | None = None
    unit: str | None = None
    dona_m2: Decimal | None = Field(default=None, gt=0)
    price: Decimal | None = Field(default=None, ge=0)
    cost_price: Decimal | None = Field(default=None, ge=0)


class ProductOut(BaseModel):
    id: int
    name: str
    sku: str | None
    qr_code: str | None
    unit: str
    dona_m2: Decimal | None
    price: Decimal
    cost_price: Decimal
    is_active: bool
    stock: Decimal


# ---------- stock ----------
class PurchaseIn(BaseModel):
    product_id: int
    quantity: Decimal = Field(gt=0)
    unit: Literal["base", "dona"] = "base"
    unit_cost: Decimal = Field(ge=0)  # bazaviy birlik uchun xarid narxi
    note: str | None = None


class AdjustIn(BaseModel):
    product_id: int
    delta: Decimal  # +/- (bazaviy birlikda)
    note: str = Field(min_length=1)


class MovementOut(ORM):
    id: int
    product_id: int
    qty_delta: Decimal
    kind: str
    ref_type: str | None
    ref_id: int | None
    note: str | None
    created_at: datetime


# ---------- customers ----------
class CustomerIn(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    phone: str | None = None


class CustomerOut(ORM):
    id: int
    name: str
    phone: str | None


# ---------- sales ----------
class SaleItemIn(BaseModel):
    product_id: int
    quantity: Decimal = Field(gt=0)
    unit: Literal["base", "dona"] = "base"


class SaleIn(BaseModel):
    items: list[SaleItemIn] = Field(min_length=1)
    paid_amount: Decimal = Field(ge=0)
    customer_id: int | None = None
    customer_name: str | None = None
    customer_phone: str | None = None


class SaleItemOut(ORM):
    product_id: int
    product_name: str
    quantity: Decimal
    unit_price: Decimal
    line_total: Decimal


class SaleOut(BaseModel):
    id: int
    customer: CustomerOut | None
    cashier_id: int
    total: Decimal
    paid: Decimal
    debt: Decimal
    created_at: datetime
    items: list[SaleItemOut]


class PaymentIn(BaseModel):
    amount: Decimal = Field(gt=0)
    method: str = "cash"


# ---------- production ----------
class TaskCreate(BaseModel):
    product_id: int
    assigned_to: int
    planned_qty: Decimal = Field(gt=0)
    note: str | None = None


class TaskReport(BaseModel):
    produced_qty: Decimal = Field(gt=0)  # shu hisobotda qo'shilgan miqdor


class TaskOut(BaseModel):
    id: int
    product_id: int
    product_name: str
    unit: str
    assigned_to: int
    worker_name: str
    planned_qty: Decimal
    produced_qty: Decimal
    status: str
    note: str | None


# ---------- finance ----------
class ExpenseIn(BaseModel):
    category: str = Field(min_length=1, max_length=32)
    amount: Decimal = Field(gt=0)
    note: str | None = None


class ExpenseOut(ORM):
    id: int
    category: str
    amount: Decimal
    note: str | None
    created_at: datetime


class FinanceSummary(BaseModel):
    revenue: Decimal  # savdo summasi
    cash_collected: Decimal  # kassaga tushgan haqiqiy pul
    cogs: Decimal  # sotilgan tovar tannarxi
    gross_profit: Decimal
    expenses: Decimal
    net_profit: Decimal
    receivables: Decimal  # umumiy qarzdorlik (nasiya)
