from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import AccessTokenResponse, RefreshRequest
from app.security import InvalidTokenError, create_access_token, create_refresh_token, decode_token
from app.services.strava_auth import StravaTokenExchangeError, build_authorize_url, exchange_code_for_tokens

router = APIRouter(prefix="/auth", tags=["auth"])

MOBILE_CALLBACK_SCHEME = "myrunner://strava/callback"


@router.get("/strava/login")
def strava_login() -> RedirectResponse:
    return RedirectResponse(build_authorize_url())


@router.get("/strava/callback")
def strava_callback(code: str | None = None, error: str | None = None, db: Session = Depends(get_db)) -> RedirectResponse:
    if error:
        return RedirectResponse(f"{MOBILE_CALLBACK_SCHEME}?error={error}")

    if not code:
        return RedirectResponse(f"{MOBILE_CALLBACK_SCHEME}?error=missing_code")

    try:
        tokens = exchange_code_for_tokens(code)
    except StravaTokenExchangeError:
        return RedirectResponse(f"{MOBILE_CALLBACK_SCHEME}?error=strava_exchange_failed")

    athlete = tokens.get("athlete", {})
    strava_athlete_id = athlete.get("id")
    if not strava_athlete_id:
        return RedirectResponse(f"{MOBILE_CALLBACK_SCHEME}?error=missing_athlete")

    user = db.query(User).filter_by(strava_athlete_id=strava_athlete_id).first()
    if not user:
        user = User(strava_athlete_id=strava_athlete_id)
        db.add(user)

    user.email = athlete.get("email")
    user.strava_access_token = tokens["access_token"]
    user.strava_refresh_token = tokens["refresh_token"]
    user.strava_expires_at = tokens["expires_at"]
    db.commit()
    db.refresh(user)

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    query = urlencode({"access_token": access_token, "refresh_token": refresh_token})
    return RedirectResponse(f"{MOBILE_CALLBACK_SCHEME}?{query}")


@router.post("/refresh", response_model=AccessTokenResponse)
def refresh(body: RefreshRequest, db: Session = Depends(get_db)) -> AccessTokenResponse:
    try:
        user_id = decode_token(body.refresh_token, expected_type="refresh")
    except InvalidTokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token") from exc

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return AccessTokenResponse(access_token=create_access_token(user.id))


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)) -> dict:
    # Stateless JWT pour le MVP : rien à invalider côté serveur, le client jette ses tokens.
    return {"status": "ok"}
