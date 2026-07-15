import json
import time
from datetime import datetime, timedelta, timezone

import requests
from sqlalchemy.orm import Session

from app.config import settings
from app.models import Activity, User

STRAVA_TOKEN_URL = "https://www.strava.com/oauth/token"
STRAVA_API_BASE = "https://www.strava.com/api/v3"

# ===== ZONES ET POIDS =====

FC_MAX_RUN = 190
BIKE_FC_FACTOR = 0.93  # vélo : -7% vs run
SWIM_FC_FACTOR = 0.90  # natation : -10% vs run

HR_ZONES_PCT = {
    1: (50, 60), 2: (60, 70), 3: (70, 80), 4: (80, 90), 5: (90, 100),
}

BASE_ZONE_WEIGHTS_PER_MIN = {
    1: 0.08,
    2: 0.33,
    3: 1.17,
    4: 3.00,
    5: 6.67,
}

SPORT_FACTORS = {
    "Run": 1.00,
    "TrailRun": 0.85,
    "VirtualRun": 1.00,
    "Ride": 0.85,
    "VirtualRide": 0.85,
    "MountainBikeRide": 0.85,
    "GravelRide": 0.85,
    "EBikeRide": 0.70,
    "Swim": 0.70,
    "OpenWaterSwim": 0.70,
    "WeightTraining": 0.55,
    "Workout": 0.55,
    "Crossfit": 0.55,
    "AlpineSki": 0.30,
    "BackcountrySki": 0.80,
    "NordicSki": 0.80,
}

SPORT_TYPE_TO_GROUP = {
    "Run": "Course",
    "TrailRun": "Course",
    "VirtualRun": "Course",
    "Ride": "Vélo",
    "VirtualRide": "Vélo",
    "MountainBikeRide": "Vélo",
    "GravelRide": "Vélo",
    "EBikeRide": "Vélo",
    "Swim": "Natation",
    "OpenWaterSwim": "Natation",
    "WeightTraining": "Renfo",
    "Workout": "Renfo",
    "Crossfit": "Renfo",
    "AlpineSki": "Ski",
    "BackcountrySki": "Ski",
    "NordicSki": "Ski",
    # Tout le reste → "Autre"
}


class StravaTokenRefreshError(Exception):
    pass


# ===== TOKEN MANAGEMENT =====

def get_valid_strava_token(user: User, db: Session) -> str:
    """Retourne un access token Strava valide, refresh + persiste si nécessaire."""
    if user.strava_expires_at and user.strava_expires_at > time.time() + 300:
        return user.strava_access_token

    response = requests.post(
        STRAVA_TOKEN_URL,
        data={
            "client_id": settings.strava_client_id,
            "client_secret": settings.strava_client_secret,
            "grant_type": "refresh_token",
            "refresh_token": user.strava_refresh_token,
        },
    )
    if response.status_code != 200:
        raise StravaTokenRefreshError(f"Strava token refresh failed: {response.status_code} {response.text}")

    tokens = response.json()
    user.strava_access_token = tokens["access_token"]
    user.strava_refresh_token = tokens["refresh_token"]
    user.strava_expires_at = tokens["expires_at"]
    db.commit()
    return user.strava_access_token


# ===== APPELS API STRAVA =====

def fetch_activities(token: str, after_ts: int | None = None, limit: int | None = None) -> list[dict]:
    headers = {"Authorization": f"Bearer {token}"}
    results: list[dict] = []
    page = 1

    while True:
        params: dict = {"per_page": 200, "page": page}
        if after_ts:
            params["after"] = after_ts

        response = requests.get(f"{STRAVA_API_BASE}/athlete/activities", headers=headers, params=params)
        if response.status_code != 200:
            break

        batch = response.json()
        if not batch:
            break

        results.extend(batch)

        if limit and len(results) >= limit:
            results = results[:limit]
            break

        if len(batch) < 200:
            break
        page += 1

    return results


def fetch_activity_streams(activity_id: int, token: str) -> dict | None:
    headers = {"Authorization": f"Bearer {token}"}
    params = {"keys": "heartrate,velocity_smooth", "key_by_type": True}
    response = requests.get(
        f"{STRAVA_API_BASE}/activities/{activity_id}/streams",
        headers=headers, params=params,
    )
    return response.json() if response.status_code == 200 else None


# ===== CALCUL DE CHARGE =====

def get_charge_coefficient(hr: float, fc_max: float, sport_factor: float) -> float:
    hr_percent = (hr / fc_max) * 100
    if hr_percent < HR_ZONES_PCT[1][0]:
        return 0.0
    for zone_num in range(1, 6):
        min_pct, max_pct = HR_ZONES_PCT[zone_num]
        if min_pct <= hr_percent < max_pct:
            progress = (hr_percent - min_pct) / (max_pct - min_pct)
            w_start = BASE_ZONE_WEIGHTS_PER_MIN[zone_num]
            w_end = BASE_ZONE_WEIGHTS_PER_MIN[zone_num + 1] if zone_num < 5 else w_start * 1.2
            return (w_start + progress * (w_end - w_start)) / 60.0 * sport_factor
    return BASE_ZONE_WEIGHTS_PER_MIN[5] * 1.2 / 60.0 * sport_factor


def get_fc_max_by_sport(sport_type: str, fc_max_run: float) -> int:
    factors = {
        "Ride": BIKE_FC_FACTOR,
        "VirtualRide": BIKE_FC_FACTOR,
        "MountainBikeRide": BIKE_FC_FACTOR,
        "GravelRide": BIKE_FC_FACTOR,
        "EBikeRide": BIKE_FC_FACTOR,
        "Swim": SWIM_FC_FACTOR,
        "OpenWaterSwim": SWIM_FC_FACTOR,
    }
    factor = factors.get(sport_type, 1.0)
    return int(fc_max_run * factor)


def calculate_charge(hr_data: list[float], sport_type: str, fc_max_run: float) -> float:
    fc_max = get_fc_max_by_sport(sport_type, fc_max_run)
    factor = SPORT_FACTORS.get(sport_type, 1.00)
    return sum(get_charge_coefficient(hr, fc_max, factor) for hr in hr_data)


def compute_pr_from_velocity(velocity_data: list[float], target_km: float) -> int | None:
    target_m = target_km * 1000
    n = len(velocity_data)

    cum = [0.0] * (n + 1)
    for i in range(n):
        cum[i + 1] = cum[i] + velocity_data[i]

    if cum[n] < target_m:
        return None

    best_time = None
    for i in range(n):
        lo, hi = i, n
        while lo < hi:
            mid = (lo + hi) // 2
            if cum[mid] - cum[i] >= target_m:
                hi = mid
            else:
                lo = mid + 1
        j = lo
        if j <= n and cum[j] - cum[i] >= target_m:
            elapsed = j - i
            if best_time is None or elapsed < best_time:
                best_time = elapsed

    return best_time


def update_user_prs_from_activity(user: User, activity: Activity) -> None:
    if not activity.velocity_data:
        return
    if SPORT_TYPE_TO_GROUP.get(activity.sport_type) != "Course":
        return

    velocity = json.loads(activity.velocity_data)

    if not activity.duration_min:
        return
    expected_pts = activity.duration_min * 60
    ratio = len(velocity) / expected_pts
    if ratio < 0.90:
        return  # stream sous-échantillonné → ignorer

    targets = [
        (5.0, "pr_5k_sec"),
        (10.0, "pr_10k_sec"),
        (21.0975, "pr_semi_sec"),
        (42.195, "pr_marathon_sec"),
    ]

    for target_km, field in targets:
        if activity.distance_km and activity.distance_km < target_km * 0.95:
            continue
        best = compute_pr_from_velocity(velocity, target_km)
        if best:
            current = getattr(user, field)
            if not current or best < current:
                setattr(user, field, best)


# ===== SYNC PRINCIPAL =====

def sync_activities(user: User, token: str, db: Session, limit: int | None = None, years_back: int = 2) -> tuple[int, int]:
    date_limit = datetime.now(timezone.utc) - timedelta(days=365 * years_back)
    date_limit_ts = int(date_limit.timestamp())

    if not user.fc_max:
        return 0, 0
    fc_max = user.fc_max

    last_activity = (
        db.query(Activity)
        .filter_by(user_id=user.id)
        .order_by(Activity.start_date.desc())
        .first()
    )

    after_ts = date_limit_ts
    if last_activity:
        last_date = last_activity.start_date.replace(hour=0, minute=0, second=0, microsecond=0)
        last_ts = int(last_date.replace(tzinfo=timezone.utc).timestamp())
        after_ts = max(date_limit_ts, last_ts)

    activities = fetch_activities(token, after_ts=after_ts, limit=limit)

    new_count = 0
    updated_count = 0

    for i, a in enumerate(activities, 1):
        strava_id = a["id"]
        sport_type = a.get("sport_type", "Run")

        streams = fetch_activity_streams(strava_id, token)
        time.sleep(0.5)

        hr_data = None
        velocity_data = None
        charge = None

        if streams:
            if "heartrate" in streams:
                hr_data = json.dumps(streams["heartrate"]["data"])
                charge = calculate_charge(streams["heartrate"]["data"], sport_type, fc_max)
            if "velocity_smooth" in streams:
                velocity_data = json.dumps(streams["velocity_smooth"]["data"])

        if SPORT_TYPE_TO_GROUP.get(sport_type) == "Course":
            temp = Activity(
                sport_type=sport_type,
                distance_km=round(a["distance"] / 1000, 2),
                velocity_data=velocity_data,
                duration_min=round(a["moving_time"] / 60, 1),
            )
            update_user_prs_from_activity(user, temp)

        existing = db.query(Activity).filter_by(strava_id=strava_id).first()
        if existing:
            existing.name = a["name"]
            existing.sport_type = sport_type
            existing.distance_km = round(a["distance"] / 1000, 2)
            existing.duration_min = round(a["moving_time"] / 60, 1)
            existing.avg_hr = a.get("average_heartrate")
            existing.total_elevation = a.get("total_elevation_gain")
            existing.charge_load = round(charge, 2) if charge else None
            existing.hr_data = hr_data
            existing.velocity_data = velocity_data
            updated_count += 1
        else:
            new_act = Activity(
                strava_id=strava_id,
                user_id=user.id,
                name=a["name"],
                sport_type=sport_type,
                start_date=datetime.strptime(a["start_date"], "%Y-%m-%dT%H:%M:%SZ"),
                distance_km=round(a["distance"] / 1000, 2),
                duration_min=round(a["moving_time"] / 60, 1),
                avg_hr=a.get("average_heartrate"),
                total_elevation=a.get("total_elevation_gain"),
                charge_load=round(charge, 2) if charge else None,
                hr_data=hr_data,
                velocity_data=velocity_data,
            )
            db.add(new_act)
            new_count += 1

        if i % 20 == 0:
            db.commit()

    db.commit()
    return new_count, updated_count


def repair_missing_charge(user: User, token: str, db: Session) -> int:
    """Recalcule charge_load pour les activités qui n'en ont pas (ex: sync interrompu)."""
    missing = db.query(Activity).filter_by(user_id=user.id, charge_load=None).all()

    fixed = 0
    for i, act in enumerate(missing, 1):
        streams = fetch_activity_streams(act.strava_id, token)
        time.sleep(0.5)

        if streams and "heartrate" in streams and user.fc_max:
            hr_data = streams["heartrate"]["data"]
            charge = calculate_charge(hr_data, act.sport_type, user.fc_max)
            act.charge_load = round(charge, 2)
            fixed += 1

        if i % 20 == 0:
            db.commit()

    db.commit()
    return fixed
