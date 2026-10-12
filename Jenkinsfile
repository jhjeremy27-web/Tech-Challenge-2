
pipeline {
    agent any

    stages {
        stage('Verify Repository Checkout') {
            steps {
                echo 'Jenkins successfully loaded the Jenkinsfile from GitHub.'

                sh 'pwd'
                sh 'git rev-parse --short HEAD'
                sh 'ls -la'
            }
        }
    }
}
