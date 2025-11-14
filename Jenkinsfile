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

        stage('Deploy on EC2 through Docker Compose') {
            steps {
                sshagent(['ec2-ssh-key']) {
                    script {
                        echo "Starting deployment on EC2 via Docker Compose"
                        echo "Connecting to: $DEPLOY_USER@$DEPLOY_HOST"
                        echo "Deployment path: $DEPLOY_PATH"

                        // Print current local docker-compose version for debug
                        sh 'docker-compose version || docker compose version || true'

                        // Test SSH connection
                        sh """
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST 'echo "Connected to \$(hostname)"; which docker-compose || which docker'
                        """

                        // Print free disk space before deploy
                        sh """
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST 'echo "Free disk space before deploy:" && df -h'
                        """

                        // Print current containers and images before deploy
                        sh """
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST 'echo "Running containers before deploy:" && sudo docker ps -a; echo "Docker images before deploy:" && sudo docker images'
                        """

                        // Main deploy step, capture and print output line by line
                        def deployCmd = """
                        set -ex
                        cd $DEPLOY_PATH
                        sudo docker-compose pull
                        sudo docker-compose up -d
                        sudo docker image prune -f
                        sudo docker ps -a
                        sudo docker images
                        """
                        echo "Running remote deployment script..."
                        sh """
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST '${deployCmd.replaceAll("'", "'\\\\''")}'
                        """

                        // Print free disk space after deploy
                        sh """
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST 'echo "Free disk space after deploy:" && df -h'
                        """
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
