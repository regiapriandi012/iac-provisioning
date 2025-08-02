# Security Configuration

## Required Jenkins Credentials

### Proxmox API Credentials

1. In Jenkins, go to "Manage Jenkins" > "Manage Credentials"
2. Add the following credentials as "Secret text":
   
   **Credential 1: Proxmox API URL**
   - ID: `proxmox-api-url`
   - Secret: Your Proxmox API URL (e.g., `https://pve.example.com:8006/api2/json`)
   
   **Credential 2: Proxmox API Token ID**
   - ID: `proxmox-api-token-id`
   - Secret: Your token ID (e.g., `root@pam!terraform`)
   
   **Credential 3: Proxmox API Token Secret**
   - ID: `proxmox-api-token-secret`
   - Secret: Your API token secret

### Slack Webhook Setup

1. Add a new "Secret text" credential:
   - ID: `slack-webhook-url`
   - Secret: Your Slack webhook URL
2. The pipeline will automatically use this credential to send notifications

## Security Best Practices

1. **Never commit sensitive credentials** to version control
2. **Use Jenkins credentials** for production environments
3. **Rotate webhooks regularly** if they are exposed
4. **Limit Slack channel access** to authorized personnel only
5. **Use dedicated channels** for infrastructure notifications

## KUBECONFIG Security

The KUBECONFIG file provides full admin access to your Kubernetes cluster. Handle it with care:

1. **Store securely** - Use encrypted storage or password managers
2. **Limit distribution** - Only share with authorized users
3. **Use RBAC** - Create limited-privilege configs for users
4. **Rotate certificates** - Periodically regenerate cluster certificates
5. **Monitor access** - Enable audit logging in your cluster

## Creating Proxmox API Token

1. Log into Proxmox VE web interface
2. Go to Datacenter > API Tokens
3. Click "Add" to create a new token
4. Fill in:
   - User: Select user (e.g., root@pam)
   - Token ID: Give it a name (e.g., terraform)
   - Privilege Separation: Uncheck if you want full privileges
5. Copy the Token ID and Secret (shown only once!)
6. The Token ID format will be: `user@realm!tokenid` (e.g., `root@pam!terraform`)

## Creating a New Slack Webhook

1. Go to https://api.slack.com/apps
2. Create a new app or select existing
3. Add "Incoming Webhooks" feature
4. Create webhook for your desired channel
5. Copy the webhook URL to Jenkins credentials