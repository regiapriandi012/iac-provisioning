#!/bin/bash
# Notify Slack Script
# Sends deployment notification to Slack

set -e

# Get cluster suffix from terraform output
CLUSTER_SUFFIX=""
if [ -d "${WORKSPACE}/terraform" ]; then
    cd ${WORKSPACE}/terraform
    CLUSTER_SUFFIX=$(terraform output -json 2>/dev/null | jq -r '.assignment_summary.value.shared_suffix // empty' 2>/dev/null || echo "")
    cd - > /dev/null
fi

# Run Python script to format the message
python3 ${WORKSPACE}/scripts/format_slack_message.py "${BUILD_NUMBER}" "${BUILD_DURATION}" "${CLUSTER_ENDPOINT}" "${MASTER_COUNT}" "${WORKER_COUNT}" "${BUILD_URL}" "${CLUSTER_SUFFIX}"

# Send to Slack
if curl -X POST ${SLACK_WEBHOOK_URL} \
     -H "Content-Type: application/json" \
     -d @slack_message.json \
     --silent --show-error --fail; then
    echo "Deployment notification sent to Slack successfully!"
else
    echo "Failed to send notification to Slack"
    exit 1
fi

# Cleanup
rm -f slack_message.json