#!/usr/bin/env python3
"""
Dynamic inventory script for Ansible
Reads from k8s-inventory.json and outputs in Ansible inventory format
"""
import json
import sys
import os

def main():
    # Default inventory file path
    inventory_file = os.environ.get('ANSIBLE_INVENTORY_FILE', 'inventory/k8s-inventory.json')
    
    # Check if specific inventory file is passed as argument
    if len(sys.argv) > 1 and sys.argv[1] == '--list':
        # Read the JSON inventory file
        try:
            with open(inventory_file, 'r') as f:
                content = f.read().strip()
                
                # Handle case where terraform output is JSON string (escaped)
                if content.startswith('"') and content.endswith('"'):
                    # Remove quotes and unescape
                    content = json.loads(content)
                
                # Parse the actual JSON
                if isinstance(content, str):
                    inventory = json.loads(content)
                else:
                    inventory = content
                
                # Convert to Ansible dynamic inventory format
                output = {
                    '_meta': {
                        'hostvars': {}
                    }
                }
                
                # Process each group
                for group_name, group_data in inventory.items():
                    if group_name == 'all':
                        # Handle global vars
                        output['all'] = {
                            'vars': group_data.get('vars', {})
                        }
                    elif isinstance(group_data, dict):
                        if 'hosts' in group_data:
                            # Regular group with hosts
                            output[group_name] = {
                                'hosts': list(group_data['hosts'].keys())
                            }
                            # Add host vars to _meta
                            for host, host_vars in group_data['hosts'].items():
                                output['_meta']['hostvars'][host] = host_vars
                                # Also inherit all vars EXCEPT ansible_ssh_common_args (handled in ansible.cfg)
                                if 'all' in inventory and 'vars' in inventory['all']:
                                    all_vars = inventory['all']['vars'].copy()
                                    # Remove SSH args to avoid conflict with ansible.cfg
                                    all_vars.pop('ansible_ssh_common_args', None)
                                    output['_meta']['hostvars'][host].update(all_vars)
                        elif 'children' in group_data:
                            # Parent group with children
                            output[group_name] = {
                                'children': list(group_data['children'].keys())
                            }
                
                print(json.dumps(output, indent=2))
                
        except Exception as e:
            print(json.dumps({'_meta': {'hostvars': {}}}))
            sys.stderr.write(f"Error reading inventory: {e}\n")
            sys.exit(1)
            
    elif len(sys.argv) > 1 and sys.argv[1] == '--host':
        # Return empty host vars
        print(json.dumps({}))
    else:
        # Invalid usage
        print("Usage: %s --list or --host <hostname>" % sys.argv[0])
        sys.exit(1)

if __name__ == '__main__':
    main()