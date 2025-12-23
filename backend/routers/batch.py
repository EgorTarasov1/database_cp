from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models import Game
from ..schemas import GameCreate

router = APIRouter(
    prefix="/batch",
    tags=["Batch"]
)


@router.post("/games")
def batch_insert_games(
    games: List[GameCreate],
    db: Session = Depends(get_db)
):
    inserted = 0

    for game in games:
        if db.query(Game).filter(Game.title == game.title).first():
            continue
        db.add(Game(**game.dict()))
        inserted += 1

    db.commit()
    return {"inserted_games": inserted}
