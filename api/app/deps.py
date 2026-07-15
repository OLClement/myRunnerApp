from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import User
from app.security import InvalidTokenError, decode_token
from app.services.strava_service import StravaTokenRefreshError, get_valid_strava_token

bearer_scheme = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    try:
        user_id = decode_token(credentials.credentials, expected_type="access")
    except InvalidTokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token") from exc

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user


def get_strava_token(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> str:
    if not current_user.strava_access_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No Strava account linked")
    try:
        return get_valid_strava_token(current_user, db)
    except StravaTokenRefreshError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unable to refresh Strava token") from exc
