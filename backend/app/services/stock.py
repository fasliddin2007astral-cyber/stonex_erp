from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import StockMovement
from ..units import q3


def get_stock(db: Session, product_id: int) -> Decimal:
    total = db.scalar(
        select(func.coalesce(func.sum(StockMovement.qty_delta), 0)).where(
            StockMovement.product_id == product_id
        )
    )
    return q3(total or 0)


def stock_map(db: Session) -> dict[int, Decimal]:
    rows = db.execute(
        select(StockMovement.product_id, func.sum(StockMovement.qty_delta)).group_by(
            StockMovement.product_id
        )
    ).all()
    return {pid: q3(total or 0) for pid, total in rows}


def add_movement(db: Session, *, product_id, qty_delta, kind, ref_type=None, ref_id=None,
                 note=None, user_id=None) -> StockMovement:
    mv = StockMovement(product_id=product_id, qty_delta=q3(qty_delta), kind=kind,
                       ref_type=ref_type, ref_id=ref_id, note=note, created_by=user_id)
    db.add(mv)
    return mv
