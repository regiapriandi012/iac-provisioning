#!/usr/bin/env python3
"""
Send cluster destruction notification to Django application
Usage: python3 send_destroy_notification_to_django.py <cluster_name> <django_url> <status>
"""
import json
import sys
import os
import requests
import time

def send_destroy_notification_to_django(cluster_name, django_url, status='success'):
    """Send destruction notification to Django"""
    
    # Prepare payload for destroy notification
    payload = {
        'cluster_name': cluster_name,
        'job_name': os.getenv('JOB_NAME', ''),
        'build_number': int(os.getenv('BUILD_NUMBER', '0')),
        'action': 'destroy',
        'status': status,
        'message': f'Cluster "{cluster_name}" destruction {"completed" if status == "success" else "failed"}',
        'timestamp': int(time.time())
    }
    
    # Send to Django webhook
    webhook_url = f"{django_url}/webhook/jenkins/"
    
    try:
        print(f"Sending destroy notification to {webhook_url}")
        print(f"Cluster: {cluster_name}")
        print(f"Status: {status}")
        print(f"Job: {os.getenv('JOB_NAME', 'unknown')}")
        print(f"Build: #{os.getenv('BUILD_NUMBER', '0')}")
        
        response = requests.post(
            webhook_url,
            json=payload,
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Success: {result.get('message', 'Destroy notification sent successfully')}")
            return True
        else:
            print(f"❌ Error: HTTP {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Network error: {e}")
        return False
    except Exception as e:
        print(f"❌ Error sending destroy notification: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 send_destroy_notification_to_django.py <cluster_name> <django_url> [status]")
        print("Example: python3 send_destroy_notification_to_django.py k8s-cluster-123 https://labngoprek.my.id success")
        sys.exit(1)
        
    cluster_name = sys.argv[1]
    django_url = sys.argv[2].rstrip('/')  # Remove trailing slash
    status = sys.argv[3] if len(sys.argv) > 3 else 'success'
    
    success = send_destroy_notification_to_django(cluster_name, django_url, status)
    sys.exit(0 if success else 1)