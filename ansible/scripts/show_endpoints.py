#!/usr/bin/env python3
"""
Show service endpoints from inventory JSON
"""
import json
import sys

def show_endpoints(inventory_file):
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
            
            print("\nKubernetes Cluster Endpoints:")
            print("=============================")
            
            # Show control plane endpoint
            if 'all' in inv and 'vars' in inv['all']:
                control_plane = inv['all']['vars'].get('control_plane_endpoint', 'Not configured')
                print(f"\nControl Plane: {control_plane}")
            
            # Show master nodes
            if 'k8s_masters' in inv and 'hosts' in inv['k8s_masters']:
                print("\nMaster Nodes:")
                for host, vars in inv['k8s_masters']['hosts'].items():
                    print(f"  - {host}: {vars['ansible_host']}")
            
            # Show worker nodes
            if 'k8s_workers' in inv and 'hosts' in inv['k8s_workers']:
                print("\nWorker Nodes:")
                for host, vars in inv['k8s_workers']['hosts'].items():
                    print(f"  - {host}: {vars['ansible_host']}")
                    
            print("\nAccess the cluster:")
            print("  kubectl --kubeconfig=kubeconfig/admin.conf get nodes")
            
    except Exception as e:
        print(f"Error reading inventory: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else '/tmp/k8s-inventory.json'
    show_endpoints(inventory_file)