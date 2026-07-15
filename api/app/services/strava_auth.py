import requests

from app.config import settings

STRAVA_AUTH_URL = "https://www.strava.com/oauth/authorize"
STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token"

STRAVA_SCOPE = "activity:read_all,profile:read_all"


def build_authorize_url() -> str:
    params = {
        "client_id": settings.strava_client_id,
        "response_type": "code",
        "redirect_uri": settings.strava_redirect_uri,
        "approval_prompt": "auto",
        "scope": STRAVA_SCOPE,
    }
    return requests.Request("GET", STRAVA_AUTH_URL, params=params).prepare().url


class StravaTokenExchangeError(Exception):
    pass


def exchange_code_for_tokens(code: str) -> dict:
    """Échange le code Strava contre les tokens + les infos de l'athlète."""
    response = requests.post(
        STRAVA_TOKEN_URL,
        data={
            "client_id": settings.strava_client_id,
            "client_secret": settings.strava_client_secret,
            "code": code,
            "grant_type": "authorization_code",
        },
    )
    if response.status_code != 200:
        raise StravaTokenExchangeError(f"Strava token exchange failed: {response.status_code} {response.text}")
    return response.json()
