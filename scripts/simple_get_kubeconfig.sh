#!/bin/bash
# Simple script to get kubeconfig using ansible

set -e

INVENTORY_FILE=$1
OUTPUT_FILE=$2

if [ -z "$INVENTORY_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <inventory_file> <output_file>"
    exit 1
fi

# Get first master from inventory
FIRST_MASTER=$(python3 -c "
import json
with open('$INVENTORY_FILE', 'r') as f:
    content = f.read()
    if content.startswith('\"') and content.endswith('\"'):
        content = json.loads(content)
    inv = json.loads(content) if isinstance(content, str) else content
    masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
    if masters:
        print(masters[0])
")

if [ -z "$FIRST_MASTER" ]; then
    echo "ERROR: No master found in inventory"
    exit 1
fi

echo "Getting kubeconfig from $FIRST_MASTER..."

# Set inventory env var
export ANSIBLE_INVENTORY_FILE="$INVENTORY_FILE"

# Change to ansible directory for inventory.py to work
cd $(dirname $0)/..

# Try to get kubeconfig
echo "Attempting to fetch /etc/kubernetes/admin.conf..."

# Method 1: Direct output with JSON formatting to preserve YAML
ansible $FIRST_MASTER -i ${WORKSPACE}/scripts/inventory.py -m shell \
    -a "cat /etc/kubernetes/admin.conf 2>/dev/null || echo 'FILE_NOT_FOUND'" \
    --timeout=30 -o 2>/dev/null | \
    awk -F' => ' '{print $2}' | \
    python3 -c "
import sys
import json
try:
    data = sys.stdin.read().strip()
    result = json.loads(data)
    if 'stdout' in result:
        print(result['stdout'])
except:
    pass
" > "$OUTPUT_FILE.tmp"

# Check if we got valid content
if grep -q "apiVersion:" "$OUTPUT_FILE.tmp" 2>/dev/null && grep -q "kind: Config" "$OUTPUT_FILE.tmp" 2>/dev/null; then
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    echo "Successfully retrieved kubeconfig"
else
    echo "Failed with method 1, trying kubectl config view..."
    
    # Method 2: kubectl config view
    ansible $FIRST_MASTER -i ${WORKSPACE}/scripts/inventory.py -m shell \
        -a "kubectl config view --raw 2>/dev/null || echo 'KUBECTL_FAILED'" \
        --timeout=30 -o 2>/dev/null | \
        awk -F' => ' '{print $2}' | \
        python3 -c "
import sys
import json
try:
    data = sys.stdin.read().strip()
    result = json.loads(data)
    if 'stdout' in result:
        print(result['stdout'])
except:
    pass
" > "$OUTPUT_FILE.tmp"
    
    if grep -q "kind: Config" "$OUTPUT_FILE.tmp" 2>/dev/null; then
        mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
        echo "Successfully retrieved kubeconfig with kubectl"
    else
        echo "ERROR: Could not retrieve kubeconfig"
        rm -f "$OUTPUT_FILE.tmp"
        exit 1
    fi
fi

# Clean up
rm -f "$OUTPUT_FILE.tmp"

# Replace localhost with actual IP
MASTER_IP=$(python3 -c "
import json
with open('$INVENTORY_FILE', 'r') as f:
    content = f.read()
    if content.startswith('\"') and content.endswith('\"'):
        content = json.loads(content)
    inv = json.loads(content) if isinstance(content, str) else content
    print(inv['k8s_masters']['hosts']['$FIRST_MASTER']['ansible_host'])
")

if [ -n "$MASTER_IP" ]; then
    sed -i "s/127.0.0.1:6443/$MASTER_IP:6443/g" "$OUTPUT_FILE"
    sed -i "s/localhost:6443/$MASTER_IP:6443/g" "$OUTPUT_FILE"
    echo "Replaced localhost with $MASTER_IP"
fi

echo "Kubeconfig saved to $OUTPUT_FILE"
exit 0