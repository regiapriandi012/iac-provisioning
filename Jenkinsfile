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
        choice(
            name: 'ansible_playbook',
            choices: ['nginx-install.yml', 'kubernetes-prep.yml', 'common-setup.yml'],
            description: 'Ansible playbook to run'
        )
    }

    environment {
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: 'gitlab-credential', url: 'https://gitlab.labngoprek.my.id/root/iac-provision'
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    sh 'terraform init'
                }
            }
        }
        
        stage('Terraform Apply/Destroy') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        if (params.action == 'apply') {
                            sh 'terraform apply --auto-approve'
                        } else {
                            sh 'terraform destroy --auto-approve'
                        }
                    }
                }
            }
        }
        
        stage('Generate Ansible Inventory') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                }
            }
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        sh '''
                            echo "📝 Generating Ansible inventory..."
                            
                            # Create inventory directory
                            mkdir -p ../${ANSIBLE_DIR}/inventory
                            
                            # Generate INI format inventory
                            terraform output -raw ansible_inventory_ini > ../${ANSIBLE_DIR}/inventory/hosts.ini
                            
                            # Generate JSON format inventory (backup)
                            terraform output -json ansible_inventory_json > ../${ANSIBLE_DIR}/inventory/hosts.json
                            
                            echo "📋 Generated inventory files:"
                            ls -la ../${ANSIBLE_DIR}/inventory/
                            
                            echo "🔍 Inventory content preview:"
                            head -20 ../${ANSIBLE_DIR}/inventory/hosts.ini
                        '''
                    }
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
                        cd ${ANSIBLE_DIR}
                        
                        # Get IP addresses from inventory
                        grep "ansible_host=" inventory/hosts.ini | awk -F'ansible_host=' '{print $2}' | awk '{print $1}' | while read ip; do
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
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''
                            echo "🔍 Testing Ansible connectivity..."
                            
                            # Retry mechanism for ansible ping
                            for i in {1..3}; do
                                echo "Attempt $i/3: Testing ansible connectivity..."
                                if ansible all -i inventory/hosts.ini -m ping --timeout=15; then
                                    echo "✅ All hosts are reachable!"
                                    break
                                else
                                    echo "⚠️  Some hosts not ready, waiting 30s before retry..."
                                    sleep 30
                                fi
                                
                                if [ $i -eq 3 ]; then
                                    echo "❌ Failed to connect to all hosts after 3 attempts"
                                    echo "🔍 Checking individual hosts:"
                                    ansible all -i inventory/hosts.ini -m ping --timeout=10 -v || true
                                    exit 1
                                fi
                            done
                        '''
                    }
                }
            }
        }
        
        stage('Deploy with Ansible') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''
                            echo "🚀 Starting deployment with Ansible..."
                            echo "📋 Using playbook: ${ansible_playbook}"
                            
                            # Run selected ansible playbook
                            ansible-playbook -i inventory/hosts.ini playbooks/${ansible_playbook} -v
                            
                            if [ $? -eq 0 ]; then
                                echo ""
                                echo "🎉 Ansible deployment completed successfully!"
                                echo ""
                                echo "🌐 Access your services:"
                                
                                # Extract IPs and show access URLs
                                grep "ansible_host=" inventory/hosts.ini | while read line; do
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
        }
        
        stage('Verify Deployment') {
            when {
                allOf {
                    expression { params.action == 'apply' }
                    expression { params.run_ansible == true }
                    expression { params.ansible_playbook == 'nginx-install.yml' }
                }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''
                            echo "🔍 Verifying nginx deployment..."
                            
                            # Check nginx status on all hosts
                            ansible all -i inventory/hosts.ini -m shell -a "systemctl is-active nginx" --timeout=10
                            
                            echo ""
                            echo "🌐 Testing HTTP responses:"
                            
                            # Test HTTP responses
                            grep "ansible_host=" inventory/hosts.ini | while read line; do
                                hostname=$(echo $line | awk '{print $1}')
                                ip=$(echo $line | awk -F'ansible_host=' '{print $2}' | awk '{print $1}')
                                
                                echo "Testing $hostname ($ip)..."
                                if curl -s -o /dev/null -w "%{http_code}" "http://$ip" | grep -q "200"; then
                                    echo "  ✅ $hostname: HTTP 200 OK"
                                else
                                    echo "  ❌ $hostname: HTTP request failed"
                                fi
                            done
                        '''
                    }
                }
            }
        }
        
        stage('Show Summary') {
            when {
                expression { params.action == 'apply' }
            }
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        sh '''
                            echo ""
                            echo "📊 Deployment Summary:"
                            terraform output assignment_summary
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                if (params.action == 'apply' && params.run_ansible == true) {
                    // Archive generated files
                    archiveArtifacts artifacts: "${ANSIBLE_DIR}/inventory/hosts.ini,${ANSIBLE_DIR}/inventory/hosts.json", allowEmptyArchive: true
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
                    - Services configured with Ansible (${params.ansible_playbook})
                    - Inventory files generated automatically
                    
                    🌐 Next steps:
                    - Access the services using the URLs shown above
                    - Check the inventory files for host details
                    - Run additional playbooks as needed
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
        
        cleanup {
            script {
                // Clean up temporary files
                sh '''
                    rm -f ${ANSIBLE_DIR}/inventory/hosts.ini
                    rm -f ${ANSIBLE_DIR}/inventory/hosts.json
                '''
            }
        }
    }
}