# Docker Mastery — Phase 3: Advanced Docker, CI/CD, Networking & Security

## 1. Project Overview

Phase 3 extends the earlier Docker project by introducing a more production-oriented container workflow.

The application is a small FastAPI service running with Uvicorn. The objective was to build a lightweight Docker image, automate quality checks and image publishing, understand Docker networking, and harden the container before deployment.

### Project details

| Component               | Details                           |
| ----------------------- | --------------------------------- |
| Application             | FastAPI                           |
| Application server      | Uvicorn                           |
| Language                | Python 3.12                       |
| Base image              | `python:3.12-alpine`              |
| Container engine        | Docker Engine                     |
| Development environment | Fedora Linux                      |
| CI/CD                   | GitHub Actions                    |
| Container registry      | Docker Hub                        |
| Vulnerability scanning  | Trivy                             |
| Image                   | `naikiam/docker-practice-project` |
| Application port        | `8000`                            |
| Deployment status       | Not yet deployed                  |

### Objectives

* Build a lightweight Docker image using a multi-stage Dockerfile.
* Run the application as a non-root user.
* Automate linting, testing, image building, scanning, and publishing.
* Publish versioned and traceable images to Docker Hub.
* Understand bridge networks, container DNS, port publishing, and network isolation.
* Apply container security controls and resource limits.
* Validate the published image locally before deployment.

---

## 2. Repository Structure

The relevant project structure is:

```text
phase3-advanced/
├── app/
│   └── main.py
├── .github/
│   └── workflows/
│       └── phase3-cicd.yml
├── Dockerfile
├── requirements.txt
├── requirements-dev.txt
├── test_main.py
└── README.md
```

The application code defines the API endpoints, the Dockerfile defines the container image, and the GitHub Actions workflow automates validation and image publishing.

---

## 3. Multi-Stage Docker Build

### Why multi-stage builds?

A Docker image can contain both application runtime requirements and tools required only during installation or compilation.

For example, Python packages with native extensions may require compilers and development libraries. Those tools are not necessarily needed when the application runs.

A multi-stage build separates these responsibilities:

1. The builder stage installs dependencies and uses the necessary build tools.
2. The runtime stage contains the application, its installed dependencies, and the runtime environment.

This reduces unnecessary content in the final image and separates build-time tools from runtime components.

### Dockerfile

```dockerfile
FROM python:3.12-alpine AS builder

WORKDIR /app

RUN apk add --no-cache gcc musl-dev libffi-dev

COPY requirements.txt .

RUN pip install --no-cache-dir --user -r requirements.txt


FROM python:3.12-alpine

WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /root/.local /home/appuser/.local

COPY app/ ./app

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Important Dockerfile instructions

| Instruction               | Purpose                                                                            |
| ------------------------- | ---------------------------------------------------------------------------------- |
| `FROM ... AS builder`     | Creates the dependency-building stage.                                             |
| `WORKDIR /app`            | Sets the working directory.                                                        |
| `apk add`                 | Installs Alpine build dependencies.                                                |
| `COPY requirements.txt .` | Copies the dependency manifest before application code.                            |
| `pip install --user`      | Installs Python dependencies in the builder user's local package directory.        |
| Second `FROM`             | Starts a clean runtime stage.                                                      |
| `addgroup` and `adduser`  | Create a dedicated non-root application identity.                                  |
| `COPY --from=builder`     | Copies installed dependencies from the builder stage.                              |
| `USER appuser`            | Runs the application as a non-root user.                                           |
| `EXPOSE 8000`             | Documents the intended application port. It does not publish the port to the host. |
| `HEALTHCHECK`             | Checks whether the application health endpoint responds successfully.              |
| `CMD`                     | Starts Uvicorn and binds it to all container interfaces.                           |

### Why bind Uvicorn to `0.0.0.0`?

Inside a container, binding to `127.0.0.1` would make the application listen only on the container's loopback interface.

Binding to `0.0.0.0` allows it to accept connections through the container's network interfaces, including connections forwarded through Docker port publishing.

### Dependency management

The application dependency manifest is:

```text
fastapi==0.143.0
uvicorn[standard]==0.30.1
```

The FastAPI dependency resolution supplies a compatible Starlette version. Starlette should not be independently pinned without checking compatibility with the selected FastAPI version.

Dependency versions and vulnerability findings should be reviewed whenever dependencies are updated.

### Build the image locally

```bash
docker build -t docker-mastery:phase3 .
```

Inspect local images:

```bash
docker images
```

Inspect image metadata:

```bash
docker image inspect docker-mastery:phase3
```

---

## 4. Non-Root Container Execution

Running applications as root inside containers increases the impact of certain application vulnerabilities.

The Dockerfile creates a dedicated user and group:

```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

The runtime inspection confirmed:

```text
uid=100(appuser) gid=101(appgroup) groups=101(appgroup)
```

The application is therefore running as a non-root user.

Verify the configured user with:

```bash
docker inspect phase3-hardened-check \
  --format '{{.Config.User}}'
```

Expected:

```text
appuser
```

A non-root user is an important security control, but it does not by itself make a container secure. Filesystem permissions, Linux capabilities, network exposure, resource limits, and image vulnerabilities must also be considered.

---

## 5. Application Health Checks

The application implements the following endpoints:

| Endpoint        | Purpose                                         |
| --------------- | ----------------------------------------------- |
| `/`             | Returns a welcome message.                      |
| `/health`       | Returns the application health status.          |
| `/info`         | Returns service metadata.                       |
| `/docs`         | Displays interactive Swagger API documentation. |
| `/openapi.json` | Returns the OpenAPI specification.              |

The `/docs` and `/openapi.json` endpoints are generated by FastAPI.

### Test the endpoints

```bash
curl -i http://localhost:8002/
curl -i http://localhost:8002/health
curl -i http://localhost:8002/info
curl -i http://localhost:8002/docs
curl -i http://localhost:8002/openapi.json
```

### Health-check configuration

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
```

Docker periodically executes the health-check command.

* A successful command marks the container healthy.
* Repeated failures can mark the container unhealthy.
* The health status does not automatically restart a container just because it becomes unhealthy.

Inspect health status:

```bash
docker inspect phase3-hardened-check \
  --format '{{json .State.Health}}'
```

The final local checks returned HTTP `200 OK`, and Docker reported the container as `healthy`.

---

## 6. GitHub Actions CI/CD Pipeline

The workflow file is:

```text
.github/workflows/phase3-cicd.yml
```

The pipeline automates code validation, image construction, vulnerability scanning, and publishing.

### Workflow triggers

The workflow runs on:

* Pushes to `main`.
* Pull requests targeting `main`.
* Version tags matching `v*.*.*`.

### Pipeline stages

```text
Code Push / Pull Request
          |
          v
      Checkout Code
          |
          v
   Set Up Python 3.12
          |
          v
   Install Dev Dependencies
          |
          v
       Run Flake8
          |
          v
       Run Pytest
          |
          v
     Build Docker Image
          |
          v
      Trivy Scan
          |
          v
   Scan Passed?
          |
          v
 Docker Hub Login on Push
          |
          v
      Push Image
```

The Docker image build job depends on the lint-and-test job, so it does not run if that job fails.

The actual workflow also runs for pull requests, but the Docker Hub login and publishing steps are restricted to push events.

### Code quality checks

The workflow installs development dependencies:

```yaml
- name: Install dependencies
  run: pip install -r requirements-dev.txt
```

It then runs Flake8:

```yaml
- name: Lint with flake8
  run: flake8 app test_main.py --max-line-length=100
```

And Pytest:

```yaml
- name: Run tests
  run: pytest -v
```

Linting detects selected code-quality issues. Tests validate the application's expected behavior.

### Docker Buildx

The workflow configures Docker Buildx:

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
```

Buildx provides advanced Docker build functionality, including support for build caching.

### Build caching

The workflow uses GitHub Actions cache:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

Caching can reduce build time by reusing eligible build layers across workflow runs.

---

## 7. Docker Image Tags and Versioning

The workflow uses Docker metadata actions to generate image tags.

Configured tag types include:

```yaml
tags: |
  type=raw,value=phase3
  type=sha,prefix=sha-,format=short
  type=raw,value=latest,enable={{is_default_branch}}
  type=semver,pattern={{version}}
  type=semver,pattern={{major}}.{{minor}}
  type=semver,pattern={{major}}
```

### Tag meanings

| Tag                   | Purpose                                                          |
| --------------------- | ---------------------------------------------------------------- |
| `phase3`              | Identifies the Phase 3 build.                                    |
| `sha-<short-commit>`  | Identifies a build by source commit.                             |
| `latest`              | Represents the current default-branch image when enabled.        |
| Semantic version tags | Identify release versions when a matching version tag is pushed. |

Example tags observed in Docker Hub:

```text
naikiam/docker-practice-project:phase3
naikiam/docker-practice-project:latest
naikiam/docker-practice-project:sha-bc10696
```

The exact SHA tag depends on the commit used for the build.

### Why use commit-based tags?

A mutable tag such as `latest` can point to a different image after a future push.

A commit-based tag provides a more traceable reference to the source revision that produced the image.

For reproducible deployment, record the tested image digest as well as the tag.

---

## 8. Docker Hub Publishing

The published repository is:

```text
naikiam/docker-practice-project
```

The workflow uses the Docker login action:

```yaml
- name: Log in to Docker Hub
  if: github.event_name == 'push'
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

The publishing step is:

```yaml
- name: Push Docker image to Docker Hub
  if: github.event_name == 'push'
  uses: docker/build-push-action@v6
  with:
    context: .
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### GitHub repository secrets

The workflow uses these repository secrets:

| Secret               | Contents                |
| -------------------- | ----------------------- |
| `DOCKERHUB_USERNAME` | Docker Hub username     |
| `DOCKERHUB_TOKEN`    | Docker Hub access token |

Secrets are configured under:

```text
GitHub Repository
  → Settings
  → Secrets and variables
  → Actions
```

The token should be stored as a GitHub secret, not committed to the repository or embedded in the Dockerfile.

### Pull the published image

```bash
docker pull naikiam/docker-practice-project:latest
```

### Inspect available images

```bash
docker images naikiam/docker-practice-project
```

The local validation used the published image rather than relying only on a locally built image.

---

## 9. Vulnerability Scanning with Trivy

Trivy scans the image for known vulnerabilities in operating-system packages and application libraries.

The workflow uses:

```yaml
- name: Scan Docker image with Trivy
  uses: aquasecurity/trivy-action@v0.36.0
  with:
    image-ref: naikiam/docker-practice-project:phase3
    format: table
    exit-code: "1"
    ignore-unfixed: true
    vuln-type: os,library
    severity: HIGH,CRITICAL
```

### Scan settings

| Setting                   | Meaning                                                                              |
| ------------------------- | ------------------------------------------------------------------------------------ |
| `image-ref`               | Specifies the image to scan.                                                         |
| `format: table`           | Displays results in table format.                                                    |
| `exit-code: "1"`          | Returns a failing status when the configured findings trigger the failure condition. |
| `ignore-unfixed: true`    | Ignores vulnerabilities for which a fix is unavailable.                              |
| `vuln-type: os,library`   | Scans operating-system packages and application libraries.                           |
| `severity: HIGH,CRITICAL` | Selects high- and critical-severity findings.                                        |

The workflow is configured to fail on matching findings, helping prevent a vulnerable image from proceeding to the publishing stage.

### Important limitation

A successful scan does not mean an image contains no vulnerabilities. The result depends on the vulnerability database, package metadata, selected severity levels, and scanning options.

The `ignore-unfixed` setting also means some known vulnerabilities may not cause the configured failure.

### Troubleshooting an incorrect image reference

If Trivy reports that an image cannot be found, check whether the reference matches the image name used during the build.

For example:

```text
Incorrect: docker-mastery-demo:phase3
Correct:   naikiam/docker-practice-project:phase3
```

An image-reference mismatch is different from a vulnerability finding.

### Dependency updates

When vulnerabilities are detected in Python dependencies, review the affected package and its compatibility constraints.

After updating dependencies:

1. Rebuild the image.
2. Run application tests.
3. Re-scan the image.
4. Review the findings.
5. Publish only after the configured checks pass.

---

## 10. Local Validation of the Published Image

The published image was pulled and run on Fedora.

### Start the published-image test container

```bash
docker pull naikiam/docker-practice-project:latest

docker run -d \
  --name phase3-published-check \
  -p 127.0.0.1:8001:8000 \
  naikiam/docker-practice-project:latest
```

The host port is `8001`, while the application listens on container port `8000`.

Binding to `127.0.0.1` restricts the published host port to local loopback access.

### Test the endpoint

```bash
curl -fsS http://localhost:8001/health
```

The health endpoint returned a JSON response with:

```json
{
  "status": "healthy",
  "timestamp": "..."
}
```

The timestamp varies with each request.

The published image ran successfully on the local Fedora host.

---

## 11. Docker Networking Fundamentals

Docker networking allows containers to communicate with other containers and with services outside their own network.

The networking experiments were conducted using temporary containers and user-defined bridge networks.

### 11.1 Inspect available networks

```bash
docker network ls
```

The environment included:

| Network  | Driver | Purpose                                  |
| -------- | ------ | ---------------------------------------- |
| `bridge` | Bridge | Default Docker bridge network            |
| `host`   | Host   | Uses the host network namespace          |
| `kind`   | Bridge | Existing Kind/Kubernetes cluster network |
| `none`   | Null   | Disables normal container networking     |

The `kind` network belongs to the existing Kubernetes learning environment and was preserved throughout the Phase 3 cleanup.

### 11.2 Default bridge network

Inspect the default bridge:

```bash
docker network inspect bridge
```

The observed configuration included:

```text
Subnet:  172.17.0.0/16
Gateway: 172.17.0.1
```

The published-image test container was observed with the address:

```text
172.17.0.2
```

These addresses are specific to the observed environment. Docker may allocate different addresses in another setup.

### 11.3 User-defined bridge network

Create a dedicated network:

```bash
docker network create phase3-net
```

The observed configuration was:

```text
Subnet:  172.19.0.0/16
Gateway: 172.19.0.1
```

Connect the published-image container:

```bash
docker network connect phase3-net phase3-published-check
```

Inspect the container:

```bash
docker inspect phase3-published-check \
  --format '{{json .NetworkSettings.Networks}}'
```

The container had addresses on both networks:

| Network          | Observed address |
| ---------------- | ---------------- |
| Default `bridge` | `172.17.0.2`     |
| `phase3-net`     | `172.19.0.2`     |

A container can have multiple network attachments. Each network attachment has its own network interface and address.

### 11.4 Run Nginx on the user-defined bridge

```bash
docker run -d \
  --name phase3-nginx \
  --network phase3-net \
  nginx:alpine
```

The observed Nginx address on `phase3-net` was:

```text
172.19.0.3
```

No host port was published for Nginx.

The Nginx container was accessible from other containers connected to the same network.

### 11.5 Container-name DNS

Run a temporary curl container on the same network:

```bash
docker run --rm \
  --network phase3-net \
  curlimages/curl:latest \
  -sS http://phase3-nginx
```

The request returned the Nginx welcome page.

This demonstrated that Docker's embedded DNS could resolve the container name on the user-defined bridge network.

The container name can be used instead of a hard-coded IP address. This is generally more convenient because container IP addresses can change.

### 11.6 Network isolation

Create a second network:

```bash
docker network create phase3-isolated
```

The observed subnet and gateway were:

```text
Subnet:  172.20.0.0/16
Gateway: 172.20.0.1
```

Attempt to resolve Nginx from the separate network:

```bash
docker run --rm \
  --network phase3-isolated \
  curlimages/curl:latest \
  -sS --max-time 5 http://phase3-nginx
```

The observed result was:

```text
Could not resolve host: phase3-nginx
```

Next, test the Nginx IP directly:

```bash
docker run --rm \
  --network phase3-isolated \
  curlimages/curl:latest \
  -sS --connect-timeout 3 http://172.19.0.3
```

The connection timed out in the observed lab.

These results demonstrated that the separate user-defined bridge network did not provide ordinary connectivity to Nginx through its name or IP address.

Network isolation is a useful security boundary, but it is not a substitute for a complete security policy or a guarantee against every possible route between networks.

### 11.7 Port publishing versus container networking

The application was published using:

```bash
-p 127.0.0.1:8001:8000
```

and the hardened test used:

```bash
-p 127.0.0.1:8002:8000
```

The syntax is:

```text
-p HOST_IP:HOST_PORT:CONTAINER_PORT
```

For example:

```text
127.0.0.1:8002:8000
```

means requests to host loopback port `8002` are forwarded to container port `8000`.

The Nginx lab did not need a published host port because the temporary curl container accessed it through the Docker network.

This illustrates the difference between container-to-container communication and host-to-container port publishing.

---

## 12. Container Security Hardening

After confirming that the application ran successfully, a separate hardened test container was created.

The original published-image test container was left unchanged.

### Hardened run command

```bash
docker run -d \
  --name phase3-hardened-check \
  -p 127.0.0.1:8002:8000 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --memory=256m \
  --cpus=0.5 \
  --pids-limit=100 \
  naikiam/docker-practice-project:latest
```

### Security controls

| Control                  | Purpose                                                                                                  |
| ------------------------ | -------------------------------------------------------------------------------------------------------- |
| Non-root user            | Reduces privileges of the application process.                                                           |
| `--read-only`            | Prevents writes to the container's root filesystem.                                                      |
| `--tmpfs /tmp`           | Provides explicitly writable temporary storage.                                                          |
| `--cap-drop=ALL`         | Drops Linux capabilities from the container process.                                                     |
| `no-new-privileges:true` | Prevents processes from gaining additional privileges through supported privilege-escalation mechanisms. |
| `--memory=256m`          | Sets a 256 MiB memory limit.                                                                             |
| `--cpus=0.5`             | Limits CPU usage to approximately half a CPU core.                                                       |
| `--pids-limit=100`       | Limits the number of processes and threads.                                                              |
| `-p 127.0.0.1:8002:8000` | Restricts host port publishing to loopback.                                                              |

These limits were selected for a lightweight local lab. Production limits should be chosen using workload measurements and expected traffic.

### Verify the configuration

```bash
docker inspect phase3-hardened-check \
  --format 'User: {{.Config.User}}
Privileged: {{.HostConfig.Privileged}}
Readonly rootfs: {{.HostConfig.ReadonlyRootfs}}
CapDrop: {{json .HostConfig.CapDrop}}
SecurityOpt: {{json .HostConfig.SecurityOpt}}
Memory bytes: {{.HostConfig.Memory}}
Nano CPUs: {{.HostConfig.NanoCpus}}
PIDs limit: {{.HostConfig.PidsLimit}}'
```

Observed configuration:

```text
User: appuser
Privileged: false
Readonly rootfs: true
CapDrop: ["ALL"]
SecurityOpt: ["no-new-privileges:true"]
Memory bytes: 268435456
Nano CPUs: 500000000
PIDs limit: 100
```

### Verify root filesystem behavior

Attempt to write to the application directory:

```bash
docker exec phase3-hardened-check sh -c \
  'touch /app/readonly-test'
```

Observed result:

```text
touch: /app/readonly-test: Read-only file system
```

This confirmed that the application directory was not writable.

Now test temporary storage:

```bash
docker exec phase3-hardened-check sh -c \
  'touch /tmp/writable-test && echo "Temporary storage is writable"'
```

Observed result:

```text
Temporary storage is writable
```

The temporary filesystem provides a writable location without making the container's root filesystem writable.

### Verify the running user

```bash
docker exec phase3-hardened-check id
```

Observed result:

```text
uid=100(appuser) gid=101(appgroup) groups=101(appgroup)
```

### Verify health and API responses

```bash
curl -i http://localhost:8002/
curl -i http://localhost:8002/health
curl -i http://localhost:8002/info
curl -i http://localhost:8002/docs
curl -i http://localhost:8002/openapi.json
```

All five endpoints returned `200 OK` in the observed test.

Docker reported:

```json
{
  "Status": "healthy",
  "FailingStreak": 0
}
```

### Observe resource usage

```bash
docker stats --no-stream phase3-hardened-check
```

The observed snapshot was approximately:

```text
CPU:          0.19%
Memory usage: 51.82 MiB / 256 MiB
Memory:       20.24%
PIDs:         6
```

This is a point-in-time observation, not a performance or load-test result.

---

## 13. Final Image Metadata

The following information was captured from the local image:

```text
Image:         naikiam/docker-practice-project:latest
Image ID:      sha256:6a875ac0e66f5ca73555af549d42827a2524cad3818faa0eb4d1a8fcb341f368
Created:       2026-10-09T17:53:53.094271866Z
Architecture:  amd64
OS:             linux
Size:           135355176 bytes
```

The reported size is approximately 129 MiB in binary units.

Image metadata and image IDs can change when the image is rebuilt. Record the metadata again for future releases.

---

## 14. Troubleshooting Notes

### Docker daemon is unavailable

If Docker reports that it cannot connect to the Docker socket:

```bash
sudo systemctl start docker
docker info
```

This starts the Docker service for the current session and checks whether the daemon is responding.

The local setup intentionally avoids changing Docker's startup behavior without a specific need.

### Docker socket remains active after stopping Docker

The Docker service can be activated by its socket unit.

Inspect both units:

```bash
systemctl status docker
systemctl status docker.socket
```

Service and socket activation are related but distinct. Stopping only `docker.service` may not prevent socket activation.

### Incorrect image reference in Trivy

Verify that the scan reference matches the image built by the workflow:

```text
naikiam/docker-practice-project:phase3
```

A missing or mismatched image reference is not itself evidence of a vulnerability.

### Application health check fails

Inspect logs and health status:

```bash
docker logs phase3-hardened-check

docker inspect phase3-hardened-check \
  --format '{{json .State.Health}}'
```

Check that the application starts, the expected port is correct, and the health endpoint is reachable inside the container.

### Port is already in use

Use a different host port while retaining container port `8000`.

For example:

```bash
-p 127.0.0.1:8002:8000
```

The host port and container port do not need to match.

### Read-only filesystem causes an error

A read-only root filesystem may expose application assumptions about writable directories.

Inspect the logs and identify which path needs writing. Add a temporary writable mount only where required rather than making the entire root filesystem writable by default.

### Capability dropping causes an error

`--cap-drop=ALL` is a strong baseline, but some applications may require specific capabilities.

If a workload fails, investigate the exact requirement rather than immediately granting all capabilities back.

---

## 15. Cleanup

The temporary networking resources were removed after the tests.

Commands used:

```bash
docker network disconnect phase3-net phase3-published-check

docker rm -f phase3-nginx

docker network rm phase3-net phase3-isolated
```

The resulting Docker network list contained:

```text
bridge
host
kind
none
```

The `kind` network was deliberately preserved for Kubernetes learning.

The application image was also retained.

### Current application containers

The following containers were retained for reference:

```text
phase3-hardened-check
phase3-published-check
```

Other historical containers, such as `phase2-app` and `phase3-app`, were left untouched.

### Safe cleanup principles

* Remove only containers created for the temporary lab.
* Disconnect a container from a temporary network before removing that network if needed.
* Do not delete the `kind` network.
* Do not run `docker system prune -a` as routine cleanup.
* Avoid deleting older project images and containers until you are certain they are no longer needed.

---

## 16. Final Pre-Deployment Validation

### Application validation

```bash
curl -fsS http://localhost:8001/health
echo

curl -fsS http://localhost:8002/health
echo
```

Both the published-image container and the hardened container returned healthy JSON responses.

### Image inspection

```bash
docker image inspect naikiam/docker-practice-project:latest \
  --format 'Image ID: {{.Id}}
Created: {{.Created}}
Architecture: {{.Architecture}}
OS: {{.Os}}
Size bytes: {{.Size}}'
```

### Container inspection

```bash
docker ps -a
```

### Network inspection

```bash
docker network ls
```

These checks confirm that the application image was published, retrieved, executed locally, and validated under the tested security restrictions.

---

## 17. What Is Complete and What Is Pending?

### Completed before deployment

* [x] Multi-stage Docker build.
* [x] Non-root application execution.
* [x] Application health check.
* [x] GitHub Actions linting and testing.
* [x] Automated Docker image build.
* [x] Trivy image scanning configured to fail on selected high/critical findings.
* [x] Docker Hub image publishing.
* [x] Commit-based and other image tagging.
* [x] Local validation of the published image.
* [x] User-defined bridge network and container-name DNS experiment.
* [x] Network isolation experiment.
* [x] Container hardening with a read-only root filesystem.
* [x] Linux capability dropping and privilege-escalation protection.
* [x] CPU, memory, and PID limits.
* [x] API endpoint validation.
* [x] Cleanup of temporary networking resources.

### Still pending

* [ ] Final written documentation saved in the repository.
* [ ] Optional additional load and failure testing.
* [ ] Choose a deployment platform.
* [ ] Configure deployment-specific secrets and settings.
* [ ] Deploy the image to the chosen platform.
* [ ] Validate the deployed service externally.
* [ ] Document deployment, availability, and operational behavior.

**Important:** this document covers the pre-deployment work. The application has been validated locally, but public hosting and deployment have not yet been completed.

---

## 18. Resume-Ready Project Description

### Dockerized FastAPI Application with CI/CD and Container Security

* Containerized a Python FastAPI application using a multi-stage Dockerfile and a lightweight Alpine-based runtime image.
* Built a GitHub Actions CI/CD workflow to automate linting, unit tests, Docker image builds, and Trivy vulnerability scanning.
* Published Docker images to Docker Hub using commit-based and release-oriented tags.
* Practiced Docker bridge networking, container-name DNS resolution, host port publishing, and isolation between user-defined networks.
* Hardened the application container with non-root execution, a read-only root filesystem, dropped Linux capabilities, privilege-escalation protection, and CPU/memory/PID limits.
* Validated application health and API endpoints locally using the published image and a separate hardened container configuration.

### Short version for a resume

**Docker Mastery — Advanced Containerization & CI/CD**

Built a Dockerized FastAPI application using multi-stage builds and implemented a GitHub Actions pipeline for automated testing, Trivy vulnerability scanning, and Docker Hub publishing. Practiced Docker networking and container hardening with non-root execution, read-only filesystems, dropped capabilities, and resource limits.

### How to describe the project in interviews

A concise explanation:

> I developed a containerized FastAPI application and automated its validation and image publishing through GitHub Actions. I used Trivy to scan the image for selected high- and critical-severity vulnerabilities, published versioned images to Docker Hub, and tested the published image locally. Before deployment, I also experimented with Docker bridge networking, container DNS, network isolation, and container hardening using a read-only root filesystem, dropped capabilities, and resource limits.

Do not claim the application has been deployed to production or hosted publicly until that work is complete.

---

## 19. Key Concepts Learned

| Concept                   | Practical understanding                                                   |
| ------------------------- | ------------------------------------------------------------------------- |
| Multi-stage build         | Separates dependency building from the runtime image.                     |
| Non-root user             | Runs the application with fewer privileges.                               |
| Health check              | Lets Docker report application health.                                    |
| CI/CD                     | Automates validation and publishing steps.                                |
| Image tags                | Help identify builds and releases.                                        |
| Image digest/ID           | Helps identify the exact image tested.                                    |
| Trivy                     | Scans image packages for known vulnerabilities.                           |
| Bridge network            | Connects containers through Docker-managed networking.                    |
| Docker DNS                | Allows containers on a user-defined network to resolve names.             |
| Port publishing           | Forwards a host port to a container port.                                 |
| Network isolation         | Separates containers on distinct networks under the tested configuration. |
| Read-only root filesystem | Prevents writes to the container root filesystem.                         |
| Capability dropping       | Reduces the Linux capabilities available to the container.                |
| Resource limits           | Restricts memory, CPU, and process/thread consumption.                    |

---

## 20. Conclusion

Phase 3 extended the project from basic containerization into automated image delivery, networking experiments, and runtime security hardening.

The image was published to Docker Hub and validated locally. The application continued to run under the tested security restrictions, and the temporary networking resources were removed without disturbing the existing Kind/Kubernetes environment.

The next phase is deployment. It should build on this validated configuration rather than replace the work already completed.
