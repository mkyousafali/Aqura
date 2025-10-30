import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const notificationId = 'a114db68-6029-435a-83e2-9bf99acc489e';
const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';

async function checkNotification() {
  console.log('='.repeat(60));
  console.log(`Checking notification: ${notificationId}`);
  console.log(`For user: ${userId}`);
  console.log('='.repeat(60));
  
  // Check the notification
  const { data: notification, error: notifError } = await supabase
    .from('notifications')
    .select('*')
    .eq('id', notificationId)
    .single();
    
  if (notifError) {
    console.log('\n❌ Notification error:', notifError.message);
  } else {
    console.log('\n✅ Notification details:');
    console.log(JSON.stringify(notification, null, 2));
  }
  
  // Check the queue
  const { data: queue, error: queueError } = await supabase
    .from('notification_queue')
    .select('*')
    .eq('notification_id', notificationId);
    
  if (queueError) {
    console.log('\n❌ Queue error:', queueError.message);
  } else {
    console.log(`\n📋 Queue entries (${queue.length}):`);
    if (queue.length === 0) {
      console.log('⚠️  NO QUEUE ENTRIES FOUND! This notification was never queued.');
    } else {
      queue.forEach((entry, i) => {
        console.log(`\n--- Entry ${i + 1} ---`);
        console.log(`ID: ${entry.id}`);
        console.log(`Status: ${entry.status}`);
        console.log(`Device ID: ${entry.device_id}`);
        console.log(`Created: ${entry.created_at}`);
        console.log(`Processed: ${entry.processed_at || 'Not yet'}`);
        console.log(`Error: ${entry.error_message || 'None'}`);
      });
    }
  }
  
  // Check push subscriptions for the user
  const { data: subs, error: subError } = await supabase
    .from('push_subscriptions')
    .select('*')
    .eq('user_id', userId);
    
  if (subError) {
    console.log('\n❌ Subscriptions error:', subError.message);
  } else {
    console.log(`\n📱 Push subscriptions for user (${subs.length}):`);
    subs.forEach((sub, i) => {
      console.log(`\n--- Subscription ${i + 1} ---`);
      console.log(`Device ID: ${sub.device_id}`);
      console.log(`User Agent: ${sub.user_agent}`);
      console.log(`Created: ${sub.created_at}`);
      console.log(`Has endpoint: ${sub.subscription?.endpoint ? 'Yes' : 'No'}`);
    });
  }
  
  // Check if trigger is still active
  const { data: triggers, error: triggerError } = await supabase
    .rpc('get_triggers_info', {});
    
  if (!triggerError && triggers) {
    console.log('\n🔄 Checking trigger status...');
    const pushTrigger = triggers.find(t => t.trigger_name === 'queue_push_notification_trigger');
    if (pushTrigger) {
      console.log('✅ Trigger is active');
    } else {
      console.log('⚠️  Trigger not found or inactive');
    }
  }
}

checkNotification().catch(console.error);
