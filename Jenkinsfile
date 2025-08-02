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
                    url: 'https://gitlab.labngoprek.my.id/root/iac-provision'
            }
        }
        
        stage('Setup Environment') {
            steps {
                script {
                    // Set use_cache as environment variable for shell script
                    env.USE_CACHE = params.use_cache.toString()
                    
                    sh '''#!/bin/bash
                        # Create cache directories if caching is enabled
                        if [ "$USE_CACHE" = "true" ]; then
                            mkdir -p ${CACHE_DIR}/terraform ${CACHE_DIR}/ansible ${CACHE_DIR}/python
                        fi
                        
                        # Setup Python virtual environment
                        echo "Setting up Python virtual environment..."
                        
                        # Check if venv exists in cache
                        if [ "$USE_CACHE" = "true" ] && [ -d "${CACHE_DIR}/python/venv" ]; then
                            echo "Using cached Python venv"
                            cp -r ${CACHE_DIR}/python/venv ${WORKSPACE}/venv || true
                        fi
                        
                        # Create venv if it doesn't exist
                        if [ ! -d "${WORKSPACE}/venv" ]; then
                            echo "Creating new Python venv..."
                            python3 -m venv ${WORKSPACE}/venv
                        fi
                        
                        # Activate venv and install required packages
                        . ${WORKSPACE}/venv/bin/activate
                        
                        # Check if asyncssh is already installed
                        if ! python3 -c "import asyncssh" 2>/dev/null; then
                            echo "Installing required Python packages..."
                            pip install --upgrade pip
                            pip install asyncssh paramiko
                        else
                            echo "Python packages already installed"
                        fi
                        
                        # Cache the venv for future use
                        if [ "$USE_CACHE" = "true" ]; then
                            echo "Caching Python venv..."
                            cp -r ${WORKSPACE}/venv ${CACHE_DIR}/python/ || true
                        fi
                        
                        # Check Terraform cache
                        if [ "$USE_CACHE" = "true" ] && [ -d "${TERRAFORM_DIR}" ]; then
                            if [ -d "${CACHE_DIR}/terraform/.terraform" ]; then
                                echo "Using cached Terraform providers"
                                cp -r ${CACHE_DIR}/terraform/.terraform ${TERRAFORM_DIR}/ || true
                            fi
                        fi
                    '''
                    
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
                                    
                                    sh '''#!/bin/bash
                                        echo "Applying Terraform with parallel execution..."
                                        terraform apply -auto-approve -parallelism=10
                                        
                                        echo "Deployment summary:"
                                        terraform output assignment_summary || echo "No assignment summary available"
                                        
                                        echo ""
                                        echo "Checking ansible inventory output:"
                                        terraform output ansible_inventory_json || echo "ERROR: No ansible_inventory_json output found"
                                        
                                        echo ""
                                        echo "Terraform state list:"
                                        terraform state list || echo "No resources in state"
                                    '''
                                    
                                    def duration = ((System.currentTimeMillis() - startTime) / 1000).intValue()
                                    echo "Infrastructure provisioned in ${duration}s"
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Fast VM Readiness') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        def startTime = System.currentTimeMillis()
                        
                        sh '''#!/bin/bash
                            # Ensure we're using venv
                            . ${WORKSPACE}/venv/bin/activate
                            
                            # Generate inventory
                            mkdir -p inventory
                            cd ../terraform
                            
                            # Debug: Check terraform output
                            echo "Checking Terraform outputs..."
                            terraform output -json || echo "Failed to get terraform outputs"
                            
                            # Generate inventory file
                            echo "Generating inventory file..."
                            terraform output -raw ansible_inventory_json > ../ansible/${INVENTORY_FILE}
                            
                            cd ../ansible
                            
                            # Debug: Check inventory file
                            echo "Checking inventory file content..."
                            if [ -f "${INVENTORY_FILE}" ]; then
                                echo "Inventory file exists. Size: $(wc -c < ${INVENTORY_FILE}) bytes"
                                echo "First 500 chars of inventory:"
                                head -c 500 ${INVENTORY_FILE}
                                echo ""
                                
                                # Validate JSON
                                if python3 -m json.tool ${INVENTORY_FILE} > /dev/null 2>&1; then
                                    echo "Inventory JSON is valid"
                                else
                                    echo "ERROR: Invalid JSON in inventory file"
                                    cat ${INVENTORY_FILE}
                                fi
                            else
                                echo "ERROR: Inventory file not found at ${INVENTORY_FILE}"
                                ls -la inventory/
                            fi
                            
                            # Use smart VM checker (which now supports both async and sync)
                            echo "Using smart VM readiness checker..."
                            
                            # Quick initial delay
                            echo "Waiting 20s for VMs to initialize..."
                            sleep 20
                            
                            # Run VM readiness check with venv Python
                            ${WORKSPACE}/venv/bin/python scripts/smart_vm_ready.py ${INVENTORY_FILE} 20
                        '''
                        
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
                        
                        sh '''#!/bin/bash
                            echo "Starting optimized Kubernetes deployment..."
                            
                            # Check if inventory has hosts
                            if [ -f "${INVENTORY_FILE}" ]; then
                                # Use the count script to check hosts
                                HOST_COUNT=$(python3 scripts/count_inventory_hosts.py ${INVENTORY_FILE} 2>/dev/null || echo "0")
                                
                                if [ "$HOST_COUNT" = "0" ]; then
                                    echo "ERROR: No hosts found in inventory. Cannot deploy Kubernetes."
                                    echo "Please check that VMs were successfully created by Terraform."
                                    echo ""
                                    echo "Inventory details:"
                                    python3 scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details || cat ${INVENTORY_FILE}
                                    exit 1
                                fi
                                
                                echo "Found $HOST_COUNT hosts in inventory:"
                                python3 scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details
                                echo ""
                                echo "Proceeding with deployment..."
                            else
                                echo "ERROR: Inventory file not found at ${INVENTORY_FILE}"
                                ls -la inventory/
                                exit 1
                            fi
                            
                            # Use optimized setup script if available
                            if [ -f "run-k8s-setup-optimized.sh" ]; then
                                ./run-k8s-setup-optimized.sh
                            else
                                ./run-k8s-setup.sh
                            fi
                        '''
                        
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
        
        stage('Extract & Notify') {
            when {
                expression { params.run_ansible }
            }
            steps {
                dir("${ANSIBLE_DIR}") {
                    script {
                        sh '''#!/bin/bash
                            # Ensure we're using venv
                            . ${WORKSPACE}/venv/bin/activate
                            
                            # Extract KUBECONFIG
                            mkdir -p kubeconfig
                            ${WORKSPACE}/venv/bin/python scripts/get_kubeconfig.py ${INVENTORY_FILE} kubeconfig/admin.conf
                            
                            echo "KUBECONFIG extracted successfully"
                        '''
                        
                        // Send KUBECONFIG to Slack
                        withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_WEBHOOK_URL')]) {
                            def buildDuration = currentBuild.durationString.replace(' and counting', '')
                            def kubeconfigContent = readFile("kubeconfig/admin.conf")
                            
                            // Get cluster info
                            def masterCount = sh(
                                script: "python3 scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details | grep k8s_masters | wc -l",
                                returnStdout: true
                            ).trim()
                            
                            def workerCount = sh(
                                script: "python3 scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details | grep k8s_workers | wc -l",
                                returnStdout: true
                            ).trim()
                            
                            def clusterEndpoint = sh(
                                script: "grep 'server:' kubeconfig/admin.conf | awk '{print \$2}'",
                                returnStdout: true
                            ).trim()
                            
                            // Create escaped content for JSON
                            def kubeconfigEscaped = kubeconfigContent.replaceAll('"', '\\\\"').replaceAll('\n', '\\\\n')
                            
                            sh """#!/bin/bash
                                # Create Slack message with KUBECONFIG
                                cat > slack_kubeconfig.json << 'SLACK_EOF'
{
  "text": "Kubernetes Cluster Ready!",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "Kubernetes Cluster Deployed Successfully"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Build:* #${BUILD_NUMBER}"
        },
        {
          "type": "mrkdwn",
          "text": "*Duration:* ${buildDuration}"
        },
        {
          "type": "mrkdwn",
          "text": "*Cluster Endpoint:* \`${clusterEndpoint}\`"
        },
        {
          "type": "mrkdwn",
          "text": "*Nodes:* ${masterCount} masters, ${workerCount} workers"
        }
      ]
    },
    {
      "type": "divider"
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*KUBECONFIG Setup Instructions:*\\n\`\`\`bash\\nmkdir -p ~/.kube\\ncat > ~/.kube/config << 'EOF'\\n${kubeconfigEscaped}\\nEOF\\nchmod 600 ~/.kube/config\\nkubectl get nodes\`\`\`"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Jenkins Build:* <${BUILD_URL}|View Details>"
      }
    }
  ]
}
SLACK_EOF
                                
                                # Send to Slack
                                curl -X POST ${SLACK_WEBHOOK_URL} \
                                     -H "Content-Type: application/json" \
                                     -d @slack_kubeconfig.json \
                                     --silent --show-error --fail \
                                && echo "KUBECONFIG sent to Slack successfully!" \
                                || echo "Failed to send to Slack"
                                
                                # Cleanup
                                rm -f slack_kubeconfig.json
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