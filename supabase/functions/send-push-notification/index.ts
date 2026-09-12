// Supabase Edge Function to send push notifications
// This function sends web push notifications to subscribed users

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5.9.6'

// CORS headers for browser requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PushPayload {
  notificationId: string;
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  image?: string;
  url?: string;
  type?: string;
  data?: any;
}

interface PushSubscriptionData {
  id: string;
  user_id: string;
  subscription: {
    endpoint?: string;
    provider?: string;
    token?: string;
    keys?: {
      p256dh: string;
      auth: string;
    };
  };
  is_active: boolean;
}

let cachedGoogleToken: { token: string; expiresAt: number } | null = null

async function getGoogleAccessToken(): Promise<{ token: string; projectId: string }> {
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')
  const privateKeyB64 = Deno.env.get('FIREBASE_PRIVATE_KEY_B64')
  if (!projectId || !clientEmail || !privateKeyB64) throw new Error('Firebase server credentials are not configured')

  if (cachedGoogleToken && cachedGoogleToken.expiresAt > Date.now() + 60_000) {
    return { token: cachedGoogleToken.token, projectId }
  }

  const privateKey = new TextDecoder().decode(Uint8Array.from(atob(privateKeyB64), c => c.charCodeAt(0)))
  const now = Math.floor(Date.now() / 1000)
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(await importPKCS8(privateKey, 'RS256'))

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion })
  })
  if (!response.ok) throw new Error(`Firebase OAuth failed (${response.status})`)
  const result = await response.json()
  cachedGoogleToken = { token: result.access_token, expiresAt: Date.now() + (result.expires_in * 1000) }
  return { token: result.access_token, projectId }
}

async function sendFcm(token: string, notificationId: string, payload: PushPayload): Promise<void> {
  const auth = await getGoogleAccessToken()
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${auth.projectId}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${auth.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: { token, data: {
      title: payload.title || 'Aqura',
      body: payload.body || '',
      url: payload.url || '',
      type: payload.type || '',
      notificationId: notificationId || '',
      data: JSON.stringify(payload.data || {})
    }, android: { priority: 'high' } } })
  })
  if (!response.ok) {
    const detail = await response.text()
    const error = new Error(`FCM send failed (${response.status}): ${detail.slice(0, 300)}`) as Error & { statusCode?: number }
    error.statusCode = response.status
    throw error
  }
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const vapidPublicKey = Deno.env.get('VITE_VAPID_PUBLIC_KEY')
    const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY')

    if (!supabaseUrl || !supabaseServiceKey || !vapidPublicKey || !vapidPrivateKey) {
      throw new Error('Missing required environment variables')
    }

    // Create Supabase client with service role key
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // VAPID contact — pulled from branding config so it's per-deployment, not hardcoded
    const { data: layoutRow } = await supabase.from('login_layout').select('contact').limit(1).maybeSingle()
    const vapidContactEmail = layoutRow?.contact?.email || Deno.env.get('VAPID_CONTACT_EMAIL') || 'admin@example.com'

    // Parse request body
    const { notificationId, userIds, customerIds, payload } = await req.json() as {
      notificationId: string;
      userIds?: string[];
      customerIds?: string[];
      payload: PushPayload;
    }

    console.log('📬 [Push Function] Sending push to', (userIds?.length || 0), 'users and', (customerIds?.length || 0), 'customers')
    console.log('📬 [Push Function] Payload received:', JSON.stringify(payload, null, 2))

    // Get active push subscriptions for staff users and/or customers
    let subscriptions: PushSubscriptionData[] = [];

    if (userIds && userIds.length > 0) {
      const { data: userSubs, error: userSubError } = await supabase
        .from('push_subscriptions')
        .select('*')
        .in('user_id', userIds)
        .eq('is_active', true)

      if (userSubError) {
        console.error('Error fetching user subscriptions:', userSubError)
      } else {
        subscriptions = subscriptions.concat(userSubs || [])
      }
    }

    if (customerIds && customerIds.length > 0) {
      const { data: customerSubs, error: custSubError } = await supabase
        .from('push_subscriptions')
        .select('*')
        .in('customer_id', customerIds)
        .eq('is_active', true)

      if (custSubError) {
        console.error('Error fetching customer subscriptions:', custSubError)
      } else {
        subscriptions = subscriptions.concat(customerSubs || [])
      }
    }

    if (!subscriptions || subscriptions.length === 0) {
      console.log('📬 [Push Function] No active subscriptions found')
      return new Response(
        JSON.stringify({ 
          success: true, 
          sent: 0, 
          message: 'No active subscriptions' 
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('📬 [Push Function] Found', subscriptions.length, 'active subscriptions')

    // Send push notification to each subscription
    const results = await Promise.allSettled(
      subscriptions.map(async (sub: PushSubscriptionData) => {
        try {
          if (sub.subscription?.provider === 'fcm' && sub.subscription.token) {
            await sendFcm(sub.subscription.token, notificationId, payload)
            await supabase.from('push_subscriptions').update({ last_used_at: new Date().toISOString(), failed_deliveries: 0 }).eq('id', sub.id)
            return { success: true, userId: sub.user_id }
          }

          // Use web-push library (imported via npm specifier)
          const webpush = await import('https://esm.sh/web-push@3.6.6')
          
          // Set VAPID details
          webpush.setVapidDetails(
            `mailto:${vapidContactEmail}`,
            vapidPublicKey,
            vapidPrivateKey
          )

          // Prepare notification payload
          const notificationPayload = JSON.stringify({
            title: payload.title,
            body: payload.body,
            icon: payload.icon || '/icons/icon-192x192.png',
            badge: payload.badge || '/icons/icon-72x72.png',
            image: payload.image,
            url: payload.url || '/',
            notificationId: notificationId,
            type: payload.type,
            data: payload.data
          })

          // Send push notification
          await webpush.sendNotification(
            sub.subscription as any,
            notificationPayload
          )

          console.log('✅ [Push Function] Sent to user:', sub.user_id)

          // Update last_used_at timestamp
          await supabase
            .from('push_subscriptions')
            .update({ last_used_at: new Date().toISOString() })
            .eq('id', sub.id)

          return { success: true, userId: sub.user_id }
        } catch (error) {
          console.error('❌ [Push Function] Error sending to user:', sub.user_id, error)

          // Handle specific errors
          if (error.statusCode === 410 || error.statusCode === 404) {
            // Subscription expired or not found - mark as inactive
            console.log('🗑️ [Push Function] Marking subscription as inactive:', sub.id)
            await supabase
              .from('push_subscriptions')
              .update({ is_active: false })
              .eq('id', sub.id)
          } else {
            // Other error - increment failed deliveries
            await supabase
              .from('push_subscriptions')
              .update({ 
                failed_deliveries: (sub.failed_deliveries || 0) + 1,
                // Deactivate after 5 consecutive failures
                is_active: (sub.failed_deliveries || 0) + 1 < 5
              })
              .eq('id', sub.id)
          }

          return { success: false, userId: sub.user_id, error: error.message }
        }
      })
    )

    // Count successes and failures
    const successful = results.filter(r => r.status === 'fulfilled' && r.value.success).length
    const failed = results.length - successful

    console.log(`📬 [Push Function] Complete: ${successful} sent, ${failed} failed`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: successful,
        failed: failed,
        total: results.length
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ [Push Function] Error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
