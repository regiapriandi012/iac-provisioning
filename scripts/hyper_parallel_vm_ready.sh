#!/bin/bash
# HYPER-PARALLEL VM Readiness Checker
# Uses multiple parallel strategies for ultra-fast VM readiness detection

set -e

# Smart inventory file detection based on current directory
if [ -f "inventory/k8s-inventory.json" ]; then
    INVENTORY_FILE=${1:-"inventory/k8s-inventory.json"}
elif [ -f "${ANSIBLE_DIR}/inventory/k8s-inventory.json" ]; then
    INVENTORY_FILE=${1:-"${ANSIBLE_DIR}/inventory/k8s-inventory.json"}
else
    INVENTORY_FILE=${1:-"../ansible/inventory/k8s-inventory.json"}
fi

TIMEOUT=${2:-30}
WORKSPACE=${WORKSPACE:-"/var/lib/jenkins/workspace/iac-provision"}

echo "🚀 HYPER-PARALLEL VM Readiness Checker"
echo "📁 Inventory: ${INVENTORY_FILE}"
echo "⏱️  Timeout: ${TIMEOUT}s"

if [ ! -f "${INVENTORY_FILE}" ]; then
    echo "❌ Inventory file not found: ${INVENTORY_FILE}"
    exit 1
fi

# Create temp directory for parallel results
TEMP_DIR="/tmp/hyper_vm_check_$$"
mkdir -p "$TEMP_DIR"

# Define cleanup function first (before any calls to it)
cleanup_and_exit() {
    local exit_code=$1
    
    echo "🧹 Cleaning up parallel processes..."
    
    # Kill all running processes (variables might not be set yet, so ignore errors)
    kill $PID1 $PID2 $PID3 $MONITOR_PID $TIMEOUT_PID 2>/dev/null || true
    
    # Wait a moment for processes to die
    sleep 1
    
    # Force kill if necessary
    kill -9 $PID1 $PID2 $PID3 $MONITOR_PID $TIMEOUT_PID 2>/dev/null || true
    
    # Cleanup temp directory
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    
    if [ $exit_code -eq 0 ]; then
        echo "🎉 HYPER-PARALLEL VM readiness check SUCCEEDED!"
    else
        echo "❌ HYPER-PARALLEL VM readiness check FAILED!"
    fi
    
    exit $exit_code
}

echo "⚡ Launching multiple parallel readiness strategies..."

# Strategy 1: Primary smart checker (most comprehensive)
{
    echo "🔍 Strategy 1: Smart VM checker (comprehensive)"
    if python3 ${WORKSPACE}/scripts/smart_vm_ready.py ${INVENTORY_FILE} ${TIMEOUT}; then
        echo "SUCCESS_STRATEGY1" > "$TEMP_DIR/result_1"
    else
        echo "FAIL_STRATEGY1" > "$TEMP_DIR/result_1"
    fi
} &
PID1=$!

# Strategy 2: Fast checker with reduced timeout (speed optimized)
{
    sleep 2  # Slight delay to avoid resource contention
    echo "⚡ Strategy 2: Speed-optimized checker"
    if timeout $((TIMEOUT / 2)) python3 ${WORKSPACE}/scripts/smart_vm_ready.py ${INVENTORY_FILE} $((TIMEOUT / 2)); then
        echo "SUCCESS_STRATEGY2" > "$TEMP_DIR/result_2"
    else
        echo "FAIL_STRATEGY2" > "$TEMP_DIR/result_2"
    fi
} &
PID2=$!

# Strategy 3: Port-only preliminary check (ultra-fast)
{
    echo "🚀 Strategy 3: Port-only checker (ultra-fast)"
    python3 -c "
import json, socket, sys, threading, time
from concurrent.futures import ThreadPoolExecutor, as_completed

def port_check(host, port=22, timeout=2):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return host, result == 0
    except:
        return host, False

def main():
    try:
        with open('${INVENTORY_FILE}') as f:
            inventory = json.load(f)
        
        hosts = set()
        for group_name, group_data in inventory.items():
            if isinstance(group_data, dict) and 'hosts' in group_data:
                for host_name, host_data in group_data['hosts'].items():
                    if isinstance(host_data, dict) and 'ansible_host' in host_data:
                        hosts.add(host_data['ansible_host'])
                    elif isinstance(host_data, dict) and 'ansible_ssh_host' in host_data:
                        hosts.add(host_data['ansible_ssh_host'])
                    else:
                        hosts.add(host_name)
        
        print(f'Checking {len(hosts)} hosts for port accessibility...')
        
        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = {executor.submit(port_check, host): host for host in hosts}
            
            ready_hosts = []
            failed_hosts = []
            
            for future in as_completed(futures, timeout=${TIMEOUT}):
                host, is_ready = future.result()
                if is_ready:
                    ready_hosts.append(host)
                else:
                    failed_hosts.append(host)
            
            print(f'Ready hosts: {ready_hosts}')
            print(f'Failed hosts: {failed_hosts}')
            
            if len(failed_hosts) == 0:
                print('All hosts are port-accessible!')
                sys.exit(0)
            else:
                print(f'Failed hosts: {failed_hosts}')
                sys.exit(1)
                
    except Exception as e:
        print(f'Port check error: {e}')
        sys.exit(1)

if __name__ == '__main__':
    main()
"
    if [ $? -eq 0 ]; then
        echo "SUCCESS_STRATEGY3" > "$TEMP_DIR/result_3"
    else
        echo "FAIL_STRATEGY3" > "$TEMP_DIR/result_3"
    fi
} &
PID3=$!

echo "🎯 Waiting for first successful strategy to complete..."
echo "   PID1 (Smart): $PID1"
echo "   PID2 (Speed): $PID2" 
echo "   PID3 (Port):  $PID3"

# Wait for any strategy to succeed, with overall timeout
{
    # Monitor results in background
    while [ ! -f "$TEMP_DIR/result_1" ] && [ ! -f "$TEMP_DIR/result_2" ] && [ ! -f "$TEMP_DIR/result_3" ]; do
        sleep 0.5
        
        # Check if any process completed successfully
        if [ -f "$TEMP_DIR/result_1" ]; then
            result1=$(cat "$TEMP_DIR/result_1")
            if [[ "$result1" == "SUCCESS_STRATEGY1" ]]; then
                echo "🎉 Strategy 1 (Smart) succeeded first!"
                cleanup_and_exit 0
            fi
        fi
        
        if [ -f "$TEMP_DIR/result_2" ]; then
            result2=$(cat "$TEMP_DIR/result_2")
            if [[ "$result2" == "SUCCESS_STRATEGY2" ]]; then
                echo "🎉 Strategy 2 (Speed) succeeded first!"
                cleanup_and_exit 0
            fi
        fi
        
        if [ -f "$TEMP_DIR/result_3" ]; then
            result3=$(cat "$TEMP_DIR/result_3")
            if [[ "$result3" == "SUCCESS_STRATEGY3" ]]; then
                echo "🎉 Strategy 3 (Port) succeeded first!"
                cleanup_and_exit 0
            fi
        fi
    done
    
    # If we get here, check final results
    sleep 2
    
    # Check if any strategy ultimately succeeded
    success_found=false
    
    if [ -f "$TEMP_DIR/result_1" ] && grep -q "SUCCESS" "$TEMP_DIR/result_1"; then
        echo "✅ Strategy 1 completed successfully"
        success_found=true
    fi
    
    if [ -f "$TEMP_DIR/result_2" ] && grep -q "SUCCESS" "$TEMP_DIR/result_2"; then
        echo "✅ Strategy 2 completed successfully"
        success_found=true
    fi
    
    if [ -f "$TEMP_DIR/result_3" ] && grep -q "SUCCESS" "$TEMP_DIR/result_3"; then
        echo "✅ Strategy 3 completed successfully"
        success_found=true
    fi
    
    if [ "$success_found" = true ]; then
        cleanup_and_exit 0
    else
        echo "❌ All strategies failed"
        cleanup_and_exit 1
    fi
} &
MONITOR_PID=$!

# Overall timeout handler
{
    sleep $((TIMEOUT + 10))
    echo "⏰ Overall timeout reached"
    cleanup_and_exit 1
} &
TIMEOUT_PID=$!

# Wait for monitor process
wait $MONITOR_PID