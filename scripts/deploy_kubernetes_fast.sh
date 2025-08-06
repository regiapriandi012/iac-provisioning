#!/bin/bash
# Fast Kubernetes Deployment Script
# Uses pre-configured templates for 5-10x faster deployment

set -e

# Ensure we're using venv
. ${WORKSPACE}/venv/bin/activate

echo "⚡ Fast Kubernetes Deployment Starting"
echo "====================================="

# Configuration
PLAYBOOK="k8s-cluster-setup-fast.yml"
INVENTORY_FILE="inventory/k8s-inventory.json"
INVENTORY_SCRIPT="../scripts/inventory.py"

# Load environment configuration
if [ -f "../config/environment.conf" ]; then
    source ../config/environment.conf
fi

# Check if fast deployment is enabled
FAST_DEPLOYMENT=${FAST_DEPLOYMENT:-false}
if [ "$FAST_DEPLOYMENT" != "true" ]; then
    echo "⚠️  Fast deployment not enabled in config/environment.conf"
    echo "   Set FAST_DEPLOYMENT=true to use this script"
    echo "   Falling back to standard deployment..."
    exec ./deploy_kubernetes.sh
fi

# Check if inventory exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "❌ Inventory file not found: $INVENTORY_FILE"
    echo "   Run terraform first to generate inventory"
    exit 1
fi

# Check if VMs are using pre-configured templates
echo "🔍 Verifying template configuration..."

FIRST_MASTER=$(${WORKSPACE}/venv/bin/python -c "
import json
with open('${INVENTORY_FILE}', 'r') as f:
    inv = json.load(f)
    masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
    if masters:
        print(masters[0])
")

if [ -n "$FIRST_MASTER" ]; then
    echo "   Testing connection to $FIRST_MASTER..."
    
    # Test if template is properly configured
    if ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "test -f /opt/k8s-template-info.txt" --timeout=30; then
        echo "✅ Pre-configured Kubernetes template detected"
        
        # Show template info
        echo "📋 Template Information:"
        ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "head -10 /opt/k8s-template-info.txt" --timeout=10 | grep -A 20 "CHANGED"
    else
        echo "❌ VMs are not using pre-configured Kubernetes templates!"
        echo ""
        echo "🔧 To use fast deployment, you need to:"
        echo "   1. Create pre-configured templates using:"
        echo "      - prepare-debian-k8s-template.sh"
        echo "      - prepare-centos-k8s-template.sh"
        echo "   2. Update vms.csv to use template names like:"
        echo "      - debian12-k8s-template"
        echo "      - centos9-k8s-template"
        echo "   3. Re-run terraform to provision VMs from templates"
        echo ""
        echo "📚 See: template-preparation/README-TEMPLATE-CREATION.md"
        echo ""
        echo "⏳ Falling back to standard deployment (slower)..."
        exec ./deploy_kubernetes.sh
    fi
else
    echo "❌ No master nodes found in inventory"
    exit 1
fi

echo ""
echo "🚀 Starting fast Kubernetes cluster setup..."
echo "   Playbook: $PLAYBOOK"
echo "   Expected time: 3-5 minutes (vs 15-25 minutes traditional)"
echo ""

# Record start time
START_TIME=$(date +%s)

# Run the fast playbook
if python3 ${WORKSPACE}/scripts/generate_inventory_with_cni.py ${WORKSPACE}/terraform/vms.csv inventory/k8s-inventory.json; then
    echo "✅ Inventory generated successfully"
else
    echo "❌ Failed to generate inventory"
    exit 1
fi

# Set parallel execution for faster deployment
export ANSIBLE_FORKS=${ANSIBLE_FORKS:-10}
export ANSIBLE_HOST_KEY_CHECKING=False

# Run the playbook with optimizations for speed
ansible-playbook \
    -i ${INVENTORY_SCRIPT} \
    playbooks/${PLAYBOOK} \
    --timeout=300 \
    --ssh-extra-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30' \
    -v

# Record end time and calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "🎉 Fast Kubernetes Deployment Complete!"
echo "======================================"
echo "⏱️  Total deployment time: ${MINUTES}m ${SECONDS}s"
echo ""

# Show cluster status
echo "📊 Cluster Status:"
if [ -n "$FIRST_MASTER" ]; then
    echo "   Getting cluster info..."
    ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "kubectl cluster-info" --timeout=30 | grep -A 10 "CHANGED" || true
    
    echo "   Getting node status..."
    ansible $FIRST_MASTER -i ${INVENTORY_SCRIPT} -m shell -a "kubectl get nodes -o wide" --timeout=30 | grep -A 20 "CHANGED" || true
fi

echo ""
echo "⚡ Performance Benefits:"
echo "   🚀 5-8x faster than traditional deployment"
echo "   📦 No package installation time"
echo "   🌐 CNI manifests pre-cached"
echo "   🔄 Multiple K8s versions ready"
echo ""
echo "🔗 Next steps:"
echo "   - Extract kubeconfig: ./extract_kubeconfig.sh"
echo "   - Access cluster: kubectl get pods --all-namespaces"
echo "   - Deploy applications!"

# Exit with success
exit 0