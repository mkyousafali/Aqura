// Send a test push notification directly to a specific user
import { createClient } from '@supabase/supabase-js';
import webpush from 'web-push';

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';
const VAPID_PUBLIC_KEY = 'BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8';
const VAPID_PRIVATE_KEY = 'hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function sendTestPush() {
    const userId = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f';
    
    console.log('🚀 Sending test push notification to user:', userId);
    console.log('');
    
    // Configure VAPID details
    webpush.setVapidDetails(
        'mailto:support@aqura.com',
        VAPID_PUBLIC_KEY,
        VAPID_PRIVATE_KEY
    );
    
    // Get all active push subscriptions for this user
    const { data: subscriptions, error: subError } = await supabase
        .from('push_subscriptions')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true);
    
    if (subError) {
        console.error('❌ Error fetching subscriptions:', subError);
        return;
    }
    
    if (!subscriptions || subscriptions.length === 0) {
        console.log('❌ No active push subscriptions found for this user');
        return;
    }
    
    console.log(`✅ Found ${subscriptions.length} active subscription(s)\n`);
    
    // Prepare the notification payload
    const payload = {
        title: '🧪 Test Push Notification',
        body: 'This is a test notification sent directly from the script!',
        icon: '/icons/icon-192x192.png',
        badge: '/icons/icon-96x96.png',
        data: {
            test: true,
            timestamp: Date.now(),
            url: '/mobile'
        }
    };
    
    // Send to each subscription
    for (let i = 0; i < subscriptions.length; i++) {
        const sub = subscriptions[i];
        console.log(`📤 Sending to device ${i + 1}: ${sub.device_id}`);
        console.log(`   Device Type: ${sub.device_type}`);
        console.log(`   Browser: ${sub.browser_name}`);
        
        try {
            const pushSubscription = {
                endpoint: sub.endpoint,
                keys: {
                    p256dh: sub.p256dh,
                    auth: sub.auth
                }
            };
            
            const result = await webpush.sendNotification(
                pushSubscription,
                JSON.stringify(payload)
            );
            
            console.log(`   ✅ Sent successfully! Status: ${result.statusCode}`);
            console.log('');
        } catch (error) {
            console.error(`   ❌ Failed:`, error.message);
            if (error.body) {
                console.error(`   Error body:`, error.body);
            }
            console.log('');
        }
    }
    
    console.log('✨ Test push notification sending complete!');
}

sendTestPush().catch(console.error);
