// Check if the trigger exists and test notification creation
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function checkTriggerAndCreateNotification() {
    console.log('🔍 Testing notification creation and push queue trigger...\n');
    
    const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';
    
    // First, create a test notification
    console.log('📝 Creating a test notification...');
    const { data: notification, error: notifError } = await supabase
        .from('notifications')
        .insert({
            title: 'Trigger Test',
            message: 'Testing if trigger automatically queues push notifications',
            type: 'info',
            priority: 'high',
            status: 'published',
            target_type: 'specific_users',
            target_users: [userId],
            created_by: 'system',
            created_by_name: 'System Test',
            created_by_role: 'Admin'
        })
        .select()
        .single();
    
    if (notifError) {
        console.error('❌ Error creating notification:', notifError);
        return;
    }
    
    console.log('✅ Notification created:', notification.id);
    console.log('   Status:', notification.status);
    console.log('');
    
    // Wait a bit for trigger to fire
    console.log('⏳ Waiting 2 seconds for trigger to process...');
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Check if it was queued
    console.log('🔍 Checking if notification was automatically queued...');
    const { data: queueItems, error: queueError } = await supabase
        .from('notification_queue')
        .select('*')
        .eq('notification_id', notification.id);
    
    if (queueError) {
        console.error('❌ Error checking queue:', queueError);
        return;
    }
    
    if (queueItems && queueItems.length > 0) {
        console.log(`✅ SUCCESS! Notification was automatically queued with ${queueItems.length} entries`);
        queueItems.forEach((item, idx) => {
            console.log(`\n  Queue Entry ${idx + 1}:`);
            console.log(`    Queue ID: ${item.id}`);
            console.log(`    Status: ${item.status}`);
            console.log(`    Device: ${item.device_id}`);
        });
    } else {
        console.log('❌ PROBLEM: Notification was NOT automatically queued!');
        console.log('   This means the trigger is not working.');
        console.log('');
        console.log('💡 Possible causes:');
        console.log('   1. Trigger not installed in database');
        console.log('   2. Trigger condition not met (status must be "unread" or "published")');
        console.log('   3. No active push subscriptions for the user');
        console.log('   4. No notification_recipients entries created');
        
        // Check notification_recipients
        console.log('\n🔍 Checking notification_recipients table...');
        const { data: recipients, error: recipError } = await supabase
            .from('notification_recipients')
            .select('*')
            .eq('notification_id', notification.id);
        
        if (recipError) {
            console.error('❌ Error checking recipients:', recipError);
        } else if (recipients && recipients.length > 0) {
            console.log(`✅ Found ${recipients.length} recipient(s)`);
            recipients.forEach((r, idx) => {
                console.log(`   ${idx + 1}. User: ${r.user_id}, Status: ${r.delivery_status}`);
            });
        } else {
            console.log('❌ No notification_recipients entries found!');
            console.log('   The trigger needs notification_recipients with delivery_status="pending"');
        }
    }
    
    console.log('\n' + '='.repeat(60));
}

checkTriggerAndCreateNotification().catch(console.error);
