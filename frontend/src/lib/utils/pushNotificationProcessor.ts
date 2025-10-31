// Import shared supabase client instead of creating a new one
import { supabase } from './supabase'; // Changed from supabase to supabase for user auth

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
    private static readonly VERSION = '3.0';
    private isProcessing = false;
    private intervalId: NodeJS.Timeout | null = null;

    /**
     * Start the background processor
     * NOTE: Server-side processing via Edge Functions is temporarily disabled due to Web Push Protocol complexity
     * Client-side processor is RE-ENABLED to handle notifications when app is open
     */
    start() {
        console.log(`ℹ️ Push notification processor v${PushNotificationProcessor.VERSION} - Client-side processing ENABLED`);
        console.log(`📱 Notifications will appear when app is open (browser notifications)`);
        console.log(`⚠️ Note: Notifications require app to be open. Edge Function approach needs more work.`);
        
        // Client-side processing RE-ENABLED
        
        if (this.isProcessing) {
            return;
        }

        console.log(`🚀 Starting push notification processor v${PushNotificationProcessor.VERSION}`);
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

        // Daily cleanup disabled to prevent notification deletion
        // setInterval(async () => {
        //     if (this.isProcessing) {
        //         try {
        //             await this.cleanupOldQueueEntries(7); // Clean up entries older than 7 days
        //         } catch (error) {
        //             console.error('❌ Periodic cleanup failed:', error);
        //         }
        //     }
        // }, 24 * 60 * 60 * 1000); // Run once per day
        
        
    }

    /**
     * Stop the background processor
     */
    stop() {
        
        this.isProcessing = false;
        
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    }

    /**
     * Preventive cleanup disabled to prevent notification deletion
     */
    private async cleanupExcessiveFailedNotifications() {
        // Cleanup disabled - was deleting notifications before they could be processed
        
        return;
    }

    /**
     * Process pending notifications in the queue with retry logic
     */
    private async processQueue() {
        try {
            // [v3.0] Preventive cleanup disabled to prevent notification deletion
            // await this.cleanupExcessiveFailedNotifications();

            // CRITICAL FIX: Get current user to only process their notifications
            const currentUser = await supabase.auth.getUser();
            if (!currentUser.data.user) {
                console.warn('⚠️ No authenticated user - skipping queue processing');
                return;
            }
            const currentUserId = currentUser.data.user.id;

            // Get pending notifications and those ready for retry FOR CURRENT USER ONLY
            const now = new Date().toISOString();
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
                    retry_count,
                    next_retry_at,
                    last_attempt_at,
                    push_subscriptions!inner(
                        endpoint,
                        p256dh,
                        auth,
                        is_active
                    )
                `)
                .eq('user_id', currentUserId) // CRITICAL: Only process current user's notifications
                .or(`status.eq.pending,and(status.eq.retry,next_retry_at.lte.${now})`)
                .eq('push_subscriptions.is_active', true)
                .order('created_at', { ascending: true }) // Process oldest first (FIFO)
                .limit(10);

            if (error) {
                console.error('❌ Error fetching queued notifications:', error);
                // If it's a connection error, stop processing for now
                if (error.message?.includes('Failed to fetch') || error.message?.includes('ERR_CONNECTION_CLOSED')) {
                    console.warn('🔌 Connection error detected, pausing queue processing');
                    return;
                }
                return;
            }

            const totalNotifications = queuedNotifications?.length || 0;
            const pendingCount = queuedNotifications?.filter(n => n.status === 'pending').length || 0;
            const retryCount = queuedNotifications?.filter(n => n.status === 'retry').length || 0;
            
            console.log(`📊 Found ${totalNotifications} notifications in queue FOR USER ${currentUserId} (${pendingCount} pending, ${retryCount} ready for retry)`);
            

            if (!queuedNotifications || queuedNotifications.length === 0) {
                return; // Don't log if no notifications (too verbose)
            }

            console.log(`📬 Processing ${queuedNotifications.length} notifications FOR CURRENT USER...`);
            

            // Process each notification individually with retry logic
                for (const queueItem of queuedNotifications) {
                try {
                    // Check if subscription exists and is still active
                    let needsFallback = false;
                    
                    if (!queueItem.push_subscriptions || !queueItem.push_subscriptions.is_active) {
                        console.warn(`⚠️ Subscription for queue item ${queueItem.id} is not active or not found - trying fallback`);
                        needsFallback = true;
                    }
                    
                    // Additional check: verify subscription ID exists in subscription table
                    if (!needsFallback && queueItem.push_subscription_id) {
                        const { data: subscriptionCheck, error: checkError } = await supabase
                            .from('push_subscriptions')
                            .select('id, is_active')
                            .eq('id', queueItem.push_subscription_id)
                            .single();
                            
                        if (checkError || !subscriptionCheck || !subscriptionCheck.is_active) {
                            console.warn(`⚠️ Subscription ID ${queueItem.push_subscription_id} not found or inactive - trying fallback`);
                            needsFallback = true;
                        }
                    }
                    
                    if (needsFallback) {
                        // Fallback: Find latest active subscription for this user
                        const fallbackSuccess = await this.processFallbackSubscription(queueItem);
                        if (!fallbackSuccess) {
                            // Mark as failed if no fallback available
                            await supabase
                                .from('notification_queue')
                                .update({ 
                                    status: 'failed',
                                    error_message: 'No active subscription found for user'
                                })
                                .eq('id', queueItem.id);
                            continue;
                        }
                    }
                    
                    await this.processNotificationWithRetry(queueItem);
                } catch (error) {
                    console.error(`❌ Error processing queue item ${queueItem.id}:`, error);
                }
            }        } catch (error) {
            console.error('❌ Error processing notification queue:', error);
        }
    }

    /**
     * Process fallback subscription when device_id or push_subscription_id not found/inactive
     */
    private async processFallbackSubscription(queueItem: any): Promise<boolean> {
        try {
            console.log(`🔄 Looking for fallback subscription for user ${queueItem.user_id}`);
            console.log(`   Current queue item - Device: ${queueItem.device_id}, Subscription: ${queueItem.push_subscription_id}`);
            
            // Find latest active subscription for this user
            const { data: latestSubscription, error } = await supabase
                .from('push_subscriptions')
                .select('id, device_id, endpoint, p256dh, auth, device_type, last_seen, created_at')
                .eq('user_id', queueItem.user_id)
                .eq('is_active', true)
                .order('last_seen', { ascending: false })
                .limit(1)
                .single();

            if (error || !latestSubscription) {
                console.warn(`⚠️ No active subscription found for user ${queueItem.user_id}`);
                return false;
            }

            console.log(`✅ Found fallback subscription:`);
            console.log(`   Device: ${latestSubscription.device_type} (${latestSubscription.device_id})`);
            console.log(`   Subscription ID: ${latestSubscription.id}`);
            console.log(`   Last seen: ${latestSubscription.last_seen}`);

            // Check if this is actually different from current queue item
            const isDeviceIdDifferent = queueItem.device_id !== latestSubscription.device_id;
            const isSubscriptionIdDifferent = queueItem.push_subscription_id !== latestSubscription.id;
            
            if (isDeviceIdDifferent || isSubscriptionIdDifferent) {
                console.log(`🔄 Updating queue item ${queueItem.id}:`);
                if (isDeviceIdDifferent) {
                    console.log(`   Device ID: ${queueItem.device_id} → ${latestSubscription.device_id}`);
                }
                if (isSubscriptionIdDifferent) {
                    console.log(`   Subscription ID: ${queueItem.push_subscription_id} → ${latestSubscription.id}`);
                }

                // Update the queue item with new subscription details
                const { error: updateError } = await supabase
                    .from('notification_queue')
                    .update({
                        push_subscription_id: latestSubscription.id,
                        device_id: latestSubscription.device_id
                    })
                    .eq('id', queueItem.id);

                if (updateError) {
                    console.error(`❌ Failed to update queue item with fallback subscription:`, updateError);
                    return false;
                }

                // Update the queue item object for immediate processing
                queueItem.push_subscription_id = latestSubscription.id;
                queueItem.device_id = latestSubscription.device_id;
                queueItem.push_subscriptions = {
                    endpoint: latestSubscription.endpoint,
                    p256dh: latestSubscription.p256dh,
                    auth: latestSubscription.auth,
                    is_active: true
                };

                console.log(`✅ Queue item ${queueItem.id} updated with fallback subscription`);
            } else {
                console.log(`ℹ️ Queue item already has the latest subscription details`);
                // Just update the push_subscriptions object for processing
                queueItem.push_subscriptions = {
                    endpoint: latestSubscription.endpoint,
                    p256dh: latestSubscription.p256dh,
                    auth: latestSubscription.auth,
                    is_active: true
                };
            }
            
            return true;

        } catch (error) {
            console.error(`❌ Error in fallback subscription process:`, error);
            return false;
        }
    }

    /**
     * Check for notifications that need fallback queue creation
     */
    private async checkAndCreateFallbackQueues(): Promise<void> {
        try {
            // Find recent notifications (last 24 hours) that might not have queue entries
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 1);

            const { data: recentNotifications, error } = await supabase
                .from('notifications')
                .select('id, title, created_at, target_type, target_users')
                .gte('created_at', yesterday.toISOString())
                .order('created_at', { ascending: false })
                .limit(10);

            if (error || !recentNotifications || recentNotifications.length === 0) {
                return;
            }

            for (const notification of recentNotifications) {
                // Check if this notification has any queue entries
                const { data: existingQueue, error: queueError } = await supabase
                    .from('notification_queue')
                    .select('id')
                    .eq('notification_id', notification.id)
                    .limit(1);

                if (queueError) continue;

                if (!existingQueue || existingQueue.length === 0) {
                    console.log(`🔄 Creating fallback queue for notification ${notification.id}: ${notification.title}`);
                    
                    // Create queue entries for this notification
                    const { error: createError } = await supabase
                        .rpc('queue_push_notification', {
                            p_notification_id: notification.id
                        });

                    if (createError) {
                        console.error(`❌ Failed to create fallback queue for notification ${notification.id}:`, createError);
                    } else {
                        console.log(`✅ Fallback queue created for notification ${notification.id}`);
                    }
                }
            }

        } catch (error) {
            console.error(`❌ Error in fallback queue creation:`, error);
        }
    }

    /**
     * Process a single notification with retry logic (3 attempts, 10-second intervals)
     */
    private async processNotificationWithRetry(queueItem: any) {
        try {
            const maxRetries = 3;
            const retryIntervalSeconds = 10;
            const currentRetryCount = queueItem.retry_count || 0;
            
            console.log(`🎯 Processing notification ${queueItem.id} (attempt ${currentRetryCount + 1}/${maxRetries})`);
            
            // Update status to indicate we're processing
            await supabase
                .from('notification_queue')
                .update({ 
                    status: 'processing',
                    last_attempt_at: new Date().toISOString()
                })
                .eq('id', queueItem.id);

            // Get push subscription details
            if (!queueItem.push_subscription_id) {
                console.warn('⚠️ Queue item has no push_subscription_id:', queueItem.id);
                await this.markNotificationFailed(queueItem.id, 'No push subscription ID');
                return;
            }

            const { data: subscription, error: subError } = await supabase
                .from('push_subscriptions')
                .select('endpoint, p256dh, auth')
                .eq('id', queueItem.push_subscription_id)
                .eq('is_active', true)
                .single();

            if (!subscription || subError) {
                console.warn('⚠️ No active push subscription found for queue item:', queueItem.id, 'subscription_id:', queueItem.push_subscription_id);
                await this.markNotificationFailed(queueItem.id, 'Push subscription not found or inactive');
                return;
            }

            
            
            try {
                // Attempt to send the notification
                await this.sendPushNotification(queueItem);
                
                // If successful, mark as sent and clean up other pending notifications for this user
                await supabase
                    .from('notification_queue')
                    .update({ 
                        status: 'sent',
                        sent_at: new Date().toISOString()
                    })
                    .eq('id', queueItem.id);

                console.log(`✅ Notification ${queueItem.id} sent successfully on attempt ${currentRetryCount + 1}`);
                
                // Clean up disabled to prevent notification deletion
                // await this.cleanupDuplicateNotifications(queueItem);
                
            } catch (error) {
                console.error(`❌ Attempt ${currentRetryCount + 1} failed for notification ${queueItem.id}:`, error);
                
                // Handle retry logic
                if (currentRetryCount < maxRetries - 1) {
                    // Calculate next retry time (10 seconds from now)
                    const nextRetryAt = new Date();
                    nextRetryAt.setSeconds(nextRetryAt.getSeconds() + retryIntervalSeconds);
                    
                    // Update to retry status with incremented retry count
                    await supabase
                        .from('notification_queue')
                        .update({ 
                            status: 'retry',
                            retry_count: currentRetryCount + 1,
                            next_retry_at: nextRetryAt.toISOString(),
                            error_message: error instanceof Error ? error.message : 'Unknown error'
                        })
                        .eq('id', queueItem.id);
                    
                    console.log(`🔄 Notification ${queueItem.id} scheduled for retry ${currentRetryCount + 2}/${maxRetries} in ${retryIntervalSeconds} seconds`);
                } else {
                    // Max retries reached, mark as permanently failed
                    await this.markNotificationFailed(queueItem.id, `Failed after ${maxRetries} attempts: ${error instanceof Error ? error.message : 'Unknown error'}`);
                    console.log(`❌ Notification ${queueItem.id} permanently failed after ${maxRetries} attempts`);
                }
            }
            
        } catch (error) {
            console.error(`❌ Error processing notification ${queueItem.id}:`, error);
            await this.markNotificationFailed(queueItem.id, `Processing error: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }

    /**
     * Cleanup disabled to prevent notification deletion
     */
    private async cleanupDuplicateNotifications(queueItem: any) {
        // Cleanup disabled - was deleting valid pending notifications
        
        return;
    }

    /**
     * Send a single push notification using Service Worker
     */
    private async sendPushNotification(queueItem: QueuedNotification) {
        // Define variables at function scope to avoid scope issues in nested error handling
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        const isPWA = window.matchMedia('(display-mode: standalone)').matches || 
                     (navigator as any).standalone || 
                     window.location.search.includes('utm_source=pwa') ||
                     document.referrer.includes('android-app://');
        let registration: ServiceWorkerRegistration | undefined;
        let notificationOptions: any;
        
        try {
            console.log(`📤 Sending push notification ${queueItem.id} to device ${queueItem.device_id}...`);
            

            // Check notification permissions first
            
            
            if (Notification.permission !== 'granted') {
                console.error('❌ Notification permission not granted:', Notification.permission);
                throw new Error(`Notification permission not granted: ${Notification.permission}`);
            }

            // Use the browser's notification API instead of web-push library
            if ('serviceWorker' in navigator && 'Notification' in window) {
                
                
                
                
                
                try {
                    // Get the service worker registration with timeout
                    
                    
                    // Production-friendly timeout: longer wait for production deployments
                    const isProduction = !window.location.hostname.includes('localhost') && !window.location.hostname.includes('127.0.0.1');
                    const timeoutMs = isProduction ? 3000 : 8000; // Reduced to 3s for production, 8s for development
                    
                    console.log(`🔍 Using ${timeoutMs/1000}s timeout for ${isProduction ? 'production' : 'development'} environment`);
                    
                    // First try to get existing registration
                    try {
                        // Check for immediate availability first (optimization for production)
                        const existingRegistrations = await navigator.serviceWorker.getRegistrations();
                        console.log(`🔍 Found ${existingRegistrations.length} existing registrations`);
                        
                        // Look for any registration first (active, waiting, or installing) - more lenient in production
                        const availableRegistration = existingRegistrations.find(reg => 
                            reg.scope.includes(window.location.origin) && (reg.active || reg.waiting || reg.installing)
                        );
                        
                        if (availableRegistration) {
                            
                            console.log('🔍 Registration state:', {
                                active: !!availableRegistration.active,
                                waiting: !!availableRegistration.waiting,
                                installing: !!availableRegistration.installing
                            });
                            registration = availableRegistration;
                        } else {
                            // Fallback to ready promise with timeout
                            const registrationPromise = navigator.serviceWorker.ready;
                            const timeoutPromise = new Promise((_, reject) => 
                                setTimeout(() => reject(new Error(`Service Worker registration timeout after ${timeoutMs/1000}s`)), timeoutMs)
                            );
                            
                            registration = await Promise.race([registrationPromise, timeoutPromise]) as ServiceWorkerRegistration;
                            
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
                                    
                                    registration = existing;
                                    break;
                                }
                            }
                            
                            if (!registration) {
                                // Try our custom service worker first since it's more reliable in production
                                
                                
                                try {
                                    registration = await navigator.serviceWorker.register('/sw.js', {
                                        scope: '/',
                                        updateViaCache: 'none'
                                    });
                                    
                                } catch (customSwError) {
                                    
                                    registration = await navigator.serviceWorker.register('/sw.js', {
                                        scope: '/',
                                        updateViaCache: 'none'
                                    });
                                    
                                }
                                
                                
                                
                                // Wait for it to become ready
                                await registration.update(); // Force update check
                                
                                if (registration.active) {
                                    
                                } else if (registration.waiting) {
                                    
                                    registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                                    await new Promise(resolve => setTimeout(resolve, 1000)); // Wait for activation
                                } else if (registration.installing) {
                                    
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
                    
                    
                    
                    
                    // Don't wait for activation in production - use Service Worker as-is for better performance
                    if (!import.meta.env.PROD) {
                        // Only wait for activation in development
                        if (!registration.active && registration.waiting) {
                            
                            registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                            
                            // Wait for activation with timeout
                            await new Promise((resolve) => {
                                const checkActive = () => {
                                    if (registration.active) {
                                        
                                        resolve(true);
                                    } else {
                                        setTimeout(checkActive, 100);
                                    }
                                };
                                setTimeout(checkActive, 500); // Initial delay
                                // Timeout after 2 seconds
                                setTimeout(() => resolve(true), 2000);
                            });
                        } else if (!registration.active && registration.installing) {
                            
                            // Wait briefly for installation but don't block
                            await new Promise((resolve) => {
                                setTimeout(resolve, 1000); // Wait max 1 second
                            });
                        }
                    } else {
                        
                    }
                    
                    // Use the Service Worker regardless of state in production
                    
                    
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
                    
                    // Check if service worker registration is available and handle activation
                    if (!registration) {
                        console.warn('⚠️ No service worker registration found');
                        throw new Error('No service worker registration available');
                    }
                    
                    
                    console.log('🔍 Registration details:', {
                        active: !!registration.active,
                        waiting: !!registration.waiting,
                        installing: !!registration.installing,
                        scope: registration.scope,
                        state: registration.active?.state || registration.waiting?.state || registration.installing?.state || 'unknown'
                    });
                    
                    // CRITICAL: Handle Service Worker activation issues
                    if (!registration.active) {
                        console.warn('⚠️ Service Worker is not active, attempting to activate...');
                        
                        if (registration.waiting) {
                            
                            registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                            
                            // Wait for activation
                            await new Promise((resolve) => {
                                const handleControllerChange = () => {
                                    
                                    navigator.serviceWorker.removeEventListener('controllerchange', handleControllerChange);
                                    resolve(true);
                                };
                                navigator.serviceWorker.addEventListener('controllerchange', handleControllerChange);
                                
                                // Timeout after 5 seconds
                                setTimeout(() => {
                                    navigator.serviceWorker.removeEventListener('controllerchange', handleControllerChange);
                                    
                                    resolve(true);
                                }, 5000);
                            });
                        } else if (registration.installing) {
                            
                            
                            // Wait for installation to complete and activate
                            await new Promise((resolve) => {
                                const worker = registration.installing!;
                                const handleStateChange = () => {
                                    
                                    if (worker.state === 'activated') {
                                        
                                        worker.removeEventListener('statechange', handleStateChange);
                                        resolve(true);
                                    } else if (worker.state === 'redundant') {
                                        console.error('❌ Service Worker became redundant');
                                        worker.removeEventListener('statechange', handleStateChange);
                                        resolve(false);
                                    }
                                };
                                worker.addEventListener('statechange', handleStateChange);
                                
                                // Force skip waiting if it's taking too long
                                setTimeout(() => {
                                    if (worker.state === 'installed') {
                                        
                                        worker.postMessage({ type: 'SKIP_WAITING' });
                                    }
                                }, 2000);
                                
                                // Timeout after 10 seconds
                                setTimeout(() => {
                                    worker.removeEventListener('statechange', handleStateChange);
                                    
                                    resolve(false);
                                }, 10000);
                            });
                        }
                        
                        // Check again after activation attempts
                        const updatedRegistration = await navigator.serviceWorker.ready.catch(() => registration);
                        if (updatedRegistration.active) {
                            
                            registration = updatedRegistration;
                        } else {
                            console.warn('⚠️ Service Worker still not active, will try direct notification fallback');
                        }
                    } else {
                        
                    }
                    
                    // Show notification through service worker (works even if not fully active)
                    
                    console.log('🔔 Notification options:', {
                        body: queueItem.payload.body,
                        icon: queueItem.payload.icon,
                        badge: queueItem.payload.badge,
                        data: queueItem.payload.data,
                        tag: `notification-${queueItem.notification_id}`,
                        requireInteraction: true,
                        silent: false
                    });
                    
                    // Mobile-optimized notification options - variables already defined at function scope
                    
                    
                    
                    
                    notificationOptions = {
                        body: queueItem.payload.body,
                        icon: queueItem.payload.icon || '/icons/icon-192x192.png',
                        badge: queueItem.payload.badge || '/icons/icon-96x96.png',
                        data: {
                            ...queueItem.payload.data,
                            isMobile: isMobile,
                            isPWA: isPWA,
                            timestamp: Date.now(),
                            forceShow: true, // Flag to force showing on mobile
                            displayMode: window.matchMedia('(display-mode: standalone)').matches ? 'standalone' : 'browser'
                        },
                        tag: `notification-${queueItem.notification_id}`,
                        // PWA-specific notification behavior
                        requireInteraction: isPWA || isMobile, // PWA apps should require interaction
                        silent: false,
                        timestamp: Date.now(),
                        // Enhanced vibration for PWA on mobile
                        vibrate: (isMobile && isPWA) ? [300, 100, 300, 100, 300] : 
                                isMobile ? [200, 100, 200, 100, 200] : [200, 100, 200],
                        // PWA-optimized actions
                        actions: (isPWA && isMobile) ? [
                            {
                                action: 'view',
                                title: 'Open',
                                icon: '/icons/icon-96x96.png'
                            }
                        ] : isMobile ? [
                            {
                                action: 'view',
                                title: 'View'
                            }
                        ] : [
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

                    
                    
                    try {
                        // Enhanced approach for different environments
                        if (isMobile || isPWA) {
                            console.log(`📱 ${isPWA ? 'PWA' : 'Mobile'} device detected - using optimized notification approach`);
                            
                            // Check if Service Worker is actually active before using it
                            if (registration && registration.active) {
                                // Method 1: Direct Service Worker showNotification (most reliable for PWA/mobile)
                                await registration.showNotification(queueItem.payload.title, notificationOptions);
                                console.log(`🎉 ${isPWA ? 'PWA' : 'Mobile'} Service Worker notification shown successfully!`);
                            } else {
                                console.warn('⚠️ Service Worker not active, using direct notification for mobile');
                                if ('Notification' in window && Notification.permission === 'granted') {
                                    // Create simplified options for direct notification (no actions allowed)
                                    const directOptions = {
                                        body: notificationOptions.body,
                                        icon: notificationOptions.icon,
                                        badge: notificationOptions.badge,
                                        tag: notificationOptions.tag,
                                        requireInteraction: notificationOptions.requireInteraction,
                                        silent: notificationOptions.silent,
                                        vibrate: notificationOptions.vibrate,
                                        data: {
                                            ...notificationOptions.data,
                                            deliveryMethod: 'direct'
                                        }
                                        // Note: actions not supported in direct notifications
                                    };
                                    
                                    const directNotification = new Notification(queueItem.payload.title, directOptions);
                                    
                                    // Handle click event
                                    directNotification.onclick = () => {
                                        
                                        if (queueItem.payload.data?.url) {
                                            window.open(queueItem.payload.data.url, '_blank');
                                        } else {
                                            window.focus();
                                        }
                                        directNotification.close();
                                    };
                                    
                                    
                                } else {
                                    throw new Error('No notification method available');
                                }
                            }
                            
                            // Method 2: Enhanced Service Worker communication for PWA (if active)
                            if (registration && registration.active) {
                                
                                registration.active.postMessage({
                                    type: 'FORCE_SHOW_NOTIFICATION',
                                    title: queueItem.payload.title,
                                    options: notificationOptions,
                                    isMobile: isMobile,
                                    isPWA: isPWA,
                                    displayMode: window.matchMedia('(display-mode: standalone)').matches ? 'standalone' : 'browser'
                                });
                            }
                            
                            // Method 3: PWA-specific enhancements (only if SW is active)
                            if (isPWA && registration && registration.active) {
                                
                                
                                // PWA apps often need special handling for background notifications
                                if (document.hidden || !document.hasFocus()) {
                                    
                                } else {
                                    
                                    
                                    // For PWA, we can be more aggressive with notifications
                                    setTimeout(async () => {
                                        try {
                                            if (registration && registration.active) {
                                                await registration.showNotification(`${queueItem.payload.title} (PWA)`, {
                                                    ...notificationOptions,
                                                    tag: `pwa-${queueItem.notification_id}`,
                                                    data: {
                                                        ...notificationOptions.data,
                                                        isPWANotification: true
                                                    }
                                                });
                                                
                                            }
                                        } catch (e) {
                                            
                                        }
                                    }, 1000);
                                }
                            } else if (isMobile) {
                                // Mobile browser behavior (no active SW or not PWA)
                                if (document.hidden || !document.hasFocus()) {
                                    
                                } else {
                                    
                                    const handleVisibilityChange = async () => {
                                        if (document.hidden) {
                                            
                                            try {
                                                if ('Notification' in window && Notification.permission === 'granted') {
                                                    new Notification(`${queueItem.payload.title} (Mobile)`, {
                                                        body: queueItem.payload.body,
                                                        icon: queueItem.payload.icon || '/icons/icon-192x192.png',
                                                        tag: `mobile-backup-${queueItem.notification_id}`
                                                    });
                                                }
                                            } catch (e) {
                                                
                                            }
                                            document.removeEventListener('visibilitychange', handleVisibilityChange);
                                        }
                                    };
                                    document.addEventListener('visibilitychange', handleVisibilityChange);
                                    // Remove listener after 10 seconds
                                    setTimeout(() => {
                                        document.removeEventListener('visibilitychange', handleVisibilityChange);
                                    }, 10000);
                                }
                            }
                        } else {
                            // Desktop approach - require active Service Worker
                            if (registration && registration.active) {
                                await registration.showNotification(queueItem.payload.title, notificationOptions);
                                
                            } else {
                                console.warn('⚠️ Service Worker not active, using direct notification for desktop');
                                if ('Notification' in window && Notification.permission === 'granted') {
                                    // Create simplified options for direct notification (no actions allowed)
                                    const directOptions = {
                                        body: notificationOptions.body,
                                        icon: notificationOptions.icon,
                                        badge: notificationOptions.badge,
                                        tag: notificationOptions.tag,
                                        requireInteraction: notificationOptions.requireInteraction,
                                        silent: notificationOptions.silent,
                                        vibrate: notificationOptions.vibrate,
                                        data: {
                                            ...notificationOptions.data,
                                            deliveryMethod: 'direct'
                                        }
                                    };
                                    
                                    const directNotification = new Notification(queueItem.payload.title, directOptions);
                                    
                                    // Handle click event
                                    directNotification.onclick = () => {
                                        
                                        if (queueItem.payload.data?.url) {
                                            window.open(queueItem.payload.data.url, '_blank');
                                        } else {
                                            window.focus();
                                        }
                                        directNotification.close();
                                    };
                                    
                                    
                                } else {
                                    throw new Error('No notification method available for desktop');
                                }
                            }
                        }
                        
                    } catch (swError) {
                        console.error('❌ Service Worker notification failed:', swError);
                        
                    }
                    
                    // Commented out test notification to prevent unwanted popup
                    /*
                    // Also send a test message to Service Worker to verify communication
                    if (registration.active) {
                        const messageChannel = new MessageChannel();
                        messageChannel.port1.onmessage = (event) => {
                            
                        };
                        
                        registration.active.postMessage({
                            type: 'SHOW_NOTIFICATION',
                            title: 'Test from Client',
                            body: 'Testing SW notification capability',
                            tag: 'test-notification'
                        }, [messageChannel.port2]);
                    }
                    */
                } catch (swError) {
                    console.error('❌ Service Worker notification failed:', swError);
                    console.error('❌ SW Error details:', {
                        name: swError.name,
                        message: swError.message,
                        stack: swError.stack,
                        isPWA: isPWA,
                        isMinimized: document.hidden,
                        swState: registration?.active?.state || 'unknown'
                    });
                    
                    // Critical: Handle PWA minimized state with SW failure
                    if (isPWA && document.hidden) {
                        console.error('🚨 CRITICAL: PWA is minimized and Service Worker failed!');
                        console.error('🚨 This means push notifications will NOT work until user reopens app');
                        console.error('🚨 Attempting emergency recovery procedures...');
                        
                        // Emergency recovery for PWA
                        try {
                            // Try to re-register the Service Worker
                            
                            
                            if ('serviceWorker' in navigator) {
                                // Get all registrations
                                const registrations = await navigator.serviceWorker.getRegistrations();
                                
                                
                                // Try to find an active registration
                                let activeRegistration = null;
                                for (const reg of registrations) {
                                    if (reg.active) {
                                        activeRegistration = reg;
                                        
                                        break;
                                    }
                                }
                                
                                if (activeRegistration) {
                                    // Try to use the active registration
                                    await activeRegistration.showNotification(queueItem.payload.title, {
                                        ...notificationOptions,
                                        body: `${queueItem.payload.body} (Recovery)`,
                                        tag: `recovery-${queueItem.notification_id}`,
                                        data: {
                                            ...notificationOptions.data,
                                            recoveryAttempt: true,
                                            originalError: swError.message
                                        }
                                    });
                                    
                                } else {
                                    console.error('❌ No active Service Worker found for recovery');
                                    
                                    // Mark notification as failed - will be retried when app is reopened
                                    await this.markNotificationFailed(queueItem.id, `PWA minimized with SW failure: ${swError.message}`);
                                    
                                }
                            }
                        } catch (recoveryError) {
                            console.error('❌ Emergency recovery failed:', recoveryError);
                            await this.markNotificationFailed(queueItem.id, `PWA recovery failed: ${recoveryError.message}`);
                        }
                        
                        // Set up visibility change listener for when PWA is reopened
                        const handlePWAReopen = async () => {
                            if (!document.hidden && isPWA) {
                                
                                
                                // Try to re-process this notification
                                try {
                                    const retryRegistration = await navigator.serviceWorker.ready;
                                    await retryRegistration.showNotification(queueItem.payload.title, {
                                        ...notificationOptions,
                                        body: `${queueItem.payload.body} (Delayed)`,
                                        tag: `delayed-${queueItem.notification_id}`,
                                        data: {
                                            ...notificationOptions.data,
                                            delayedDelivery: true,
                                            originalError: swError.message
                                        }
                                    });
                                    
                                } catch (retryError) {
                                    console.error('❌ Delayed notification retry failed:', retryError);
                                }
                                
                                document.removeEventListener('visibilitychange', handlePWAReopen);
                            }
                        };
                        
                        document.addEventListener('visibilitychange', handlePWAReopen);
                        
                        // Remove listener after 5 minutes to prevent memory leaks
                        setTimeout(() => {
                            document.removeEventListener('visibilitychange', handlePWAReopen);
                        }, 5 * 60 * 1000);
                        
                    } else {
                        console.warn('⚠️ Service Worker notification failed, trying direct notification fallback:', swError);
                        
                        // Standard fallback for non-PWA or visible apps
                        try {
                            if ('Notification' in window && Notification.permission === 'granted') {
                                
                                const directNotification = new Notification(queueItem.payload.title, {
                                    body: queueItem.payload.body,
                                    icon: queueItem.payload.icon,
                                    tag: `notification-${queueItem.notification_id}`,
                                    requireInteraction: isMobile || isPWA
                                });

                                // Handle click event for direct notification
                                directNotification.onclick = () => {
                                    
                                    if (queueItem.payload.data?.url) {
                                        window.open(queueItem.payload.data.url, '_blank');
                                    }
                                    directNotification.close();
                                };
                                
                                
                            } else {
                                console.error('❌ Direct notifications not available either');
                                await this.markNotificationFailed(queueItem.id, `Both SW and direct notifications failed: ${swError.message}`);
                            }
                        } catch (directError) {
                            console.error('❌ Direct notification fallback also failed:', directError);
                            await this.markNotificationFailed(queueItem.id, `All notification methods failed: ${swError.message} -> ${directError.message}`);
                        }
                    }
                    
                    
                }
            } else if ('Notification' in window) {
                
                
                // Direct browser notifications don't work on mobile browsers
                // Only Service Worker notifications are supported on mobile
                console.warn('⚠️ Direct browser notifications not supported on mobile - notification skipped');
                
                
            } else {
                console.error('❌ Notifications not supported in this browser');
                throw new Error('Notifications not supported');
            }

            // Mark as sent
            await supabase
                .from('notification_queue')
                .update({ 
                    status: 'sent',
                    sent_at: new Date().toISOString()
                })
                .eq('id', queueItem.id);

            console.log(`✅ Push notification ${queueItem.id} sent successfully`);

            // Cleanup disabled to prevent notification deletion
            // try {
            //     console.log(`🗑️ [v2.0] Deleting other pending and failed notifications for user ${queueItem.user_id} and notification ${queueItem.notification_id}...`);
            //     // Auto-cleanup disabled - was deleting valid notifications
            // } catch (deleteError) {
            //     console.error('❌ Error in auto-delete process:', deleteError);
            // }

        } catch (error) {
            console.error(`❌ Failed to send push notification ${queueItem.id}:`, error);

            // Mark as failed
            await supabase
                .from('notification_queue')
                .update({ 
                    status: 'failed',
                    error_message: error instanceof Error ? error.message : 'Unknown error'
                })
                .eq('id', queueItem.id);
        }
    }

    /**
     * Mark a notification as failed with error details
     */
    private async markNotificationFailed(notificationId: string, errorMessage: string) {
        try {
            await supabase
                .from('notification_queue')
                .update({ 
                    status: 'failed',
                    error_message: errorMessage,
                    failed_at: new Date().toISOString()
                })
                .eq('id', notificationId);
                
            console.log(`📝 Notification ${notificationId} marked as failed: ${errorMessage}`);
        } catch (error) {
            console.error(`❌ Failed to mark notification ${notificationId} as failed:`, error);
        }
    }

    /**
     * Cleanup disabled to prevent notification deletion
     */
    async cleanupOldQueueEntries(olderThanDays: number = 7) {
        // Cleanup disabled - was deleting notifications before they could be processed
        console.log(`🧹 [DISABLED] Old queue cleanup is disabled to prevent notification deletion`);
        return;
    }

    /**
     * Manually process queue once (for testing)
     */
    async processOnce() {
        
        await this.processQueue();
    }

    /**
     * Create a test notification queue entry (DISABLED - removed to prevent unwanted test notifications)
     */
    async createTestQueueEntry() {
        
        
        return;
    }
}

/**
 * Mobile Push Notification Prompt for First-Time Login
 * This function detects if a user is logging in for the first time on a mobile device
 * and prompts them to enable push notifications
 */
export async function promptMobilePushNotifications(userId: string): Promise<boolean> {
    try {
        
        
        // Check if we're on a mobile device
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        const isTablet = /iPad|Android(?=.*\bMobile\b)/i.test(navigator.userAgent);
        const isMobileDevice = isMobile || isTablet;
        
        if (!isMobileDevice) {
            
            return false;
        }
        
        // Check if notifications are supported
        if (!('Notification' in window) || !('serviceWorker' in navigator)) {
            
            return false;
        }
        
        // Check if user has already been prompted for this device
        const deviceId = localStorage.getItem('aqura-device-id') || `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        const promptKey = `aqura-push-prompted-${deviceId}`;
        const hasBeenPrompted = localStorage.getItem(promptKey);
        
        if (hasBeenPrompted) {
            
            return false;
        }
        
        // Check current notification permission
        const currentPermission = Notification.permission;
        if (currentPermission === 'granted') {
            
            // Mark as prompted to avoid future prompts
            localStorage.setItem(promptKey, 'granted');
            return true;
        }
        
        if (currentPermission === 'denied') {
            
            localStorage.setItem(promptKey, 'denied');
            return false;
        }
        
        // Show mobile-friendly prompt
        const userWantsNotifications = await showMobilePushPrompt();
        
        if (userWantsNotifications) {
            
            
            // Request permission
            const permission = await Notification.requestPermission();
            
            if (permission === 'granted') {
                
                localStorage.setItem(promptKey, 'granted');
                
                // Initialize push notifications for this user
                try {
                    const { pushNotificationService } = await import('./pushNotifications');
                    await pushNotificationService.initialize();
                    
                    return true;
                } catch (error) {
                    console.error('❌ Failed to initialize push notifications:', error);
                }
            } else {
                
                localStorage.setItem(promptKey, 'denied');
            }
        } else {
            
            localStorage.setItem(promptKey, 'declined');
        }
        
        return false;
    } catch (error) {
        console.error('❌ Error in mobile push notification prompt:', error);
        return false;
    }
}

/**
 * Show a mobile-optimized dialog to ask user about enabling push notifications
 */
async function showMobilePushPrompt(): Promise<boolean> {
    return new Promise((resolve) => {
        // Create mobile-friendly modal
        const modal = document.createElement('div');
        modal.className = 'mobile-push-prompt-overlay';
        modal.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.5);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 10000;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        `;
        
        const dialog = document.createElement('div');
        dialog.className = 'mobile-push-prompt-dialog';
        dialog.style.cssText = `
            background: white;
            border-radius: 12px;
            padding: 24px;
            margin: 20px;
            max-width: 320px;
            width: 100%;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
            text-align: center;
            animation: slideUp 0.3s ease-out;
        `;
        
        dialog.innerHTML = `
            <div style="margin-bottom: 20px;">
                <div style="
                    width: 60px;
                    height: 60px;
                    background: #007AFF;
                    border-radius: 50%;
                    margin: 0 auto 16px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 24px;
                ">🔔</div>
                <h3 style="margin: 0 0 8px; font-size: 18px; font-weight: 600; color: #333;">
                    Enable Notifications?
                </h3>
                <p style="margin: 0; font-size: 14px; color: #666; line-height: 1.4;">
                    Stay updated with important notifications from Aqura. You can change this anytime in your browser settings.
                </p>
            </div>
            <div style="display: flex; gap: 12px; justify-content: center;">
                <button id="push-prompt-decline" style="
                    background: #f1f1f1;
                    border: none;
                    padding: 12px 20px;
                    border-radius: 8px;
                    font-size: 16px;
                    font-weight: 500;
                    color: #666;
                    cursor: pointer;
                    flex: 1;
                ">Not Now</button>
                <button id="push-prompt-accept" style="
                    background: #007AFF;
                    border: none;
                    padding: 12px 20px;
                    border-radius: 8px;
                    font-size: 16px;
                    font-weight: 500;
                    color: white;
                    cursor: pointer;
                    flex: 1;
                ">Enable</button>
            </div>
        `;
        
        // Add slide-up animation
        const style = document.createElement('style');
        style.textContent = `
            @keyframes slideUp {
                from {
                    transform: translateY(100px);
                    opacity: 0;
                }
                to {
                    transform: translateY(0);
                    opacity: 1;
                }
            }
            
            .mobile-push-prompt-dialog button:active {
                transform: scale(0.95);
            }
        `;
        document.head.appendChild(style);
        
        modal.appendChild(dialog);
        document.body.appendChild(modal);
        
        // Handle button clicks
        const acceptBtn = dialog.querySelector('#push-prompt-accept');
        const declineBtn = dialog.querySelector('#push-prompt-decline');
        
        const cleanup = () => {
            document.body.removeChild(modal);
            document.head.removeChild(style);
        };
        
        acceptBtn?.addEventListener('click', () => {
            cleanup();
            resolve(true);
        });
        
        declineBtn?.addEventListener('click', () => {
            cleanup();
            resolve(false);
        });
        
        // Close on backdrop click
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                cleanup();
                resolve(false);
            }
        });
        
        // Auto-close after 30 seconds (decline by default)
        setTimeout(() => {
            if (document.body.contains(modal)) {
                cleanup();
                resolve(false);
            }
        }, 30000);
    });
}

/**
 * Check if user should be prompted for push notifications on login
 * Call this function after successful user authentication
 */
export async function checkAndPromptPushNotifications(userId: string): Promise<void> {
    try {
        
        
        // Small delay to ensure UI is ready
        setTimeout(async () => {
            const enabled = await promptMobilePushNotifications(userId);
            if (enabled) {
                
            }
        }, 1000);
        
    } catch (error) {
        console.error('❌ Error checking push notification prompt:', error);
    }
}

// Create singleton instance
export const pushNotificationProcessor = new PushNotificationProcessor();

// Debug functions disabled in production to prevent unwanted test notifications
if (typeof window !== 'undefined' && import.meta.env.DEV) {
    // Only expose test functions in development mode
    (window as any).testPushNotificationQueue = () => {
        
        // pushNotificationProcessor.createTestQueueEntry();
    };
    
    (window as any).processPushNotificationQueue = () => {
        pushNotificationProcessor.processOnce();
    };
    
    // Mobile notification debugging functions (disabled in production)
    (window as any).aquraPushDebug = {
        // Test mobile notification immediately (disabled in production)
        testMobileNotification: async () => {
            if (!import.meta.env.DEV) {
                
                return 'Test functions disabled in production';
            }
            
            try {
                const registration = await navigator.serviceWorker.ready;
                const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
                
                const options = {
                    body: `Mobile test notification - Device: ${isMobile ? 'Mobile' : 'Desktop'}`,
                    icon: '/icons/icon-192x192.png',
                    badge: '/icons/icon-96x96.png',
                    tag: 'mobile-debug-test',
                    requireInteraction: true,
                    silent: false,
                    vibrate: [300, 100, 300],
                    data: {
                        debug: true,
                        mobile: isMobile,
                        timestamp: Date.now()
                    }
                };
                
                await registration.showNotification('🧪 Mobile Debug Test', options);
                
                
                // Also try direct SW message
                if (registration.active) {
                    registration.active.postMessage({
                        type: 'FORCE_SHOW_NOTIFICATION',
                        title: '📱 Force Mobile Test',
                        options: {
                            ...options,
                            body: 'This is a forced mobile notification test',
                            tag: 'force-mobile-test'
                        }
                    });
                    
                }
                
                return 'Test notification sent - check your device!';
            } catch (error) {
                console.error('❌ Mobile test failed:', error);
                return `Test failed: ${error.message}`;
            }
        },
        
        // Check mobile notification status
        checkMobileStatus: () => {
            const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
            const hasServiceWorker = 'serviceWorker' in navigator;
            const hasNotifications = 'Notification' in window;
            const permission = hasNotifications ? Notification.permission : 'not-supported';
            
            const status = {
                isMobile,
                hasServiceWorker,
                hasNotifications,
                permission,
                userAgent: navigator.userAgent,
                isPageHidden: document.hidden,
                isPageFocused: document.hasFocus(),
                visibilityState: document.visibilityState
            };
            
            console.table(status);
            return status;
        },
        
        // Process queue manually
        processQueue: () => pushNotificationProcessor.processOnce(),
        
        // Get processor info
        getProcessorInfo: () => {
            return {
                version: '3.0',
                isProcessing: (pushNotificationProcessor as any).isProcessing,
                intervalId: (pushNotificationProcessor as any).intervalId
            };
        }
    };
    
    // Add emergency stop function
    (window as any).stopPushNotificationProcessor = () => {
        pushNotificationProcessor.stop();
        
    };
    
    // Log available debugging functions
    
    
    
    
    

    // Cleanup functions disabled to prevent notification deletion
    (window as any).cleanupOldNotifications = (days = 7) => {
        console.log(`🧹 [DISABLED] Cleanup is disabled to prevent notification deletion`);
    };

    // Manual cleanup function disabled to prevent notification deletion
    (window as any).deleteDuplicateNotifications = async (notificationId: string, userId: string) => {
        console.log(`🗑️ [DISABLED] Manual duplicate deletion is disabled to prevent notification loss`);
        return;
    };

    // Add helper function to find real notification IDs for testing
    (window as any).findNotificationIds = async () => {
        
        try {
            const { data: queueItems, error } = await supabase
                .from('notification_queue')
                .select('id, notification_id, user_id, status')
                .limit(10);

            if (error) {
                console.error('❌ Error fetching notification IDs:', error);
                return;
            }

            
            queueItems?.forEach((item, index) => {
                console.log(`${index + 1}. ID: ${item.id}, Notification: ${item.notification_id}, User: ${item.user_id}, Status: ${item.status}`);
            });
            
            if (queueItems && queueItems.length > 0) {
                const first = queueItems[0];
                console.log(`💡 To test deletion, use: deleteDuplicateNotifications('${first.notification_id}', '${first.user_id}')`);
            } else {
                
            }
        } catch (error) {
            console.error('❌ Error finding notification IDs:', error);
        }
    };

    // Test if database trigger is working by manually calling the queue function
    (window as any).testDatabaseTrigger = async () => {
        
        try {
            // Call the queue_push_notification function directly with the notification ID from your console
            const { data, error } = await supabase.rpc('queue_push_notification', {
                p_notification_id: '0d1dc630-c253-4269-b30b-f416a747e69e'
            });

            if (error) {
                console.error('❌ Database trigger function failed:', error);
                console.error('❌ This suggests the trigger function was not properly installed');
            } else {
                
                
                
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
                    
                }
            } else {
                
                
                
                
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
        
        try {
            
            
            if (Notification.permission !== 'granted') {
                
                const permission = await Notification.requestPermission();
                
                
                if (permission !== 'granted') {
                    console.error('❌ Permission denied');
                    return;
                }
            }

            // Test service worker notification only (mobile compatible)
            if ('serviceWorker' in navigator) {
                
                const registration = await navigator.serviceWorker.ready;
                await registration.showNotification('Service Worker Test', {
                    body: 'This is a service worker notification test',
                    icon: '/favicon.png',
                    requireInteraction: true
                });
                
                
                // Also create a direct test for desktop (but skip on mobile)
                if (!navigator.userAgent.includes('Mobile')) {
                    
                    const directNotification = new Notification('Direct Test', {
                        body: 'This is a direct browser notification test (desktop only)',
                        icon: '/favicon.png'
                    });

                    directNotification.onclick = () => {
                        
                        directNotification.close();
                    };

                    setTimeout(() => directNotification.close(), 5000);
                }
            } else {
                console.warn('⚠️ Service Worker not supported - notifications disabled');
            }

        } catch (err) {
            console.error('❌ Basic notification test failed:', err);
        }
    };

    // Helper function to queue the latest notification manually
    (window as any).queueLatestNotification = async () => {
        
        try {
            // Get the most recent notification
            const { data: latestNotification, error } = await supabase
                .from('notifications')
                .select('id, title, created_at')
                .order('created_at', { ascending: false })
                .limit(1)
                .single();

            if (error || !latestNotification) {
                console.error('❌ No notifications found:', error);
                return;
            }

            

            // Queue it using the database function
            const { data: queueResult, error: queueError } = await supabase.rpc('queue_push_notification', {
                p_notification_id: latestNotification.id
            });

            if (queueError) {
                console.error('❌ Failed to queue notification:', queueError);
            } else {
                
                
                
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
        
        try {
            const { data: queueResult, error: queueError } = await supabase.rpc('queue_push_notification', {
                p_notification_id: notificationId
            });

            if (queueError) {
                console.error('❌ Auto-queue failed:', queueError);
            } else {
                console.log('✅ Auto-queue successful');
                // Process immediately
                setTimeout(async () => {
                    await pushNotificationProcessor.processOnce();
                }, 500);
            }
        } catch (err) {
            console.error('❌ Auto-queue error:', err);
        }
    };

    // Manual fallback processing
    (window as any).processFallbackQueues = async () => {
        console.log('🔄 Processing fallback queues...');
        try {
            await (pushNotificationProcessor as any).checkAndCreateFallbackQueues();
            console.log('✅ Fallback queue processing completed');
        } catch (err) {
            console.error('❌ Fallback queue processing failed:', err);
        }
    };

    // Check subscription limits (1 mobile + 1 desktop)
    (window as any).checkSubscriptionLimits = async (userId?: string) => {
        const user = userId || await (window as any).persistentAuth?.getCurrentUser()?.id;
        if (!user) {
            console.error('❌ No user specified');
            return;
        }

        try {
            const { data: subscriptions, error } = await supabase
                .from('push_subscriptions')
                .select('id, device_type, device_id, last_seen, is_active')
                .eq('user_id', user)
                .eq('is_active', true)
                .order('last_seen', { ascending: false });

            if (error) {
                console.error('❌ Error fetching subscriptions:', error);
                return;
            }

            const mobile = subscriptions?.filter(s => s.device_type === 'mobile') || [];
            const desktop = subscriptions?.filter(s => s.device_type === 'desktop') || [];

            console.log(`📊 User ${user} subscriptions:`);
            console.log(`📱 Mobile: ${mobile.length} (limit: 1)`);
            console.log(`💻 Desktop: ${desktop.length} (limit: 1)`);
            
            if (mobile.length > 1) {
                console.warn(`⚠️ Mobile subscriptions exceed limit! Found ${mobile.length}, limit is 1`);
            }
            if (desktop.length > 1) {
                console.warn(`⚠️ Desktop subscriptions exceed limit! Found ${desktop.length}, limit is 1`);
            }

            return { mobile, desktop, withinLimits: mobile.length <= 1 && desktop.length <= 1 };

        } catch (err) {
            console.error('❌ Error checking subscription limits:', err);
        }
    };

    // Test fallback subscription logic
    (window as any).testSubscriptionFallback = async (queueItemId?: string) => {
        console.log('🧪 Testing subscription fallback logic...');
        
        try {
            // If no queue item specified, get the first pending one
            let queueItem;
            if (queueItemId) {
                const { data, error } = await supabase
                    .from('notification_queue')
                    .select('*')
                    .eq('id', queueItemId)
                    .single();
                
                if (error || !data) {
                    console.error(`❌ Queue item ${queueItemId} not found:`, error);
                    return;
                }
                queueItem = data;
            } else {
                const { data, error } = await supabase
                    .from('notification_queue')
                    .select('*')
                    .eq('status', 'pending')
                    .limit(1)
                    .single();
                
                if (error || !data) {
                    console.warn(`⚠️ No pending queue items found for testing`);
                    return;
                }
                queueItem = data;
            }

            console.log(`🔍 Testing fallback for queue item ${queueItem.id}:`);
            console.log(`   User: ${queueItem.user_id}`);
            console.log(`   Device: ${queueItem.device_id}`);
            console.log(`   Subscription: ${queueItem.push_subscription_id}`);
            
            // Test the fallback logic
            const success = await (pushNotificationProcessor as any).processFallbackSubscription(queueItem);
            
            if (success) {
                console.log(`✅ Fallback successful! Queue item updated.`);
            } else {
                console.log(`❌ Fallback failed - no active subscription found.`);
            }
            
            return { success, queueItem };

        } catch (err) {
            console.error('❌ Error testing subscription fallback:', err);
        }
    };

    // Check for orphaned queue items (subscription IDs that don't exist)
    (window as any).findOrphanedQueueItems = async () => {
        console.log('🔍 Looking for orphaned queue items...');
        
        try {
            const { data: queueItems, error } = await supabase
                .from('notification_queue')
                .select(`
                    id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    status,
                    created_at
                `)
                .in('status', ['pending', 'retry'])
                .order('created_at', { ascending: false })
                .limit(50);

            if (error) {
                console.error('❌ Error fetching queue items:', error);
                return;
            }

            if (!queueItems || queueItems.length === 0) {
                console.log('✅ No pending/retry queue items found');
                return;
            }

            console.log(`🔍 Checking ${queueItems.length} queue items for orphaned subscriptions...`);
            
            const orphaned = [];
            
            for (const item of queueItems) {
                const { data: subscription, error: subError } = await supabase
                    .from('push_subscriptions')
                    .select('id, is_active')
                    .eq('id', item.push_subscription_id)
                    .single();
                
                if (subError || !subscription || !subscription.is_active) {
                    orphaned.push({
                        queue_id: item.id,
                        user_id: item.user_id,
                        device_id: item.device_id,
                        subscription_id: item.push_subscription_id,
                        status: item.status,
                        issue: subError ? 'subscription_not_found' : 'subscription_inactive'
                    });
                }
            }

            if (orphaned.length === 0) {
                console.log('✅ No orphaned queue items found - all subscriptions are valid');
            } else {
                console.warn(`⚠️ Found ${orphaned.length} orphaned queue items:`);
                orphaned.forEach((item, index) => {
                    console.log(`${index + 1}. Queue ${item.queue_id} - User ${item.user_id} - ${item.issue}`);
                });
                
                console.log('💡 Run processOnce() to trigger automatic fallback processing');
            }
            
            return orphaned;

        } catch (err) {
            console.error('❌ Error finding orphaned queue items:', err);
        }
    };
}
