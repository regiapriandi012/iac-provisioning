#!/usr/bin/env python3
"""
Show service endpoints from inventory JSON
"""
import json
import sys

def show_endpoints(inventory_file):
    try:
        with open(inventory_file, 'r') as f:
            inv = json.load(f)
            for host, vars in inv['_meta']['hostvars'].items():
                print(f"  - {host}: {vars['ansible_host']}")
    except Exception as e:
        print(f"Error reading inventory: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/k8s-inventory.json'
    show_endpoints(inventory_file)