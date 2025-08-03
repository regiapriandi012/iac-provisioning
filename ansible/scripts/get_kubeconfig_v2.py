#!/usr/bin/env python3
"""
Get KUBECONFIG from first master node using ansible slurp module
"""
import json
import sys
import subprocess
import base64
import os

def get_kubeconfig(inventory_file, output_file=None):
    try:
        # Load inventory
        with open(inventory_file, 'r') as f:
            content = f.read().strip()
            
            # Handle escaped JSON
            if content.startswith('"') and content.endswith('"'):
                content = json.loads(content)
            
            inv = json.loads(content) if isinstance(content, str) else content
            masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
            
            if not masters:
                print("No master nodes found in inventory")
                return False
                
            first_master = masters[0]
            master_ip = inv['k8s_masters']['hosts'][first_master]['ansible_host']
            
            print(f"Retrieving KUBECONFIG from {first_master} ({master_ip})...")
            
            # Set environment for dynamic inventory
            os.environ['ANSIBLE_INVENTORY_FILE'] = inventory_file
            
            # Try different kubeconfig locations
            kubeconfig_paths = [
                '/etc/kubernetes/admin.conf',
                '/root/.kube/config',
                '/etc/kubernetes/super-admin.conf'
            ]
            
            kubeconfig = None
            found_path = None
            
            for kube_path in kubeconfig_paths:
                print(f"Trying {kube_path}...")
                
                # Use ansible slurp module to get file content as base64
                cmd = [
                    'ansible', first_master,
                    '-i', '../inventory.py',
                    '-m', 'slurp',
                    '-a', f'src={kube_path}',
                    '--timeout=30'
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0:
                    try:
                        # Parse ansible JSON output
                        output = result.stdout
                        
                        # Find the JSON part (ansible adds some text before/after)
                        json_start = output.find('{')
                        json_end = output.rfind('}') + 1
                        
                        if json_start >= 0 and json_end > json_start:
                            json_output = output[json_start:json_end]
                            data = json.loads(json_output)
                            
                            if 'content' in data:
                                # Decode base64 content
                                kubeconfig = base64.b64decode(data['content']).decode('utf-8')
                                found_path = kube_path
                                print(f"Successfully retrieved kubeconfig from {kube_path}")
                                break
                    except Exception as e:
                        print(f"Failed to parse output from {kube_path}: {e}")
                        continue
            
            if not kubeconfig:
                print("ERROR: Could not retrieve kubeconfig from any location")
                
                # Last resort: try with fetch module
                print("Trying ansible fetch module as last resort...")
                temp_file = '/tmp/kubeconfig_temp'
                
                cmd = [
                    'ansible', first_master,
                    '-i', '../inventory.py',
                    '-m', 'fetch',
                    '-a', f'src=/etc/kubernetes/admin.conf dest={temp_file} flat=yes',
                    '--timeout=30'
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0 and os.path.exists(temp_file):
                    with open(temp_file, 'r') as f:
                        kubeconfig = f.read()
                    os.remove(temp_file)
                    print("Retrieved kubeconfig using fetch module")
                else:
                    print("Fetch module also failed")
                    return False
            
            # Validate kubeconfig
            if not kubeconfig or 'apiVersion:' not in kubeconfig:
                print("ERROR: Invalid kubeconfig content")
                return False
            
            # Replace localhost/127.0.0.1 with actual master IP
            kubeconfig = kubeconfig.replace('127.0.0.1:6443', f'{master_ip}:6443')
            kubeconfig = kubeconfig.replace('localhost:6443', f'{master_ip}:6443')
            kubeconfig = kubeconfig.replace('https://127.0.0.1:', f'https://{master_ip}:')
            kubeconfig = kubeconfig.replace('https://localhost:', f'https://{master_ip}:')
            
            # Save or print
            if output_file:
                with open(output_file, 'w') as f:
                    f.write(kubeconfig)
                print(f"KUBECONFIG saved to: {output_file}")
                print(f"Config size: {len(kubeconfig)} bytes")
            else:
                print(kubeconfig)
            
            return True
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: get_kubeconfig_v2.py <inventory_file> [output_file]")
        sys.exit(1)
        
    inventory_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    success = get_kubeconfig(inventory_file, output_file)
    sys.exit(0 if success else 1)