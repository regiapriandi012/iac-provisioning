# Security Configuration

## Slack Webhook Setup

### Option 1: Jenkins Credentials (Recommended)

1. In Jenkins, go to "Manage Jenkins" > "Manage Credentials"
2. Add a new "Secret text" credential with ID: `slack-webhook-url`
3. Paste your Slack webhook URL as the secret value
4. The pipeline will automatically use this credential

### Option 2: Local .env File

1. Copy `.env.example` to `.env`
2. Add your Slack webhook URL:
   ```
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/HERE
   ```
3. The `.env` file is gitignored and will not be committed

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

## Creating a New Slack Webhook

1. Go to https://api.slack.com/apps
2. Create a new app or select existing
3. Add "Incoming Webhooks" feature
4. Create webhook for your desired channel
5. Copy the webhook URL to Jenkins or .env file