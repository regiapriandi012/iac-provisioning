#!/usr/bin/env python3
"""
Setup Ansible Mitogen for ultra-fast performance
"""
import os
import sys
import subprocess
import shutil
import tempfile

def install_mitogen():
    print("Installing Ansible Mitogen for ULTRA-FAST performance...")
    print("=" * 50)
    
    # Create directories
    os.makedirs("plugins/strategy", exist_ok=True)
    os.makedirs("plugins/connection", exist_ok=True)
    
    # Download and install Mitogen locally in the project
    print("Downloading Mitogen into project directory...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        try:
            # Clone Mitogen repository
            subprocess.run([
                "git", "clone", "--depth", "1",
                "https://github.com/mitogen-hq/mitogen.git",
                os.path.join(tmpdir, "mitogen")
            ], check=True)
            
            # Copy the entire ansible_mitogen module
            src_mitogen = os.path.join(tmpdir, "mitogen")
            
            # Copy strategy plugins
            src_strategy = os.path.join(src_mitogen, "ansible_mitogen/plugins/strategy")
            if os.path.exists(src_strategy):
                for f in os.listdir(src_strategy):
                    if f.endswith('.py'):
                        shutil.copy2(
                            os.path.join(src_strategy, f),
                            os.path.join("plugins/strategy", f)
                        )
                print("✅ Strategy plugins copied")
            
            # Copy connection plugins
            src_connection = os.path.join(src_mitogen, "ansible_mitogen/plugins/connection")
            if os.path.exists(src_connection):
                for f in os.listdir(src_connection):
                    if f.endswith('.py'):
                        shutil.copy2(
                            os.path.join(src_connection, f),
                            os.path.join("plugins/connection", f)
                        )
                print("✅ Connection plugins copied")
            
            # Copy the mitogen and ansible_mitogen libraries
            os.makedirs("plugins/mitogen_lib", exist_ok=True)
            
            # Copy mitogen core
            if os.path.exists(os.path.join(src_mitogen, "mitogen")):
                shutil.copytree(
                    os.path.join(src_mitogen, "mitogen"),
                    os.path.join("plugins/mitogen_lib/mitogen"),
                    dirs_exist_ok=True
                )
            
            # Copy ansible_mitogen
            if os.path.exists(os.path.join(src_mitogen, "ansible_mitogen")):
                shutil.copytree(
                    os.path.join(src_mitogen, "ansible_mitogen"),
                    os.path.join("plugins/mitogen_lib/ansible_mitogen"),
                    dirs_exist_ok=True
                )
            
            print("✅ Mitogen libraries copied to project")
            
        except subprocess.CalledProcessError as e:
            print(f"Error cloning Mitogen: {e}")
            return False
    
    print("\n✅ Mitogen setup complete!")
    print("\nMitogen provides:")
    print("  - 1.25x to 7x faster execution")
    print("  - 50% less CPU usage")
    print("  - Drastically reduced network traffic")
    print("  - Automatic compression of modules")
    
    return True

if __name__ == "__main__":
    if install_mitogen():
        sys.exit(0)
    else:
        sys.exit(1)