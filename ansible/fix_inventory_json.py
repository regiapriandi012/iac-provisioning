#!/usr/bin/env python3
"""
Fix escaped JSON inventory from terraform output
"""
import json
import sys

def fix_terraform_json_output(input_file, output_file):
    """Convert escaped JSON string to proper JSON"""
    try:
        with open(input_file, 'r') as f:
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
                
        # Write properly formatted JSON
        with open(output_file, 'w') as f:
            json.dump(inv, f, indent=2)
            
        print(f"SUCCESS: Converted {input_file} -> {output_file}")
        return True
        
    except Exception as e:
        print(f"ERROR: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 fix_inventory_json.py <input_file> <output_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    success = fix_terraform_json_output(input_file, output_file)
    sys.exit(0 if success else 1)