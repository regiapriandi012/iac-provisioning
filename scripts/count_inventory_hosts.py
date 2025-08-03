#!/usr/bin/env python3
"""
Count total hosts in inventory across all groups
"""
import json
import sys

def count_hosts(inventory_file):
    try:
        with open(inventory_file, 'r') as f:
            data = json.load(f)
        
        total_hosts = 0
        host_details = []
        
        # Check all groups for hosts
        for group_name, group_data in data.items():
            if isinstance(group_data, dict) and 'hosts' in group_data:
                hosts = group_data['hosts']
                total_hosts += len(hosts)
                for host_name, host_info in hosts.items():
                    host_details.append(f"{host_name} ({group_name}): {host_info.get('ansible_host', 'no IP')}")
        
        # Also check if there are hosts directly in 'all'
        if 'all' in data and isinstance(data['all'], dict) and 'hosts' in data['all']:
            all_hosts = data['all']['hosts']
            total_hosts += len(all_hosts)
            for host_name, host_info in all_hosts.items():
                host_details.append(f"{host_name} (all): {host_info.get('ansible_host', 'no IP')}")
        
        return total_hosts, host_details
    except Exception as e:
        print(f"Error reading inventory: {e}", file=sys.stderr)
        return 0, []

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: count_inventory_hosts.py <inventory_file>")
        sys.exit(1)
    
    count, details = count_hosts(sys.argv[1])
    
    if len(sys.argv) > 2 and sys.argv[2] == "--details":
        print(f"Total hosts: {count}")
        for detail in details:
            print(f"  - {detail}")
    else:
        print(count)