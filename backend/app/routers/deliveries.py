from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session, selectinload

from .. import models as m
from ..database import get_db
from ..deps import get_current_user
from ..schemas import DeliveryCreate, DeliveryOut, DeliveryStatusUpdate, DeliveryUpdate

router = APIRouter(prefix="/deliveries", tags=["deliveries"])


@router.get("", response_model=list[DeliveryOut])
def list_deliveries(
    status: str | None = None,
    query: str | None = None,
    driver_id: int | None = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: m.User = Depends(get_current_user),
):
    stmt = (
        select(m.Delivery)
        .options(selectinload(m.Delivery.items))
        .order_by(m.Delivery.id.desc())
        .limit(min(limit, 200))
    )
    # Agar haydovchi kirgan bo'lsa, o'zining buyurtmalari va barchaga ochiq (hali olinmagan) buyurtmalar chiqadi
    if current_user.role == "haydovchi":
        stmt = stmt.where(
            or_(
                m.Delivery.driver_id == current_user.id,
                m.Delivery.driver_name.ilike(f"%{current_user.full_name}%"),
                (m.Delivery.driver_phone == current_user.username) if current_user.username else False,
                # Ochiq buyurtmalar (barcha haydovchilar olishi mumkin)
                and_(m.Delivery.driver_id.is_(None), m.Delivery.status == "loading"),
                and_(m.Delivery.driver_name.ilike("%Ochiq%"), m.Delivery.status == "loading"),
            )
        )
    elif driver_id:
        stmt = stmt.where(m.Delivery.driver_id == driver_id)

    if status and status != "all":
        stmt = stmt.where(m.Delivery.status == status)
    if query:
        q = f"%{query.strip()}%"
        stmt = stmt.where(
            or_(
                m.Delivery.vehicle_number.ilike(q),
                m.Delivery.driver_name.ilike(q),
                m.Delivery.recipient_name.ilike(q),
                m.Delivery.destination_address.ilike(q),
            )
        )
    return list(db.scalars(stmt).all())


@router.get("/{delivery_id}", response_model=DeliveryOut)
def get_delivery(
    delivery_id: int,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    stmt = (
        select(m.Delivery)
        .options(selectinload(m.Delivery.items))
        .where(m.Delivery.id == delivery_id)
    )
    delivery = db.scalars(stmt).first()
    if delivery is None:
        raise HTTPException(404, "Yetkazib berish yozuvi topilmadi")
    return delivery


@router.post("", response_model=DeliveryOut, status_code=201)
def create_delivery(
    data: DeliveryCreate,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    driver_id = data.driver_id
    if not driver_id and data.driver_name:
        matched_driver = db.scalar(
            select(m.User).where(
                m.User.role == "haydovchi",
                m.User.full_name.ilike(f"%{data.driver_name.strip()}%"),
            )
        )
        if matched_driver:
            driver_id = matched_driver.id

    delivery = m.Delivery(
        sale_id=data.sale_id,
        driver_id=driver_id,
        vehicle_number=data.vehicle_number.strip().upper(),
        vehicle_model=data.vehicle_model.strip(),
        driver_name=data.driver_name.strip(),
        driver_phone=data.driver_phone.strip() if data.driver_phone else None,
        recipient_name=data.recipient_name.strip(),
        recipient_phone=data.recipient_phone.strip() if data.recipient_phone else None,
        destination_address=data.destination_address.strip() if data.destination_address else None,
        delivery_fee=data.delivery_fee,
        fee_payer=data.fee_payer,
        status=data.status,
        dispatch_time=data.dispatch_time or (datetime.utcnow() if data.status == "on_the_way" else None),
        delivered_time=data.delivered_time or (datetime.utcnow() if data.status == "delivered" else None),
        note=data.note.strip() if data.note else None,
    )
    db.add(delivery)
    db.flush()

    for item in data.items:
        d_item = m.DeliveryItem(
            delivery_id=delivery.id,
            product_id=item.product_id,
            product_name=item.product_name.strip(),
            quantity=item.quantity,
            unit=item.unit.strip(),
        )
        db.add(d_item)

    db.commit()
    db.refresh(delivery)
    return delivery


@router.put("/{delivery_id}", response_model=DeliveryOut)
def update_delivery(
    delivery_id: int,
    data: DeliveryUpdate,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    stmt = (
        select(m.Delivery)
        .options(selectinload(m.Delivery.items))
        .where(m.Delivery.id == delivery_id)
    )
    delivery = db.scalars(stmt).first()
    if delivery is None:
        raise HTTPException(404, "Yetkazib berish yozuvi topilmadi")

    if data.driver_id is not None:
        delivery.driver_id = data.driver_id
    if data.vehicle_number is not None:
        delivery.vehicle_number = data.vehicle_number.strip().upper()
    if data.vehicle_model is not None:
        delivery.vehicle_model = data.vehicle_model.strip()
    if data.driver_name is not None:
        delivery.driver_name = data.driver_name.strip()
    if data.driver_phone is not None:
        delivery.driver_phone = data.driver_phone.strip() or None
    if data.recipient_name is not None:
        delivery.recipient_name = data.recipient_name.strip()
    if data.recipient_phone is not None:
        delivery.recipient_phone = data.recipient_phone.strip() or None
    if data.destination_address is not None:
        delivery.destination_address = data.destination_address.strip() or None
    if data.delivery_fee is not None:
        delivery.delivery_fee = data.delivery_fee
    if data.fee_payer is not None:
        delivery.fee_payer = data.fee_payer
    if data.note is not None:
        delivery.note = data.note.strip() or None

    if data.status is not None and data.status != delivery.status:
        delivery.status = data.status
        if data.status == "on_the_way" and not delivery.dispatch_time:
            delivery.dispatch_time = datetime.utcnow()
        elif data.status == "delivered" and not delivery.delivered_time:
            delivery.delivered_time = datetime.utcnow()

    if data.dispatch_time is not None:
        delivery.dispatch_time = data.dispatch_time
    if data.delivered_time is not None:
        delivery.delivered_time = data.delivered_time

    if data.items is not None:
        # replace items
        delivery.items.clear()
        for item in data.items:
            d_item = m.DeliveryItem(
                delivery_id=delivery.id,
                product_id=item.product_id,
                product_name=item.product_name.strip(),
                quantity=item.quantity,
                unit=item.unit.strip(),
            )
            db.add(d_item)

    db.commit()
    db.refresh(delivery)
    return delivery


@router.patch("/{delivery_id}/status", response_model=DeliveryOut)
def update_delivery_status(
    delivery_id: int,
    data: DeliveryStatusUpdate,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    stmt = (
        select(m.Delivery)
        .options(selectinload(m.Delivery.items))
        .where(m.Delivery.id == delivery_id)
    )
    delivery = db.scalars(stmt).first()
    if delivery is None:
        raise HTTPException(404, "Yetkazib berish yozuvi topilmadi")

    delivery.status = data.status
    if data.status == "on_the_way" and not delivery.dispatch_time:
        delivery.dispatch_time = datetime.utcnow()
    elif data.status == "delivered":
        delivery.delivered_time = datetime.utcnow()

    db.commit()
    db.refresh(delivery)
    return delivery


@router.delete("/{delivery_id}", status_code=204)
def delete_delivery(
    delivery_id: int,
    db: Session = Depends(get_db),
    _: m.User = Depends(get_current_user),
):
    delivery = db.get(m.Delivery, delivery_id)
    if delivery is None:
        raise HTTPException(404, "Yetkazib berish yozuvi topilmadi")
    db.delete(delivery)
    db.commit()
    return None


@router.post("/{delivery_id}/accept", response_model=DeliveryOut)
def accept_delivery(
    delivery_id: int,
    db: Session = Depends(get_db),
    current_user: m.User = Depends(get_current_user),
):
    stmt = (
        select(m.Delivery)
        .options(selectinload(m.Delivery.items))
        .where(m.Delivery.id == delivery_id)
    )
    delivery = db.scalars(stmt).first()
    if delivery is None:
        raise HTTPException(404, "Yetkazib berish yozuvi topilmadi")

    if current_user.role == "haydovchi" and not current_user.is_on_shift:
        raise HTTPException(400, "Buyurtma olishdan oldin smenani oching (Ishlamoqda)")

    if delivery.driver_id and delivery.driver_id != current_user.id:
        raise HTTPException(400, "Bu buyurtma allaqachon boshqa haydovchi tomonidan olingan")

    delivery.driver_id = current_user.id
    delivery.driver_name = current_user.full_name
    if current_user.username and current_user.username.isdigit():
        delivery.driver_phone = current_user.username
    delivery.status = "on_the_way"
    if not delivery.dispatch_time:
        delivery.dispatch_time = datetime.utcnow()

    db.commit()
    db.refresh(delivery)
    return delivery


@router.post("/{delivery_id}/reject", response_model=DeliveryOut)
def reject_delivery(
    delivery_id: int,
    db: Session = Depends(get_db),
    current_user: m.User = Depends(get_current_user),
):
    stmt = (
        select(m.Delivery)
        .options(selectinload(m.Delivery.items))
        .where(m.Delivery.id == delivery_id)
    )
    delivery = db.scalars(stmt).first()
    if delivery is None:
        raise HTTPException(404, "Yetkazib berish yozuvi topilmadi")

    delivery.driver_id = None
    delivery.driver_name = "Ochiq (barchaga)"
    delivery.driver_phone = None
    delivery.status = "loading"
    rejection_tag = f"[{current_user.full_name} rad etdi]"
    if delivery.note:
        if rejection_tag not in delivery.note:
            delivery.note = f"{delivery.note} | {rejection_tag}"
    else:
        delivery.note = rejection_tag

    db.commit()
    db.refresh(delivery)
    return delivery


