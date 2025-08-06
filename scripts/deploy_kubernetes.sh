#!/bin/bash
# Deploy Kubernetes Script
# Deploys Kubernetes cluster using Ansible

set -e

# Load environment configuration to check for fast deployment
if [ -f "../config/environment.conf" ]; then
    source ../config/environment.conf
fi

# Check if fast deployment is enabled
FAST_DEPLOYMENT=${FAST_DEPLOYMENT:-false}
if [ "$FAST_DEPLOYMENT" = "true" ]; then
    echo "⚡ Fast deployment enabled - using pre-configured templates"
    exec ./deploy_kubernetes_fast.sh
fi

echo "Starting standard Kubernetes deployment..."

# Check if inventory has hosts
if [ -f "${INVENTORY_FILE}" ]; then
    # Use the count script to check hosts
    HOST_COUNT=$(python3 ${WORKSPACE}/scripts/count_inventory_hosts.py ${INVENTORY_FILE} 2>/dev/null || echo "0")
    
    if [ "$HOST_COUNT" = "0" ]; then
        echo "ERROR: No hosts found in inventory. Cannot deploy Kubernetes."
        echo "Please check that VMs were successfully created by Terraform."
        echo ""
        echo "Inventory details:"
        python3 ${WORKSPACE}/scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details || cat ${INVENTORY_FILE}
        exit 1
    fi
    
    echo "Found $HOST_COUNT hosts in inventory:"
    python3 ${WORKSPACE}/scripts/count_inventory_hosts.py ${INVENTORY_FILE} --details
    echo ""
    echo "Proceeding with deployment..."
else
    echo "ERROR: Inventory file not found at ${INVENTORY_FILE}"
    ls -la inventory/
    exit 1
fi

# Use optimized setup script if available
if [ -f "${WORKSPACE}/scripts/run-k8s-setup-optimized.sh" ]; then
    ${WORKSPACE}/scripts/run-k8s-setup-optimized.sh
else
    ${WORKSPACE}/scripts/run-k8s-setup.sh
fi