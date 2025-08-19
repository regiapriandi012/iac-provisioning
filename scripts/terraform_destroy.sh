#!/bin/bash

# Terraform Destroy Script for Kubernetes Cluster
# This script safely destroys infrastructure for a specific cluster

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check required environment variables
check_env() {
    local required_vars=(
        "TF_VAR_cluster_name"
        "TF_VAR_pm_api_url"
        "TF_VAR_pm_api_token_id"
        "TF_VAR_pm_api_token_secret"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required environment variable $var is not set"
            exit 1
        fi
    done
}

# Validate cluster name
validate_cluster_name() {
    if [[ -z "${TF_VAR_cluster_name}" ]]; then
        error "Cluster name cannot be empty"
        exit 1
    fi
    
    if [[ "${TF_VAR_cluster_name}" =~ [^a-zA-Z0-9\-] ]]; then
        error "Cluster name contains invalid characters. Only alphanumeric and hyphens allowed."
        exit 1
    fi
    
    log "Cluster name validated: ${TF_VAR_cluster_name}"
}

# Check if terraform state exists and has resources for this cluster
check_terraform_state() {
    log "Checking terraform state for cluster: ${TF_VAR_cluster_name}"
    
    if [[ ! -f "terraform.tfstate" ]]; then
        warn "No terraform state file found"
        return 1
    fi
    
    # Check if state has any resources for this cluster
    local cluster_resources
    cluster_resources=$(terraform show -json terraform.tfstate 2>/dev/null | \
        python3 -c "
import json, sys
try:
    state = json.load(sys.stdin)
    resources = state.get('values', {}).get('root_module', {}).get('resources', [])
    cluster_resources = [r for r in resources if '${TF_VAR_cluster_name}' in str(r.get('values', {}))]
    print(len(cluster_resources))
except:
    print('0')
" 2>/dev/null || echo "0")
    
    if [[ "${cluster_resources}" -eq 0 ]]; then
        warn "No resources found for cluster '${TF_VAR_cluster_name}' in terraform state"
        return 1
    fi
    
    log "Found ${cluster_resources} resources for cluster '${TF_VAR_cluster_name}'"
    return 0
}

# Show what will be destroyed
show_destroy_plan() {
    log "Generating destroy plan for cluster: ${TF_VAR_cluster_name}"
    
    # Generate destroy plan
    if terraform plan -destroy -out=tfplan.destroy \
        -var cluster_name="${TF_VAR_cluster_name}" \
        -var proxmox_node="${TF_VAR_proxmox_node:-thinkcentre}" \
        -detailed-exitcode; then
        
        log "Destroy plan generated successfully"
        
        # Show summary of what will be destroyed
        echo -e "\n${YELLOW}=== RESOURCES TO BE DESTROYED ===${NC}"
        terraform show -json tfplan.destroy | python3 -c "
import json, sys
try:
    plan = json.load(sys.stdin)
    changes = plan.get('resource_changes', [])
    destroy_count = sum(1 for c in changes if c.get('change', {}).get('actions') == ['delete'])
    print(f'Total resources to destroy: {destroy_count}')
    
    for change in changes:
        if change.get('change', {}).get('actions') == ['delete']:
            resource_type = change.get('type', '')
            resource_name = change.get('name', '')
            address = change.get('address', '')
            print(f'  🔥 {address}')
except Exception as e:
    print(f'Error parsing plan: {e}')
"
        echo -e "${YELLOW}=====================================\n${NC}"
        
    else
        error "Failed to generate destroy plan"
        exit 1
    fi
}

# Execute terraform destroy
execute_destroy() {
    local start_time=$(date +%s)
    
    log "Starting infrastructure destruction for cluster: ${TF_VAR_cluster_name}"
    
    # Execute destroy with detailed logging
    if terraform destroy \
        -auto-approve \
        -var cluster_name="${TF_VAR_cluster_name}" \
        -var proxmox_node="${TF_VAR_proxmox_node:-thinkcentre}" \
        2>&1 | tee destroy.log; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        success "Infrastructure destroyed successfully in ${duration} seconds"
        
        # Clean up terraform files
        rm -f terraform.tfstate terraform.tfstate.backup
        rm -f tfplan.destroy
        
        return 0
    else
        error "Terraform destroy failed"
        
        # Show last few lines of output for debugging
        echo -e "\n${RED}=== DESTROY ERROR LOG ===${NC}"
        tail -20 destroy.log || echo "No log available"
        echo -e "${RED}=========================${NC}\n"
        
        return 1
    fi
}

# Verify destruction completed
verify_destruction() {
    log "Verifying destruction completed..."
    
    # Check if state file still has resources
    if [[ -f "terraform.tfstate" ]]; then
        local remaining_resources
        remaining_resources=$(terraform show -json terraform.tfstate 2>/dev/null | \
            python3 -c "
import json, sys
try:
    state = json.load(sys.stdin)
    resources = state.get('values', {}).get('root_module', {}).get('resources', [])
    cluster_resources = [r for r in resources if '${TF_VAR_cluster_name}' in str(r.get('values', {}))]
    print(len(cluster_resources))
except:
    print('0')
" || echo "0")
        
        if [[ "${remaining_resources}" -gt 0 ]]; then
            warn "Warning: ${remaining_resources} resources still exist in state"
            return 1
        fi
    fi
    
    success "Destruction verification completed - no resources remaining"
    return 0
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f tfplan.destroy destroy.log
}

# Main execution
main() {
    log "Starting terraform destroy process"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Validate environment and inputs
    check_env
    validate_cluster_name
    
    # Check if there's anything to destroy
    if ! check_terraform_state; then
        warn "No resources to destroy for cluster '${TF_VAR_cluster_name}'"
        success "Destruction completed (nothing to destroy)"
        exit 0
    fi
    
    # Show what will be destroyed
    show_destroy_plan
    
    # Execute the destruction
    if execute_destroy; then
        verify_destruction
        success "Cluster '${TF_VAR_cluster_name}' has been completely destroyed"
    else
        error "Failed to destroy cluster '${TF_VAR_cluster_name}'"
        exit 1
    fi
}

# Run main function
main "$@"