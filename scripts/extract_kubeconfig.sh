#!/bin/bash
# Extract Kubeconfig Script
# Extracts and validates Kubernetes configuration

set -e

# Ensure we're using venv
. ${WORKSPACE}/venv/bin/activate

# Debug: Check current directory and inventory
echo "Current directory: $(pwd)"
echo "Inventory file: ${INVENTORY_FILE}"
echo "Inventory content (first 10 lines):"
head -10 ${INVENTORY_FILE} || echo "Cannot read inventory"

# Test ansible connectivity first
echo ""
echo "Testing ansible connectivity to masters..."
FIRST_MASTER=$(${WORKSPACE}/venv/bin/python -c "
import json
with open('${INVENTORY_FILE}', 'r') as f:
    inv = json.load(f)
    masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
    if masters:
        print(masters[0])
")

if [ -n "$FIRST_MASTER" ]; then
    echo "First master: $FIRST_MASTER"
    echo "Testing ansible ping..."
    ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m ping --timeout=10 || echo "Ping failed"
    
    echo ""
    echo "Checking if kubeconfig exists on master..."
    ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "ls -la /etc/kubernetes/admin.conf" --timeout=10 || echo "Cannot check file"
fi

# Extract KUBECONFIG
mkdir -p kubeconfig

# Try to get kubeconfig with simple bash script first
echo ""
echo "Attempting to extract kubeconfig..."
if bash ${WORKSPACE}/scripts/simple_get_kubeconfig.sh ${INVENTORY_FILE} kubeconfig/admin.conf; then
    echo "KUBECONFIG extracted successfully with simple bash script"
elif ${WORKSPACE}/venv/bin/python ${WORKSPACE}/scripts/get_kubeconfig_v2.py ${INVENTORY_FILE} kubeconfig/admin.conf; then
    echo "KUBECONFIG extracted successfully with v2 script"
elif ${WORKSPACE}/venv/bin/python ${WORKSPACE}/scripts/get_kubeconfig.py ${INVENTORY_FILE} kubeconfig/admin.conf; then
    echo "KUBECONFIG extracted successfully with v1 script"
    
    # Verify the kubeconfig file
    if [ -f kubeconfig/admin.conf ]; then
        KUBE_SIZE=$(stat -c%s kubeconfig/admin.conf)
        echo "KUBECONFIG file size: $KUBE_SIZE bytes"
        
        if [ $KUBE_SIZE -lt 100 ]; then
            echo "ERROR: KUBECONFIG file is too small, trying direct ansible approach..."
            
            # Fallback: try direct ansible command
            FIRST_MASTER=$(${WORKSPACE}/venv/bin/python -c "
import json
with open('${INVENTORY_FILE}', 'r') as f:
    inv = json.load(f)
    masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
    if masters:
        print(masters[0])
")
            
            if [ -n "$FIRST_MASTER" ]; then
                echo "Trying to fetch kubeconfig directly from $FIRST_MASTER..."
                
                # Method 1: Try direct fetch
                echo "Method 1: Using ansible fetch module..."
                ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m fetch \
                    -a "src=/etc/kubernetes/admin.conf dest=kubeconfig/admin.conf flat=yes" \
                    --timeout=30
                
                # Check if fetch worked
                if [ ! -f kubeconfig/admin.conf ] || [ ! -s kubeconfig/admin.conf ]; then
                    echo "Method 1 failed, trying Method 2..."
                    
                    # Method 2: Use shell to cat the file
                    echo "Method 2: Using ansible shell to cat file..."
                    ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell \
                        -a "cat /etc/kubernetes/admin.conf" --timeout=30 > kubeconfig/admin.conf.tmp
                    
                    # Clean ansible output (remove the first line with hostname and SUCCESS)
                    if [ -f kubeconfig/admin.conf.tmp ]; then
                        grep -A 1000 "apiVersion:" kubeconfig/admin.conf.tmp > kubeconfig/admin.conf || true
                        rm -f kubeconfig/admin.conf.tmp
                    fi
                fi
                
                # If still no luck, try kubectl config view
                if [ ! -f kubeconfig/admin.conf ] || [ ! -s kubeconfig/admin.conf ] || ! grep -q "apiVersion:" kubeconfig/admin.conf; then
                    echo "Method 2 failed, trying Method 3..."
                    echo "Method 3: Using kubectl config view..."
                    
                    ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell \
                        -a "kubectl config view --raw" --timeout=30 > kubeconfig/admin.conf.tmp
                        
                    if [ -f kubeconfig/admin.conf.tmp ]; then
                        grep -A 1000 "apiVersion:" kubeconfig/admin.conf.tmp > kubeconfig/admin.conf || true
                        rm -f kubeconfig/admin.conf.tmp
                    fi
                fi
            fi
        fi
    else
        echo "ERROR: kubeconfig/admin.conf not created!"
    fi
else
    echo "ERROR: Failed to extract KUBECONFIG"
fi

# Final check
if [ -f kubeconfig/admin.conf ] && [ -s kubeconfig/admin.conf ]; then
    echo "KUBECONFIG file exists and has content"
    echo "First 10 lines:"
    head -10 kubeconfig/admin.conf
    echo ""
    
    # Validate YAML structure
    echo "Validating YAML structure..."
    ${WORKSPACE}/venv/bin/python -c "
try:
    import yaml
    with open('kubeconfig/admin.conf', 'r') as f:
        config = yaml.safe_load(f)
    print('YAML validation: PASSED')
    print(f'Config type: {type(config)}')
    print(f'Keys: {list(config.keys()) if isinstance(config, dict) else \"Not a dict\"}')
except ImportError:
    print('YAML validation: SKIPPED - PyYAML not available')
    # Basic validation without PyYAML
    with open('kubeconfig/admin.conf', 'r') as f:
        content = f.read()
        if 'apiVersion:' in content and 'kind:' in content:
            print('Basic validation: PASSED - Contains required YAML keys')
        else:
            print('Basic validation: FAILED - Missing required YAML keys')
except Exception as e:
    print(f'YAML validation: FAILED - {e}')
"
else
    echo "WARNING: No valid KUBECONFIG found!"
    echo "Creating placeholder..."
    echo "# KUBECONFIG could not be retrieved automatically" > kubeconfig/admin.conf
    echo "# Please manually copy from master node: /etc/kubernetes/admin.conf" >> kubeconfig/admin.conf
fi