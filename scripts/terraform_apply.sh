#!/bin/bash
# Terraform Apply Script
# Provisions infrastructure with parallel execution

set -e

# Only load environment if TF_VAR variables are not already set (e.g., by Jenkins)
if [ -z "$TF_VAR_master_node_count" ]; then
    echo "🌍 Loading environment configuration..."
    source ../scripts/load_environment.sh
else
    echo "🌍 Using pre-set TF_VAR environment variables..."
    echo "   Masters: ${TF_VAR_master_node_count}, Workers: ${TF_VAR_worker_node_count}"
    echo "   Template: ${TF_VAR_vm_template}, Node: ${TF_VAR_proxmox_node}"
fi

echo "🔧 Applying Terraform with environment variables (TF_VAR_*)..."
terraform apply -auto-approve -parallelism=20  # ULTRA-FAST: Doubled parallelism

echo "Deployment summary:"
terraform output assignment_summary || echo "No assignment summary available"

echo ""
echo "Generating Ansible inventory with CNI configuration..."
terraform output ansible_inventory_json > ../ansible/inventory/k8s-inventory.json

echo ""
echo "Terraform state list:"
terraform state list || echo "No resources in state"