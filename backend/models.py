from sqlalchemy import Column, Integer, String, Text, Date, Boolean, ForeignKey, DateTime, func, Numeric, \
    CheckConstraint, true
from sqlalchemy.orm import relationship
from .database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    registration_date = Column(Date, server_default=func.current_date())
    is_active = Column(Boolean, server_default=true(), default=True)
    bio = Column(Text)
    total_hours = Column(Integer, server_default="0", default=0)

    progress = relationship(
        "UserGameProgress",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )
    reviews = relationship(
        "Review",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )


class Game(Base):
    __tablename__ = "games"

    game_id = Column(Integer, primary_key=True, index=True)
    title = Column(String(100), unique=True, nullable=False)
    description = Column(Text, nullable=False)
    release_date = Column(Date)
    company_id = Column(Integer, ForeignKey("companies.company_id", ondelete="RESTRICT"), nullable=False)
    created_at = Column(DateTime, server_default=func.current_timestamp())
    average_rating = Column(Numeric(3, 2), server_default="0.0", default=0.0)
    review_count = Column(Integer, server_default="0", default=0)

    company = relationship("Company", back_populates="games")

    progress = relationship(
        "UserGameProgress",
        back_populates="game",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    reviews = relationship(
        "Review",
        back_populates="game",
        cascade="all, delete-orphan",
        passive_deletes=True
    )


class Company(Base):
    __tablename__ = "companies"

    company_id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    founded_year = Column(Integer)
    country = Column(String(50))
    website = Column(String(255))
    created_at = Column(DateTime, server_default=func.current_timestamp())
    games = relationship("Game", back_populates="company")


class UserGameProgress(Base):
    __tablename__ = "user_game_progress"

    progress_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    game_id = Column(Integer, ForeignKey("games.game_id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), nullable=False)
    hours_played = Column(Integer, server_default="0")
    last_played = Column(DateTime)
    last_updated = Column(DateTime, server_default=func.current_timestamp())

    user = relationship("User", back_populates="progress")
    game = relationship("Game", back_populates="progress")


class Review(Base):
    __tablename__ = "reviews"

    review_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    game_id = Column(Integer, ForeignKey("games.game_id", ondelete="CASCADE"), nullable=False)
    rating = Column(Integer, nullable=False)
    review_text = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.current_timestamp())
    is_approved = Column(Boolean, server_default=true(), default=True)

    user = relationship("User", back_populates="reviews")
    game = relationship("Game", back_populates="reviews")