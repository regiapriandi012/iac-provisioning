#!/bin/bash
# Notify Slack Script
# Sends deployment notification to Slack

set -e

# Check if kubeconfig exists
echo "Checking kubeconfig file:"
ls -la kubeconfig/admin.conf || echo "Kubeconfig file not found!"
echo ""
echo "First 5 lines of kubeconfig:"
head -5 kubeconfig/admin.conf || echo "Cannot read kubeconfig!"
echo ""

# Run Python script to format the message
python3 ${WORKSPACE}/scripts/format_slack_message.py "${BUILD_NUMBER}" "${BUILD_DURATION}" "${CLUSTER_ENDPOINT}" "${MASTER_COUNT}" "${WORKER_COUNT}" "${BUILD_URL}"

# Debug: Check the generated JSON
echo ""
echo "Generated Slack message (first 1000 chars):"
cat slack_message.json | head -c 1000
echo ""
echo ""
echo "Debug kubeconfig content:"
cat debug_kubeconfig.txt | head -20 || echo "No debug kubeconfig"
echo ""

# Send to Slack
if ! curl -X POST ${SLACK_WEBHOOK_URL} \
     -H "Content-Type: application/json" \
     -d @slack_message.json \
     --silent --show-error --fail; then
    
    echo "Blocks format failed, trying simple format..."
    
    # Use fallback Python script for multiple messages
    export MASTER_COUNT
    export WORKER_COUNT
    python3 ${WORKSPACE}/scripts/send_slack_fallback.py
else
    echo "KUBECONFIG sent to Slack successfully!"
fi

# Cleanup
rm -f slack_message.json debug_kubeconfig.txt