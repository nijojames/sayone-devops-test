# Deployment & Configuration Guide

This document contains detailed instructions for the CI/CD pipeline, AWS deployment, and server configuration.

## 📋 Jenkins Pipeline Stages

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

## 🐳 Docker Configuration

### Multi-Stage Build

The Dockerfile uses a 3-stage build process:

1. **Base**: Install dependencies with `npm ci`
2. **Development**: Full source code for local development
3. **Production**: Minimal image with non-root user

## ☁️ AWS Deployment

### AWS Prerequisites

1. **AWS Resources**
    - ECR repository created
    - Secrets Manager created
    - EC2 instance running (Ubuntu recommended)
    - Security group allowing port 3000
    - IAM role with ECR pull permissions

2. **Jenkins Configuration**
    - Jenkins server with Docker installed
    - Required plugins: Pipeline, AWS Steps, Slack Notification
    - SSH key configured for EC2 access

### Jenkins Pipeline Setup

**Environment Variables** (Manage Jenkins → System → Global properties → Environment variables):

| Variable Name | Description | Example Value |
| :--- | :--- | :--- |
| `APP_NAME_AWS_ACCOUNT_REGION` | AWS region | `us-east-1` |
| `APP_NAME_DEV_AWS_ACCOUNT_ID` | AWS account ID | `123456789012` |
| `APP_NAME_DEV_DOCKER_IMAGE_NAME` | ECR repository name | `devops-machine-test` |
| `APP_NAME_DEV_SECRET_MANAGER` | AWS Secrets Manager secret name | `devops-machine-test/dev` |
| `APP_NAME_DEV_SERVER_IP` | EC2 instance IP address | `54.123.45.67` |

**Credentials** (Manage Jenkins → Credentials):

| Credential ID | Type | Description |
| :--- | :--- | :--- |
| `APP_NAME_DEV` | AWS Credentials | AWS access key and secret for ECR/Secrets Manager access |
| `SLACK_WEBHOOK` | Secret text | Slack webhook URL for build notifications |

### EC2 Server Setup

### 1. Install Docker and Docker Compose

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
```

### 2. Configure ECR Access

#### Option A: IAM Role (Recommended)

Attach an IAM role to the EC2 instance with ECR read permissions.

#### Option B: AWS CLI Credentials

```bash
aws configure
```

## 🌐 Nginx Configuration

**To enable SSL in production:**

1. Uncomment the HTTPS redirect in `nginx.conf` (lines 10-12)
2. Uncomment the SSL server block (lines 58-120)
3. Update `server_name` with your actual domain
4. Run Certbot:

   ```bash
   docker compose --profile certbot run certbot certonly --webroot -w /var/www/certbot -d yourdomain.com
   ```
