from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models import Game as GameModel
from ..schemas import Game as GameSchema, GameCreate

router = APIRouter(
    prefix="/games",
    tags=["Games"]
)


@router.post("/", response_model=GameSchema)
def create_game(game: GameCreate, db: Session = Depends(get_db)):
    existing_game = (
        db.query(GameModel)
        .filter(GameModel.title == game.title)
        .first()
    )
    if existing_game:
        raise HTTPException(status_code=400, detail="Game already exists")

    new_game = GameModel(**game.dict())
    db.add(new_game)
    db.commit()
    db.refresh(new_game)
    return new_game


@router.get("/{game_id}", response_model=GameSchema)
def get_game(game_id: int, db: Session = Depends(get_db)):
    game = db.query(GameModel).filter(GameModel.game_id == game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")
    return game


@router.get("/", response_model=List[GameSchema])
def get_games(db: Session = Depends(get_db)):
    return db.query(GameModel).all()
