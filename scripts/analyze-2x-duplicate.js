import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const notificationId = '874c34dd-4898-46cb-a58b-fc9a6defc27c';

async function analyzeQueue() {
  console.log('='.repeat(60));
  console.log('ANALYZING 2 QUEUE ENTRIES');
  console.log('='.repeat(60));
  
  // Get the 2 queue entries
  const { data: queue, error } = await supabase
    .from('notification_queue')
    .select('*')
    .eq('notification_id', notificationId);
    
  if (error) {
    console.log('❌ Error:', error.message);
    return;
  }
  
  console.log(`\nFound ${queue.length} queue entries:\n`);
  
  queue.forEach((entry, i) => {
    console.log(`--- Entry ${i + 1} ---`);
    console.log(`ID: ${entry.id}`);
    console.log(`User ID: ${entry.user_id}`);
    console.log(`Device ID: ${entry.device_id}`);
    console.log(`Push Subscription ID: ${entry.push_subscription_id}`);
    console.log(`Status: ${entry.status}`);
    console.log(`Created: ${entry.created_at}`);
    console.log('');
  });
  
  // Check if they're identical
  if (queue.length === 2) {
    const entry1 = queue[0];
    const entry2 = queue[1];
    
    console.log('🔍 Comparison:');
    console.log(`Same User: ${entry1.user_id === entry2.user_id ? '✅' : '❌'}`);
    console.log(`Same Device: ${entry1.device_id === entry2.device_id ? '✅' : '❌'}`);
    console.log(`Same Subscription: ${entry1.push_subscription_id === entry2.push_subscription_id ? '✅' : '❌'}`);
    console.log(`Created at same time: ${entry1.created_at === entry2.created_at ? '✅' : '❌'}`);
    
    if (entry1.device_id === entry2.device_id) {
      console.log('\n⚠️  STILL DUPLICATE! Same device getting 2 entries.');
      console.log('\nPossible causes:');
      console.log('1. Trigger still firing twice');
      console.log('2. User has 2 push subscriptions for same device');
      console.log('3. Function being called twice somehow');
    }
  }
  
  // Check push subscriptions for this user
  console.log('\n\n📱 Checking push subscriptions...');
  const { data: subs } = await supabase
    .from('push_subscriptions')
    .select('id, device_id, user_id, is_active')
    .eq('user_id', queue[0].user_id);
    
  console.log(`Found ${subs.length} subscription(s):\n`);
  subs.forEach((sub, i) => {
    console.log(`${i + 1}. ID: ${sub.id}, Device: ${sub.device_id}, Active: ${sub.is_active}`);
  });
  
  if (subs.length === 2 && subs[0].device_id === subs[1].device_id) {
    console.log('\n❌ FOUND IT! User has 2 subscriptions for same device!');
    console.log('This is causing the duplicate queue entries.');
    console.log('\nFix: Delete one of the subscriptions:');
    console.log(`DELETE FROM push_subscriptions WHERE id = '${subs[1].id}';`);
  }
  
  // Check notification_recipients
  console.log('\n\n👥 Checking notification recipients...');
  const { data: recipients } = await supabase
    .from('notification_recipients')
    .select('*')
    .eq('notification_id', notificationId);
    
  console.log(`Found ${recipients.length} recipient(s):\n`);
  recipients.forEach((rec, i) => {
    console.log(`${i + 1}. ID: ${rec.id}, User: ${rec.user_id}, Status: ${rec.delivery_status}`);
  });
  
  if (recipients.length > 1) {
    console.log('\n⚠️  Multiple recipients found!');
    const uniqueUsers = new Set(recipients.map(r => r.user_id));
    if (uniqueUsers.size === 1) {
      console.log('❌ DUPLICATE RECIPIENTS! Same user appears multiple times.');
      console.log('This is causing duplicate queue entries.');
    }
  }
}

analyzeQueue().catch(console.error);
