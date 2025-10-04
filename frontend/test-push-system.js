// Test Push Notification System
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

// Read environment variables
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('❌ Missing Supabase environment variables');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function testPushNotificationSystem() {
    try {
        console.log('🔍 Testing Push Notification System...\n');

        // 1. Check push subscriptions
        console.log('1️⃣ Checking Push Subscriptions...');
        const { data: subscriptions, error: subError } = await supabase
            .from('push_subscriptions')
            .select('id, user_id, device_id, created_at, is_active')
            .eq('is_active', true)
            .order('created_at', { ascending: false })
            .limit(5);

        if (subError) {
            console.error('❌ Error checking subscriptions:', subError);
        } else {
            console.log(`✅ Found ${subscriptions.length} active push subscriptions`);
            if (subscriptions.length > 0) {
                console.log('📊 Sample subscriptions:', subscriptions);
            }
        }

        // 2. Check notification queue
        console.log('\n2️⃣ Checking Notification Queue...');
        const { data: queue, error: queueError } = await supabase
            .from('notification_queue')
            .select('id, notification_id, user_id, status, created_at, error_message')
            .order('created_at', { ascending: false })
            .limit(10);

        if (queueError) {
            console.error('❌ Error checking queue:', queueError);
        } else {
            console.log(`✅ Found ${queue.length} items in notification queue`);
            if (queue.length > 0) {
                console.log('📊 Queue status breakdown:');
                const statusCounts = queue.reduce((acc, item) => {
                    acc[item.status] = (acc[item.status] || 0) + 1;
                    return acc;
                }, {});
                console.log(statusCounts);
                
                // Show any errors
                const errors = queue.filter(item => item.error_message);
                if (errors.length > 0) {
                    console.log('⚠️ Errors found in queue:');
                    errors.forEach(item => {
                        console.log(`- ${item.id}: ${item.error_message}`);
                    });
                }
            }
        }

        // 3. Check recent notifications
        console.log('\n3️⃣ Checking Recent Notifications...');
        const { data: notifications, error: notifError } = await supabase
            .from('notifications')
            .select('id, title, message, type, status, created_at')
            .order('created_at', { ascending: false })
            .limit(5);

        if (notifError) {
            console.error('❌ Error checking notifications:', notifError);
        } else {
            console.log(`✅ Found ${notifications.length} recent notifications`);
            if (notifications.length > 0) {
                console.log('📊 Recent notifications:', notifications.map(n => ({
                    id: n.id,
                    title: n.title,
                    type: n.type,
                    status: n.status,
                    created_at: n.created_at
                })));
            }
        }

        // 4. Test the queue_push_notification function
        console.log('\n4️⃣ Testing queue_push_notification function...');
        try {
            // Try to call the function with a test notification ID (if any exist)
            if (notifications.length > 0) {
                const testNotificationId = notifications[0].id;
                const { data: functionResult, error: functionError } = await supabase
                    .rpc('queue_push_notification', { notification_id: testNotificationId });

                if (functionError) {
                    console.error('❌ Function error:', functionError);
                } else {
                    console.log('✅ Function executed successfully:', functionResult);
                }
            } else {
                console.log('⚠️ No notifications available to test function');
            }
        } catch (error) {
            console.error('❌ Exception testing function:', error);
        }

        // 5. Check notification recipients
        console.log('\n5️⃣ Checking Notification Recipients...');
        const { data: recipients, error: recipientError } = await supabase
            .from('notification_recipients')
            .select(`
                id,
                notification_id,
                user_id,
                delivery_status,
                created_at,
                notifications!inner(title, type)
            `)
            .order('created_at', { ascending: false })
            .limit(5);

        if (recipientError) {
            console.error('❌ Error checking recipients:', recipientError);
        } else {
            console.log(`✅ Found ${recipients.length} notification recipients`);
            if (recipients.length > 0) {
                console.log('📊 Recent recipients:', recipients);
            }
        }

        // 6. Summary and recommendations
        console.log('\n📋 DIAGNOSIS SUMMARY:');
        console.log('='.repeat(50));
        
        if (subscriptions.length === 0) {
            console.log('🔴 ISSUE: No active push subscriptions found');
            console.log('   → Users need to enable push notifications');
        }
        
        if (notifications.length === 0) {
            console.log('🔴 ISSUE: No notifications in system');
            console.log('   → Create a test notification to verify system');
        }
        
        if (queue.length === 0 && notifications.length > 0) {
            console.log('🔴 ISSUE: Notifications exist but no queue entries');
            console.log('   → Push notification trigger may not be working');
        }
        
        const failedQueue = queue.filter(item => item.status === 'failed');
        if (failedQueue.length > 0) {
            console.log(`🔴 ISSUE: ${failedQueue.length} failed queue items`);
            console.log('   → Check error messages and push subscription validity');
        }

        console.log('\n🔧 QUICK TESTS:');
        console.log('- Create a test notification: window.createTestNotification()');
        console.log('- Test push queue: window.testPushNotificationQueue()');
        console.log('- Process queue manually: window.processPushNotificationQueue()');

    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

testPushNotificationSystem();