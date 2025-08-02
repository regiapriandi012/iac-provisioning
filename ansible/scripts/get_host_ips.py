#!/usr/bin/env python3
"""
Extract host IP addresses from inventory JSON
"""
import json
import sys

def get_host_ips(inventory_file):
    try:
        with open(inventory_file, 'r') as f:
            inv = json.load(f)
            
            # Check if _meta section exists, otherwise extract from groups
            if '_meta' in inv and 'hostvars' in inv['_meta']:
                for host, vars in inv['_meta']['hostvars'].items():
                    if 'ansible_host' in vars:
                        print(vars['ansible_host'])
            else:
                # Extract from group hosts
                for group_name, group_data in inv.items():
                    if group_name in ['all', '_meta'] or not isinstance(group_data, dict):
                        continue
                    hosts = group_data.get('hosts', {})
                    for host, host_vars in hosts.items():
                        if isinstance(host_vars, dict) and 'ansible_host' in host_vars:
                            print(host_vars['ansible_host'])
    except Exception as e:
        print(f"Error reading inventory: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else 'inventory/k8s-inventory.json'
    get_host_ips(inventory_file)