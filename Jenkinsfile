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
        
        stage('Verify Docker') {
            steps {
                script {
                    sh 'docker --version'
                    sh 'docker info'
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        echo "Building Docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        echo "Docker registry: https://index.docker.io/v1/"
                        echo "Credentials ID: fawaswebcastle-dockerhub"
                        
                        // Verify Dockerfile exists
                        sh 'test -f Dockerfile || (echo "ERROR: Dockerfile not found!" && exit 1)'
                        sh 'test -f package.json || (echo "ERROR: package.json not found!" && exit 1)'
                        
                        docker.withRegistry('https://index.docker.io/v1/', 'fawaswebcastle-dockerhub') {
                            def customImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}", ".")
                            
                            echo "Image built successfully: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                            
                            echo "Pushing image with tag: ${DOCKER_TAG}"
                            customImage.push("${DOCKER_TAG}")
                            
                            echo "Pushing image with tag: latest"
                            customImage.push("latest")
                            
                            echo "Successfully pushed ${DOCKER_IMAGE}:${DOCKER_TAG} to Docker Hub"
                        }
                    } catch (Exception err) {
                        echo "ERROR: Docker build or push failed!"
                        echo "Error message: ${err.getMessage()}"
                        echo "Error class: ${err.getClass()}"
                        err.printStackTrace()
                        currentBuild.result = 'FAILURE'
                        error("Stopping pipeline because Docker build or push failed.")
                    }
                }
            }
        }
        
        stage('Test Docker Image') {
            steps {
                script {
                    echo "Testing Docker image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    def testImage = docker.image("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    testImage.inside {
                        sh 'echo "Container is running!"'
                        sh 'node --version'
                        sh 'npm --version'
                        // Add your test commands here
                        // sh 'npm test'
                        // sh 'npm run lint'
                    }
                    echo "Docker image test completed successfully"
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