#!/usr/bin/env python3
"""
Send KUBECONFIG to Slack with professional formatting
"""

import json
import sys
import os
import urllib.request
import urllib.error
from datetime import datetime
import base64

def load_env_file():
    """Load environment variables from .env file"""
    env_vars = {}
    env_files = ['.env', '../.env', '../../.env']
    
    for env_file in env_files:
        if os.path.exists(env_file):
            with open(env_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        env_vars[key.strip()] = value.strip()
            break
    
    return env_vars

def send_to_slack(webhook_url, message):
    """Send a message to Slack using webhook"""
    data = json.dumps(message).encode('utf-8')
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    
    try:
        response = urllib.request.urlopen(req)
        return response.status == 200
    except urllib.error.URLError as e:
        print(f"Error sending to Slack: {e}")
        return False

def format_kubeconfig_message(kubeconfig_content, cluster_info):
    """Format KUBECONFIG for Slack with professional styling"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
    
    # Base64 encode the kubeconfig for safe transmission
    kubeconfig_b64 = base64.b64encode(kubeconfig_content.encode()).decode()
    
    # Extract cluster endpoint from kubeconfig
    cluster_endpoint = "N/A"
    # Extract manually without yaml dependency
    for line in kubeconfig_content.split('\n'):
        if 'server:' in line:
            cluster_endpoint = line.split('server:', 1)[1].strip()
            break
    
    message = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "🚀 Kubernetes Cluster Deployed Successfully"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Deployment Time:*\n{timestamp}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Cluster Endpoint:*\n`{cluster_endpoint}`"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Cluster Mode:*\n{cluster_info.get('mode', 'Unknown')}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Total Nodes:*\n{cluster_info.get('total_nodes', 'Unknown')}"
                    }
                ]
            },
            {
                "type": "divider"
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*📋 Quick Setup Instructions:*\n```bash\n# Save the kubeconfig below to ~/.kube/config\nmkdir -p ~/.kube\necho '<BASE64_CONTENT>' | base64 -d > ~/.kube/config\nchmod 600 ~/.kube/config\n\n# Test connection\nkubectl get nodes\n```"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*🔐 KUBECONFIG (Base64 Encoded):*\n```\n{kubeconfig_b64[:500]}...\n```\n_Full content truncated for security. Copy from Jenkins output._"
                }
            },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": "⚠️ *Security Notice:* This KUBECONFIG provides full cluster admin access. Store it securely and do not share publicly."
                    }
                ]
            }
        ]
    }
    
    return message

def main():
    if len(sys.argv) < 2:
        print("Usage: send_kubeconfig_to_slack.py <kubeconfig_file> [inventory_file]")
        sys.exit(1)
    
    kubeconfig_file = sys.argv[1]
    inventory_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Load environment variables
    env_vars = load_env_file()
    webhook_url = env_vars.get('SLACK_WEBHOOK_URL', os.environ.get('SLACK_WEBHOOK_URL'))
    
    if not webhook_url:
        print("Warning: SLACK_WEBHOOK_URL not found in .env or environment variables")
        print("Skipping Slack notification")
        return
    
    # Read kubeconfig
    try:
        with open(kubeconfig_file, 'r') as f:
            kubeconfig_content = f.read()
    except Exception as e:
        print(f"Error reading kubeconfig file: {e}")
        sys.exit(1)
    
    # Get cluster info if inventory provided
    cluster_info = {}
    if inventory_file and os.path.exists(inventory_file):
        try:
            with open(inventory_file, 'r') as f:
                inventory = json.load(f)
                
            # Count nodes
            master_count = len(inventory.get('k8s_masters', {}).get('hosts', {}))
            worker_count = len(inventory.get('k8s_workers', {}).get('hosts', {}))
            
            cluster_info = {
                'mode': 'HA Multi-Master' if master_count > 1 else 'Single Master',
                'total_nodes': f"{master_count} masters, {worker_count} workers"
            }
        except:
            pass
    
    # Format and send message
    message = format_kubeconfig_message(kubeconfig_content, cluster_info)
    
    if send_to_slack(webhook_url, message):
        print("✅ KUBECONFIG sent to Slack successfully!")
    else:
        print("❌ Failed to send KUBECONFIG to Slack")

if __name__ == "__main__":
    main()