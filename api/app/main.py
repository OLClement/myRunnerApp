from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import activities, auth, dashboard

app = FastAPI(title="MyRunner API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(activities.router)
app.include_router(dashboard.router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
