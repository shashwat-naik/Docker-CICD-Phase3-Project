# =========================================================
# PHASE 3 - ADVANCED
# Multi-stage, Alpine-based, non-root, with a HEALTHCHECK.
# Designed to be built, cached, scanned, tagged, and pushed
# to Docker Hub by the CI/CD pipeline in
# .github/workflows/ci-cd.yml
# =========================================================

# ---------- Stage 1: Builder ----------
FROM python:3.12-alpine AS builder

WORKDIR /app

# Build-time only dependencies needed to compile some Python wheels on Alpine
RUN apk add --no-cache gcc musl-dev libffi-dev

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt


# ---------- Stage 2: Runtime ----------
FROM python:3.12-alpine

WORKDIR /app

# Create a dedicated, unprivileged user to run the app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only the installed packages (no compilers/build tools) + app code
COPY --from=builder /root/.local /home/appuser/.local
COPY app/ ./app

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

# Drop root privileges
USER appuser

EXPOSE 8000

# Container-level health check hitting the /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
