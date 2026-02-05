# DevOps Machine Test

## Overview

A production-ready Jenkins multi-branch pipeline for a Node.js application.

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

## 📁 Project Structure

```text
├── index.js                 # Node.js application entry point
├── package.json            # Node.js dependencies
├── Dockerfile              # Multi-stage Docker build
├── docker-compose.yml      # Local development setup
├── .dockerignore          # Docker build exclusions
├── env.example            # Example environment variables
├── Jenkinsfile            # CI/CD pipeline definition
├── k8s-helm/              # Helm chart configuration
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

## 🚀 Local Development

### Prerequisites

- Docker 20.10+
- Docker Compose v2+

### Quick Start

```bash
# 1. Clone
git clone <repository-url>
cd sayone-devops-test

# 2. Configure
cp env.example .env

# 3. Run
docker compose up --watch --build
```

Access the app at <http://localhost:3000>.

## 🐳 Docker Configuration

The application uses an optimized **multi-stage Dockerfile** (Alpine based) with a non-root user for security.

## Jenkins CI/CD Pipeline

### Pipeline Flow

#### Normal Deployment (BUILD_NGINX=false)

1. **Setup Environment**: Configure AWS credentials and generate git commit ID tag
2. **Build Docker Image**: Create production image with commit ID tag
3. **Run Tests**: Execute `npm test` with temporary environment file
4. **Push to ECR**: Upload tested image to AWS ECR
5. **Deploy to Server**: Update docker-compose with commit ID and restart containers

#### Nginx-Only Deployment (BUILD_NGINX=true)

1. **Setup Environment**: Configure AWS credentials
2. **Build Nginx Image**: Build Nginx container with custom configuration
3. **Push to ECR**: Upload Nginx image with `nginx` tag
4. **Deploy to Server**: Update Nginx container only

> 📖 **Detailed Guide**: See [DEPLOYMENT.md](DEPLOYMENT.md) for full pipeline configuration and stage details.

## ☁️ AWS Deployment

The project is designed to be deployed on **AWS EC2** using **Jenkins** and **AWS ECR**.

- **Infrastructure**: EC2 (Ubuntu), ECR, Secrets Manager.
- **Orchestration**: Docker Compose on EC2.
- **Security**: IAM Roles for ECR access, Security Groups.

> 📖 **Setup Guide**: See [DEPLOYMENT.md](DEPLOYMENT.md#aws-deployment) for prerequisites, Jenkins setup, and EC2 configuration.

## ☸️ Kubernetes Configuration

This project includes production-ready Kubernetes manifests for deploying to any Kubernetes cluster.

### Features

- ✅ **Security**: Non-root user, read-only filesystem, network policies, pod security contexts
- ✅ **High Availability**: 2 replicas, Pod Disruption Budget, rolling updates
- ✅ **Auto-scaling**: Horizontal Pod Autoscaler (2-5 replicas based on CPU/memory)
- ✅ **Health Checks**: Liveness and readiness probes using `/health` endpoint
- ✅ **Secrets Management**: Kubernetes Secrets with base64 encoding
- ✅ **Ingress**: Nginx Ingress Controller with security headers
- ✅ **Resource Management**: CPU/memory requests and limits

### Helm Chart Configuration

For a more scalable and reusable deployment, use the provided Helm chart.

```bash
# Install the chart
helm install devops-machine-test ./k8s-helm --namespace devops-machine-test --create-namespace

# Upgrade
helm upgrade devops-machine-test ./k8s-helm --namespace devops-machine-test
```

> 📖 **Helm Documentation**: See [k8s-helm/README.md](k8s-helm/README.md) for configuration options.
