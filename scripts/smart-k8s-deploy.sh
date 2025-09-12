#!/bin/bash
# Smart Kubernetes Deployment - Auto-detects template optimization and deploys accordingly
# Skips pre-baked features to maximize speed

set -e

echo "🧠 SMART KUBERNETES DEPLOYMENT"
echo "=============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

# Start deployment timer
DEPLOYMENT_START=$(date +%s)

log "Phase 1: Smart template detection..."

# Configure Ansible
cd ansible
export ANSIBLE_CONFIG=ansible-hyper.cfg
export ANSIBLE_HOST_KEY_CHECKING=False

# Check template optimization levels
ULTRA_COUNT=$(ansible all -i inventory/k8s-inventory.json -m stat -a "path=/etc/kubernetes-ultra-optimized" --one-line 2>/dev/null | grep -c "exists.*true" || echo "0")
TEMPLATE_COUNT=$(ansible all -i inventory/k8s-inventory.json -m stat -a "path=/etc/kubernetes-template-info" --one-line 2>/dev/null | grep -c "exists.*true" || echo "0")
TOTAL_NODES=$(ansible all -i inventory/k8s-inventory.json --list-hosts 2>/dev/null | grep -c "hosts" || echo "1")

log "Template detection results:"
log "  • ULTRA nodes: $ULTRA_COUNT/$TOTAL_NODES"
log "  • Template nodes: $TEMPLATE_COUNT/$TOTAL_NODES"

# Determine deployment strategy
if [ "$ULTRA_COUNT" -eq "$TOTAL_NODES" ] && [ "$ULTRA_COUNT" -gt 0 ]; then
    DEPLOYMENT_MODE="ULTRA"
    TARGET_TIME="25-30s"
    SCRIPT="../scripts/deploy_kubernetes_ultra.sh"
elif [ "$TEMPLATE_COUNT" -eq "$TOTAL_NODES" ] && [ "$TEMPLATE_COUNT" -gt 0 ]; then
    DEPLOYMENT_MODE="TEMPLATE"
    TARGET_TIME="50-60s"
    SCRIPT="../scripts/deploy_kubernetes_template.sh"
else
    DEPLOYMENT_MODE="REGULAR"
    TARGET_TIME="120-180s"
    SCRIPT="../scripts/deploy_kubernetes_parallel.sh"
fi

echo ""
echo -e "${PURPLE}🎯 DEPLOYMENT STRATEGY SELECTED:${NC}"
echo -e "${PURPLE}  Mode: $DEPLOYMENT_MODE${NC}"
echo -e "${PURPLE}  Target: $TARGET_TIME${NC}"
echo -e "${PURPLE}  Benefits: $([ "$DEPLOYMENT_MODE" = "ULTRA" ] && echo "Skip ALL pre-baked features" || [ "$DEPLOYMENT_MODE" = "TEMPLATE" ] && echo "Skip enhancements" || echo "Full installation")${NC}"
echo ""

log "Phase 2: Executing $DEPLOYMENT_MODE deployment..."

# Execute the appropriate deployment script
if [ -f "$SCRIPT" ]; then
    $SCRIPT
else
    # Fallback to direct playbook execution
    case $DEPLOYMENT_MODE in
        "ULTRA")
            ansible-playbook playbooks/ultra-optimized-k8s-deploy.yml -i inventory/k8s-inventory.json --forks=200 --strategy=free
            ;;
        "TEMPLATE")  
            ansible-playbook playbooks/template-optimized-k8s-deploy.yml -i inventory/k8s-inventory.json --forks=100 --strategy=free
            ;;
        "REGULAR")
            ansible-playbook playbooks/k8s-cluster-setup.yml -i inventory/k8s-inventory.json --forks=50
            # Apply enhancements for regular deployments
            ansible-playbook playbooks/k8s-cluster-enhancements.yml -i inventory/k8s-inventory.json --forks=50
            ;;
    esac
fi

DEPLOYMENT_END=$(date +%s)
DURATION=$((DEPLOYMENT_END - DEPLOYMENT_START))

echo ""
echo -e "${PURPLE}======================================${NC}"
echo -e "${PURPLE}🎉 SMART DEPLOYMENT COMPLETE!${NC}"
echo -e "${PURPLE}======================================${NC}"
echo ""

echo "📊 Smart Deployment Results:"
echo "  • Mode: $DEPLOYMENT_MODE"
echo "  • Actual time: ${DURATION}s"
echo "  • Target time: $TARGET_TIME"

# Performance evaluation
if [ "$DEPLOYMENT_MODE" = "ULTRA" ]; then
    if [ $DURATION -le 30 ]; then
        echo "  • Performance: 🔥 ULTRA TARGET ACHIEVED!"
    elif [ $DURATION -le 45 ]; then
        echo "  • Performance: ✅ EXCELLENT!"
    else
        echo "  • Performance: ⚙️ Good (check optimization)"
    fi
elif [ "$DEPLOYMENT_MODE" = "TEMPLATE" ]; then
    if [ $DURATION -le 60 ]; then
        echo "  • Performance: 🔥 TEMPLATE TARGET ACHIEVED!"  
    elif [ $DURATION -le 90 ]; then
        echo "  • Performance: ✅ EXCELLENT!"
    else
        echo "  • Performance: ⚙️ Good"
    fi
else
    if [ $DURATION -le 120 ]; then
        echo "  • Performance: ✅ BETTER THAN BASELINE!"
    elif [ $DURATION -le 180 ]; then
        echo "  • Performance: ⚙️ Baseline achieved"
    else
        echo "  • Performance: ⏳ Slower than expected"
    fi
fi

echo ""
echo "💡 Optimizations Applied:"
case $DEPLOYMENT_MODE in
    "ULTRA")
        echo "  • ZSH & MOTD: SKIPPED (pre-baked in template)"
        echo "  • CLI tools: SKIPPED (pre-installed)"
        echo "  • Container images: SKIPPED (pre-pulled)"
        echo "  • System config: SKIPPED (pre-configured)"
        echo "  • Pure cluster formation only!"
        ;;
    "TEMPLATE")
        echo "  • ZSH & MOTD: SKIPPED (pre-baked in template)"
        echo "  • Enhanced installation speed"
        echo "  • Reduced system preparation time"
        ;;
    "REGULAR")
        echo "  • Full installation with all features"
        echo "  • ZSH & MOTD: APPLIED via enhancements"
        echo "  • Complete system configuration"
        ;;
esac

echo ""
echo "🚀 LABNGOPREK Smart Kubernetes deployment completed!"

log "Smart deployment finished successfully in ${DURATION}s"