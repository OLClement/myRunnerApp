from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, model_validator


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


class ActivityDetailOut(BaseModel):
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
    z1_min: float | None
    z2_min: float | None
    z3_min: float | None
    z4_min: float | None
    z5_min: float | None
    below_z1_min: float | None
    hr_data: str | None
    velocity_data: str | None


class SyncResult(BaseModel):
    new: int
    updated: int


class RepairResult(BaseModel):
    fixed: int


class SettingsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    fc_max: int | None
    pr_5k_sec: int | None
    pr_10k_sec: int | None
    pr_semi_sec: int | None
    pr_marathon_sec: int | None


class SettingsUpdate(BaseModel):
    fc_max: int | None = None
    pr_5k_sec: int | None = None
    pr_10k_sec: int | None = None
    pr_semi_sec: int | None = None
    pr_marathon_sec: int | None = None


class WorkoutTemplateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    sport_type: str | None
    duration_min: int | None
    zone: str | None
    description: str | None


class PlannedWorkoutCreate(BaseModel):
    template_id: int | None = None
    planned_date: date | None = None

    # Champs "from scratch" — utilisés seulement quand template_id est absent.
    name: str | None = None
    sport_type: str | None = None
    duration_min: int | None = None
    zone: str | None = None
    keep_as_template: bool = False

    @model_validator(mode="after")
    def _check_template_or_scratch(self) -> "PlannedWorkoutCreate":
        if (self.template_id is None) == (self.name is None):
            raise ValueError("Provide either template_id or name (from-scratch), not both/neither")
        return self


class PlannedWorkoutUpdate(BaseModel):
    planned_date: date


class PlannedWorkoutMatch(BaseModel):
    activity_id: int


class PlannedWorkoutOut(BaseModel):
    id: int
    template_id: int
    planned_date: date | None
    status: str
    matched_activity_id: int | None
    custom_name: str | None
    notes: str | None
    template_name: str
    sport_type: str | None
    duration_min: int | None
    zone: str | None


class DashboardOut(BaseModel):
    labels: list[str]
    series: dict[str, dict[str, list[float]]]
    moving_avg: dict[str, list[float]]
    zone_data: dict[str, list[float]]
    sport_types: list[str]
    charge_current: float
    charge_last: float
    avg_4w: float
    charge_projected: float
    ratio: float


class DailyDashboardOut(BaseModel):
    labels: list[str]
    daily_charge: list[float]
    mm7: list[float]
    band_low: list[float]
    band_high: list[float]
