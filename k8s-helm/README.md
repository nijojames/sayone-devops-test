# DevOps Machine Test Helm Chart

A Helm chart for deploying the DevOps Machine Test Node.js application on Kubernetes.

## 🚀 Installation

```bash
# Install the chart
helm install devops-machine-test ./k8s-helm --namespace devops-machine-test --create-namespace

# Upgrade the chart
helm upgrade devops-machine-test ./k8s-helm --namespace devops-machine-test
```

## ⚙️ Configuration

The following table lists the configurable parameters of the chart and their default values (see `values.yaml`).

| Parameter | Description | Default |
| :--- | :--- | :--- |
| `replicaCount` | Number of replicas | `2` |
| `fullname` | Overrides the full name of the release | `devops-machine-test` |
| `image.repository` | ECR repository URL | `<AWS_ACCOUNT_ID>...` |
| `image.tag` | Image tag to deploy | `latest` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Enable Ingress | `true` |
| `ingress.hosts` | Ingress hosts | `devopsmachinetest.com` |
| `autoscaling.enabled` | Enable HPA | `true` |
| `autoscaling.minReplicas` | Min replicas for HPA | `2` |
| `autoscaling.maxReplicas` | Max replicas for HPA | `5` |
| `pdb.create` | Create Pod Disruption Budget | `true` |
| `networkPolicy.enabled` | Enable Network Policy | `true` |

## 🔐 Secrets

For production, provide secrets via `values.yaml` (Base64 encoding NOT required, Helm handles it) or use External Secrets Operator.

```yaml
secrets:
  DATABASE_URL: "postgresql://user:pass@host:5432/db"
  API_KEY: "my-secret-key"
```

## 🔒 Security Features

### Pod Security

- ✅ Non-root user (UID 1000)
- ✅ Read-only root filesystem where possible
- ✅ Drop all capabilities
- ✅ No privilege escalation

### Network Security

- ✅ NetworkPolicy restricts ingress/egress traffic
- ✅ Only allows traffic from Ingress controller

## 📊 Monitoring & Debugging

```bash
# Verify deployment
kubectl get all -n devops-machine-test

# Check pod logs
kubectl logs -f -n devops-machine-test -l app.kubernetes.io/name=devops-machine-test

# Port-forward for testing
kubectl port-forward -n devops-machine-test svc/devops-machine-test 3000:80
```

## 📝 Best Practices

### 1. ☸️ Use Helm for Reusability

Instead of managing raw YAML files, use **Helm** to package your application. This allows you to:

- Reuse the same chart for different environments (dev, staging, prod)
- Template your manifests with variable substitution
- Manage release history and rollbacks easily

### 2. 🔄 Jenkins Integration with Helm

In your `Jenkinsfile`, you can use Helm to upgrade your application seamlessly:

```groovy
stage('Deploy to K8s') {
    steps {
        script {
            withKubeConfig([credentialsId: 'kubeconfig']) {
                sh """
                    helm upgrade --install devops-machine-test ./helm-chart \
                        --namespace devops-machine-test \
                        --set image.tag=${env.DOCKER_IMAGE_TAG} \
                        --values helm-chart/values-${env.BRANCH_NAME}.yaml \
                        --wait
                """
            }
        }
    }
}
```

### 3. 🔐 Secrets Management with AWS Secrets Manager

Avoid storing base64 encoded secrets in git. Use **External Secrets Operator** (ESO) to sync secrets from AWS Secrets Manager directly into Kubernetes.
