from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models as m
from .. import roles
from ..database import get_db
from ..deps import require_roles
from ..schemas import AdjustIn, MovementOut, PurchaseIn
from ..services.sales import to_base_qty
from ..services.stock import add_movement, get_stock
from ..units import q2

router = APIRouter(prefix="/stock", tags=["stock"])
_admin = require_roles(roles.ADMIN)


@router.get("/movements", response_model=list[MovementOut])
def movements(product_id: int | None = None, limit: int = 200, db: Session = Depends(get_db),
              _: m.User = Depends(_admin)):
    stmt = select(m.StockMovement).order_by(m.StockMovement.id.desc()).limit(min(limit, 1000))
    if product_id:
        stmt = stmt.where(m.StockMovement.product_id == product_id)
    return db.scalars(stmt).all()


@router.post("/purchase", response_model=MovementOut, status_code=201)
def purchase(data: PurchaseIn, db: Session = Depends(get_db), admin: m.User = Depends(_admin)):
    """Xarid kirimi. Tannarx — o'rtacha tortilgan (weighted average) usulida yangilanadi."""
    p = db.get(m.Product, data.product_id, with_for_update=True)
    if p is None or not p.is_active:
        raise HTTPException(404, "Mahsulot topilmadi")
    qty = to_base_qty(p, data.quantity, data.unit)
    old_stock = max(get_stock(db, p.id), Decimal(0))
    new_stock = old_stock + qty
    p.cost_price = q2((old_stock * p.cost_price + qty * data.unit_cost) / new_stock)
    mv = add_movement(db, product_id=p.id, qty_delta=qty, kind=m.MV_PURCHASE, note=data.note,
                      user_id=admin.id)
    db.commit()
    return mv


@router.post("/adjust", response_model=MovementOut, status_code=201)
def adjust(data: AdjustIn, db: Session = Depends(get_db), admin: m.User = Depends(_admin)):
    p = db.get(m.Product, data.product_id, with_for_update=True)
    if p is None:
        raise HTTPException(404, "Mahsulot topilmadi")
    if data.delta == 0:
        raise HTTPException(400, "O'zgarish 0 bo'lmasligi kerak")
    if get_stock(db, p.id) + data.delta < 0:
        raise HTTPException(400, "Qoldiq manfiy bo'lib qoladi")
    mv = add_movement(db, product_id=p.id, qty_delta=data.delta, kind=m.MV_ADJUST,
                      note=data.note, user_id=admin.id)
    db.commit()
    return mv
