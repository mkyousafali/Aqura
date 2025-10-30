// Check notification status in push_notification_queue
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function checkNotification() {
    const notificationId = '1ffcb299-3d1f-4609-856f-fa5dcb71b11e';
    
    console.log('🔍 Checking notification:', notificationId);
    console.log('');
    
    // Check notification_queue - search by notification_id not id
    const { data: queueItems, error: queueError } = await supabase
        .from('notification_queue')
        .select('*')
        .eq('notification_id', notificationId);
    
    if (queueError) {
        console.error('❌ Error fetching notification_queue:', queueError);
    } else if (queueItems && queueItems.length > 0) {
        console.log(`✅ Found ${queueItems.length} queue entries for this notification`);
        queueItems.forEach((item, idx) => {
            console.log(`\n  Queue Entry ${idx + 1}:`);
            console.log(`    Queue ID: ${item.id}`);
            console.log(`    Status: ${item.status}`);
            console.log(`    User: ${item.user_id}`);
            console.log(`    Device ID: ${item.device_id}`);
            console.log(`    Push Subscription: ${item.push_subscription_id}`);
            console.log(`    Created: ${item.created_at}`);
            console.log(`    Scheduled: ${item.scheduled_at}`);
            console.log(`    Sent: ${item.sent_at || 'Not sent yet'}`);
            console.log(`    Attempts: ${item.attempts || 0}/${item.max_attempts || 3}`);
            if (item.payload) {
                console.log(`    Payload:`, JSON.stringify(item.payload, null, 6));
            }
            if (item.error_message) {
                console.log(`    ❌ Error: ${item.error_message}`);
            }
        });
        console.log('');
    } else {
        console.log('⚠️ No queue entries found for this notification');
    }
    console.log('');
    
    // Check push_subscriptions for this user
    if (queueData && queueData.user_id) {
        console.log('🔍 Checking push subscriptions for user:', queueData.user_id);
        
        const { data: subscriptions, error: subError } = await supabase
            .from('push_subscriptions')
            .select('*')
            .eq('user_id', queueData.user_id)
            .eq('is_active', true);
        
        if (subError) {
            console.error('❌ Error fetching subscriptions:', subError);
        } else if (subscriptions && subscriptions.length > 0) {
            console.log(`✅ Found ${subscriptions.length} active subscription(s)`);
            subscriptions.forEach((sub, idx) => {
                console.log(`\n  Subscription ${idx + 1}:`);
                console.log('    Device ID:', sub.device_id);
                console.log('    Device Type:', sub.device_type);
                console.log('    Browser:', sub.browser_name);
                console.log('    Endpoint:', sub.endpoint.substring(0, 50) + '...');
                console.log('    Last Seen:', sub.last_seen);
            });
        } else {
            console.log('❌ No active push subscriptions found for this user');
            console.log('   This is why the notification is not being sent!');
        }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('💡 Next Steps:');
    if (queueData) {
        if (queueData.status === 'pending') {
            console.log('   - Notification is pending, waiting for cron job to process');
            console.log('   - Check if pg_cron is running');
            console.log('   - Check Edge Function logs');
        } else if (queueData.status === 'failed') {
            console.log('   - Notification failed to send');
            console.log('   - Error:', queueData.error_message);
            console.log('   - Attempts:', queueData.attempts, '/', queueData.max_attempts);
        } else if (queueData.status === 'sent') {
            console.log('   - Notification was already sent successfully');
        }
    }
}

checkNotification().catch(console.error);
