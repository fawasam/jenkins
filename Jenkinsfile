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
                    sh """
                    ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST '
                        cd $DEPLOY_PATH &&
                        sudo docker-compose pull &&
                        sudo docker-compose up -d &&
                        sudo docker image prune -f
                    '
                    """
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
