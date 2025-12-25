from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models import Review as ReviewModel
from ..models import Game
from ..schemas import Review as ReviewSchema, ReviewCreate

router = APIRouter(prefix="/reviews", tags=["Reviews"])


@router.post("/user/{user_id}", response_model=ReviewSchema)
def add_review(user_id: int, review: ReviewCreate, db: Session = Depends(get_db)):
    game = db.query(Game).filter(Game.game_id == review.game_id).first()
    if not game:
        raise HTTPException(status_code=404, detail="Game not found")

    db_review = ReviewModel(**review.dict(), user_id=user_id)
    db.add(db_review)
    db.commit()
    db.refresh(db_review)
    return db_review


@router.get("/game/{game_id}", response_model=List[ReviewSchema])
def get_game_reviews(game_id: int, db: Session = Depends(get_db)):
    reviews = (
        db.query(ReviewModel)
        .filter(ReviewModel.game_id == game_id, ReviewModel.is_approved == True)
        .all()
    )
    return reviews