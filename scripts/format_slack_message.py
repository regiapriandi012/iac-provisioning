#!/usr/bin/env python3
"""
Format Slack message for Kubernetes deployment notification.
"""
import json
import sys
import os
import gzip
import base64
import random
import string

def main():
    # Read inputs
    build_num = sys.argv[1]
    duration = sys.argv[2]
    endpoint = sys.argv[3]
    masters = sys.argv[4]
    workers = sys.argv[5]
    build_url = sys.argv[6]
    cluster_suffix = sys.argv[7] if len(sys.argv) > 7 else None

    print(f"Debug - Build: {build_num}")
    print(f"Debug - Duration: {duration}")
    print(f"Debug - Endpoint: {endpoint}")
    print(f"Debug - Masters: {masters}")
    print(f"Debug - Workers: {workers}")

    # Read kubeconfig
    kubeconfig_path = 'kubeconfig/admin.conf'
    if not os.path.exists(kubeconfig_path):
        print(f"ERROR: {kubeconfig_path} does not exist!")
        print(f"Current directory: {os.getcwd()}")
        print(f"Directory contents: {os.listdir('.')}")
        if os.path.exists('kubeconfig'):
            print(f"Kubeconfig dir contents: {os.listdir('kubeconfig')}")
        kubeconfig = "# ERROR: KUBECONFIG could not be retrieved\n# Please check the cluster setup"
    else:
        with open(kubeconfig_path, 'r') as f:
            kubeconfig = f.read()
        
        # Check if it's a placeholder
        if kubeconfig.startswith("# KUBECONFIG could not be retrieved"):
            print("WARNING: Using placeholder kubeconfig")
        else:
            print(f"Debug - KUBECONFIG length: {len(kubeconfig)}")
            print(f"Debug - KUBECONFIG first 100 chars: {kubeconfig[:100]}")
            
            # Validate it's a real kubeconfig
            if 'apiVersion:' not in kubeconfig or len(kubeconfig) < 100:
                print("WARNING: kubeconfig seems invalid")
                kubeconfig = f"# WARNING: Invalid KUBECONFIG (length: {len(kubeconfig)})\n# Content:\n{kubeconfig}"

    # Compress kubeconfig using gzip + base64 for compact Slack message
    if kubeconfig and not kubeconfig.startswith("# ERROR:") and not kubeconfig.startswith("# WARNING:"):
        # Compress with gzip and encode with base64
        kubeconfig_bytes = kubeconfig.encode('utf-8')
        compressed = gzip.compress(kubeconfig_bytes, compresslevel=9)
        kubeconfig_compressed = base64.b64encode(compressed).decode('ascii')
        
        # Use cluster suffix from terraform or generate random one as fallback
        if cluster_suffix:
            config_filename = f"config-{cluster_suffix}"
            print(f"Using cluster suffix: {cluster_suffix}")
        else:
            random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
            config_filename = f"config-{random_suffix}"
            print(f"Using random suffix: {random_suffix}")
        
        print(f"Kubeconfig original size: {len(kubeconfig)} characters")
        print(f"Kubeconfig compressed size: {len(kubeconfig_compressed)} characters")
        print(f"Compression ratio: {len(kubeconfig_compressed)/len(kubeconfig)*100:.1f}%")
    else:
        kubeconfig_compressed = None
        config_filename = "config-error"
        print(f"Kubeconfig size: {len(kubeconfig)} characters (not compressed due to error)")

    # Create the Slack message
    message = {
        "text": "Kubernetes Cluster Ready!",
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "Kubernetes Cluster Deployed Successfully"
                }
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*Build:* #{build_num}"},
                    {"type": "mrkdwn", "text": f"*Duration:* {duration}"},
                    {"type": "mrkdwn", "text": f"*Cluster Endpoint:* `{endpoint}`" if endpoint else "*Cluster Endpoint:* Not found"},
                    {"type": "mrkdwn", "text": f"*Nodes:* {masters} masters, {workers} workers"}
                ]
            },
            {"type": "divider"},
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*📋 Quick Setup Command:*" + (f"\n```bash\n# Create .kube directory and extract compressed kubeconfig\nmkdir -p ~/.kube\necho '{kubeconfig_compressed}' | base64 -d | gunzip > ~/.kube/{config_filename}\n\n# Set as default kubeconfig\nexport KUBECONFIG=~/.kube/{config_filename}\n\n# Test connection\nkubectl get nodes\n```" if kubeconfig_compressed else "\n*Error:* Kubeconfig could not be compressed. Please download from Jenkins artifacts.")
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Jenkins Build:* <{build_url}|View Details>"
                }
            }
        ]
    }

    # Write to file
    with open('slack_message.json', 'w') as f:
        json.dump(message, f, indent=2)
        
    # Check message size
    message_size = os.path.getsize('slack_message.json')
    print(f"Slack message written to slack_message.json (size: {message_size} bytes)")

    if message_size > 40000:  # 40KB limit
        print(f"WARNING: Message too large ({message_size} bytes), creating simplified version...")
        
        # Create a simplified message
        simple_message = {
            "text": "Kubernetes Cluster Ready!",
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "Kubernetes Cluster Deployed Successfully"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {"type": "mrkdwn", "text": f"*Build:* #{build_num}"},
                        {"type": "mrkdwn", "text": f"*Duration:* {duration}"},
                        {"type": "mrkdwn", "text": f"*Cluster Endpoint:* `{endpoint}`"},
                        {"type": "mrkdwn", "text": f"*Nodes:* {masters} masters, {workers} workers"}
                    ]
                },
                {"type": "divider"},
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*📋 Access Instructions:*\n1. Use the quick setup command above for instant access\n2. Or download `kubeconfig/admin.conf` from Jenkins artifacts\n3. Run `kubectl get nodes` to verify connection\n\n*Note:* Kubeconfig is compressed for compact delivery via Slack."
                    }
                }
            ]
        }
        
        with open('slack_message.json', 'w') as f:
            json.dump(simple_message, f, indent=2)
        
        print("Created simplified message due to size limit")

    # Also write a debug version to see what's happening
    with open('debug_kubeconfig.txt', 'w') as f:
        f.write(kubeconfig)
    print("Debug - KUBECONFIG written to debug_kubeconfig.txt")

if __name__ == "__main__":
    main()