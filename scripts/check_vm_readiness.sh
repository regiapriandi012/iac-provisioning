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

# Use HYPER-PARALLEL VM readiness checker for maximum speed
echo "Using HYPER-PARALLEL VM readiness checker..."

# EXTENDED initial delay for better SSH service startup
echo "Waiting 30s for VMs to fully initialize (including SSH service)..."
sleep 30

# HYPER-PARALLEL readiness check (multiple strategies)
echo "🚀 Launching HYPER-PARALLEL VM readiness check..."
if ${WORKSPACE}/scripts/hyper_parallel_vm_ready.sh ${INVENTORY_FILE} 30; then
    echo "✅ HYPER-PARALLEL VM readiness check SUCCEEDED!"
    
    # ADDITIONAL VERIFICATION: Test SSH connection to ensure VMs are truly ready
    echo "🔍 Performing additional SSH verification..."
    if ${WORKSPACE}/venv/bin/python ${WORKSPACE}/scripts/smart_vm_ready.py ${INVENTORY_FILE} 10; then
        echo "✅ SSH verification confirmed - VMs are truly ready!"
    else
        echo "❌ SSH verification FAILED - VMs reported ready but not accessible!"
        exit 1
    fi
else
    echo "⚠️  HYPER-PARALLEL check failed, falling back to standard retry mechanism..."
    
    # Fallback to original retry mechanism
    MAX_RETRIES=10
    INITIAL_DELAY=5
    
    for i in $(seq 1 $MAX_RETRIES); do
        echo "Fallback VM readiness check attempt $i/$MAX_RETRIES..."
        
        if ${WORKSPACE}/venv/bin/python ${WORKSPACE}/scripts/smart_vm_ready.py ${INVENTORY_FILE} 20; then
            echo "All VMs are ready!"
            break
        else
            if [ $i -lt $MAX_RETRIES ]; then
                RETRY_DELAY=$INITIAL_DELAY
                echo "Retry in ${RETRY_DELAY}s..."
                sleep $RETRY_DELAY
            else
                echo "ERROR: VMs still not ready after $MAX_RETRIES attempts"
                exit 1
            fi
        fi
    done
fi