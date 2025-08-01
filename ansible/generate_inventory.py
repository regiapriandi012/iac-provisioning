#!/usr/bin/env python3
"""
Dynamic Inventory Generator for Kubernetes Cluster
Generates Ansible inventory from Terraform CSV output
"""

import csv
import sys
import json
from pathlib import Path

def generate_inventory_from_csv(csv_file):
    """Generate dynamic inventory based on VM names in CSV"""
    inventory = {
        'k8s_masters': {'hosts': {}, 'vars': {}},
        'k8s_workers': {'hosts': {}, 'vars': {}},
        'k8s_lb': {'hosts': {}, 'vars': {}},
        'k8s_cluster': {'children': {
            'k8s_masters': {},
            'k8s_workers': {}
        }},
        '_meta': {'hostvars': {}},
        'all': {'vars': {
            'ansible_user': 'root',
            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
        }}
    }
    
    masters = []
    workers = []
    lb_nodes = []
    
    try:
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                vm_name = row.get('vm_name') or ''
                vm_name = vm_name.strip() if vm_name else ''
                if not vm_name:
                    continue
                    
                ip = row.get('ip', '0')
                if ip == '0' or not ip:
                    ip = f"192.168.1.{len(masters + workers + lb_nodes) + 10}"
                else:
                    # Strip subnet mask if present (e.g., 10.200.0.30/24 -> 10.200.0.30)
                    ip = ip.split('/')[0]
                
                hostvars = {
                    'ansible_host': ip,
                    'vm_name': vm_name,
                    'cores': row.get('cores', '2'),
                    'memory': row.get('memory', '4096'),
                    'disk_size': row.get('disk_size', '32G'),
                    'template': row.get('template', 'unknown')
                }
                
                # Classify nodes based on naming convention
                if 'master' in vm_name.lower():
                    masters.append(vm_name)
                    inventory['k8s_masters']['hosts'][vm_name] = hostvars
                    inventory['_meta']['hostvars'][vm_name] = hostvars
                elif 'worker' in vm_name.lower():
                    workers.append(vm_name)
                    inventory['k8s_workers']['hosts'][vm_name] = hostvars
                    inventory['_meta']['hostvars'][vm_name] = hostvars
                elif 'lb' in vm_name.lower() or 'haproxy' in vm_name.lower():
                    lb_nodes.append(vm_name)
                    inventory['k8s_lb']['hosts'][vm_name] = hostvars
                    inventory['_meta']['hostvars'][vm_name] = hostvars
    
    except FileNotFoundError:
        print(f"Error: CSV file {csv_file} not found", file=sys.stderr)
        sys.exit(1)
    
    # Set cluster configuration based on master count
    master_count = len(masters)
    
    # Cluster-wide variables
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
            'control_plane_endpoint': '192.168.1.100:6443',  # HAProxy VIP
            'haproxy_vip': '192.168.1.100',
            'haproxy_port': '6443',
            'etcd_cluster': True
        })
        
        # Add HAProxy group if not explicitly defined
        if not lb_nodes and master_count > 1:
            inventory['k8s_lb']['children'] = {'k8s_masters': {}}  # Masters will also run HAProxy
    else:
        # Single master setup
        if masters:
            first_master_ip = inventory['_meta']['hostvars'][masters[0]]['ansible_host']
            cluster_vars['control_plane_endpoint'] = f"{first_master_ip}:6443"
    
    inventory['all']['vars'].update(cluster_vars)
    
    # Remove empty groups but keep essential sections
    filtered_inventory = {}
    
    for k, v in inventory.items():
        if k == 'all':
            # Always keep all section
            filtered_inventory[k] = v
        elif k == '_meta':
            # Skip _meta to avoid Ansible warnings, hostvars are now in individual groups
            continue
        elif v.get('hosts'):
            # Keep groups with hosts
            filtered_inventory[k] = v
        elif v.get('children') and any(child in inventory and inventory[child].get('hosts') for child in v['children']):
            # Keep parent groups that have children with hosts
            filtered_inventory[k] = v
    
    return filtered_inventory

def main():
    """Main function to generate and output inventory"""
    csv_file = sys.argv[1] if len(sys.argv) > 1 else '../terraform/vms.csv'
    
    inventory = generate_inventory_from_csv(csv_file)
    print(json.dumps(inventory, indent=2))

if __name__ == '__main__':
    main()