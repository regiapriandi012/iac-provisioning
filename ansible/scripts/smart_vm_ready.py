#!/usr/bin/env python3
"""
Smart and FAST VM readiness check
Replaces the slow netcat-based checking with direct Ansible ping
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

def smart_ssh_check(host_info):
    """Smart SSH check using direct ansible ping - much faster than netcat"""
    host, ip = host_info
    
    # Use ansible ping directly - it's the most reliable SSH test
    cmd = [
        'ansible', host, 
        '-i', 'inventory/k8s-inventory.json',
        '-m', 'ping',
        '--timeout=8',
        '-o'  # one line output
    ]
    
    start_time = time.time()
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=12)
        elapsed = time.time() - start_time
        
        if result.returncode == 0 and 'SUCCESS' in result.stdout:
            return host, ip, True, f"Ready in {elapsed:.1f}s"
        else:
            error_msg = result.stderr.strip() if result.stderr else "Connection failed"
            return host, ip, False, f"Failed in {elapsed:.1f}s: {error_msg[:50]}"
    except subprocess.TimeoutExpired:
        elapsed = time.time() - start_time
        return host, ip, False, f"Timeout after {elapsed:.1f}s"
    except Exception as e:
        elapsed = time.time() - start_time
        return host, ip, False, f"Error in {elapsed:.1f}s: {str(e)[:50]}"

def fast_vm_readiness_check(inventory_file, max_retries=3, retry_delay=15):
    """Fast VM readiness check with smart retry logic"""
    try:
        with open(inventory_file, 'r') as f:
            content = f.read().strip()
            
            # Handle case where terraform output is JSON string (escaped)
            if content.startswith('"') and content.endswith('"'):
                # Remove quotes and unescape
                content = json.loads(content)
            
            # Parse the actual JSON
            if isinstance(content, str):
                inv = json.loads(content)
            else:
                inv = content
        
        # Extract all hosts and IPs
        hosts_to_check = []
        for group_name, group_data in inv.items():
            if group_name in ['all', '_meta'] or not isinstance(group_data, dict):
                continue
            if 'hosts' in group_data:
                for host, host_vars in group_data['hosts'].items():
                    if 'ansible_host' in host_vars:
                        hosts_to_check.append((host, host_vars['ansible_host']))
        
        if not hosts_to_check:
            safe_print("ERROR: No hosts found in inventory")
            return False
        
        safe_print(f"Smart VM Readiness Check")
        safe_print(f"Checking {len(hosts_to_check)} VMs: {', '.join([f'{h}({ip})' for h, ip in hosts_to_check])}")
        safe_print("")
        
        for attempt in range(1, max_retries + 1):
            safe_print(f"Attempt {attempt}/{max_retries}")
            start_time = time.time()
            
            # Check all hosts in parallel - MUCH faster
            with concurrent.futures.ThreadPoolExecutor(max_workers=len(hosts_to_check)) as executor:
                future_to_host = {
                    executor.submit(smart_ssh_check, host_info): host_info 
                    for host_info in hosts_to_check
                }
                
                ready_hosts = []
                failed_hosts = []
                
                for future in concurrent.futures.as_completed(future_to_host):
                    host, ip, is_ready, message = future.result()
                    
                    if is_ready:
                        ready_hosts.append((host, ip))
                        safe_print(f"OK {host} ({ip}): {message}")
                    else:
                        failed_hosts.append((host, ip))
                        safe_print(f"FAIL {host} ({ip}): {message}")
            
            elapsed = time.time() - start_time
            safe_print(f"Parallel check completed in {elapsed:.1f}s")
            
            if len(ready_hosts) == len(hosts_to_check):
                safe_print(f"\nAll {len(hosts_to_check)} VMs are ready!")
                safe_print(f"Total time: {elapsed:.1f}s (attempt {attempt})")
                return True
            
            if attempt < max_retries:
                safe_print(f"\n{len(failed_hosts)} VMs not ready. Retrying in {retry_delay}s...")
                # Only update the list to check failed hosts
                hosts_to_check = failed_hosts
                time.sleep(retry_delay)
            else:
                safe_print(f"\nTimeout: {len(ready_hosts)}/{len(hosts_to_check) + len(ready_hosts)} VMs ready")
                return False
        
        return False
        
    except Exception as e:
        safe_print(f"ERROR: Error during readiness check: {e}")
        return False

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else 'inventory/k8s-inventory.json'
    max_retries = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    
    success = fast_vm_readiness_check(inventory_file, max_retries)
    
    if success:
        print("\nSUCCESS: ALL VMs are ready for Ansible operations!")
        sys.exit(0)
    else:
        print("\nFAILED: Some VMs are not ready. Check the logs above.")
        sys.exit(1)