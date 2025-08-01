pipeline {
    agent any
    
    parameters {
        choice(
            name: 'action',
            choices: ['apply', 'destroy'],
            description: 'Terraform action to perform'
        )
        booleanParam(
            name: 'run_ansible',
            defaultValue: true,
            description: 'Run Ansible after Terraform apply'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: 'gitlab-credential', url: 'https://gitlab.labngoprek.my.id/root/iac-provision'
            }
        }
        
        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }
        
        stage('Terraform Apply/Destroy') {
            steps {
                script {
                    if (params.action == 'apply') {
                        sh 'terraform apply --auto-approve'
                    } else {
                        sh 'terraform destroy --auto-approve'
                    }
                }
            }
        }
        
        stage('Generate Ansible Files') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                }
            }
            steps {
                script {
                    // Generate inventory file dari terraform output
                    sh '''
                        echo "📝 Generating Ansible inventory..."
                        terraform output -raw ansible_inventory > inventory.ini
                        
                        echo "📝 Generating Ansible playbook..."
                        terraform output -raw ansible_playbook > nginx-playbook.yml
                        
                        echo "📋 Generated files:"
                        ls -la inventory.ini nginx-playbook.yml
                        
                        echo "🔍 Inventory content preview:"
                        head -20 inventory.ini
                    '''
                }
            }
        }
        
        stage('Wait for VMs Ready') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                }
            }
            steps {
                script {
                    sh '''
                        echo "⏳ Waiting for VMs to be ready..."
                        sleep 45
                        
                        echo "🔍 Testing VM connectivity..."
                        # Get IP addresses dari inventory untuk test ping
                        grep "ansible_host=" inventory.ini | awk -F'ansible_host=' '{print $2}' | awk '{print $1}' | while read ip; do
                            echo "Testing connectivity to $ip..."
                            timeout 10 ping -c 2 $ip || echo "Warning: $ip not responding to ping yet"
                        done
                    '''
                }
            }
        }
        
        stage('Ansible Connectivity Test') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                }
            }
            steps {
                script {
                    sh '''
                        echo "🔍 Testing Ansible connectivity..."
                        
                        # Retry mechanism for ansible ping
                        for i in {1..3}; do
                            echo "Attempt $i/3: Testing ansible connectivity..."
                            if ansible all -i inventory.ini -m ping --timeout=15; then
                                echo "✅ All hosts are reachable!"
                                break
                            else
                                echo "⚠️  Some hosts not ready, waiting 30s before retry..."
                                sleep 30
                            fi
                            
                            if [ $i -eq 3 ]; then
                                echo "❌ Failed to connect to all hosts after 3 attempts"
                                echo "🔍 Checking individual hosts:"
                                ansible all -i inventory.ini -m ping --timeout=10 -v || true
                                exit 1
                            fi
                        done
                    '''
                }
            }
        }
        
        stage('Deploy Nginx with Ansible') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                }
            }
            steps {
                script {
                    sh '''
                        echo "🚀 Starting nginx deployment with Ansible..."
                        
                        # Run ansible playbook with retry
                        ansible-playbook -i inventory.ini nginx-playbook.yml -v
                        
                        if [ $? -eq 0 ]; then
                            echo ""
                            echo "🎉 Nginx deployment completed successfully!"
                            echo ""
                            echo "🌐 Access your nginx servers:"
                            
                            # Extract IPs and show access URLs
                            grep "ansible_host=" inventory.ini | while read line; do
                                hostname=$(echo $line | awk '{print $1}')
                                ip=$(echo $line | awk -F'ansible_host=' '{print $2}' | awk '{print $1}')
                                echo "  - $hostname: http://$ip"
                            done
                            
                            echo ""
                            echo "✅ All services are up and running!"
                        else
                            echo "❌ Ansible deployment failed!"
                            exit 1
                        fi
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                }
            }
            steps {
                script {
                    sh '''
                        echo "🔍 Verifying nginx deployment..."
                        
                        # Check nginx status on all hosts
                        ansible all -i inventory.ini -m shell -a "systemctl is-active nginx" --timeout=10
                        
                        echo ""
                        echo "🌐 Testing HTTP responses:"
                        
                        # Test HTTP responses
                        grep "ansible_host=" inventory.ini | while read line; do
                            hostname=$(echo $line | awk '{print $1}')
                            ip=$(echo $line | awk -F'ansible_host=' '{print $2}' | awk '{print $1}')
                            
                            echo "Testing $hostname ($ip)..."
                            if curl -s -o /dev/null -w "%{http_code}" "http://$ip" | grep -q "200"; then
                                echo "  ✅ $hostname: HTTP 200 OK"
                            else
                                echo "  ❌ $hostname: HTTP request failed"
                            fi
                        done
                        
                        echo ""
                        echo "📊 Deployment Summary:"
                        terraform output assignment_summary
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                if (params.action == 'apply' && params.run_ansible == true) {
                    // Archive generated files
                    archiveArtifacts artifacts: 'inventory.ini,nginx-playbook.yml', allowEmptyArchive: true
                    
                    // Clean up generated files
                    sh 'rm -f inventory.ini nginx-playbook.yml'
                }
            }
        }
        
        success {
            script {
                if (params.action == 'apply') {
                    echo """
                    🎉 Infrastructure deployment completed successfully!
                    
                    📋 What was deployed:
                    - VMs provisioned with Terraform
                    - Nginx installed and configured with Ansible
                    - Custom web pages with server information
                    
                    🌐 Next steps:
                    - Access the web servers using the URLs shown above
                    - Check the custom pages for server details
                    - Use the VMs for your Kubernetes cluster setup
                    """
                } else {
                    echo "🗑️  Infrastructure destroyed successfully!"
                }
            }
        }
        
        failure {
            script {
                echo """
                ❌ Pipeline failed!
                
                🔍 Check the following:
                - Terraform state and resources
                - VM connectivity and SSH access
                - Ansible inventory and playbook syntax
                - Network connectivity to target VMs
                """
            }
        }
    }
}