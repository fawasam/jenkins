pipeline {
    agent any

    environment {
        // Docker Hub credentials binding (use credentials id stored in Jenkins)
        DOCKERHUB_CREDENTIALS = credentials('fawaswebcastle-dockerhub')
        DOCKER_REPO = "fawaswebcastle/my-project"
        // Use build number as immutable tag
        DOCKER_TAG = "${env.BUILD_NUMBER}"

        DEPLOY_HOST = "3.110.157.196"
        DEPLOY_USER = "ubuntu"
        DEPLOY_PATH = "/var/www/jenkins-test"

        // Optional: your domain and email for Let's Encrypt (set in Jenkins job as environment variables if available)
        DOMAIN = "your.domain.com"
        EMAIL = "admin@your.domain.com"

        // Blue/Green ports (on remote host)
        BLUE_PORT = "3001"
        GREEN_PORT = "3002"

        // Nginx config path (internal decision file will store current color)
        NGINX_CONFIG_PATH = "/etc/nginx/sites-available/jenkins-test"
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
                    sh '''
                    docker build -t node-app:latest -t node-app:$DOCKER_TAG .
                    '''
                }
            }
        }

        stage('Docker Login & Push') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'fawaswebcastle-dockerhub', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                        echo "Logging into Docker Hub..."
                        sh '''
                        echo $PASS | docker login -u $USER --password-stdin
                        '''

                        echo "Tagging and pushing image..."
                        sh '''
                        docker tag node-app:latest $DOCKER_REPO:latest
                        docker tag node-app:latest $DOCKER_REPO:$DOCKER_TAG
                        docker push $DOCKER_REPO:latest
                        docker push $DOCKER_REPO:$DOCKER_TAG
                        echo "Successfully pushed $DOCKER_REPO:latest and $DOCKER_REPO:$DOCKER_TAG"
                        '''
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
                            sh '''
                                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $DEPLOY_USER@$DEPLOY_HOST 'echo "✅ SSH connection successful!" && hostname && whoami'
                            '''
                        }
                    } catch (Exception e) {
                        error("❌ SSH connection failed: ${e.getMessage()}\n\nPlease check:\n1. SSH credentials 'ec2-ssh-key' are configured in Jenkins\n2. SSH Agent Plugin is installed\n3. EC2 instance is accessible from Jenkins agent")
                    }
                }
            }
        }

        stage('Setup Infrastructure (NGINX/Certbot/Portainer)') {
            steps {
                script {
                    sshagent(['ec2-ssh-key']) {
                        sh '''
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST "
                            # Install NGINX if not present
                            if ! command -v nginx &> /dev/null; then
                                sudo apt-get update && sudo apt-get install -y nginx || true
                            fi

                            # Install Certbot if not present
                            if ! command -v certbot &> /dev/null; then
                                sudo apt-get install -y certbot python3-certbot-nginx || true
                            fi

                            # Setup Portainer if not running
                            if ! sudo docker ps -a | grep -q '^portainer$'; then
                                sudo docker volume create portainer_data || true
                                sudo docker run -d -p 9000:9000 --name portainer --restart=always \
                                  -v /var/run/docker.sock:/var/run/docker.sock \
                                  -v portainer_data:/data portainer/portainer-ce
                            fi

                            echo '✅ NGINX/Certbot/Portainer prep done'
                        "
                        '''
                    }
                }
            }
        }

        stage('Blue/Green Deploy (Docker Compose)') {
            steps {
                script {
                    try {
                        sshagent(['ec2-ssh-key']) {
                            echo "Starting Blue/Green deployment"

                            sh '''
                            ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST "
                                set -e
                                cd ${DEPLOY_PATH}

                                # Determine current color (blue or green)
                                if [ -f .bg_current ]; then
                                    CURRENT_COLOR=$(cat .bg_current)
                                else
                                    CURRENT_COLOR=green
                                fi

                                if [ \"$CURRENT_COLOR\" = "blue" ]; then
                                    NEW_COLOR=green
                                    NEW_PORT=${GREEN_PORT}
                                    OLD_PORT=${BLUE_PORT}
                                else
                                    NEW_COLOR=blue
                                    NEW_PORT=${BLUE_PORT}
                                    OLD_PORT=${GREEN_PORT}
                                fi

                                echo "Current color: $CURRENT_COLOR -> deploying to: $NEW_COLOR on port $NEW_PORT"

                                # Create a directory for the new color deployment
                                mkdir -p ${DEPLOY_PATH}/$NEW_COLOR

                                # Create a minimal docker-compose-blue/green from base compose but override image tag and port
                                # Prefer docker-compose.multi.yml if present (multi-container stack support)
                                if [ -f docker-compose.multi.yml ]; then
                                    COMPOSE_FILE=docker-compose.multi.yml
                                else
                                    COMPOSE_FILE=docker-compose.yml
                                fi

                                # Generate a temporary compose that forces the image tag and port mapping
                                cat > ${DEPLOY_PATH}/$NEW_COLOR/docker-compose.yml <<EOF
version: '3.8'
services:
  nextapp:
    image: ${DOCKER_REPO}:${DOCKER_TAG}
    container_name: nextapp_${NEW_COLOR}
    restart: always
    ports:
      - "${NEW_PORT}:3000"
    environment:
      NODE_ENV: production
EOF

                                # If a multi-container compose exists, copy it instead and replace the image tag where applicable
                                if [ -f $COMPOSE_FILE ] && [ "$COMPOSE_FILE" != "docker-compose.yml" ]; then
                                    # copy base multi-compose and try to replace image placeholders
                                    cp $COMPOSE_FILE ${DEPLOY_PATH}/$NEW_COLOR/docker-compose.multi.yml || true
                                    sed -i "s#image: .*#image: ${DOCKER_REPO}:${DOCKER_TAG}#g" ${DEPLOY_PATH}/$NEW_COLOR/docker-compose.multi.yml || true
                                fi

                                # Start the new stack
                                cd ${DEPLOY_PATH}/$NEW_COLOR
                                sudo docker compose pull || sudo docker-compose pull || true
                                sudo docker compose up -d --remove-orphans || sudo docker-compose up -d --remove-orphans

                                # Health check - wait and probe the new port
                                ATTEMPTS=0
                                MAX=12
                                until curl -s --fail http://127.0.0.1:$NEW_PORT/_next/ || curl -s --fail http://127.0.0.1:$NEW_PORT/ || [ $ATTEMPTS -ge $MAX ]; do
                                    ATTEMPTS=$((ATTEMPTS+1))
                                    echo "Waiting for new service to become healthy... attempt $ATTEMPTS"
                                    sleep 2
                                done

                                if [ $ATTEMPTS -ge $MAX ]; then
                                    echo "❌ New deployment did not become healthy, rolling back"
                                    sudo docker compose down || sudo docker-compose -f ${DEPLOY_PATH}/$NEW_COLOR/docker-compose.yml down || true
                                    exit 1
                                fi

                                # Update NGINX configuration to point to new port (optional - requires DNS record pointing to host)
                                if [ -n "${DOMAIN}" ] && [ "${DOMAIN}" != "your.domain.com" ]; then
                                    # Update nginx config to proxy to the new port
                                    sudo sed -i "s/proxy_pass http:\/\/.*:.*;/proxy_pass http:\/\/127.0.0.1:$NEW_PORT;/g" ${NGINX_CONFIG_PATH} || true
                                    sudo nginx -t && sudo systemctl reload nginx || true
                                    
                                    # Setup SSL certificate if domain is configured
                                    if [ -n "${EMAIL}" ] && [ "${EMAIL}" != "admin@your.domain.com" ]; then
                                        sudo certbot --nginx --non-interactive --agree-tos -m ${EMAIL} -d ${DOMAIN} || true
                                    fi
                                fi

                                # Update current pointer
                                echo $NEW_COLOR > ${DEPLOY_PATH}/.bg_current

                                # Stop old stack (optional: keep it for quick rollback)
                                if [ -d ${DEPLOY_PATH}/$CURRENT_COLOR ]; then
                                    cd ${DEPLOY_PATH}/$CURRENT_COLOR
                                    sudo docker compose down || sudo docker-compose down || true
                                fi

                                echo '✅ Blue/Green swap complete'
                            "
                            '''

                        }
                    } catch (Exception e) {
                        echo "❌ Blue/Green deployment failed: ${e.getMessage()}"
                        currentBuild.result = 'FAILURE'
                        error("Blue/Green deployment failed: ${e.getMessage()}")
                    }
                }
            }
        }

        stage('Post-Deploy Monitoring & Logs') {
            steps {
                script {
                    // Collect logs and basic monitoring info from remote host
                    sshagent(['ec2-ssh-key']) {
                        sh '''
                        REMOTE_LOG=deployment_logs_${BUILD_NUMBER}.log
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST "
                            echo '=== docker ps -a ===' && sudo docker ps -a
                            echo '\n=== docker images (top 20) ===' && sudo docker images | head -20
                            echo '\n=== docker-compose recent logs (last 200 lines) ===' && sudo docker compose logs --tail=200 || sudo docker-compose logs --tail=200
                        " > $REMOTE_LOG

                        echo "Downloading logs to Jenkins workspace: $REMOTE_LOG"
                        # Ensure file exists locally (it is generated by the ssh redirection above)
                        ls -lah $REMOTE_LOG || true
                        ''', returnStdout: true

                        // Optionally archive artifact (requires pipeline to be able to archive)
                        archiveArtifacts artifacts: "deployment_logs_${BUILD_NUMBER}.log", fingerprint: true, allowEmptyArchive: true
                    }
                }
            }
        }

        stage('Rollback (Manual Trigger)') {
            when {
                expression { return params.ROLLBACK == true }
            }
            steps {
                script {
                    echo "⚠️ Initiating manual rollback..."
                    sshagent(['ec2-ssh-key']) {
                        sh """
                        ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$DEPLOY_HOST '
                            set -e
                            cd ${DEPLOY_PATH}

                            echo "Checking current deployment color..."
                            if [ -f .bg_current ]; then
                                CURRENT_COLOR=$(cat .bg_current)
                            else
                                echo "No .bg_current found — cannot determine previous state"
                                exit 1
                            fi

                            if [ "$CURRENT_COLOR" = "blue" ]; then
                                ROLLBACK_COLOR=green
                            else
                                ROLLBACK_COLOR=blue
                            fi

                            echo "Rolling back to: $ROLLBACK_COLOR"

                            if [ ! -d ${DEPLOY_PATH}/$ROLLBACK_COLOR ]; then
                                echo "Rollback directory not found: ${DEPLOY_PATH}/$ROLLBACK_COLOR"
                                exit 1
                            fi

                            # Start rollback container
                            cd ${DEPLOY_PATH}/$ROLLBACK_COLOR
                            sudo docker compose up -d --remove-orphans || sudo docker-compose up -d --remove-orphans

                            # Detect rollback port
                            if [ "$ROLLBACK_COLOR" = "blue" ]; then
                                ROLLBACK_PORT=${BLUE_PORT}
                            else
                                ROLLBACK_PORT=${GREEN_PORT}
                            fi

                            # Update NGINX configuration to point to rollback port (optional)
                            if [ -n "${DOMAIN}" ] && [ "${DOMAIN}" != "your.domain.com" ]; then
                                sudo sed -i "s/proxy_pass http:\/\/.*:.*;/proxy_pass http:\/\/127.0.0.1:$ROLLBACK_PORT;/g" ${NGINX_CONFIG_PATH} || true
                                sudo nginx -t && sudo systemctl reload nginx || true
                            fi

                            # Update current color pointer
                            echo $ROLLBACK_COLOR > ${DEPLOY_PATH}/.bg_current

                            echo "Rollback completed to $ROLLBACK_COLOR ($ROLLBACK_PORT)"
                        '
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
            echo "❌ Deployment failed. Check logs above and the archive artifact for details."
        }
    }
}
