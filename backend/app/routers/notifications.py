from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from .. import models as m
from ..database import get_db
from ..deps import get_current_user
from ..schemas import NotificationIn, NotificationOut

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationOut])
def list_notifications(
    limit: int = 50,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    stmt = (
        select(m.Notification)
        .order_by(m.Notification.id.desc())
        .limit(min(limit, 100))
    )
    return list(db.scalars(stmt).all())


@router.post("", response_model=NotificationOut, status_code=201)
def create_notification(
    data: NotificationIn,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    notif = m.Notification(title=data.title, message=data.message, kind=data.kind)
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif


@router.put("/{notif_id}/read", response_model=NotificationOut)
def mark_read(
    notif_id: int,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    notif = db.get(m.Notification, notif_id)
    if notif is None:
        raise HTTPException(404, "Bildirishnoma topilmadi")
    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif


@router.put("/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    db.execute(update(m.Notification).values(is_read=True))
    db.commit()
    return {"status": "ok"}

