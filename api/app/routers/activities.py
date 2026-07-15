from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user, get_strava_token
from app.models import Activity, User
from app.schemas import ActivityOut, RepairResult, SyncResult
from app.services.strava_service import repair_missing_charge, sync_activities

router = APIRouter(prefix="/activities", tags=["activities"])


@router.get("", response_model=list[ActivityOut])
def list_activities(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Activity]:
    return (
        db.query(Activity)
        .filter_by(user_id=current_user.id)
        .order_by(Activity.start_date.desc())
        .all()
    )


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
