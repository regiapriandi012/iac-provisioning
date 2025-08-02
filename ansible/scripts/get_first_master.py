#!/usr/bin/env python3
"""
Get first master node from inventory JSON
"""
import json
import sys

def get_first_master(inventory_file):
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
            if masters:
                print(masters[0])
            else:
                print("")
    except Exception as e:
        print(f"Error reading inventory: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/k8s-inventory.json'
    get_first_master(inventory_file)