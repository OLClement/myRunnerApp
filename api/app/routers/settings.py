from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import SettingsOut, SettingsUpdate

router = APIRouter(prefix="/me", tags=["settings"])


@router.get("", response_model=SettingsOut)
def get_settings(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@router.put("", response_model=SettingsOut)
def update_settings(
    payload: SettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user
