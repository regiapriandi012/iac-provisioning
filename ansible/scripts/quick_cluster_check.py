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

def run_ansible_command(host, module, args="", timeout=30):
    """Run ansible command with timeout"""
    cmd = [
        'ansible', host,
        '-i', '/tmp/k8s-inventory.json',
        '-m', module,
        f'--timeout={timeout}',
        '-o'
    ]
    
    if args:
        cmd.extend(['-a', args])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout+5)
        return result.returncode == 0, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "", "Command timeout"
    except Exception as e:
        return False, "", str(e)

def check_host_comprehensive(host_info):
    """Comprehensive check of a single host"""
    host, host_vars = host_info
    ip = host_vars.get('ansible_host', '')
    template = host_vars.get('template', 'unknown')
    
    checks = {
        'connectivity': False,
        'os_info': 'Unknown',
        'uptime': 'Unknown',
        'resources': 'Unknown'
    }
    
    # 1. Basic connectivity
    success, stdout, stderr = run_ansible_command(host, 'ping')
    if success and 'SUCCESS' in stdout:
        checks['connectivity'] = True
    else:
        return host, checks
    
    # 2. Get OS info and uptime in one command
    success, stdout, stderr = run_ansible_command(
        host, 'shell', 
        'cat /etc/os-release | head -2; uptime; free -h | head -2'
    )
    if success:
        lines = stdout.split('\n')
        if len(lines) >= 2:
            # Parse OS info
            for line in lines[:3]:
                if 'PRETTY_NAME' in line:
                    checks['os_info'] = line.split('=')[1].strip('"')
                    break
                elif 'ID=' in line and not line.startswith('ID_LIKE'):
                    checks['os_info'] = line.split('=')[1].strip('"')
            
            # Parse uptime
            for line in lines:
                if 'up' in line and ('day' in line or 'min' in line or ':' in line):
                    checks['uptime'] = line.strip()
                    break
            
            # Parse memory
            for line in lines:
                if 'Mem:' in line:
                    checks['resources'] = line.strip()
                    break
    
    return host, checks

def quick_cluster_analysis(inventory_file):
    """Quick comprehensive cluster analysis"""
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