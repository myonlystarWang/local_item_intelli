"""initial MVP schema baseline

Revision ID: 20260623_1248
Revises:
Create Date: 2026-06-23 12:48:00
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "20260623_1248"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "tools",
        sa.Column("code", sa.String(length=50), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("model", sa.String(length=100), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("use_count", sa.Integer(), nullable=False),
        sa.Column("lifespan_limit", sa.Integer(), nullable=False),
        sa.Column("location", sa.String(length=100), nullable=True),
        sa.Column("operator", sa.String(length=50), nullable=False),
        sa.Column("last_update_time", sa.DateTime(), nullable=False),
        sa.Column("checkout_time", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("code"),
    )
    op.create_index(op.f("ix_tools_code"), "tools", ["code"], unique=False)

    op.create_table(
        "accessories",
        sa.Column("barcode", sa.String(length=50), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("spec", sa.String(length=100), nullable=False),
        sa.Column("unit", sa.String(length=10), nullable=False),
        sa.Column("safety_stock", sa.Integer(), nullable=False),
        sa.Column("current_stock", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("barcode"),
    )
    op.create_index(op.f("ix_accessories_barcode"), "accessories", ["barcode"], unique=False)

    op.create_table(
        "dictionaries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("dict_type", sa.String(length=30), nullable=False),
        sa.Column("dict_value", sa.String(length=100), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_dictionaries_id"), "dictionaries", ["id"], unique=False)

    op.create_table(
        "sync_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("terminal_uuid", sa.String(length=100), nullable=False),
        sa.Column("timestamp", sa.DateTime(), nullable=False),
        sa.Column("type", sa.String(length=20), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("source_time", sa.String(length=50), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_sync_logs_id"), "sync_logs", ["id"], unique=False)
    op.create_index(op.f("ix_sync_logs_terminal_uuid"), "sync_logs", ["terminal_uuid"], unique=False)

    op.create_table(
        "tool_histories",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("tool_code", sa.String(length=50), nullable=False),
        sa.Column("timestamp", sa.DateTime(), nullable=False),
        sa.Column("type", sa.String(length=50), nullable=False),
        sa.Column("detail", sa.Text(), nullable=False),
        sa.Column("operator", sa.String(length=50), nullable=False),
        sa.ForeignKeyConstraint(["tool_code"], ["tools.code"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_tool_histories_id"), "tool_histories", ["id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_tool_histories_id"), table_name="tool_histories")
    op.drop_table("tool_histories")
    op.drop_index(op.f("ix_sync_logs_terminal_uuid"), table_name="sync_logs")
    op.drop_index(op.f("ix_sync_logs_id"), table_name="sync_logs")
    op.drop_table("sync_logs")
    op.drop_index(op.f("ix_dictionaries_id"), table_name="dictionaries")
    op.drop_table("dictionaries")
    op.drop_index(op.f("ix_accessories_barcode"), table_name="accessories")
    op.drop_table("accessories")
    op.drop_index(op.f("ix_tools_code"), table_name="tools")
    op.drop_table("tools")
