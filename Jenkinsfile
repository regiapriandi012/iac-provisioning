pipeline {
    agent any
    
    parameters {
        // ===== Ansible Configuration =====
        booleanParam(
            name: 'run_ansible',
            defaultValue: true,
            description: 'Deploy Kubernetes cluster using Ansible after VM provisioning'
        )
        
        // ===== Provision Kubernetes =====
        text(
            name: 'vm_csv_content',
            defaultValue: '''vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,t-debian12-86,thinkcentre,0,2,2048,32G
0,kube-worker01,t-debian12-86,thinkcentre,0,2,2048,32G
0,kube-worker02,t-debian12-86,thinkcentre,0,2,2048,32G''',
            description: 'VM specifications (CSV format) - define template and node per VM'
        )
        
        // ===== Advanced Options =====
        booleanParam(
            name: 'use_cache',
            defaultValue: true,
            description: 'Enable caching for faster subsequent runs'
        )
        
        string(
            name: 'git_repository_url',
            defaultValue: 'https://gitlab.labngoprek.my.id/root/iac-provision',
            description: 'Git repository URL (leave default for original repo)'
        )
    }

    environment {
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
        INVENTORY_FILE = 'inventory/k8s-inventory.json'
        INVENTORY_SCRIPT = '../scripts/inventory.py'
        CACHE_DIR = "${WORKSPACE}/.iac-cache"
    }
    
    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                    credentialsId: 'gitlab-credential', 
                    url: params.git_repository_url ?: 'https://gitlab.labngoprek.my.id/root/iac-provision'
            }
        }
        
        stage('Setup Environment') {
            steps {
                script {
                    // Set use_cache as environment variable for shell script
                    env.USE_CACHE = params.use_cache.toString()
                    
                    sh './scripts/setup_environment.sh'
                    
                    // Set environment variables for subsequent stages
                    env.PATH = "${WORKSPACE}/venv/bin:${env.PATH}"
                    env.VIRTUAL_ENV = "${WORKSPACE}/venv"
                }
            }
        }
        
        stage('Generate VM Configuration') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        def startTime = System.currentTimeMillis()
                        
                        // Use CSV content directly
                        def csvContent = params.vm_csv_content
                        
                        // Write final CSV to file
                        writeFile file: "vms.csv", text: csvContent
                        
                        def duration = ((System.currentTimeMillis() - startTime) / 1000).intValue()
                        echo "Configuration generated in ${duration}s"
                    }
                }
            }
        }
        
        stage('Terraform Provisioning') {
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
                                    
                                    def duration = ((System.currentTimeMillis() - startTime) / 1000).intValue()
                                    echo "Terraform init completed in ${duration}s"
                                    
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
                                    
                                    sh '../scripts/terraform_apply.sh'
                                    
                                    def duration = ((System.currentTimeMillis() - startTime) / 1000).intValue()
                                    echo "Infrastructure provisioned in ${duration}s"
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('VM Readiness') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        def startTime = System.currentTimeMillis()
                        
                        sh '../scripts/check_vm_readiness.sh'
                        
                        def duration = ((System.currentTimeMillis() - startTime) / 1000).intValue()
                        echo "VM readiness check completed in ${duration}s"
                    }
                }
            }
        }
        
        stage('Deploy Kubernetes') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        def startTime = System.currentTimeMillis()
                        
                        sh '../scripts/deploy_kubernetes.sh'
                        
                        def duration = ((System.currentTimeMillis() - startTime) / 1000).intValue()
                        def minutes = duration / 60
                        def seconds = duration % 60
                        
                        echo "Kubernetes deployed in ${minutes}m ${seconds}s"
                    }
                }
            }
        }
        
        stage('Verify Kubernetes Cluster') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    sh '''
                        echo "Verifying Kubernetes deployment..."
                        
                        # Get first master node
                        FIRST_MASTER=$(python3 ${WORKSPACE}/scripts/get_first_master.py ${INVENTORY_FILE})
                        
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
        
        stage('Extract & Notify') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '../scripts/extract_kubeconfig.sh'
                        
                        // Send KUBECONFIG to Slack
                        withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK_URL')]) {
                            def buildDuration = currentBuild.durationString.replace(' and counting', '')
                            def kubeconfigContent = readFile("kubeconfig/admin.conf")
                            
                            // Get cluster info
                            def masterCount = sh(
                                script: "python3 ${WORKSPACE}/scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details | grep k8s_masters | wc -l",
                                returnStdout: true
                            ).trim()
                            
                            def workerCount = sh(
                                script: "python3 ${WORKSPACE}/scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details | grep k8s_workers | wc -l",
                                returnStdout: true
                            ).trim()
                            
                            def clusterEndpoint = sh(
                                script: "grep 'server:' kubeconfig/admin.conf | awk '{print \$2}' | head -1",
                                returnStdout: true
                            ).trim()
                            
                            // Debug output
                            echo "Master Count: ${masterCount}"
                            echo "Worker Count: ${workerCount}"
                            echo "Cluster Endpoint: ${clusterEndpoint}"
                            echo "KUBECONFIG length: ${kubeconfigContent.length()}"
                            
                            // Set environment variables for the notification script
                            env.BUILD_DURATION = buildDuration
                            env.CLUSTER_ENDPOINT = clusterEndpoint
                            env.MASTER_COUNT = masterCount
                            env.WORKER_COUNT = workerCount
                            
                            sh '../scripts/notify_slack.sh'
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
                Performance Summary
                =====================
                Total Build Time: ${totalDuration}
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