import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';

async function testAutomaticProcessing() {
  console.log('='.repeat(60));
  console.log('TESTING AUTOMATIC NOTIFICATION PROCESSING');
  console.log('='.repeat(60));
  
  // Create a test notification
  console.log('\n1️⃣ Creating test notification...');
  const { data: notification, error: createError } = await supabase
    .from('notifications')
    .insert({
      title: 'Auto Test',
      message: `Testing automatic processing at ${new Date().toISOString()}`,
      target_users: [userId],
      target_type: 'specific_users',
      type: 'info',
      priority: 'medium',
      status: 'published',
      created_by: 'system',
      created_by_name: 'System Test',
      created_by_role: 'Admin'
    })
    .select()
    .single();
    
  if (createError) {
    console.log('❌ Error creating notification:', createError.message);
    return;
  }
  
  console.log('✅ Notification created:', notification.id);
  
  // Wait a moment for trigger to fire
  console.log('\n2️⃣ Waiting 2 seconds for trigger to queue...');
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Check if it was queued
  const { data: queued, error: queueError } = await supabase
    .from('notification_queue')
    .select('id, status, created_at')
    .eq('notification_id', notification.id);
    
  if (queueError) {
    console.log('❌ Error checking queue:', queueError.message);
    return;
  }
  
  console.log(`✅ Found ${queued.length} queue entry(ies)`);
  queued.forEach(q => {
    console.log(`  - ID: ${q.id}, Status: ${q.status}, Created: ${q.created_at}`);
  });
  
  if (queued.length === 0) {
    console.log('❌ TRIGGER NOT WORKING! Notification was not queued.');
    return;
  }
  
  // Wait for automatic processing (pg_cron runs every minute)
  console.log('\n3️⃣ Waiting 90 seconds for automatic processing...');
  console.log('   (pg_cron should run within 1 minute)');
  
  for (let i = 90; i > 0; i -= 10) {
    process.stdout.write(`\r   ${i} seconds remaining...`);
    await new Promise(resolve => setTimeout(resolve, 10000));
    
    // Check status every 10 seconds
    const { data: current } = await supabase
      .from('notification_queue')
      .select('status, sent_at')
      .eq('notification_id', notification.id);
      
    if (current && current.some(q => q.status === 'sent')) {
      console.log('\n\n✅ AUTOMATIC PROCESSING WORKS! Notification was sent!');
      current.forEach(q => {
        console.log(`  - Status: ${q.status}, Sent: ${q.sent_at || 'N/A'}`);
      });
      return;
    }
  }
  
  // Final check
  console.log('\n\n4️⃣ Final status check...');
  const { data: final } = await supabase
    .from('notification_queue')
    .select('status, sent_at, error_message')
    .eq('notification_id', notification.id);
    
  if (final.some(q => q.status === 'sent')) {
    console.log('✅ SUCCESS! Automatic processing worked!');
  } else {
    console.log('❌ FAILED! Notification still pending after 90 seconds.');
    console.log('⚠️  pg_cron might not be configured or running.');
    console.log('\nCurrent status:');
    final.forEach(q => {
      console.log(`  - Status: ${q.status}`);
      console.log(`  - Sent: ${q.sent_at || 'Not sent'}`);
      console.log(`  - Error: ${q.error_message || 'None'}`);
    });
  }
}

testAutomaticProcessing().catch(console.error);
