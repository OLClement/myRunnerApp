from datetime import date, datetime, time

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, load_only

from app.db import get_db
from app.deps import get_current_user, get_strava_token
from app.models import Activity, User
from app.schemas import ActivityDetailOut, ActivityOut, RepairResult, SyncResult
from app.services.strava_service import backfill_hr_zones, repair_missing_charge, sync_activities

router = APIRouter(prefix="/activities", tags=["activities"])


@router.get("", response_model=list[ActivityOut])
def list_activities(
    start: date | None = None,
    end: date | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Activity]:
    query = (
        db.query(Activity)
        .filter_by(user_id=current_user.id)
        # hr_data/velocity_data sont de gros JSON texte non utilisés par ActivityOut :
        # les exclure évite de transférer des Mo inutiles depuis Supabase à chaque appel.
        .options(
            load_only(
                Activity.id,
                Activity.strava_id,
                Activity.name,
                Activity.sport_type,
                Activity.start_date,
                Activity.distance_km,
                Activity.duration_min,
                Activity.avg_hr,
                Activity.total_elevation,
                Activity.charge_load,
            )
        )
    )
    if start is not None:
        query = query.filter(Activity.start_date >= datetime.combine(start, time.min))
    if end is not None:
        query = query.filter(Activity.start_date <= datetime.combine(end, time.max))
    return query.order_by(Activity.start_date.desc()).all()


@router.get("/{activity_id}", response_model=ActivityDetailOut)
def get_activity(
    activity_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Activity:
    activity = db.query(Activity).filter_by(id=activity_id, user_id=current_user.id).first()
    if activity is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Activity not found")
    return activity


@router.post("/sync", response_model=SyncResult)
def sync(
    current_user: User = Depends(get_current_user),
    token: str = Depends(get_strava_token),
    db: Session = Depends(get_db),
) -> SyncResult:
    new_count, updated_count = sync_activities(current_user, token, db, limit=50)
    return SyncResult(new=new_count, updated=updated_count)


@router.post("/sync/full", response_model=SyncResult)
def sync_full(
    current_user: User = Depends(get_current_user),
    token: str = Depends(get_strava_token),
    db: Session = Depends(get_db),
) -> SyncResult:
    db.query(Activity).filter_by(user_id=current_user.id).delete()
    db.commit()
    new_count, _ = sync_activities(current_user, token, db, limit=None)
    return SyncResult(new=new_count, updated=0)


@router.post("/sync/repair", response_model=RepairResult)
def sync_repair(
    current_user: User = Depends(get_current_user),
    token: str = Depends(get_strava_token),
    db: Session = Depends(get_db),
) -> RepairResult:
    fixed = repair_missing_charge(current_user, token, db)
    return RepairResult(fixed=fixed)


@router.post("/sync/repair-zones", response_model=RepairResult)
def sync_repair_zones(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RepairResult:
    fixed = backfill_hr_zones(current_user, db)
    return RepairResult(fixed=fixed)
