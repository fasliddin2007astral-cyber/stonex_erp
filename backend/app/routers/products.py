import os
import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import models as m
from .. import roles
from ..database import get_db
from ..deps import get_current_user, require_roles
from ..schemas import ProductIn, ProductOut, ProductUpdate
from ..services.stock import add_movement, get_stock, stock_map

router = APIRouter(prefix="/products", tags=["products"])

UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads" / "products"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


def to_out(p: m.Product, stock) -> ProductOut:
    return ProductOut(id=p.id, name=p.name, sku=p.sku, qr_code=p.qr_code, unit=p.unit,
                      dona_m2=p.dona_m2, price=p.price, cost_price=p.cost_price,
                      sort=getattr(p, 'sort', None),
                      has_sorts=getattr(p, 'has_sorts', False) or False,
                      image_url=p.image_url, is_active=p.is_active, stock=stock)


@router.get("", response_model=list[ProductOut])
def list_products(q: str | None = None, db: Session = Depends(get_db),
                  _: m.User = Depends(get_current_user)):
    stmt = select(m.Product).where(m.Product.is_active.is_(True)).order_by(m.Product.name)
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(m.Product.name.like(like), m.Product.sku.like(like),
                              m.Product.qr_code.like(like), m.Product.color.like(like)))
    stocks = stock_map(db)
    return [to_out(p, stocks.get(p.id, 0)) for p in db.scalars(stmt).all()]


@router.get("/by-code/{code}", response_model=ProductOut)
def by_code(code: str, db: Session = Depends(get_db), _: m.User = Depends(get_current_user)):
    p = db.scalar(select(m.Product).where(
        m.Product.is_active.is_(True), or_(m.Product.qr_code == code, m.Product.sku == code)))
    if p is None:
        raise HTTPException(404, "Mahsulot topilmadi")
    return to_out(p, get_stock(db, p.id))


@router.post("/upload-image")
def upload_image(file: UploadFile = File(...), _: m.User = Depends(require_roles(roles.ADMIN))):
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp", ".gif"]:
        ext = ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    dest_path = UPLOAD_DIR / filename
    with open(dest_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"image_url": f"/uploads/products/{filename}"}


@router.post("/{product_id}/image", response_model=ProductOut)
def upload_product_image(product_id: int, file: UploadFile = File(...),
                         db: Session = Depends(get_db),
                         _: m.User = Depends(require_roles(roles.ADMIN))):
    p = db.get(m.Product, product_id)
    if p is None:
        raise HTTPException(404, "Mahsulot topilmadi")
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in [".jpg", ".jpeg", ".png", ".webp", ".gif"]:
        ext = ".jpg"
    filename = f"prod_{product_id}_{uuid.uuid4().hex[:8]}{ext}"
    dest_path = UPLOAD_DIR / filename
    with open(dest_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    p.image_url = f"/uploads/products/{filename}"
    db.commit()
    return to_out(p, get_stock(db, p.id))


@router.post("", response_model=ProductOut, status_code=201)
def create_product(data: ProductIn, db: Session = Depends(get_db),
                   admin: m.User = Depends(require_roles(roles.ADMIN))):
    p = m.Product(name=data.name.strip(), sku=data.sku or None, qr_code=data.qr_code or None,
                  unit=data.unit, dona_m2=data.dona_m2, price=data.price,
                  cost_price=data.cost_price, sort=data.sort, has_sorts=data.has_sorts, image_url=data.image_url)
    db.add(p)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "SKU yoki QR-kod allaqachon mavjud")
    if data.initial_stock > 0:
        add_movement(db, product_id=p.id, qty_delta=data.initial_stock, kind=m.MV_OPENING,
                     note="Boshlang'ich qoldiq", user_id=admin.id)
    db.commit()
    return to_out(p, get_stock(db, p.id))


@router.patch("/{product_id}", response_model=ProductOut)
def update_product(product_id: int, data: ProductUpdate, db: Session = Depends(get_db),
                   _: m.User = Depends(require_roles(roles.ADMIN))):
    p = db.get(m.Product, product_id)
    if p is None:
        raise HTTPException(404, "Mahsulot topilmadi")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(p, field, value or None if field in ("sku", "qr_code") else value)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "SKU yoki QR-kod allaqachon mavjud")
    return to_out(p, get_stock(db, p.id))


@router.delete("/{product_id}", status_code=204)
def deactivate_product(product_id: int, db: Session = Depends(get_db),
                       _: m.User = Depends(require_roles(roles.ADMIN))):
    """Tarix saqlanishi uchun mahsulot o'chirilmaydi, faqat faolsizlantiriladi."""
    p = db.get(m.Product, product_id)
    if p is None:
        raise HTTPException(404, "Mahsulot topilmadi")
    p.is_active = False
    db.commit()
