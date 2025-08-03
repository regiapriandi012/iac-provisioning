#!/bin/bash
# Terraform Apply Script
# Provisions infrastructure with parallel execution

set -e

echo "Applying Terraform with parallel execution..."
terraform apply -auto-approve -parallelism=10

echo "Deployment summary:"
terraform output assignment_summary || echo "No assignment summary available"

echo ""
echo "Checking ansible inventory output:"
terraform output ansible_inventory_json || echo "ERROR: No ansible_inventory_json output found"

echo ""
echo "Terraform state list:"
terraform state list || echo "No resources in state"