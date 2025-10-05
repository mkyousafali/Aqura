# SUPABASE PUSH NOTIFICATIONS DEPLOYMENT GUIDE

## Prerequisites
1. Install Supabase CLI: `npm install -g supabase`
2. Login to Supabase: `supabase login`

## Deployment Steps

### 1. Link to Your Supabase Project
```bash
cd F:\Aqura
supabase link --project-ref vmypotfsyrvuublyddyt
```

### 2. Set Environment Variables in Supabase Dashboard
1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/settings/environment-variables
2. Add environment variable:
   - Name: `VAPID_PRIVATE_KEY`
   - Value: `hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8`

### 3. Deploy Edge Function
```bash
supabase functions deploy send-push-notification
```

### 4. Test Edge Function
```bash
curl -L -X POST 'https://vmypotfsyrvuublyddyt.supabase.co/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  --data-raw '{
    "subscription": {
      "endpoint": "test",
      "keys": {"p256dh": "test", "auth": "test"}
    },
    "payload": {
      "title": "Test",
      "body": "Test notification"
    }
  }'
```

## Architecture Overview
```
Frontend (SvelteKit) 
    ↓ 
Supabase Client 
    ↓ 
Supabase Edge Function (send-push-notification)
    ↓ 
Web Push API (sends to browser)
```

## Key Points
- ✅ No separate backend needed
- ✅ VAPID private key secured in Supabase environment
- ✅ Scalable with Supabase edge functions
- ✅ Integrates with your existing Supabase setup

## Usage in Frontend
```typescript
import { sendPushNotification } from '$lib/utils/supabasePushNotifications';

// Send notification to a user
await sendPushNotification('user-id', {
  title: 'New Task Assigned',
  body: 'You have a new task to complete',
  data: { url: '/tasks/123' }
});
```