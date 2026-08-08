from collections import defaultdict
from datetime import date, datetime, time, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session, load_only

from app.db import get_db
from app.deps import get_current_user
from app.models import Activity, PlannedWorkout, User, WorkoutTemplate
from app.schemas import (
    PlannedWorkoutCreate,
    PlannedWorkoutMatch,
    PlannedWorkoutOut,
    PlannedWorkoutUpdate,
    WorkoutTemplateOut,
)
from app.services.strava_service import SPORT_TYPE_TO_GROUP

router = APIRouter(prefix="/planning", tags=["planning"])


def _sport_group(sport_type: str | None) -> str:
    return SPORT_TYPE_TO_GROUP.get(sport_type, "Autre")


@router.get("/templates", response_model=list[WorkoutTemplateOut])
def list_templates(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[WorkoutTemplate]:
    return (
        db.query(WorkoutTemplate)
        .filter(
            or_(WorkoutTemplate.user_id.is_(None), WorkoutTemplate.user_id == current_user.id),
            WorkoutTemplate.is_reusable.is_(True),
        )
        .order_by(WorkoutTemplate.name)
        .all()
    )


def _to_planned_out(planned: PlannedWorkout) -> PlannedWorkoutOut:
    template = planned.template
    return PlannedWorkoutOut(
        id=planned.id,
        template_id=planned.template_id,
        planned_date=planned.planned_date,
        status=planned.status,
        matched_activity_id=planned.matched_activity_id,
        custom_name=planned.custom_name,
        notes=planned.notes,
        template_name=planned.custom_name or template.name,
        sport_type=template.sport_type,
        duration_min=template.duration_min,
        zone=template.zone,
    )


@router.get("/planned", response_model=list[PlannedWorkoutOut])
def list_planned(
    start: date,
    end: date,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[PlannedWorkoutOut]:
    planned = (
        db.query(PlannedWorkout)
        .filter(
            PlannedWorkout.user_id == current_user.id,
            PlannedWorkout.planned_date >= start,
            PlannedWorkout.planned_date <= end,
        )
        .order_by(PlannedWorkout.planned_date)
        .all()
    )

    activities = (
        db.query(Activity)
        .filter(
            Activity.user_id == current_user.id,
            Activity.start_date >= datetime.combine(start, time.min),
            Activity.start_date <= datetime.combine(end, time.max),
        )
        # hr_data/velocity_data sont de gros JSON texte non utilisés ici (seuls id/start_date/
        # sport_type servent au matching plan-vs-actual) : les exclure évite de transférer des
        # Mo inutiles depuis Supabase à chaque appel.
        .options(load_only(Activity.id, Activity.start_date, Activity.sport_type))
        .all()
    )
    activities_by_day: dict[date, list[Activity]] = defaultdict(list)
    for a in activities:
        if a.start_date is not None:
            activities_by_day[a.start_date.date()].append(a)

    # Plan vs actual : même jour + même groupe de sport -> match auto si candidat unique ; si
    # ambigu (plusieurs candidats), on laisse l'utilisateur choisir côté mobile (POST /match) ;
    # si aucun candidat et la date est passée, la séance "manquée" est simplement masquée.
    claimed_activity_ids = {p.matched_activity_id for p in planned if p.matched_activity_id is not None}
    today = date.today()
    result: list[PlannedWorkout] = []
    dirty = False

    for p in planned:
        if p.matched_activity_id is not None or p.planned_date is None:
            result.append(p)
            continue

        group = _sport_group(p.template.sport_type)
        candidates = [
            a
            for a in activities_by_day.get(p.planned_date, [])
            if a.id not in claimed_activity_ids and _sport_group(a.sport_type) == group
        ]

        if len(candidates) == 1:
            p.matched_activity_id = candidates[0].id
            p.status = "done"
            claimed_activity_ids.add(candidates[0].id)
            dirty = True
            result.append(p)
        elif len(candidates) == 0 and p.planned_date < today:
            continue
        else:
            result.append(p)

    if dirty:
        db.commit()

    return [_to_planned_out(p) for p in result]


@router.post("/planned", response_model=PlannedWorkoutOut, status_code=status.HTTP_201_CREATED)
def create_planned(
    payload: PlannedWorkoutCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlannedWorkoutOut:
    if payload.template_id is not None:
        template = (
            db.query(WorkoutTemplate)
            .filter(
                WorkoutTemplate.id == payload.template_id,
                or_(WorkoutTemplate.user_id.is_(None), WorkoutTemplate.user_id == current_user.id),
            )
            .first()
        )
        if template is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")
    else:
        # "From scratch" : la contrainte NOT NULL sur template_id impose de créer un
        # WorkoutTemplate — is_reusable contrôle juste s'il apparaît dans le picker ensuite.
        template = WorkoutTemplate(
            user_id=current_user.id,
            name=payload.name,
            sport_type=payload.sport_type,
            duration_min=payload.duration_min,
            zone=payload.zone,
            is_reusable=payload.keep_as_template,
        )
        db.add(template)
        db.flush()

    week_start = (
        payload.planned_date - timedelta(days=payload.planned_date.weekday())
        if payload.planned_date is not None
        else None
    )
    planned = PlannedWorkout(
        user_id=current_user.id,
        template_id=template.id,
        planned_date=payload.planned_date,
        week_start=week_start,
        status="planned",
    )
    db.add(planned)
    db.commit()
    db.refresh(planned)
    return _to_planned_out(planned)


@router.get("/pool", response_model=list[PlannedWorkoutOut])
def list_pool(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[PlannedWorkoutOut]:
    planned = (
        db.query(PlannedWorkout)
        .filter(PlannedWorkout.user_id == current_user.id, PlannedWorkout.planned_date.is_(None))
        .order_by(PlannedWorkout.created_at)
        .all()
    )
    return [_to_planned_out(p) for p in planned]


@router.patch("/planned/{planned_id}", response_model=PlannedWorkoutOut)
def update_planned(
    planned_id: int,
    payload: PlannedWorkoutUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlannedWorkoutOut:
    planned = (
        db.query(PlannedWorkout)
        .filter(PlannedWorkout.id == planned_id, PlannedWorkout.user_id == current_user.id)
        .first()
    )
    if planned is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Planned workout not found")
    planned.planned_date = payload.planned_date
    planned.week_start = payload.planned_date - timedelta(days=payload.planned_date.weekday())
    db.commit()
    db.refresh(planned)
    return _to_planned_out(planned)


@router.post("/planned/{planned_id}/match", response_model=PlannedWorkoutOut)
def match_planned(
    planned_id: int,
    payload: PlannedWorkoutMatch,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlannedWorkoutOut:
    planned = (
        db.query(PlannedWorkout)
        .filter(PlannedWorkout.id == planned_id, PlannedWorkout.user_id == current_user.id)
        .first()
    )
    if planned is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Planned workout not found")
    activity = (
        db.query(Activity)
        .filter(Activity.id == payload.activity_id, Activity.user_id == current_user.id)
        .options(load_only(Activity.id))
        .first()
    )
    if activity is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Activity not found")
    planned.matched_activity_id = activity.id
    planned.status = "done"
    db.commit()
    db.refresh(planned)
    return _to_planned_out(planned)


@router.delete("/planned/{planned_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_planned(
    planned_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    planned = (
        db.query(PlannedWorkout)
        .filter(PlannedWorkout.id == planned_id, PlannedWorkout.user_id == current_user.id)
        .first()
    )
    if planned is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Planned workout not found")
    db.delete(planned)
    db.commit()
