#!/bin/bash
# VM Readiness Check Script
# Ensures VMs are ready before Ansible deployment

set -e

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
    
    if ${WORKSPACE}/venv/bin/python ${WORKSPACE}/scripts/smart_vm_ready.py ${INVENTORY_FILE} 20; then
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