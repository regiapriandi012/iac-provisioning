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
    
    # Try to install via pip first
    print("Installing mitogen via pip...")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "mitogen"], check=True)
        print("✅ Mitogen installed via pip")
        
        # Find mitogen installation
        import mitogen
        mitogen_path = os.path.dirname(mitogen.__file__)
        parent_path = os.path.dirname(mitogen_path)
        
        # Look for ansible_mitogen
        ansible_mitogen_path = None
        for possible_path in [
            os.path.join(parent_path, "ansible_mitogen"),
            os.path.join(mitogen_path, "..", "ansible_mitogen"),
            "/usr/local/lib/python3.*/site-packages/ansible_mitogen",
            "/usr/lib/python3.*/site-packages/ansible_mitogen"
        ]:
            import glob
            matches = glob.glob(possible_path)
            if matches and os.path.exists(matches[0]):
                ansible_mitogen_path = matches[0]
                break
        
        if not ansible_mitogen_path:
            # Download and extract manually
            print("Downloading Mitogen manually...")
            with tempfile.TemporaryDirectory() as tmpdir:
                # Download
                subprocess.run([
                    "git", "clone", "--depth", "1",
                    "https://github.com/mitogen-hq/mitogen.git",
                    os.path.join(tmpdir, "mitogen")
                ], check=True)
                
                # Copy plugins
                src_strategy = os.path.join(tmpdir, "mitogen/ansible_mitogen/plugins/strategy")
                src_connection = os.path.join(tmpdir, "mitogen/ansible_mitogen/plugins/connection")
                
                if os.path.exists(src_strategy):
                    for f in os.listdir(src_strategy):
                        if f.endswith('.py'):
                            shutil.copy2(
                                os.path.join(src_strategy, f),
                                os.path.join("plugins/strategy", f)
                            )
                
                if os.path.exists(src_connection):
                    for f in os.listdir(src_connection):
                        if f.endswith('.py'):
                            shutil.copy2(
                                os.path.join(src_connection, f),
                                os.path.join("plugins/connection", f)
                            )
        
        print("\n✅ Mitogen setup complete!")
        print("\nMitogen provides:")
        print("  - 1.25x to 7x faster execution")
        print("  - 50% less CPU usage")
        print("  - Drastically reduced network traffic")
        print("  - Automatic compression of modules")
        
        return True
        
    except Exception as e:
        print(f"Error setting up Mitogen: {e}")
        return False

if __name__ == "__main__":
    if install_mitogen():
        sys.exit(0)
    else:
        sys.exit(1)