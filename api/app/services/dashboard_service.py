import statistics
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session, load_only

from app.models import Activity, User
from app.services.strava_service import SPORT_TYPE_TO_GROUP

PERIOD_WEEKS = {"3m": 13, "6m": 26, "1y": 52, "2y": 104, "all": None}
PERIOD_DAYS = {"3m": 90, "6m": 182, "1y": 365, "2y": 730, "all": None}

METRICS = ("charge", "distance", "duration")
ZONE_KEYS = ("Z1", "Z2", "Z3", "Z4", "Z5")

_METRIC_COLUMNS = {"charge": "charge_load", "distance": "distance_km", "duration": "duration_min"}
_ZONE_COLUMNS = {"Z1": "z1_min", "Z2": "z2_min", "Z3": "z3_min", "Z4": "z4_min", "Z5": "z5_min"}


def _week_label(dt: datetime) -> str:
    return dt.strftime("S%W %Y")


def _week_sort_key(label: str) -> tuple[str, int]:
    week_part, year_part = label.split(" ")
    return year_part, int(week_part[1:])


def build_weekly_dashboard(user: User, db: Session, period: str = "1y") -> dict:
    max_weeks = PERIOD_WEEKS.get(period, 52)

    acts = (
        db.query(Activity)
        .filter_by(user_id=user.id)
        .options(
            load_only(
                Activity.start_date,
                Activity.sport_type,
                Activity.charge_load,
                Activity.distance_km,
                Activity.duration_min,
                Activity.z1_min,
                Activity.z2_min,
                Activity.z3_min,
                Activity.z4_min,
                Activity.z5_min,
                Activity.below_z1_min,
            )
        )
        .order_by(Activity.start_date.asc())
        .all()
    )

    # weekly[metric][week_label][group] = total for that metric/week/sport-group
    weekly: dict[str, dict[str, dict[str, float]]] = {m: defaultdict(lambda: defaultdict(float)) for m in METRICS}
    # zone_weekly[week_label][zone_or_below_z1] = total minutes, all sports combined
    zone_weekly: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    groups: set[str] = set()

    for a in acts:
        if not a.start_date:
            continue
        week_label = _week_label(a.start_date)
        group = SPORT_TYPE_TO_GROUP.get(a.sport_type, "Autre")
        groups.add(group)

        for metric, column in _METRIC_COLUMNS.items():
            value = getattr(a, column)
            if value:
                weekly[metric][week_label][group] += value
                weekly[metric][week_label]["Tout"] += value

        for zone, column in _ZONE_COLUMNS.items():
            value = getattr(a, column)
            if value:
                zone_weekly[week_label][zone] += value
        if a.below_z1_min:
            zone_weekly[week_label]["below_z1"] += a.below_z1_min

    all_weeks = sorted({w for m in weekly.values() for w in m} | zone_weekly.keys(), key=_week_sort_key)
    sport_types = ["Tout"] + sorted(groups)

    series_all = {
        metric: {st: [round(weekly[metric][w].get(st, 0), 1) for w in all_weeks] for st in sport_types}
        for metric in METRICS
    }

    moving_avg_all: dict[str, list[float]] = {}
    for metric in METRICS:
        tout_all = series_all[metric].get("Tout", [])
        ma = []
        for i in range(len(tout_all)):
            window = tout_all[max(0, i - 3):i + 1]
            ma.append(round(sum(window) / len(window), 1))
        moving_avg_all[metric] = ma

    zone_data_all: dict[str, list[float]] = {zone: [] for zone in ZONE_KEYS}
    for w in all_weeks:
        totals = zone_weekly.get(w, {})
        classified_total = sum(totals.get(z, 0) for z in ZONE_KEYS) + totals.get("below_z1", 0)
        for zone in ZONE_KEYS:
            pct = round(totals.get(zone, 0) / classified_total * 100, 1) if classified_total > 0 else 0
            zone_data_all[zone].append(pct)

    slice_start = -max_weeks if max_weeks else None
    labels = all_weeks[slice_start:] if slice_start else all_weeks
    series = {metric: {st: v[slice_start:] for st, v in series_all[metric].items()} for metric in METRICS}
    moving_avg = {
        metric: (moving_avg_all[metric][slice_start:] if slice_start else moving_avg_all[metric])
        for metric in METRICS
    }
    zone_data = {
        zone: (zone_data_all[zone][slice_start:] if slice_start else zone_data_all[zone]) for zone in ZONE_KEYS
    }

    now = datetime.now(timezone.utc)
    current_week = _week_label(now)
    last_week = _week_label(now - timedelta(weeks=1))

    charge_by_week = weekly["charge"]
    charge_current = round(charge_by_week.get(current_week, {}).get("Tout", 0), 1)
    charge_last = round(charge_by_week.get(last_week, {}).get("Tout", 0), 1)

    past_weeks = [w for w in all_weeks if w != current_week]
    avg_4w = (
        round(sum(charge_by_week.get(w, {}).get("Tout", 0) for w in past_weeks[-4:]) / 4, 1)
        if len(past_weeks) >= 4
        else 0
    )

    days_elapsed = now.weekday() + 1
    charge_projected = round(charge_current / days_elapsed * 7, 1) if days_elapsed > 0 else 0
    ratio = round((charge_projected / avg_4w * 100) - 100) if avg_4w > 0 else 0

    return {
        "labels": labels,
        "series": series,
        "moving_avg": moving_avg,
        "zone_data": zone_data,
        "sport_types": sport_types,
        "charge_current": charge_current,
        "charge_last": charge_last,
        "avg_4w": avg_4w,
        "charge_projected": charge_projected,
        "ratio": ratio,
    }


def build_daily_dashboard(user: User, db: Session, period: str = "1y") -> dict:
    max_days = PERIOD_DAYS.get(period, 365)

    acts = (
        db.query(Activity)
        .filter_by(user_id=user.id)
        .options(load_only(Activity.start_date, Activity.charge_load))
        .order_by(Activity.start_date.asc())
        .all()
    )

    daily: dict[date, float] = defaultdict(float)
    for a in acts:
        if not a.start_date or not a.charge_load:
            continue
        daily[a.start_date.date()] += a.charge_load

    if not daily:
        return {"labels": [], "daily_charge": [], "mm7": [], "band_low": [], "band_high": []}

    start_day = min(daily.keys())
    end_day = datetime.now(timezone.utc).date()

    all_days = []
    d = start_day
    while d <= end_day:
        all_days.append(d)
        d += timedelta(days=1)

    daily_series_all = [round(daily.get(d, 0), 1) for d in all_days]

    mm7_all = []
    band_low_all = []
    band_high_all = []
    for i in range(len(daily_series_all)):
        window7 = daily_series_all[max(0, i - 6):i + 1]
        mm7_all.append(round(sum(window7) / len(window7), 1))

        window28 = daily_series_all[max(0, i - 27):i + 1]
        mean28 = sum(window28) / len(window28)
        std28 = statistics.pstdev(window28) if len(window28) > 1 else 0
        band_low_all.append(round(max(0.0, mean28 - std28), 1))
        band_high_all.append(round(mean28 + std28, 1))

    slice_start = -max_days if max_days else None
    visible_days = all_days[slice_start:] if slice_start else all_days
    labels = [d.isoformat() for d in visible_days]
    daily_charge = daily_series_all[slice_start:] if slice_start else daily_series_all
    mm7 = mm7_all[slice_start:] if slice_start else mm7_all
    band_low = band_low_all[slice_start:] if slice_start else band_low_all
    band_high = band_high_all[slice_start:] if slice_start else band_high_all

    return {
        "labels": labels,
        "daily_charge": daily_charge,
        "mm7": mm7,
        "band_low": band_low,
        "band_high": band_high,
    }
