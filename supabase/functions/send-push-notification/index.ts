// Supabase Edge Function to send push notifications
// This function sends web push notifications to subscribed users

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

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
    endpoint: string;
    keys: {
      p256dh: string;
      auth: string;
    };
  };
  is_active: boolean;
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
          // Use web-push library (imported via npm specifier)
          const webpush = await import('https://esm.sh/web-push@3.6.6')
          
          // Set VAPID details
          webpush.setVapidDetails(
            'mailto:admin@urbanaqura.com',
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
            sub.subscription,
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
