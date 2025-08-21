pipeline {
    agent any

    // Define parameters that can be passed from Django REST API
    parameters {
        string(name: 'CLUSTER_NAME', defaultValue: 'k8s-cluster', description: 'Name of the Kubernetes cluster')
        string(name: 'DESCRIPTION', defaultValue: 'Kubernetes cluster deployed from Django', description: 'Cluster description')
        choice(name: 'PROXMOX_NODE', choices: ['thinkcentre', 'proxmox'], description: 'Proxmox node to deploy on')
        choice(name: 'VM_TEMPLATE', choices: ['t-debian12-kube', 't-centos9-kube'], description: 'VM template to use')
        string(name: 'MASTER_COUNT', defaultValue: '3', description: 'Number of master nodes')
        string(name: 'WORKER_COUNT', defaultValue: '2', description: 'Number of worker nodes')
        string(name: 'CORES', defaultValue: '2', description: 'CPU cores per VM')
        string(name: 'MEMORY', defaultValue: '2048', description: 'Memory per VM in MB')
        string(name: 'DISK_SIZE', defaultValue: '10G', description: 'Disk size per VM')
        string(name: 'KUBERNETES_VERSION', defaultValue: '1.32.7', description: 'Kubernetes version')
        string(name: 'CNI_TYPE', defaultValue: 'cilium', description: 'CNI type')
        string(name: 'CNI_VERSION', defaultValue: '1.14.5', description: 'CNI version')
        string(name: 'POD_NETWORK_CIDR', defaultValue: '10.244.0.0/16', description: 'Pod network CIDR')
        string(name: 'SERVICE_CIDR', defaultValue: '10.96.0.0/12', description: 'Service CIDR')
        string(name: 'CONTAINER_RUNTIME', defaultValue: 'containerd', description: 'Container runtime')
        string(name: 'IP_RANGE_START', defaultValue: '10.200.0.0/24', description: 'IP range for VMs')
    }

    environment {
        TERRAFORM_DIR = 'terraform'
        ANSIBLE_DIR = 'ansible'
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
        INVENTORY_FILE = 'inventory/k8s-inventory.json'
        INVENTORY_SCRIPT = '../scripts/inventory.py'
        CACHE_DIR = "${WORKSPACE}/.iac-cache"
        CONFIG_FILE = 'config/environment.conf'
        
        // Use parameters passed from Django REST API or defaults from config
        TF_VAR_cluster_name = "${params.CLUSTER_NAME}"
        TF_VAR_master_node_count = "${params.MASTER_COUNT}"
        TF_VAR_worker_node_count = "${params.WORKER_COUNT}"
        TF_VAR_vm_template = "${params.VM_TEMPLATE}"
        TF_VAR_proxmox_node = "${params.PROXMOX_NODE}"
        TF_VAR_vm_cores = "${params.CORES}"
        TF_VAR_vm_memory = "${params.MEMORY}"
        TF_VAR_vm_disk_size = "${params.DISK_SIZE}"
        TF_VAR_kubernetes_version = "${params.KUBERNETES_VERSION}"
        TF_VAR_cni_type = "${params.CNI_TYPE}"
        TF_VAR_cni_version = "${params.CNI_VERSION}"
        TF_VAR_pod_network_cidr = "${params.POD_NETWORK_CIDR}"
        TF_VAR_service_cidr = "${params.SERVICE_CIDR}"
        TF_VAR_container_runtime = "${params.CONTAINER_RUNTIME}"
        TF_VAR_ip_range_start = "${params.IP_RANGE_START}"
    }
    
    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Validate Parameters') {
            steps {
                script {
                    echo """
=== CLUSTER DEPLOYMENT STARTED ===
Cluster Name: ${params.CLUSTER_NAME}
Description: ${params.DESCRIPTION}
Proxmox Node: ${params.PROXMOX_NODE}
VM Template: ${params.VM_TEMPLATE}
Masters: ${params.MASTER_COUNT}
Workers: ${params.WORKER_COUNT}
VM Specs: ${params.CORES} cores, ${params.MEMORY}MB RAM, ${params.DISK_SIZE} disk
Kubernetes: ${params.KUBERNETES_VERSION} with ${params.CNI_TYPE} ${params.CNI_VERSION}
Parameters passed from Django REST API successfully!

=== TERRAFORM ENVIRONMENT VARIABLES ===
TF_VAR_cluster_name: ${env.TF_VAR_cluster_name}
TF_VAR_master_node_count: ${env.TF_VAR_master_node_count}
TF_VAR_worker_node_count: ${env.TF_VAR_worker_node_count}
TF_VAR_vm_template: ${env.TF_VAR_vm_template}
TF_VAR_proxmox_node: ${env.TF_VAR_proxmox_node}
TF_VAR_vm_cores: ${env.TF_VAR_vm_cores}
TF_VAR_vm_memory: ${env.TF_VAR_vm_memory}
=====================================
"""
                }
            }
        }

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
                    env.KUBERNETES_VERSION = configProps.OVERRIDE_KUBERNETES_VERSION ?: (configProps.DEFAULT_KUBERNETES_VERSION ?: '1.28.0')
                    
                    env.PROXMOX_CREDENTIALS_PREFIX = configProps.PROXMOX_CREDENTIALS_PREFIX ?: 'proxmox'
                    env.SLACK_WEBHOOK_CREDENTIAL_ID = configProps.SLACK_WEBHOOK_CREDENTIAL_ID ?: 'slack-webhook-url'
                    
                    sh './scripts/setup_environment.sh'
                    
                    // Set environment variables for subsequent stages
                    env.PATH = "${WORKSPACE}/venv/bin:${env.PATH}"
                    env.VIRTUAL_ENV = "${WORKSPACE}/venv"
                }
            }
        }
        
        // Environment variables now set from parameters in environment block above
        
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
                                    
                                    // Set CNI and Kubernetes environment variables for Terraform
                                    env.TF_VAR_cni_type = env.CNI_TYPE
                                    env.TF_VAR_cni_version = env.CNI_VERSION
                                    env.TF_VAR_kubernetes_version = env.KUBERNETES_VERSION
                                    
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
                        
                        // Send metadata to Django webhook
                        try {
                            echo "Sending cluster metadata to Django..."
                            sh """
                                cd ${WORKSPACE}
                                python3 scripts/send_metadata_to_django.py "${params.CLUSTER_NAME}" "https://labngoprek.my.id"
                            """
                            echo "Successfully sent metadata to Django!"
                        } catch (Exception e) {
                            echo "Warning: Failed to send metadata to Django: ${e.getMessage()}"
                            // Continue with deployment even if Django webhook fails
                        }
                        
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
            Kubernetes cluster deployment completed successfully!
            
            Cluster Configuration (from Django REST API):
            - Cluster: ${params.CLUSTER_NAME}
            - Masters: ${params.MASTER_COUNT}, Workers: ${params.WORKER_COUNT}
            - VM Template: ${params.VM_TEMPLATE} on ${params.PROXMOX_NODE}
            - Kubernetes: ${params.KUBERNETES_VERSION} with ${params.CNI_TYPE}
            - VM Specs: ${params.CORES} cores, ${params.MEMORY}MB RAM, ${params.DISK_SIZE} disk
            
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