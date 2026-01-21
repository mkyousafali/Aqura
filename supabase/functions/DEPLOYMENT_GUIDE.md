# Edge Function Deployment Guide

## Prerequisites
1. Deno installed on your server
2. Supabase CLI installed
3. Access to your Supabase server via SSH

## Deployment Steps

### 1. Install Supabase CLI (on your server)
```bash
npm install -g supabase
```

### 2. Login to Supabase (if using cloud features)
```bash
supabase login
```

### 3. Link to your project
```bash
cd /path/to/your/supabase
supabase link --project-ref your-project-ref
```

### 4. Deploy the function
```bash
supabase functions deploy send-push-notification
```

### 5. Set Environment Variables
After deployment, set the required environment variables in your Supabase dashboard or via CLI:

```bash
supabase secrets set VITE_VAPID_PUBLIC_KEY=BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8
supabase secrets set VAPID_PRIVATE_KEY=hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8
```

## Testing the Function

### Via curl:
```bash
curl -X POST 'https://supabase.urbanaqura.com/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "notificationId": "test-123",
    "userIds": ["b658eca1-3cc1-48b2-bd3c-33b81fab5a0f"],
    "payload": {
      "title": "Test Notification",
      "body": "This is a test push notification!",
      "url": "/",
      "type": "info"
    }
  }'
```

### Via frontend (TypeScript):
```typescript
const { data, error } = await supabase.functions.invoke('send-push-notification', {
  body: {
    notificationId: notification.id,
    userIds: ['user-id-1', 'user-id-2'],
    payload: {
      title: 'New Task Assigned',
      body: 'You have been assigned a new task',
      url: '/tasks',
      type: 'task_assigned'
    }
  }
});
```

## Troubleshooting

### Function not found
- Ensure the function is deployed: `supabase functions list`
- Check function logs: `supabase functions logs send-push-notification`

### Environment variables not set
- List secrets: `supabase secrets list`
- Verify values match your .env file

### CORS errors
- Function already includes CORS headers
- Ensure your frontend URL is allowed

## Alternative: Manual Deployment for Self-Hosted

If you're running a fully self-hosted Supabase without the CLI integration:

1. SSH into your server
2. Copy the function file to your Supabase functions directory
3. Restart your Supabase edge-runtime or Kong gateway
4. Set environment variables in your Supabase configuration

Contact me if you need help with manual deployment!
