#!/usr/bin/env python3
"""
Configure Ansible to use Mitogen with proper paths
"""
import os
import sys
import subprocess

def setup_mitogen_path():
    """Setup Mitogen to use local project plugins"""
    # Always use local plugins directory
    return "plugins/strategy"

def update_ansible_cfg():
    """Update ansible.cfg to use local Mitogen plugins"""
    mitogen_path = setup_mitogen_path()
    
    print(f"Setting up Mitogen to use local plugins at: {mitogen_path}")
    
    # Read current ansible.cfg
    with open("ansible.cfg", "r") as f:
        content = f.read()
    
    # Update the strategy_plugins line to use only local plugins
    import re
    new_content = re.sub(
        r'strategy_plugins = .*',
        f'strategy_plugins = {mitogen_path}',
        content
    )
    
    # Also add the library path for Mitogen modules
    if 'library' not in new_content:
        # Add library path after strategy_plugins
        new_content = re.sub(
            r'(strategy_plugins = .*)',
            r'\1\nlibrary = plugins/mitogen_lib',
            new_content
        )
    
    # Write back
    with open("ansible.cfg", "w") as f:
        f.write(new_content)
    
    print("✅ Updated ansible.cfg to use local Mitogen plugins")
    return True

if __name__ == "__main__":
    update_ansible_cfg()