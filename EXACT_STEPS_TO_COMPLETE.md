# 🚀 EXACT Steps to Complete Push Notifications

## Step 1: Deploy Edge Function (5 minutes)

### 1.1 Open Supabase Dashboard
1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/functions
2. You should see your project dashboard

### 1.2 Create New Function
1. Click the **"Create Function"** button (green button on the right)
2. You'll see a form with these fields:
   - **Function Name**: Enter `send-push-notification` (exactly this name)
   - **Template**: Select "HTTP Function" (default)

### 1.3 Replace the Template Code
1. You'll see a code editor with template code
2. **SELECT ALL** the template code (Ctrl+A)
3. **DELETE** it all
4. **PASTE** this exact code:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8"
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') || "hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8"

interface PushSubscription {
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
}

interface NotificationPayload {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  data?: any;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { subscription, payload }: { 
      subscription: PushSubscription; 
      payload: NotificationPayload;
    } = await req.json()

    if (!subscription || !payload) {
      return new Response(
        JSON.stringify({ error: 'Missing subscription or payload' }),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    const webpush = await import('https://esm.sh/web-push@3.6.6')

    webpush.setVapidDetails(
      'mailto:admin@aqura.com',
      VAPID_PUBLIC_KEY,
      VAPID_PRIVATE_KEY
    )

    await webpush.sendNotification(
      subscription,
      JSON.stringify(payload)
    )

    return new Response(
      JSON.stringify({ success: true, message: 'Notification sent' }),
      {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )

  } catch (error) {
    console.error('Push notification error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Failed to send notification', 
        details: error.message 
      }),
      {
        status: 500,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )
  }
})
```

### 1.4 Deploy the Function
1. Click **"Deploy Function"** button (blue button at bottom)
2. Wait for deployment (usually 30-60 seconds)
3. You should see "✅ Function deployed successfully"

---

## Step 2: Set Environment Variable (2 minutes)

### 2.1 Open Environment Variables
1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/settings/environment-variables
2. You'll see a list of environment variables

### 2.2 Add New Variable
1. Click **"Add Variable"** button
2. Fill in the form:
   - **Name**: `VAPID_PRIVATE_KEY` (exactly this name)
   - **Value**: `hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8`
   - **Scope**: Leave as "Edge Functions" (default)

### 2.3 Save the Variable
1. Click **"Add Variable"** or **"Save"**
2. You should see the new variable in the list

---

## ✅ Verification (1 minute)

### Test Your Setup
1. Open terminal in your project
2. Run: `node test-push-notifications.js`
3. You should see: "✅ Edge Function: Deployed and working"

---

## 🎯 Quick Links

| Step | Direct Link |
|------|-------------|
| 1. Functions | https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/functions |
| 2. Environment Variables | https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/settings/environment-variables |

---

## 🆘 Troubleshooting

### If Edge Function fails to deploy:
- Make sure you selected "HTTP Function" template
- Verify the function name is exactly: `send-push-notification`
- Check that you copied ALL the code above

### If Environment Variable doesn't save:
- Make sure the name is exactly: `VAPID_PRIVATE_KEY`
- Check that the value is exactly: `hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8`
- Ensure "Edge Functions" scope is selected

### If test fails:
- Wait 2-3 minutes after deployment for changes to propagate
- Refresh your browser and try again
- Check the Supabase Functions logs for error details

---

## 🎉 That's It!

Once both steps are complete, your push notification system is fully operational!