#!/usr/bin/env python3
"""
Configure Ansible to use Mitogen with proper paths
"""
import os
import sys
import subprocess

def find_mitogen_path():
    """Find the mitogen installation path"""
    try:
        # Try to import mitogen and find its path
        result = subprocess.run([
            sys.executable, "-c",
            "import ansible_mitogen.plugins.strategy; import os; print(os.path.dirname(ansible_mitogen.plugins.strategy.__file__))"
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            return result.stdout.strip()
    except:
        pass
    
    # Try common paths
    possible_paths = [
        "/usr/local/lib/python*/dist-packages/ansible_mitogen/plugins/strategy",
        "/usr/lib/python*/dist-packages/ansible_mitogen/plugins/strategy",
        "/usr/local/lib/python*/site-packages/ansible_mitogen/plugins/strategy",
        "/usr/lib/python*/site-packages/ansible_mitogen/plugins/strategy",
        os.path.expanduser("~/.local/lib/python*/site-packages/ansible_mitogen/plugins/strategy")
    ]
    
    import glob
    for pattern in possible_paths:
        matches = glob.glob(pattern)
        if matches and os.path.exists(matches[0]):
            return matches[0]
    
    return None

def update_ansible_cfg():
    """Update ansible.cfg with the correct mitogen path"""
    mitogen_path = find_mitogen_path()
    
    if not mitogen_path:
        print("WARNING: Could not find ansible_mitogen installation")
        print("Mitogen may not work properly")
        return False
    
    print(f"Found Mitogen at: {mitogen_path}")
    
    # Read current ansible.cfg
    with open("ansible.cfg", "r") as f:
        content = f.read()
    
    # Update the strategy_plugins line
    import re
    new_content = re.sub(
        r'strategy_plugins = .*',
        f'strategy_plugins = {mitogen_path}:plugins/strategy',
        content
    )
    
    # Write back
    with open("ansible.cfg", "w") as f:
        f.write(new_content)
    
    print("✅ Updated ansible.cfg with correct Mitogen path")
    return True

if __name__ == "__main__":
    update_ansible_cfg()