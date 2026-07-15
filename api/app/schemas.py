from datetime import datetime

from pydantic import BaseModel, ConfigDict


class RefreshRequest(BaseModel):
    refresh_token: str


class AccessTokenResponse(BaseModel):
    access_token: str


class ActivityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    strava_id: int
    name: str | None
    sport_type: str | None
    start_date: datetime | None
    distance_km: float | None
    duration_min: float | None
    avg_hr: float | None
    total_elevation: float | None
    charge_load: float | None


class SyncResult(BaseModel):
    new: int
    updated: int


class RepairResult(BaseModel):
    fixed: int


class DashboardOut(BaseModel):
    labels: list[str]
    weekly_data: dict[str, list[float]]
    moving_avg: list[float]
    sport_types: list[str]
    charge_current: float
    charge_last: float
    avg_4w: float
    charge_projected: float
    ratio: float
