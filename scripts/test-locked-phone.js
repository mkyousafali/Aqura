// Test script to verify locked phone notification delivery
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs'

const supabase = createClient(supabaseUrl, supabaseKey)

const USER_ID = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'

async function testLockedPhone() {
  console.log('🔒 Testing locked phone notification delivery...\n')

  // Create a high-priority notification
  const { data: notification, error: notifError } = await supabase
    .from('notifications')
    .insert({
      title: '🔒 Locked Phone Test',
      message: 'If you see this on your LOCKED screen, it works! 🎉',
      type: 'info',
      target_users: [USER_ID],
      priority: 'high', // This will trigger urgency: 'high' in Edge Function
      created_by: USER_ID
    })
    .select()
    .single()

  if (notifError) {
    console.error('❌ Error creating notification:', notifError)
    return
  }

  console.log('✅ Notification created:', notification.id)
  console.log('📱 Priority: HIGH (will use urgency: "high")')
  console.log('\n🔐 Now LOCK YOUR PHONE and wait...')
  console.log('⏱️  The notification should appear on your lock screen within ~10-15 seconds')
  console.log('\n🎯 Expected behavior:')
  console.log('   - Notification appears on locked screen')
  console.log('   - Sound/vibration plays')
  console.log('   - No need to unlock phone first')

  // Wait and check status
  await new Promise(resolve => setTimeout(resolve, 15000))

  const { data: queue, error: queueError } = await supabase
    .from('notification_queue')
    .select('status, sent_at, error_message')
    .eq('notification_id', notification.id)
    .single()

  if (queueError) {
    console.error('\n❌ Error checking queue:', queueError)
    return
  }

  console.log('\n📊 Notification Status:', queue.status)
  if (queue.status === 'sent') {
    console.log('✅ Push notification sent successfully!')
    console.log('⏰ Sent at:', queue.sent_at)
  } else if (queue.error_message) {
    console.log('❌ Error:', queue.error_message)
  }
}

testLockedPhone().catch(console.error)
