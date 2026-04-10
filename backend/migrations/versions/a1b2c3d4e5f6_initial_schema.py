"""initial schema

Revision ID: a1b2c3d4e5f6
Revises:
Create Date: 2026-04-09

"""
from alembic import op
import sqlalchemy as sa


revision = 'a1b2c3d4e5f6'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'restaurant',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=50), nullable=True),
        sa.Column('street_address', sa.String(length=50), nullable=True),
        sa.Column('description', sa.String(length=250), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_table(
        'review',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('restaurant', sa.Integer(), nullable=True),
        sa.Column('user_name', sa.String(length=30), nullable=True),
        sa.Column('rating', sa.Integer(), nullable=True),
        sa.Column('review_text', sa.String(length=500), nullable=True),
        sa.Column('review_date', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['restaurant'], ['restaurant.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )


def downgrade():
    op.drop_table('review')
    op.drop_table('restaurant')
