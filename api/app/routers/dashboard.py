from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import DailyDashboardOut, DashboardOut
from app.services.dashboard_service import build_daily_dashboard, build_weekly_dashboard

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("", response_model=DashboardOut)
def get_dashboard(
    period: str = "1y",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DashboardOut:
    return DashboardOut(**build_weekly_dashboard(current_user, db, period))


@router.get("/daily", response_model=DailyDashboardOut)
def get_daily_dashboard(
    period: str = "1y",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DailyDashboardOut:
    return DailyDashboardOut(**build_daily_dashboard(current_user, db, period))
