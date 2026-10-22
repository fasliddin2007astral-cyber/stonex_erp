from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from .. import models as m
from .. import roles
from ..database import get_db
from ..deps import require_roles
from ..schemas import PaymentIn, SaleIn, SaleOut
from ..services import sales as svc

router = APIRouter(prefix="/sales", tags=["sales"])
_sellers = require_roles(roles.ADMIN, roles.CASHIER)


def to_out(s: m.Sale) -> SaleOut:
    return SaleOut(id=s.id, customer=s.customer, cashier_id=s.cashier_id, total=s.total,
                   paid=s.paid, debt=s.debt, created_at=s.created_at, items=s.items)


@router.post("", response_model=SaleOut, status_code=201)
def create(data: SaleIn, db: Session = Depends(get_db), user: m.User = Depends(_sellers)):
    return to_out(svc.create_sale(db, user, data))


@router.get("", response_model=list[SaleOut])
def list_sales(limit: int = 100, db: Session = Depends(get_db), user: m.User = Depends(_sellers)):
    stmt = (
        select(m.Sale)
        .options(selectinload(m.Sale.items), selectinload(m.Sale.customer))
        .order_by(m.Sale.id.desc())
        .limit(min(limit, 500))
    )
    if user.role != roles.ADMIN:  # kassir faqat o'z savdolarini ko'radi
        stmt = stmt.where(m.Sale.cashier_id == user.id)
    return [to_out(s) for s in db.scalars(stmt).all()]


@router.get("/debts", response_model=list[SaleOut])
def debts(db: Session = Depends(get_db), _: m.User = Depends(_sellers)):
    stmt = (
        select(m.Sale)
        .options(selectinload(m.Sale.items), selectinload(m.Sale.customer))
        .where(m.Sale.paid < m.Sale.total)
        .order_by(m.Sale.id)
    )
    return [to_out(s) for s in db.scalars(stmt).all()]


@router.get("/{sale_id}", response_model=SaleOut)
def get_sale(sale_id: int, db: Session = Depends(get_db), user: m.User = Depends(_sellers)):
    s = db.get(m.Sale, sale_id)
    if s is None or (user.role != roles.ADMIN and s.cashier_id != user.id):
        raise HTTPException(404, "Savdo topilmadi")
    return to_out(s)


@router.post("/{sale_id}/payments", response_model=SaleOut)
def pay(sale_id: int, data: PaymentIn, db: Session = Depends(get_db),
        user: m.User = Depends(_sellers)):
    return to_out(svc.add_payment(db, user, sale_id, data.amount, data.method))
