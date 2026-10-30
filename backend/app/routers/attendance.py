from datetime import datetime, timezone
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import roles
from ..database import get_db
from ..deps import get_current_user, require_roles
from ..models import Attendance, User
from ..schemas import (
    AttendanceCheckIn,
    AttendanceCheckOut,
    AttendanceOut,
    AttendanceRecordIn,
    SalaryReportItem,
)

router = APIRouter(prefix="/attendance", tags=["attendance"])


def _today_str() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def _calc_hours(check_in: datetime | None, check_out: datetime | None) -> Decimal:
    if not check_in or not check_out:
        return Decimal(0)
    diff = (check_out - check_in).total_seconds()
    hours = max(0.0, diff / 3600.0)
    return Decimal(str(round(hours, 2)))


@router.get("", response_model=list[AttendanceOut])
def list_attendance(
    date: str | None = None,
    month: str | None = None,
    user_id: int | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = select(Attendance).order_by(Attendance.date.desc(), Attendance.id.desc())
    if date:
        q = q.where(Attendance.date == date)
    elif month:
        q = q.where(Attendance.date.startswith(month))

    if user_id:
        if user.role != roles.ADMIN and user.id != user_id:
            raise HTTPException(403, "Ruxsat berilmagan")
        q = q.where(Attendance.user_id == user_id)
    elif user.role != roles.ADMIN:
        q = q.where(Attendance.user_id == user.id)

    records = db.scalars(q).all()
    out = []
    for r in records:
        u_name = r.user.full_name if r.user else None
        out.append(
            AttendanceOut(
                id=r.id,
                user_id=r.user_id,
                user_name=u_name,
                date=r.date,
                check_in=r.check_in,
                check_out=r.check_out,
                worked_hours=r.worked_hours,
                status=r.status,
                note=r.note,
            )
        )
    return out


@router.post("/check-in", response_model=AttendanceOut)
def check_in(
    data: AttendanceCheckIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != roles.ADMIN and current_user.id != data.user_id:
        raise HTTPException(403, "Boshqa xodim nomidan kirish belgilab bo'lmaydi")

    u = db.get(User, data.user_id)
    if not u or not u.is_active:
        raise HTTPException(404, "Xodim topilmadi")

    date_str = data.date or _today_str()
    record = db.scalar(
        select(Attendance).where(
            Attendance.user_id == data.user_id, Attendance.date == date_str
        )
    )

    now = data.check_in or datetime.now()
    # 09:15 dan kech kelsa late deb belgilaymiz
    is_late = now.hour > 9 or (now.hour == 9 and now.minute > 15)

    if record:
        record.check_in = now
        if record.check_out:
            record.worked_hours = _calc_hours(now, record.check_out)
        if is_late:
            record.status = "late"
        if data.note:
            record.note = data.note
    else:
        record = Attendance(
            user_id=data.user_id,
            date=date_str,
            check_in=now,
            status="late" if is_late else "present",
            note=data.note,
        )
        db.add(record)

    db.commit()
    db.refresh(record)
    return AttendanceOut(
        id=record.id,
        user_id=record.user_id,
        user_name=u.full_name,
        date=record.date,
        check_in=record.check_in,
        check_out=record.check_out,
        worked_hours=record.worked_hours,
        status=record.status,
        note=record.note,
    )


@router.post("/check-out", response_model=AttendanceOut)
def check_out(
    data: AttendanceCheckOut,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != roles.ADMIN and current_user.id != data.user_id:
        raise HTTPException(403, "Ruxsat berilmagan")

    u = db.get(User, data.user_id)
    if not u:
        raise HTTPException(404, "Xodim topilmadi")

    date_str = data.date or _today_str()
    record = db.scalar(
        select(Attendance).where(
            Attendance.user_id == data.user_id, Attendance.date == date_str
        )
    )

    now = data.check_out or datetime.now()
    if not record:
        record = Attendance(
            user_id=data.user_id,
            date=date_str,
            check_out=now,
            status="present",
            note=data.note,
        )
        db.add(record)
    else:
        record.check_out = now
        record.worked_hours = _calc_hours(record.check_in, now)
        if data.note:
            record.note = data.note

    db.commit()
    db.refresh(record)
    return AttendanceOut(
        id=record.id,
        user_id=record.user_id,
        user_name=u.full_name,
        date=record.date,
        check_in=record.check_in,
        check_out=record.check_out,
        worked_hours=record.worked_hours,
        status=record.status,
        note=record.note,
    )


@router.post("/record", response_model=AttendanceOut)
def record_attendance(
    data: AttendanceRecordIn,
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(roles.ADMIN)),
):
    u = db.get(User, data.user_id)
    if not u:
        raise HTTPException(404, "Xodim topilmadi")

    if data.id:
        rec = db.get(Attendance, data.id)
        if not rec:
            raise HTTPException(404, "Davomat yozuvi topilmadi")
    else:
        rec = db.scalar(
            select(Attendance).where(
                Attendance.user_id == data.user_id, Attendance.date == data.date
            )
        )
        if not rec:
            rec = Attendance(user_id=data.user_id, date=data.date)
            db.add(rec)

    rec.check_in = data.check_in
    rec.check_out = data.check_out
    rec.status = data.status
    rec.note = data.note
    if data.worked_hours > 0:
        rec.worked_hours = data.worked_hours
    elif data.check_in and data.check_out:
        rec.worked_hours = _calc_hours(data.check_in, data.check_out)

    db.commit()
    db.refresh(rec)
    return AttendanceOut(
        id=rec.id,
        user_id=rec.user_id,
        user_name=u.full_name,
        date=rec.date,
        check_in=rec.check_in,
        check_out=rec.check_out,
        worked_hours=rec.worked_hours,
        status=rec.status,
        note=rec.note,
    )


@router.get("/salary-report", response_model=list[SalaryReportItem])
def get_salary_report(
    month: str = Query(..., description="YYYY-MM formati"),
    total_working_days: int = Query(26, ge=1, le=31),
    db: Session = Depends(get_db),
    _: User = Depends(require_roles(roles.ADMIN)),
):
    users = db.scalars(select(User).where(User.is_active == True).order_by(User.id)).all()
    attendances = db.scalars(
        select(Attendance).where(Attendance.date.startswith(month))
    ).all()

    user_att: dict[int, list[Attendance]] = {}
    for a in attendances:
        user_att.setdefault(a.user_id, []).append(a)

    report: list[SalaryReportItem] = []
    for u in users:
        atts = user_att.get(u.id, [])
        worked_atts = [a for a in atts if a.status != "absent"]
        days_worked = len(worked_atts)
        hours_worked = sum((a.worked_hours for a in worked_atts), Decimal(0))
        days_late = sum(1 for a in atts if a.status == "late")

        base_sal = u.salary or Decimal(0)
        sal_type = u.salary_type or "monthly"

        # Davomat bo'yicha hisoblash
        if sal_type == "daily":
            calc_sal = base_sal * Decimal(days_worked)
        elif sal_type == "hourly":
            calc_sal = base_sal * hours_worked
        else:  # monthly
            per_day = base_sal / Decimal(total_working_days) if total_working_days else Decimal(0)
            calc_sal = Decimal(str(round(float(per_day * Decimal(days_worked)), 2)))

        # Kechikishlar jarimasi (har bir kechikish uchun kunlik maoshning 10%)
        day_rate = (base_sal / Decimal(total_working_days)) if total_working_days else Decimal(0)
        deduction = Decimal(str(round(float(day_rate * Decimal(0.1) * Decimal(days_late)), 2)))
        net = max(Decimal(0), calc_sal - deduction)

        report.append(
            SalaryReportItem(
                user_id=u.id,
                full_name=u.full_name,
                role=u.role,
                base_salary=base_sal,
                salary_type=sal_type,
                days_worked=days_worked,
                hours_worked=hours_worked,
                days_late=days_late,
                calculated_salary=calc_sal,
                bonus=Decimal(0),
                deduction=deduction,
                net_salary=net,
                is_paid=False,
            )
        )

    return report

