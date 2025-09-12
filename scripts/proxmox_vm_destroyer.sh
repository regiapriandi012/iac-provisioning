#!/bin/bash
# Direct Proxmox VM Destroyer
# Destroys VMs directly via Proxmox API using VM IDs from terraform state

set -e

echo "🗑️  PROXMOX DIRECT VM DESTROYER"
echo "==============================="

TERRAFORM_DIR=${1:-"terraform"}
WORKSPACE=${WORKSPACE:-"/var/lib/jenkins/workspace/iac-provision"}

# Proxmox API credentials from environment
PROXMOX_URL=${PROXMOX_URL:-$TF_VAR_pm_api_url}
PROXMOX_TOKEN_ID=${PROXMOX_TOKEN_ID:-$TF_VAR_pm_api_token_id} 
PROXMOX_TOKEN_SECRET=${PROXMOX_TOKEN_SECRET:-$TF_VAR_pm_api_token_secret}

echo "📁 Workspace: ${WORKSPACE}"
echo "🏗️  Terraform Dir: ${TERRAFORM_DIR}"
echo "🔗 Proxmox URL: ${PROXMOX_URL}"

cd "${WORKSPACE}/${TERRAFORM_DIR}"

if [ ! -f "terraform.tfstate" ]; then
    echo "⚠️  No terraform state file found - nothing to destroy"
    exit 0
fi

# Extract VM IDs from terraform state
echo "🔍 Extracting VM IDs from terraform state..."

VM_IDS=$(terraform show -json 2>/dev/null | python3 -c "
import json, sys
try:
    state = json.load(sys.stdin)
    vm_ids = []
    
    if 'values' in state and 'root_module' in state['values']:
        resources = state['values']['root_module'].get('resources', [])
        for resource in resources:
            if resource.get('type') == 'proxmox_vm_qemu':
                values = resource.get('values', {})
                vmid = values.get('vmid')
                name = values.get('name', 'unknown')
                if vmid:
                    vm_ids.append(f'{vmid}:{name}')
    
    if vm_ids:
        for vm_id in vm_ids:
            print(vm_id)
    else:
        print('NO_VMS_FOUND')
        
except Exception as e:
    print(f'ERROR_PARSING_STATE', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "ERROR_PARSING_STATE")

if [ "$VM_IDS" = "ERROR_PARSING_STATE" ]; then
    echo "❌ Failed to parse terraform state - falling back to standard destroy"
    terraform destroy -auto-approve -no-color || true
    exit $?
fi

if [ "$VM_IDS" = "NO_VMS_FOUND" ] || [ -z "$VM_IDS" ]; then
    echo "⚠️  No VMs found in terraform state"
    exit 0
fi

echo "🎯 Found VMs to destroy:"
echo "$VM_IDS" | sed 's/^/  - VM ID /' | sed 's/:/ Name: /'

# Validate Proxmox API credentials
if [ -z "$PROXMOX_URL" ] || [ -z "$PROXMOX_TOKEN_ID" ] || [ -z "$PROXMOX_TOKEN_SECRET" ]; then
    echo "⚠️  Missing Proxmox API credentials - falling back to terraform destroy"
    terraform destroy -auto-approve -no-color || true
    exit $?
fi

# Destroy VMs directly via Proxmox API
echo ""
echo "🔥 Destroying VMs via direct Proxmox API calls..."

SUCCESS_COUNT=0
TOTAL_COUNT=0

echo "$VM_IDS" | while IFS=':' read -r vm_id vm_name; do
    if [ -n "$vm_id" ]; then
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
        echo "🗑️  Destroying VM $vm_id ($vm_name)..."
        
        # API call to stop VM first (force)
        curl -s -k -X POST \
            "${PROXMOX_URL}/api2/json/nodes/proxmox/qemu/${vm_id}/status/stop" \
            -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
            -d "forceStop=1" || echo "⚠️  Failed to stop VM $vm_id"
        
        sleep 2
        
        # API call to delete VM
        RESULT=$(curl -s -k -X DELETE \
            "${PROXMOX_URL}/api2/json/nodes/proxmox/qemu/${vm_id}" \
            -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
            -d "destroy-unreferenced-disks=1" \
            -d "purge=1" 2>/dev/null || echo '{"success":false}')
        
        if echo "$RESULT" | grep -q '"success"' || echo "$RESULT" | grep -q '"data"'; then
            echo "✅ Successfully destroyed VM $vm_id ($vm_name)"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "❌ Failed to destroy VM $vm_id ($vm_name): $RESULT"
            
            # Try alternative node names
            for node in thinkcentre orangepi5plus; do
                echo "🔄 Trying alternative node: $node"
                ALT_RESULT=$(curl -s -k -X DELETE \
                    "${PROXMOX_URL}/api2/json/nodes/${node}/qemu/${vm_id}" \
                    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
                    -d "destroy-unreferenced-disks=1" \
                    -d "purge=1" 2>/dev/null || echo '{"success":false}')
                
                if echo "$ALT_RESULT" | grep -q '"success"' || echo "$ALT_RESULT" | grep -q '"data"'; then
                    echo "✅ Successfully destroyed VM $vm_id on node $node"
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                    break
                fi
            done
        fi
        
        sleep 1
    fi
done

# Clean up terraform state regardless of API results
echo ""
echo "🧹 Cleaning up terraform state..."
terraform state list 2>/dev/null | grep -E "proxmox_vm_qemu|random_string" | while read resource; do
    echo "🗑️  Removing from state: $resource"
    terraform state rm "$resource" 2>/dev/null || true
done

# Final verification
REMAINING=$(terraform state list 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo "✅ All terraform resources cleaned up successfully!"
else
    echo "⚠️  $REMAINING terraform resources remaining (may be non-VM resources)"
fi

echo ""
echo "📊 VM Destruction Summary:"
echo "   Total VMs: $TOTAL_COUNT"  
echo "   Destroyed: $SUCCESS_COUNT"
echo "   Failed: $((TOTAL_COUNT - SUCCESS_COUNT))"
echo ""
echo "💡 Verify in Proxmox console that VMs are actually destroyed"
echo "==============================="

exit 0