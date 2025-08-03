#!/usr/bin/env python3
"""
Format Slack message for Kubernetes deployment notification.
"""
import json
import sys
import os

def main():
    # Read inputs
    build_num = sys.argv[1]
    duration = sys.argv[2]
    endpoint = sys.argv[3]
    masters = sys.argv[4]
    workers = sys.argv[5]
    build_url = sys.argv[6]

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

    # Don't truncate kubeconfig - send full content
    kubeconfig_truncated = kubeconfig
    print(f"Kubeconfig size: {len(kubeconfig)} characters")

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
                    "text": "*📋 Access Instructions:*\n1. Download `kubeconfig/admin.conf` from Jenkins artifacts\n2. Save to `~/.kube/config`\n3. Run `kubectl get nodes`"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Quick Setup:*\n```bash\n# Save this as ~/.kube/config\ncat << 'EOF' > ~/.kube/config\n{kubeconfig_truncated}\nEOF\n\n# Test connection\nkubectl get nodes\n```"
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
    import os
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
                        "text": "*📋 Access Instructions:*\n1. Download `kubeconfig/admin.conf` from Jenkins artifacts\n2. Save to `~/.kube/config`\n3. Run `kubectl get nodes`\n\n*Note:* Full kubeconfig too large for Slack. Please download from Jenkins."
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