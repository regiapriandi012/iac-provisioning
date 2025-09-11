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

# ULTRA-OPTIMIZED initial delay
echo "Waiting 10s for VMs to initialize..."
sleep 10

# ULTRA-FAST retry mechanism with exponential backoff
MAX_RETRIES=15
INITIAL_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
    echo "VM readiness check attempt $i/$MAX_RETRIES..."
    
    if ${WORKSPACE}/venv/bin/python ${WORKSPACE}/scripts/smart_vm_ready.py ${INVENTORY_FILE} 20; then
        echo "All VMs are ready!"
        break
    else
        if [ $i -lt $MAX_RETRIES ]; then
            if [ $i -le 5 ]; then
                RETRY_DELAY=$INITIAL_DELAY
                echo "Quick retry in ${RETRY_DELAY}s..."
            else
                # Exponential backoff after 5 attempts
                RETRY_DELAY=$((INITIAL_DELAY * (i - 3)))
                echo "Exponential backoff: waiting ${RETRY_DELAY}s..."
            fi
            sleep $RETRY_DELAY
        else
            echo "ERROR: VMs still not ready after $MAX_RETRIES attempts"
            exit 1
        fi
    fi
done