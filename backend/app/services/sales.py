"""Savdo biznes mantiqi (UI va router'dan ajratilgan).

Bitta tranzaksiyada: qoldiq tekshiruvi -> savdo -> ombor chiqimi -> to'lov.
Pul tushumi (Payment) savdo summasidan alohida; bitta to'lov ikki marta hisoblanmaydi.
"""
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy.orm import Session

from .. import models as m
from ..schemas import SaleIn
from ..units import dona_to_base, q2, q3
from .stock import add_movement, get_stock


def to_base_qty(product: m.Product, quantity: Decimal, unit: str) -> Decimal:
    if unit == "dona":
        try:
            return dona_to_base(quantity, product.dona_m2)
        except ValueError as e:
            raise HTTPException(400, f"{product.name}: {e}")
    return q3(quantity)


def create_sale(db: Session, cashier: m.User, data: SaleIn) -> m.Sale:
    reserved: dict[int, Decimal] = {}
    lines: list[tuple[m.Product, Decimal]] = []

    for it in data.items:
        product = db.get(m.Product, it.product_id, with_for_update=True)
        if product is None or not product.is_active:
            raise HTTPException(404, f"Mahsulot topilmadi (id={it.product_id})")
        qty = to_base_qty(product, it.quantity, it.unit)
        if qty <= 0:
            raise HTTPException(400, f"{product.name}: miqdor 0 dan katta bo'lishi kerak")
        available = get_stock(db, product.id) - reserved.get(product.id, Decimal(0))
        if qty > available:
            raise HTTPException(
                400, f"{product.name}: omborda yetarli emas (bor: {available} {product.unit})"
            )
        reserved[product.id] = reserved.get(product.id, Decimal(0)) + qty
        lines.append((product, qty))

    total = sum((q2(q * p.price) for p, q in lines), Decimal(0))
    total_cost = sum((q2(q * p.cost_price) for p, q in lines), Decimal(0))
    paid = q2(data.paid_amount)
    if paid > total:
        raise HTTPException(400, "To'lov savdo summasidan oshib ketdi")
    debt = total - paid

    customer_id = data.customer_id
    if customer_id is not None and db.get(m.Customer, customer_id) is None:
        raise HTTPException(404, "Mijoz topilmadi")
    if customer_id is None and data.customer_name:
        c = m.Customer(
            name=data.customer_name.strip(),
            phone=data.customer_phone,
            passport=data.customer_passport,
            photo_url=data.customer_photo_url,
        )
        db.add(c)
        db.flush()
        customer_id = c.id
    elif customer_id is not None:
        c = db.get(m.Customer, customer_id)
        if c:
            if data.customer_passport:
                c.passport = data.customer_passport
            if data.customer_photo_url:
                c.photo_url = data.customer_photo_url
            if data.customer_phone and not c.phone:
                c.phone = data.customer_phone
    if debt > 0 and customer_id is None:
        raise HTTPException(400, "Nasiya uchun mijoz ko'rsatilishi shart")

    sale = m.Sale(customer_id=customer_id, cashier_id=cashier.id, total=total,
                  total_cost=total_cost, paid=paid)
    db.add(sale)
    db.flush()

    for product, qty in lines:
        db.add(m.SaleItem(sale_id=sale.id, product_id=product.id, product_name=product.name,
                          quantity=qty, unit_price=product.price, unit_cost=product.cost_price,
                          line_total=q2(qty * product.price)))
        add_movement(db, product_id=product.id, qty_delta=-qty, kind=m.MV_SALE,
                     ref_type="sale", ref_id=sale.id, user_id=cashier.id)
    if paid > 0:
        db.add(m.Payment(sale_id=sale.id, amount=paid, received_by=cashier.id))

    # Avtomatik bildirishnoma yaratish
    db.add(m.Notification(
        title="Yangi savdo amalga oshirildi",
        message=f"Kassir {cashier.full_name} tomonidan {int(total):,} so‘mlik savdo qilindi (Chek #{sale.id}).".replace(",", " "),
        kind="sale",
    ))

    # Kam qolgan tovarlar bo'yicha ogohlantirish
    for product, _ in lines:
        curr_stock = get_stock(db, product.id)
        if curr_stock <= Decimal("20"):
            db.add(m.Notification(
                title="Ombor ogohlantirishi: Zaxira kam",
                message=f"{product.name} qoldig‘i {curr_stock} {product.unit} qoldi. Yangi partiya xaridini rejalashtiring.",
                kind="warning",
            ))

    db.commit()
    db.refresh(sale)
    return sale


def add_payment(db: Session, user: m.User, sale_id: int, amount: Decimal, method: str) -> m.Sale:
    sale = db.get(m.Sale, sale_id, with_for_update=True)
    if sale is None:
        raise HTTPException(404, "Savdo topilmadi")
    amount = q2(amount)
    if amount > sale.total - sale.paid:
        raise HTTPException(400, "To'lov qolgan qarzdan oshib ketdi")
    db.add(m.Payment(sale_id=sale.id, amount=amount, method=method, received_by=user.id))
    sale.paid = sale.paid + amount

    c_name = sale.customer.name if sale.customer else f"Mijoz (Savdo #{sale.id})"
    db.add(m.Notification(
        title="Qarz to‘lovi qabul qilindi",
        message=f"{c_name} {int(amount):,} so‘m qarzini {method} orqali to‘ladi.".replace(",", " "),
        kind="payment",
    ))

    db.commit()
    db.refresh(sale)
    return sale
