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
                        
                        // Login to Docker Hub using credentials
                        withCredentials([usernamePassword(credentialsId: 'fawaswebcastle-dockerhub', 
                                                         usernameVariable: 'DOCKER_USER', 
                                                         passwordVariable: 'DOCKER_PASS')]) {
                            sh '''
                                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                            '''
                        }
                        
                        // Build Docker image
                        echo "Building image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        sh """
                            docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        """
                        
                        // Tag as latest
                        sh """
                            docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                        """
                        
                        echo "Image built successfully: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        
                        // Push both tags
                        echo "Pushing image with tag: ${DOCKER_TAG}"
                        sh """
                            docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        """
                        
                        echo "Pushing image with tag: latest"
                        sh """
                            docker push ${DOCKER_IMAGE}:latest
                        """
                        
                        
                        echo "Successfully pushed ${DOCKER_IMAGE}:${DOCKER_TAG} to Docker Hub"
                        
                    } catch (Exception err) {
                        echo "ERROR: Docker build or push failed!"
                        echo "Error message: ${err.getMessage()}"
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
                    sh """
                        docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} sh -c 'echo "Container is running!" && node --version && npm --version'
                    """
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