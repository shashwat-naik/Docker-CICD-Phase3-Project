# Phase 2 — Intermediate Docker & CI/CD

Phase 2 focused on moving from a basic Docker container to a more realistic development workflow using **slim Python images, multi-stage builds, automated testing, linting, GitHub Actions, and Docker build caching**.

---

## 1. Phase 2 Objective

The objective was to improve the Phase 1 Docker project by introducing:

* Smaller/base-purpose Docker images
* Multi-stage builds
* Separation of production and development dependencies
* `.dockerignore`
* Automated testing with `pytest`
* Code quality checks with `flake8`
* Git/GitHub workflow
* GitHub Actions CI
* Docker build automation
* Docker layer caching

The overall flow became:

```text
Developer
    │
    ▼
Write application code
    │
    ├── pytest
    │
    └── flake8
    │
    ▼
Git commit
    │
    ▼
GitHub push
    │
    ▼
GitHub Actions
    │
    ├── Lint
    ├── Test
    │
    ▼
Docker Build
```

---

# 2. Project Structure

The Phase 2 GitHub repository contains:

```text
Docker-CICD-Phase2-Project/
│
├── app/
│   └── main.py
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── .dockerignore
├── .gitignore
├── Dockerfile
├── README.md
├── requirements.txt
├── requirements-dev.txt
└── test_main.py
```

---

# 3. Application

The application is a small FastAPI API.

Endpoints:

```text
GET /
GET /health
GET /info
```

Example:

```text
/
```

returns information about the application and its current phase.

The `/health` endpoint provides a simple health response:

```json
{
  "status": "healthy"
}
```

The `/info` endpoint provides application metadata.

---

# 4. Production Dependencies

`requirements.txt` contains only dependencies required to run the application:

```text
fastapi==0.111.0
uvicorn[standard]==0.30.1
```

This distinction is important.

The production Docker image doesn't need:

```text
pytest
flake8
httpx
```

because those are development/testing tools.

---

# 5. Development Dependencies

`requirements-dev.txt` contains:

```text
-r requirements.txt
flake8==7.1.0
httpx==0.27.0
pytest==8.2.2
```

This allows the local development environment and CI environment to install everything needed for testing without putting those tools into the production image.

---

# 6. `.dockerignore`

We created:

```text
__pycache__/
*.pyc
*.pyo
.git
.gitignore
.github
.venv/
venv/
.env
.pytest_cache/
README.md
test_main.py
requirements-dev.txt
```

The purpose is to reduce the Docker build context and prevent unnecessary/development files from being sent to the Docker builder.

Important distinction:

```text
.dockerignore
      ↓
controls Docker build context
```

It does **not** delete those files from Fedora.

For example:

```text
.venv/
```

still exists locally, but Docker doesn't receive it during the build.

---

# 7. Multi-Stage Docker Build

The biggest Docker improvement in Phase 2 was moving from the Phase 1 single-stage Ubuntu image to:

```dockerfile
FROM python:3.12-slim AS builder
```

followed by:

```dockerfile
FROM python:3.12-slim
```

Conceptually:

```text
             Dockerfile
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
   Builder stage     Runtime stage
        │                 │
   Install packages      App
        │                 │
   Build dependencies    Runtime only
        │                 │
        └───────┬─────────┘
                ▼
          Final image
```

The builder stage installs the Python dependencies.

The runtime stage receives only the required installed packages and application code.

---

# 8. Why `pip install --user`?

We used:

```dockerfile
RUN pip install --no-cache-dir --user -r requirements.txt
```

This installs the Python packages into:

```text
/root/.local
```

Then:

```dockerfile
COPY --from=builder /root/.local /root/.local
```

copies those installed packages into the runtime image.

We then added:

```dockerfile
ENV PATH=/root/.local/bin:$PATH
```

so executables such as:

```text
uvicorn
```

can be found.

---

# 9. Why `python:3.12-slim`?

Instead of:

```dockerfile
FROM ubuntu:22.04
```

we used:

```dockerfile
FROM python:3.12-slim
```

This gives us a Python-focused runtime without having to manually install Python and pip through Ubuntu's package manager.

The Phase 2 image was around:

```text
259 MB
```

compared with the much heavier Phase 1 design.

The important lesson isn't simply:

> "slim is smaller."

It's:

> Use a base image appropriate for the application and avoid carrying unnecessary build/runtime components.

---

# 10. Local Virtual Environment

We created:

```text
.venv/
```

for local Python development.

Activation:

```bash
source .venv/bin/activate
```

This explained an important difference:

```text
Python venv
     ↓
isolates Python packages on the host
```

while:

```text
Docker
     ↓
isolates the application environment in a container
```

We also experienced what happens when the virtual environment isn't activated:

```text
pytest: command not found
```

Fedora offered to install a system-level `python3-pytest`.

We avoided that and activated the project's `.venv` instead.

---

# 11. Automated Testing

We created:

```text
test_main.py
```

with three tests:

```text
test_root
test_health
test_info
```

Running:

```bash
pytest -v
```

gave:

```text
3 passed
```

This established a repeatable way of verifying that the application works.

---

# 12. Code Quality — Flake8

We ran:

```bash
flake8 app test_main.py
```

Initially Flake8 reported:

```text
E501 line too long
```

Two lines exceeded the configured line length.

We reformatted them and ran Flake8 again.

Result:

```text
Flake8 passed
```

This demonstrated that CI should catch not only application failures but also code-quality issues.

---

# 13. Docker Image Build

We built:

```bash
docker build -t docker-mastery:phase2 .
```

The image was tagged:

```text
docker-mastery:phase2
```

We also inspected the image using:

```bash
docker images
docker history docker-mastery:phase2
```

This helped us understand that Docker images consist of layers rather than being one monolithic file.

---

# 14. Running the Container

We ran:

```bash
docker run -d \
  --name phase2-app \
  -p 8001:8000 \
  docker-mastery:phase2
```

This means:

```text
Fedora host
   │
   │ port 8001
   ▼
Docker container
   │
   │ port 8000
   ▼
Uvicorn
   │
   ▼
FastAPI
```

The application listens inside the container on:

```text
8000
```

while Fedora exposes:

```text
8001
```

Therefore:

```text
http://localhost:8001
```

reaches:

```text
container:8000
```

---

# 15. Container Logs

We used:

```bash
docker logs phase2-app
```

and saw:

```text
Uvicorn running on http://0.0.0.0:8000
```

We also observed:

```text
GET / 200
GET /favicon.ico 404
```

The favicon `404` wasn't an application failure.

The browser automatically requested:

```text
/favicon.ico
```

and our API doesn't provide that endpoint.

---

# 16. `docker run` vs `docker start`

We also accidentally created another container without specifying a name.

Docker generated a random name such as:

```text
dazzling_chatterjee
```

This helped demonstrate:

### `docker run`

Creates a **new container**.

```bash
docker run ...
```

### `docker start`

Starts an **existing stopped container**.

```bash
docker start phase2-app
```

### `docker stop`

Stops the container.

```bash
docker stop phase2-app
```

### `docker rm`

Removes the container.

```bash
docker rm phase2-app
```

---

# 17. Docker and Fedora Restart Behavior

After a Fedora restart, the container was found in an exited state.

We also learned about the relationship between:

```text
docker.service
docker.socket
```

Running:

```bash
sudo systemctl stop docker
```

showed that:

```text
docker.socket
```

could remain active.

We later used:

```bash
sudo systemctl disable --now docker.socket
```

when discussing how Docker socket activation works.

Most importantly, we kept the existing Kind/Kubernetes Docker resources untouched.

---

# 18. Git Repository

We initialized Git inside the Phase 2 directory:

```bash
git init
```

The branch was changed to:

```text
main
```

We configured Git and created:

```text
.gitignore
```

to prevent things such as:

```text
.venv/
__pycache__/
.pytest_cache/
```

from entering the repository.

Then:

```bash
git add .
git commit
git push
```

was used to publish the project to GitHub.

Repository:

```text
Docker-CICD-Phase2-Project
```

---

# 19. GitHub Actions CI

We created:

```text
.github/workflows/ci.yml
```

The pipeline contains two jobs:

```text
lint-and-test
      │
      ▼
build-image
```

The second job contains:

```yaml
needs: lint-and-test
```

Therefore the Docker image isn't built if linting/testing fails.

The pipeline became:

```text
GitHub Push
     │
     ▼
Checkout
     │
     ▼
Python 3.12
     │
     ▼
Install dev dependencies
     │
     ├──────────────┐
     ▼              ▼
  Flake8          Pytest
     │              │
     └──────┬───────┘
            ▼
          PASS
            │
            ▼
      Docker Build
```

The image is built but **not pushed** to a registry in Phase 2:

```yaml
push: false
```

Registry publishing is intentionally reserved for Phase 3.

---

# 20. Bug We Created — CI Didn't Run

Our initial workflow assumed the GitHub repository had:

```text
phase2-intermediate/
```

inside it.

The workflow contained:

```yaml
paths:
  - "phase2-intermediate/**"
```

and:

```yaml
working-directory: phase2-intermediate
```

and:

```yaml
context: phase2-intermediate
```

But the actual GitHub repository itself **was** the Phase 2 directory.

Actual repository:

```text
Docker-CICD-Phase2-Project/
├── Dockerfile
├── app/
├── requirements.txt
└── ...
```

There was no:

```text
Docker-CICD-Phase2-Project/phase2-intermediate/
```

So the workflow didn't trigger as expected.

### Fix

We changed the workflow to operate from the repository root:

```yaml
on:
  push:
    branches: ["main"]

  pull_request:
    branches: ["main"]
```

and:

```yaml
context: .
```

After pushing the fix, GitHub Actions successfully executed.

### Lesson

Always understand:

```text
repository structure
        +
workflow paths
        +
working directory
        +
Docker build context
```

They must agree with each other.

---

# 21. Bug We Intentionally Created — Failed CI

We deliberately changed:

```python
assert response.status_code == 200
```

to:

```python
assert response.status_code == 201
```

The application correctly returned:

```text
200
```

but our test expected:

```text
201
```

Therefore:

```bash
pytest -v
```

failed.

We pushed the broken test to GitHub.

GitHub Actions then showed:

```text
Lint & Test       ❌
Build Docker      ⏭️
```

because:

```yaml
needs: lint-and-test
```

prevented the Docker build from running.

This was intentional and demonstrated the CI gate.

---

# 22. Fixing the Broken CI

We changed:

```python
assert response.status_code == 201
```

back to:

```python
assert response.status_code == 200
```

Then locally:

```bash
pytest -v
```

passed.

We also ran:

```bash
flake8 app test_main.py --max-line-length=100
```

and it passed.

Then:

```bash
git add test_main.py
git commit -m "Test: Fix root endpoint assertion"
git push
```

GitHub Actions became:

```text
Lint & Test        ✅
Build Docker Image ✅
```

### The complete failure/recovery flow

```text
Developer change
      │
      ▼
Wrong test assertion
      │
      ▼
Local pytest ❌
      │
      ▼
Push to GitHub
      │
      ▼
GitHub Actions
      │
      ▼
Lint/Test ❌
      │
      ▼
Docker Build BLOCKED
      │
      ▼
Fix assertion
      │
      ▼
Local pytest ✅
      │
      ▼
Push again
      │
      ▼
Lint/Test ✅
      │
      ▼
Docker Build ✅
```

This is an important real-world CI/CD pattern.

---

# 23. Docker Build Cache Experiment

We then deliberately tested Docker's layer caching.

## Baseline

```bash
docker build -t docker-mastery:phase2 .
```

Docker reused layers such as:

```text
CACHED [builder 2/4] WORKDIR /app
CACHED [builder 3/4] COPY requirements.txt .
CACHED [builder 4/4] RUN pip install ...
```

---

# 24. Experiment 1 — Application Change

We changed only the application message in:

```text
app/main.py
```

The dependency-related layers remained cached:

```text
CACHED COPY requirements.txt
CACHED RUN pip install
CACHED COPY dependencies
```

while:

```text
COPY app/ ./app
```

was rebuilt.

This demonstrated:

```text
Application change
       ↓
app layer rebuilt
       ↓
dependencies remain cached
```

---

# 25. Experiment 2 — Dependency Change

We temporarily added:

```text
requests==2.32.3
```

to:

```text
requirements.txt
```

Then rebuilt.

This time:

```text
COPY requirements.txt
```

was no longer cached.

Therefore:

```text
COPY requirements.txt
       ↓
pip install
       ↓
COPY dependencies
```

had to be rebuilt.

The `pip install` step alone took around:

```text
21 seconds
```

and the total build took around:

```text
29 seconds
```

compared with approximately:

```text
2–3 seconds
```

for the cached/application-only build.

We then removed the temporary `requests` dependency.

---

# 26. Why Dockerfile Ordering Matters

Our Dockerfile intentionally uses:

```dockerfile
COPY requirements.txt .

RUN pip install --no-cache-dir --user -r requirements.txt

COPY app/ ./app
```

rather than:

```dockerfile
COPY . .

RUN pip install ...
```

The first approach allows Docker to reuse the dependency layer when only application code changes.

Conceptually:

```text
             requirements.txt
                    │
                    ▼
             pip install
                    │
                    ▼
          installed dependencies
                    │
                    ▼
                app code
```

If only:

```text
app/main.py
```

changes:

```text
dependencies → CACHE ✅
app          → REBUILD 🔨
```

If:

```text
requirements.txt
```

changes:

```text
dependencies → REBUILD 🔨
```

This is a major practical Docker optimization.

---

# 27. Important Concepts Learned

By the end of Phase 2, we covered:

### Docker

* Docker image
* Docker container
* Dockerfile
* Docker layers
* Multi-stage builds
* Build context
* `.dockerignore`
* Docker cache
* `docker build`
* `docker run`
* `docker start`
* `docker stop`
* `docker rm`
* `docker logs`
* `docker history`
* Port mapping
* Container networking

### Python

* Virtual environments
* `pip`
* Production dependencies
* Development dependencies
* Pytest
* Flake8

### Git

* Repository initialization
* `.gitignore`
* Staging
* Commits
* Branches
* Remote repository
* Push/pull workflow

### CI/CD

* GitHub Actions
* Workflow YAML
* Jobs
* Steps
* Triggers
* `needs`
* CI gates
* Automated linting
* Automated testing
* Automated Docker builds
* Failure detection
* Failure recovery

---

# 28. Phase 1 vs Phase 2

| Area               | Phase 1      | Phase 2                   |
| ------------------ | ------------ | ------------------------- |
| Base image         | Ubuntu       | Python Slim               |
| Python setup       | Manual       | Built into image          |
| Docker build       | Single-stage | Multi-stage               |
| Dependencies       | Basic        | Production/dev separation |
| `.dockerignore`    | No           | Yes                       |
| Testing            | Manual       | Pytest                    |
| Linting            | No           | Flake8                    |
| Git                | Basic/none   | GitHub repository         |
| CI                 | No           | GitHub Actions            |
| Docker build in CI | No           | Yes                       |
| Registry           | No           | No                        |
| Security scanning  | No           | No                        |
| Non-root user      | No           | No                        |
| AWS deployment     | No           | No                        |

---

# 29. Phase 2 Architecture

The final Phase 2 concept is:

```text
                    GitHub
                      │
                  git push
                      │
                      ▼
              GitHub Actions
                      │
             ┌────────┴────────┐
             │                 │
             ▼                 ▼
          Flake8             Pytest
             │                 │
             └────────┬────────┘
                      │
                   Success
                      │
                      ▼
                Docker Build
                      │
                      ▼
             docker-mastery:phase2
                      │
                      ▼
                  Fedora
                      │
                      ▼
               Docker Engine
                      │
                      ▼
                phase2-app
                      │
                host :8001
                      │
                      ▼
                 FastAPI
```

---

# 30. Phase 2 Final Outcome

The project has now moved from:

```text
"Can I run my application inside Docker?"
```

to:

```text
"Can I reliably develop, test, lint, build,
and validate my Docker application automatically?"
```

That's the purpose of Phase 2.

The next phase will move beyond **building and validating** into **security, image publishing, and deployment**.

---

## Phase 3 — Advanced

When you're ready, say **"Start Phase 3"** and we'll begin from **Step 1**, designing the Phase 3 architecture before changing any files.
