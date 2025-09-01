// 10_ci_cd_integration/jenkins/shared-library/vars/dockerBuild.groovy

def call(Map config) {
    def imageName = config.imageName ?: env.JOB_NAME.toLowerCase()
    def tag = config.tag ?: env.BUILD_NUMBER
    def dockerfile = config.dockerfile ?: 'Dockerfile'
    def context = config.context ?: '.'
    def registry = config.registry ?: 'docker.io'
    def pushToRegistry = config.push ?: true
    
    pipeline {
        agent any
        
        stages {
            stage('Docker Build') {
                steps {
                    script {
                        def buildArgs = config.buildArgs ?: [:]
                        def buildArgsStr = buildArgs.collect { k, v -> "--build-arg ${k}=${v}" }.join(' ')
                        
                        sh """
                            docker buildx build \
                                --platform linux/amd64,linux/arm64 \
                                --tag ${registry}/${imageName}:${tag} \
                                --tag ${registry}/${imageName}:latest \
                                ${buildArgsStr} \
                                -f ${dockerfile} \
                                ${pushToRegistry ? '--push' : '--load'} \
                                ${context}
                        """
                    }
                }
            }
        }
    }
}

// 10_ci_cd_integration/jenkins/shared-library/vars/deployToK8s.groovy

def call(Map config) {
    def namespace = config.namespace ?: 'default'
    def manifestPath = config.manifestPath ?: 'k8s'
    def image = config.image
    def timeout = config.timeout ?: '300s'
    
    if (!image) {
        error "Image is required for Kubernetes deployment"
    }
    
    sh """
        # Update image in manifests
        sed -i 's|IMAGE_PLACEHOLDER|${image}|g' ${manifestPath}/*.yaml
        
        # Apply manifests
        kubectl apply -f ${manifestPath}/ -n ${namespace}
        
        # Wait for rollout
        kubectl rollout status deployment/\$(basename ${env.JOB_NAME}) -n ${namespace} --timeout=${timeout}
        
        # Verify deployment
        kubectl get pods -n ${namespace} -l app=\$(basename ${env.JOB_NAME})
    """
}

// 10_ci_cd_integration/jenkins/shared-library/vars/securityScan.groovy

def call(Map config) {
    def image = config.image
    def severity = config.severity ?: 'HIGH,CRITICAL'
    def format = config.format ?: 'json'
    def outputFile = config.outputFile ?: 'security-results.json'
    
    if (!image) {
        error "Image is required for security scanning"
    }
    
    sh """
        # Install Trivy
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        
        # Scan image
        trivy image --format ${format} --severity ${severity} --output ${outputFile} ${image}
        
        # Fail build on critical vulnerabilities
        trivy image --exit-code 1 --severity CRITICAL ${image}
    """
    
    archiveArtifacts artifacts: outputFile, fingerprint: true
}

// 10_ci_cd_integration/jenkins/shared-library/vars/notifySlack.groovy

def call(Map config) {
    def channel = config.channel ?: '#deployments'
    def message = config.message
    def color = config.color ?: 'good'
    def webhook = config.webhook ?: env.SLACK_WEBHOOK_URL
    
    if (!message || !webhook) {
        echo "Missing required parameters for Slack notification"
        return
    }
    
    sh """
        curl -X POST -H 'Content-type: application/json' \
            --data '{
                "channel": "${channel}",
                "text": "${message}",
                "color": "${color}",
                "username": "Jenkins",
                "icon_emoji": ":jenkins:"
            }' \
            ${webhook}
    """
}

// 10_ci_cd_integration/jenkins/shared-library/vars/runTests.groovy

def call(Map config) {
    def testCommand = config.command ?: 'npm test'
    def coverage = config.coverage ?: true
    def publishResults = config.publishResults ?: true
    def coverageThreshold = config.coverageThreshold ?: 80
    
    sh """
        ${testCommand}
        
        # Check coverage threshold
        if [ ${coverage} == true ]; then
            COVERAGE=\$(grep -o '"pct":[0-9.]*' coverage/coverage-summary.json | head -1 | cut -d: -f2)
            if (( \$(echo "\$COVERAGE < ${coverageThreshold}" | bc -l) )); then
                echo "Coverage \$COVERAGE% is below threshold ${coverageThreshold}%"
                exit 1
            fi
        fi
    """
    
    if (publishResults) {
        publishHTML([
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'coverage',
            reportFiles: 'index.html',
            reportName: 'Coverage Report'
        ])
        
        publishTestResults testResultsPattern: 'test-results.xml'
    }
}

// 10_ci_cd_integration/jenkins/shared-library/src/com/company/Utils.groovy

package com.company

class Utils implements Serializable {
    def script
    
    Utils(script) {
        this.script = script
    }
    
    def getGitCommitHash() {
        return script.sh(
            script: "git rev-parse --short HEAD",
            returnStdout: true
        ).trim()
    }
    
    def getGitBranch() {
        return script.sh(
            script: "git rev-parse --abbrev-ref HEAD",
            returnStdout: true
        ).trim()
    }
    
    def generateImageTag() {
        def branch = getGitBranch()
        def commit = getGitCommitHash()
        def timestamp = new Date().format('yyyyMMddHHmmss')
        
        if (branch == 'main') {
            return "latest-${commit}-${timestamp}"
        } else {
            return "${branch}-${commit}-${timestamp}"
        }
    }
    
    def validateDockerfile(String dockerfile = 'Dockerfile') {
        script.sh """
            docker run --rm -i hadolint/hadolint < ${dockerfile}
        """
    }
    
    def generateSBOM(String image, String format = 'spdx-json') {
        script.sh """
            syft ${image} -o ${format} --file sbom.${format.split('-')[1]}
        """
        script.archiveArtifacts artifacts: "sbom.${format.split('-')[1]}", fingerprint: true
    }
}

// 10_ci_cd_integration/jenkins/shared-library/vars/pipelineUtils.groovy

@Library('jenkins-shared-library') _

def call() {
    return new com.company.Utils(this)
}