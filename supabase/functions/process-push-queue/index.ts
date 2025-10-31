import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8"
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') || "hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8"

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
    // Initialize Supabase client with service role
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    console.log('🚀 Starting push notification queue processor...')

    // Get pending notifications from queue
    const now = new Date().toISOString()
    const { data: queueItems, error: fetchError } = await supabase
      .from('notification_queue')
      .select(`
        id,
        notification_id,
        user_id,
        device_id,
        push_subscription_id,
        payload,
        status,
        retry_count
      `)
      .or(`status.eq.pending,and(status.eq.retry,next_retry_at.lte.${now})`)
      .order('created_at', { ascending: true })
      .limit(50) // Process 50 at a time

    if (fetchError) {
      console.error('❌ Error fetching queue:', fetchError)
      throw fetchError
    }

    console.log('📊 Fetched queue items:', queueItems?.length || 0)

    if (!queueItems || queueItems.length === 0) {
      console.log('📭 No pending notifications in queue')
      return new Response(
        JSON.stringify({ success: true, processed: 0, message: 'No pending notifications' }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        }
      )
    }

    console.log(`📬 Processing ${queueItems.length} queued notifications...`)

    let successCount = 0
    let failCount = 0

    // Process each queue item
    for (const item of queueItems) {
      try {
        console.log(`📤 Sending notification ${item.id} to user ${item.user_id}...`)

        // Update status to processing
        await supabase
          .from('notification_queue')
          .update({ 
            status: 'processing',
            last_attempt_at: new Date().toISOString()
          })
          .eq('id', item.id)

        // Fetch the push subscription separately
        const { data: subscription, error: subError } = await supabase
          .from('push_subscriptions')
          .select('endpoint, p256dh, auth, is_active')
          .eq('id', item.push_subscription_id)
          .single()

        if (subError || !subscription || !subscription.is_active) {
          throw new Error('No active push subscription found for this queue item')
        }

        // Prepare subscription object for send-push-notification function
        const pushSubscription = {
          endpoint: subscription.endpoint,
          keys: {
            p256dh: subscription.p256dh,
            auth: subscription.auth
          }
        }

        console.log(`📤 Calling send-push-notification function...`)

        // Call the send-push-notification Edge Function (which has working web-push)
        const pushResponse = await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'apikey': supabaseServiceKey
          },
          body: JSON.stringify({
            subscription: pushSubscription,
            payload: item.payload
          })
        })

        if (!pushResponse.ok) {
          const errorText = await pushResponse.text()
          throw new Error(`send-push-notification failed: ${pushResponse.status} - ${errorText}`)
        }

        // Mark as sent
        await supabase
          .from('notification_queue')
          .update({ 
            status: 'sent',
            sent_at: new Date().toISOString()
          })
          .eq('id', item.id)

        successCount++
        console.log(`✅ Notification ${item.id} sent successfully`)

      } catch (error) {
        failCount++
        const errorMessage = error instanceof Error ? error.message : String(error)
        console.error(`❌ Failed to send notification ${item.id}:`, error)

        const retryCount = (item.retry_count || 0) + 1
        const maxRetries = 3

        if (retryCount < maxRetries) {
          // Schedule retry (exponential backoff: 1min, 5min, 15min)
          const retryDelayMinutes = retryCount === 1 ? 1 : retryCount === 2 ? 5 : 15
          const nextRetryAt = new Date()
          nextRetryAt.setMinutes(nextRetryAt.getMinutes() + retryDelayMinutes)

          await supabase
            .from('notification_queue')
            .update({ 
              status: 'retry',
              retry_count: retryCount,
              next_retry_at: nextRetryAt.toISOString(),
              error_message: errorMessage
            })
            .eq('id', item.id)

          console.log(`🔄 Notification ${item.id} scheduled for retry ${retryCount}/${maxRetries} in ${retryDelayMinutes}min`)
        } else {
          // Max retries reached, mark as failed
          await supabase
            .from('notification_queue')
            .update({ 
              status: 'failed',
              error_message: `Failed after ${maxRetries} attempts: ${errorMessage}`,
              failed_at: new Date().toISOString()
            })
            .eq('id', item.id)

          console.log(`❌ Notification ${item.id} permanently failed after ${maxRetries} attempts`)
        }
      }
    }

    console.log(`✅ Queue processing complete: ${successCount} sent, ${failCount} failed`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        processed: queueItems.length,
        sent: successCount,
        failed: failCount
      }),
      {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )

  } catch (error) {
    console.error('❌ Queue processor error:', error)
    const errorMessage = error instanceof Error ? error.message : String(error)
    return new Response(
      JSON.stringify({ 
        error: 'Queue processing failed', 
        details: errorMessage
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
