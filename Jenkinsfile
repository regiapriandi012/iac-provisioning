pipeline {
    agent any
    
    parameters {
        booleanParam(
            name: 'run_ansible',
            defaultValue: true,
            description: 'Run Ansible after Terraform apply'
        )
        booleanParam(
            name: 'skip_verification',
            defaultValue: false,
            description: 'Skip Kubernetes cluster verification steps'
        )
    }

    environment {
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
        INVENTORY_FILE = 'inventory/k8s-inventory.json'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                    credentialsId: 'gitlab-credential', 
                    url: 'https://gitlab.labngoprek.my.id/root/iac-provision'
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        echo "Cleaning up old Terraform state..."
                        rm -f .terraform.lock.hcl
                        rm -rf .terraform/
                        
                        echo "Initializing Terraform with fresh state..."
                        terraform init
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        echo "Planning Terraform deployment..."
                        terraform plan -out=tfplan
                    '''
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        echo "Applying Terraform plan..."
                        terraform apply tfplan
                        
                        echo "Infrastructure deployed successfully!"
                        terraform state list
                        
                        echo ""
                        echo "Updated CSV with sequential IP assignments:"
                        cat vms.csv
                    '''
                }
            }
        }
        
        stage('Prepare Ansible') {
            when {
                expression { params.run_ansible }
            }
            parallel {
                stage('Generate Dynamic Inventory') {
                    steps {
                        dir("${ANSIBLE_DIR}") {
                            sh '''
                                echo "Generating dynamic inventory from CSV..."
                                
                                # Ensure inventory directory exists
                                mkdir -p inventory
                                
                                # Generate inventory from terraform output (dynamic)
                                cd ../terraform
                                terraform output ansible_inventory_json > ../ansible/${INVENTORY_FILE}
                                cd ../ansible
                                
                                echo "Verifying generated inventory JSON:"
                                python3 -m json.tool ${INVENTORY_FILE}
                                
                                echo "Generated inventory:"
                                python3 -m json.tool ${INVENTORY_FILE}
                                
                                echo "Cluster configuration detected:"
                                python3 scripts/show_cluster_config.py ${INVENTORY_FILE}
                                
                                echo ""
                                echo "OS Distribution Analysis:"
                                python3 scripts/detect_os_type.py ${INVENTORY_FILE}
                            '''
                        }
                    }
                }
                stage('Smart VM Readiness Check') {
                    steps {
                        sh '''
                            echo "Smart VM Readiness Check (replaces slow netcat checking)"
                            echo "This should complete in ~15-30 seconds instead of 2+ minutes"
                            
                            cd ${ANSIBLE_DIR}
                            
                            # Give VMs a moment to finish booting
                            echo "Wait for VM initialization (60s)..."
                            sleep 60
                            
                            # Use our smart readiness checker
                            echo "Running smart parallel readiness check..."
                            python3 scripts/smart_vm_ready.py ${INVENTORY_FILE} 3
                            
                            if [ $? -eq 0 ]; then
                                echo "All VMs ready! Proceeding to connectivity test..."
                            else
                                echo "VM readiness check failed. Check logs above."
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Final Connectivity Verification') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''
                            echo "Final connectivity verification and cluster analysis..."
                            
                            # Quick comprehensive check (replaces multiple slow steps)
                            echo "Running comprehensive cluster check..."
                            python3 scripts/quick_cluster_check.py ${INVENTORY_FILE}
                            
                            if [ $? -eq 0 ]; then
                                echo "All connectivity checks passed!"
                                echo "Ready for Kubernetes deployment..."
                            else
                                echo "Connectivity issues detected. Falling back to debug mode..."
                                
                                # Only run detailed debug if quick check fails
                                echo "Debug: Inventory validation"
                                python3 -m json.tool ${INVENTORY_FILE} || echo "JSON validation failed!"
                                
                                echo "Debug: Manual ansible ping test"
                                ansible all -i ${INVENTORY_FILE} -m ping --timeout=20 -v || true
                                
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Deploy Kubernetes Cluster') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''
                            echo "Starting Kubernetes cluster deployment..."
                            
                            echo "Deploying Kubernetes cluster..."
                            ./run-k8s-setup.sh
                            
                            if [ $? -eq 0 ]; then
                                echo "Kubernetes deployment completed successfully!"
                                
                                echo "Cluster endpoints:"
                                python3 scripts/show_endpoints.py ${INVENTORY_FILE}
                            else
                                echo "Kubernetes deployment failed!"
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Verify Kubernetes Cluster') {
            when {
                allOf {
                    expression { params.run_ansible }
                    expression { !params.skip_verification }
                }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        echo "Verifying Kubernetes deployment..."
                        
                        # Get first master node
                        FIRST_MASTER=$(python3 scripts/get_first_master.py ${INVENTORY_FILE})
                        
                        if [ -n "$FIRST_MASTER" ]; then
                            echo "Testing kubectl on $FIRST_MASTER..."
                            ansible $FIRST_MASTER -i ${INVENTORY_FILE} -m shell -a "kubectl get nodes" --timeout=30
                            ansible $FIRST_MASTER -i ${INVENTORY_FILE} -m shell -a "kubectl get pods --all-namespaces" --timeout=30
                        else
                            echo "No master nodes found in inventory"
                            exit 1
                        fi
                    '''
                }
            }
        }
        
        stage('Extract KUBECONFIG') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''
                            echo "Extracting KUBECONFIG from master node..."
                            
                            # Create kubeconfig directory for archiving
                            mkdir -p kubeconfig
                            
                            # Get KUBECONFIG and save to file
                            python3 scripts/get_kubeconfig.py ${INVENTORY_FILE} kubeconfig/admin.conf
                            
                            if [ $? -eq 0 ]; then
                                echo ""
                                echo "==================== KUBECONFIG ===================="
                                echo "KUBECONFIG has been extracted and saved to kubeconfig/admin.conf"
                                echo ""
                                echo "Quick setup commands:"
                                echo "  mkdir -p ~/.kube"
                                echo "  # Copy the content from the archived kubeconfig/admin.conf"
                                echo "  kubectl get nodes"
                                echo ""
                                echo "Content preview:"
                                head -20 kubeconfig/admin.conf
                                echo "... (full content available in archived artifacts)"
                                echo "====================================================="
                            else
                                echo "Failed to extract KUBECONFIG"
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Show Summary') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        echo "==================== DEPLOYMENT SUMMARY ===================="
                        terraform output assignment_summary
                        
                        echo ""
                        echo "==================== INFRASTRUCTURE DETAILS ===================="
                        terraform output vm_assignments
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                if (params.run_ansible) {
                    archiveArtifacts artifacts: "${ANSIBLE_DIR}/inventory/*", allowEmptyArchive: true
                    archiveArtifacts artifacts: "${TERRAFORM_DIR}/vms.csv", allowEmptyArchive: true
                    
                    archiveArtifacts artifacts: "${ANSIBLE_DIR}/kubeconfig/*", allowEmptyArchive: true
                }
            }
        }
        
        success {
            script {
                def successMessage = """
            ==================== SUCCESS ====================
            Infrastructure deployment completed successfully!
            
            What was deployed:
            - VMs provisioned with Terraform
            - Kubernetes cluster configured with Ansible
            - Dynamic inventory generated automatically"""
            
                successMessage += """
            - KUBECONFIG extracted and archived
            
            Kubernetes Access:
            - Download 'kubeconfig/admin.conf' from Jenkins artifacts
            - Run: mkdir -p ~/.kube && cp admin.conf ~/.kube/config
            - Test: kubectl get nodes"""
                
                successMessage += """
            
            Next steps:
            - Access services using endpoints shown above
            - Check archived files for configuration details
            - Scale or modify as needed
            
            Cleanup (if needed):
            - cd terraform && terraform destroy --auto-approve
            ==================================================
            """
            
                echo successMessage
            }
        }
        
        failure {
            echo """
            ==================== FAILURE ====================
            Pipeline execution failed!
            
            Common troubleshooting steps:
            1. Check Terraform state and resources
            2. Verify VM connectivity and SSH access
            3. Validate Ansible inventory and playbooks
            4. Check network connectivity to target VMs
            5. Review stage logs for specific errors
            ==================================================
            """
        }
        
        cleanup {
            sh '''
                echo "Cleaning up temporary files..."
                rm -f ${TERRAFORM_DIR}/tfplan
                # Note: keeping inventory for artifact archiving
            '''
        }
    }
}