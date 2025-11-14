pipeline {
    agent any
    
    environment {
        NODE_VERSION = '18'
        PROJECT_NAME = 'my-project'
        DOCKERHUB_CREDENTIALS = credentials('fawaswebcastle-dockerhub')
        DOCKER_IMAGE = 'fawaswebcastle/my-project'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('Greet') {
            steps {
                echo '~k Hello from jenkins! This is my first pipeline'
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo 'Building Docker image...'
                    docker.withRegistry('https://index.docker.io/v1/', 'fawaswebcastle-dockerhub') {
                        def customImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                        customImage.push()
                        customImage.push("latest")
                    }
                }
            }
        }
        
        stage('Test Docker Image') {
            steps {
                script {
                    echo 'Testing Docker image...'
                    def testImage = docker.image("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    testImage.inside {
                        sh 'echo "Container is running!"'
                        // Add your test commands here
                        // sh 'npm test'
                        // sh 'npm run lint'
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    echo 'Deploying Docker container...'
                    sh '''
                        docker stop ${PROJECT_NAME} || true
                        docker rm ${PROJECT_NAME} || true
                        docker run -d --name ${PROJECT_NAME} \
                            -p 3000:3000 \
                            ${DOCKER_IMAGE}:${DOCKER_TAG}
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline succeeded!'
            script {
                // Clean up old images
                sh 'docker image prune -f'
            }
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            cleanWs()
        }
    }
}