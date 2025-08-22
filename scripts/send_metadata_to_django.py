#!/usr/bin/env python3
"""
Send cluster metadata to Django application
Usage: python3 send_metadata_to_django.py <cluster_name> <django_url>
"""
import json
import sys
import os
import requests
import subprocess

def get_terraform_outputs():
    """Get terraform outputs as JSON"""
    try:
        # Use absolute path or relative to current working directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        terraform_dir = os.path.join(script_dir, '..', 'terraform')
        
        # Try both relative and from workspace root
        terraform_dirs = [
            terraform_dir,
            'terraform',  # From workspace root
            os.path.join(os.getcwd(), 'terraform')
        ]
        
        for tf_dir in terraform_dirs:
            if os.path.exists(tf_dir):
                print(f"Trying terraform directory: {tf_dir}")
                result = subprocess.run(
                    ['terraform', 'output', '-json'],
                    cwd=tf_dir,
                    capture_output=True,
                    text=True
                )
                print(f"Terraform output command exit code: {result.returncode}")
                if result.returncode == 0:
                    outputs = json.loads(result.stdout)
                    print(f"Successfully got terraform outputs: {list(outputs.keys())}")
                    return outputs
                else:
                    print(f"Terraform output error: {result.stderr}")
        
        print(f"No valid terraform directory found in: {terraform_dirs}")
    except Exception as e:
        print(f"Error getting terraform outputs: {e}")
        import traceback
        traceback.print_exc()
    return {}

def get_inventory_data():
    """Get ansible inventory data"""
    # Try multiple possible locations
    inventory_paths = [
        'inventory/k8s-inventory.json',
        'ansible/inventory/k8s-inventory.json', 
        os.path.join(os.getcwd(), 'inventory', 'k8s-inventory.json'),
        os.path.join(os.getcwd(), 'ansible', 'inventory', 'k8s-inventory.json')
    ]
    
    for inventory_file in inventory_paths:
        try:
            print(f"Trying inventory file: {inventory_file}")
            if os.path.exists(inventory_file):
                with open(inventory_file, 'r') as f:
                    content = f.read().strip()
                    print(f"Found inventory file: {inventory_file} ({len(content)} chars)")
                    
                    # Handle escaped JSON from terraform
                    if content.startswith('"') and content.endswith('"'):
                        content = json.loads(content)
                    
                    return json.loads(content) if isinstance(content, str) else content
        except Exception as e:
            print(f"Error reading inventory {inventory_file}: {e}")
    
    print(f"No inventory file found in: {inventory_paths}")
    return {}

def get_kubeconfig():
    """Get kubeconfig content"""
    # Try multiple possible locations
    kubeconfig_paths = [
        'kubeconfig/admin.conf',
        'ansible/kubeconfig/admin.conf',
        os.path.join(os.getcwd(), 'kubeconfig', 'admin.conf'),
        os.path.join(os.getcwd(), 'ansible', 'kubeconfig', 'admin.conf')
    ]
    
    for kubeconfig_file in kubeconfig_paths:
        try:
            print(f"Trying kubeconfig file: {kubeconfig_file}")
            if os.path.exists(kubeconfig_file):
                with open(kubeconfig_file, 'r') as f:
                    content = f.read()
                    print(f"Found kubeconfig file: {kubeconfig_file} ({len(content)} chars)")
                    return content
        except Exception as e:
            print(f"Error reading kubeconfig {kubeconfig_file}: {e}")
    
    print(f"No kubeconfig file found in: {kubeconfig_paths}")
    return ""

def send_metadata_to_django(cluster_name, django_url):
    """Send all metadata to Django"""
    
    print(f"=== DEBUGGING CLUSTER METADATA ===")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Script directory: {os.path.dirname(os.path.abspath(__file__))}")
    print(f"Input cluster_name: {cluster_name}")
    print(f"JOB_NAME: {os.getenv('JOB_NAME', 'N/A')}")
    print(f"BUILD_NUMBER: {os.getenv('BUILD_NUMBER', 'N/A')}")
    
    # Collect all metadata
    terraform_outputs = get_terraform_outputs()
    inventory_data = get_inventory_data()
    kubeconfig = get_kubeconfig()
    
    # Extract actual cluster information from terraform outputs
    real_cluster_name = cluster_name
    master_ip = None
    random_suffix = None
    
    if terraform_outputs and 'assignment_summary' in terraform_outputs:
        assignment_summary = terraform_outputs['assignment_summary']['value']
        random_suffix = assignment_summary.get('shared_suffix', '')
        print(f"Random suffix from terraform: {random_suffix}")
    
    if terraform_outputs and 'vm_assignments' in terraform_outputs:
        vm_assignments = terraform_outputs['vm_assignments']['value']
        for vm_name, vm_data in vm_assignments.items():
            if 'master' in vm_name.lower():
                master_ip = vm_data.get('ip_address', '').split('/')[0]
                print(f"First master IP found: {master_ip}")
                break
    
    # Prepare payload
    payload = {
        'cluster_name': cluster_name,
        'job_name': os.getenv('JOB_NAME', ''),
        'build_number': int(os.getenv('BUILD_NUMBER', '0')),
        'terraform_outputs': terraform_outputs,
        'inventory_data': inventory_data,
        'kubeconfig': kubeconfig,
        'random_suffix': random_suffix,
        'detected_master_ip': master_ip
    }
    
    # Send to Django
    webhook_url = f"{django_url}/webhook/jenkins/metadata/"
    
    try:
        print(f"Sending metadata to {webhook_url}")
        print(f"Cluster: {cluster_name}")
        print(f"Terraform outputs: {len(json.dumps(terraform_outputs))} chars")
        print(f"Inventory data: {len(json.dumps(inventory_data))} chars") 
        print(f"Kubeconfig: {len(kubeconfig)} chars")
        
        response = requests.post(
            webhook_url,
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Success: {result.get('message', 'Metadata sent successfully')}")
            if 'master_ip' in result:
                print(f"Master IP: {result['master_ip']}")
            return True
        else:
            print(f"❌ Error: HTTP {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"❌ Error sending metadata: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 send_metadata_to_django.py <cluster_name> <django_url>")
        print("Example: python3 send_metadata_to_django.py k8s-cluster-123 https://labngoprek.my.id")
        sys.exit(1)
        
    cluster_name = sys.argv[1]
    django_url = sys.argv[2].rstrip('/')  # Remove trailing slash
    
    success = send_metadata_to_django(cluster_name, django_url)
    sys.exit(0 if success else 1)