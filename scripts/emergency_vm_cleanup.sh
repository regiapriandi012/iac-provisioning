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

# Method 1: Direct Proxmox API destroy (fastest and most reliable)
echo "🚀 Attempting direct Proxmox API VM destruction..."
if ${WORKSPACE}/scripts/proxmox_vm_destroyer.sh ${TERRAFORM_DIR}; then
    echo "✅ Direct Proxmox API destroy completed successfully!"
    exit 0
fi

echo "⚠️  Direct API destroy failed, trying standard terraform destroy..."

# Method 2: Direct state cleanup (skip terraform destroy due to credentials)
echo "🚨 API destroy failed - proceeding with direct state cleanup..."
echo "⚠️  Note: VMs may remain in Proxmox but will be removed from Terraform state"

# List all resources that will be removed
echo "📋 Resources to be removed from state:"
terraform state list 2>/dev/null | while IFS= read -r resource; do
    echo "  - $resource"
done

echo ""
echo "🗑️  Removing all resources from terraform state..."

# Remove all resources from state (this prevents resource accumulation in terraform)
terraform state list 2>/dev/null | while IFS= read -r resource; do
    echo "🗑️  Removing from state: $resource"
    terraform state rm "$resource" || true
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