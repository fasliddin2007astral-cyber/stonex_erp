from datetime import datetime
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
    is_order = (getattr(data, "status", "completed") == "order")

    for it in data.items:
        product = db.get(m.Product, it.product_id, with_for_update=True)
        if product is None or not product.is_active:
            raise HTTPException(404, f"Mahsulot topilmadi (id={it.product_id})")
        qty = to_base_qty(product, it.quantity, it.unit)
        if qty <= 0:
            raise HTTPException(400, f"{product.name}: miqdor 0 dan katta bo'lishi kerak")
        if not is_order:
            available = get_stock(db, product.id) - reserved.get(product.id, Decimal(0))
            if qty > available:
                raise HTTPException(
                    400, f"{product.name}: omborda yetarli emas (bor: {available} {product.unit})"
                )
            reserved[product.id] = reserved.get(product.id, Decimal(0)) + qty
        lines.append((product, qty, it.custom_name))

    total = sum((q2(q * p.price) for p, q, _ in lines), Decimal(0))
    total_cost = sum((q2(q * p.cost_price) for p, q, _ in lines), Decimal(0))
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
    if (debt > 0 or is_order) and customer_id is None:
        raise HTTPException(400, "Buyurtma yoki nasiya uchun mijoz ko'rsatilishi shart")

    sale_status = "order" if is_order else "completed"
    sale = m.Sale(customer_id=customer_id, cashier_id=cashier.id, total=total,
                  total_cost=total_cost, paid=paid, status=sale_status, note=data.note)
    db.add(sale)
    db.flush()

    for product, qty, custom_name in lines:
        item_name = custom_name.strip() if (custom_name and custom_name.strip()) else product.name
        db.add(m.SaleItem(sale_id=sale.id, product_id=product.id, product_name=item_name,
                          quantity=qty, unit_price=product.price, unit_cost=product.cost_price,
                          line_total=q2(qty * product.price)))
        if not is_order:
            add_movement(db, product_id=product.id, qty_delta=-qty, kind=m.MV_SALE,
                         ref_type="sale", ref_id=sale.id, user_id=cashier.id)
    if paid > 0:
        db.add(m.Payment(sale_id=sale.id, amount=paid, received_by=cashier.id))

    # Avtomatik bildirishnoma yaratish
    if is_order:
        c_name = data.customer_name or "Mijoz"
        db.add(m.Notification(
            title="Yangi buyurtma qabul qilindi",
            message=f"{c_name} uchun {int(total):,} so‘mlik buyurtma olindi (Buyurtma #{sale.id}). Avans: {int(paid):,} so‘m.".replace(",", " "),
            kind="sale",
        ))
    else:
        db.add(m.Notification(
            title="Yangi savdo amalga oshirildi",
            message=f"Kassir {cashier.full_name} tomonidan {int(total):,} so‘mlik savdo qilindi (Chek #{sale.id}).".replace(",", " "),
            kind="sale",
        ))

        # Kam qolgan tovarlar bo'yicha ogohlantirish
        for product, *rest in lines:
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


def fulfill_order(db: Session, user: m.User, sale_id: int) -> m.Sale:
    """Buyurtmani to'liq savdoga aylantirish (tovarlarni ombordan chiqarish)."""
    sale = db.get(m.Sale, sale_id, with_for_update=True)
    if sale is None:
        raise HTTPException(404, "Buyurtma topilmadi")
    if sale.status == "completed":
        raise HTTPException(400, "Ushbu buyurtma allaqachon topshirilgan")
    if sale.status == "cancelled":
        raise HTTPException(400, "Bekor qilingan buyurtmani topshirib bo'lmaydi")

    for it in sale.items:
        available = get_stock(db, it.product_id)
        if it.quantity > available:
            raise HTTPException(400, f"{it.product_name}: omborda yetarli emas (mavjud: {available})")

    for it in sale.items:
        add_movement(db, product_id=it.product_id, qty_delta=-it.quantity, kind=m.MV_SALE,
                     ref_type="sale", ref_id=sale.id, user_id=user.id)

    sale.status = "completed"
    c_name = sale.customer.name if sale.customer else f"Mijoz #{sale.customer_id}"
    db.add(m.Notification(
        title="Buyurtma topshirildi",
        message=f"{c_name} uchun Buyurtma #{sale.id} tovarlari topshirildi va ombordan chiqarildi.",
        kind="sale",
    ))

    db.commit()
    db.refresh(sale)
    return sale


def cancel_order(db: Session, user: m.User, sale_id: int) -> m.Sale:
    """Buyurtmani bekor qilish."""
    sale = db.get(m.Sale, sale_id, with_for_update=True)
    if sale is None:
        raise HTTPException(404, "Buyurtma topilmadi")
    if sale.status != "order":
        raise HTTPException(400, "Faqat faol buyurtmalarni bekor qilish mumkin")

    sale.status = "cancelled"
    db.commit()
    db.refresh(sale)
    return sale

def process_return(db: Session, user: m.User, sale_id: int, return_items: list, reason: str | None = None) -> m.Sale:
    """Chek bo'yicha mahsulotni qaytarib olish (Vozvrat).
    Qoidalar:
    1. 10 kunlik muddat (savdo sanasidan 10 kundan oshsa qabul qilinmaydi).
    2. Kesilgan kafel/toshlar qaytarilmaydi (faqat butun holatdagilar olinadi).
    """
    sale = db.get(m.Sale, sale_id, with_for_update=True)
    if sale is None:
        raise HTTPException(404, "Savdo topilmadi")

    # 1. 10 kunlik muddat tekshiruvi
    created_at = sale.created_at or datetime.utcnow()
    diff_days = (datetime.utcnow() - created_at).total_seconds() / 86400.0
    if diff_days > 10.0:
        raise HTTPException(
            400,
            f"Mahsulotni qaytarish muddati (10 kun) o‘tgan! Savdo bundan {int(diff_days)} kun oldin qilingan.",
        )

    if sale.status in ("cancelled", "returned"):
        raise HTTPException(400, "Ushbu savdo allaqachon bekor qilingan yoki to‘liq qaytarilgan")

    sale_item_map = {item.product_id: item for item in sale.items}
    total_refund = Decimal(0)

    for ret in return_items:
        p_id = getattr(ret, "product_id", None) or (ret.get("product_id") if isinstance(ret, dict) else None)
        raw_qty = getattr(ret, "quantity", None) or (ret.get("quantity", 0) if isinstance(ret, dict) else 0)
        qty = Decimal(str(raw_qty))
        if qty <= Decimal(0):
            continue

        if p_id not in sale_item_map:
            raise HTTPException(400, f"Mahsulot (ID: {p_id}) ushbu chekda topilmadi")
        s_item = sale_item_map[p_id]

        # 2. Kesilgan kafel / tosh tekshiruvi
        p_name = s_item.product_name
        is_cut = (("[" in p_name and ("]" in p_name or "dona)" in p_name)) or "kesil" in p_name.lower() or "maxsus razmer" in p_name.lower())
        if is_cut:
            raise HTTPException(
                400,
                f"'{p_name}' maxsus razmerda kesib berilgan! Kesilgan kafellar qaytarib olinmaydi.",
            )

        if qty > s_item.quantity:
            raise HTTPException(
                400,
                f"Qaytarish miqdori ({qty}) sotilgan miqdordan ({s_item.quantity}) ko‘p bo‘lishi mumkin emas",
            )

        line_refund = qty * s_item.unit_price
        total_refund += line_refund

        # Omborga qaytarish (MV_RETURN = 'return')
        add_movement(
            db,
            product_id=s_item.product_id,
            qty_delta=qty,
            kind=m.MV_RETURN,
            ref_type="sale",
            ref_id=sale.id,
            note=f"Chek #{sale.id} dan qaytarildi (Vozvrat): {qty} ta. {reason or ''}".strip(),
            user_id=user.id,
        )

        s_item.quantity -= qty
        s_item.line_total = s_item.quantity * s_item.unit_price

    if total_refund <= Decimal(0):
        raise HTTPException(400, "Qaytarish uchun kamida bitta mahsulot miqdori tanlanishi kerak")

    # 3. Moliyaviy hisob-kitob (Nasiya va Kassa qaytarilishi)
    remaining_debt = sale.debt
    debt_reduced = min(remaining_debt, total_refund)
    cash_refund = total_refund - debt_reduced

    sale.total = max(Decimal(0), sale.total - total_refund)
    sale.paid = max(Decimal(0), sale.paid - cash_refund)

    all_returned = all(item.quantity <= Decimal(0) for item in sale.items)
    if all_returned or sale.total <= Decimal(0):
        sale.status = "returned"
    else:
        sale.status = "partially_returned"

    today_str = datetime.utcnow().strftime('%d.%m.%Y')
    return_note = f"[Qaytarildi: {total_refund:,.0f} so'm ({today_str})]"
    sale.note = f"{sale.note or ''} {return_note}".strip()

    db.commit()
    db.refresh(sale)
    return sale

