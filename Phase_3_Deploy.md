# Docker Mastery Phase 3 — AWS EC2 Deployment

## 1. Project Overview

This document covers deploying the Docker Mastery Phase 3 FastAPI application on AWS EC2 using the Docker image published to Docker Hub.

The image is built and published by the existing GitHub Actions CI/CD workflow. EC2 pulls the published image and runs it inside a hardened Docker container.

### Architecture

```text
GitHub Repository
       |
       v
GitHub Actions CI/CD
       |
       | Build, test, scan
       v
Docker Hub
naikiam/docker-practice-project:latest
       |
       | docker pull
       v
AWS EC2 Instance
Amazon Linux 2023
       |
       | Docker Engine
       v
FastAPI Application
       |
       +---- Port 8000
       +---- /health
       +---- /info
       +---- /docs
```

### Deployment Details

| Component | Configuration |
|---|---|
| Cloud provider | AWS |
| Compute service | Amazon EC2 |
| Operating system | Amazon Linux 2023 |
| Region | `ap-southeast-2` (Sydney; verify against the actual instance) |
| Container runtime | Docker Engine |
| Container image | `naikiam/docker-practice-project:latest` |
| Container name | `docker-mastery-api` |
| Application port | 8000 |
| Security group | `docker-mastery-sg`, if created with this name |
| Key pair | `docker-mastery-key`, if created with this name |
| Access method | EC2 Instance Connect |
| Application protocol | HTTP |

> **Note:** This is a learning deployment, not a production-ready architecture. The API was exposed directly over HTTP on port 8000.

---

## 2. Prerequisites

- An AWS account with EC2 access.
- The application image published to Docker Hub.
- Access to the AWS Management Console.
- A suitable EC2 instance with public connectivity.
- A security group configured for the required traffic.

The GitHub repository can be cloned on Windows for source-code access and documentation. Cloning the repository on EC2 is not required because the published Docker image is used for deployment.

---

## 3. Launching the EC2 Instance

1. Open the AWS EC2 Console: https://console.aws.amazon.com/ec2/
2. Select the intended AWS Region.
3. Check whether a suitable existing EC2 instance can be reused.
4. If no suitable instance exists, select **Launch instance**.
5. Configure the instance.

| Setting | Value |
|---|---|
| Name | `docker-mastery-phase3` |
| AMI | Amazon Linux 2023 |
| Instance type | Small instance suitable for the account's eligibility and budget |
| Key pair | Create or select a key pair if required |
| Public IP | Enable public IPv4 connectivity |
| Storage | Review the EBS size and associated cost |

6. Review the estimated charges.
7. Launch the instance.
8. Wait until the instance state is `Running` and the status checks pass.
9. Record its public IPv4 address.

### Important Cost Consideration

AWS Free Tier eligibility depends on account eligibility, current offers, Region, and resource configuration. A small instance is not automatically free.

Check AWS Billing and Cost Management before and after the deployment.

---

## 4. Security Group Configuration

A security group acts as a virtual firewall for the EC2 instance.

### Inbound Rules

Inbound rules control which incoming connections can reach the instance.

| Type | Protocol | Port | Source | Purpose |
|---|---|---:|---|---|
| SSH | TCP | 22 | Your public IP, when using SSH from Windows | Remote administration |
| Custom TCP | TCP | 8000 | `0.0.0.0/0` for a public demo | Access to the FastAPI application |

For a private test, restrict port 8000 to your own public IP. The `0.0.0.0/0` source allows any IPv4 address on the internet to attempt a connection.

For browser-based EC2 Instance Connect, ensure that port 22 is reachable from the appropriate source for the chosen connection method.

### Outbound Rules

A typical default outbound rule is:

| Type | Protocol | Port | Destination | Purpose |
|---|---|---|---|---|
| All traffic | All | All | `0.0.0.0/0` | Allows outbound IPv4 connections |

For this learning deployment, the default outbound rule was retained.

Outbound access allows EC2 to contact external services such as Docker Hub and package repositories.

### How Security Groups Work

- **Inbound:** Controls connections initiated from outside the instance toward the instance.
- **Outbound:** Controls connections initiated by the instance toward other destinations.
- **Stateful behavior:** Responses to permitted connections are automatically allowed back through the security group.

> **Security note:** Port 8000 was exposed directly over HTTP. Do not send passwords, credentials, or sensitive data through this demo. For production, use HTTPS, suitable network restrictions, and an appropriate reverse proxy or load balancer.

---

## 5. Connecting to EC2

The deployment used **EC2 Instance Connect** through the AWS Console.

Steps:

1. Open **EC2 → Instances**.
2. Select the target instance.
3. Choose **Connect**.
4. Open the **EC2 Instance Connect** option.
5. Connect to the instance.

Once connected, commands run in the Linux shell on EC2.

### Alternative: SSH from Windows PowerShell

If a `.pem` key was downloaded and SSH access is configured, use:

```powershell
cd $HOME\Downloads
ssh -i .\docker-mastery-key.pem ec2-user@YOUR_EC2_PUBLIC_IP
```

Replace the placeholder with the instance's actual public IP and adjust the key path if needed.

Never upload the private key to GitHub or Docker Hub.

---

## 6. Installing Docker on EC2

The following commands were used on Amazon Linux 2023:

```bash
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl enable --now docker
```

Verify the installation:

```bash
sudo docker --version
sudo systemctl status docker --no-pager
```

Add the default EC2 user to the Docker group:

```bash
sudo usermod -aG docker ec2-user
```

Log out and reconnect for the new group membership to take effect.

Verify Docker access:

```bash
docker ps
```

If permission errors continue, reconnect again or temporarily use `sudo docker`.

> Membership in the Docker group grants powerful control over the host. Use it only for trusted administrators.

---

## 7. Pulling the Docker Image

The application image was already built and published to Docker Hub through the existing CI/CD workflow.

Pull the image on EC2:

```bash
docker pull naikiam/docker-practice-project:latest
```

Verify the image:

```bash
docker images
```

Expected repository and tag:

```text
naikiam/docker-practice-project:latest
```

Rebuilding the application on EC2 is unnecessary for this deployment.

For reproducible releases, prefer a specific version tag or image digest instead of `latest`, because the `latest` tag may point to a newer image after another push.

---

## 8. Running the Hardened Container

The container was launched with runtime security controls and resource limits.

```bash
docker run -d \
  --name docker-mastery-api \
  --restart unless-stopped \
  -p 8000:8000 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --memory=256m \
  --cpus=0.5 \
  --pids-limit=100 \
  naikiam/docker-practice-project:latest
```

### Explanation of the Options

| Option | Purpose |
|---|---|
| `--name docker-mastery-api` | Assigns a recognizable container name |
| `--restart unless-stopped` | Restarts the container after many Docker or host restarts unless manually stopped |
| `-p 8000:8000` | Maps host port 8000 to container port 8000 |
| `--read-only` | Makes the container root filesystem read-only |
| `--tmpfs /tmp:...` | Provides temporary writable storage at `/tmp` |
| `--cap-drop=ALL` | Drops Linux capabilities from the container |
| `--security-opt=no-new-privileges:true` | Prevents processes from gaining additional privileges |
| `--memory=256m` | Limits container memory to 256 MiB |
| `--cpus=0.5` | Limits the container to half a CPU's capacity |
| `--pids-limit=100` | Limits the number of processes in the container |

These are defense-in-depth measures. They improve the container's security posture but do not guarantee production security.

---

## 9. Verifying the Container

### Check Container Status

```bash
docker ps
```

### Check Application Logs

```bash
docker logs --tail 100 docker-mastery-api
```

### Check Health Status

```bash
docker inspect --format='{{.State.Health.Status}}' docker-mastery-api
```

Expected result after startup:

```text
healthy
```

The container's health check tests the application's configured `/health` endpoint.

### Inspect Runtime Security Settings

```bash
docker inspect --format='User={{.Config.User}} ReadOnly={{.HostConfig.ReadonlyRootfs}} Memory={{.HostConfig.Memory}}' docker-mastery-api
```

Expected values include:

```text
User=appuser
ReadOnly=true
Memory=268435456
```

The memory limit of `268435456` bytes is equivalent to 256 MiB.

### Monitor Resource Usage

```bash
docker stats --no-stream docker-mastery-api
```

This provides a point-in-time view of container CPU, memory, network, and process usage.

---

## 10. Testing the API

The application was exposed on the EC2 public IPv4 address using port 8000.

Replace `YOUR_EC2_PUBLIC_IP` with the current public address.

| Endpoint | Expected Result |
|---|---|
| `http://YOUR_EC2_PUBLIC_IP:8000/` | Welcome response |
| `http://YOUR_EC2_PUBLIC_IP:8000/health` | Healthy status and timestamp |
| `http://YOUR_EC2_PUBLIC_IP:8000/info` | Application name, version, and phase |
| `http://YOUR_EC2_PUBLIC_IP:8000/docs` | FastAPI Swagger UI |

### Test Locally on EC2

Run these commands in the EC2 Linux shell:

```bash
curl -i http://localhost:8000/health
curl -i http://localhost:8000/
curl -i http://localhost:8000/info
```

### Test from Windows

Run in Windows PowerShell:

```powershell
curl.exe -i http://YOUR_EC2_PUBLIC_IP:8000/health
```

The command `curl.exe` is intended for Windows. Inside the EC2 Linux shell, use `curl`.

### Troubleshooting Public Access

If local requests succeed but public requests fail, check:

1. The security group permits inbound TCP port 8000 from the intended source.
2. The instance has a public IPv4 address and suitable routing.
3. The Docker container is running and listening on port 8000.
4. The public IP address is current.

A `healthy` Docker status confirms the configured health check succeeds; it does not by itself prove that external network access works.

---

## 11. Troubleshooting Commands

```bash
# Show running containers
docker ps

# Show all containers, including stopped containers
docker ps -a

# View application logs
docker logs --tail 100 docker-mastery-api

# Check container health
docker inspect --format='{{.State.Health.Status}}' docker-mastery-api

# Check resource usage
docker stats --no-stream docker-mastery-api

# Test the application from inside EC2
curl -i http://localhost:8000/health
```

If a container with the same name already exists, inspect it before removing it. Avoid removing unrelated containers.

---

## 12. Cleaning Up AWS Resources

After testing, remove the resources created exclusively for this project.

Perform cleanup in the same Region in which the resources were created. The deployment was believed to use `ap-southeast-2` (Sydney), but verify the actual Region before deleting anything.

### 12.1 Terminate the EC2 Instance

1. Open **EC2 → Instances**.
2. Identify the instance created for this deployment.
3. Verify its name and public IP before acting.
4. Select **Instance state → Terminate (delete) instance**.
5. Confirm termination.
6. Wait until the instance state shows `Terminated`.

> **Warning:** Termination is permanent. Back up anything you need before deleting the instance. Charges already incurred will not be erased.

### 12.2 Check EBS Volumes

1. Open **EC2 → Elastic Block Store → Volumes**.
2. Identify volumes created for this project.
3. Wait for the instance to terminate, then refresh.
4. Delete only project-specific volumes that remain and are no longer needed.

The root volume may be configured for deletion on termination, but verify the result instead of assuming it was deleted.

### 12.3 Release Project Elastic IPs

1. Open **EC2 → Network & Security → Elastic IPs**.
2. Identify any Elastic IP allocated specifically for this project.
3. Disassociate it if necessary.
4. Release it if it is no longer needed.

An automatically assigned public IPv4 address is not the same as an Elastic IP and normally disappears when its instance is terminated.

### 12.4 Delete the Project Security Group

1. Open **EC2 → Network & Security → Security Groups**.
2. Find `docker-mastery-sg`, if created.
3. Delete it only if it belongs exclusively to this project and is no longer in use.

If AWS reports that the security group is in use, inspect the dependent network interface or resource before making further changes.

Do not delete the default security group or any group used by another project.

### 12.5 Delete the Project Key Pair (Optional)

1. Open **EC2 → Network & Security → Key Pairs**.
2. Find `docker-mastery-key`, if created.
3. Delete it only if it was created solely for this deployment and is no longer needed.

Deleting the AWS key-pair entry does not remove the downloaded `.pem` file from Windows.

### 12.6 Check for Other Project-Created Resources

If you created any of the following during experimentation, review them and remove only resources that belong to this project:

- Load balancers
- NAT Gateways
- EBS snapshots
- AMIs
- S3 buckets
- CloudWatch log groups
- Other project-specific network interfaces or resources

Do not delete resources simply because they appear in the console. Confirm ownership and dependencies first.

### 12.7 Verify Cleanup and Billing

Confirm that:

- The EC2 instance is terminated.
- No unwanted project-specific EBS volumes remain.
- No unused project Elastic IP remains allocated.
- The project security group is deleted if it is no longer needed.
- Other project-created resources are removed.

Review AWS Billing and Cost Management:

https://console.aws.amazon.com/costmanagement/

Billing information may take time to update. Stopping an instance is not the same as deleting it, and separately retained resources can continue to incur charges.

---

## 13. Resources Not Affected by AWS Cleanup

This cleanup does not delete:

- The GitHub repository.
- The Docker Hub image `naikiam/docker-practice-project`.
- The local Windows repository clone.
- Docker images, containers, or networks on Fedora.
- Kind/CKA clusters and their resources on Fedora.
- Unrelated AWS resources.

Avoid running broad cleanup commands such as `docker system prune -a` on Fedora, because they can remove images and containers used for other labs.

---

## 14. Deployment Checklist

- [ ] EC2 instance launched in the intended Region.
- [ ] Security group configured and reviewed.
- [ ] Docker installed and running on EC2.
- [ ] Docker Hub image pulled successfully.
- [ ] Hardened container started.
- [ ] Container health check reported `healthy`.
- [ ] API endpoints tested locally on EC2.
- [ ] Public API tested from Windows.
- [ ] Project-specific AWS resources cleaned up after testing.
- [ ] AWS Billing and Cost Management reviewed.

---

## 15. Future Improvements

Potential improvements for the next version:

1. Pin image tags or digests for reproducible deployments.
2. Add an automated deployment stage to the existing GitHub Actions pipeline.
3. Configure HTTPS through an appropriate reverse proxy or load balancer.
4. Restrict public network access and introduce appropriate monitoring.
5. Use Terraform to define AWS infrastructure reproducibly and simplify controlled creation and destruction.

These improvements can be introduced incrementally after the basic EC2 deployment and cleanup workflow is understood.
