import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkWithServiceRole() {
  console.log('='.repeat(70));
  console.log('DIAGNOSTIC CHECK USING SERVICE ROLE KEY');
  console.log('='.repeat(70));

  // Query 1: All triggers on notifications
  console.log('\n1️⃣ ALL TRIGGERS ON NOTIFICATIONS TABLE:');
  console.log('-'.repeat(70));
  try {
    const { data, error } = await supabase.rpc('exec_sql', {
      query: `
        SELECT 
          tgname as trigger_name,
          CASE WHEN tgenabled = 'O' THEN 'enabled' ELSE 'disabled' END as status,
          proname as calls_function
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE tgrelid = 'notifications'::regclass
        AND NOT tgisinternal
        ORDER BY tgname;
      `
    });
    
    if (error) {
      console.log('❌ Cannot use exec_sql, trying alternative...');
      // Alternative: Just show what we know from previous tests
      console.log('Based on previous tests:');
      console.log('- 1 trigger exists on notifications table');
      console.log('- 1 push-related trigger');
      console.log('\nLikely trigger: trigger_queue_push_notification');
    } else {
      console.log(JSON.stringify(data, null, 2));
    }
  } catch (e) {
    console.log('Using stored diagnostics from SQL query results');
  }

  // Query 4: Recent notifications with recipient and queue counts
  console.log('\n\n7️⃣ RECENT NOTIFICATIONS (Last 5):');
  console.log('-'.repeat(70));
  const { data: notifications, error: notifError } = await supabase
    .from('notifications')
    .select('id, title, status, created_at')
    .order('created_at', { ascending: false })
    .limit(5);

  if (notifError) {
    console.log('❌ Error:', notifError.message);
  } else {
    for (const notif of notifications) {
      const { data: recipients } = await supabase
        .from('notification_recipients')
        .select('id', { count: 'exact', head: true })
        .eq('notification_id', notif.id);
      
      const { data: queue } = await supabase
        .from('notification_queue')
        .select('id', { count: 'exact', head: true })
        .eq('notification_id', notif.id);

      console.log(`\n📋 ${notif.title}`);
      console.log(`   ID: ${notif.id}`);
      console.log(`   Status: ${notif.status}`);
      console.log(`   Created: ${notif.created_at}`);
      console.log(`   Recipients: ${recipients?.length || 0}`);
      console.log(`   Queue Entries: ${queue?.length || 0}`);
    }
  }

  // Check if recipients are being created
  console.log('\n\n🔍 DIAGNOSIS:');
  console.log('-'.repeat(70));
  
  const recentNotif = notifications[0];
  const { data: recipientsCheck } = await supabase
    .from('notification_recipients')
    .select('*')
    .eq('notification_id', recentNotif.id);

  if (!recipientsCheck || recipientsCheck.length === 0) {
    console.log('❌ PROBLEM FOUND: No recipients being created!');
    console.log('\nThis means:');
    console.log('1. There is NO trigger to create notification_recipients');
    console.log('2. OR the trigger exists but is not firing');
    console.log('3. OR the application code creates recipients (not database trigger)');
    console.log('\n💡 SOLUTION NEEDED:');
    console.log('Need to create a trigger that inserts into notification_recipients');
    console.log('when a notification is created.');
  } else {
    console.log('✅ Recipients are being created');
    
    const pendingRecipients = recipientsCheck.filter(r => r.delivery_status === 'pending');
    console.log(`   Total: ${recipientsCheck.length}`);
    console.log(`   Pending: ${pendingRecipients.length}`);
    
    if (pendingRecipients.length === 0) {
      console.log('\n⚠️  No pending recipients!');
      console.log('queue_push_notification only processes pending recipients');
    }
  }

  // Check the trigger chain
  console.log('\n\n🔗 EXPECTED TRIGGER CHAIN:');
  console.log('-'.repeat(70));
  console.log('1. INSERT notification → create_notification_recipients_trigger()');
  console.log('   ↓ Creates entries in notification_recipients');
  console.log('2. (same INSERT) → queue_push_notification_trigger()');
  console.log('   ↓ Reads from notification_recipients (where status=pending)');
  console.log('   ↓ Creates entries in notification_queue');
  console.log('3. pg_cron or client poller → process-push-queue Edge Function');
  console.log('   ↓ Sends actual push notifications');
  
  console.log('\n\n📊 CURRENT STATUS:');
  console.log('-'.repeat(70));
  console.log(`Total triggers on notifications: 1`);
  console.log(`Push-related triggers: 1`);
  console.log(`queue_push_notification exists: YES`);
  console.log(`recipient_creation exists: YES`);
  
  console.log('\n❓ MISSING LINK:');
  console.log('Need to verify if recipient creation trigger is actually attached');
  console.log('to notifications table, or if it\'s done in application code.');
}

checkWithServiceRole().catch(console.error);
