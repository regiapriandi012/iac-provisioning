#!/usr/bin/env python3
"""
Wait for VMs to be ready with optimized checking
"""
import json
import sys
import subprocess
import time
import concurrent.futures
from threading import Lock

print_lock = Lock()

def safe_print(message):
    """Thread-safe printing"""
    with print_lock:
        print(message, flush=True)

def check_vm_ready(host_info):
    """Check if a single VM is ready"""
    host, host_vars = host_info
    ip = host_vars.get('ansible_host', '')
    
    if not ip:
        return host, False, "No IP address"
    
    # Quick connectivity test
    cmd = [
        'ansible', host, 
        '-i', '/tmp/k8s-inventory.json',
        '-m', 'ping',
        '--timeout=10',
        '-o'  # one line output
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if result.returncode == 0 and 'SUCCESS' in result.stdout:
            return host, True, "Ready"
        else:
            return host, False, f"Ping failed: {result.stderr.strip()}"
    except subprocess.TimeoutExpired:
        return host, False, "Timeout"
    except Exception as e:
        return host, False, f"Error: {str(e)}"

def wait_for_cluster_ready(inventory_file, max_wait=300, check_interval=10):
    """Wait for all VMs in cluster to be ready"""
    try:
        with open(inventory_file, 'r') as f:
            inv = json.load(f)
        
        # Extract all hosts
        all_hosts = {}
        for group_name, group_data in inv.items():
            if group_name == 'all' or not isinstance(group_data, dict):
                continue
            if 'hosts' in group_data:
                all_hosts.update(group_data['hosts'])
        
        if not all_hosts:
            safe_print("No hosts found in inventory")
            return False
        
        safe_print(f"Waiting for {len(all_hosts)} VMs to be ready...")
        safe_print(f"Hosts: {', '.join(all_hosts.keys())}")
        
        start_time = time.time()
        ready_hosts = set()
        
        while time.time() - start_time < max_wait:
            # Check all hosts in parallel
            with concurrent.futures.ThreadPoolExecutor(max_workers=len(all_hosts)) as executor:
                host_checks = [(host, host_vars) for host, host_vars in all_hosts.items() 
                              if host not in ready_hosts]
                
                if not host_checks:
                    break
                
                future_to_host = {
                    executor.submit(check_vm_ready, host_info): host_info[0] 
                    for host_info in host_checks
                }
                
                for future in concurrent.futures.as_completed(future_to_host):
                    host, is_ready, message = future.result()
                    
                    if is_ready:
                        ready_hosts.add(host)
                        safe_print(f"✓ {host}: {message}")
                    else:
                        safe_print(f"⏳ {host}: {message}")
            
            if len(ready_hosts) == len(all_hosts):
                safe_print(f"\n✅ All {len(all_hosts)} VMs are ready!")
                elapsed = time.time() - start_time
                safe_print(f"Total wait time: {elapsed:.1f} seconds")
                return True
            
            # Wait before next check
            remaining = len(all_hosts) - len(ready_hosts)
            safe_print(f"\n⏳ Waiting for {remaining} more VMs... (sleeping {check_interval}s)")
            time.sleep(check_interval)
        
        # Timeout reached
        safe_print(f"\n❌ Timeout reached after {max_wait} seconds")
        safe_print(f"Ready: {len(ready_hosts)}/{len(all_hosts)}")
        return False
        
    except Exception as e:
        safe_print(f"Error waiting for cluster: {e}")
        return False

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/k8s-inventory.json'
    max_wait = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    
    success = wait_for_cluster_ready(inventory_file, max_wait)
    sys.exit(0 if success else 1)