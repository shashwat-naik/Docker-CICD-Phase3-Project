from datetime import datetime, timezone

from fastapi import FastAPI

app = FastAPI(
    title="Docker Mastery Demo API",
    description="A tiny FastAPI service used to demonstrate Docker across three maturity phases.",
    version="1.2.0",
)


@app.get("/")
def root():
    """Root endpoint - simple welcome message."""
    return {
        "message": "Welcome to the Docker Mastery Demo API",
        "phase": "3 - advanced",
        "status": "running",
    }


@app.get("/health")
def health():
    """Health check endpoint - used by the container HEALTHCHECK and CI smoke tests."""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/info")
def info():
    """Basic metadata about the running service."""
    return {
        "app": "docker-mastery-demo",
        "version": app.version,
        "phase": "3 - advanced",
    }
