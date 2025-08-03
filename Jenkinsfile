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
        choice(
            name: 'cluster_preset',
            choices: ['small-single-master', 'medium-single-master', 'ha-3-masters', 'custom'],
            description: 'Cluster size preset configuration'
        )
        choice(
            name: 'vm_template',
            choices: ['t-debian12-86', 't-centos9-86'],
            description: 'VM template to use for all nodes'
        )
        string(
            name: 'proxmox_node',
            defaultValue: 'thinkcentre',
            description: 'Target Proxmox node for VM deployment'
        )
        text(
            name: 'vm_csv_content',
            defaultValue: '''vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,32G
0,kube-worker01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,32G
0,kube-worker02,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,32G''',
            description: 'Custom VM specifications (CSV format) - used when cluster_preset is "custom"'
        )
        
        // ===== Advanced Options =====
        booleanParam(
            name: 'use_cache',
            defaultValue: true,
            description: 'Enable caching for faster subsequent runs'
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
                        
                        # Check if packages are already installed
                        NEED_INSTALL=false
                        if ! python3 -c "import asyncssh" 2>/dev/null; then
                            NEED_INSTALL=true
                        fi
                        if ! python3 -c "import mitogen" 2>/dev/null; then
                            NEED_INSTALL=true
                        fi
                        
                        if [ "$NEED_INSTALL" = "true" ]; then
                            echo "Installing required Python packages..."
                            pip install --upgrade pip
                            pip install asyncssh paramiko mitogen
                        else
                            echo "Python packages already installed"
                        fi
                        
                        # Setup Mitogen for Ansible (ULTRA-FAST performance)
                        cd ${ANSIBLE_DIR}
                        if [ -f "setup_mitogen.py" ]; then
                            echo "Setting up Mitogen for ULTRA-FAST Ansible performance..."
                            python3 setup_mitogen.py || true
                            python3 mitogen_ansible_cfg.py || true
                        fi
                        cd ${WORKSPACE}
                        
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
0,kube-master,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,50G
0,kube-worker01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,50G
0,kube-worker02,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,50G''',
                                
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
                            
                            # Run VM readiness check with retry mechanism
                            MAX_RETRIES=10
                            RETRY_DELAY=30
                            
                            for i in $(seq 1 $MAX_RETRIES); do
                                echo "VM readiness check attempt $i/$MAX_RETRIES..."
                                
                                if ${WORKSPACE}/venv/bin/python scripts/smart_vm_ready.py ${INVENTORY_FILE} 20; then
                                    echo "All VMs are ready!"
                                    break
                                else
                                    if [ $i -lt $MAX_RETRIES ]; then
                                        echo "Some VMs not ready yet. Waiting ${RETRY_DELAY}s before retry..."
                                        sleep $RETRY_DELAY
                                    else
                                        echo "ERROR: VMs still not ready after $MAX_RETRIES attempts"
                                        exit 1
                                    fi
                                fi
                            done
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
                expression { params.run_ansible }
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
                            
                            # Debug: Check current directory and inventory
                            echo "Current directory: $(pwd)"
                            echo "Inventory file: ${INVENTORY_FILE}"
                            echo "Inventory content (first 10 lines):"
                            head -10 ${INVENTORY_FILE} || echo "Cannot read inventory"
                            
                            # Test ansible connectivity first
                            echo ""
                            echo "Testing ansible connectivity to masters..."
                            FIRST_MASTER=$(${WORKSPACE}/venv/bin/python -c "
import json
with open('${INVENTORY_FILE}', 'r') as f:
    inv = json.load(f)
    masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
    if masters:
        print(masters[0])
")
                            
                            if [ -n "$FIRST_MASTER" ]; then
                                echo "First master: $FIRST_MASTER"
                                echo "Testing ansible ping..."
                                ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m ping --timeout=10 || echo "Ping failed"
                                
                                echo ""
                                echo "Checking if kubeconfig exists on master..."
                                ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "ls -la /etc/kubernetes/admin.conf" --timeout=10 || echo "Cannot check file"
                            fi
                            
                            # Extract KUBECONFIG
                            mkdir -p kubeconfig
                            
                            # Try to get kubeconfig with simple bash script first
                            echo ""
                            echo "Attempting to extract kubeconfig..."
                            if bash scripts/simple_get_kubeconfig.sh ${INVENTORY_FILE} kubeconfig/admin.conf; then
                                echo "KUBECONFIG extracted successfully with simple bash script"
                            elif ${WORKSPACE}/venv/bin/python scripts/get_kubeconfig_v2.py ${INVENTORY_FILE} kubeconfig/admin.conf; then
                                echo "KUBECONFIG extracted successfully with v2 script"
                            elif ${WORKSPACE}/venv/bin/python scripts/get_kubeconfig.py ${INVENTORY_FILE} kubeconfig/admin.conf; then
                                echo "KUBECONFIG extracted successfully with v1 script"
                                
                                # Verify the kubeconfig file
                                if [ -f kubeconfig/admin.conf ]; then
                                    KUBE_SIZE=$(stat -c%s kubeconfig/admin.conf)
                                    echo "KUBECONFIG file size: $KUBE_SIZE bytes"
                                    
                                    if [ $KUBE_SIZE -lt 100 ]; then
                                        echo "ERROR: KUBECONFIG file is too small, trying direct ansible approach..."
                                        
                                        # Fallback: try direct ansible command
                                        FIRST_MASTER=$(${WORKSPACE}/venv/bin/python -c "
import json
with open('${INVENTORY_FILE}', 'r') as f:
    inv = json.load(f)
    masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
    if masters:
                                            print(masters[0])
")
                                        
                                        if [ -n "$FIRST_MASTER" ]; then
                                            echo "Trying to fetch kubeconfig directly from $FIRST_MASTER..."
                                            
                                            # Method 1: Try direct fetch
                                            echo "Method 1: Using ansible fetch module..."
                                            ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m fetch \
                                                -a "src=/etc/kubernetes/admin.conf dest=kubeconfig/admin.conf flat=yes" \
                                                --timeout=30
                                            
                                            # Check if fetch worked
                                            if [ ! -f kubeconfig/admin.conf ] || [ ! -s kubeconfig/admin.conf ]; then
                                                echo "Method 1 failed, trying Method 2..."
                                                
                                                # Method 2: Use shell to cat the file
                                                echo "Method 2: Using ansible shell to cat file..."
                                                ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell \
                                                    -a "cat /etc/kubernetes/admin.conf" --timeout=30 > kubeconfig/admin.conf.tmp
                                                
                                                # Clean ansible output (remove the first line with hostname and SUCCESS)
                                                if [ -f kubeconfig/admin.conf.tmp ]; then
                                                    grep -A 1000 "apiVersion:" kubeconfig/admin.conf.tmp > kubeconfig/admin.conf || true
                                                    rm -f kubeconfig/admin.conf.tmp
                                                fi
                                            fi
                                            
                                            # If still no luck, try kubectl config view
                                            if [ ! -f kubeconfig/admin.conf ] || [ ! -s kubeconfig/admin.conf ] || ! grep -q "apiVersion:" kubeconfig/admin.conf; then
                                                echo "Method 2 failed, trying Method 3..."
                                                echo "Method 3: Using kubectl config view..."
                                                
                                                ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell \
                                                    -a "kubectl config view --raw" --timeout=30 > kubeconfig/admin.conf.tmp
                                                    
                                                if [ -f kubeconfig/admin.conf.tmp ]; then
                                                    grep -A 1000 "apiVersion:" kubeconfig/admin.conf.tmp > kubeconfig/admin.conf || true
                                                    rm -f kubeconfig/admin.conf.tmp
                                                fi
                                            fi
                                        fi
                                    fi
                                else
                                    echo "ERROR: kubeconfig/admin.conf not created!"
                                fi
                            else
                                echo "ERROR: Failed to extract KUBECONFIG"
                            fi
                            
                            # Final check
                            if [ -f kubeconfig/admin.conf ] && [ -s kubeconfig/admin.conf ]; then
                                echo "KUBECONFIG file exists and has content"
                                echo "First 5 lines:"
                                head -5 kubeconfig/admin.conf
                            else
                                echo "WARNING: No valid KUBECONFIG found!"
                                echo "Creating placeholder..."
                                echo "# KUBECONFIG could not be retrieved automatically" > kubeconfig/admin.conf
                                echo "# Please manually copy from master node: /etc/kubernetes/admin.conf" >> kubeconfig/admin.conf
                            fi
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
                                script: "grep 'server:' kubeconfig/admin.conf | awk '{print \$2}' | head -1",
                                returnStdout: true
                            ).trim()
                            
                            // Debug output
                            echo "Master Count: ${masterCount}"
                            echo "Worker Count: ${workerCount}"
                            echo "Cluster Endpoint: ${clusterEndpoint}"
                            echo "KUBECONFIG length: ${kubeconfigContent.length()}"
                            
                            // Create a Python script to properly format the message
                            def pythonScript = '''
import json
import sys
import os

# Read inputs
build_num = sys.argv[1]
duration = sys.argv[2]
endpoint = sys.argv[3]
masters = sys.argv[4]
workers = sys.argv[5]
build_url = sys.argv[6]

print(f"Debug - Build: {build_num}")
print(f"Debug - Duration: {duration}")
print(f"Debug - Endpoint: {endpoint}")
print(f"Debug - Masters: {masters}")
print(f"Debug - Workers: {workers}")

# Read kubeconfig
kubeconfig_path = 'kubeconfig/admin.conf'
if not os.path.exists(kubeconfig_path):
    print(f"ERROR: {kubeconfig_path} does not exist!")
    print(f"Current directory: {os.getcwd()}")
    print(f"Directory contents: {os.listdir('.')}")
    if os.path.exists('kubeconfig'):
        print(f"Kubeconfig dir contents: {os.listdir('kubeconfig')}")
    kubeconfig = "# ERROR: KUBECONFIG could not be retrieved\\n# Please check the cluster setup"
else:
    with open(kubeconfig_path, 'r') as f:
        kubeconfig = f.read()
    
    # Check if it's a placeholder
    if kubeconfig.startswith("# KUBECONFIG could not be retrieved"):
        print("WARNING: Using placeholder kubeconfig")
    else:
        print(f"Debug - KUBECONFIG length: {len(kubeconfig)}")
        print(f"Debug - KUBECONFIG first 100 chars: {kubeconfig[:100]}")
        
        # Validate it's a real kubeconfig
        if 'apiVersion:' not in kubeconfig or len(kubeconfig) < 100:
            print("WARNING: kubeconfig seems invalid")
            kubeconfig = f"# WARNING: Invalid KUBECONFIG (length: {len(kubeconfig)})\\n# Content:\\n{kubeconfig}"

# For Slack, we need to escape the content properly
# But since we're using json.dump, it should handle it automatically

# Slack has a limit on message size, so we need to be careful
# Maximum text length in a section block is 3000 characters
# Total message size should be under 40KB

# Truncate kubeconfig if it's too long
max_kubeconfig_length = 2000  # Leave room for the rest of the message
if len(kubeconfig) > max_kubeconfig_length:
    print(f"WARNING: Kubeconfig too long ({len(kubeconfig)} chars), truncating to {max_kubeconfig_length}")
    # Keep the important parts: beginning and a note
    kubeconfig_truncated = kubeconfig[:max_kubeconfig_length] + "\\n\\n# ... truncated for Slack (full config in Jenkins artifacts)"
else:
    kubeconfig_truncated = kubeconfig

# Create the Slack message
message = {
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
                {"type": "mrkdwn", "text": f"*Build:* #{build_num}"},
                {"type": "mrkdwn", "text": f"*Duration:* {duration}"},
                {"type": "mrkdwn", "text": f"*Cluster Endpoint:* `{endpoint}`" if endpoint else "*Cluster Endpoint:* Not found"},
                {"type": "mrkdwn", "text": f"*Nodes:* {masters} masters, {workers} workers"}
            ]
        },
        {"type": "divider"},
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*📋 Access Instructions:*\\n1. Download `kubeconfig/admin.conf` from Jenkins artifacts\\n2. Save to `~/.kube/config`\\n3. Run `kubectl get nodes`"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*Quick Setup (if kubeconfig is small):*\\n```bash\\n# First {min(500, len(kubeconfig_truncated))} chars of kubeconfig:\\n{kubeconfig_truncated[:500]}...\\n\\n# Full config available in Jenkins artifacts\\n```"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*Jenkins Build:* <{build_url}|View Details>"
            }
        }
    ]
}

# Write to file
with open('slack_message.json', 'w') as f:
    json.dump(message, f, indent=2)
    
# Check message size
import os
message_size = os.path.getsize('slack_message.json')
print(f"Slack message written to slack_message.json (size: {message_size} bytes)")

if message_size > 40000:  # 40KB limit
    print(f"WARNING: Message too large ({message_size} bytes), creating simplified version...")
    
    # Create a simplified message
    simple_message = {
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
                    {"type": "mrkdwn", "text": f"*Build:* #{build_num}"},
                    {"type": "mrkdwn", "text": f"*Duration:* {duration}"},
                    {"type": "mrkdwn", "text": f"*Cluster Endpoint:* `{endpoint}`"},
                    {"type": "mrkdwn", "text": f"*Nodes:* {masters} masters, {workers} workers"}
                ]
            },
            {"type": "divider"},
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*📋 Access Instructions:*\\n1. Download `kubeconfig/admin.conf` from Jenkins artifacts\\n2. Save to `~/.kube/config`\\n3. Run `kubectl get nodes`\\n\\n*Note:* Full kubeconfig too large for Slack. Please download from Jenkins."
                }
            }
        ]
    }
    
    with open('slack_message.json', 'w') as f:
        json.dump(simple_message, f, indent=2)
    
    print("Created simplified message due to size limit")

# Also write a debug version to see what's happening
with open('debug_kubeconfig.txt', 'w') as f:
    f.write(kubeconfig)
print("Debug - KUBECONFIG written to debug_kubeconfig.txt")
'''
                            
                            writeFile file: "format_slack.py", text: pythonScript
                            
                            sh """#!/bin/bash
                                # Debug: Check if kubeconfig exists
                                echo "Checking kubeconfig file:"
                                ls -la kubeconfig/admin.conf || echo "Kubeconfig file not found!"
                                echo ""
                                echo "First 5 lines of kubeconfig:"
                                head -5 kubeconfig/admin.conf || echo "Cannot read kubeconfig!"
                                echo ""
                                
                                # Run Python script to format the message
                                python3 format_slack.py "${BUILD_NUMBER}" "${buildDuration}" "${clusterEndpoint}" "${masterCount}" "${workerCount}" "${BUILD_URL}"
                                
                                # Debug: Check the generated JSON
                                echo ""
                                echo "Generated Slack message (first 1000 chars):"
                                cat slack_message.json | head -c 1000
                                echo ""
                                echo ""
                                echo "Debug kubeconfig content:"
                                cat debug_kubeconfig.txt | head -20 || echo "No debug kubeconfig"
                                echo ""
                                
                                # Send to Slack
                                curl -X POST ${SLACK_WEBHOOK_URL} \
                                     -H "Content-Type: application/json" \
                                     -d @slack_message.json \
                                     --silent --show-error --fail \
                                && echo "KUBECONFIG sent to Slack successfully!" \
                                || echo "Failed to send to Slack"
                                
                                # Cleanup
                                rm -f slack_message.json format_slack.py debug_kubeconfig.txt
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