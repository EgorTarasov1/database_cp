from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List

from ..database import get_db
from ..schemas import *

router = APIRouter(prefix="/stats", tags=["Statistics & Analytics"])


@router.get("/game/{game_id}/rating", response_model=GameRatingResponse)
def get_game_rating_endpoint(game_id: int, db: Session = Depends(get_db)):
    result = db.execute(text("SELECT get_game_rating(:game_id)"), {"game_id": game_id})
    rating = result.scalar()
    if rating is None:
        raise HTTPException(status_code=404, detail="Game not found or no approved reviews")
    return {"rating": float(rating)}


@router.get("/user/{user_id}/total-hours", response_model=UserTotalHoursResponse)
def get_user_total_hours_endpoint(user_id: int, db: Session = Depends(get_db)):
    result = db.execute(text("SELECT get_user_total_hours(:user_id)"), {"user_id": user_id})
    total_hours = result.scalar()
    return {"total_hours": total_hours or 0}


@router.get("/top-players/genre/{genre_name}", response_model=List[TopPlayerByGenre])
def get_top_players_by_genre_endpoint(genre_name: str, db: Session = Depends(get_db)):
    result = db.execute(
        text("SELECT * FROM get_top_players_by_genre(:genre_name)"),
        {"genre_name": genre_name}
    )
    rows = result.mappings().all()
    if not rows:
        raise HTTPException(status_code=404, detail="No players found for this genre")
    return rows


@router.get("/user-activity", response_model=List[UserActivityEntry])
def get_user_activity_endpoint(
    start_date: date,
    end_date: date,
    db: Session = Depends(get_db)
):
    if start_date > end_date:
        raise HTTPException(status_code=400, detail="start_date cannot be after end_date")

    result = db.execute(
        text("SELECT * FROM get_user_activity(:start, :end)"),
        {"start": start_date, "end": end_date}
    )
    rows = result.mappings().all()
    return rows