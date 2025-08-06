#!/bin/bash
# Kubernetes Deployment Benchmark Script
# Compares parallel vs standard deployment performance

set -e

echo "⚡ KUBERNETES DEPLOYMENT BENCHMARK"
echo "=================================="

# Configuration
BENCHMARK_RESULTS="/tmp/k8s-deployment-benchmark.txt"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Load environment configuration
if [ -f "../config/environment.conf" ]; then
    source ../config/environment.conf
fi

echo "Benchmark started at: $TIMESTAMP" > $BENCHMARK_RESULTS
echo "========================================" >> $BENCHMARK_RESULTS

# Check if we can run both tests
if [ ! -f "deploy_kubernetes_parallel.sh" ]; then
    echo "❌ Parallel deployment script not found!"
    echo "Please ensure deploy_kubernetes_parallel.sh exists"
    exit 1
fi

# Function to clean up cluster between tests
cleanup_cluster() {
    echo "🧹 Cleaning up existing cluster..."
    
    # Try to drain and delete nodes
    FIRST_MASTER=$(${WORKSPACE}/venv/bin/python -c "
    import json
    try:
        with open('inventory/k8s-inventory.json', 'r') as f:
            inv = json.load(f)
            masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys()))
            if masters:
                print(masters[0])
    except:
        pass
    " 2>/dev/null || echo "")
    
    if [ -n "$FIRST_MASTER" ]; then
        # Reset cluster
        ansible all -i ../scripts/inventory.py -m shell -a "kubeadm reset --force" --timeout=60 || true
        ansible all -i ../scripts/inventory.py -m shell -a "rm -rf /etc/kubernetes" --timeout=30 || true
        ansible all -i ../scripts/inventory.py -m shell -a "rm -rf ~/.kube" --timeout=30 || true
    fi
    
    echo "✅ Cleanup completed"
    sleep 10
}

# Function to verify cluster is working
verify_cluster() {
    local deployment_type="$1"
    echo "🔍 Verifying $deployment_type cluster..."
    
    FIRST_MASTER=$(${WORKSPACE}/venv/bin/python -c "
    import json
    try:
        with open('inventory/k8s-inventory.json', 'r') as f:
            inv = json.load(f)
            masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys()))
            if masters:
                print(masters[0])
    except:
        pass
    " 2>/dev/null || echo "")
    
    if [ -n "$FIRST_MASTER" ]; then
        # Check if all nodes are ready
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            local ready_nodes=$(ansible $FIRST_MASTER -i ../scripts/inventory.py -m shell -a "kubectl get nodes --no-headers | grep Ready | wc -l" --timeout=30 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")
            local total_nodes=$(ansible $FIRST_MASTER -i ../scripts/inventory.py -m shell -a "kubectl get nodes --no-headers | wc -l" --timeout=30 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")
            
            if [ "$ready_nodes" -gt 0 ] && [ "$ready_nodes" -eq "$total_nodes" ]; then
                echo "✅ All $ready_nodes nodes are ready"
                return 0
            fi
            
            echo "   Attempt $attempt/$max_attempts: $ready_nodes/$total_nodes nodes ready..."
            sleep 10
            ((attempt++))
        done
        
        echo "❌ Cluster verification failed for $deployment_type"
        return 1
    else
        echo "❌ No master node found for verification"
        return 1
    fi
}

# Test 1: Standard Deployment
echo ""
echo "📊 TEST 1: STANDARD DEPLOYMENT"
echo "=============================="

# Ensure parallel deployment is disabled
export PARALLEL_DEPLOYMENT=false

STANDARD_START=$(date +%s)
echo "Standard deployment started at: $(date)" >> $BENCHMARK_RESULTS

if timeout 1800 ./deploy_kubernetes.sh; then
    STANDARD_END=$(date +%s)
    STANDARD_DURATION=$((STANDARD_END - STANDARD_START))
    STANDARD_MINUTES=$((STANDARD_DURATION / 60))
    STANDARD_SECONDS=$((STANDARD_DURATION % 60))
    
    echo "✅ Standard deployment completed in ${STANDARD_MINUTES}m ${STANDARD_SECONDS}s"
    echo "Standard deployment duration: ${STANDARD_DURATION}s (${STANDARD_MINUTES}m ${STANDARD_SECONDS}s)" >> $BENCHMARK_RESULTS
    
    if verify_cluster "standard"; then
        echo "✅ Standard deployment verification passed"
        echo "Standard deployment verification: PASSED" >> $BENCHMARK_RESULTS
    else
        echo "❌ Standard deployment verification failed"
        echo "Standard deployment verification: FAILED" >> $BENCHMARK_RESULTS
    fi
else
    echo "❌ Standard deployment failed or timed out"
    echo "Standard deployment: FAILED/TIMEOUT" >> $BENCHMARK_RESULTS
    STANDARD_DURATION=1800  # Timeout duration
fi

# Clean up between tests
cleanup_cluster

echo ""
echo "⏳ Waiting 30 seconds before next test..."
sleep 30

# Test 2: Parallel Deployment
echo ""
echo "📊 TEST 2: PARALLEL DEPLOYMENT"
echo "==============================="

PARALLEL_START=$(date +%s)
echo "Parallel deployment started at: $(date)" >> $BENCHMARK_RESULTS

if timeout 1800 ./deploy_kubernetes_parallel.sh; then
    PARALLEL_END=$(date +%s)
    PARALLEL_DURATION=$((PARALLEL_END - PARALLEL_START))
    PARALLEL_MINUTES=$((PARALLEL_DURATION / 60))
    PARALLEL_SECONDS=$((PARALLEL_DURATION % 60))
    
    echo "✅ Parallel deployment completed in ${PARALLEL_MINUTES}m ${PARALLEL_SECONDS}s"
    echo "Parallel deployment duration: ${PARALLEL_DURATION}s (${PARALLEL_MINUTES}m ${PARALLEL_SECONDS}s)" >> $BENCHMARK_RESULTS
    
    if verify_cluster "parallel"; then
        echo "✅ Parallel deployment verification passed"
        echo "Parallel deployment verification: PASSED" >> $BENCHMARK_RESULTS
    else
        echo "❌ Parallel deployment verification failed"
        echo "Parallel deployment verification: FAILED" >> $BENCHMARK_RESULTS
    fi
else
    echo "❌ Parallel deployment failed or timed out"
    echo "Parallel deployment: FAILED/TIMEOUT" >> $BENCHMARK_RESULTS
    PARALLEL_DURATION=1800  # Timeout duration
fi

# Calculate results
echo ""
echo "🏆 BENCHMARK RESULTS"
echo "==================="

if [ $STANDARD_DURATION -gt 0 ] && [ $PARALLEL_DURATION -gt 0 ]; then
    SPEEDUP=$(echo "scale=2; $STANDARD_DURATION / $PARALLEL_DURATION" | bc -l)
    TIME_SAVED=$((STANDARD_DURATION - PARALLEL_DURATION))
    TIME_SAVED_MINUTES=$((TIME_SAVED / 60))
    TIME_SAVED_SECONDS=$((TIME_SAVED % 60))
    
    echo "Standard Deployment: ${STANDARD_MINUTES}m ${STANDARD_SECONDS}s"
    echo "Parallel Deployment: ${PARALLEL_MINUTES}m ${PARALLEL_SECONDS}s"
    echo "Time Saved: ${TIME_SAVED_MINUTES}m ${TIME_SAVED_SECONDS}s"
    echo "Speedup: ${SPEEDUP}x faster"
    
    # Add to results file
    echo "" >> $BENCHMARK_RESULTS
    echo "FINAL RESULTS:" >> $BENCHMARK_RESULTS
    echo "=============" >> $BENCHMARK_RESULTS
    echo "Standard Deployment: ${STANDARD_DURATION}s (${STANDARD_MINUTES}m ${STANDARD_SECONDS}s)" >> $BENCHMARK_RESULTS
    echo "Parallel Deployment: ${PARALLEL_DURATION}s (${PARALLEL_MINUTES}m ${PARALLEL_SECONDS}s)" >> $BENCHMARK_RESULTS
    echo "Time Saved: ${TIME_SAVED}s (${TIME_SAVED_MINUTES}m ${TIME_SAVED_SECONDS}s)" >> $BENCHMARK_RESULTS
    echo "Speedup: ${SPEEDUP}x faster" >> $BENCHMARK_RESULTS
    
    # Performance rating
    if (( $(echo "$SPEEDUP >= 5.0" | bc -l) )); then
        RATING="🚀 EXCELLENT (5x+ speedup)"
    elif (( $(echo "$SPEEDUP >= 3.0" | bc -l) )); then
        RATING="⚡ GREAT (3-5x speedup)"
    elif (( $(echo "$SPEEDUP >= 2.0" | bc -l) )); then
        RATING="✅ GOOD (2-3x speedup)"
    else
        RATING="📈 MODERATE (less than 2x speedup)"
    fi
    
    echo "Performance Rating: $RATING"
    echo "Performance Rating: $RATING" >> $BENCHMARK_RESULTS
    
else
    echo "❌ Unable to calculate speedup due to failed deployments"
    echo "Unable to calculate speedup due to failed deployments" >> $BENCHMARK_RESULTS
fi

echo ""
echo "📄 Full results saved to: $BENCHMARK_RESULTS"
echo ""
echo "🎯 RECOMMENDATION:"
if [ $PARALLEL_DURATION -lt $STANDARD_DURATION ]; then
    echo "   Enable parallel deployment in config/environment.conf:"
    echo "   Set PARALLEL_DEPLOYMENT=true"
else
    echo "   Use standard deployment for stability"
fi

echo ""
echo "Benchmark completed at: $(date)" >> $BENCHMARK_RESULTS

# Show results file
echo "📊 BENCHMARK SUMMARY:"
echo "===================="
cat $BENCHMARK_RESULTS