#!/bin/bash
# Template-Optimized Kubernetes Deployment Script
# Auto-detects template optimization level and skips pre-baked features

set -e

echo "🚀 TEMPLATE-OPTIMIZED KUBERNETES DEPLOYMENT"
echo "==========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Start deployment timer
DEPLOYMENT_START=$(date +%s)

log "Phase 1: Template optimization detection..."

# Check for ULTRA optimization
if ansible all -i inventory/k8s-inventory.json -m stat -a "path=/etc/kubernetes-ultra-optimized" --one-line 2>/dev/null | grep -q "exists.*true"; then
    log "✅ ULTRA templates detected - using ultra-optimized deployment"
    exec ../scripts/deploy_kubernetes_ultra.sh
fi

# Check for basic template optimization
TEMPLATE_CHECK=$(ansible all -i inventory/k8s-inventory.json -m stat -a "path=/etc/kubernetes-template-info" --one-line 2>/dev/null | grep -c "exists.*true" || echo "0")

if [ "$TEMPLATE_CHECK" -gt 0 ]; then
    log "✅ Template optimization detected"
    SKIP_ENHANCEMENTS=true
else
    log "🔧 Regular VMs detected - full installation required"
    SKIP_ENHANCEMENTS=false
fi

log "Phase 2: Template-optimized deployment execution..."

# Configure Ansible for performance
export ANSIBLE_CONFIG=ansible.cfg
export ANSIBLE_HOST_KEY_CHECKING=False

# Execute template-optimized playbook
ansible-playbook \
    playbooks/template-optimized-k8s-deploy.yml \
    -i inventory/k8s-inventory.json \
    --forks=100 \
    --strategy=free \
    -e "kubernetes_version=${KUBERNETES_VERSION:-1.32.7}" \
    -e "cni_type=${CNI_TYPE:-cilium}" \
    -e "cni_version=${CNI_VERSION:-1.16.0}" \
    -e "pod_network_cidr=${POD_NETWORK_CIDR:-10.244.0.0/16}" \
    -e "service_cidr=${SERVICE_CIDR:-10.96.0.0/12}"

# Skip enhancements if using templates (pre-baked)
if [ "$SKIP_ENHANCEMENTS" = "true" ]; then
    log "⚡ Skipping enhancements - already pre-baked in template"
    log "  • ZSH configuration: Ready"
    log "  • MOTD branding: Ready"  
    log "  • kubectl aliases: Ready"
else
    log "Phase 3: Applying enhancements for regular VMs..."
    ansible-playbook \
        playbooks/k8s-cluster-enhancements.yml \
        -i inventory/k8s-inventory.json \
        --forks=50
fi

DEPLOYMENT_END=$(date +%s)
DURATION=$((DEPLOYMENT_END - DEPLOYMENT_START))

echo ""
echo "✅ TEMPLATE-OPTIMIZED DEPLOYMENT COMPLETE!"
echo ""
echo "📊 Performance Results:"
echo "  • Deployment time: ${DURATION}s"
echo "  • Template optimization: $([ "$SKIP_ENHANCEMENTS" = "true" ] && echo "ENABLED" || echo "DISABLED")"
echo "  • Enhancement skip: $([ "$SKIP_ENHANCEMENTS" = "true" ] && echo "YES (pre-baked)" || echo "NO (applied)")"

if [ $DURATION -le 60 ]; then
    echo "  • Performance: 🔥 EXCELLENT!"
elif [ $DURATION -le 90 ]; then
    echo "  • Performance: ✅ GOOD!"
else
    echo "  • Performance: ⚙️ OK"
fi

echo ""
echo "🚀 LABNGOPREK Kubernetes cluster ready!"

log "Template-optimized deployment completed successfully!"