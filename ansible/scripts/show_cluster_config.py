#!/usr/bin/env python3
"""
Show cluster configuration from inventory JSON
"""
import json
import sys

def show_cluster_config(inventory_file):
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
                
            vars = inv['all']['vars']
            
            print(f"Master nodes: {vars.get('master_count', 'Unknown')}")
            print(f"HA cluster: {vars.get('is_ha_cluster', 'Unknown')}")
            print(f"Control plane: {vars.get('control_plane_endpoint', 'Unknown')}")
            
    except Exception as e:
        print(f"Error reading inventory: {e}")
        sys.exit(1)

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/k8s-inventory.json'
    show_cluster_config(inventory_file)