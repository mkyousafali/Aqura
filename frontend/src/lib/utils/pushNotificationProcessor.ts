// Import shared supabase client instead of creating a new one
import { supabaseAdmin } from './supabase';

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

        console.log('🚀 Starting push notification processor');
        this.isProcessing = true;
        
        // Process queue immediately
        this.processQueue().catch(err => {
            console.error('❌ Initial queue processing failed:', err);
        });

        // Set up periodic processing every 30 seconds
        this.intervalId = setInterval(async () => {
            if (this.isProcessing) {
                try {
                    await this.processQueue();
                } catch (error) {
                    console.error('❌ Periodic queue processing failed:', error);
                }
            }
        }, 30000); // Process every 30 seconds

        // Set up daily cleanup (run every 24 hours)
        setInterval(async () => {
            if (this.isProcessing) {
                try {
                    await this.cleanupOldQueueEntries(7); // Clean up entries older than 7 days
                } catch (error) {
                    console.error('❌ Periodic cleanup failed:', error);
                }
            }
        }, 24 * 60 * 60 * 1000); // Run once per day
        
        console.log('✅ Push notification processor started successfully with periodic processing');
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
            console.log('🔍 Processing notification queue');

            // Get pending notifications from queue
            const { data: queuedNotifications, error } = await supabaseAdmin
                .from('notification_queue')
                .select(`
                    id,
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    payload,
                    status,
                    created_at
                `)
                .eq('status', 'pending')
                .order('created_at', { ascending: true }) // Process oldest first (FIFO)
                .limit(10); // Reduced batch size for more frequent processing

            if (error) {
                console.error('❌ Error fetching queued notifications:', error);
                // If it's a connection error, stop processing for now
                if (error.message?.includes('Failed to fetch') || error.message?.includes('ERR_CONNECTION_CLOSED')) {
                    console.warn('🔌 Connection error detected, pausing queue processing');
                    return;
                }
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
                    const { data: subscription, error: subError } = await supabaseAdmin
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
                        await supabaseAdmin
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
                    await supabaseAdmin
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

            // Use the browser's notification API instead of web-push library
            if ('serviceWorker' in navigator && 'Notification' in window) {
                console.log('🔍 Service Worker and Notification API available');
                console.log('🔍 About to get service worker registration...');
                console.log('🔍 navigator.serviceWorker:', navigator.serviceWorker);
                console.log('🔍 navigator.serviceWorker.ready:', navigator.serviceWorker.ready);
                
                try {
                    // Get the service worker registration with timeout
                    console.log('🔍 Getting service worker registration...');
                    
                    // Production-friendly timeout: longer wait for production deployments
                    const isProduction = !window.location.hostname.includes('localhost') && !window.location.hostname.includes('127.0.0.1');
                    const timeoutMs = isProduction ? 10000 : 8000; // Reduced to 10s for production, 8s for development
                    
                    console.log(`🔍 Using ${timeoutMs/1000}s timeout for ${isProduction ? 'production' : 'development'} environment`);
                    
                    let registration: ServiceWorkerRegistration;
                    
                    // First try to get existing registration
                    try {
                        // Check for immediate availability first (optimization for production)
                        const existingRegistrations = await navigator.serviceWorker.getRegistrations();
                        console.log(`🔍 Found ${existingRegistrations.length} existing registrations`);
                        
                        // Look for an active registration first (faster than waiting for ready)
                        const activeRegistration = existingRegistrations.find(reg => 
                            reg.active && reg.scope.includes(window.location.origin)
                        );
                        
                        if (activeRegistration) {
                            console.log('✅ Found immediate active Service Worker registration');
                            registration = activeRegistration;
                        } else {
                            // Fallback to ready promise with timeout
                            const registrationPromise = navigator.serviceWorker.ready;
                            const timeoutPromise = new Promise((_, reject) => 
                                setTimeout(() => reject(new Error(`Service Worker registration timeout after ${timeoutMs/1000}s`)), timeoutMs)
                            );
                            
                            registration = await Promise.race([registrationPromise, timeoutPromise]) as ServiceWorkerRegistration;
                            console.log('🔍 Service Worker ready via navigator.serviceWorker.ready');
                        }
                    } catch (readyError) {
                        console.warn('⚠️ Service Worker not ready, attempting manual registration...', readyError);
                        
                        // Fallback: Try to register the service worker manually
                        try {
                            // Check for existing registrations first
                            const existingRegistrations = await navigator.serviceWorker.getRegistrations();
                            console.log(`🔍 Found ${existingRegistrations.length} existing registrations`);
                            
                            for (const existing of existingRegistrations) {
                                console.log(`🔍 Existing registration scope: ${existing.scope}, active: ${!!existing.active}`);
                                if (existing.active && existing.scope.includes(window.location.origin)) {
                                    console.log('🔍 Found active Service Worker registration, using it');
                                    registration = existing;
                                    break;
                                }
                            }
                            
                            if (!registration) {
                                // Use the VitePWA generated service worker path consistently
                                const swPath = isProduction ? '/sw.js' : '/sw-advanced.js';
                                console.log(`🔍 Attempting to register SW at: ${swPath}`);
                                
                                registration = await navigator.serviceWorker.register(swPath, {
                                    scope: '/',
                                    updateViaCache: 'none'
                                });
                                
                                console.log('🔍 Service Worker registered manually:', registration);
                                
                                // Wait for it to become ready
                                await registration.update(); // Force update check
                                
                                if (registration.active) {
                                    console.log('🔍 Service Worker is now active');
                                } else if (registration.waiting) {
                                    console.log('🔍 Service Worker is waiting, attempting to activate...');
                                    registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                                    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for activation
                                } else if (registration.installing) {
                                    console.log('🔍 Service Worker is installing, waiting for activation...');
                                    await new Promise((resolve) => {
                                        const checkState = () => {
                                            if (registration.installing?.state === 'activated' || registration.active) {
                                                resolve(true);
                                            } else {
                                                setTimeout(checkState, 100);
                                            }
                                        };
                                        checkState();
                                    });
                                }
                            }
                        } catch (registerError) {
                            console.error('❌ Failed to manually register Service Worker:', registerError);
                            throw readyError; // Throw original error
                        }
                    }
                    console.log('🔍 Service Worker ready:', registration);
                    console.log('🔍 Service Worker state:', registration.active?.state);
                    console.log('🔍 Service Worker scope:', registration.scope);
                    
                    // Wait for Service Worker to be fully active if it's not yet
                    if (!registration.active && registration.waiting) {
                        console.log('🔄 Service Worker is waiting, activating...');
                        registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                        
                        // Wait for activation
                        await new Promise((resolve) => {
                            const checkActive = () => {
                                if (registration.active) {
                                    console.log('✅ Service Worker activated successfully');
                                    resolve(true);
                                } else {
                                    setTimeout(checkActive, 100);
                                }
                            };
                            setTimeout(checkActive, 500); // Initial delay
                        });
                    } else if (!registration.active && registration.installing) {
                        console.log('🔄 Service Worker is installing, waiting for activation...');
                        await new Promise((resolve) => {
                            const checkActive = () => {
                                if (registration.active) {
                                    console.log('✅ Service Worker installed and activated');
                                    resolve(true);
                                } else {
                                    setTimeout(checkActive, 100);
                                }
                            };
                            setTimeout(checkActive, 1000); // Wait longer for installation
                        });
                    }
                    
                    // Final check - ensure we have an active Service Worker
                    if (!registration.active) {
                        throw new Error('Service Worker registration succeeded but no active worker available');
                    }
                    
                    // Enhanced service worker debugging
                    console.log('🔍 Service Worker details:', {
                        active: !!registration.active,
                        installing: !!registration.installing,
                        waiting: !!registration.waiting,
                        scope: registration.scope,
                        updateViaCache: registration.updateViaCache
                    });
                    
                    if (registration.active) {
                        console.log('🔍 Active SW details:', {
                            scriptURL: registration.active.scriptURL,
                            state: registration.active.state
                        });
                    }
                    
                    // Check if notification API is working
                    console.log('🔍 Notification API test:', {
                        permission: Notification.permission,
                        prototype: Object.getOwnPropertyNames(Notification.prototype)
                    });
                    
                    // Check if service worker is actually active
                    if (!registration.active) {
                        console.warn('⚠️ Service worker registration exists but no active worker found');
                        throw new Error('No active service worker available');
                    }
                    
                    console.log('✅ Service worker is active and ready');
                    
                    // Show notification through service worker
                    console.log('🔔 Showing notification with title:', queueItem.payload.title);
                    console.log('🔔 Notification options:', {
                        body: queueItem.payload.body,
                        icon: queueItem.payload.icon,
                        badge: queueItem.payload.badge,
                        data: queueItem.payload.data,
                        tag: `notification-${queueItem.notification_id}`,
                        requireInteraction: true,
                        silent: false
                    });
                    
                    // Try multiple notification approaches for better compatibility
                    const notificationOptions = {
                        body: queueItem.payload.body,
                        icon: queueItem.payload.icon || '/icons/icon-192x192.png',
                        badge: queueItem.payload.badge || '/icons/icon-96x96.png',
                        data: queueItem.payload.data,
                        tag: `notification-${queueItem.notification_id}`,
                        requireInteraction: true,
                        silent: false,
                        timestamp: Date.now(),
                        vibrate: [200, 100, 200],
                        actions: [
                            {
                                action: 'view',
                                title: 'View'
                            },
                            {
                                action: 'dismiss',
                                title: 'Dismiss'
                            }
                        ]
                    };

                    console.log('🔔 Attempting notification with enhanced options:', notificationOptions);
                    
                    try {
                        await registration.showNotification(queueItem.payload.title, notificationOptions);
                        console.log('🎉 Service Worker notification shown successfully!');
                        
                        // Also try direct browser notification as fallback
                        console.log('🔔 Also trying direct browser notification as backup...');
                        const directNotification = new Notification(queueItem.payload.title, {
                            body: queueItem.payload.body,
                            icon: queueItem.payload.icon || '/icons/icon-192x192.png',
                            tag: `direct-notification-${queueItem.notification_id}`,
                            requireInteraction: true,
                            silent: false
                        });
                        
                        directNotification.onclick = () => {
                            console.log('🖱️ Direct notification clicked');
                            window.focus();
                            directNotification.close();
                        };
                        
                        console.log('🎉 Direct browser notification also created!');
                        
                    } catch (swError) {
                        console.error('❌ Service Worker notification failed:', swError);
                        
                        // Fallback to direct browser notification
                        console.log('🔄 Falling back to direct browser notification...');
                        const fallbackNotification = new Notification(queueItem.payload.title, {
                            body: queueItem.payload.body,
                            icon: queueItem.payload.icon || '/icons/icon-192x192.png',
                            tag: `fallback-notification-${queueItem.notification_id}`,
                            requireInteraction: true,
                            silent: false
                        });
                        
                        fallbackNotification.onclick = () => {
                            console.log('🖱️ Fallback notification clicked');
                            window.focus();
                            fallbackNotification.close();
                        };
                        
                        console.log('🎉 Fallback notification created successfully!');
                    }
                    
                    // Also send a test message to Service Worker to verify communication
                    if (registration.active) {
                        const messageChannel = new MessageChannel();
                        messageChannel.port1.onmessage = (event) => {
                            console.log('📨 Message from SW about notification:', event.data);
                        };
                        
                        registration.active.postMessage({
                            type: 'SHOW_NOTIFICATION',
                            title: 'Test from Client',
                            body: 'Testing SW notification capability',
                            tag: 'test-notification'
                        }, [messageChannel.port2]);
                    }
                } catch (swError) {
                    console.error('❌ Service Worker notification failed:', swError);
                    console.error('❌ SW Error details:', {
                        name: swError.name,
                        message: swError.message,
                        stack: swError.stack
                    });
                    console.warn('⚠️ Service Worker notification failed, trying direct notification:', swError);
                    
                    // Fallback to direct browser notification
                    console.log('🔔 Creating direct browser notification as fallback...');
                    const directNotification = new Notification(queueItem.payload.title, {
                        body: queueItem.payload.body,
                        icon: queueItem.payload.icon,
                        tag: `notification-${queueItem.notification_id}`,
                        requireInteraction: true
                    });

                    // Handle click event for direct notification
                    directNotification.onclick = () => {
                        console.log('🖱️ Direct notification clicked');
                        if (queueItem.payload.data?.url) {
                            window.open(queueItem.payload.data.url, '_blank');
                        }
                        directNotification.close();
                    };
                    
                    console.log('🎉 Direct notification created as fallback!');
                }
            } else if ('Notification' in window) {
                console.log('🔍 Using direct browser notification (no service worker)');
                
                // Direct browser notification without service worker
                const directNotification = new Notification(queueItem.payload.title, {
                    body: queueItem.payload.body,
                    icon: queueItem.payload.icon,
                    tag: `notification-${queueItem.notification_id}`,
                    requireInteraction: true
                });

                // Handle click event
                directNotification.onclick = () => {
                    console.log('🖱️ Direct notification clicked');
                    if (queueItem.payload.data?.url) {
                        window.open(queueItem.payload.data.url, '_blank');
                    }
                    directNotification.close();
                };
                
                console.log('🎉 Direct notification shown successfully!');
            } else {
                console.error('❌ Notifications not supported in this browser');
                throw new Error('Notifications not supported');
            }

            // Mark as sent
            await supabaseAdmin
                .from('notification_queue')
                .update({ 
                    status: 'sent',
                    sent_at: new Date().toISOString()
                })
                .eq('id', queueItem.id);

            console.log(`✅ Push notification ${queueItem.id} sent successfully`);

            // Delete all other pending notifications for this user+notification combination
            // Once a user receives a notification on ANY device, they don't need it on other devices
            // Deleting instead of marking as delivered keeps the queue table clean
            try {
                console.log(`🗑️ Deleting other pending notifications for user ${queueItem.user_id} and notification ${queueItem.notification_id}...`);
                
                const { data: deletedNotifications, error: deleteError } = await supabaseAdmin
                    .from('notification_queue')
                    .delete()
                    .eq('notification_id', queueItem.notification_id)
                    .eq('user_id', queueItem.user_id)
                    .eq('status', 'pending')
                    .neq('id', queueItem.id) // Don't delete the current notification
                    .select(); // Select to get count of deleted items

                if (deleteError) {
                    console.error('❌ Error deleting duplicate pending notifications:', deleteError);
                } else {
                    console.log(`✅ Deleted ${deletedNotifications?.length || 0} duplicate pending notifications for user`);
                    console.log('🧹 Queue table cleaned up - duplicate entries removed permanently');
                }
            } catch (deleteError) {
                console.error('❌ Error in auto-delete process:', deleteError);
            }

        } catch (error) {
            console.error(`❌ Failed to send push notification ${queueItem.id}:`, error);

            // Mark as failed
            await supabaseAdmin
                .from('notification_queue')
                .update({ 
                    status: 'failed',
                    error_message: error instanceof Error ? error.message : 'Unknown error'
                })
                .eq('id', queueItem.id);
        }
    }

    /**
     * Clean up old processed notifications from the queue table
     * Removes entries older than specified days that are 'sent', 'delivered', or 'failed'
     */
    async cleanupOldQueueEntries(olderThanDays: number = 7) {
        try {
            console.log(`🧹 Cleaning up queue entries older than ${olderThanDays} days...`);
            
            const cutoffDate = new Date();
            cutoffDate.setDate(cutoffDate.getDate() - olderThanDays);
            
            const { data: deletedEntries, error } = await supabaseAdmin
                .from('notification_queue')
                .delete()
                .in('status', ['sent', 'delivered', 'failed'])
                .lt('created_at', cutoffDate.toISOString())
                .select(); // Get count of deleted items
                
            if (error) {
                console.error('❌ Error cleaning up old queue entries:', error);
            } else {
                console.log(`✅ Cleaned up ${deletedEntries?.length || 0} old queue entries`);
                console.log('🗃️ Queue table optimized - old processed notifications removed');
            }
            
        } catch (error) {
            console.error('❌ Error in cleanup process:', error);
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
            const { data, error } = await supabaseAdmin
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

    // Add cleanup function for old queue entries
    (window as any).cleanupOldNotifications = (days = 7) => {
        pushNotificationProcessor.cleanupOldQueueEntries(days);
        console.log(`🧹 Cleaning up notifications older than ${days} days...`);
    };

    // Add function to manually delete duplicate pending notifications for testing
    (window as any).deleteDuplicateNotifications = async (notificationId: string, userId: string) => {
        console.log(`🗑️ Manually deleting duplicate notifications for notification ${notificationId} and user ${userId}...`);
        try {
            const { data: deletedEntries, error } = await supabaseAdmin
                .from('notification_queue')
                .delete()
                .eq('notification_id', notificationId)
                .eq('user_id', userId)
                .eq('status', 'pending')
                .select();

            if (error) {
                console.error('❌ Error deleting duplicates:', error);
            } else {
                console.log(`✅ Deleted ${deletedEntries?.length || 0} duplicate pending notifications`);
            }
        } catch (error) {
            console.error('❌ Manual delete failed:', error);
        }
    };

    // Test if database trigger is working by manually calling the queue function
    (window as any).testDatabaseTrigger = async () => {
        console.log('🧪 Testing if database trigger function exists and works...');
        try {
            // Call the queue_push_notification function directly with the notification ID from your console
            const { data, error } = await supabaseAdmin.rpc('queue_push_notification', {
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

            const { data, error } = await supabaseAdmin
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
            
            const { data, error } = await supabaseAdmin.rpc('queue_push_notification', {
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

    // Helper function to queue the latest notification manually
    (window as any).queueLatestNotification = async () => {
        console.log('🔍 Looking for the latest notification to queue...');
        try {
            // Get the most recent notification
            const { data: latestNotification, error } = await supabaseAdmin
                .from('notifications')
                .select('id, title, created_at')
                .order('created_at', { ascending: false })
                .limit(1)
                .single();

            if (error || !latestNotification) {
                console.error('❌ No notifications found:', error);
                return;
            }

            console.log('📋 Latest notification:', latestNotification);

            // Queue it using the database function
            const { data: queueResult, error: queueError } = await supabaseAdmin.rpc('queue_push_notification', {
                p_notification_id: latestNotification.id
            });

            if (queueError) {
                console.error('❌ Failed to queue notification:', queueError);
            } else {
                console.log('✅ Notification queued successfully:', queueResult);
                console.log('🔄 Processing queue now...');
                
                // Process the queue immediately
                setTimeout(async () => {
                    await pushNotificationProcessor.processOnce();
                }, 1000);
            }
        } catch (err) {
            console.error('❌ Error queuing latest notification:', err);
        }
    };

    // Auto-queue function that can be called after creating notifications
    (window as any).autoQueueNewNotification = async (notificationId: string) => {
        console.log('🔄 Auto-queuing notification:', notificationId);
        try {
            const { data: queueResult, error: queueError } = await supabaseAdmin.rpc('queue_push_notification', {
                p_notification_id: notificationId
            });

            if (queueError) {
                console.error('❌ Auto-queue failed:', queueError);
            } else {
                console.log('✅ Auto-queued successfully:', queueResult);
                // Process immediately
                setTimeout(async () => {
                    await pushNotificationProcessor.processOnce();
                }, 500);
            }
        } catch (err) {
            console.error('❌ Auto-queue error:', err);
        }
    };
}