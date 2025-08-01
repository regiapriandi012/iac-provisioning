#!/bin/bash
#
# Debug connectivity issues with inventory
#

INVENTORY_FILE="${1:-/tmp/k8s-inventory.json}"

echo "=== Debugging Ansible Connectivity ==="
echo "Inventory file: $INVENTORY_FILE"
echo

if [[ ! -f "$INVENTORY_FILE" ]]; then
    echo "ERROR: Inventory file not found!"
    exit 1
fi

echo "=== Inventory Content ==="
cat "$INVENTORY_FILE"
echo

echo "=== Parsed Inventory ==="
ansible-inventory -i "$INVENTORY_FILE" --list
echo

echo "=== Host Variables ==="
ansible-inventory -i "$INVENTORY_FILE" --host kube-master 2>/dev/null || echo "No kube-master found"
echo

echo "=== Testing Raw SSH Connections ==="
python3 -c "
import json
with open('$INVENTORY_FILE', 'r') as f:
    inv = json.load(f)
    for host, vars in inv.get('_meta', {}).get('hostvars', {}).items():
        ip = vars.get('ansible_host', 'unknown')
        print(f'Testing SSH to {host} ({ip})...')
        import subprocess
        result = subprocess.run(['ssh', '-o', 'ConnectTimeout=5', '-o', 'StrictHostKeyChecking=no', 
                               '-o', 'UserKnownHostsFile=/dev/null', 'root@' + ip, 'echo SSH_OK'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f'  SUCCESS: {host} is reachable')
        else:
            print(f'  FAILED: {host} - {result.stderr.strip()}')
        print()
"

echo "=== Testing Ansible Ping ==="
ansible all -i "$INVENTORY_FILE" -m ping -o \
    -e ansible_ssh_common_args="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"