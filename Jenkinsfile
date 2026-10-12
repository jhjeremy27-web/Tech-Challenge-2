
pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '234617061592'

        ECR_REPOSITORY = 'tech-challenge-2-app'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_REPOSITORY = "${ECR_REGISTRY}/${ECR_REPOSITORY}"

        EKS_CLUSTER = 'tech-challenge-2-cluster'

        HELM_RELEASE = 'hello-world'
        HELM_CHART = './helm/tech-challenge-2'
        K8S_NAMESPACE = 'default'
        K8S_DEPLOYMENT = 'hello-world-tech-challenge-2'
    }

    stages {

        stage('Verify Repository Checkout') {
            steps {
                echo 'Verifying GitHub repository checkout...'

                sh '''
                    pwd
                    git rev-parse --short HEAD
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'

                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }

                sh '''
                    docker build \
                        -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
                        .
                '''
            }
        }

        stage('Authenticate with Amazon ECR') {
            steps {
                echo 'Authenticating with Amazon ECR...'

                sh '''
                    aws ecr get-login-password \
                        --region "${AWS_REGION}" | \
                    docker login \
                        --username AWS \
                        --password-stdin \
                        "${ECR_REGISTRY}"
                '''
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                echo 'Pushing Docker image to Amazon ECR...'

                sh '''
                    docker push "${IMAGE_REPOSITORY}:${IMAGE_TAG}"
                '''
            }
        }

        stage('Configure EKS Access') {
            steps {
                echo 'Configuring access to Amazon EKS...'

                sh '''
                    aws eks update-kubeconfig \
                        --region "${AWS_REGION}" \
                        --name "${EKS_CLUSTER}"

                    kubectl get deployment \
                        "${K8S_DEPLOYMENT}" \
                        -n "${K8S_NAMESPACE}"
                '''
            }
        }

        stage('Deploy to EKS with Helm') {
            steps {
                echo 'Deploying application using Helm...'

                sh '''
                    helm upgrade --install \
                        "${HELM_RELEASE}" \
                        "${HELM_CHART}" \
                        --namespace "${K8S_NAMESPACE}" \
                        --set image.repository="${IMAGE_REPOSITORY}" \
                        --set image.tag="${IMAGE_TAG}" \
                        --wait \
                        --timeout 10m
                '''
            }
        }

        stage('Verify Kubernetes Rollout') {
            steps {
                echo 'Verifying Kubernetes deployment...'

                sh '''
                    kubectl rollout status \
                        deployment/"${K8S_DEPLOYMENT}" \
                        -n "${K8S_NAMESPACE}" \
                        --timeout=300s

                    kubectl get pods \
                        -n "${K8S_NAMESPACE}" \
                        -l app.kubernetes.io/instance="${HELM_RELEASE}"
                '''
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Application built, pushed to ECR, and deployed to EKS.'
        }

        failure {
            echo 'FAILED: Review the Jenkins console output to identify the failing stage.'
        }

        always {
            echo 'Jenkins pipeline execution completed.'
        }
    }
}
