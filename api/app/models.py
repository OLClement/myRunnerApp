from datetime import datetime, timezone

from sqlalchemy import BigInteger, Boolean, Column, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.db import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    email = Column(String(255), unique=True, nullable=True)
    strava_athlete_id = Column(BigInteger, unique=True, nullable=False)
    strava_access_token = Column(String(255), nullable=True)
    strava_refresh_token = Column(String(255), nullable=True)
    strava_expires_at = Column(BigInteger, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    fc_max = Column(Integer, nullable=True, default=195)
    activities = relationship("Activity", backref="user", lazy=True)

    pr_5k_sec = Column(Integer, nullable=True)
    pr_10k_sec = Column(Integer, nullable=True)
    pr_semi_sec = Column(Integer, nullable=True)
    pr_marathon_sec = Column(Integer, nullable=True)

    def __repr__(self) -> str:
        return f"<User strava_id={self.strava_athlete_id}>"


class Activity(Base):
    __tablename__ = "activities"

    id = Column(Integer, primary_key=True)
    strava_id = Column(BigInteger, unique=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(255))
    sport_type = Column(String(100))
    start_date = Column(DateTime)
    distance_km = Column(Float)
    duration_min = Column(Float)
    avg_hr = Column(Float)
    total_elevation = Column(Float)
    charge_load = Column(Float)
    hr_data = Column(Text, nullable=True)  # JSON list de FC
    velocity_data = Column(Text, nullable=True)  # JSON list de vitesse

    def __repr__(self) -> str:
        return f"<Activity {self.name} - {self.sport_type}>"


class WorkoutTemplate(Base):
    __tablename__ = "workout_templates"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # None = template global
    name = Column(String(255), nullable=False)
    sport_type = Column(String(100))
    duration_min = Column(Integer, nullable=True)
    zone = Column(String(20), nullable=True)  # Z1, Z2, Z3, Z4, Z5, Mixte
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=_utcnow)

    planned = relationship("PlannedWorkout", backref="template", lazy=True)

    def __repr__(self) -> str:
        return f"<WorkoutTemplate {self.name}>"


class PlannedWorkout(Base):
    __tablename__ = "planned_workouts"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    template_id = Column(Integer, ForeignKey("workout_templates.id"), nullable=False)
    planned_date = Column(Date, nullable=True)  # null = dans le pool
    week_start = Column(Date, nullable=True)  # lundi de la semaine
    status = Column(String(20), default="planned")  # planned / done / missed
    strava_activity_id = Column(BigInteger, nullable=True)  # pour matching futur
    custom_name = Column(String(255), nullable=True)  # override nom template
    notes = Column(Text, nullable=True)  # notes spécifiques
    created_at = Column(DateTime, default=_utcnow)

    def __repr__(self) -> str:
        return f"<PlannedWorkout template={self.template_id} date={self.planned_date}>"


class PrepPlan(Base):
    __tablename__ = "prep_plans"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(255), nullable=False)  # "Semi Paris avril 2027"
    race_type = Column(String(50), nullable=False)  # 10k / semi / marathon / trail
    race_date = Column(Date, nullable=False)
    start_date = Column(Date, nullable=True)  # date de début de la prépa
    goal_time = Column(String(20), nullable=True)  # "1h45"
    sessions_per_week = Column(Integer, nullable=False)
    cross_sports = Column(Text, nullable=True)  # JSON dict {"Vélo": 2, "Trail": 1}
    status = Column(String(20), default="active")  # active / done / archived
    created_at = Column(DateTime, default=_utcnow)
    fitness_level = Column(String(20), nullable=True, default="intermédiaire")
    contexte = Column(Text, nullable=True)  # contexte libre utilisateur
    weeks = relationship("PrepWeek", backref="plan", lazy=True, cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<PrepPlan {self.name}>"


class PrepWeek(Base):
    __tablename__ = "prep_weeks"

    id = Column(Integer, primary_key=True)
    plan_id = Column(Integer, ForeignKey("prep_plans.id"), nullable=False)
    week_number = Column(Integer, nullable=False)  # 1, 2, 3...
    week_start = Column(Date, nullable=True)  # date du lundi
    week_type = Column(String(50), nullable=True)  # construction / intensité / récup / affûtage
    description = Column(Text, nullable=True)  # résumé macro LLM
    target_load = Column(Float, nullable=True)  # charge cible
    actual_load = Column(Float, nullable=True)  # charge réelle Strava
    imported = Column(Boolean, default=False)  # importé dans F1 ?
    bloc = Column(String(50), nullable=True)  # base / construction / spécifique / affûtage / course

    def __repr__(self) -> str:
        return f"<PrepWeek plan={self.plan_id} w={self.week_number}>"
