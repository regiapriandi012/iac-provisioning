#!/bin/bash
# Trigger Jenkins Destroy Job
# Triggers the iac-provision-destroy Jenkins job to clean up VMs

set -e

echo "🚨 JENKINS DESTROY JOB TRIGGER"
echo "==============================="

# Jenkins configuration
JENKINS_URL=${JENKINS_URL:-"http://localhost:8080"}
DESTROY_JOB_NAME=${DESTROY_JOB_NAME:-"iac-provision-destroy"}

# Build parameters to pass
CLUSTER_NAME=${CLUSTER_NAME:-${params_CLUSTER_NAME:-"k8s-cluster"}}
PROXMOX_NODE=${PROXMOX_NODE:-${params_PROXMOX_NODE:-"thinkcentre"}}
BUILD_ID=${BUILD_ID:-"manual-cleanup"}

echo "🔗 Jenkins URL: ${JENKINS_URL}"
echo "🗑️  Destroy Job: ${DESTROY_JOB_NAME}"
echo "🏷️  Cluster Name: ${CLUSTER_NAME}"
echo "🖥️  Proxmox Node: ${PROXMOX_NODE}"
echo "🔢 Build ID: ${BUILD_ID}"

# Try to get current terraform state info for parameters
TERRAFORM_DIR="terraform"
if [ -f "${TERRAFORM_DIR}/terraform.tfstate" ]; then
    echo "🔍 Extracting parameters from terraform state..."
    
    # Extract VM IDs and parameters from state
    TERRAFORM_PARAMS=$(terraform -chdir="${TERRAFORM_DIR}" show -json 2>/dev/null | python3 -c "
import json, sys
try:
    state = json.load(sys.stdin)
    params = {}
    
    if 'values' in state and 'root_module' in state['values']:
        resources = state['values']['root_module'].get('resources', [])
        for resource in resources:
            if resource.get('type') == 'proxmox_vm_qemu':
                values = resource.get('values', {})
                if 'vmid' in values:
                    params['VMIDS'] = params.get('VMIDS', [])
                    params['VMIDS'].append(str(values['vmid']))
                if 'target_node' in values:
                    params['PROXMOX_NODE'] = values['target_node']
    
    # Output parameters for Jenkins
    if 'VMIDS' in params:
        print(f\"VM_IDS={','.join(params['VMIDS'])}\")
    if 'PROXMOX_NODE' in params:
        print(f\"PROXMOX_NODE={params['PROXMOX_NODE']}\")
        
except Exception as e:
    print(f'# Error extracting params: {e}', file=sys.stderr)
" 2>/dev/null || echo "# No terraform params extracted")

    if [ -n "$TERRAFORM_PARAMS" ] && [ "$TERRAFORM_PARAMS" != "# No terraform params extracted" ]; then
        eval "$TERRAFORM_PARAMS"
        echo "📊 Extracted from terraform state:"
        echo "$TERRAFORM_PARAMS" | sed 's/^/   /'
    fi
fi

# Method 1: Try triggering Jenkins job via curl (if available)
echo ""
echo "🚀 Attempting to trigger Jenkins destroy job..."

if command -v curl >/dev/null 2>&1; then
    echo "📡 Using curl to trigger Jenkins job..."
    
    # Build URL with parameters
    JENKINS_TRIGGER_URL="${JENKINS_URL}/job/${DESTROY_JOB_NAME}/buildWithParameters"
    
    # Prepare POST data
    POST_DATA="CLUSTER_NAME=${CLUSTER_NAME}&PROXMOX_NODE=${PROXMOX_NODE}&BUILD_CAUSE=auto-cleanup-from-${BUILD_ID}"
    
    if [ -n "$VM_IDS" ]; then
        POST_DATA="${POST_DATA}&VM_IDS=${VM_IDS}"
    fi
    
    echo "🔗 Trigger URL: ${JENKINS_TRIGGER_URL}"
    echo "📝 Parameters: ${POST_DATA}"
    
    # Get Jenkins crumb for CSRF protection
    JENKINS_CRUMB=$(curl -s "${JENKINS_URL}/crumbIssuer/api/json" | grep -o '"crumb":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    
    # Trigger the job with proper headers
    if [ -n "$JENKINS_CRUMB" ]; then
        echo "🔒 Using Jenkins CSRF crumb for authentication"
        RESPONSE=$(curl -X POST \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -H "Jenkins-Crumb: ${JENKINS_CRUMB}" \
            -d "${POST_DATA}" \
            "${JENKINS_TRIGGER_URL}" \
            -w "HTTP_STATUS:%{http_code}" \
            -s || echo "HTTP_STATUS:000_CURL_FAILED")
    else
        echo "⚠️  No CSRF crumb available, trying without..."
        RESPONSE=$(curl -X POST \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "${POST_DATA}" \
            "${JENKINS_TRIGGER_URL}" \
            -w "HTTP_STATUS:%{http_code}" \
            -s || echo "HTTP_STATUS:000_CURL_FAILED")
    fi
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    
    if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "200" ]; then
        echo "✅ Jenkins destroy job triggered successfully!"
        echo "🔗 Check job status: ${JENKINS_URL}/job/${DESTROY_JOB_NAME}"
        exit 0
    else
        echo "⚠️  Jenkins job trigger failed (HTTP ${HTTP_STATUS})"
        echo "Response: $RESPONSE"
    fi
else
    echo "⚠️  curl not available for Jenkins API call"
fi

# Method 2: Try using Jenkins CLI (if available)
if [ -f "/var/lib/jenkins/jenkins-cli.jar" ]; then
    echo "🔧 Using Jenkins CLI to trigger destroy job..."
    
    java -jar /var/lib/jenkins/jenkins-cli.jar -s "${JENKINS_URL}" build "${DESTROY_JOB_NAME}" \
        -p "CLUSTER_NAME=${CLUSTER_NAME}" \
        -p "PROXMOX_NODE=${PROXMOX_NODE}" \
        -p "BUILD_CAUSE=auto-cleanup-from-${BUILD_ID}" \
        && {
            echo "✅ Jenkins destroy job triggered via CLI!"
            exit 0
        } || {
            echo "⚠️  Jenkins CLI trigger failed"
        }
fi

# Method 3: Direct execution fallback
echo "🔄 Falling back to direct emergency cleanup..."
EMERGENCY_SCRIPT="${WORKSPACE:-/var/lib/jenkins/workspace/iac-provision}/scripts/emergency_vm_cleanup.sh"

if [ -x "$EMERGENCY_SCRIPT" ]; then
    echo "🚨 Running emergency VM cleanup directly..."
    "$EMERGENCY_SCRIPT" "${TERRAFORM_DIR}"
    exit $?
else
    echo "❌ No cleanup methods available"
    echo ""
    echo "Manual cleanup options:"
    echo "1. Run Jenkins job manually: ${JENKINS_URL}/job/${DESTROY_JOB_NAME}"
    echo "2. Manual terraform destroy: cd terraform && terraform destroy --auto-approve"
    echo "3. Check Proxmox console for VMs to delete manually"
    exit 1
fi