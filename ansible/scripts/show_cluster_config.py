#!/usr/bin/env python3
"""
Show cluster configuration from inventory JSON
"""
import json
import sys

def show_cluster_config(inventory_file):
    try:
        with open(inventory_file, 'r') as f:
            inv = json.load(f)
            vars = inv['all']['vars']
            
            print(f"Master nodes: {vars['master_count']}")
            print(f"HA cluster: {vars['is_ha_cluster']}")
            print(f"Control plane: {vars['control_plane_endpoint']}")
    except Exception as e:
        print(f"Error reading inventory: {e}")
        sys.exit(1)

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/k8s-inventory.json'
    show_cluster_config(inventory_file)