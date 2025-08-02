#!/usr/bin/env python3
"""
Detect OS type from template names in inventory
"""
import json
import sys

def detect_os_from_template(template_name):
    """Detect OS family from template name"""
    template_lower = template_name.lower()
    
    # CentOS/RHEL templates
    if any(x in template_lower for x in ['centos', 'rhel', 'rocky', 'alma']):
        return 'RedHat'
    
    # Debian/Ubuntu templates
    elif any(x in template_lower for x in ['debian', 'ubuntu']):
        return 'Debian'
    
    # Default fallback
    else:
        return 'Unknown'

def analyze_cluster_os(inventory_file):
    """Analyze OS distribution across cluster"""
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
        
        os_distribution = {}
        total_nodes = 0
        
        # Extract host variables from all groups, not just _meta
        hosts_data = {}
        
        # Check if _meta exists (old format)
        if '_meta' in inv and 'hostvars' in inv['_meta']:
            hosts_data = inv['_meta']['hostvars']
        else:
            # New format: extract from groups
            for group_name, group_data in inv.items():
                if group_name == 'all' or not isinstance(group_data, dict):
                    continue
                if 'hosts' in group_data:
                    for host, host_vars in group_data['hosts'].items():
                        hosts_data[host] = host_vars
        
        for host, vars in hosts_data.items():
            template = vars.get('template', 'unknown')
            os_family = detect_os_from_template(template)
            
            if os_family not in os_distribution:
                os_distribution[os_family] = []
            
            os_distribution[os_family].append({
                'host': host,
                'template': template
            })
            total_nodes += 1
        
        print("Cluster OS Distribution:")
        print(f"Total nodes: {total_nodes}")
        print("")
        
        for os_family, nodes in os_distribution.items():
            print(f"{os_family}: {len(nodes)} nodes")
            for node in nodes:
                print(f"  - {node['host']}: {node['template']}")
            print("")
        
        # Check for mixed OS
        if len(os_distribution) > 1:
            print("WARNING: Mixed OS detected! Consider using homogeneous templates for better compatibility.")
            return False
        else:
            primary_os = list(os_distribution.keys())[0]
            print(f"Homogeneous cluster detected: {primary_os}")
            return True
            
    except Exception as e:
        print(f"Error reading inventory: {e}")
        return False

if __name__ == '__main__':
    inventory_file = sys.argv[1] if len(sys.argv) > 1 else 'inventory/k8s-inventory.json'
    analyze_cluster_os(inventory_file)