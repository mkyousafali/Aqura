import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTriggers() {
  console.log('='.repeat(60));
  console.log('CHECKING DATABASE TRIGGERS');
  console.log('='.repeat(60));
  
  // Check triggers on notifications table
  const { data, error } = await supabase
    .rpc('exec_sql', {
      sql: `
        SELECT 
          tgname as trigger_name,
          tgrelid::regclass as table_name,
          tgenabled as enabled,
          tgtype as trigger_type,
          proname as function_name
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE tgrelid = 'notifications'::regclass
        AND tgname LIKE '%push%'
        ORDER BY tgname;
      `
    });
    
  if (error) {
    console.log('❌ Cannot query triggers directly');
    console.log('Error:', error.message);
    console.log('\nTrying alternative method...\n');
    
    // Alternative: Check if function exists and test it manually
    console.log('Testing queue_push_notification function manually:');
    
    // Create a test notification
    const { data: testNotif, error: createError } = await supabase
      .from('notifications')
      .insert({
        title: 'Trigger Test',
        message: 'Testing trigger count',
        target_users: ['b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'],
        target_type: 'specific_users',
        type: 'info',
        priority: 'low',
        status: 'published',
        created_by: 'system',
        created_by_name: 'System Test',
        created_by_role: 'Admin'
      })
      .select()
      .single();
      
    if (createError) {
      console.log('Error creating test:', createError.message);
      return;
    }
    
    console.log(`✅ Created notification: ${testNotif.id}`);
    
    // Wait for trigger
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Check how many queue entries were created
    const { data: queueCount } = await supabase
      .from('notification_queue')
      .select('id', { count: 'exact', head: false })
      .eq('notification_id', testNotif.id);
      
    console.log(`\n📊 Queue entries created: ${queueCount.length}`);
    
    if (queueCount.length === 3) {
      console.log('❌ CONFIRMED: Trigger is firing 3 times!');
      console.log('\nPossible causes:');
      console.log('1. Multiple triggers registered on notifications table');
      console.log('2. Trigger calling function 3 times internally');
      console.log('3. Recursive trigger (trigger calling itself)');
      
      console.log('\n💡 Solution:');
      console.log('Run this SQL in Supabase SQL Editor to check triggers:');
      console.log('');
      console.log('SELECT tgname, tgrelid::regclass, tgenabled');
      console.log('FROM pg_trigger');
      console.log("WHERE tgrelid = 'notifications'::regclass");
      console.log("AND tgname LIKE '%push%';");
    } else if (queueCount.length === 1) {
      console.log('✅ Trigger working correctly (1 entry)');
    } else {
      console.log(`⚠️  Unexpected: ${queueCount.length} entries created`);
    }
    
  } else {
    console.log('✅ Found triggers:\n');
    console.log(JSON.stringify(data, null, 2));
  }
}

checkTriggers().catch(console.error);
