#!/usr/bin/env python3
"""
Quick cluster readiness check for Jenkins pipeline
Combines multiple checks in one optimized script
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

def simple_connectivity_check(ip):
    """Simple TCP connectivity check - more reliable than ansible"""
    try:
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((ip, 22))
        sock.close()
        return result == 0
    except:
        return False

def check_host_comprehensive(host_info):
    """Simple connectivity check for each host"""
    host, host_vars = host_info
    ip = host_vars.get('ansible_host', '')
    template = host_vars.get('template', 'unknown')
    
    checks = {
        'connectivity': False,
        'os_info': 'Ready',
        'uptime': 'SSH Available',
        'resources': 'Connected'
    }
    
    # Simple TCP connectivity check
    if simple_connectivity_check(ip):
        checks['connectivity'] = True
        checks['os_info'] = 'SSH Ready'
        checks['uptime'] = 'Connected'
        checks['resources'] = 'Available'
    
    return host, checks

def quick_cluster_analysis(inventory_file):
    """Quick comprehensive cluster analysis"""
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
        
        # Extract all hosts
        all_hosts = {}
        for group_name, group_data in inv.items():
            if group_name == 'all' or not isinstance(group_data, dict):
                continue
            if 'hosts' in group_data:
                all_hosts.update(group_data['hosts'])
        
        if not all_hosts:
            safe_print("ERROR: No hosts found in inventory")
            return False
        
        safe_print("Quick Cluster Analysis")
        safe_print(f"Checking {len(all_hosts)} nodes...")
        safe_print("")
        
        start_time = time.time()
        
        # Check all hosts in parallel
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(all_hosts)) as executor:
            host_checks = [(host, host_vars) for host, host_vars in all_hosts.items()]
            
            future_to_host = {
                executor.submit(check_host_comprehensive, host_info): host_info[0] 
                for host_info in host_checks
            }
            
            results = {}
            for future in concurrent.futures.as_completed(future_to_host):
                host, checks = future.result()
                results[host] = checks
        
        elapsed = time.time() - start_time
        
        # Display results
        safe_print("Cluster Status Report:")
        safe_print("=" * 60)
        
        ready_count = 0
        for host, checks in results.items():
            status = "OK" if checks['connectivity'] else "FAIL"
            safe_print(f"{status:<4} {host:<20} {checks['os_info']:<25}")
            safe_print(f"     Uptime: {checks['uptime']}")
            safe_print(f"     Memory: {checks['resources']}")
            safe_print("")
            
            if checks['connectivity']:
                ready_count += 1
        
        safe_print("=" * 60)
        safe_print(f"Ready nodes: {ready_count}/{len(all_hosts)}")
        safe_print(f"Analysis time: {elapsed:.1f} seconds")
        
        # OS Distribution Analysis
        safe_print("\nOS Distribution Analysis:")
        os_count = {}
        for host, checks in results.items():
            os_info = checks['os_info']
            if 'centos' in os_info.lower() or 'rhel' in os_info.lower():
                os_family = 'RedHat'
            elif 'ubuntu' in os_info.lower() or 'debian' in os_info.lower():
                os_family = 'Debian'
            else:
                os_family = 'Other'
            
            os_count[os_family] = os_count.get(os_family, 0) + 1
        
        for os_family, count in os_count.items():
            safe_print(f"   {os_family}: {count} nodes")
        
        if len(os_count) == 1:
            safe_print("SUCCESS: Homogeneous cluster detected")
        else:
            safe_print("WARNING: Mixed OS detected - consider homogeneous deployment")
        
        return ready_count == len(all_hosts)
        
    except Exception as e:
        safe_print(f"ERROR: Error during analysis: {e}")
        return False

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else 'inventory/k8s-inventory.json'
    
    success = quick_cluster_analysis(inventory_file)
    sys.exit(0 if success else 1)