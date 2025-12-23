from pydantic import BaseModel, ConfigDict
from datetime import date, datetime
from typing import Optional

class UserBase(BaseModel):
    username: str
    email: str

class UserCreate(UserBase):
    password_hash: str

class User(UserBase):
    user_id: int
    registration_date: date
    is_active: bool

    class Config:
        from_attributes = True

class GameBase(BaseModel):
    title: str
    description: str
    release_date: Optional[date] = None

class GameCreate(GameBase):
    developer_id: Optional[int] = None
    publisher_id: Optional[int] = None

class Game(GameBase):
    game_id: int
    created_at: datetime

    class Config:
        from_attributes = True

class ReviewBase(BaseModel):
    rating: int
    review_text: str

class ReviewCreate(ReviewBase):
    game_id: int

class Review(ReviewBase):
    review_id: int
    user_id: int
    game_id: int
    created_at: datetime
    is_approved: bool

    class Config:
        from_attributes = True

class GameRatingView(BaseModel):
    game_id: int
    title: str
    release_date: date | None
    average_rating: float
    review_count: int

    class Config:
        from_attributes = True

class UserStatsView(BaseModel):
    user_id: int
    username: str
    registration_date: date
    total_games: int
    completed_games: int
    total_hours: int

    class Config:
        from_attributes = True


class PopularGameView(BaseModel):
    game_id: int
    title: str
    players_count: int
    average_rating: float | None

    class Config:
        from_attributes = True

class GameUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    release_date: Optional[date] = None
    developer_id: Optional[int] = None
    publisher_id: Optional[int] = None

class GameOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    game_id: int
    title: str
    description: str | None
    release_date: date
    developer_id: int
    publisher_id: int
