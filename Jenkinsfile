pipeline {
    agent any

    triggers {
        githubPush()
    }

    parameters {
        booleanParam(name: 'BUILD_NGINX', defaultValue: false, description: 'Build and push Nginx Docker image to ECR')
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: "3"))
        disableConcurrentBuilds()
        timeout(time: 20, unit: 'MINUTES')
    }

    environment {
        APP_NAME = "devops-machine-test"
        SLACK_CHANNEL = "#jenkins-builds"
        DOCKER_BUILDKIT = 1
        COMPOSE_DOCKER_CLI_BUILD = 1
    }

    stages {
        stage('Setup Environment') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def envConfig = [
                        main: [
                            AWS_REGION: "${APP_NAME_AWS_ACCOUNT_REGION}",
                            AWS_ACCOUNT_ID: "${APP_NAME_DEV_AWS_ACCOUNT_ID}",
                            DOCKER_IMAGE_NAME: "${APP_NAME_DEV_DOCKER_IMAGE_NAME}",
                            SERVER_IP: "${APP_NAME_DEV_SERVER_IP}",
                            AWS_CREDENTIALS: "APP_NAME_DEV",
                            CONFIG_FOLDER: "main"
                        ]
                    ][env.BRANCH_NAME]

                    if (!envConfig) error "No config defined for branch: ${env.BRANCH_NAME}"

                    env.AWS_REGION = envConfig.AWS_REGION
                    env.AWS_ACCOUNT_ID = envConfig.AWS_ACCOUNT_ID
                    env.DOCKER_IMAGE_NAME = envConfig.DOCKER_IMAGE_NAME
                    env.SERVER_IP = envConfig.SERVER_IP
                    env.AWS_CREDENTIALS = envConfig.AWS_CREDENTIALS
                    env.CONFIG_FOLDER = envConfig.CONFIG_FOLDER
                    
                    // Use git commit ID as Docker image tag
                    env.DOCKER_IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

                    echo "Deploying to environment: ${env.BRANCH_NAME}"
                    echo "AWS Region: ${env.AWS_REGION}"
                    echo "Docker Image: ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG}"
                    echo "Server: ${env.SERVER_IP}"
                }
            }
        }

        stage('Build Docker Image') {
            when {
                allOf {
                    expression { !params.BUILD_NGINX }
                    branch 'main'
                }
            }
            steps {
                script {
                    echo "� Building ${env.APP_NAME} Docker image..."
                    sendSlackNotification('#FFFF00', "� ${env.APP_NAME}: Docker Build started: ${env.BRANCH_NAME}")

                    sh """
                        docker build \\
                            --build-arg BUILDKIT_INLINE_CACHE=1 \\
                            -f Dockerfile \\
                            --target production \\
                            -t ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG} .
                    """

                    echo "✅ ${env.APP_NAME} Docker image built successfully"
                    sendSlackNotification('#00FF00', "✅ ${env.APP_NAME}: Docker Build completed: ${env.DOCKER_IMAGE_TAG}")
                }
            }
        }
        stage('Run Tests') {
            when {
                allOf {
                    expression { !params.BUILD_NGINX }
                    branch 'main'
                }
            }
            steps {
                script {
                    echo "🧪 Starting ${env.APP_NAME} tests..."
                    sendSlackNotification('#FFFF00', "🧪 ${env.APP_NAME}: Tests started: ${env.BRANCH_NAME}")

                    // Create temporary .env file from example for testing
                    sh """
                        cp env.example .env.test
                        docker run --rm \
                            -v \$(pwd)/.env.test:/app/.env:ro \
                            ${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG} \
                            npm test
                    """

                    echo "✅ ${env.APP_NAME} tests passed successfully"
                    sendSlackNotification('#00FF00', "✅ ${env.APP_NAME}: Tests passed: ${env.BRANCH_NAME}")
                }
            }
            post {
                always {
                    // Clean up temporary test env file
                    sh "rm -f .env.test || true"
                }
                failure {
                    sendSlackNotification('#FF0000', "❌ ${env.APP_NAME}: Tests failed: ${env.BRANCH_NAME}", true)
                }
            }
        }

        stage('Build Nginx Image') {
            when {
                allOf {
                    expression { params.BUILD_NGINX }
                    branch 'main'
                }
            }
            steps {
                script {
                    echo "🐳 Building Nginx Docker image..."
                    sendSlackNotification('#FFFF00', "🐳 ${env.APP_NAME}: Nginx Build started")

                    sh """
                        cd server-configs
                        docker build \\
                            -f Dockerfile.nginx \\
                            -t ${env.DOCKER_IMAGE_NAME}:nginx .
                    """

                    // Push Nginx image to ECR using reusable function
                    dockerPush(env.DOCKER_IMAGE_NAME, 'nginx')

                    echo "✅ Nginx image built and pushed successfully"
                    sendSlackNotification('#00FF00', "✅ ${env.APP_NAME}: Nginx image pushed to ECR")
                }
            }
        }

        stage('Push APP Docker Image') {
            when {
                allOf {
                    expression { !params.BUILD_NGINX }
                    branch 'main'
                }
            }
            steps {
                script {
                    echo "🚀 Pushing ${env.APP_NAME} Docker image to ECR..."
                    sendSlackNotification('#FFFF00', "🚀 ${env.APP_NAME}: Pushing to ECR: ${env.DOCKER_IMAGE_TAG}")

                    dockerPush(env.DOCKER_IMAGE_NAME)

                    echo "✅ ${env.APP_NAME} Docker image pushed successfully"
                    sendSlackNotification('#00FF00', "✅ ${env.APP_NAME}: Image pushed to ECR: ${env.DOCKER_IMAGE_TAG}")
                }
            }
        }

        stage('Deploy to Server') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Starting ${env.APP_NAME} server deployment..."
                    sendSlackNotification('#FFFF00', "🚀 ${env.APP_NAME}: Server Deployment started: ${env.BRANCH_NAME}")

                    deployToServer(env.SERVER_IP)
                    echo "✅ ${env.APP_NAME} server deployment completed successfully"
                    sendSlackNotification('#00FF00', "✅ ${env.APP_NAME}: Server Deployment completed: ${env.BRANCH_NAME}")
                }
            }
        }
    }

    post {
        always {
            script {
                // Only run cleanup for main branch
                if (env.BRANCH_NAME == 'main') {
                    sh "docker system prune -f || true"
                    echo "🧹 ${env.APP_NAME}: Workspace cleanup completed"
                }
            }
        }
        success {
            script {
                // Only send success notification for main branch
                if (env.BRANCH_NAME == 'main') {
                    sendSlackNotification('#36A64F', "✅ ${env.APP_NAME}: Deployment successful: ${env.BRANCH_NAME}")
                }
            }
        }
        failure {
            script {
                // Only send failure notification for main branch
                if (env.BRANCH_NAME == 'main') {
                    sendSlackNotification('#FF0000', "❌ ${env.APP_NAME}: Deployment failed: ${env.BRANCH_NAME}", true)
                }
            }
        }
    }
}

// Updated helper to support optional channel override
// color: Slack color string, message: text, includeUrl: append BUILD_URL, channel: override target channel
// Defaults channel to env.SLACK_CHANNEL
// Example override: sendSlackNotification('#00FF00', 'ok', false, '#custom-channel')
def sendSlackNotification(color, message, includeUrl = false, channel = null) {
    def resolvedChannel = channel ?: env.SLACK_CHANNEL
    def fullMessage = includeUrl ? "${message}\nBuild URL: ${env.BUILD_URL}" : message
    slackSend(channel: resolvedChannel, color: color, message: fullMessage)
}

def configureEnvironmentAndDockerCompose(server, sourceComposeName = "docker-compose") {
    echo "Configuring environment and docker compose for server: ${server}"

    withCredentials([[
        $class: 'AmazonWebServicesCredentialsBinding',
        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY', // pragma: allowlist secret
        credentialsId: env.AWS_CREDENTIALS
    ]]) {
        sh """
            # Get secrets from AWS Secrets Manager and save to server-configs
            aws secretsmanager get-secret-value \\
                --secret-id ${env.AWS_SECRET_MANAGER} \\
                --query SecretString \\
                --output text \\
                --region ${env.AWS_REGION} | \\
            jq -r 'to_entries[] | "\\(.key)=\\(.value|tostring)"' > server-configs/.env
            
            # Process server docker-compose with variable substitution
            sed -e "s/\\\${DOCKER_IMAGE_TAG}/${env.DOCKER_IMAGE_TAG}/g" \\
                -e "s/\\\${AWS_ACCOUNT_ID}/${env.AWS_ACCOUNT_ID}/g" \\
                -e "s/\\\${AWS_REGION}/${env.AWS_REGION}/g" \\
                -e "s/\\\${DOCKER_IMAGE_NAME}/${env.DOCKER_IMAGE_NAME}/g" \\
                -e "s/\\\${APP_NAME}/${env.APP_NAME}/g" \\
                server-configs/docker-compose.yml > /tmp/docker-compose.yml
        """
    }

    sh """
        scp -o StrictHostKeyChecking=no /tmp/docker-compose.yml ubuntu@${server}:/home/ubuntu/${env.APP_NAME}/docker-compose.yml &
        scp -o StrictHostKeyChecking=no server-configs/.env ubuntu@${server}:/home/ubuntu/${env.APP_NAME}/ &
        wait
        
        # Clean up temp files
        rm -f /tmp/docker-compose.yml server-configs/.env
    """
}

def dockerPush(imageName, imageTag = null) {
    def tag = imageTag ?: env.DOCKER_IMAGE_TAG
    
    withCredentials([[
        $class: 'AmazonWebServicesCredentialsBinding',
        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY', // pragma: allowlist secret
        credentialsId: env.AWS_CREDENTIALS
    ]]) {
        sh """
            aws ecr get-login-password --region ${env.AWS_REGION} | \
            docker login --username AWS --password-stdin ${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com

            docker tag ${imageName}:${tag} \
                ${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${imageName}:${tag}

            docker push ${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${imageName}:${tag}
        """
    }
}

def runOnServer(server, command) {
    sh "ssh -o StrictHostKeyChecking=no ubuntu@${server} -t 'cd /home/ubuntu/${env.APP_NAME} && ${command}'"
}

def updateDockerImageOnServers(server) {
    sh """
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@${server} -t "
            aws ecr get-login-password --region ${env.AWS_REGION} | \
            docker login --username AWS --password-stdin ${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com && \
            docker pull ${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.DOCKER_IMAGE_NAME}:${env.DOCKER_IMAGE_TAG}
        "
    """
}

def restartContainers(server) {
    sh """
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@${server} -t "
            cd /home/ubuntu/${env.APP_NAME} && \
            docker compose -f docker-compose.yml up -d --force-recreate --build && \
            docker image prune -a -f
        "
    """
}

def deployToServer(server, sourceComposeName = "docker-compose") {
    try {
        echo "🚀 Starting deployment to ${env.APP_NAME} Server: ${server}"
        sendSlackNotification('#FFFF00', "🚀 Deploying to ${env.APP_NAME} Server: ${server}")

        configureEnvironmentAndDockerCompose(server, sourceComposeName)
        updateDockerImageOnServers(server)
        restartContainers(server)

        echo "✅ ${env.APP_NAME} Server updated successfully: ${server}"
        sendSlackNotification('#00FF00', "✅ ${env.APP_NAME} Server updated: ${server}")
    } catch (Exception e) {
        sendSlackNotification('#FF0000', "❌ ${env.APP_NAME} deployment failed: ${e.getMessage()}", true)
        throw e
    }
}