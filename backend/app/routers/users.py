from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import roles
from ..database import get_db
from ..deps import get_current_user, require_roles
from ..models import User
from ..schemas import UserCreate, UserOut, UserUpdate
from ..security import hash_password

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserOut])
def list_users(role: str | None = None, db: Session = Depends(get_db),
               user: User = Depends(get_current_user)):
    if user.role != roles.ADMIN and role != roles.WORKER:
        raise HTTPException(403, "Bu amal uchun ruxsat yo'q")
    q = select(User).order_by(User.id)
    if role:
        q = q.where(User.role == role)
    elif user.role != roles.ADMIN:
        q = q.where(User.role == roles.WORKER)
    return db.scalars(q).all()


@router.post("", response_model=UserOut, status_code=201)
def create_user(data: UserCreate, db: Session = Depends(get_db),
                _: User = Depends(require_roles(roles.ADMIN))):
    if db.scalar(select(User).where(User.username == data.username)):
        raise HTTPException(409, "Bu login band")
    u = User(username=data.username, full_name=data.full_name, role=data.role,
             password_hash=hash_password(data.password))
    db.add(u)
    db.commit()
    return u


@router.patch("/{user_id}", response_model=UserOut)
def update_user(user_id: int, data: UserUpdate, db: Session = Depends(get_db),
                admin: User = Depends(require_roles(roles.ADMIN))):
    u = db.get(User, user_id)
    if u is None:
        raise HTTPException(404, "Foydalanuvchi topilmadi")
    if u.id == admin.id and (data.is_active is False or (data.role and data.role != roles.ADMIN)):
        raise HTTPException(400, "O'zingizni o'chira yoki rolingizni pasaytira olmaysiz")
    if data.full_name is not None:
        u.full_name = data.full_name
    if data.role is not None:
        u.role = data.role
    if data.is_active is not None:
        u.is_active = data.is_active
    if data.password:
        u.password_hash = hash_password(data.password)
    db.commit()
    return u
