"""seed default workout templates

Revision ID: 9eea66f3a625
Revises: e33a90cc0bb3
Create Date: 2026-07-16 07:50:08.861029

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9eea66f3a625'
down_revision: Union[str, Sequence[str], None] = 'e33a90cc0bb3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# user_id NULL = template global, visible à tous les utilisateurs.
TEMPLATES = [
    {"name": "Sortie longue Z2", "sport_type": "Run", "duration_min": 90, "zone": "Z2",
     "description": "Endurance fondamentale, allure conversationnelle, à plat ou faible dénivelé."},
    {"name": "Fractionné VMA", "sport_type": "Run", "duration_min": 45, "zone": "Z4",
     "description": "10-12 x 400m à allure VMA, récupération trot égale au temps d'effort."},
    {"name": "Seuil", "sport_type": "Run", "duration_min": 50, "zone": "Z3",
     "description": "20-30 min continues à allure seuil (tempo), encadrées d'échauffement/retour au calme."},
    {"name": "Récup active", "sport_type": "Run", "duration_min": 30, "zone": "Z1",
     "description": "Footing très facile, objectif récupération, pas de contrainte d'allure."},
    {"name": "Sortie vélo endurance", "sport_type": "Ride", "duration_min": 90, "zone": "Z2",
     "description": "Sortie longue à faible intensité, cadence régulière."},
    {"name": "Renfo général", "sport_type": "WeightTraining", "duration_min": 40, "zone": "Mixte",
     "description": "Circuit renforcement musculaire général (gainage, bas du corps, haut du corps)."},
]


def upgrade() -> None:
    """Upgrade schema."""
    templates_table = sa.table(
        "workout_templates",
        sa.column("user_id", sa.Integer),
        sa.column("name", sa.String),
        sa.column("sport_type", sa.String),
        sa.column("duration_min", sa.Integer),
        sa.column("zone", sa.String),
        sa.column("description", sa.Text),
    )
    op.bulk_insert(
        templates_table,
        [{**t, "user_id": None} for t in TEMPLATES],
    )


def downgrade() -> None:
    """Downgrade schema."""
    conn = op.get_bind()
    for t in TEMPLATES:
        conn.execute(
            sa.text(
                "DELETE FROM workout_templates WHERE user_id IS NULL AND name = :name"
            ),
            {"name": t["name"]},
        )
