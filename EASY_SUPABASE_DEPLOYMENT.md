# SUPABASE EDGE FUNCTION DEPLOYMENT GUIDE
# Manual Dashboard Method (Easier Alternative)

## Method 1: Using Supabase Dashboard (Recommended)

### Step 1: Add Environment Variable
1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/settings/environment-variables
2. Click "Add Variable"
3. Name: `VAPID_PRIVATE_KEY`
4. Value: `hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8`
5. Click "Add Variable"

### Step 2: Create Edge Function
1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/functions
2. Click "Create Function"
3. Function Name: `send-push-notification`
4. Copy and paste the code from: supabase/functions/send-push-notification/index.ts
5. Click "Deploy Function"

### Step 3: Test Edge Function
Use this curl command to test:
```bash
curl -L -X POST 'https://vmypotfsyrvuublyddyt.supabase.co/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs' \
  -H 'Content-Type: application/json' \
  --data-raw '{
    "subscription": {
      "endpoint": "https://example.com/test",
      "keys": {"p256dh": "test", "auth": "test"}
    },
    "payload": {
      "title": "Test Notification",
      "body": "Push notifications are working!"
    }
  }'
```

## Method 2: CLI Method (If you prefer)

If you want to try CLI again:

1. **Set Access Token Manually**:
   - Go to: https://supabase.com/dashboard/account/tokens
   - Create new token
   - Set environment variable: `set SUPABASE_ACCESS_TOKEN=your_token_here`

2. **Link and Deploy**:
   ```bash
   npx supabase link --project-ref vmypotfsyrvuublyddyt
   npx supabase functions deploy send-push-notification
   ```

## ✅ Current Status
- ✅ VAPID keys generated
- ✅ Frontend configured with public key
- ✅ Edge function code created
- ⚠️ Need to deploy to Supabase (use Dashboard method above)
- ⚠️ Need to add private key to environment variables

## 🔧 Frontend Integration
Your frontend is already configured to call:
```typescript
supabase.functions.invoke('send-push-notification', {
  body: { subscription, payload }
})
```

This will work once the edge function is deployed!