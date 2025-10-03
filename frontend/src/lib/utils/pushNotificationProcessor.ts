import { createClient } from '@supabase/supabase-js';

// Use service role for queue processing - UPDATED CORRECT URLs
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

interface QueuedNotification {
    id: string;
    notification_id: string;
    user_id: string;
    device_id: string;
    push_subscription_id: string;
    payload: any;
    status: string;
    created_at: string;
    push_subscriptions: {
        endpoint: string;
        p256dh: string;
        auth: string;
    };
}

class PushNotificationProcessor {
    private isProcessing = false;
    private intervalId: NodeJS.Timeout | null = null;

    /**
     * Start the background processor
     */
    start() {
        if (this.isProcessing) {
            console.log('🔄 Push notification processor already running');
            return;
        }

        console.log('🚀 Starting push notification processor with URL:', SUPABASE_URL);
        console.log('🔧 Using service key ending in:', SUPABASE_SERVICE_KEY.slice(-10));
        this.isProcessing = true;
        
        // Process queue immediately
        this.processQueue().catch(err => {
            console.error('❌ Initial queue processing failed:', err);
        });
        
        // DISABLED: Process every 5 seconds to prevent console spam
        // this.intervalId = setInterval(() => {
        //     this.processQueue().catch(err => {
        //         console.error('❌ Queue processing failed:', err);
        //     });
        // }, 5000) as any;
        
        console.log('✅ Push notification processor started successfully');
    }

    /**
     * Stop the background processor
     */
    stop() {
        console.log('🛑 Stopping push notification processor...');
        this.isProcessing = false;
        
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    }

    /**
     * Process pending notifications in the queue
     */
    private async processQueue() {
        try {
            console.log('🔍 Processing notification queue with URL:', SUPABASE_URL);

            // Get pending notifications from queue with push subscription details
            const { data: queuedNotifications, error } = await supabase
                .from('notification_queue')
                .select(`
                    id,
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    payload,
                    status,
                    created_at,
                    push_subscriptions (
                        endpoint,
                        p256dh,
                        auth
                    )
                `)
                .eq('status', 'pending')
                .order('created_at', { ascending: true })
                .limit(20); // Process 20 at a time

            if (error) {
                console.error('❌ Error fetching queued notifications:', error);
                console.error('❌ Database URL:', SUPABASE_URL);
                return;
            }

            console.log(`📊 Found ${queuedNotifications?.length || 0} pending notifications in queue`);
            console.log('🔍 Database response:', { queuedNotifications, error });

            if (!queuedNotifications || queuedNotifications.length === 0) {
                return; // Don't log if no notifications (too verbose)
            }

            console.log(`📬 Processing ${queuedNotifications.length} pending notifications...`);
            console.log('🔍 Queue items:', queuedNotifications);

            // Process each notification
            for (const queueItem of queuedNotifications) {
                console.log('🔍 Processing queue item:', queueItem);
                
                // Get the push subscription details for this queue item
                if (queueItem.push_subscription_id) {
                    const { data: subscription, error: subError } = await supabase
                        .from('push_subscriptions')
                        .select('endpoint, p256dh, auth')
                        .eq('id', queueItem.push_subscription_id)
                        .eq('is_active', true)
                        .single();

                    if (subscription && !subError) {
                        console.log('✅ Found push subscription for queue item:', queueItem.id);
                        console.log('🔍 Subscription details:', subscription);
                        await this.sendPushNotification(queueItem as any);
                    } else {
                        console.warn('⚠️ No active push subscription found for queue item:', queueItem.id, 'subscription_id:', queueItem.push_subscription_id);
                        console.warn('🔍 Subscription error:', subError);
                        
                        // Mark as failed since we can't send it
                        await supabase
                            .from('notification_queue')
                            .update({ 
                                status: 'failed',
                                error_message: 'Push subscription not found or inactive'
                            })
                            .eq('id', queueItem.id);
                    }
                } else {
                    console.warn('⚠️ Queue item has no push_subscription_id:', queueItem.id);
                    
                    // Mark as failed
                    await supabase
                        .from('notification_queue')
                        .update({ 
                            status: 'failed',
                            error_message: 'No push subscription ID'
                        })
                        .eq('id', queueItem.id);
                }
            }

        } catch (error) {
            console.error('❌ Error processing notification queue:', error);
            console.error('❌ Database URL being used:', SUPABASE_URL);
        }
    }

    /**
     * Send a single push notification using Service Worker
     */
    private async sendPushNotification(queueItem: QueuedNotification) {
        try {
            console.log(`📤 Sending push notification ${queueItem.id} to device ${queueItem.device_id}...`);
            console.log('🔍 Notification payload:', queueItem.payload);

            // Check notification permissions first
            console.log('🔍 Notification permission:', Notification.permission);
            
            if (Notification.permission !== 'granted') {
                console.error('❌ Notification permission not granted:', Notification.permission);
                throw new Error(`Notification permission not granted: ${Notification.permission}`);
            }

            // Mark as processing
            await supabase
                .from('notification_queue')
                .update({ status: 'processing' })
                .eq('id', queueItem.id);

            // Use the browser's notification API instead of web-push library
            if ('serviceWorker' in navigator && 'Notification' in window) {
                console.log('🔍 Service Worker and Notification API available');
                
                // Get the service worker registration
                const registration = await navigator.serviceWorker.ready;
                console.log('🔍 Service Worker ready:', registration);
                
                // Show notification through service worker
                console.log('🔔 Showing notification with title:', queueItem.payload.title);
                await registration.showNotification(queueItem.payload.title, {
                    body: queueItem.payload.body,
                    icon: queueItem.payload.icon,
                    badge: queueItem.payload.badge,
                    data: queueItem.payload.data,
                    tag: `notification-${queueItem.notification_id}`,
                    requireInteraction: true,
                    silent: false // Make sure it's not silent
                });

                console.log('🎉 Notification shown successfully!');

                // Mark as sent
                await supabase
                    .from('notification_queue')
                    .update({ 
                        status: 'sent',
                        sent_at: new Date().toISOString()
                    })
                    .eq('id', queueItem.id);

                console.log(`✅ Push notification ${queueItem.id} sent successfully`);
            } else {
                console.error('❌ Service Worker or Notifications not supported');
                throw new Error('Service Worker or Notifications not supported');
            }

        } catch (error) {
            console.error(`❌ Failed to send push notification ${queueItem.id}:`, error);

            // Mark as failed
            await supabase
                .from('notification_queue')
                .update({ 
                    status: 'failed',
                    error_message: error instanceof Error ? error.message : 'Unknown error',
                    failed_at: new Date().toISOString()
                })
                .eq('id', queueItem.id);
        }
    }

    /**
     * Manually process queue once (for testing)
     */
    async processOnce() {
        console.log('🧪 Manual queue processing...');
        await this.processQueue();
    }

    /**
     * Create a test notification queue entry (for debugging)
     */
    async createTestQueueEntry() {
        try {
            console.log('🧪 Creating test notification queue entry...');
            
            // Create a test payload
            const testPayload = {
                title: 'Test Push Notification',
                body: 'This is a test notification to verify the processor works',
                icon: '/favicon.png',
                badge: '/badge-icon.png',
                data: {
                    notification_id: 'test-notification-id',
                    url: '/notifications?test=true',
                    created_at: new Date().toISOString(),
                    sender: 'System Test'
                }
            };

            // Insert test entry directly into queue
            const { data, error } = await supabase
                .from('notification_queue')
                .insert({
                    notification_id: 'test-notification-id',
                    user_id: 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', // Current user ID
                    device_id: 'test-device',
                    push_subscription_id: null,
                    status: 'pending',
                    payload: testPayload
                })
                .select();

            if (error) {
                console.error('❌ Failed to create test queue entry:', error);
            } else {
                console.log('✅ Test queue entry created:', data);
                console.log('🔄 Processing queue immediately...');
                await this.processQueue();
            }
        } catch (error) {
            console.error('❌ Error creating test queue entry:', error);
        }
    }
}

// Create singleton instance
export const pushNotificationProcessor = new PushNotificationProcessor();

// Expose test function globally for debugging
if (typeof window !== 'undefined') {
    (window as any).testPushNotificationQueue = () => {
        pushNotificationProcessor.createTestQueueEntry();
    };
    
    (window as any).processPushNotificationQueue = () => {
        pushNotificationProcessor.processOnce();
    };
    
    // Add emergency stop function
    (window as any).stopPushNotificationProcessor = () => {
        pushNotificationProcessor.stop();
        console.log('🛑 Emergency stop: Push notification processor stopped');
    };

    // Test if database trigger is working by manually calling the queue function
    (window as any).testDatabaseTrigger = async () => {
        console.log('🧪 Testing if database trigger function exists and works...');
        try {
            // Call the queue_push_notification function directly with the notification ID from your console
            const { data, error } = await supabase.rpc('queue_push_notification', {
                p_notification_id: '0d1dc630-c253-4269-b30b-f416a747e69e'
            });

            if (error) {
                console.error('❌ Database trigger function failed:', error);
                console.error('❌ This suggests the trigger function was not properly installed');
            } else {
                console.log('✅ Database trigger function executed successfully');
                console.log('🔄 Now checking if notification was queued...');
                
                // Check if the notification was actually queued
                setTimeout(async () => {
                    await pushNotificationProcessor.processOnce();
                }, 1000);
            }
        } catch (err) {
            console.error('❌ Error testing database trigger:', err);
        }
    };

    // Manual queue entry with real notification ID
    (window as any).manualQueueTest = async () => {
        console.log('🧪 Manually adding notification to queue...');
        try {
            const currentUser = await (window as any).persistentAuth?.getCurrentUser();
            if (!currentUser) {
                console.error('❌ No current user found');
                return;
            }

            const testEntry = {
                notification_id: '0d1dc630-c253-4269-b30b-f416a747e69e',
                user_id: currentUser.id,
                device_id: 'manual-test-device',
                status: 'pending',
                payload: {
                    title: 'Test Notification',
                    body: 'This is a manual test from the browser console',
                    icon: '/favicon.png',
                    data: {
                        notification_id: '0d1dc630-c253-4269-b30b-f416a747e69e',
                        url: '/notifications'
                    }
                }
            };

            const { data, error } = await supabase
                .from('notification_queue')
                .insert([testEntry])
                .select();

            if (error) {
                console.error('❌ Failed to manually queue notification:', error);
            } else {
                console.log('✅ Manually queued notification:', data);
                console.log('🔄 Now processing queue...');
                setTimeout(async () => {
                    await pushNotificationProcessor.processOnce();
                }, 1000);
            }
        } catch (err) {
            console.error('❌ Manual queue test failed:', err);
        }
    };

    // Quickly test the trigger with your existing notification
    (window as any).testExistingNotification = async () => {
        console.log('🧪 Testing trigger function with existing notification...');
        try {
            // Use the notification ID from your console log
            const notificationId = '0d1dc630-c253-4269-b30b-f416a747e69e';
            
            console.log(`🔍 Calling queue_push_notification function for notification: ${notificationId}`);
            
            const { data, error } = await supabase.rpc('queue_push_notification', {
                p_notification_id: notificationId
            });

            if (error) {
                console.error('❌ Trigger function failed:', error);
                console.error('❌ Error details:', error.message);
                if (error.message.includes('function') && error.message.includes('does not exist')) {
                    console.log('💡 The queue_push_notification function was not properly applied to the database');
                }
            } else {
                console.log('✅ Trigger function executed successfully');
                console.log('📋 Result:', data);
                console.log('🔄 Now checking queue...');
                
                // Wait and then check the queue
                setTimeout(async () => {
                    await pushNotificationProcessor.processOnce();
                }, 2000);
            }
        } catch (err) {
            console.error('❌ Test failed with error:', err);
        }
    };

    // Test basic browser notification functionality
    (window as any).testBasicNotification = async () => {
        console.log('🧪 Testing basic browser notification...');
        try {
            console.log('🔍 Notification permission:', Notification.permission);
            
            if (Notification.permission !== 'granted') {
                console.log('📝 Requesting notification permission...');
                const permission = await Notification.requestPermission();
                console.log('📋 Permission result:', permission);
                
                if (permission !== 'granted') {
                    console.error('❌ Permission denied');
                    return;
                }
            }

            // Test direct browser notification first
            console.log('🔔 Creating direct browser notification...');
            const directNotification = new Notification('Direct Test', {
                body: 'This is a direct browser notification test',
                icon: '/favicon.png'
            });

            directNotification.onclick = () => {
                console.log('🖱️ Direct notification clicked');
                directNotification.close();
            };

            setTimeout(() => directNotification.close(), 5000);

            // Test service worker notification
            if ('serviceWorker' in navigator) {
                console.log('🔔 Creating service worker notification...');
                const registration = await navigator.serviceWorker.ready;
                await registration.showNotification('Service Worker Test', {
                    body: 'This is a service worker notification test',
                    icon: '/favicon.png',
                    requireInteraction: true
                });
                console.log('✅ Service worker notification created');
            }

        } catch (err) {
            console.error('❌ Basic notification test failed:', err);
        }
    };
}