
pipeline {
    agent any

    stages {
        stage('Verify Repository Checkout') {
            steps {
                echo 'Jenkins successfully checked out the repository.'
                sh 'git rev-parse --short HEAD'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Tech Challenge 2 Docker image...'
                sh 'docker build -t tech-challenge-2-app:jenkins-test .'
            }
        }
    }
}
