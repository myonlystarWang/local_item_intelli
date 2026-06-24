"""add authorized devices

Revision ID: 20260623_1410
Revises: 20260623_1348
Create Date: 2026-06-23 14:10:00
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "20260623_1410"
down_revision: Union[str, None] = "20260623_1348"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "authorized_devices",
        sa.Column("uuid", sa.String(length=100), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("registered_at", sa.DateTime(), nullable=False),
        sa.Column("last_sync_at", sa.DateTime(), nullable=True),
        sa.Column("remark", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("uuid"),
    )
    op.create_index(op.f("ix_authorized_devices_uuid"), "authorized_devices", ["uuid"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_authorized_devices_uuid"), table_name="authorized_devices")
    op.drop_table("authorized_devices")
