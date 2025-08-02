#!/usr/bin/env python3
"""
Utility to fix JSON parsing in all scripts
"""
import os
import re

# Script files yang perlu diperbaiki
scripts_to_fix = [
    'scripts/show_endpoints.py',
    'scripts/quick_cluster_check.py', 
    'scripts/wait_for_vms.py',
    'scripts/get_host_ips.py',
    'scripts/get_first_master.py',
    'scripts/get_kubeconfig.py'
]

# Template replacement
old_pattern = r'''    try:
        with open\(inventory_file, 'r'\) as f:
            inv = json\.load\(f\)'''

new_pattern = '''    try:
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
                inv = content'''

def fix_script(script_path):
    """Fix JSON parsing in a script"""
    if not os.path.exists(script_path):
        print(f"SKIP: {script_path} not found")
        return False
    
    try:
        with open(script_path, 'r') as f:
            content = f.read()
        
        # Check if script needs fixing
        if 'json.load(f)' not in content:
            print(f"SKIP: {script_path} already fixed or doesn't need fixing")
            return False
            
        if 'Handle case where terraform output is JSON string' in content:
            print(f"SKIP: {script_path} already fixed")
            return False
        
        # Apply fix
        fixed_content = re.sub(old_pattern, new_pattern, content, flags=re.MULTILINE)
        
        if fixed_content == content:
            print(f"WARN: {script_path} pattern not matched, manual fix needed")
            return False
        
        with open(script_path, 'w') as f:
            f.write(fixed_content)
        
        print(f"FIXED: {script_path}")
        return True
        
    except Exception as e:
        print(f"ERROR: {script_path} - {e}")
        return False

def main():
    print("Fixing JSON parsing in all scripts...")
    print()
    
    fixed_count = 0
    for script in scripts_to_fix:
        if fix_script(script):
            fixed_count += 1
    
    print()
    print(f"Fixed {fixed_count} scripts")
    
    if fixed_count > 0:
        print("\nRun 'git add . && git commit -m \"fix: batch fix JSON parsing in remaining scripts\"' to commit changes")

if __name__ == '__main__':
    main()