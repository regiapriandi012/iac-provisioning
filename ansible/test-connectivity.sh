#!/bin/bash

echo "=== Testing Connectivity to VMs ==="

# Deploy VMs terlebih dahulu jika belum ada
if [ ! -f "../terraform/vms.csv" ]; then
    echo "Deploying VMs with Terraform..."
    cd ../terraform
    terraform apply -auto-approve
    cd ../ansible
fi

# Generate inventory dari terraform output
echo "Generating inventory..."
python3 generate_inventory.py ../terraform/vms.csv > inventory/hosts.json

# Test ping ke semua host
echo "Testing ping to all hosts..."
ansible all -i inventory/hosts.json -m ping --timeout=120

# Test uptime untuk memastikan VM fully booted
echo "Testing uptime (to check if VMs are fully booted)..."
ansible all -i inventory/hosts.json -m command -a "uptime" --timeout=120

# Test SSH connection yang lebih detail
echo "Testing detailed SSH connection..."
ansible all -i inventory/hosts.json -m setup -a "filter=ansible_default_ipv4" --timeout=120

echo "=== Connectivity test completed ==="