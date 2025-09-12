#!/bin/bash
# Emergency VM Cleanup Script
# Cleans up VMs when Jenkins pipeline fails to prevent resource accumulation

set -e

echo "🚨 EMERGENCY VM CLEANUP SCRIPT"
echo "==============================="

# Configuration from environment or defaults
TERRAFORM_DIR=${1:-"terraform"}
WORKSPACE=${WORKSPACE:-"/var/lib/jenkins/workspace/iac-provision"}
BUILD_ID=${BUILD_ID:-"manual-cleanup"}

echo "📁 Workspace: ${WORKSPACE}"
echo "🏗️  Terraform Dir: ${TERRAFORM_DIR}"
echo "🔢 Build ID: ${BUILD_ID}"

cd "${WORKSPACE}"

if [ ! -d "${TERRAFORM_DIR}" ]; then
    echo "❌ Terraform directory not found: ${TERRAFORM_DIR}"
    exit 1
fi

cd "${TERRAFORM_DIR}"

echo "🔍 Checking Terraform state..."

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "⚠️  No terraform state file found - nothing to cleanup"
    exit 0
fi

# Check if there are any resources in state
RESOURCES=$(terraform state list 2>/dev/null | wc -l)
if [ "$RESOURCES" -eq 0 ]; then
    echo "⚠️  No resources found in terraform state - nothing to cleanup"
    exit 0
fi

echo "🎯 Found $RESOURCES terraform resources to cleanup"

# List what we're about to destroy
echo "📋 Resources to be destroyed:"
terraform state list 2>/dev/null | sed 's/^/  - /' || true

echo ""
echo "🗑️  Starting VM destruction process..."

# Method 1: Standard terraform destroy
echo "🔄 Attempting standard terraform destroy..."
if timeout 300 terraform destroy -auto-approve -no-color 2>&1; then
    echo "✅ Standard terraform destroy completed successfully!"
    exit 0
fi

echo "⚠️  Standard destroy failed or timed out, trying targeted cleanup..."

# Method 2: Targeted resource destruction
echo "🎯 Attempting targeted resource destruction..."
terraform state list 2>/dev/null | while IFS= read -r resource; do
    if [[ "$resource" =~ ^proxmox_vm_qemu\. ]] || [[ "$resource" =~ ^random_string\. ]]; then
        echo "🗑️  Destroying: $resource"
        timeout 60 terraform destroy -target="$resource" -auto-approve -no-color || {
            echo "❌ Failed to destroy $resource, continuing..."
        }
    fi
done

# Method 3: Force state removal (last resort)
echo "🚨 Final cleanup: removing remaining resources from state..."
terraform state list 2>/dev/null | while IFS= read -r resource; do
    if [[ "$resource" =~ ^proxmox_vm_qemu\. ]] || [[ "$resource" =~ ^random_string\. ]]; then
        echo "🗑️  Force removing from state: $resource"
        terraform state rm "$resource" || true
    fi
done

# Verify cleanup
REMAINING=$(terraform state list 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo "✅ VM cleanup completed successfully - no resources remaining!"
else
    echo "⚠️  VM cleanup completed with $REMAINING resources remaining"
    echo "🔍 Remaining resources:"
    terraform state list 2>/dev/null | sed 's/^/  - /' || true
fi

echo ""
echo "🧹 Emergency VM cleanup process finished"
echo "💡 Check Proxmox console to verify VMs are destroyed"
echo "==============================="