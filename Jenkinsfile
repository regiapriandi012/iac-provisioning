pipeline {
    agent any
    
    parameters {
        choice(
            name: 'cluster_preset',
            choices: ['custom', 'small-single-master', 'medium-single-master', 'ha-3-masters'],
            description: 'Choose a preset or select custom to use vm_csv_content'
        )
        choice(
            name: 'vm_template',
            choices: ['t-debian12-86', 't-centos9-86'],
            description: 'VM template to use for all nodes'
        )
        string(
            name: 'proxmox_node',
            defaultValue: 'thinkcentre',
            description: 'Proxmox node where VMs will be created'
        )
        text(
            name: 'vm_csv_content',
            defaultValue: '''vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,4096,32G
0,kube-worker01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,4096,32G
0,kube-worker02,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,4096,32G''',
            description: 'VM specifications in CSV format (used when cluster_preset is "custom"). TEMPLATE_PLACEHOLDER and NODE_PLACEHOLDER will be replaced with selected values.'
        )
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
        booleanParam(
            name: 'use_cache',
            defaultValue: true,
            description: 'Use cached dependencies and templates'
        )
    }

    environment {
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
        INVENTORY_FILE = 'inventory/k8s-inventory.json'
        INVENTORY_SCRIPT = 'inventory.py'
        CACHE_DIR = '/var/jenkins_home/iac-cache'
    }
    
    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('🚀 Initialize') {
            parallel {
                stage('Checkout Code') {
                    steps {
                        git branch: 'main', 
                            credentialsId: 'gitlab-credential', 
                            url: 'https://gitlab.labngoprek.my.id/root/iac-provision'
                    }
                }
                
                stage('Setup Cache') {
                    when {
                        expression { params.use_cache }
                    }
                    steps {
                        script {
                            sh '''
                                # Create cache directories
                                mkdir -p ${CACHE_DIR}/{terraform,ansible,python}
                                
                                # Cache Terraform providers
                                if [ -d "${CACHE_DIR}/terraform/.terraform" ]; then
                                    echo "♻️  Using cached Terraform providers"
                                    cp -r ${CACHE_DIR}/terraform/.terraform ${TERRAFORM_DIR}/ || true
                                fi
                                
                                # Cache Python packages
                                if [ -d "${CACHE_DIR}/python/site-packages" ]; then
                                    echo "♻️  Using cached Python packages"
                                    export PYTHONPATH="${CACHE_DIR}/python/site-packages:$PYTHONPATH"
                                fi
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Generate VM Configuration') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        def startTime = System.currentTimeMillis()
                        
                        // Generate CSV based on preset or custom input
                        def csvContent = ""
                        
                        if (params.cluster_preset == 'custom') {
                            // Use custom CSV content
                            csvContent = params.vm_csv_content
                        } else {
                            // Use preset configurations with placeholders
                            def presetConfigs = [
                                'small-single-master': '''vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,4096,50G
0,kube-worker01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,4096,50G
0,kube-worker02,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,4096,50G''',
                                
                                'medium-single-master': '''vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,100G
0,kube-worker01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,100G
0,kube-worker02,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,100G
0,kube-worker03,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,100G''',
                                
                                'ha-3-masters': '''vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,50G
0,kube-master02,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,50G
0,kube-master03,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,50G
0,kube-worker01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,100G
0,kube-worker02,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,100G
0,kube-worker03,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,4,8192,100G'''
                            ]
                            
                            csvContent = presetConfigs[params.cluster_preset]
                        }
                        
                        // Replace placeholders with actual values
                        csvContent = csvContent.replaceAll('TEMPLATE_PLACEHOLDER', params.vm_template)
                        csvContent = csvContent.replaceAll('NODE_PLACEHOLDER', params.proxmox_node)
                        
                        // Write final CSV to file
                        writeFile file: "vms.csv", text: csvContent
                        
                        def duration = (System.currentTimeMillis() - startTime) / 1000
                        echo "✅ Configuration generated in ${duration}s"
                    }
                }
            }
        }
        
        stage('🔧 Terraform Provisioning') {
            stages {
                stage('Init') {
                    steps {
                        dir("${TERRAFORM_DIR}") {
                            withCredentials([
                                string(credentialsId: 'proxmox-api-url', variable: 'TF_VAR_pm_api_url'),
                                string(credentialsId: 'proxmox-api-token-id', variable: 'TF_VAR_pm_api_token_id'),
                                string(credentialsId: 'proxmox-api-token-secret', variable: 'TF_VAR_pm_api_token_secret')
                            ]) {
                                script {
                                    def startTime = System.currentTimeMillis()
                                    
                                    sh '''
                                        # Clean state for fresh deployment
                                        rm -f terraform.tfstate terraform.tfstate.backup
                                        
                                        terraform init -upgrade=false
                                    '''
                                    
                                    def duration = (System.currentTimeMillis() - startTime) / 1000
                                    echo "✅ Terraform init completed in ${duration}s"
                                    
                                    // Cache providers
                                    if (params.use_cache) {
                                        sh 'cp -r .terraform ${CACHE_DIR}/terraform/ || true'
                                    }
                                }
                            }
                        }
                    }
                }
                
                stage('Apply') {
                    steps {
                        dir("${TERRAFORM_DIR}") {
                            withCredentials([
                                string(credentialsId: 'proxmox-api-url', variable: 'TF_VAR_pm_api_url'),
                                string(credentialsId: 'proxmox-api-token-id', variable: 'TF_VAR_pm_api_token_id'),
                                string(credentialsId: 'proxmox-api-token-secret', variable: 'TF_VAR_pm_api_token_secret')
                            ]) {
                                script {
                                    def startTime = System.currentTimeMillis()
                                    
                                    sh '''
                                        echo "🚀 Applying Terraform with parallel execution..."
                                        terraform apply -auto-approve -parallelism=10
                                        
                                        echo "📋 Deployment summary:"
                                        terraform output assignment_summary
                                    '''
                                    
                                    def duration = (System.currentTimeMillis() - startTime) / 1000
                                    echo "✅ Infrastructure provisioned in ${duration}s"
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('⚡ Fast VM Readiness') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        def startTime = System.currentTimeMillis()
                        
                        sh '''
                            # Generate inventory
                            mkdir -p inventory
                            cd ../terraform
                            terraform output -raw ansible_inventory_json > ../ansible/${INVENTORY_FILE}
                            cd ../ansible
                            
                            # Use ultra-fast checker if available
                            if [ -f "scripts/ultra_fast_vm_ready.py" ]; then
                                echo "⚡ Using ultra-fast VM readiness checker..."
                                
                                # Quick initial delay
                                echo "Waiting 20s for VMs to initialize..."
                                sleep 20
                                
                                # Run ultra-fast parallel check
                                python3 scripts/ultra_fast_vm_ready.py ${INVENTORY_FILE} 20
                            else
                                # Fallback to standard checker
                                echo "Using standard VM readiness checker..."
                                python3 scripts/smart_vm_ready.py ${INVENTORY_FILE} 3
                            fi
                        '''
                        
                        def duration = (System.currentTimeMillis() - startTime) / 1000
                        echo "✅ VM readiness check completed in ${duration}s"
                    }
                }
            }
        }
        
        stage('🚀 Deploy Kubernetes') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        def startTime = System.currentTimeMillis()
                        
                        sh '''
                            echo "🚀 Starting optimized Kubernetes deployment..."
                            
                            # Use optimized setup script if available
                            if [ -f "run-k8s-setup-optimized.sh" ]; then
                                ./run-k8s-setup-optimized.sh
                            else
                                ./run-k8s-setup.sh
                            fi
                        '''
                        
                        def duration = (System.currentTimeMillis() - startTime) / 1000
                        def minutes = (duration / 60).intValue()
                        def seconds = (duration % 60).intValue()
                        
                        echo "✅ Kubernetes deployed in ${minutes}m ${seconds}s"
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
                            export ANSIBLE_INVENTORY_FILE=${INVENTORY_FILE}
                            ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "kubectl get nodes" --timeout=30
                            ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "kubectl get pods --all-namespaces" --timeout=30
                        else
                            echo "No master nodes found in inventory"
                            exit 1
                        fi
                    '''
                }
            }
        }
        
        stage('📤 Extract & Notify') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''
                            # Extract KUBECONFIG
                            mkdir -p kubeconfig
                            python3 scripts/get_kubeconfig.py ${INVENTORY_FILE} kubeconfig/admin.conf
                            
                            echo "✅ KUBECONFIG extracted successfully"
                        '''
                        
                        // Simplified Slack notification
                        withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK_URL')]) {
                            def buildDuration = currentBuild.durationString.replace(' and counting', '')
                            
                            sh """
                                # Send simple notification
                                curl -X POST ${SLACK_WEBHOOK_URL} \
                                     -H "Content-Type: application/json" \
                                     -d '{
                                       "text": "🚀 *Kubernetes Cluster Ready!*",
                                       "blocks": [
                                         {
                                           "type": "section",
                                           "text": {
                                             "type": "mrkdwn",
                                             "text": "*Build #${BUILD_NUMBER}* completed in *${buildDuration}*\\n<${BUILD_URL}|View Build>"
                                           }
                                         }
                                       ]
                                     }' || echo "Slack notification failed"
                            """
                        }
                    }
                }
            }
        }
        
        stage('Show Summary') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    withCredentials([
                        string(credentialsId: 'proxmox-api-url', variable: 'TF_VAR_pm_api_url'),
                        string(credentialsId: 'proxmox-api-token-id', variable: 'TF_VAR_pm_api_token_id'),
                        string(credentialsId: 'proxmox-api-token-secret', variable: 'TF_VAR_pm_api_token_secret')
                    ]) {
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
    }
    
    post {
        always {
            script {
                if (params.run_ansible) {
                    archiveArtifacts artifacts: "${ANSIBLE_DIR}/inventory/*", allowEmptyArchive: true
                    archiveArtifacts artifacts: "${ANSIBLE_DIR}/kubeconfig/*", allowEmptyArchive: true
                    archiveArtifacts artifacts: "${TERRAFORM_DIR}/vms.csv", allowEmptyArchive: true
                }
                
                // Show performance metrics
                def totalDuration = currentBuild.durationString.replace(' and counting', '')
                echo """
                ⏱️  Performance Summary
                =====================
                Total Build Time: ${totalDuration}
                
                Tips for faster provisioning:
                - Enable template caching in Proxmox
                - Use SSD storage for VMs
                - Increase Jenkins executors
                - Pre-pull container images
                """
            }
        }
        
        success {
            script {
                def successMessage = """
            ==================== SUCCESS ====================
            Infrastructure deployment completed successfully!
            
            Deployment Type: NEW VMs (Previous VMs remain untouched)
            
            What was deployed:
            - Brand NEW VMs provisioned with Terraform
            - Previous VMs still running (not destroyed)
            - Kubernetes cluster configured on new VMs
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
                # Cleanup but preserve cache
                rm -f ${TERRAFORM_DIR}/tfplan
                find ${ANSIBLE_DIR} -name "*.retry" -delete || true
            '''
        }
    }
}