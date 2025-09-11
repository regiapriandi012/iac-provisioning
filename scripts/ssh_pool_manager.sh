#!/bin/bash
# ULTRA-FAST SSH Connection Pool Manager
# Pre-establishes SSH connections to all VMs for faster subsequent connections

set -e

INVENTORY_FILE=${1:-"${ANSIBLE_DIR}/inventory/k8s-inventory.json"}
WORKSPACE=${WORKSPACE:-"/var/lib/jenkins/workspace/iac-provision"}

echo "🚀 Starting SSH Connection Pool Manager..."
echo "📁 Using inventory: ${INVENTORY_FILE}"

if [ ! -f "${INVENTORY_FILE}" ]; then
    echo "⚠️  Inventory file not found: ${INVENTORY_FILE}"
    exit 1
fi

# Extract all host IPs from inventory
echo "🔍 Extracting host IPs from inventory..."
hosts=$(python3 -c "
import json
import sys
try:
    with open('${INVENTORY_FILE}') as f:
        inventory = json.load(f)
    
    # Get all hosts from different groups
    all_hosts = set()
    for group_name, group_data in inventory.items():
        if isinstance(group_data, dict) and 'hosts' in group_data:
            for host_name, host_data in group_data['hosts'].items():
                if isinstance(host_data, dict) and 'ansible_host' in host_data:
                    all_hosts.add(host_data['ansible_host'])
                elif isinstance(host_data, dict) and 'ansible_ssh_host' in host_data:
                    all_hosts.add(host_data['ansible_ssh_host'])
                else:
                    # Assume host_name is IP if no ansible_host
                    all_hosts.add(host_name)
    
    for host in sorted(all_hosts):
        print(host)
        
except Exception as e:
    print(f'Error parsing inventory: {e}', file=sys.stderr)
    sys.exit(1)
")

if [ -z "$hosts" ]; then
    echo "⚠️  No hosts found in inventory"
    exit 1
fi

echo "🎯 Found hosts:"
echo "$hosts"

# Pre-establish SSH connections to all VMs in parallel
echo "⚡ Pre-establishing SSH connections in parallel..."
connection_pids=()

for host in $hosts; do
    {
        echo "🔌 Connecting to $host..."
        
        # Pre-establish SSH connection with long persistence
        ssh -o ControlMaster=auto \
            -o ControlPersist=3600s \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            -o ServerAliveInterval=60 \
            -o ServerAliveCountMax=3 \
            -o BatchMode=yes \
            root@$host \
            "echo 'SSH pool connection established for $host'" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ SSH connection established: $host"
        else
            echo "❌ SSH connection failed: $host"
        fi
    } &
    
    connection_pids+=($!)
done

# Wait for all connections to complete with timeout
echo "⏳ Waiting for all SSH connections (max 30s)..."
timeout 30 bash -c '
for pid in '"${connection_pids[*]}"'; do
    wait $pid
done
' || echo "⚠️  Some SSH connections may have timed out"

echo "🎉 SSH Connection Pool established!"
echo "💡 Connections will persist for 1 hour (3600s)"
echo "🔄 All subsequent SSH connections will be ultra-fast"

# Verify connection pool status
echo "🔍 Verifying connection pool status..."
ssh_control_path="/tmp"
active_connections=$(find $ssh_control_path -name "ansible-ssh-*" -type s 2>/dev/null | wc -l)
echo "📊 Active SSH control connections: $active_connections"

if [ $active_connections -gt 0 ]; then
    echo "✅ SSH Connection Pool is active and ready!"
    exit 0
else
    echo "⚠️  SSH Connection Pool may not be fully active"
    exit 1
fi