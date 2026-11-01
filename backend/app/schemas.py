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
    salary: Decimal = Decimal(0)
    salary_type: str = "monthly"
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
    salary: Decimal = Field(default=Decimal(0), ge=0)
    salary_type: Literal["monthly", "daily", "hourly"] = "monthly"


class UserUpdate(BaseModel):
    full_name: str | None = None
    password: str | None = Field(default=None, min_length=8, max_length=128)
    role: Literal["admin", "kassir", "ishchi"] | None = None
    salary: Decimal | None = Field(default=None, ge=0)
    salary_type: Literal["monthly", "daily", "hourly"] | None = None
    is_active: bool | None = None


# ---------- attendance & payroll ----------
class AttendanceCheckIn(BaseModel):
    user_id: int
    date: str | None = None  # YYYY-MM-DD
    check_in: datetime | None = None
    note: str | None = None


class AttendanceCheckOut(BaseModel):
    user_id: int
    date: str | None = None  # YYYY-MM-DD
    check_out: datetime | None = None
    note: str | None = None


class AttendanceRecordIn(BaseModel):
    id: int | None = None
    user_id: int
    date: str  # YYYY-MM-DD
    check_in: datetime | None = None
    check_out: datetime | None = None
    worked_hours: Decimal = Decimal(0)
    status: Literal["present", "late", "absent", "half_day"] = "present"
    note: str | None = None


class AttendanceOut(ORM):
    id: int
    user_id: int
    user_name: str | None = None
    date: str
    check_in: datetime | None = None
    check_out: datetime | None = None
    worked_hours: Decimal = Decimal(0)
    status: str
    note: str | None = None


class SalaryReportItem(BaseModel):
    user_id: int
    full_name: str
    role: str
    base_salary: Decimal
    salary_type: str
    days_worked: int
    hours_worked: Decimal
    days_late: int
    calculated_salary: Decimal
    bonus: Decimal = Decimal(0)
    deduction: Decimal = Decimal(0)
    net_salary: Decimal
    is_paid: bool = False


# ---------- products ----------
class ProductIn(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: str | None = None
    sku: str | None = None
    qr_code: str | None = None
    unit: str = Field(min_length=1, max_length=16)
    dona_m2: Decimal | None = Field(default=None, gt=0)
    thickness: Decimal | None = Field(default=None, gt=0)
    tile_length: Decimal | None = Field(default=None, gt=0)
    tile_width: Decimal | None = Field(default=None, gt=0)
    box_pieces: int | None = Field(default=None, gt=0)
    box_m2: Decimal | None = Field(default=None, gt=0)
    min_stock: Decimal | None = Field(default=Decimal(15), ge=0)
    price: Decimal = Field(ge=0)
    cost_price: Decimal = Field(default=Decimal(0), ge=0)
    sort: str | None = None
    has_sorts: bool = False
    color: str | None = None
    price_sort1: Decimal | None = Field(default=None, ge=0)
    price_sort1_5: Decimal | None = Field(default=None, ge=0)
    price_sort2: Decimal | None = Field(default=None, ge=0)
    image_url: str | None = None
    initial_stock: Decimal = Field(default=Decimal(0), ge=0)  # faqat yaratishda


class ProductUpdate(BaseModel):
    name: str | None = None
    category: str | None = None
    sku: str | None = None
    qr_code: str | None = None
    unit: str | None = None
    dona_m2: Decimal | None = Field(default=None, gt=0)
    thickness: Decimal | None = Field(default=None, gt=0)
    tile_length: Decimal | None = Field(default=None, gt=0)
    tile_width: Decimal | None = Field(default=None, gt=0)
    box_pieces: int | None = Field(default=None, gt=0)
    box_m2: Decimal | None = Field(default=None, gt=0)
    min_stock: Decimal | None = Field(default=None, ge=0)
    price: Decimal | None = Field(default=None, ge=0)
    cost_price: Decimal | None = Field(default=None, ge=0)
    sort: str | None = None
    has_sorts: bool | None = None
    color: str | None = None
    price_sort1: Decimal | None = Field(default=None, ge=0)
    price_sort1_5: Decimal | None = Field(default=None, ge=0)
    price_sort2: Decimal | None = Field(default=None, ge=0)
    image_url: str | None = None


class ProductOut(BaseModel):
    id: int
    name: str
    category: str | None = None
    sku: str | None
    qr_code: str | None
    unit: str
    dona_m2: Decimal | None
    thickness: Decimal | None = None
    tile_length: Decimal | None = None
    tile_width: Decimal | None = None
    box_pieces: int | None = None
    box_m2: Decimal | None = None
    min_stock: Decimal | None = Decimal(15)
    price: Decimal
    cost_price: Decimal
    sort: str | None = None
    has_sorts: bool = False
    color: str | None = None
    price_sort1: Decimal | None = None
    price_sort1_5: Decimal | None = None
    price_sort2: Decimal | None = None
    image_url: str | None = None
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
    product_name: str | None = None
    qty_delta: Decimal
    kind: str
    ref_type: str | None = None
    ref_id: int | None = None
    note: str | None = None
    created_by_name: str | None = None
    created_at: datetime


# ---------- customers ----------
class CustomerIn(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    phone: str | None = None
    passport: str | None = None
    photo_url: str | None = None


class CustomerOut(ORM):
    id: int
    name: str
    phone: str | None = None
    passport: str | None = None
    photo_url: str | None = None
    created_at: datetime | None = None
    total_spent: Decimal | None = None
    total_debt: Decimal | None = None
    sales_count: int | None = None


# ---------- sales ----------
class SaleItemIn(BaseModel):
    product_id: int
    quantity: Decimal = Field(gt=0)
    unit: Literal["base", "dona"] = "base"
    custom_name: str | None = None
    price: Decimal | None = None
    sort: str | None = None
    color: str | None = None


class SaleIn(BaseModel):
    items: list[SaleItemIn] = Field(min_length=1)
    paid_amount: Decimal = Field(ge=0)
    currency_rate: Decimal | None = None
    paid_uzs: Decimal | None = None
    paid_usd: Decimal | None = None
    customer_id: int | None = None
    customer_name: str | None = None
    customer_phone: str | None = None
    customer_passport: str | None = None
    customer_photo_url: str | None = None
    status: str = "completed"  # completed | order
    note: str | None = None


class SaleReturnItemIn(BaseModel):
    product_id: int
    quantity: Decimal = Field(gt=0)


class SaleReturnIn(BaseModel):
    items: list[SaleReturnItemIn] = Field(min_length=1)
    reason: str | None = None


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
    cashier_name: str | None = None
    total: Decimal
    paid: Decimal
    debt: Decimal
    currency_rate: Decimal | None = None
    paid_uzs: Decimal | None = None
    paid_usd: Decimal | None = None
    status: str = "completed"
    note: str | None = None
    created_at: datetime
    items: list[SaleItemOut]
    payment_method: str | None = None


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


# ---------- notifications ----------
class NotificationIn(BaseModel):
    title: str = Field(min_length=1, max_length=128)
    message: str = Field(min_length=1)
    kind: str = Field(default="system")  # warning | payment | sale | production | system


class NotificationOut(ORM):
    id: int
    title: str
    message: str
    kind: str
    is_read: bool
    created_at: datetime

