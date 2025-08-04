#!/usr/bin/env python3
"""
Get KUBECONFIG from first master node
"""
import json
import sys
import subprocess

def get_kubeconfig(inventory_file, output_file=None):
    import os
    inventory_script = os.path.join(os.environ.get('WORKSPACE', '/root/coder/iac-provision'), 'scripts', 'inventory.py')
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
            masters = list(inv.get('k8s_masters', {}).get('hosts', {}).keys())
            
            if not masters:
                print("No master nodes found in inventory")
                return False
                
            first_master = masters[0]
            master_ip = inv['k8s_masters']['hosts'][first_master]['ansible_host']
            
            print(f"Retrieving KUBECONFIG from {first_master} ({master_ip})...")
            
            # Use ansible to get the kubeconfig content
            # Set environment variable for dynamic inventory
            import os
            os.environ['ANSIBLE_INVENTORY_FILE'] = inventory_file
            
            # Try multiple possible locations for kubeconfig
            kubeconfig_locations = [
                '/etc/kubernetes/admin.conf',  # Default location for kubeadm
                '/root/.kube/config',           # Root user config
                '/home/ubuntu/.kube/config',    # Ubuntu user
                '/etc/kubernetes/super-admin.conf'  # New kubeadm location
            ]
            
            config_found = False
            kubeconfig = None
            
            for config_path in kubeconfig_locations:
                print(f"Checking {config_path}...")
                
                # First check if file exists
                check_cmd = [
                    'ansible', first_master, 
                    '-i', inventory_script,
                    '-m', 'shell',
                    '-a', f'test -f {config_path} && echo "FILE_EXISTS"',
                    '--timeout=30'
                ]
                
                check_result = subprocess.run(check_cmd, capture_output=True, text=True)
                
                if check_result.returncode == 0 and 'FILE_EXISTS' in check_result.stdout:
                    print(f"File exists at {config_path}, retrieving content...")
                    
                    # Now get the content
                    cmd = [
                        'ansible', first_master, 
                        '-i', inventory_script,
                        '-m', 'shell',
                        '-a', f'cat {config_path}',
                        '--timeout=30'
                    ]
                    
                    result = subprocess.run(cmd, capture_output=True, text=True)
                    
                    if result.returncode == 0:
                        print(f"Successfully retrieved content from {config_path}")
                        config_found = True
                        break
                    else:
                        print(f"Failed to cat {config_path}: {result.stderr}")
                else:
                    print(f"File not found at {config_path}")
            
            if not config_found:
                # If no config found, generate one from the cluster
                print("No existing kubeconfig found, generating from cluster...")
                cmd = [
                    'ansible', first_master,
                    '-i', inventory_script, 
                    '-m', 'shell',
                    '-a', 'kubectl config view --raw',
                    '--timeout=30'
                ]
                result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0 or 'apiVersion:' not in result.stdout:
                print(f"Failed to retrieve KUBECONFIG: {result.stderr}")
                print("Stdout:", result.stdout[:200])
                return False
                
            # Extract the config content from ansible output
            # Ansible output format: hostname | CHANGED | rc=0 >>
            # actual content starts after >>
            output = result.stdout
            
            
            # Find where the actual output starts (after >>)
            if ' >> ' in output:
                output = output.split(' >> ', 1)[1]
            elif '>>' in output:
                output = output.split('>>', 1)[1]
            
            # Remove any ansible success/error messages at the end
            lines = output.split('\n')
            clean_lines = []
            for line in lines:
                # Skip ansible metadata lines
                if line.startswith(first_master) or ' | CHANGED' in line or ' | SUCCESS' in line:
                    continue
                clean_lines.append(line)
            
            kubeconfig = '\n'.join(clean_lines).strip()
            
            # Validate kubeconfig has content
            if not kubeconfig or len(kubeconfig) < 100 or 'apiVersion:' not in kubeconfig:
                print(f"ERROR: Retrieved kubeconfig is invalid (length: {len(kubeconfig)})")
                print(f"Parsed content (first 200 chars): {kubeconfig[:200]}")
                print("\nTrying alternative parsing...")
                
                # Alternative: just find the YAML content
                import re
                yaml_match = re.search(r'(apiVersion:[\s\S]+)', output, re.MULTILINE)
                if yaml_match:
                    kubeconfig = yaml_match.group(1).strip()
                    print("Found kubeconfig with regex matching")
                else:
                    print("ERROR: Could not extract valid kubeconfig from output")
                    return False
            
            # Replace internal IP with external accessible IP
            kubeconfig = kubeconfig.replace('127.0.0.1', master_ip)
            kubeconfig = kubeconfig.replace('localhost', master_ip)
            
            # For multi-master setup, update the server URL to use the load balancer if available
            if len(masters) > 1:
                print(f"Multi-master setup detected ({len(masters)} masters)")
                # Keep using first master IP for now, but could be enhanced to use LB
            
            if output_file:
                with open(output_file, 'w') as f:
                    f.write(kubeconfig)
                print(f"KUBECONFIG saved to: {output_file}")
            else:
                print("\n" + "="*60)
                print("KUBECONFIG CONTENT:")
                print("="*60)
                print(kubeconfig)
                print("="*60)
                print("\nTo use this config:")
                print("1. Copy the content above to ~/.kube/config")
                print("2. Or set: export KUBECONFIG=/path/to/saved/config")
                print("3. Test with: kubectl get nodes")
                
            return True
            
    except Exception as e:
        print(f"Error retrieving KUBECONFIG: {e}")
        return False

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/k8s-inventory.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    success = get_kubeconfig(inventory_file, output_file)
    sys.exit(0 if success else 1)