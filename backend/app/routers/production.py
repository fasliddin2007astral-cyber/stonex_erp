from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models as m
from .. import roles
from ..database import get_db
from ..deps import require_roles
from ..schemas import TaskCreate, TaskOut, TaskReport
from ..services.stock import add_movement
from ..units import q3

router = APIRouter(prefix="/production", tags=["production"])
_prod = require_roles(roles.ADMIN, roles.WORKER)


def to_out(t: m.ProductionTask) -> TaskOut:
    return TaskOut(id=t.id, product_id=t.product_id, product_name=t.product.name,
                   unit=t.product.unit, assigned_to=t.assigned_to, worker_name=t.worker.full_name,
                   planned_qty=t.planned_qty, produced_qty=t.produced_qty, status=t.status,
                   note=t.note)


@router.get("", response_model=list[TaskOut])
def list_tasks(db: Session = Depends(get_db), user: m.User = Depends(_prod)):
    stmt = select(m.ProductionTask).order_by(m.ProductionTask.id.desc()).limit(300)
    if user.role == roles.WORKER:  # ishchi faqat o'z topshiriqlarini ko'radi
        stmt = stmt.where(m.ProductionTask.assigned_to == user.id)
    return [to_out(t) for t in db.scalars(stmt).all()]


@router.post("", response_model=TaskOut, status_code=201)
def create_task(data: TaskCreate, db: Session = Depends(get_db),
                _: m.User = Depends(require_roles(roles.ADMIN))):
    if db.get(m.Product, data.product_id) is None:
        raise HTTPException(404, "Mahsulot topilmadi")
    worker = db.get(m.User, data.assigned_to)
    if worker is None or worker.role != roles.WORKER or not worker.is_active:
        raise HTTPException(400, "Topshiriq faqat faol ishchiga beriladi")
    t = m.ProductionTask(product_id=data.product_id, assigned_to=data.assigned_to,
                         planned_qty=data.planned_qty, note=data.note)
    db.add(t)
    db.commit()
    db.refresh(t)
    return to_out(t)


@router.post("/{task_id}/report", response_model=TaskOut)
def report(task_id: int, data: TaskReport, db: Session = Depends(get_db),
           user: m.User = Depends(_prod)):
    """Bajarilgan ishni qayd etadi va tayyor mahsulotni omborga kirim qiladi."""
    t = db.get(m.ProductionTask, task_id, with_for_update=True)
    if t is None or (user.role == roles.WORKER and t.assigned_to != user.id):
        raise HTTPException(404, "Topshiriq topilmadi")
    if t.status == "done":
        raise HTTPException(400, "Topshiriq yopilgan")
    qty = q3(data.produced_qty)
    t.produced_qty = t.produced_qty + qty
    if t.produced_qty >= t.planned_qty:
        t.status = "done"
    add_movement(db, product_id=t.product_id, qty_delta=qty, kind=m.MV_PRODUCTION,
                 ref_type="task", ref_id=t.id, user_id=user.id)
    db.commit()
    db.refresh(t)
    return to_out(t)
