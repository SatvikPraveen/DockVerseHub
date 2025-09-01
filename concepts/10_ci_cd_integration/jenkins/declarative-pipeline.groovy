// 10_ci_cd_integration/jenkins/declarative-pipeline.groovy

@Library('docker-shared-library') _

pipeline {
    agent {
        kubernetes {
            yaml """
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: docker
                    image: docker:24.0.5-dind
                    securityContext:
                      privileged: true
                    env:
                    - name: DOCKER_TLS_CERTDIR
                      value: "/certs"
                  - name: kubectl
                    image: bitnami/kubectl:latest
                    command:
                    - sleep
                    args:
                    - 99d
                  - name: helm
                    image: alpine/helm:latest
                    command:
                    - sleep
                    args:
                    - 99d
            """
        }
    }

    parameters {
        choice(
            name: 'DEPLOYMENT_ENVIRONMENT',
            choices: ['staging', 'production'],
            description: 'Target deployment environment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip test execution'
        )
        booleanParam(
            name: 'FORCE_DEPLOY',
            defaultValue: false,
            description: 'Force deployment without approval'
        )
        string(
            name: 'CUSTOM_TAG',
            defaultValue: '',
            description: 'Custom image tag (optional)'
        )
    }

    environment {
        // Registry configuration
        REGISTRY_URL = 'harbor.company.com'
        REGISTRY_PROJECT = 'production'
        REGISTRY_CREDENTIALS = 'harbor-credentials'
        
        // Kubernetes configuration
        KUBECONFIG_STAGING = credentials('kubeconfig-staging')
        KUBECONFIG_PRODUCTION = credentials('kubeconfig-production')
        
        // Security scanning
        TRIVY_NO_PROGRESS = 'true'
        COSIGN_EXPERIMENTAL = '1'
        
        // Build configuration
        DOCKER_BUILDKIT = '1'
        BUILDKIT_PROGRESS = 'plain'
        
        // Notifications
        TEAMS_WEBHOOK = credentials('teams-webhook')
        JIRA_TOKEN = credentials('jira-api-token')
    }

    stages {
        stage('Initialize') {
            steps {
                container('docker') {
                    script {
                        // Set dynamic variables
                        env.BUILD_TIMESTAMP = sh(script: "date -u +'%Y%m%d%H%M%S'", returnStdout: true).trim()
                        env.GIT_SHORT_COMMIT = sh(script: "git rev-parse --short=8 HEAD", returnStdout: true).trim()
                        env.IMAGE_TAG = params.CUSTOM_TAG ?: "${env.BRANCH_NAME}-${env.BUILD_TIMESTAMP}-${env.GIT_SHORT_COMMIT}"
                        env.FULL_IMAGE_NAME = "${REGISTRY_URL}/${REGISTRY_PROJECT}/app:${env.IMAGE_TAG}"
                        
                        echo """
                            === Build Configuration ===
                            Branch: ${env.BRANCH_NAME}
                            Build: ${env.BUILD_NUMBER}
                            Timestamp: ${env.BUILD_TIMESTAMP}
                            Commit: ${env.GIT_SHORT_COMMIT}
                            Image Tag: ${env.IMAGE_TAG}
                            Full Image: ${env.FULL_IMAGE_NAME}
                            Environment: ${params.DEPLOYMENT_ENVIRONMENT}
                            Skip Tests: ${params.SKIP_TESTS}
                            Force Deploy: ${params.FORCE_DEPLOY}
                        """
                    }
                }
            }
        }

        stage('Parallel Quality Checks') {
            when {
                not { params.SKIP_TESTS }
            }
            parallel {
                stage('Unit Tests') {
                    agent {
                        docker {
                            image 'node:18-alpine'
                            args '-v ${WORKSPACE}:/workspace -w /workspace'
                        }
                    }
                    steps {
                        script {
                            dockerUtils.runTests([
                                testCommand: 'npm run test:unit',
                                coverageThreshold: 80,
                                reportFormat: 'junit'
                            ])
                        }
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'test-results.xml'
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'coverage',
                                reportFiles: 'index.html',
                                reportName: 'Unit Test Coverage'
                            ])
                        }
                    }
                }

                stage('Lint & Security') {
                    agent {
                        docker {
                            image 'node:18-alpine'
                            args '-v ${WORKSPACE}:/workspace -w /workspace'
                        }
                    }
                    steps {
                        script {
                            // Static code analysis
                            sh '''
                                npm ci --prefer-offline
                                npm run lint -- --format=checkstyle --output-file=eslint-results.xml
                                npm audit --audit-level moderate --json > npm-audit.json
                            '''
                        }
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: '.',
                                reportFiles: 'eslint-results.xml',
                                reportName: 'ESLint Report'
                            ])
                            archiveArtifacts artifacts: 'npm-audit.json', allowEmptyArchive: true
                        }
                    }
                }

                stage('Dockerfile Lint') {
                    agent {
                        docker {
                            image 'hadolint/hadolint:latest-alpine'
                            args '--entrypoint='
                        }
                    }
                    steps {
                        sh '''
                            hadolint Dockerfile --format checkstyle > hadolint-results.xml || true
                            hadolint Dockerfile --format json > hadolint-results.json || true
                        '''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'hadolint-results.*', allowEmptyArchive: true
                        }
                    }
                }
            }
        }

        stage('Docker Build & Test') {
            steps {
                container('docker') {
                    script {
                        // Build multi-stage image
                        dockerUtils.buildMultiStage([
                            dockerfile: 'Dockerfile',
                            platforms: ['linux/amd64', 'linux/arm64'],
                            buildArgs: [
                                BUILDTIME: env.BUILD_TIMESTAMP,
                                VERSION: env.IMAGE_TAG,
                                REVISION: env.GIT_COMMIT
                            ],
                            tags: [
                                env.FULL_IMAGE_NAME,
                                "${REGISTRY_URL}/${REGISTRY_PROJECT}/app:build-${BUILD_NUMBER}"
                            ],
                            cache: [
                                from: "type=registry,ref=${REGISTRY_URL}/${REGISTRY_PROJECT}/app:cache",
                                to: "type=registry,ref=${REGISTRY_URL}/${REGISTRY_PROJECT}/app:cache,mode=max"
                            ]
                        ])

                        // Test image functionality
                        sh """
                            docker run --rm --name smoke-test \
                                -e NODE_ENV=test \
                                ${env.FULL_IMAGE_NAME} \
                                timeout 30 npm run test:smoke
                        """
                    }
                }
            }
            post {
                always {
                    container('docker') {
                        sh '''
                            # Image inspection
                            docker image inspect ${FULL_IMAGE_NAME} > image-manifest.json
                            docker history ${FULL_IMAGE_NAME} > image-layers.txt
                            
                            # Size analysis
                            docker images ${FULL_IMAGE_NAME} --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" > image-size.txt
                        '''
                        archiveArtifacts artifacts: 'image-*.json,image-*.txt', fingerprint: true
                    }
                }
            }
        }

        stage('Security & Compliance') {
            parallel {
                stage('Container Security Scan') {
                    steps {
                        container('docker') {
                            script {
                                securityUtils.scanContainer([
                                    image: env.FULL_IMAGE_NAME,
                                    severity: ['HIGH', 'CRITICAL'],
                                    exitOnVuln: true,
                                    reportFormats: ['json', 'sarif']
                                ])
                            }
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'trivy-*.json,trivy-*.sarif', fingerprint: true
                        }
                    }
                }

                stage('Generate SBOM') {
                    steps {
                        container('docker') {
                            sh '''
                                # Install Syft
                                curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
                                
                                # Generate SBOM in multiple formats
                                syft ${FULL_IMAGE_NAME} -o spdx-json --file sbom.spdx.json
                                syft ${FULL_IMAGE_NAME} -o cyclonedx-json --file sbom.cyclonedx.json
                                syft ${FULL_IMAGE_NAME} -o table --file sbom-summary.txt
                            '''
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'sbom.*', fingerprint: true
                        }
                    }
                }

                stage('Image Signing') {
                    when {
                        anyOf {
                            branch 'main'
                            buildingTag()
                        }
                    }
                    steps {
                        container('docker') {
                            script {
                                // Sign with Cosign
                                withCredentials([string(credentialsId: 'cosign-private-key', variable: 'COSIGN_PRIVATE_KEY')]) {
                                    sh '''
                                        # Install Cosign
                                        curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
                                        mv cosign-linux-amd64 /usr/local/bin/cosign
                                        chmod +x /usr/local/bin/cosign
                                        
                                        # Sign image
                                        echo "${COSIGN_PRIVATE_KEY}" | cosign sign --key env://COSIGN_PRIVATE_KEY ${FULL_IMAGE_NAME}
                                        
                                        # Generate attestation
                                        cosign attest --predicate=sbom.spdx.json --key env://COSIGN_PRIVATE_KEY ${FULL_IMAGE_NAME}
                                    '''
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Integration Tests') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                container('docker') {
                    script {
                        // Run integration test suite
                        sh '''
                            # Start test environment
                            cat > docker-compose.integration.yml << EOF
                            version: '3.8'
                            services:
                              app:
                                image: ${FULL_IMAGE_NAME}
                                ports:
                                  - "3000:3000"
                                environment:
                                  NODE_ENV: test
                                  DATABASE_URL: postgres://test:test@db:5432/testdb
                                  REDIS_URL: redis://redis:6379
                                depends_on:
                                  - db
                                  - redis
                              db:
                                image: postgres:15-alpine
                                environment:
                                  POSTGRES_USER: test
                                  POSTGRES_PASSWORD: test
                                  POSTGRES_DB: testdb
                              redis:
                                image: redis:7-alpine
                            EOF
                            
                            # Start services
                            docker-compose -f docker-compose.integration.yml up -d
                            
                            # Wait for readiness
                            timeout 120 bash -c '
                                until curl -f http://localhost:3000/health; do
                                    echo "Waiting for application..."
                                    sleep 5
                                done
                            '
                            
                            # Run integration tests
                            docker-compose -f docker-compose.integration.yml exec -T app npm run test:integration
                        '''
                    }
                }
            }
            post {
                always {
                    container('docker') {
                        sh 'docker-compose -f docker-compose.integration.yml down -v --remove-orphans || true'
                    }
                    publishTestResults testResultsPattern: 'integration-test-results.xml'
                }
            }
        }

        stage('Push to Registry') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    buildingTag()
                }
            }
            steps {
                container('docker') {
                    script {
                        docker.withRegistry("https://${REGISTRY_URL}", "${REGISTRY_CREDENTIALS}") {
                            // Push multi-platform image
                            sh """
                                docker buildx build \
                                    --platform linux/amd64,linux/arm64 \
                                    --build-arg BUILDTIME=${env.BUILD_TIMESTAMP} \
                                    --build-arg VERSION=${env.IMAGE_TAG} \
                                    --build-arg REVISION=${env.GIT_COMMIT} \
                                    --cache-from type=registry,ref=${REGISTRY_URL}/${REGISTRY_PROJECT}/app:cache \
                                    --cache-to type=registry,ref=${REGISTRY_URL}/${REGISTRY_PROJECT}/app:cache,mode=max \
                                    --tag ${env.FULL_IMAGE_NAME} \
                                    --tag ${REGISTRY_URL}/${REGISTRY_PROJECT}/app:latest \
                                    --push \
                                    .
                            """
                            
                            echo "✅ Successfully pushed ${env.FULL_IMAGE_NAME}"
                        }
                    }
                }
            }
        }

        stage('Deploy') {
            when {
                anyOf {
                    allOf {
                        branch 'develop'
                        equals expected: 'staging', actual: params.DEPLOYMENT_ENVIRONMENT
                    }
                    allOf {
                        branch 'main'
                        equals expected: 'production', actual: params.DEPLOYMENT_ENVIRONMENT
                    }
                }
            }
            steps {
                script {
                    if (params.DEPLOYMENT_ENVIRONMENT == 'production' && !params.FORCE_DEPLOY) {
                        timeout(time: 10, unit: 'MINUTES') {
                            input message: "Deploy ${env.FULL_IMAGE_NAME} to production?",
                                  ok: 'Deploy',
                                  parameters: [
                                      choice(name: 'DEPLOYMENT_STRATEGY', 
                                             choices: ['rolling', 'blue-green', 'canary'], 
                                             description: 'Deployment strategy')
                                  ]
                        }
                    }
                    
                    container('kubectl') {
                        deploymentUtils.deployToK8s([
                            environment: params.DEPLOYMENT_ENVIRONMENT,
                            image: env.FULL_IMAGE_NAME,
                            strategy: params.DEPLOYMENT_STRATEGY ?: 'rolling',
                            namespace: params.DEPLOYMENT_ENVIRONMENT,
                            timeout: '600s'
                        ])
                    }
                    
                    container('kubectl') {
                        // Post-deployment verification
                        sh """
                            kubectl get pods -n ${params.DEPLOYMENT_ENVIRONMENT} -l app=myapp
                            kubectl get svc -n ${params.DEPLOYMENT_ENVIRONMENT} -l app=myapp
                            
                            # Health check
                            kubectl port-forward svc/myapp-service 8080:80 -n ${params.DEPLOYMENT_ENVIRONMENT} &
                            sleep 10
                            curl -f http://localhost:8080/health
                        """
                    }
                }
            }
            post {
                success {
                    script {
                        // Update deployment in external systems
                        updateDeploymentStatus([
                            environment: params.DEPLOYMENT_ENVIRONMENT,
                            image: env.FULL_IMAGE_NAME,
                            status: 'success',
                            build: env.BUILD_NUMBER
                        ])
                    }
                }
                failure {
                    script {
                        updateDeploymentStatus([
                            environment: params.DEPLOYMENT_ENVIRONMENT,
                            image: env.FULL_IMAGE_NAME,
                            status: 'failed',
                            build: env.BUILD_NUMBER
                        ])
                    }
                }
            }
        }
    }

    post {
        always {
            // Cleanup containers
            container('docker') {
                sh '''
                    docker system prune -f --volumes || true
                    docker buildx prune -f || true
                '''
            }
            
            // Archive build info
            writeFile file: 'build-info.json', text: """
            {
                "build_number": "${BUILD_NUMBER}",
                "git_commit": "${GIT_COMMIT}",
                "git_branch": "${BRANCH_NAME}",
                "image_tag": "${env.IMAGE_TAG}",
                "full_image_name": "${env.FULL_IMAGE_NAME}",
                "build_timestamp": "${env.BUILD_TIMESTAMP}",
                "deployment_environment": "${params.DEPLOYMENT_ENVIRONMENT}",
                "jenkins_url": "${BUILD_URL}"
            }
            """
            archiveArtifacts artifacts: 'build-info.json', fingerprint: true
        }
        
        success {
            script {
                notificationUtils.sendTeamsNotification([
                    webhook: env.TEAMS_WEBHOOK,
                    status: 'success',
                    title: "✅ Build Success - ${JOB_NAME} #${BUILD_NUMBER}",
                    message: """
                        **Branch:** ${BRANCH_NAME}
                        **Image:** ${env.FULL_IMAGE_NAME}
                        **Environment:** ${params.DEPLOYMENT_ENVIRONMENT}
                        **Duration:** ${currentBuild.durationString}
                    """,
                    color: '00FF00'
                ])
            }
        }
        
        failure {
            script {
                notificationUtils.sendTeamsNotification([
                    webhook: env.TEAMS_WEBHOOK,
                    status: 'failure',
                    title: "❌ Build Failed - ${JOB_NAME} #${BUILD_NUMBER}",
                    message: """
                        **Branch:** ${BRANCH_NAME}
                        **Stage:** ${env.STAGE_NAME}
                        **Duration:** ${currentBuild.durationString}
                        **Logs:** [View Build](${BUILD_URL})
                    """,
                    color: 'FF0000'
                ])
            }
        }
        
        unstable {
            script {
                notificationUtils.sendTeamsNotification([
                    webhook: env.TEAMS_WEBHOOK,
                    status: 'warning',
                    title: "⚠️ Build Unstable - ${JOB_NAME} #${BUILD_NUMBER}",
                    message: "Some tests failed but build continued",
                    color: 'FFA500'
                ])
            }
        }
    }
}

// Helper functions
def updateDeploymentStatus(config) {
    script {
        // Update Jira deployment
        if (env.JIRA_TOKEN) {
            sh """
                curl -X POST \
                    -H "Authorization: Bearer ${env.JIRA_TOKEN}" \
                    -H "Content-Type: application/json" \
                    -d '{
                        "deploymentSequenceNumber": ${config.build},
                        "displayName": "Build ${config.build}",
                        "description": "Deployed to ${config.environment}",
                        "state": "${config.status}",
                        "environment": {
                            "id": "${config.environment}",
                            "displayName": "${config.environment}",
                            "type": "${config.environment == 'production' ? 'production' : 'staging'}"
                        }
                    }' \
                    "\${JIRA_BASE_URL}/rest/deployments/0.1/bulk"
            """
        }
    }
}