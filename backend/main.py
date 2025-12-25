from fastapi import FastAPI
from .routers import users, games, reviews, batch, views, stats
from .database import engine, Base

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Game Portal API")

app.include_router(users.router)
app.include_router(games.router)
app.include_router(reviews.router)
app.include_router(batch.router)
app.include_router(views.router)
app.include_router(stats.router)

@app.get("/")
def root():
    return {"message": "Game Portal API is running!"}