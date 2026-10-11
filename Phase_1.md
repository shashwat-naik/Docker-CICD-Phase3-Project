# Docker Mastery Project — Phase 1: Beginner

## 1. Objective

The objective of Phase 1 was to understand the fundamentals of containerizing a Python/FastAPI application using Docker.

The application was packaged using a **generic Ubuntu 22.04 base image**. Python, pip, application dependencies, and application code were installed manually inside the Docker image.

### Learning objectives

* Understand Docker images and containers
* Understand the purpose of a Dockerfile
* Understand Docker image layers
* Understand Docker build context
* Understand Docker layer caching
* Understand `EXPOSE` vs port publishing
* Run a FastAPI application inside a container
* Understand container processes and PID 1
* Understand basic Docker networking
* Understand the difference between a Python virtual environment and a Docker container
* Understand the limitations of a basic Docker image

---

# 2. Application Architecture

The application is a small FastAPI service.

It provides three endpoints:

```text
GET /
GET /health
GET /info
```

The basic architecture is:

```text
Fedora Host
    |
    | docker build
    v
Docker Image
    |
    | docker run
    v
Docker Container
    |
    +-- Ubuntu 22.04
    +-- Python 3.10
    +-- pip
    +-- FastAPI
    +-- Uvicorn
    +-- Application
             |
             v
         Port 8000
```

---

# 3. Project Structure

The Phase 1 directory contains:

```text
phase1-beginner/
├── app/
│   └── main.py
├── Dockerfile
├── requirements.txt
└── README.md
```

---

# 4. FastAPI Application

The application is defined in:

```text
app/main.py
```

The important endpoints are:

```text
/
```

Returns a welcome message.

```text
/health
```

Returns the health status of the application.

```text
/info
```

Returns application metadata such as the application name and version.

The `/health` endpoint becomes particularly useful in later phases because it can be used by:

* Docker `HEALTHCHECK`
* CI smoke tests
* Deployment health checks

---

# 5. Requirements

The application requires:

```text
fastapi==0.111.0
uvicorn[standard]==0.30.1
```

These dependencies are specified in:

```text
requirements.txt
```

---

# 6. Phase 1 Dockerfile

The Phase 1 Dockerfile:

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY app/ ./app

EXPOSE 8000

CMD ["python3", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

# 7. Dockerfile Explanation

## 7.1 `FROM ubuntu:22.04`

```dockerfile
FROM ubuntu:22.04
```

This defines the base image.

Instead of using an image that already contains Python, we started with a general-purpose Ubuntu operating system.

Conceptually:

```text
Ubuntu
   |
   +-- Install Python
   |
   +-- Install pip
   |
   +-- Install application dependencies
   |
   +-- Copy application
```

### Why use Ubuntu in Phase 1?

The purpose was educational.

It allows us to understand what a Docker image actually contains and what happens when application dependencies are installed manually.

In later phases, we will use more specialized and smaller base images.

---

# 8. `DEBIAN_FRONTEND=noninteractive`

```dockerfile
ENV DEBIAN_FRONTEND=noninteractive
```

This prevents Ubuntu's package manager from waiting for interactive input during the Docker build.

Docker builds should be automated and non-interactive.

---

# 9. Installing Python and pip

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip && \
    rm -rf /var/lib/apt/lists/*
```

Because the base image is simply Ubuntu, Python and pip need to be installed manually.

The command performs three main operations:

1. Update the package index
2. Install Python and pip
3. Remove cached package-list files

The important packages are:

```text
python3
python3-pip
```

Inside our running container, we verified:

```text
Python 3.10.12
pip 22.0.2
```

---

# 10. `WORKDIR`

```dockerfile
WORKDIR /app
```

This sets `/app` as the working directory inside the container.

After this instruction, relative paths are based on:

```text
/app
```

For example:

```dockerfile
COPY requirements.txt .
```

copies the file to:

```text
/app/requirements.txt
```

---

# 11. Copying `requirements.txt`

```dockerfile
COPY requirements.txt .
```

The dependency file is copied before the application source code.

This is intentional.

Docker builds images in layers, and Docker can reuse previously built layers when nothing relevant has changed.

Suppose we change:

```text
app/main.py
```

but don't change:

```text
requirements.txt
```

Docker can reuse the dependency installation layer instead of reinstalling FastAPI and Uvicorn.

This is an example of **Docker layer caching**.

---

# 12. Installing Python Dependencies

```dockerfile
RUN pip3 install --no-cache-dir -r requirements.txt
```

This installs:

```text
FastAPI
Uvicorn
```

inside the image.

The `--no-cache-dir` option prevents pip from keeping its package download cache, reducing unnecessary data in the image.

---

# 13. Copying Application Code

```dockerfile
COPY app/ ./app
```

This copies the local application directory into the container.

Local:

```text
app/
└── main.py
```

becomes:

```text
/app/
└── app/
    └── main.py
```

inside the container.

---

# 14. `EXPOSE`

```dockerfile
EXPOSE 8000
```

`EXPOSE` documents that the application is expected to listen on port `8000`.

However, `EXPOSE` does **not** publish the port to the host.

This distinction is important.

### `EXPOSE`

```dockerfile
EXPOSE 8000
```

Means:

```text
The containerized application uses port 8000.
```

### `-p`

When running the container:

```bash
-p 8000:8000
```

actually publishes the port.

Therefore:

```text
EXPOSE 8000
    |
    +-- Image metadata/documentation

-p 8000:8000
    |
    +-- Actual host → container port publishing
```

---

# 15. `CMD`

```dockerfile
CMD ["python3", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

This defines the default process that starts when the container starts.

It launches Uvicorn.

The application reference:

```text
app.main:app
```

means:

```text
app/
└── main.py
      |
      └── app = FastAPI(...)
```

The server listens on:

```text
0.0.0.0:8000
```

### Why `0.0.0.0`?

Inside a container, the application must listen on the container's network interfaces so Docker's published port can reach it.

If the application only listened on:

```text
127.0.0.1:8000
```

it would only accept connections from the container's own loopback interface.

---

# 16. Building the Docker Image

We built the image using:

```bash
docker build -t docker-mastery:phase1 .
```

### Command breakdown

```text
docker build
```

Build a Docker image.

```text
-t docker-mastery:phase1
```

Assign the image:

```text
Name: docker-mastery
Tag:  phase1
```

```text
.
```

Use the current directory as the Docker build context.

---

# 17. Docker Build Context

The `.` at the end of:

```bash
docker build -t docker-mastery:phase1 .
```

means Docker can access files from the current directory when processing:

```dockerfile
COPY
```

instructions.

For example:

```dockerfile
COPY requirements.txt .
COPY app/ ./app
```

require those files to be inside the build context.

---

# 18. Image Layers

We inspected the image using:

```bash
docker history docker-mastery:phase1
```

The image contained layers corresponding to:

```text
Ubuntu base image
        ↓
ENV
        ↓
Install Python + pip
        ↓
WORKDIR
        ↓
requirements.txt
        ↓
Install Python dependencies
        ↓
Application code
        ↓
EXPOSE
        ↓
CMD
```

The important concept is:

> Docker images are built from layers.

Each relevant Dockerfile instruction contributes to the resulting image structure.

---

# 19. Image Size Observation

The application code itself was very small.

The Docker history showed approximately:

```text
Application code        ~4 KB
Python dependencies     ~57 MB
Ubuntu/runtime          significantly larger
```

This demonstrates an important Docker concept:

> The application source code is often only a small part of the final container image. The operating system and runtime environment can contribute much more to the image size.

This is one of the problems Phase 2 will address.

---

# 20. Running the Container

We started the container using:

```bash
docker run -d \
    --name phase1-app \
    -p 8000:8000 \
    docker-mastery:phase1
```

### `-d`

Runs the container in detached/background mode.

### `--name phase1-app`

Assigns the container a readable name.

Instead of:

```text
29f233c17d36
```

we can use:

```text
phase1-app
```

### `-p 8000:8000`

Publishes:

```text
Host Port : Container Port
8000      : 8000
```

Therefore:

```text
Fedora :8000
      |
      v
Container :8000
```

---

# 21. Verifying the Container

We used:

```bash
docker ps
```

The container appeared as:

```text
phase1-app
```

with:

```text
0.0.0.0:8000->8000/tcp
```

This confirms that Docker is publishing host port 8000 to container port 8000.

---

# 22. Checking Container Logs

We ran:

```bash
docker logs phase1-app
```

The output included:

```text
Started server process
Application startup complete.
Uvicorn running on http://0.0.0.0:8000
```

This confirmed that:

```text
Container
    |
    v
CMD
    |
    v
Uvicorn
    |
    v
FastAPI
```

was running correctly.

---

# 23. Testing the Application

We opened:

```text
http://localhost:8000
```

from the Fedora browser.

We also tested:

```text
http://localhost:8000/health
```

and:

```text
http://localhost:8000/info
```

This verified that the application was accessible through Docker's published port.

---

# 24. Entering the Container

We entered the running container using:

```bash
docker exec -it phase1-app bash
```

This gives an interactive shell inside the running container.

Inside the container:

```bash
pwd
```

returned:

```text
/app
```

We could therefore inspect the application's filesystem directly.

---

# 25. Python Environment Inside the Container

Inside the container we checked:

```bash
python3 --version
```

Result:

```text
Python 3.10.12
```

We also checked:

```bash
pip3 --version
```

Result:

```text
pip 22.0.2
```

This demonstrated that Python and pip are part of the container environment.

They are not being provided by the Fedora host.

---

# 26. Understanding PID 1

Inside the container we ran:

```bash
ps aux
```

The main process was:

```text
PID 1
python3 -m uvicorn app.main:app ...
```

The main application process became **PID 1** inside the container.

Conceptually:

```text
Container
│
├── PID 1 → Uvicorn
│
├── PID 12 → bash
│
└── PID 24 → ps
```

The `bash` process appeared because we entered the container using:

```bash
docker exec -it phase1-app bash
```

---

# 27. Why Starting Uvicorn Again Failed

While inside the container, we manually executed:

```bash
python3 -m uvicorn app.main:app \
    --host 0.0.0.0 \
    --port 8000
```

It returned:

```text
[Errno 98] error while attempting to bind on address
('0.0.0.0', 8000): address already in use
```

This happened because Uvicorn was already running as PID 1.

Existing process:

```text
PID 1
└── Uvicorn
    └── 0.0.0.0:8000
```

We attempted to start another process:

```text
PID 25
└── Uvicorn
    └── 0.0.0.0:8000
```

The second process could not bind to the same port.

This was not a Docker failure.

It confirmed that the original Uvicorn process was already running.

---

# 28. Container Networking

Inside the container we checked:

```bash
hostname
```

The hostname was:

```text
29f233c17d36
```

which corresponds to the container identity.

We also found the container IP:

```text
172.17.0.2
```

This showed that the container has its own network identity.

The container was attached to Docker's default `bridge` network.

---

# 29. Docker Bridge Networking

The local networking flow was:

```text
Browser
    |
    | localhost:8000
    v
Fedora Host
    |
    | Docker port publishing
    | 8000 → 8000
    v
Docker Bridge Network
    |
    | Container IP: 172.17.0.2
    v
phase1-app
    |
    | Port 8000
    v
Uvicorn
    |
    v
FastAPI
```

This is different from the Kubernetes `kind` network already present on the machine.

The Docker Mastery container was kept separate from the existing Kind environment.

---

# 30. Python Virtual Environment vs Docker

A Python virtual environment can be created using:

```bash
python3 -m venv venv
```

A Python `venv` is mainly used to isolate Python packages.

Example:

```text
Fedora
└── Python venv
    ├── Python packages
    ├── FastAPI
    └── Uvicorn
```

Docker provides broader isolation:

```text
Docker Container
├── Filesystem
├── Processes
├── Networking
├── Python
├── Dependencies
└── Application
```

Therefore:

```text
Python venv ≠ Docker container
```

A Python virtual environment can still be useful for local development, but it isn't required for the Docker container we built.

---

# 31. Phase 1 Request Flow

The complete request flow is:

```text
Browser
   |
   | http://localhost:8000
   v
Fedora Host
   |
   | Port 8000
   v
Docker Port Publishing
   |
   | 8000 → 8000
   v
Docker Container
   |
   | 0.0.0.0:8000
   v
Uvicorn
   |
   v
FastAPI
   |
   v
Endpoint
```

This is one of the most important concepts learned in Phase 1.

---

# 32. What Phase 1 Achieved

By completing Phase 1, we learned how to:

* Create a Docker image from a Dockerfile
* Use a base image
* Install application dependencies
* Copy application files into an image
* Understand Docker build context
* Understand Docker image layers
* Use Docker layer caching
* Create a container from an image
* Publish container ports
* Run and inspect containers
* Read container logs
* Enter a running container
* Inspect container processes
* Understand PID 1
* Understand basic Docker networking
* Understand container IP addressing
* Understand `EXPOSE` vs `-p`
* Understand Python `venv` vs Docker containers

---

# 33. Limitations of Phase 1

Although Phase 1 works correctly, it is not optimized.

We used:

```dockerfile
FROM ubuntu:22.04
```

and manually installed:

```text
Python
pip
```

Therefore the final image contains:

```text
Ubuntu
+
Python
+
pip
+
FastAPI
+
Uvicorn
+
Application
```

This results in a larger image than necessary.

Other limitations include:

* Generic OS base image
* Manual Python installation
* Larger image size
* Slower builds compared with an optimized setup
* Development/runtime components are not separated
* No automated CI pipeline
* No image scanning
* No container registry workflow

These limitations are intentional because Phase 1 is the **fundamentals phase**.

---

# 34. Interview Explanation

## Short version

If asked:

> "What did you do in Phase 1 of your Docker project?"

A good answer is:

> I containerized a FastAPI application using Docker. For the first phase, I used Ubuntu 22.04 as the base image to understand Docker fundamentals. I manually installed Python and pip, copied the requirements file and installed FastAPI and Uvicorn, then copied the application code into the image.
>
> I structured the Dockerfile so that the requirements file was copied before the application code, allowing Docker to reuse the dependency layer when application code changes. I exposed port 8000 and configured Uvicorn to listen on `0.0.0.0:8000`.
>
> I built the image using `docker build`, ran it using `docker run -p 8000:8000`, and verified the application through the browser and container logs. I also entered the container using `docker exec`, inspected its Python environment and processes, identified Uvicorn as PID 1, and examined its Docker bridge networking.
>
> The main limitation of Phase 1 is that Ubuntu is a general-purpose and relatively large base image, and Python has to be installed manually. Phase 2 improves this using a Python slim base image and a multi-stage build.

---

# 35. Important Interview Questions

### Q: What is the difference between an image and a container?

**Image:** A packaged, immutable template containing the application, dependencies, filesystem layers, and configuration.

**Container:** A running instance created from an image.

```text
Image
   |
   | docker run
   v
Container
```

---

### Q: What does `docker build` do?

It reads the Dockerfile and build context and creates a Docker image from the specified instructions.

---

### Q: What does `docker run` do?

It creates and starts a container from a Docker image.

---

### Q: What is the difference between `EXPOSE` and `-p`?

`EXPOSE` documents the port used by the application.

```dockerfile
EXPOSE 8000
```

`-p` actually publishes the port from the host to the container.

```bash
-p 8000:8000
```

---

### Q: Why use `0.0.0.0` instead of `127.0.0.1`?

`0.0.0.0` makes Uvicorn listen on all network interfaces inside the container, allowing Docker's port forwarding to reach it.

---

### Q: Why did you copy `requirements.txt` before the application code?

To take advantage of Docker layer caching.

If only application code changes, Docker can reuse the dependency installation layer.

---

### Q: What is PID 1 in a container?

It is the main process of the container.

In our case:

```text
PID 1 → Uvicorn → FastAPI
```

---

### Q: Why did the second Uvicorn command fail?

Because another Uvicorn process was already listening on port 8000.

---

### Q: Why is Phase 1 image larger?

Because we used a general Ubuntu image and manually installed Python and other dependencies instead of starting from a smaller, purpose-built Python image.

---

### Q: What would you improve?

I would:

* Use a Python slim base image
* Use multi-stage builds
* Reduce unnecessary packages
* Run the application as a non-root user
* Add health checks
* Automate build/test through CI/CD
* Scan the image for vulnerabilities
* Push the image to a container registry

These improvements lead directly into the later phases of the project.

---

# 36. Phase 1 Final Architecture

```text
                    PHASE 1
             Docker Fundamentals

                    Fedora
                      |
                      |
                Docker Engine
                      |
                      v
             +----------------+
             | Docker Image   |
             |                |
             | Ubuntu 22.04   |
             | Python         |
             | pip            |
             | FastAPI        |
             | Uvicorn        |
             | Application    |
             +----------------+
                      |
                 docker run
                      |
                      v
             +----------------+
             |   Container    |
             |                |
             | phase1-app     |
             |                |
             | Uvicorn :8000  |
             +----------------+
                      |
                -p 8000:8000
                      |
                      v
                  Browser
             localhost:8000
```

---

# 37. Phase 1 → Phase 2

The key question after Phase 1 is:

> **Can we package the same application in a smaller and more efficient way?**

Phase 1:

```text
Ubuntu
  ↓
Install Python manually
  ↓
Install dependencies
  ↓
Copy application
  ↓
Large final image
```

Phase 2 will move toward:

```text
Python Slim
    ↓
Multi-stage build
    ↓
Build dependencies separately
    ↓
Keep only what is required at runtime
    ↓
Smaller final image
```

The application itself should remain largely the same.

The major change will be **how we package, build, and deliver it**.

---

## Phase 1 Status

```text
[✓] Application inspected
[✓] Dockerfile understood
[✓] Image built
[✓] Image layers inspected
[✓] Container created
[✓] Application tested
[✓] Logs inspected
[✓] Container inspected
[✓] Processes inspected
[✓] PID 1 understood
[✓] Networking inspected
[✓] Port publishing understood
[✓] Phase 1 limitations identified

Phase 1: COMPLETE
```
