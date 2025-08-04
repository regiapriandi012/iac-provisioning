#!/usr/bin/env python3
"""
Format professional Slack message for Kubernetes deployment notification.
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
    cluster_suffix = sys.argv[7] if len(sys.argv) > 7 else "cluster"

    # Validate kubeconfig exists
    kubeconfig_available = os.path.exists('kubeconfig/admin.conf')
    
    # Create artifact URL for kubeconfig download
    artifact_url = f"{build_url}artifact/kubeconfig/admin.conf" if build_url else None

    # Create professional Slack message
    message = {
        "text": "🎉 Kubernetes Cluster Deployed Successfully",
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "🎉 Kubernetes Cluster Deployed Successfully",
                    "emoji": True
                }
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*🏗️ Build:* #{build_num}"},
                    {"type": "mrkdwn", "text": f"*⏱️ Duration:* {duration}"},
                    {"type": "mrkdwn", "text": f"*🌐 Endpoint:* `{endpoint}`" if endpoint and endpoint != "Not found" else "*🌐 Endpoint:* _Pending_"},
                    {"type": "mrkdwn", "text": f"*🖥️ Nodes:* {masters} master{'s' if int(masters) > 1 else ''}, {workers} worker{'s' if int(workers) > 1 else ''}"}
                ]
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Cluster ID:* `{cluster_suffix}`"
                }
            },
            {"type": "divider"}
        ]
    }

    # Add kubeconfig section
    if kubeconfig_available and artifact_url:
        message["blocks"].extend([
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*📁 Kubeconfig Access*"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"Download kubeconfig: <{artifact_url}|admin.conf>\n\n*Setup Instructions:*\n1. Download the kubeconfig file above\n2. Save as `~/.kube/config-{cluster_suffix}`\n3. Set environment: `export KUBECONFIG=~/.kube/config-{cluster_suffix}`\n4. Verify: `kubectl get nodes`"
                }
            }
        ])
    else:
        message["blocks"].append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*⚠️ Kubeconfig Status:* Not available in artifacts"
            }
        })

    # Add footer
    message["blocks"].extend([
        {"type": "divider"},
        {
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": f"📊 <{build_url}|View Build Details> | 🔧 Infrastructure as Code Pipeline"
                }
            ]
        }
    ])

    # Write to file
    with open('slack_message.json', 'w') as f:
        json.dump(message, f, indent=2)

if __name__ == "__main__":
    main()