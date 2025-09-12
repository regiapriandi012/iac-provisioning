#!/bin/bash
# ULTRA-OPTIMIZED Kubernetes Deployment Script for LABNGOPREK
# Target: 25-30 second deployment time (5-7x faster than regular)

set -e

echo "⚡ LABNGOPREK ULTRA-OPTIMIZED KUBERNETES DEPLOYMENT"
echo "=================================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Start deployment timer
DEPLOYMENT_START=$(date +%s)

log "Phase 1: Pre-deployment validation"

# Verify ULTRA template availability - STRICT MODE (no fallbacks)
if ! ansible all -i inventory/k8s-inventory.json -m stat -a "path=/etc/kubernetes-ultra-optimized" --one-line 2>/dev/null | grep -q "exists.*true"; then
    echo -e "${RED}❌ ULTRA-optimized templates NOT FOUND!${NC}"
    echo "🔧 Required templates:"
    echo "  • t-debian12-ultra-k8s"
    echo "  • t-centos9-ultra-k8s"
    echo ""
    echo "💡 Create templates using:"
    echo "  ./scripts/create-ultra-optimized-k8s-template.sh"
    echo "  ./scripts/create-ultra-optimized-centos9-k8s-template.sh"
    exit 1
fi

log "✅ ULTRA-optimized templates confirmed"

# Configure ULTRA-performance Ansible
export ANSIBLE_CONFIG=ansible-hyper.cfg
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_SSH_PIPELINING=True

log "Phase 2: ULTRA-FAST deployment execution"

# Execute ultra-optimized playbook with maximum speed settings
ansible-playbook \
    playbooks/ultra-optimized-k8s-deploy.yml \
    -i inventory/k8s-inventory.json \
    --forks=200 \
    -e "kubernetes_version=${KUBERNETES_VERSION:-1.32.7}" \
    -e "cni_type=${CNI_TYPE:-cilium}" \
    -e "cni_version=${CNI_VERSION:-1.15.6}" \
    -e "pod_network_cidr=${POD_NETWORK_CIDR:-10.244.0.0/16}" \
    -e "service_cidr=${SERVICE_CIDR:-10.96.0.0/12}"

DEPLOYMENT_END=$(date +%s)
DURATION=$((DEPLOYMENT_END - DEPLOYMENT_START))

echo -e "${PURPLE}"
echo "========================================"
echo "🎉 ULTRA-OPTIMIZED DEPLOYMENT COMPLETE!"
echo "========================================"
echo -e "${NC}"

echo "📊 Performance Results:"
echo "  • Deployment time: ${DURATION}s ($(echo "scale=1; $DURATION/60" | bc 2>/dev/null || echo "~$((DURATION/60))")m)"
echo "  • Target time: 25-30s"
echo "  • Performance: $(if [ $DURATION -le 30 ]; then echo "🔥 ULTRA-FAST!"; elif [ $DURATION -le 50 ]; then echo "✅ EXCELLENT!"; else echo "⚙️ GOOD"; fi)"

if [ $DURATION -le 30 ]; then
    echo "  • Achievement: 🏆 ULTRA target achieved!"
elif [ $DURATION -le 50 ]; then
    echo "  • Achievement: ⚡ Template-level performance"
else
    echo "  • Note: Review optimization settings"
fi

echo ""
echo "🚀 LABNGOPREK Kubernetes cluster ready for workloads!"

log "Phase 3: Cleanup SSH connections"
../scripts/ssh_pool_manager.sh cleanup || true

log "✅ ULTRA-OPTIMIZED deployment completed successfully"