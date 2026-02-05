# DevOps Machine Test - CI/CD Pipeline POC

A production-ready DevOps pipeline demonstration featuring a Node.js application with automated CI/CD using Jenkins, Docker, and AWS.

## Project Overview

This project demonstrates a production-ready jenkins multi-branch pipeline for a Node.js application with:

- Simple Node.js/Express application with health endpoints
- Optimized Docker containerization with multi-stage builds
- Jenkins CI/CD pipeline with build→test→push flow
- Git commit ID-based image tagging for traceability
- Nginx reverse proxy for production deployment
- AWS ECR for container registry
- EC2 deployment with Docker Compose
- Slack notifications for build status

### Pipeline Flow

#### Normal Deployment (BUILD_NGINX=false)

1. **Setup Environment**: Configure AWS credentials and generate git commit ID tag
2. **Build Docker Image**: Create production image with commit ID tag
3. **Run Tests**: Execute `npm test` with temporary environment file
4. **Push to ECR**: Upload tested image to AWS ECR
5. **Deploy to Server**: Update docker-compose with commit ID and restart containers
6. **Health Check**: Validate application via Nginx reverse proxy

#### Nginx-Only Deployment (BUILD_NGINX=true)

1. **Setup Environment**: Configure AWS credentials
2. **Build Nginx Image**: Build Nginx container with custom configuration
3. **Push to ECR**: Upload Nginx image with `nginx` tag
4. **Deploy to Server**: Update Nginx container only

## 🛠️ Technology Stack

| Component | Technology |
|-----------|------------|
| **Application** | Node.js 24.13.0 (Alpine Linux) |
| **Framework** | Express.js 4.18.2 |
| **Reverse Proxy** | Nginx 1.28 (Alpine) |
| **Containerization** | Docker (multi-stage builds) |
| **Orchestration** | Docker Compose |
| **CI/CD** | Jenkins with Pipeline as Code |
| **Container Registry** | AWS ECR |
| **Deployment** | AWS EC2 + Docker Compose |
| **Secrets Management** | AWS Secrets Manager |
| **Notifications** | Slack |
| **Tagging Strategy** | Git commit ID (short hash) |

## 📋 Pipeline Stages

### 1. Setup Environment

- Loads branch-specific configuration (main)
- Sets AWS credentials and region
- **Generates git commit ID tag** (short hash) for Docker images
- Configures Docker image names with commit-based tags

### 2. Build Docker Image

- Creates optimized multi-stage Docker image
- Uses `--target production` for production build
- Tags image with git commit ID (e.g., `app:a1b2c3d`)
- **Skipped when BUILD_NGINX=true**

### 3. Run Tests

- Creates temporary `.env.test` from `env.example`
- Mounts environment file into container (read-only)
- Runs `npm test` inside Docker container
- Cleans up test environment file
- **Pipeline fails if tests fail**
- **Skipped when BUILD_NGINX=true**

### 4. Build Nginx Image (Optional)

- **Only runs when BUILD_NGINX=true**
- Builds Nginx reverse proxy image from `server-configs/`
- Tags with static `nginx` tag
- Pushes to ECR for production deployment

### 5. Push APP Docker Image

- Authenticates with AWS ECR
- Tags image with full ECR repository path
- Pushes tested image to ECR
- **Skipped when BUILD_NGINX=true**

### 6. Deploy to Server

- Copies `server-configs/docker-compose.yml` to workspace
- **Injects git commit ID** into docker-compose.yml
- Injects AWS account ID, region, and app name
- Copies processed docker-compose.yml and .env to EC2
- Pulls latest images from ECR
- Restarts containers with `docker compose up -d`

## 📁 Project Structure

```text
├── index.js                 # Node.js application entry point
├── package.json            # Node.js dependencies
├── Dockerfile              # Multi-stage Docker build
├── docker-compose.yml      # Local development setup
├── .dockerignore          # Docker build exclusions
├── env.example            # Example environment variables
├── Jenkinsfile            # CI/CD pipeline definition
├── k8s-helm/            # Helm chart configuration
│   ├── Chart.yaml         # Chart metadata
│   ├── values.yaml        # Default values
│   ├── templates/         # Kubernetes manifest templates
│   └── README.md          # Chart documentation
├── server-configs/        # Production server configuration
│   ├── nginx.conf         # Nginx reverse proxy config
│   ├── Dockerfile.nginx   # Nginx Docker image
│   └── docker-compose.yml # Production compose with Nginx + App
└── README.md              # This file
```

### Server Deployment Configuration

The `server-configs/` directory contains production deployment files:

- **nginx.conf**: Reverse proxy configuration with security headers and health check endpoint
- **Dockerfile.nginx**: Nginx container build with Alpine Linux base
- **docker-compose.yml**: Production orchestration with:
  - Nginx service (port 80) with ECR image
  - App service (internal port 3000) with ECR image
  - Health checks for both services
  - Proper networking and logging configuration
  - Environment variables injected by Jenkins

## 🚀 Local Development

### Prerequisites

- Docker 20.10+
- Docker Compose v2+
- Node.js 24.13.0 (optional, for local development)

### Quick Start

**Clone the repository**

```bash
git clone <repository-url>
cd devops-machine-test-0304
```

**Create environment file**

```bash
cp env.example .env
# Edit .env with your configuration
```

**Run with Docker Compose**

Development with Live Reload, Docker Compose v2+ includes live reload support:

```bash
docker compose up --watch --build
```

This will automatically sync changes to `index.js` and `src/` directory.

**Access the application**

- Main endpoint: <http://localhost:3000>
- Health check: <http://localhost:3000/health>

### Running npm install Inside development Container

If you need to install new dependencies inside a running container:

```bash
docker compose exec app npm install <package-name>
```

## Nginx Configuration

**Access via domain**

- Main endpoint: <http://devopsmachinetest.com>
- Health check: <http://devopsmachinetest.com/health>

> **Note**: The Nginx configuration includes domain validation. Accessing via `http://localhost` or IP address will return a 403/444 error. You must use the domain name configured in `/etc/hosts`.

### SSL Configuration

The Nginx configuration includes SSL/HTTPS support via Let's Encrypt (Certbot), but it's **commented out** for local testing since SSL certificates cannot be obtained for localhost.

**SSL Features (when enabled in production):**

- TLS 1.2 and 1.3 support
- HTTP to HTTPS redirect
- HSTS (HTTP Strict Transport Security)
- Certbot integration for automatic certificate renewal
- Security headers for HTTPS

**To enable SSL in production:**

1. Uncomment the HTTPS redirect in `nginx.conf` (lines 10-12)
2. Uncomment the SSL server block (lines 58-120)
3. Update `server_name` with your actual domain
4. Run Certbot to obtain certificates:

   ```bash
   docker compose --profile certbot run certbot certonly --webroot -w /var/www/certbot -d yourdomain.com
   ```

## 🐳 Docker Configuration

### Multi-Stage Build

The Dockerfile uses a 3-stage build process:

1. **Base**: Install dependencies with `npm ci`
2. **Development**: Full source code for local development
3. **Production**: Minimal image with non-root user

### Image Optimization

- Alpine Linux base (minimal size)
- Layer caching for dependencies
- `.dockerignore` excludes unnecessary files
- Non-root user for security
- BuildKit for faster builds

### Build Commands

```bash
# Development build
docker build --target development -t devops-machine-test:dev .

# Production build
docker build --target production -t devops-machine-test:prod .

# Run production image
docker run -p 3000:3000 devops-machine-test:prod
```

## ☁️ AWS Deployment

### AWS Prerequisites

1. **AWS Resources**
    - ECR repository created
    - EC2 instance running (Ubuntu recommended)
    - Security group allowing port 3000
    - IAM role with ECR pull permissions

2. **Jenkins Configuration**
    - Jenkins server with Docker installed
    - Required plugins: Pipeline, AWS Steps, Slack Notification
    - SSH key configured for EC2 access

#### Jenkins Pipeline Setup

**Environment Variables** (Manage Jenkins → System → Global properties → Environment variables):

| Variable Name | Description | Example Value |
|---------------|-------------|---------------|
| `APP_NAME_AWS_ACCOUNT_REGION` | AWS region | `us-east-1` |
| `APP_NAME_DEV_AWS_ACCOUNT_ID` | AWS account ID | `123456789012` |
| `APP_NAME_DEV_DOCKER_IMAGE_NAME` | ECR repository name | `devops-machine-test` |
| `APP_NAME_DEV_SECRET_MANAGER` | AWS Secrets Manager secret name | `devops-machine-test/dev` |
| `APP_NAME_DEV_SERVER_IP` | EC2 instance IP address | `54.123.45.67` |

**Credentials** (Manage Jenkins → Credentials):

| Credential ID | Type | Description |
|---------------|------|-------------|
| `APP_NAME_DEV` | AWS Credentials | AWS access key and secret for ECR/Secrets Manager access |
| `SLACK_WEBHOOK` | Secret text | Slack webhook URL for build notifications |

**Note**: `DOCKER_IMAGE_TAG` is no longer needed - the pipeline automatically generates tags from git commit IDs.

#### Jenkins Parameters

The pipeline supports the following build parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `BUILD_NGINX` | Boolean | `false` | When `true`, skips app build/test/push and only builds/pushes Nginx image |

**Usage**:

- **Normal deployment**: Leave `BUILD_NGINX` unchecked (default)
- **Nginx-only update**: Check `BUILD_NGINX` to update only the Nginx configuration/image

### EC2 Server Setup

1. **Install Docker and Docker Compose**:

```bash
# Update system and install prerequisites
sudo apt update
sudo apt install ca-certificates curl

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository to Apt sources
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Install Docker Engine and Docker Compose plugin
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo groupadd docker
sudo usermod -aG docker $USER

# Log out and log back in for group membership to take effect
# Or run: newgrp docker

# Verify installations
docker --version
docker compose version
```

1. **Configure Security Group**:

- Allow inbound traffic on port **80** (HTTP) for Nginx
- Allow inbound traffic on port **443** (HTTPS) for Nginx
- Allow inbound traffic on port **22** (SSH) from Jenkins server
- Allow outbound traffic to AWS ECR

1. **Create Application Directory**:

```bash
mkdir -p /home/ubuntu/devops-machine-test
cd /home/ubuntu/devops-machine-test
```

1. **Configure ECR Access** (Choose one method):

#### Option A: IAM Role (Recommended)

Attach an IAM role to the EC2 instance with ECR read permissions:

- Attach the role to your EC2 instance (EC2 → Actions → Security → Modify IAM role)

#### Option B: AWS CLI Credentials

```bash
aws configure
# Enter AWS Access Key ID
# Enter AWS Secret Access Key
# Enter region (e.g., us-east-1)
```

## 🔒 Security Best Practices

### Secrets Management

- ✅ Environment variables stored in AWS Secrets Manager
- ✅ No hardcoded credentials in code or Jenkinsfile
- ✅ Jenkins credentials binding for AWS access
- ✅ Secrets cleaned up after pipeline execution

### Docker Security

- ✅ Non-root user in production image
- ✅ Minimal Alpine base image
- ✅ `.dockerignore` excludes sensitive files
- ✅ Multi-stage builds reduce attack surface

### AWS Security

- ✅ IAM roles with least privilege
- ✅ ECR image scanning enabled (recommended)
- ✅ Security groups restrict network access
- ✅ SSH key-based authentication

## 📊 Monitoring & Notifications

### Slack Integration

The pipeline sends notifications to `#jenkins-builds` channel:

- 🟡 Yellow: Build/deployment started
- 🟢 Green: Success
- 🔴 Red: Failure (includes build URL)

## ☸️ Kubernetes Deployment

This project includes production-ready Kubernetes manifests for deploying to any Kubernetes cluster (EKS, GKE, AKS, or self-managed).

### Features

- ✅ **Security**: Non-root user, read-only filesystem, network policies, pod security contexts
- ✅ **High Availability**: 2 replicas, Pod Disruption Budget, rolling updates
- ✅ **Auto-scaling**: Horizontal Pod Autoscaler (2-5 replicas based on CPU/memory)
- ✅ **Health Checks**: Liveness and readiness probes using `/health` endpoint
- ✅ **Secrets Management**: Kubernetes Secrets with base64 encoding
- ✅ **Ingress**: Nginx Ingress Controller with security headers
- ✅ **Resource Management**: CPU/memory requests and limits

### Helm Chart Deployment (Recommended)

For a more scalable and reusable deployment, use the provided Helm chart.

```bash
# Install the chart
helm install devops-machine-test ./k8s-helm --namespace devops-machine-test --create-namespace

# Upgrade
helm upgrade devops-machine-test ./k8s-helm --namespace devops-machine-test
```

> 📖 **Helm Documentation**: See [k8s-helm/README.md](k8s-helm/README.md) for configuration options.
