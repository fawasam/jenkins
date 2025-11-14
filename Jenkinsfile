pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('fawaswebcastle-dockerhub')
        DOCKER_REPO = "fawaswebcastle/my-project"
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
                sh """
                docker build -t node-app .
                """
            }
        }

        stage('Docker Login & Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    sh """
                    echo \$PASS | docker login -u \$USER --password-stdin
                    docker tag nextjs-app:latest \$DOCKER_REPO:latest
                    docker push \$DOCKER_REPO:latest
                    """
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
