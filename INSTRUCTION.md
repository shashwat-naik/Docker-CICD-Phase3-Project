# Phase 3 CI/CD — Step-by-Step Setup Guide

Do these steps in order. Everywhere you see `YOUR_USERNAME` or
`YOUR_ACCOUNT_ID`, replace it with your real value before running.

We do the code push only **once**, at the very end, after every account,
registry, and secret is already in place — so the first pipeline run
succeeds instead of failing halfway through.

---

## Step 1 — Create the GitHub repo

1. Go to https://github.com/new
2. Repository name: `docker-mastery-project`
3. Leave "Add a README" **unchecked**
4. Click **Create repository**

Leave this tab open.

---

## Step 2 — Connect this instance to GitHub

Run on your instance:

```bash
git --version || sudo apt install git -y

git config --global user.name "Your Name"
git config --global user.email "you@example.com"

ssh-keygen -t ed25519 -C "you@example.com"
```
Press Enter three times to accept the defaults.

```bash
cat ~/.ssh/id_ed25519.pub
```
Copy the full output.

Go to **GitHub → Settings → SSH and GPG keys → New SSH key** → paste it → **Add key**.

Back on the instance, confirm it works:
```bash
ssh -T git@github.com
```
You should see: `Hi YOUR_USERNAME! You've successfully authenticated...`

---

## Step 3 — Clone the repo and add the Phase 3 code

```bash
git clone git@github.com:YOUR_USERNAME/docker-mastery-project.git
cd docker-mastery-project
```

Copy in **only the `phase3-advanced` folder** (app code, Dockerfile,
`.dockerignore`, `.github/workflows/ci-cd.yml`, requirements files). That's
the only code this pipeline needs — don't add Phase 1 or Phase 2 here.

Do not push yet — continue to Step 4 first.

---

## Step 4 — Create a Docker Hub account and access token

1. Sign up / log in at https://hub.docker.com
2. **Account Settings → Security → New Access Token**
3. Name: `github-actions`, permissions: **Read & Write**
4. Click **Generate** and copy the token now — it's shown only once

Note down:
- Docker Hub **username**
- Docker Hub **access token**

---

## Step 5 — Create the ECR repository

AWS Console → **ECR → Repositories → Create repository**
- Visibility: **Private**
- Name: `docker-mastery-demo`
- Region: `us-east-1`
- Click **Create repository**

(Or via CLI: `aws ecr create-repository --repository-name docker-mastery-demo --region us-east-1`)

---

## Step 6 — Create the IAM service account

1. AWS Console → **IAM → Users → Create user**
2. Name: `github-actions-ci`
3. Skip console access — this account is for automation only
4. Attach policy: `AmazonEC2ContainerRegistryFullAccess`
5. Click **Create user**
6. Open the new user → **Security credentials tab → Create access key**
7. Use case: **Third-party service** → Create
8. Copy both values now — shown only once:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

---

## Step 7 — Add the 4 secrets to the GitHub repo

GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**

Add each one:

| Name | Value |
|---|---|
| `DOCKERHUB_USERNAME` | from Step 4 |
| `DOCKERHUB_TOKEN` | from Step 4 |
| `AWS_ACCESS_KEY_ID` | from Step 6 |
| `AWS_SECRET_ACCESS_KEY` | from Step 6 |

---

## Step 8 — Push (only push of the whole video)

Everything is in place now, so this push is final — it goes straight to `main`
and immediately triggers the pipeline.

```bash
git add .
git commit -m "Add phase 3 CI/CD pipeline"
git push -u origin main
```

Go to the repo's **Actions tab** and watch it run:
lint → test → build (cached) → scan → push to Docker Hub → push to ECR.