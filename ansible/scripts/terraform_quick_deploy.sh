#!/bin/bash
set -e

echo "🚀 Quick Terraform Deployment"
echo "================================"

# Change to terraform directory
cd "$(dirname "$0")/../../terraform"

# Check if VMs already exist and are running
echo "🔍 Checking existing VMs..."
if terraform show -json | jq -r '.values.root_module.resources[]? | select(.type=="proxmox_vm_qemu") | .values.vm_state' 2>/dev/null | grep -q "running"; then
    echo "✅ VMs already running, checking outputs..."
    
    # Verify outputs exist
    if terraform output -json > /dev/null 2>&1; then
        echo "✅ Terraform outputs available"
        
        # Quick CSV update without full terraform apply
        if [ -f "vms.csv" ]; then
            echo "✅ VM CSV file exists"
        else
            echo "⚠️  Regenerating CSV from outputs..."
            terraform apply -target=local_file.vms_csv -auto-approve
        fi
        
        echo "⚡ Using existing infrastructure (fast path)"
        exit 0
    fi
fi

echo "🔧 Deploying new infrastructure..."

# Parallel deployment optimization
export TF_PARALLELISM=10

# Fast apply with parallelism
terraform apply -auto-approve -parallelism=10

echo "✅ Terraform deployment completed"

# Wait a bit for VMs to initialize
echo "⏳ Waiting for VMs to initialize (30s)..."
sleep 30

echo "🎉 Quick deployment finished!"