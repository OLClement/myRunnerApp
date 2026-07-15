from collections import defaultdict
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models import Activity, User
from app.services.strava_service import SPORT_TYPE_TO_GROUP

PERIOD_WEEKS = {"3m": 13, "6m": 26, "1y": 52, "2y": 104, "all": None}


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
        .order_by(Activity.start_date.asc())
        .all()
    )

    weekly: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    groups: set[str] = set()

    for a in acts:
        if not a.start_date:
            continue
        week_label = _week_label(a.start_date)
        group = SPORT_TYPE_TO_GROUP.get(a.sport_type, "Autre")
        groups.add(group)
        if a.charge_load:
            weekly[week_label][group] += a.charge_load
            weekly[week_label]["Tout"] += a.charge_load

    all_weeks = sorted(weekly.keys(), key=_week_sort_key)
    sport_types = ["Tout"] + sorted(groups)

    weekly_data_all = {st: [round(weekly[w].get(st, 0), 1) for w in all_weeks] for st in sport_types}

    tout_all = weekly_data_all.get("Tout", [])
    moving_avg_all = []
    for i in range(len(tout_all)):
        window = tout_all[max(0, i - 3):i + 1]
        moving_avg_all.append(round(sum(window) / len(window), 1))

    slice_start = -max_weeks if max_weeks else None
    labels = all_weeks[slice_start:] if slice_start else all_weeks
    weekly_data = {st: v[slice_start:] for st, v in weekly_data_all.items()}
    moving_avg = moving_avg_all[slice_start:] if slice_start else moving_avg_all

    now = datetime.now(timezone.utc)
    current_week = _week_label(now)
    last_week = _week_label(now - timedelta(weeks=1))

    charge_current = round(weekly.get(current_week, {}).get("Tout", 0), 1)
    charge_last = round(weekly.get(last_week, {}).get("Tout", 0), 1)

    past_weeks = [w for w in all_weeks if w != current_week]
    avg_4w = round(sum(weekly[w]["Tout"] for w in past_weeks[-4:]) / 4, 1) if len(past_weeks) >= 4 else 0

    days_elapsed = now.weekday() + 1
    charge_projected = round(charge_current / days_elapsed * 7, 1) if days_elapsed > 0 else 0
    ratio = round((charge_projected / avg_4w * 100) - 100) if avg_4w > 0 else 0

    return {
        "labels": labels,
        "weekly_data": weekly_data,
        "moving_avg": moving_avg,
        "sport_types": sport_types,
        "charge_current": charge_current,
        "charge_last": charge_last,
        "avg_4w": avg_4w,
        "charge_projected": charge_projected,
        "ratio": ratio,
    }
