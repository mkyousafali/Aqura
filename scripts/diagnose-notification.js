// Diagnose specific notification
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs'

const supabase = createClient(supabaseUrl, supabaseKey)

const NOTIFICATION_ID = '31a720fc-2063-4820-9cb0-8aee8060feda'
const USER_ID = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'

async function diagnose() {
  console.log('🔍 Diagnosing notification:', NOTIFICATION_ID)
  console.log('👤 User ID:', USER_ID)
  console.log('=' .repeat(60))

  // 1. Check notification exists
  const { data: notif, error: notifError } = await supabase
    .from('notifications')
    .select('*')
    .eq('id', NOTIFICATION_ID)
    .single()

  if (notifError) {
    console.log('❌ Notification not found:', notifError.message)
    return
  }

  console.log('\n✅ Notification found:')
  console.log('   Title:', notif.title)
  console.log('   Type:', notif.type)
  console.log('   Priority:', notif.priority)
  console.log('   Target Users:', notif.target_users)
  console.log('   Created:', notif.created_at)

  // 2. Check recipients were created
  const { data: recipients, error: recipError } = await supabase
    .from('notification_recipients')
    .select('*')
    .eq('notification_id', NOTIFICATION_ID)

  console.log('\n📋 Recipients:')
  if (recipError) {
    console.log('   ❌ Error:', recipError.message)
  } else if (!recipients || recipients.length === 0) {
    console.log('   ❌ NO RECIPIENTS CREATED!')
    console.log('   ⚠️  Trigger "trigger_create_notification_recipients" may not have fired')
  } else {
    console.log(`   ✅ ${recipients.length} recipient(s) created`)
    recipients.forEach(r => {
      console.log(`      - User: ${r.user_id}, Status: ${r.delivery_status}`)
    })
  }

  // 3. Check queue entries
  const { data: queue, error: queueError } = await supabase
    .from('notification_queue')
    .select('*')
    .eq('notification_id', NOTIFICATION_ID)

  console.log('\n📬 Queue Entries:')
  if (queueError) {
    console.log('   ❌ Error:', queueError.message)
  } else if (!queue || queue.length === 0) {
    console.log('   ❌ NO QUEUE ENTRIES CREATED!')
    console.log('   ⚠️  Trigger "trigger_queue_push_notification" may not have fired')
  } else {
    console.log(`   ✅ ${queue.length} queue entry(ies) created`)
    queue.forEach(q => {
      console.log(`      - Queue ID: ${q.id}`)
      console.log(`        Status: ${q.status}`)
      console.log(`        Device: ${q.device_id}`)
      console.log(`        Subscription: ${q.push_subscription_id}`)
      console.log(`        Created: ${q.created_at}`)
      console.log(`        Last Attempt: ${q.last_attempt_at || 'N/A'}`)
      console.log(`        Sent At: ${q.sent_at || 'N/A'}`)
      console.log(`        Error: ${q.error_message || 'None'}`)
    })
  }

  // 4. Check push subscriptions exist
  const { data: subs, error: subsError } = await supabase
    .from('push_subscriptions')
    .select('id, device_id, is_active, created_at')
    .eq('user_id', USER_ID)

  console.log('\n📱 Push Subscriptions for User:')
  if (subsError) {
    console.log('   ❌ Error:', subsError.message)
  } else if (!subs || subs.length === 0) {
    console.log('   ❌ NO PUSH SUBSCRIPTIONS FOUND!')
    console.log('   ⚠️  User needs to enable notifications in browser')
  } else {
    console.log(`   ✅ ${subs.length} subscription(s) found`)
    subs.forEach(s => {
      console.log(`      - ID: ${s.id}`)
      console.log(`        Device: ${s.device_id}`)
      console.log(`        Active: ${s.is_active}`)
      console.log(`        Created: ${s.created_at}`)
    })
  }

  // 5. Summary
  console.log('\n' + '='.repeat(60))
  console.log('📊 DIAGNOSIS SUMMARY:')
  const hasRecipients = recipients && recipients.length > 0
  const hasQueue = queue && queue.length > 0
  const hasSubs = subs && subs.length > 0

  if (!hasRecipients) {
    console.log('❌ ISSUE 1: Recipient creation trigger not working')
  }
  if (!hasQueue) {
    console.log('❌ ISSUE 2: Queue creation trigger not working')
  }
  if (!hasSubs) {
    console.log('❌ ISSUE 3: User has no push subscriptions')
  }
  if (hasRecipients && hasQueue && hasSubs) {
    const allSent = queue.every(q => q.status === 'sent')
    if (allSent) {
      console.log('✅ All looks good - notification should have been delivered')
    } else {
      console.log('⚠️  Queue entries exist but not all sent - check Edge Function logs')
    }
  }
}

diagnose().catch(console.error)
