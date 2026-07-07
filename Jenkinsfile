pipeline {
    agent { label 'docker-agent' }

    options {
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'demo-app'
        REGISTRY = 'ghcr.io/gapropp123'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.BUILD_TIME = sh(script: 'date -u +%Y-%m-%dT%H:%M:%SZ', returnStdout: true).trim()
                }
                echo "building commit ${env.GIT_COMMIT_SHORT}"
            }
        }

        stage('Compile') {
            steps {
                dir('app') {
                    sh 'mvn -B -q compile'
                }
            }
        }

        stage('Test & Quality') {
            parallel {
                stage('Unit Test') {
                    steps {
                        dir('app') {
                            sh 'mvn -B test'
                        }
                    }
                    post {
                        always {
                            junit 'app/target/surefire-reports/*.xml'
                            jacoco execPattern: 'app/target/jacoco.exec',
                                   classPattern: 'app/target/classes',
                                   sourcePattern: 'app/src/main/java'
                        }
                    }
                }

                stage('Code Quality') {
                    steps {
                        dir('app') {
                            sh 'mvn -B checkstyle:check'
                        }
                    }
                }
            }
        }

        stage('Package') {
            steps {
                dir('app') {
                    sh 'mvn -B -q package -DskipTests'
                }
                archiveArtifacts artifacts: 'app/target/demo-app.jar', fingerprint: true
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build -f docker/Dockerfile \
                        --build-arg APP_VERSION=${env.GIT_COMMIT_SHORT} \
                        --build-arg GIT_COMMIT=${env.GIT_COMMIT_SHORT} \
                        --build-arg BUILD_TIME=${env.BUILD_TIME} \
                        -t ${IMAGE_NAME}:${env.GIT_COMMIT_SHORT} .
                """
            }
        }

        stage('Container Validation') {
            steps {
                script {
                    def container = "${IMAGE_NAME}-validate-${BUILD_NUMBER}"
                    env.VALIDATE_CONTAINER = container
                    sh """
                        docker rm -f ${container} || true
                        docker run -d --rm --name ${container} --network cicd-net ${IMAGE_NAME}:${env.GIT_COMMIT_SHORT}
                    """
                    sh """
                        for i in \$(seq 1 30); do
                            code=\$(curl -s -o /dev/null -w '%{http_code}' http://${container}:8080/actuator/health || true)
                            [ "\$code" = "200" ] && break
                            sleep 1
                        done
                        curl -sf http://${container}:8080/version
                    """
                }
            }
            post {
                always {
                    sh "docker rm -f ${env.VALIDATE_CONTAINER} || true"
                }
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(
                        credentialsId: 'ghcr-credentials',
                        usernameVariable: 'GHCR_USER',
                        passwordVariable: 'GHCR_TOKEN')]) {
                    sh '''
                        echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
                    '''
                }
                sh """
                    docker tag ${IMAGE_NAME}:${env.GIT_COMMIT_SHORT} ${REGISTRY}/${IMAGE_NAME}:${env.GIT_COMMIT_SHORT}
                    docker push ${REGISTRY}/${IMAGE_NAME}:${env.GIT_COMMIT_SHORT}
                """
                script {
                    if (env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'main' || !env.BRANCH_NAME) {
                        sh """
                            docker tag ${IMAGE_NAME}:${env.GIT_COMMIT_SHORT} ${REGISTRY}/${IMAGE_NAME}:latest
                            docker push ${REGISTRY}/${IMAGE_NAME}:latest
                        """
                    }
                }
            }
            post {
                always {
                    sh 'docker logout ghcr.io || true'
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-deployer', variable: 'KUBECONFIG')]) {
                    sh """
                        sed 's|image: demo-app:.*|image: ${REGISTRY}/${IMAGE_NAME}:${env.GIT_COMMIT_SHORT}|' k8s/deployment.yaml > deployment-deploy.yaml
                        kubectl apply -f k8s/configmap.yaml
                        kubectl apply -f deployment-deploy.yaml
                        kubectl apply -f k8s/service.yaml
                    """
                }
            }
        }

        stage('Rollout Verify & Smoke Test') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-deployer', variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            sh 'kubectl rollout status deployment/demo-app -n default --timeout=120s'
                            sh """
                                NODE_HOST=\$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed -E 's#https://##; s#:.*##')
                                NODEPORT=\$(kubectl get svc demo-app -n default -o jsonpath='{.spec.ports[0].nodePort}')
                                for i in \$(seq 1 30); do
                                    ACTUAL=\$(curl -sf "http://\$NODE_HOST:\$NODEPORT/version" | jq -r .commit 2>/dev/null || true)
                                    [ "\$ACTUAL" = "${env.GIT_COMMIT_SHORT}" ] && break
                                    sleep 2
                                done
                                if [ "\$ACTUAL" != "${env.GIT_COMMIT_SHORT}" ]; then
                                    echo "smoke test failed: expected ${env.GIT_COMMIT_SHORT}, got \$ACTUAL"
                                    exit 1
                                fi
                                echo "smoke test passed: /version returned ${env.GIT_COMMIT_SHORT}"
                            """
                        } catch (err) {
                            echo "deploy verification failed: ${err}"
                            echo "collecting diagnostics before rolling back (the failing pods disappear once rolled back)"
                            sh '''
                                echo "--- failed image tag ---"
                                echo "''' + "${REGISTRY}/${IMAGE_NAME}:${env.GIT_COMMIT_SHORT}" + '''"
                                echo "--- kubectl get pods -o wide ---"
                                kubectl get pods -n default -o wide || true
                                echo "--- kubectl describe pods ---"
                                kubectl describe pods -n default -l app=demo-app || true
                                echo "--- kubectl get events (most recent last) ---"
                                kubectl get events -n default --sort-by=.lastTimestamp || true
                                echo "--- kubectl logs (current + previous container, best effort) ---"
                                kubectl logs -n default -l app=demo-app --tail=80 --all-containers || true
                                kubectl logs -n default -l app=demo-app --tail=80 --all-containers --previous || true
                                echo "--- rollout history ---"
                                kubectl rollout history deployment/demo-app -n default || true
                            '''
                            echo "rolling back to the previous revision"
                            sh 'kubectl rollout undo deployment/demo-app -n default'
                            sh 'kubectl rollout status deployment/demo-app -n default --timeout=120s'
                            error("deployment failed verification and was rolled back to the previous revision")
                        }
                    }
                }
            }
        }
    }

    post {
        failure {
            echo "build failed at stage '${env.STAGE_NAME ?: 'unknown'}' for commit ${env.GIT_COMMIT_SHORT ?: 'unknown'} - see the stage log above for the actual error"
        }
        always {
            cleanWs()
        }
    }
}
