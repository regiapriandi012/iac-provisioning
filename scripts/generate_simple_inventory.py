#!/usr/bin/env python3
"""
Generate simple, reliable inventory that works without phantom hosts
"""
import csv
import sys
import json
from pathlib import Path

def generate_simple_inventory(csv_file):
    """Generate simple inventory without complex merging that causes issues"""
    
    # Read defaults from environment config
    env_config = {}
    config_file = Path(__file__).parent.parent / 'config' / 'environment.conf'
    
    if config_file.exists():
        with open(config_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_config[key] = value
    
    inventory = {
        'k8s_masters': {'hosts': {}},
        'k8s_workers': {'hosts': {}},
        'k8s_cluster': {
            'children': {
                'k8s_masters': {},
                'k8s_workers': {}
            }
        },
        'all': {
            'vars': {
                'ansible_user': 'root',
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no',
                'ansible_timeout': 120,
                'pod_network_cidr': env_config.get('DEFAULT_POD_NETWORK_CIDR', '10.244.0.0/16'),
                'service_cidr': env_config.get('DEFAULT_SERVICE_CIDR', '10.96.0.0/12'),
                'kubernetes_version': env_config.get('DEFAULT_KUBERNETES_VERSION', '1.28.0'),
                'cni_type': env_config.get('DEFAULT_CNI_TYPE', 'cilium'),
                'cni_version': env_config.get('DEFAULT_CNI_VERSION', '1.14.5')
            }
        }
    }
    
    try:
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                vm_name = row.get('vm_name', '').strip()
                ip = row.get('ip', '').strip()
                
                if not vm_name or not ip:
                    continue
                
                host_vars = {
                    'ansible_host': ip,
                    'ansible_user': 'root',
                    'template': row.get('template', 'debian-12')
                }
                
                # Simple classification
                if 'master' in vm_name.lower():
                    inventory['k8s_masters']['hosts'][vm_name] = host_vars
                elif 'worker' in vm_name.lower():
                    inventory['k8s_workers']['hosts'][vm_name] = host_vars
        
        # Add cluster info based on what we found
        masters = list(inventory['k8s_masters']['hosts'].keys())
        if masters:
            first_master_ip = inventory['k8s_masters']['hosts'][masters[0]]['ansible_host']
            inventory['all']['vars'].update({
                'control_plane_endpoint': f"{first_master_ip}:6443",
                'master_count': len(masters),
                'is_ha_cluster': len(masters) > 1
            })
        
        return inventory
        
    except Exception as e:
        print(f"Error generating inventory: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    csv_file = sys.argv[1] if len(sys.argv) > 1 else '../terraform/vms.csv'
    inventory = generate_simple_inventory(csv_file)
    print(json.dumps(inventory, indent=2))

if __name__ == '__main__':
    main()