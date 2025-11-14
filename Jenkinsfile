pipeline {
    agent any
    
    environment {
        NODE_VERSION = '18'
        PROJECT_NAME = 'my-project'
        DOCKERHUB_CREDENTIALS=credentials('fawaswebcastle-dockerhub')
    }
    
    stages {
          stage('Greet'){
            steps{
                echo '~k Hello from jenkins! This is my first pipeline'
            }
        }
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building the application...'
                sh 'npm install'
                sh 'npm run build'
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                sh 'npm test'
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Deploying the application...'
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            cleanWs()
        }
    }
}