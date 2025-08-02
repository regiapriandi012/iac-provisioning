#!/bin/bash
set -e

echo "🚀 Starting OPTIMIZED Kubernetes cluster deployment..."
echo "=================================================="

INVENTORY_FILE="inventory/k8s-inventory.json"
export ANSIBLE_CONFIG="./ansible.cfg"

# Function to run playbook with performance monitoring
run_playbook() {
    local playbook=$1
    local description=$2
    local extra_args="${3:-}"
    
    echo ""
    echo "▶️  Running: $description"
    echo "   Playbook: $playbook"
    START_TIME=$(date +%s)
    
    # Run with optimized settings
    ansible-playbook \
        -i inventory.py \
        playbooks/$playbook \
        --forks 50 \
        --timeout 30 \
        $extra_args
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "   ✅ Completed in ${DURATION} seconds"
    
    return 0
}

# Function to run playbooks in parallel where possible
run_parallel_playbooks() {
    echo ""
    echo "🔄 Running parallel playbooks..."
    
    # Run non-dependent playbooks in parallel
    (
        run_playbook "01-common.yml" "Common setup (parallel)" &
        PID1=$!
        
        run_playbook "07-docker.yml" "Docker installation (parallel)" &
        PID2=$!
        
        # Wait for parallel tasks
        wait $PID1 $PID2
    )
}

# Pre-flight checks
echo "🔍 Pre-flight checks..."
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "❌ Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

# Optimize fact gathering
echo "🎯 Pre-gathering facts in parallel..."
ansible all -i inventory.py -m setup -a "gather_subset=!all,!hardware,network,virtual" --forks 50 &>/dev/null || true

# Main deployment sequence
echo ""
echo "📋 Starting deployment sequence..."
TOTAL_START=$(date +%s)

# Phase 1: Parallel preparation
run_parallel_playbooks

# Phase 2: Sequential Kubernetes setup (must be in order)
echo ""
echo "🔧 Kubernetes setup phase..."

# Run critical playbooks in sequence with monitoring
run_playbook "02-kubernetes-prereq.yml" "Kubernetes prerequisites"
run_playbook "03-kubernetes-install.yml" "Kubernetes installation"
run_playbook "04-kubernetes-master.yml" "Master node configuration"
run_playbook "05-kubernetes-workers.yml" "Worker nodes join"

# Phase 3: Parallel post-setup
echo ""
echo "🔌 Running post-setup tasks in parallel..."
(
    run_playbook "06-kubernetes-addons.yml" "Kubernetes addons" &
    PID1=$!
    
    # Network plugin with retry logic
    echo "   Installing Cilium network plugin..."
    ansible-playbook -i inventory.py playbooks/08-cilium.yml --forks 50 || \
    ansible-playbook -i inventory.py playbooks/08-cilium.yml --forks 50 &
    PID2=$!
    
    wait $PID1 $PID2
)

# Final verification
echo ""
echo "✅ Running final verification..."
FIRST_MASTER=$(python3 scripts/get_first_master.py $INVENTORY_FILE)

if [ -n "$FIRST_MASTER" ]; then
    echo "   Checking cluster status on $FIRST_MASTER..."
    
    # Quick cluster health check
    ansible $FIRST_MASTER -i inventory.py -m shell -a "kubectl get nodes -o wide && echo '---' && kubectl get pods -A | grep -v Running | head -20" || true
    
    # Get cluster info
    NODE_COUNT=$(ansible $FIRST_MASTER -i inventory.py -m shell -a "kubectl get nodes -o json | jq '.items | length'" -o | tail -1 | tr -d '\r\n')
    READY_COUNT=$(ansible $FIRST_MASTER -i inventory.py -m shell -a "kubectl get nodes -o json | jq '[.items[] | select(.status.conditions[] | select(.type==\"Ready\" and .status==\"True\"))] | length'" -o | tail -1 | tr -d '\r\n')
    
    echo ""
    echo "📊 Cluster Status:"
    echo "   - Total Nodes: $NODE_COUNT"
    echo "   - Ready Nodes: $READY_COUNT"
fi

# Calculate total time
TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
MINUTES=$((TOTAL_DURATION / 60))
SECONDS=$((TOTAL_DURATION % 60))

echo ""
echo "=================================================="
echo "🎉 Kubernetes cluster deployment completed!"
echo "⏱️  Total time: ${MINUTES}m ${SECONDS}s"
echo ""
echo "📋 Quick commands:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo "   kubectl cluster-info"
echo "=================================================="

# Performance tips
if [ $TOTAL_DURATION -gt 600 ]; then
    echo ""
    echo "💡 Performance tip: Deployment took over 10 minutes."
    echo "   Consider:"
    echo "   - Using pre-pulled Docker images"
    echo "   - Enabling template caching in Proxmox"
    echo "   - Increasing VM resources during provisioning"
fi

exit 0