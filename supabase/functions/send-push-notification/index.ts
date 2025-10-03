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
  // Handle CORS
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

    // Validate input
    if (!subscription || !payload) {
      return new Response(
        JSON.stringify({ error: 'Missing subscription or payload' }),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Import web-push functionality
    const webpush = await import('https://esm.sh/web-push@3.6.6')

    // Set VAPID details
    webpush.setVapidDetails(
      'mailto:your-email@domain.com', // Replace with your email
      VAPID_PUBLIC_KEY,
      VAPID_PRIVATE_KEY
    )

    // Send notification
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