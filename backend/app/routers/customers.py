from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models as m
from .. import roles
from ..database import get_db
from ..deps import require_roles
from ..schemas import CustomerIn, CustomerOut

router = APIRouter(prefix="/customers", tags=["customers"])
_sellers = require_roles(roles.ADMIN, roles.CASHIER)


@router.get("", response_model=list[CustomerOut])
def list_customers(db: Session = Depends(get_db), _: m.User = Depends(_sellers)):
    return db.scalars(select(m.Customer).order_by(m.Customer.name)).all()


@router.post("", response_model=CustomerOut, status_code=201)
def create_customer(data: CustomerIn, db: Session = Depends(get_db), _: m.User = Depends(_sellers)):
    c = m.Customer(name=data.name.strip(), phone=data.phone)
    db.add(c)
    db.commit()
    return c
