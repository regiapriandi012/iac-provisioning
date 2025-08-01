pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: 'gitlab-credential', url: 'https://gitlab.labngoprek.my.id/root/iac-provision'
            }
        }
        stage('Terraform init') {
            steps {
                sh 'terraform init'
            }
        }
        stage('Terraform apply') {
            steps {
                sh 'terraform sh ${action} --auto-approve'
            }
        }
        
    }
}