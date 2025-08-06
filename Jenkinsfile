pipeline {
    agent any

    environment {
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
        INVENTORY_FILE = 'inventory/k8s-inventory.json'
        INVENTORY_SCRIPT = '../scripts/inventory.py'
        CACHE_DIR = "${WORKSPACE}/.iac-cache"
        CONFIG_FILE = 'config/environment.conf'
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
                script {
                    // Load configuration values using simple file reading
                    def configContent = readFile(CONFIG_FILE)
                    def configProps = [:]
                    
                    configContent.split('\n').each { line ->
                        line = line.trim()
                        if (line && !line.startsWith('#') && line.contains('=')) {
                            def parts = line.split('=', 2)
                            configProps[parts[0].trim()] = parts[1].trim()
                        }
                    }
                    
                    def gitUrl = configProps.GIT_REPOSITORY_URL ?: 'https://gitlab.labngoprek.my.id/root/iac-provision'
                    def gitBranch = configProps.GIT_BRANCH ?: 'main'
                    def gitCredentials = configProps.GIT_CREDENTIALS_ID ?: 'gitlab-credential'
                    
                    git branch: gitBranch,
                        credentialsId: gitCredentials,
                        url: gitUrl
                }
            }
        }
        
        stage('Setup Environment') {
            steps {
                script {
                    // Load configuration using simple file reading
                    def configContent = readFile(CONFIG_FILE)
                    def configProps = [:]
                    
                    configContent.split('\n').each { line ->
                        line = line.trim()
                        if (line && !line.startsWith('#') && line.contains('=')) {
                            def parts = line.split('=', 2)
                            configProps[parts[0].trim()] = parts[1].trim()
                        }
                    }
                    
                    // Set environment variables from config (with override support)
                    env.USE_CACHE = configProps.OVERRIDE_USE_CACHE ?: (configProps.USE_CACHE ?: 'true')
                    env.RUN_ANSIBLE = configProps.OVERRIDE_RUN_ANSIBLE ?: (configProps.RUN_ANSIBLE ?: 'true')
                    env.CNI_TYPE = configProps.OVERRIDE_CNI_TYPE ?: (configProps.DEFAULT_CNI_TYPE ?: 'cilium')
                    env.CNI_VERSION = configProps.OVERRIDE_CNI_VERSION ?: (configProps.DEFAULT_CNI_VERSION ?: '1.14.5')
                    
                    env.PROXMOX_CREDENTIALS_PREFIX = configProps.PROXMOX_CREDENTIALS_PREFIX ?: 'proxmox'
                    env.SLACK_WEBHOOK_CREDENTIAL_ID = configProps.SLACK_WEBHOOK_CREDENTIAL_ID ?: 'slack-webhook-url'
                    
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
                        
                        // Load configuration using simple file reading
                        def configContent = readFile("../${CONFIG_FILE}")
                        def configProps = [:]
                        
                        configContent.split('\n').each { line ->
                            line = line.trim()
                            if (line && !line.startsWith('#') && line.contains('=')) {
                                def parts = line.split('=', 2)
                                configProps[parts[0].trim()] = parts[1].trim()
                            }
                        }
                        
                        // Copy vms.csv from repository root to terraform directory
                        sh 'cp ../vms.csv .'
                        
                        // Process CSV content and replace placeholders with config values
                        def csvContent = readFile('vms.csv')
                        def defaultTemplate = configProps.DEFAULT_VM_TEMPLATE ?: 't-debian12-86'
                        def defaultNode = configProps.DEFAULT_PROXMOX_NODE ?: 'thinkcentre'
                        
                        csvContent = csvContent
                            .replace('TEMPLATE_PLACEHOLDER', defaultTemplate)
                            .replace('NODE_PLACEHOLDER', defaultNode)
                        
                        // Write processed CSV back
                        writeFile file: "vms.csv", text: csvContent
                        
                        def duration = ((System.currentTimeMillis() - startTime) / 1000).intValue()
                        echo "VM configuration processed in ${duration}s"
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
                                string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-url", variable: 'TF_VAR_pm_api_url'),
                                string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-token-id", variable: 'TF_VAR_pm_api_token_id'),
                                string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-token-secret", variable: 'TF_VAR_pm_api_token_secret')
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
                                    if (env.USE_CACHE && env.USE_CACHE.toBoolean()) {
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
                                string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-url", variable: 'TF_VAR_pm_api_url'),
                                string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-token-id", variable: 'TF_VAR_pm_api_token_id'),
                                string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-token-secret", variable: 'TF_VAR_pm_api_token_secret')
                            ]) {
                                script {
                                    def startTime = System.currentTimeMillis()
                                    
                                    // Set CNI environment variables for Terraform
                                    env.TF_VAR_cni_type = env.CNI_TYPE
                                    env.TF_VAR_cni_version = env.CNI_VERSION
                                    
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
                expression { env.RUN_ANSIBLE && env.RUN_ANSIBLE.toBoolean() }
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
                expression { env.RUN_ANSIBLE && env.RUN_ANSIBLE.toBoolean() }
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
                expression { env.RUN_ANSIBLE && env.RUN_ANSIBLE.toBoolean() }
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
                expression { env.RUN_ANSIBLE && env.RUN_ANSIBLE.toBoolean() }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '../scripts/extract_kubeconfig.sh'
                        
                        // Send KUBECONFIG to Slack
                        withCredentials([string(credentialsId: env.SLACK_WEBHOOK_CREDENTIAL_ID, variable: 'SLACK_WEBHOOK_URL')]) {
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
                        string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-url", variable: 'TF_VAR_pm_api_url'),
                        string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-token-id", variable: 'TF_VAR_pm_api_token_id'),
                        string(credentialsId: "${env.PROXMOX_CREDENTIALS_PREFIX}-api-token-secret", variable: 'TF_VAR_pm_api_token_secret')
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
                if (env.RUN_ANSIBLE && env.RUN_ANSIBLE.toBoolean()) {
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