from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List

from ..database import get_db
from ..schemas import (
    GameRatingView,
    UserStatsView,
    PopularGameView
)

router = APIRouter(
    prefix="/views",
    tags=["Views (read-only)"]
)


@router.get("/game-ratings", response_model=List[GameRatingView])
def get_game_ratings(db: Session = Depends(get_db)):
    result = db.execute(text("select * from game_ratings_view"))
    return result.mappings().all()


@router.get("/user-stats", response_model=List[UserStatsView])
def get_user_stats(db: Session = Depends(get_db)):
    result = db.execute(text("select * from user_stats_view"))
    return result.mappings().all()


@router.get("/popular-games", response_model=List[PopularGameView])
def get_popular_games(db: Session = Depends(get_db)):
    result = db.execute(text("select * from popular_games_view"))
    return result.mappings().all()
