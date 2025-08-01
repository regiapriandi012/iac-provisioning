#!/bin/bash
#
# Debug Terraform outputs and CSV generation
#

echo "=== Terraform Output Debug ==="
cd ../terraform

echo "1. Terraform state list:"
terraform state list | grep vm_qemu || echo "No VMs in state"

echo
echo "2. VM assignments output:"
terraform output vm_assignments 2>/dev/null || echo "No vm_assignments output"

echo
echo "3. Created VMs output:"
terraform output created_vms 2>/dev/null || echo "No created_vms output"

echo
echo "4. Current CSV content:"
cat vms.csv

echo
echo "5. Local VM data (should show IP addresses):"
terraform console <<< "local.vm_data" 2>/dev/null || echo "Cannot access local.vm_data"

echo
echo "6. Actual VM IP configs:"
terraform state show $(terraform state list | grep vm_qemu | head -1) 2>/dev/null | grep -E "(ipconfig|ip_address)" || echo "No VM state found"