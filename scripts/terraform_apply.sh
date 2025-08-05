#!/bin/bash
# Terraform Apply Script
# Provisions infrastructure with parallel execution

set -e

echo "Applying Terraform with parallel execution..."
terraform apply -auto-approve -parallelism=10

echo "Deployment summary:"
terraform output assignment_summary || echo "No assignment summary available"

echo ""
echo "Generating Ansible inventory with CNI configuration..."
terraform output ansible_inventory_json > ../ansible/inventory/k8s-inventory.json || {
    echo "Failed to get Terraform inventory output, generating from CSV..."
    ../scripts/generate_ansible_inventory.sh vms.csv ../ansible/inventory/k8s-inventory.json
}

echo ""
echo "Terraform state list:"
terraform state list || echo "No resources in state"