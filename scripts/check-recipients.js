import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const notificationId = '4edc2732-a069-4385-9819-3261aa2bc888'; // The test notification

async function checkRecipients() {
  console.log('='.repeat(60));
  console.log('CHECKING NOTIFICATION RECIPIENTS');
  console.log('='.repeat(60));
  
  const { data: recipients, error } = await supabase
    .from('notification_recipients')
    .select('*')
    .eq('notification_id', notificationId);
    
  if (error) {
    console.log('❌ Error:', error.message);
    return;
  }
  
  console.log(`\nFound ${recipients.length} recipient(s):\n`);
  
  recipients.forEach((rec, i) => {
    console.log(`--- Recipient ${i + 1} ---`);
    console.log(`ID: ${rec.id}`);
    console.log(`User ID: ${rec.user_id}`);
    console.log(`Notification ID: ${rec.notification_id}`);
    console.log(`Delivery Status: ${rec.delivery_status}`);
    console.log(`Created: ${rec.created_at}`);
    console.log('');
  });
  
  // Check if there are duplicates
  const uniqueUsers = new Set(recipients.map(r => r.user_id));
  
  console.log('📊 Analysis:');
  console.log(`Total recipients: ${recipients.length}`);
  console.log(`Unique users: ${uniqueUsers.size}`);
  
  if (recipients.length > uniqueUsers.size) {
    console.log('\n⚠️  DUPLICATE RECIPIENTS FOUND!');
    console.log('Same user appears multiple times in recipients table.');
    console.log('This causes multiple queue entries per device!');
  } else if (recipients.length === uniqueUsers.size && recipients.length > 1) {
    console.log('\n✅ Multiple unique users (expected for broadcast)');
  } else if (recipients.length === 1) {
    console.log('\n✅ Single recipient (expected for specific user notification)');
  }
  
  // Check queue entries
  console.log('\n\n📋 Queue entries for this notification:');
  const { data: queue } = await supabase
    .from('notification_queue')
    .select('id, user_id, device_id, status, created_at')
    .eq('notification_id', notificationId);
    
  console.log(`Found ${queue.length} queue entry(ies):\n`);
  queue.forEach((q, i) => {
    console.log(`${i + 1}. ID: ${q.id}, User: ${q.user_id.substring(0, 8)}..., Device: ${q.device_id}, Status: ${q.status}`);
  });
  
  if (queue.length > recipients.length) {
    console.log('\n⚠️  More queue entries than recipients!');
    console.log('Possible causes:');
    console.log('- Multiple triggers firing');
    console.log('- User has multiple devices');
    console.log('- Duplicate recipient records');
  }
}

checkRecipients().catch(console.error);
