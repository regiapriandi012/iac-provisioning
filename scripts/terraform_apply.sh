#!/bin/bash
# Terraform Apply Script
# Provisions infrastructure with parallel execution

set -e

# Load environment configuration first
echo "🌍 Loading environment configuration..."
source ../scripts/load_environment.sh

echo "🔧 Applying Terraform with environment variables (TF_VAR_*)..."
terraform apply -auto-approve -parallelism=10

echo "Deployment summary:"
terraform output assignment_summary || echo "No assignment summary available"

echo ""
echo "Generating Ansible inventory with CNI configuration..."
terraform output ansible_inventory_json > ../ansible/inventory/k8s-inventory.json

echo ""
echo "Terraform state list:"
terraform state list || echo "No resources in state"