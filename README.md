# Phase 3 — Advanced: Production-Style CI/CD

## Goal
A fast, secure, cache-optimized CI/CD pipeline that builds, tests, scans, tags, and publishes the FastAPI image to **both** Docker Hub and AWS ECR automatically.

---

## What's Inside
```
phase3-advanced/
├── app/
│   └── main.py
├── requirements.txt
├── requirements-dev.txt
├── test_main.py
├── Dockerfile                          # multi-stage, alpine base, non-root user, HEALTHCHECK
├── .dockerignore
├── .github/workflows/ci-cd.yml         # full pipeline: lint → test → build → scan → push
└── README.md
```

---

## How the Dockerfile Differs from Phase 2

Phase 3 goes further on security and size:

- **Alpine base** (`python:3.12-alpine`) — even smaller than slim, typically ~80–120MB final image
- **Non-root user** — the app runs as an unprivileged user inside the container, not as root. If the container is ever compromised, the attacker has limited permissions
- **`HEALTHCHECK`** — Docker periodically runs a health check command inside the container and marks it healthy/unhealthy. Orchestrators like Kubernetes or ECS use this to decide whether to restart or route traffic to the container

---

## Build & Run Locally
```bash
cd phase3-advanced
docker build -t docker-mastery:phase3 .
docker run -d --name phase3-app -p 8000:8000 docker-mastery:phase3

# Check the HEALTHCHECK status (wait ~30s after start)
docker inspect --format='{{json .State.Health}}' phase3-app
```

---

## Required GitHub Secrets
Set these in your repo: **Settings → Secrets and variables → Actions**

| Secret | Purpose |
|---|---|
| `DOCKERHUB_USERNAME` | Your Docker Hub username or org name |
| `DOCKERHUB_TOKEN` | Docker Hub access token (not your password — create one at hub.docker.com/settings/security) |
| `AWS_ROLE_TO_ASSUME` | IAM role ARN that the pipeline assumes via OIDC to push to ECR |

> Secrets are encrypted and only injected into the runner at runtime. They are never visible in logs or to other workflows.

> **OIDC auth for AWS**: instead of storing long-lived AWS access keys as secrets, the pipeline uses GitHub's OpenID Connect (OIDC) token to prove its identity to AWS and temporarily assume an IAM role. No static AWS credentials are stored anywhere in the repo.

---

## How the CI/CD Pipeline Works (`.github/workflows/ci-cd.yml`)

### What triggers it
The pipeline fires on every push to `main` that touches files in `phase3-advanced/`, and also on Git tags (e.g. `v1.2.0`) for versioned releases.

### What the GitHub runner does

GitHub spins up a **fresh ubuntu-latest VM** for each job. The jobs run in this order:

---

**Stage 1: Lint & Test**
- Checks out the repo, sets up Python, installs dev dependencies
- Runs `flake8` for style/error checking
- Runs `pytest` to verify all API endpoints work correctly
- If either fails, the pipeline stops here — no image is built or pushed

---

**Stage 2: Build (with cache)**
```yaml
cache-from: type=gha
cache-to: type=gha, mode=max
```
- Uses `docker/build-push-action` with **GitHub Actions cache** (`type=gha`) as the cache backend
- Docker layers that haven't changed since the last run are pulled from cache instead of rebuilt
- This makes repeat builds significantly faster — if only your app code changed, the dependency installation layer is reused

> `push: false` at this stage — the image is built and stored in the runner's local Docker daemon but not pushed yet. It must pass scanning first.

---

**Stage 3: Scan (Trivy)**
- Trivy scans the built image for known CVEs (vulnerabilities) in OS packages and Python dependencies
- If any CRITICAL or HIGH vulnerabilities are found, the pipeline **fails before pushing**
- This ensures nothing insecure is ever published to a registry

---

**Stage 4: Tag**
Every image gets multiple tags for traceability:
- `:<commit-sha>` — links the image to the exact commit that produced it (e.g. `docker-mastery:a3f9c12`)
- `:latest` — always points to the most recent build from main
- `:v1.2.0` — added when the pipeline is triggered by a Git tag, for versioned releases

---

**Stage 5: Push**
The same scanned, tagged image is pushed to **two registries**:
- **Docker Hub** — public registry, authenticated with `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN`
- **AWS ECR** — private registry, authenticated via OIDC role assumption (no stored AWS keys)

Pushing to both in one pipeline run ensures both registries are always in sync.

---

## Docker Hub — Published Image

![Docker Hub](../images/docker-phase3.png)

## Try It End-to-End
1. Push a commit touching `phase3-advanced/**` on `main` → pipeline lints, tests, builds, scans, and pushes `:latest` + `:<sha>` to both registries
2. Create and push a Git tag: `git tag v1.2.0 && git push origin v1.2.0` → pipeline additionally pushes `:v1.2.0`

---

## Core Concepts Demonstrated
- **Alpine + non-root + HEALTHCHECK**: security and reliability hardening in the Dockerfile
- **Build cache (`type=gha`)**: reuse unchanged layers across pipeline runs — faster CI
- **Trivy vulnerability scanning**: mandatory security gate before any image is published
- **Meaningful tagging**: SHA for traceability, `latest` for convenience, semver for releases
- **Dual registry push**: same image, same tags, published to both public and private registries
- **OIDC AWS auth**: temporary credentials via identity federation — no static keys stored anywhere
- **GitHub Secrets**: encrypted values injected at runtime, never exposed in logs

---

## Comparing All Three Phases

| | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|
| Base image | `ubuntu:22.04` | `python:3.12-slim` | `python:3.12-alpine` |
| Build | Single-stage | Multi-stage | Multi-stage, non-root, HEALTHCHECK |
| Automation | None (manual CLI) | Basic CI (lint/test/build) | Full CI/CD (cache, scan, tag, push) |
| Registries | None | None | Docker Hub + AWS ECR |
| Security | None | None | Trivy scan, OIDC auth, GitHub Secrets |
| Approx. image size | 400–600MB+ | ~150–180MB | ~80–120MB |

> Actual sizes vary by machine/Docker version — run `docker images` to get exact numbers.
