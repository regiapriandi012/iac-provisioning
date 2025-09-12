#!/bin/bash
set -e


INVENTORY_FILE="inventory/k8s-inventory.json"
export ANSIBLE_CONFIG="./ansible.cfg"

# Pre-flight checks
if [ ! -f "$INVENTORY_FILE" ]; then
    exit 1
    exit 1
fi

# Check if we have the single playbook or multiple playbooks
if [ -f "playbooks/k8s-cluster-setup.yml" ]; then
    SINGLE_PLAYBOOK=true
else
    SINGLE_PLAYBOOK=false
fi

# Optimize fact gathering
ansible all -i ${WORKSPACE}/scripts/inventory.py -m setup -a "gather_subset=!all,!hardware,network,virtual" --forks 50 &>/dev/null || true

# Main deployment sequence
TOTAL_START=$(date +%s)

if [ "$SINGLE_PLAYBOOK" = "true" ]; then
    # Run the single comprehensive playbook
    START_TIME=$(date +%s)
    
    ansible-playbook \
        -i ${WORKSPACE}/scripts/inventory.py \
        playbooks/k8s-cluster-setup.yml \
        --forks 50 \
        --timeout 30
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
else
    # Original multi-playbook logic (kept for compatibility)
    # Function to run playbook with performance monitoring
    run_playbook() {
        local playbook=$1
        local description=$2
        local extra_args="${3:-}"
        
        START_TIME=$(date +%s)
        
        # Run with optimized settings
        ansible-playbook \
            -i ${WORKSPACE}/scripts/inventory.py \
            playbooks/$playbook \
            --forks 50 \
            --timeout 30 \
            $extra_args
        
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        return 0
    }
    
    # Run playbooks in sequence
    run_playbook "01-common.yml" "Common setup"
    run_playbook "02-kubernetes-prereq.yml" "Kubernetes prerequisites"
    run_playbook "03-kubernetes-install.yml" "Kubernetes installation"
    run_playbook "04-kubernetes-master.yml" "Master node configuration"
    run_playbook "05-kubernetes-workers.yml" "Worker nodes join"
    run_playbook "06-kubernetes-addons.yml" "Kubernetes addons"
    run_playbook "07-docker.yml" "Docker installation"
    run_playbook "08-cilium.yml" "Cilium network plugin"
fi

# Check if using ULTRA templates (skip enhancements if pre-baked)
echo "🔍 Checking for ULTRA template optimization..."
FIRST_NODE=$(python3 ${WORKSPACE}/scripts/get_first_master.py $INVENTORY_FILE 2>/dev/null || echo "")

if [ -n "$FIRST_NODE" ]; then
    ULTRA_CHECK=$(ansible $FIRST_NODE -i ${WORKSPACE}/scripts/inventory.py -m stat -a "path=/etc/kubernetes-ultra-optimized" 2>/dev/null | grep -c "exists.*true" || echo "0")
    
    if [ "$ULTRA_CHECK" -gt 0 ]; then
        echo "✅ ULTRA templates detected - skipping enhancements (already pre-baked)"
        echo "⚡ ZSH, MOTD, and aliases already configured in template"
    else
        # Run cluster enhancements for non-ULTRA templates
        ENHANCEMENT_START=$(date +%s)
        echo "🎨 Applying LABNGOPREK cluster enhancements (regular templates)..."

        ansible-playbook \
            -i ${WORKSPACE}/scripts/inventory.py \
            playbooks/k8s-cluster-enhancements.yml \
            --forks 50 \
            --timeout 30

        ENHANCEMENT_END=$(date +%s)
        ENHANCEMENT_DURATION=$((ENHANCEMENT_END - ENHANCEMENT_START))
        echo "✅ Cluster enhancements completed in ${ENHANCEMENT_DURATION} seconds"
    fi
else
    echo "⚠️  Could not detect template type - skipping enhancements"
fi

# Final verification
FIRST_MASTER=$(python3 ${WORKSPACE}/scripts/get_first_master.py $INVENTORY_FILE)

if [ -n "$FIRST_MASTER" ]; then
    # Quick cluster health check with enhanced features
    echo "🔍 Running enhanced cluster verification..."
    ansible $FIRST_MASTER -i ${WORKSPACE}/scripts/inventory.py -m shell -a "kubectl get nodes -o wide && echo '---' && kubectl get pods -A | grep -v Running | head -20" &>/dev/null || true
    
    # Test new features
    echo "🧪 Testing LABNGOPREK enhancements..."
    ansible $FIRST_MASTER -i ${WORKSPACE}/scripts/inventory.py -m shell -a "echo 'Testing kubectl alias:' && k get nodes --no-headers | wc -l && echo 'Testing metrics server:' && kubectl top nodes" &>/dev/null || echo "Metrics server may still be starting..."
    
    # Get cluster info without jq
    NODE_COUNT=$(ansible $FIRST_MASTER -i ${WORKSPACE}/scripts/inventory.py -m shell -a "kubectl get nodes --no-headers | wc -l" -o | tail -1 | tr -d '\r\n' | grep -o '[0-9]*' || echo "0")
    READY_COUNT=$(ansible $FIRST_MASTER -i ${WORKSPACE}/scripts/inventory.py -m shell -a "kubectl get nodes --no-headers | grep ' Ready' | wc -l" -o | tail -1 | tr -d '\r\n' | grep -o '[0-9]*' || echo "0")
fi

# Calculate total time
TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START))
MINUTES=$((TOTAL_DURATION / 60))
SECONDS=$((TOTAL_DURATION % 60))



exit 0