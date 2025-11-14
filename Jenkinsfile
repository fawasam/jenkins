pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('fawaswebcastle-dockerhub')
        DOCKER_REPO = "fawaswebcastle/my-project"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        DEPLOY_HOST = "3.110.157.196"
        DEPLOY_USER = "ubuntu"
        DEPLOY_PATH = "/var/www/jenkins-test"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/fawasam/jenkins.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image..."
                    sh """
                    docker build -t node-app:latest -t node-app:\$DOCKER_TAG .
                    """
                }
            }
        }

        stage('Docker Login & Push') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'fawaswebcastle-dockerhub', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                        echo "Logging into Docker Hub..."
                        sh """
                        echo \$PASS | docker login -u \$USER --password-stdin
                        """
                        
                        echo "Tagging and pushing image..."
                        sh """
                        docker tag node-app:latest \$DOCKER_REPO:latest
                        docker tag node-app:latest \$DOCKER_REPO:\$DOCKER_TAG
                        docker push \$DOCKER_REPO:latest
                        docker push \$DOCKER_REPO:\$DOCKER_TAG
                        echo "Successfully pushed \$DOCKER_REPO:latest and \$DOCKER_REPO:\$DOCKER_TAG"
                        """
                    }
                }
            }
        }

        stage('Test SSH Connection') {
            steps {
                script {
                    try {
                        sshagent(['ec2-ssh-key']) {
                            echo "Testing SSH connection to $DEPLOY_USER@$DEPLOY_HOST"
                            sh """
                                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $DEPLOY_USER@$DEPLOY_HOST 'echo "✅ SSH connection successful!" && hostname && whoami'
                            """
                        }
                    } catch (Exception e) {
                        error("❌ SSH connection failed: ${e.getMessage()}\n\nPlease check:\n1. SSH credentials 'ec2-ssh-key' are configured in Jenkins\n2. SSH Agent Plugin is installed\n3. EC2 instance is accessible from Jenkins agent")
                    }
                }
            }
        }

        stage('Deploy on EC2 through Docker Compose') {
            steps {
                script {
                    try {
                        sshagent(['ec2-ssh-key']) {
                            echo "🚀 Starting deployment on EC2 via Docker Compose"
                            echo "📍 Connecting to: $DEPLOY_USER@$DEPLOY_HOST"
                            echo "📁 Deployment path: $DEPLOY_PATH"

                            // Test SSH connection first
                            echo "🔍 Testing SSH connection..."
                            sh """
                                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $DEPLOY_USER@$DEPLOY_HOST 'echo "Connected to \$(hostname)"'
                            """

                            // Check if deployment path exists
                            echo "🔍 Checking deployment path..."
                            sh """
                                ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST 'test -d $DEPLOY_PATH && echo "✅ Path exists" || echo "❌ Path does not exist - creating it..." && sudo mkdir -p $DEPLOY_PATH && sudo chown \$USER:\$USER $DEPLOY_PATH'
                            """

                            // Check if docker-compose.yml exists
                            echo "🔍 Checking for docker-compose.yml..."
                            sh """
                                ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST 'cd $DEPLOY_PATH && test -f docker-compose.yml && echo "✅ docker-compose.yml found" || echo "⚠️  docker-compose.yml not found"'
                            """

                            // Main deploy step
                            echo "🚀 Running deployment..."
                            sh """
                                ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST "
                                    set -e
                                    cd $DEPLOY_PATH
                                    echo '📥 Pulling latest images...'
                                    sudo docker-compose pull || sudo docker compose pull
                                    echo '🚀 Starting containers...'
                                    sudo docker-compose up -d || sudo docker compose up -d
                                    echo '🧹 Cleaning up unused images...'
                                    sudo docker image prune -f
                                    echo '📊 Current containers:'
                                    sudo docker ps -a
                                    echo '📦 Current images:'
                                    sudo docker images | head -10
                                    echo '✅ Deployment completed!'
                                "
                            """

                            echo "✅ Deployment successful!"
                        }
                    } catch (Exception e) {
                        echo "❌ Deployment failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Deployment failed: ${e.getMessage()}")
                    }
                }
            }
        }
    }

    post {
        success {
            echo "🎉 Deployment successful!"
        }
        failure {
            echo "❌ Deployment failed."
        }
    }
}
