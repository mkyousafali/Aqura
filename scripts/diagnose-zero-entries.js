import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const notificationId = 'ec381af4-bbf0-4568-9d21-a1fda026a958';

async function diagnoseZeroEntries() {
  console.log('='.repeat(60));
  console.log('DIAGNOSING 0 QUEUE ENTRIES');
  console.log('='.repeat(60));
  
  // Check the notification
  const { data: notification, error: notifError } = await supabase
    .from('notifications')
    .select('*')
    .eq('id', notificationId)
    .single();
    
  if (notifError) {
    console.log('❌ Notification error:', notifError.message);
    return;
  }
  
  console.log('\n📋 Notification Details:');
  console.log(`ID: ${notification.id}`);
  console.log(`Title: ${notification.title}`);
  console.log(`Status: ${notification.status}`);
  console.log(`Target Type: ${notification.target_type}`);
  console.log(`Target Users: ${JSON.stringify(notification.target_users)}`);
  console.log(`Created At: ${notification.created_at}`);
  
  // Check recipients
  const { data: recipients, error: recipError } = await supabase
    .from('notification_recipients')
    .select('*')
    .eq('notification_id', notificationId);
    
  if (recipError) {
    console.log('\n❌ Recipients error:', recipError.message);
  } else {
    console.log(`\n👥 Recipients: ${recipients.length}`);
    if (recipients.length === 0) {
      console.log('⚠️  NO RECIPIENTS FOUND!');
      console.log('This means notification_recipients table was not populated.');
      console.log('Possible causes:');
      console.log('1. Trigger on notifications → notification_recipients not working');
      console.log('2. target_users array is empty');
      console.log('3. RLS policy blocking insert');
    } else {
      recipients.forEach((r, i) => {
        console.log(`  ${i + 1}. User: ${r.user_id}, Status: ${r.delivery_status}`);
      });
    }
  }
  
  // Check queue
  const { data: queue, error: queueError } = await supabase
    .from('notification_queue')
    .select('*')
    .eq('notification_id', notificationId);
    
  if (queueError) {
    console.log('\n❌ Queue error:', queueError.message);
  } else {
    console.log(`\n📬 Queue Entries: ${queue.length}`);
    if (queue.length === 0) {
      console.log('⚠️  NO QUEUE ENTRIES!');
      console.log('\nPossible causes:');
      console.log('1. No trigger exists to call queue_push_notification');
      console.log('2. Trigger condition not met (status != "published")');
      console.log('3. No recipients with delivery_status = "pending"');
      console.log('4. No active push subscriptions for user');
    }
  }
  
  // Check user's push subscriptions
  if (notification.target_users && notification.target_users.length > 0) {
    const userId = notification.target_users[0];
    console.log(`\n📱 Checking push subscriptions for user ${userId}...`);
    
    const { data: subs, error: subError } = await supabase
      .from('push_subscriptions')
      .select('id, device_id, is_active')
      .eq('user_id', userId);
      
    if (subError) {
      console.log('❌ Subscriptions error:', subError.message);
    } else {
      console.log(`Found ${subs.length} subscription(s):`);
      subs.forEach((s, i) => {
        console.log(`  ${i + 1}. ID: ${s.id}, Device: ${s.device_id}, Active: ${s.is_active}`);
      });
      
      if (subs.length === 0) {
        console.log('⚠️  No subscriptions! User needs to enable push notifications.');
      }
    }
  }
  
  // Try to manually call the function
  console.log('\n\n🔧 Attempting manual queue_push_notification call...');
  try {
    const { error: manualError } = await supabase.rpc('queue_push_notification', {
      p_notification_id: notificationId
    });
    
    if (manualError) {
      console.log('❌ Manual call failed:', manualError.message);
    } else {
      console.log('✅ Manual call succeeded!');
      
      // Check queue again
      const { data: newQueue } = await supabase
        .from('notification_queue')
        .select('id')
        .eq('notification_id', notificationId);
        
      console.log(`Queue entries after manual call: ${newQueue?.length || 0}`);
      
      if (newQueue && newQueue.length > 0) {
        console.log('✅ Function works! Trigger is the problem.');
        console.log('\nSolution: Recreate the trigger in Supabase SQL Editor:');
        console.log(`
CREATE TRIGGER trigger_queue_push_notification
    AFTER INSERT ON notifications
    FOR EACH ROW
    WHEN (NEW.status = 'published')
    EXECUTE FUNCTION queue_push_notification_trigger();
        `);
      }
    }
  } catch (error) {
    console.log('❌ Manual call exception:', error.message);
  }
}

diagnoseZeroEntries().catch(console.error);
