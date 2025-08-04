#!/usr/bin/env python3
"""
Ultra-fast VM readiness checker with parallel execution and optimized checks
"""

import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import socket
import subprocess

# Try to import asyncssh, but fall back to sync SSH if not available
try:
    import asyncio
    import asyncssh
    HAS_ASYNCSSH = True
except ImportError:
    HAS_ASYNCSSH = False

class UltraFastVMChecker:
    def __init__(self, inventory_file, max_workers=20):
        self.inventory_file = inventory_file
        self.max_workers = max_workers
        self.results = {}
        
    def load_inventory(self):
        """Load inventory file"""
        with open(self.inventory_file, 'r') as f:
            return json.load(f)
    
    def quick_port_check(self, host, port=22, timeout=2):
        """Ultra-fast TCP port check"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        try:
            result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except:
            return False
    
    def sync_ssh_check(self, host, user="root", password="Passw0rd!", timeout=5):
        """Synchronous SSH connectivity check using sshpass"""
        try:
            # Use sshpass with ssh to check connectivity
            cmd = [
                'sshpass', '-p', password,
                'ssh', '-o', 'StrictHostKeyChecking=no',
                '-o', 'UserKnownHostsFile=/dev/null',
                '-o', 'ConnectTimeout=' + str(timeout),
                '-o', 'BatchMode=yes',
                f'{user}@{host}',
                'echo', 'OK'
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout + 1
            )
            
            return result.returncode == 0 and result.stdout.strip() == "OK"
        except:
            return False
    
    async def async_ssh_check(self, host, user="root", password="Passw0rd!", timeout=5):
        """Async SSH connectivity check"""
        try:
            async with asyncssh.connect(
                host, 
                username=user, 
                password=password,
                known_hosts=None,
                connect_timeout=timeout
            ) as conn:
                # Quick command to verify SSH works
                result = await conn.run('echo "OK"', check=True, timeout=2)
                return result.stdout.strip() == "OK"
        except:
            return False
    
    def check_vm_batch(self, vm_batch):
        """Check a batch of VMs in parallel"""
        batch_results = {}
        
        # First, quick port scan for all VMs
        with ThreadPoolExecutor(max_workers=len(vm_batch)) as executor:
            port_futures = {
                executor.submit(self.quick_port_check, vm_info['ansible_host']): vm_name
                for vm_name, vm_info in vm_batch.items()
            }
            
            for future in as_completed(port_futures, timeout=3):
                vm_name = port_futures[future]
                try:
                    is_open = future.result()
                    batch_results[vm_name] = {'port_22': is_open, 'ssh': False}
                except:
                    batch_results[vm_name] = {'port_22': False, 'ssh': False}
        
        # Then, SSH check only for VMs with open ports
        vms_to_ssh_check = {
            vm: info for vm, info in vm_batch.items() 
            if vm in batch_results and batch_results[vm]['port_22']
        }
        
        if vms_to_ssh_check:
            if HAS_ASYNCSSH:
                # Run async SSH checks
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                ssh_tasks = [
                    self.async_ssh_check(
                        info['ansible_host'],
                        info.get('ansible_user', 'root'),
                        info.get('ansible_ssh_pass', 'Passw0rd!')
                    ) for info in vms_to_ssh_check.values()
                ]
                
                ssh_results = loop.run_until_complete(
                    asyncio.gather(*ssh_tasks, return_exceptions=True)
                )
                loop.close()
                
                for vm_name, ssh_ok in zip(vms_to_ssh_check.keys(), ssh_results):
                    batch_results[vm_name]['ssh'] = ssh_ok is True
            else:
                # Fall back to synchronous SSH checks
                with ThreadPoolExecutor(max_workers=min(len(vms_to_ssh_check), 10)) as executor:
                    ssh_futures = {
                        executor.submit(
                            self.sync_ssh_check,
                            info['ansible_host'],
                            info.get('ansible_user', 'root'),
                            info.get('ansible_ssh_pass', 'Passw0rd!')
                        ): vm_name
                        for vm_name, info in vms_to_ssh_check.items()
                    }
                    
                    for future in as_completed(ssh_futures, timeout=10):
                        vm_name = ssh_futures[future]
                        try:
                            ssh_ok = future.result()
                            batch_results[vm_name]['ssh'] = ssh_ok
                        except:
                            batch_results[vm_name]['ssh'] = False
        
        return batch_results
    
    def run_parallel_checks(self):
        """Run checks in parallel batches"""
        inventory = self.load_inventory()
        
        # Try different inventory structures
        all_hosts = {}
        
        # First try standard structure (all.hosts)
        if 'all' in inventory and 'hosts' in inventory['all']:
            all_hosts.update(inventory['all']['hosts'])
        
        # Also check k8s_masters and k8s_workers
        if 'k8s_masters' in inventory and 'hosts' in inventory['k8s_masters']:
            all_hosts.update(inventory['k8s_masters']['hosts'])
            
        if 'k8s_workers' in inventory and 'hosts' in inventory['k8s_workers']:
            all_hosts.update(inventory['k8s_workers']['hosts'])
        
        
        if not all_hosts:
            print("No hosts found in inventory")
            print("Inventory structure:")
            for key in inventory:
                print(f"  {key}: {type(inventory[key])}")
                if isinstance(inventory[key], dict) and 'hosts' in inventory[key]:
                    print(f"    - has 'hosts' with {len(inventory[key]['hosts'])} entries")
            return False
        
        method = "async SSH (asyncssh)" if HAS_ASYNCSSH else "sync SSH (sshpass)"
        print(f"Ultra-fast checking {len(all_hosts)} VMs with {self.max_workers} workers using {method}...")
        start_time = time.time()
        
        # Split hosts into batches
        batch_size = min(10, len(all_hosts))  # Process 10 VMs at a time
        vm_items = list(all_hosts.items())
        batches = [
            dict(vm_items[i:i + batch_size]) 
            for i in range(0, len(vm_items), batch_size)
        ]
        
        # Process batches in parallel
        with ThreadPoolExecutor(max_workers=max(1, self.max_workers // 10)) as executor:
            batch_futures = {
                executor.submit(self.check_vm_batch, batch): idx
                for idx, batch in enumerate(batches)
            }
            
            for future in as_completed(batch_futures, timeout=30):
                batch_idx = batch_futures[future]
                try:
                    batch_results = future.result()
                    self.results.update(batch_results)
                    
                    # Show progress
                    ready_count = sum(1 for r in self.results.values() if r['ssh'])
                    print(f"  [OK] Batch {batch_idx + 1}/{len(batches)} complete. "
                          f"Ready: {ready_count}/{len(all_hosts)}")
                except Exception as e:
                    print(f"  [FAIL] Batch {batch_idx + 1} failed: {e}")
        
        # Final report
        elapsed = time.time() - start_time
        ready_vms = [vm for vm, status in self.results.items() if status['ssh']]
        not_ready = [vm for vm, status in self.results.items() if not status['ssh']]
        
        print(f"\nCompleted in {elapsed:.1f} seconds")
        print(f"Ready VMs ({len(ready_vms)}/{len(all_hosts)}): {', '.join(ready_vms)}")
        
        if not_ready:
            print(f"Not ready ({len(not_ready)}): {', '.join(not_ready)}")
            
        
        return len(ready_vms) == len(all_hosts)


def main():
    if len(sys.argv) < 2:
        print("Usage: ultra_fast_vm_ready.py <inventory_file> [max_workers]")
        sys.exit(1)
    
    inventory_file = sys.argv[1]
    max_workers = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    
    checker = UltraFastVMChecker(inventory_file, max_workers)
    
    try:
        if checker.run_parallel_checks():
            print("\nAll VMs are ready!")
            sys.exit(0)
        else:
            print("\nWARNING: Some VMs are not ready yet")
            sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()