#!/usr/bin/env python3
"""
Generate Dynamic Inventory from Terraform Output
Better approach than CSV - directly from terraform output
"""

import json
import subprocess
import sys
import os

def get_terraform_output(output_name):
    """Get terraform output as JSON"""
    try:
        result = subprocess.run([
            'terraform', 'output', '-json', output_name
        ], cwd='../terraform', capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting terraform output {output_name}: {e.stderr}", file=sys.stderr)
        return None
    except json.JSONDecodeError as e:
        print(f"Error parsing terraform output {output_name}: {e}", file=sys.stderr)
        return None

def generate_inventory_from_terraform():
    """Generate inventory from terraform outputs"""
    
    # Get VM data from terraform
    created_vms = get_terraform_output('created_vms')
    assignment_summary = get_terraform_output('assignment_summary')
    
    if not created_vms:
        print("Error: Could not get created_vms from terraform output", file=sys.stderr)
        sys.exit(1)
    
    inventory = {
        'k8s_masters': {'hosts': {}, 'vars': {}},
        'k8s_workers': {'hosts': {}, 'vars': {}},
        'k8s_lb': {'hosts': {}, 'vars': {}},
        'k8s_cluster': {'children': {
            'k8s_masters': {},
            'k8s_workers': {}
        }},
        'all': {'vars': {
            'ansible_user': 'root',
            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o ConnectTimeout=30'
        }}
    }
    
    masters = []
    workers = []
    lb_nodes = []
    
    # Process each VM from terraform output
    for vm_key, vm_data in created_vms.get('value', {}).items():
        vm_name = vm_data.get('original_name', vm_key)
        final_name = vm_data.get('final_name', vm_key)
        
        # Extract IP from ipconfig0 (format: ip=10.200.0.56/24,gw=10.200.0.254)
        ipconfig = vm_data.get('ip', '')
        ip_address = ''
        if 'ip=' in ipconfig:
            ip_part = ipconfig.split('ip=')[1].split(',')[0]
            ip_address = ip_part.split('/')[0]  # Remove /24 subnet mask
        
        if not ip_address:
            print(f"Warning: No IP found for {vm_name}, skipping...", file=sys.stderr)
            continue
            
        hostvars = {
            'ansible_host': ip_address,
            'vm_name': vm_name,
            'final_name': final_name,
            'vmid': vm_data.get('vmid', ''),
            'node': vm_data.get('node', ''),
            'cores': vm_data.get('cores', 2),
            'memory': vm_data.get('memory', 4096),
            'original_name': vm_name
        }
        
        # Classify based on original name
        if 'master' in vm_name.lower():
            masters.append(vm_name)
            inventory['k8s_masters']['hosts'][vm_name] = hostvars
        elif 'worker' in vm_name.lower():
            workers.append(vm_name)
            inventory['k8s_workers']['hosts'][vm_name] = hostvars
        elif 'lb' in vm_name.lower() or 'haproxy' in vm_name.lower():
            lb_nodes.append(vm_name)
            inventory['k8s_lb']['hosts'][vm_name] = hostvars
    
    # Set cluster configuration
    master_count = len(masters)
    cluster_vars = {
        'master_count': master_count,
        'is_ha_cluster': master_count > 1,
        'pod_network_cidr': '10.244.0.0/16',
        'service_cidr': '10.96.0.0/12',
        'kubernetes_version': '1.28.0',
        'container_runtime': 'containerd'
    }
    
    if master_count > 1:
        # HA cluster setup
        cluster_vars.update({
            'control_plane_endpoint': '10.200.0.100:6443',  # HAProxy VIP
            'haproxy_vip': '10.200.0.100',
            'haproxy_port': '6443',
            'etcd_cluster': True
        })
        # Add HAProxy group if not explicitly defined
        if not lb_nodes:
            inventory['k8s_lb']['children'] = {'k8s_masters': {}}
    else:
        # Single master setup
        if masters and masters[0] in inventory['k8s_masters']['hosts']:
            first_master_ip = inventory['k8s_masters']['hosts'][masters[0]]['ansible_host']
            cluster_vars['control_plane_endpoint'] = f"{first_master_ip}:6443"
    
    inventory['all']['vars'].update(cluster_vars)
    
    # Filter empty groups
    filtered_inventory = {}
    for k, v in inventory.items():
        if k == 'all':
            filtered_inventory[k] = v
        elif v.get('hosts'):
            filtered_inventory[k] = v
        elif v.get('children') and any(child in inventory and inventory[child].get('hosts') for child in v['children']):
            filtered_inventory[k] = v
    
    return filtered_inventory

def main():
    """Main function"""
    try:
        inventory = generate_inventory_from_terraform()
        print(json.dumps(inventory, indent=2))
    except Exception as e:
        print(f"Error generating inventory: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()