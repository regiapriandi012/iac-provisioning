#!/usr/bin/env python3
"""
Fallback script for sending Slack notifications with simplified format.
"""
import json
import urllib.request
import urllib.error
import os
import base64

def send_slack_message(webhook_url, message):
    """Send a message to Slack webhook."""
    data = json.dumps(message).encode('utf-8')
    req = urllib.request.Request(webhook_url, data=data, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status == 200, response.read().decode()
    except urllib.error.HTTPError as e:
        return False, f'{e.code}: {e.read().decode()}'
    except Exception as e:
        return False, str(e)

def main():
    webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    build_number = os.environ.get('BUILD_NUMBER')
    build_url = os.environ.get('BUILD_URL')
    master_count = os.environ.get('MASTER_COUNT', '0')
    worker_count = os.environ.get('WORKER_COUNT', '0')
    
    if not webhook_url:
        print("ERROR: SLACK_WEBHOOK_URL not set")
        return 1

    # Read kubeconfig
    kubeconfig_path = 'kubeconfig/admin.conf'
    if not os.path.exists(kubeconfig_path):
        kubeconfig = "# ERROR: KUBECONFIG could not be retrieved\n# Please check the cluster setup"
    else:
        with open(kubeconfig_path, 'r') as f:
            kubeconfig = f.read()

    # First message: Summary
    summary_msg = {
        'text': f'''Kubernetes Cluster Ready! (Build #{build_number})

Master nodes: {master_count}
Worker nodes: {worker_count}

Jenkins: {build_url}

Kubeconfig will follow in next message...'''
    }

    # Send summary
    success, resp = send_slack_message(webhook_url, summary_msg)
    if success:
        print('Summary sent successfully')
    else:
        print(f'Failed to send summary: {resp}')

    # Second message: Kubeconfig with proper formatting
    # Escape the kubeconfig content to preserve formatting
    kubeconfig_b64 = base64.b64encode(kubeconfig.encode()).decode()

    kubeconfig_msg = {
        'text': f'''To setup kubeconfig, run this command:

```bash
echo "{kubeconfig_b64}" | base64 -d > ~/.kube/config
kubectl get nodes
```

Or download from Jenkins: {build_url}artifact/ansible/kubeconfig/admin.conf'''
    }

    # Send kubeconfig
    success, resp = send_slack_message(webhook_url, kubeconfig_msg)
    if success:
        print('Kubeconfig sent successfully')
    else:
        print(f'Failed to send kubeconfig: {resp}')
        
        # If too large, try sending just the command
        if 'too_long' in resp or '400' in resp:
            print('Kubeconfig too large, sending download instructions instead')
            fallback_msg = {
                'text': f'''Kubeconfig is too large for Slack. Download it from Jenkins:

{build_url}artifact/ansible/kubeconfig/admin.conf

Or copy from the Jenkins console output above.'''
            }
            success2, resp2 = send_slack_message(webhook_url, fallback_msg)
            if success2:
                print('Fallback message sent')
            else:
                print(f'Failed to send fallback: {resp2}')

    return 0

if __name__ == "__main__":
    exit(main())