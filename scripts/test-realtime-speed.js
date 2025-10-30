// Quick test to measure real-time delivery speed
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs'

const supabase = createClient(supabaseUrl, supabaseKey)

const USER_ID = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'

async function testRealTimeSpeed() {
  console.log('⚡ Testing Real-Time Push Notification Speed...\n')

  const startTime = Date.now()

  // Create notification
  const { data: notif, error } = await supabase
    .from('notifications')
    .insert({
      title: '⚡ Real-Time Speed Test',
      message: `Testing instant delivery at ${new Date().toLocaleTimeString()}`,
      type: 'info',
      priority: 'high',
      target_type: 'specific_users',
      target_users: [USER_ID],
      created_by: USER_ID,
      status: 'published'
    })
    .select()
    .single()

  if (error) {
    console.error('❌ Failed to create notification:', error)
    return
  }

  const notifCreatedAt = Date.now()
  console.log(`✅ Notification created: ${notif.id}`)
  console.log(`⏱️  Time to create: ${notifCreatedAt - startTime}ms\n`)

  // ⚡ INSTANT TRIGGER: Call Edge Function immediately
  console.log('⚡ Triggering instant push delivery...')
  const edgeFunctionUrl = `${supabaseUrl}/functions/v1/process-push-queue`
  
  fetch(edgeFunctionUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json'
    }
  }).then(response => {
    if (response.ok) {
      console.log('✅ Edge Function triggered successfully\n')
    } else {
      console.warn('⚠️ Edge Function call failed\n')
    }
  }).catch(error => {
    console.error('❌ Edge Function error:', error.message, '\n')
  })

  // Wait and check status every 500ms
  console.log('🔍 Monitoring delivery status...\n')

  for (let i = 0; i < 20; i++) { // Check for up to 10 seconds
    await new Promise(resolve => setTimeout(resolve, 500))

    const { data: queue } = await supabase
      .from('notification_queue')
      .select('status, sent_at, created_at')
      .eq('notification_id', notif.id)
      .single()

    if (queue) {
      const elapsed = Date.now() - startTime
      
      if (queue.status === 'sent' && queue.sent_at) {
        const deliveryTime = new Date(queue.sent_at).getTime() - new Date(queue.created_at).getTime()
        console.log(`✅ DELIVERED!`)
        console.log(`📊 Total time: ${elapsed}ms`)
        console.log(`⚡ Queue → Sent: ${deliveryTime}ms`)
        console.log(`\n🎯 ${deliveryTime < 3000 ? '🚀 EXCELLENT!' : deliveryTime < 5000 ? '✅ GOOD!' : '⚠️ SLOW'}`)
        return
      } else {
        process.stdout.write(`\r⏱️  ${elapsed}ms - Status: ${queue.status}`)
      }
    }
  }

  console.log('\n\n⚠️  Notification not delivered within 10 seconds')
}

testRealTimeSpeed()
