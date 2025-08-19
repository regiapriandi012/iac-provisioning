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
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            cwd='../terraform',
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
    except Exception as e:
        print(f"Error getting terraform outputs: {e}")
    return {}

def get_inventory_data():
    """Get ansible inventory data"""
    inventory_file = 'inventory/k8s-inventory.json'
    try:
        if os.path.exists(inventory_file):
            with open(inventory_file, 'r') as f:
                content = f.read().strip()
                
                # Handle escaped JSON from terraform
                if content.startswith('"') and content.endswith('"'):
                    content = json.loads(content)
                
                return json.loads(content) if isinstance(content, str) else content
    except Exception as e:
        print(f"Error reading inventory: {e}")
    return {}

def get_kubeconfig():
    """Get kubeconfig content"""
    kubeconfig_file = 'kubeconfig/admin.conf'
    try:
        if os.path.exists(kubeconfig_file):
            with open(kubeconfig_file, 'r') as f:
                return f.read()
    except Exception as e:
        print(f"Error reading kubeconfig: {e}")
    return ""

def send_metadata_to_django(cluster_name, django_url):
    """Send all metadata to Django"""
    
    # Collect all metadata
    terraform_outputs = get_terraform_outputs()
    inventory_data = get_inventory_data()
    kubeconfig = get_kubeconfig()
    
    # Prepare payload
    payload = {
        'cluster_name': cluster_name,
        'job_name': os.getenv('JOB_NAME', ''),
        'build_number': int(os.getenv('BUILD_NUMBER', '0')),
        'terraform_outputs': terraform_outputs,
        'inventory_data': inventory_data,
        'kubeconfig': kubeconfig
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