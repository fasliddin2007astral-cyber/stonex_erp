from datetime import date, datetime, time
from decimal import Decimal

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import models as m
from .. import roles
from ..database import get_db
from ..deps import require_roles
from ..schemas import ExpenseIn, ExpenseOut, FinanceSummary
from ..units import q2

router = APIRouter(tags=["finance"])
_admin = require_roles(roles.ADMIN)


def _sum(db: Session, col, *conds) -> Decimal:
    return q2(db.scalar(select(func.coalesce(func.sum(col), 0)).where(*conds)) or 0)


@router.get("/finance/summary", response_model=FinanceSummary)
def summary(date_from: date | None = None, date_to: date | None = None,
            db: Session = Depends(get_db), _: m.User = Depends(_admin)):
    def rng(col):
        c = []
        if date_from:
            c.append(col >= datetime.combine(date_from, time.min))
        if date_to:
            c.append(col <= datetime.combine(date_to, time.max))
        return c

    revenue = _sum(db, m.Sale.total, *rng(m.Sale.created_at))
    cogs = _sum(db, m.Sale.total_cost, *rng(m.Sale.created_at))
    cash = _sum(db, m.Payment.amount, *rng(m.Payment.created_at))
    expenses = _sum(db, m.Expense.amount, *rng(m.Expense.created_at))
    receivables = _sum(db, m.Sale.total - m.Sale.paid)  # umumiy, davrga bog'liq emas
    gross = revenue - cogs
    return FinanceSummary(revenue=revenue, cash_collected=cash, cogs=cogs, gross_profit=gross,
                          expenses=expenses, net_profit=gross - expenses, receivables=receivables)


@router.post("/expenses", response_model=ExpenseOut, status_code=201)
def add_expense(data: ExpenseIn, db: Session = Depends(get_db), admin: m.User = Depends(_admin)):
    e = m.Expense(category=data.category, amount=q2(data.amount), note=data.note,
                  created_by=admin.id)
    db.add(e)
    db.commit()
    return e


@router.get("/expenses", response_model=list[ExpenseOut])
def list_expenses(limit: int = 200, db: Session = Depends(get_db), _: m.User = Depends(_admin)):
    return db.scalars(select(m.Expense).order_by(m.Expense.id.desc()).limit(min(limit, 1000))).all()
