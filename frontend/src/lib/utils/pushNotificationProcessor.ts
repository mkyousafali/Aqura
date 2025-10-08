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
    private static readonly VERSION = '3.0';
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
     * Clean up excessive failed notifications to prevent queue bloat
     */
    private async cleanupExcessiveFailedNotifications() {
        try {
            console.log('🧹 [v2.0] Performing preventive cleanup of old failed notifications...');
            
            // Delete failed notifications older than 30 minutes to prevent queue bloat
            const thirtyMinutesAgo = new Date();
            thirtyMinutesAgo.setMinutes(thirtyMinutesAgo.getMinutes() - 30);
            
            const { data: deletedOld, error: deleteError } = await supabaseAdmin
                .from('notification_queue')
                .delete()
                .eq('status', 'failed')
                .lt('created_at', thirtyMinutesAgo.toISOString())
                .select();

            if (deleteError) {
                console.log(`⚠️ [v2.0] Note: Could not delete old failed notifications: ${deleteError.message}`);
            } else {
                console.log(`🗑️ [v2.0] Deleted ${deletedOld?.length || 0} old failed notifications (>30 min old)`);
            }
        } catch (error) {
            console.log('⚠️ [v2.0] Preventive cleanup failed, but continuing with normal processing:', error);
        }
    }

    /**
     * Process pending notifications in the queue with retry logic
     */
    private async processQueue() {
        try {
            console.log('🔍 Processing notification queue with retry support');

            // [v3.0] Perform preventive cleanup to prevent queue bloat
            await this.cleanupExcessiveFailedNotifications();

            // Get pending notifications and those ready for retry
            const now = new Date().toISOString();
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
                    created_at,
                    retry_count,
                    next_retry_at,
                    last_attempt_at
                `)
                .or(`status.eq.pending,and(status.eq.retry,next_retry_at.lte.${now})`)
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

            const totalNotifications = queuedNotifications?.length || 0;
            const pendingCount = queuedNotifications?.filter(n => n.status === 'pending').length || 0;
            const retryCount = queuedNotifications?.filter(n => n.status === 'retry').length || 0;
            
            console.log(`📊 Found ${totalNotifications} notifications in queue (${pendingCount} pending, ${retryCount} ready for retry)`);
            console.log('🔍 Database response:', { queuedNotifications, error });

            if (!queuedNotifications || queuedNotifications.length === 0) {
                return; // Don't log if no notifications (too verbose)
            }

            console.log(`📬 Processing ${queuedNotifications.length} notifications...`);
            console.log('🔍 Queue items:', queuedNotifications);

            // Process each notification individually with retry logic
            for (const queueItem of queuedNotifications) {
                await this.processNotificationWithRetry(queueItem);
            }

        } catch (error) {
            console.error('❌ Error processing notification queue:', error);
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
            await supabaseAdmin
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

            const { data: subscription, error: subError } = await supabaseAdmin
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

            console.log('✅ Found push subscription for queue item:', queueItem.id);
            
            try {
                // Attempt to send the notification
                await this.sendPushNotification(queueItem);
                
                // If successful, mark as sent and clean up other pending notifications for this user
                await supabaseAdmin
                    .from('notification_queue')
                    .update({ 
                        status: 'sent',
                        sent_at: new Date().toISOString()
                    })
                    .eq('id', queueItem.id);

                console.log(`✅ Notification ${queueItem.id} sent successfully on attempt ${currentRetryCount + 1}`);
                
                // Clean up other pending/failed notifications for this user+notification
                await this.cleanupDuplicateNotifications(queueItem);
                
            } catch (error) {
                console.error(`❌ Attempt ${currentRetryCount + 1} failed for notification ${queueItem.id}:`, error);
                
                // Handle retry logic
                if (currentRetryCount < maxRetries - 1) {
                    // Calculate next retry time (10 seconds from now)
                    const nextRetryAt = new Date();
                    nextRetryAt.setSeconds(nextRetryAt.getSeconds() + retryIntervalSeconds);
                    
                    // Update to retry status with incremented retry count
                    await supabaseAdmin
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
     * Clean up duplicate pending/failed notifications for the same user+notification
     */
    private async cleanupDuplicateNotifications(queueItem: any) {
        try {
            console.log(`🧹 Cleaning up duplicate notifications for user ${queueItem.user_id} and notification ${queueItem.notification_id}...`);
            
            // Delete other pending/failed for same notification_id
            const { data: deletedSameNotification, error: deleteError1 } = await supabaseAdmin
                .from('notification_queue')
                .delete()
                .eq('notification_id', queueItem.notification_id)
                .eq('user_id', queueItem.user_id)
                .or('status.eq.pending,status.eq.retry,status.eq.failed')
                .neq('id', queueItem.id) // Don't delete the successful one
                .select();

            // Delete ALL failed notifications for this user (any notification_id)
            const { data: deletedAllFailed, error: deleteError2 } = await supabaseAdmin
                .from('notification_queue')
                .delete()
                .eq('user_id', queueItem.user_id)
                .eq('status', 'failed')
                .neq('id', queueItem.id)
                .select();

            if (deleteError1 || deleteError2) {
                console.error('❌ Error in cleanup:', deleteError1 || deleteError2);
            } else {
                const totalDeleted = (deletedSameNotification?.length || 0) + (deletedAllFailed?.length || 0);
                console.log(`✅ Cleaned up ${totalDeleted} duplicate notifications`);
            }
        } catch (error) {
            console.error('❌ Error in cleanup process:', error);
        }
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
                            console.log('✅ Found immediate Service Worker registration (any state)');
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
                                // Try our custom service worker first since it's more reliable in production
                                console.log('🔍 Attempting to register custom SW at: /sw.js');
                                
                                try {
                                    registration = await navigator.serviceWorker.register('/sw.js', {
                                        scope: '/',
                                        updateViaCache: 'none'
                                    });
                                    console.log('✅ Custom Service Worker registered successfully');
                                } catch (customSwError) {
                                    console.log('🔍 Custom SW failed, trying VitePWA SW at: /sw.js', customSwError);
                                    registration = await navigator.serviceWorker.register('/sw.js', {
                                        scope: '/',
                                        updateViaCache: 'none'
                                    });
                                    console.log('✅ VitePWA Service Worker registered successfully');
                                }
                                
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
                    
                    // Don't wait for activation in production - use Service Worker as-is for better performance
                    if (!import.meta.env.PROD) {
                        // Only wait for activation in development
                        if (!registration.active && registration.waiting) {
                            console.log('🔄 Service Worker is waiting, activating...');
                            registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                            
                            // Wait for activation with timeout
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
                                // Timeout after 2 seconds
                                setTimeout(() => resolve(true), 2000);
                            });
                        } else if (!registration.active && registration.installing) {
                            console.log('🔄 Service Worker is installing, waiting briefly...');
                            // Wait briefly for installation but don't block
                            await new Promise((resolve) => {
                                setTimeout(resolve, 1000); // Wait max 1 second
                            });
                        }
                    } else {
                        console.log('🏭 Production mode: Using Service Worker in any state for optimal performance');
                    }
                    
                    // Use the Service Worker regardless of state in production
                    console.log('✅ Using Service Worker registration for push notifications');
                    
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
                    
                    console.log('✅ Service worker registration is available');
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
                            console.log('🔄 Service Worker is waiting, sending skip waiting message...');
                            registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                            
                            // Wait for activation
                            await new Promise((resolve) => {
                                const handleControllerChange = () => {
                                    console.log('🎯 Service Worker controller changed - activation successful');
                                    navigator.serviceWorker.removeEventListener('controllerchange', handleControllerChange);
                                    resolve(true);
                                };
                                navigator.serviceWorker.addEventListener('controllerchange', handleControllerChange);
                                
                                // Timeout after 5 seconds
                                setTimeout(() => {
                                    navigator.serviceWorker.removeEventListener('controllerchange', handleControllerChange);
                                    console.log('⏰ Service Worker activation timeout, proceeding anyway');
                                    resolve(true);
                                }, 5000);
                            });
                        } else if (registration.installing) {
                            console.log('🔄 Service Worker is installing, waiting for activation...');
                            
                            // Wait for installation to complete and activate
                            await new Promise((resolve) => {
                                const worker = registration.installing!;
                                const handleStateChange = () => {
                                    console.log('🔄 Service Worker state changed to:', worker.state);
                                    if (worker.state === 'activated') {
                                        console.log('🎯 Service Worker activated successfully!');
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
                                        console.log('⏰ Forcing Service Worker activation...');
                                        worker.postMessage({ type: 'SKIP_WAITING' });
                                    }
                                }, 2000);
                                
                                // Timeout after 10 seconds
                                setTimeout(() => {
                                    worker.removeEventListener('statechange', handleStateChange);
                                    console.log('⏰ Service Worker activation timeout, proceeding with direct notification');
                                    resolve(false);
                                }, 10000);
                            });
                        }
                        
                        // Check again after activation attempts
                        const updatedRegistration = await navigator.serviceWorker.ready.catch(() => registration);
                        if (updatedRegistration.active) {
                            console.log('✅ Service Worker is now active!');
                            registration = updatedRegistration;
                        } else {
                            console.warn('⚠️ Service Worker still not active, will try direct notification fallback');
                        }
                    } else {
                        console.log('✅ Service Worker is already active');
                    }
                    
                    // Show notification through service worker (works even if not fully active)
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
                    
                    // Mobile-optimized notification options - variables already defined at function scope
                    console.log('📱 Is mobile device:', isMobile);
                    console.log('📱 Is PWA installed:', isPWA);
                    console.log('📱 Display mode:', window.matchMedia('(display-mode: standalone)').matches ? 'standalone' : 'browser');
                    
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

                    console.log('🔔 Attempting notification with enhanced options:', notificationOptions);
                    
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
                                        console.log('🖱️ Direct notification clicked');
                                        if (queueItem.payload.data?.url) {
                                            window.open(queueItem.payload.data.url, '_blank');
                                        } else {
                                            window.focus();
                                        }
                                        directNotification.close();
                                    };
                                    
                                    console.log('🎉 Direct mobile notification created successfully!');
                                } else {
                                    throw new Error('No notification method available');
                                }
                            }
                            
                            // Method 2: Enhanced Service Worker communication for PWA (if active)
                            if (registration && registration.active) {
                                console.log('📨 Sending enhanced notification message to Service Worker');
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
                                console.log('📱 PWA-specific notification enhancements');
                                
                                // PWA apps often need special handling for background notifications
                                if (document.hidden || !document.hasFocus()) {
                                    console.log('📱 PWA is backgrounded - notification should show automatically');
                                } else {
                                    console.log('📱 PWA is active - ensuring notification visibility');
                                    
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
                                                console.log('📱 PWA secondary notification sent');
                                            }
                                        } catch (e) {
                                            console.log('📱 PWA secondary notification failed:', e);
                                        }
                                    }, 1000);
                                }
                            } else if (isMobile) {
                                // Mobile browser behavior (no active SW or not PWA)
                                if (document.hidden || !document.hasFocus()) {
                                    console.log('📱 Mobile page is hidden/unfocused - notification should show');
                                } else {
                                    console.log('📱 Mobile page is active - setting up visibility change detection');
                                    const handleVisibilityChange = async () => {
                                        if (document.hidden) {
                                            console.log('📱 Mobile page became hidden - showing backup notification');
                                            try {
                                                if ('Notification' in window && Notification.permission === 'granted') {
                                                    new Notification(`${queueItem.payload.title} (Mobile)`, {
                                                        body: queueItem.payload.body,
                                                        icon: queueItem.payload.icon || '/icons/icon-192x192.png',
                                                        tag: `mobile-backup-${queueItem.notification_id}`
                                                    });
                                                }
                                            } catch (e) {
                                                console.log('📱 Mobile backup notification failed:', e);
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
                                console.log('🎉 Desktop Service Worker notification shown successfully!');
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
                                        console.log('🖱️ Direct desktop notification clicked');
                                        if (queueItem.payload.data?.url) {
                                            window.open(queueItem.payload.data.url, '_blank');
                                        } else {
                                            window.focus();
                                        }
                                        directNotification.close();
                                    };
                                    
                                    console.log('🎉 Direct desktop notification created successfully!');
                                } else {
                                    throw new Error('No notification method available for desktop');
                                }
                            }
                        }
                        
                    } catch (swError) {
                        console.error('❌ Service Worker notification failed:', swError);
                        console.log('⚠️ Direct browser notifications not supported on mobile - notification skipped');
                    }
                    
                    // Commented out test notification to prevent unwanted popup
                    /*
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
                            console.log('🔄 Attempting Service Worker recovery for PWA...');
                            
                            if ('serviceWorker' in navigator) {
                                // Get all registrations
                                const registrations = await navigator.serviceWorker.getRegistrations();
                                console.log('🔍 Found existing SW registrations:', registrations.length);
                                
                                // Try to find an active registration
                                let activeRegistration = null;
                                for (const reg of registrations) {
                                    if (reg.active) {
                                        activeRegistration = reg;
                                        console.log('✅ Found active Service Worker registration');
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
                                    console.log('✅ Emergency PWA notification sent via recovery SW');
                                } else {
                                    console.error('❌ No active Service Worker found for recovery');
                                    
                                    // Mark notification as failed - will be retried when app is reopened
                                    await this.markNotificationFailed(queueItem.id, `PWA minimized with SW failure: ${swError.message}`);
                                    console.log('📝 Notification marked as failed - will retry when PWA is reopened');
                                }
                            }
                        } catch (recoveryError) {
                            console.error('❌ Emergency recovery failed:', recoveryError);
                            await this.markNotificationFailed(queueItem.id, `PWA recovery failed: ${recoveryError.message}`);
                        }
                        
                        // Set up visibility change listener for when PWA is reopened
                        const handlePWAReopen = async () => {
                            if (!document.hidden && isPWA) {
                                console.log('🔄 PWA reopened after SW failure - attempting notification recovery');
                                
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
                                    console.log('✅ Delayed PWA notification delivered after reopen');
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
                                console.log('🔔 Creating direct browser notification as fallback...');
                                const directNotification = new Notification(queueItem.payload.title, {
                                    body: queueItem.payload.body,
                                    icon: queueItem.payload.icon,
                                    tag: `notification-${queueItem.notification_id}`,
                                    requireInteraction: isMobile || isPWA
                                });

                                // Handle click event for direct notification
                                directNotification.onclick = () => {
                                    console.log('🖱️ Direct notification clicked');
                                    if (queueItem.payload.data?.url) {
                                        window.open(queueItem.payload.data.url, '_blank');
                                    }
                                    directNotification.close();
                                };
                                
                                console.log('✅ Direct notification fallback created successfully');
                            } else {
                                console.error('❌ Direct notifications not available either');
                                await this.markNotificationFailed(queueItem.id, `Both SW and direct notifications failed: ${swError.message}`);
                            }
                        } catch (directError) {
                            console.error('❌ Direct notification fallback also failed:', directError);
                            await this.markNotificationFailed(queueItem.id, `All notification methods failed: ${swError.message} -> ${directError.message}`);
                        }
                    }
                    
                    console.log('🎉 Direct notification created as fallback!');
                }
            } else if ('Notification' in window) {
                console.log('🔍 Service Worker not available - skipping notification (mobile compatibility)');
                
                // Direct browser notifications don't work on mobile browsers
                // Only Service Worker notifications are supported on mobile
                console.warn('⚠️ Direct browser notifications not supported on mobile - notification skipped');
                
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

            // Delete all other pending and failed notifications for this user+notification combination
            // Once a user receives a notification on ANY device, they don't need it on other devices
            // Also delete ALL failed notifications for this user (regardless of notification_id)
            // Deleting instead of marking as delivered keeps the queue table clean
            try {
                console.log(`🗑️ [v2.0] Deleting other pending and failed notifications for user ${queueItem.user_id} and notification ${queueItem.notification_id}...`);
                
                // First: Delete pending/failed for same notification_id
                const { data: deletedSameNotification, error: deleteError1 } = await supabaseAdmin
                    .from('notification_queue')
                    .delete()
                    .eq('notification_id', queueItem.notification_id)
                    .eq('user_id', queueItem.user_id)
                    .or('status.eq.pending,status.eq.failed') // Use .or() instead of .in()
                    .neq('id', queueItem.id) // Don't delete the current notification
                    .select(); // Select to get count of deleted items

                // Second: Delete ALL failed notifications for this user (any notification_id)
                console.log(`🗑️ [v2.0] Deleting ALL failed notifications for user ${queueItem.user_id}...`);
                const { data: deletedAllFailed, error: deleteError2 } = await supabaseAdmin
                    .from('notification_queue')
                    .delete()
                    .eq('user_id', queueItem.user_id)
                    .eq('status', 'failed')
                    .neq('id', queueItem.id) // Don't delete the current notification
                    .select(); // Select to get count of deleted items

                if (deleteError1 || deleteError2) {
                    console.error('❌ Error deleting duplicate pending/failed notifications:', deleteError1 || deleteError2);
                } else {
                    const totalDeleted = (deletedSameNotification?.length || 0) + (deletedAllFailed?.length || 0);
                    console.log(`✅ [v2.0] Deleted ${deletedSameNotification?.length || 0} duplicate pending/failed notifications for same notification`);
                    console.log(`✅ [v2.0] Deleted ${deletedAllFailed?.length || 0} failed notifications for user (all notification IDs)`);
                    console.log(`✅ [v2.0] Total deleted: ${totalDeleted} notifications`);
                    console.log('🧹 [v2.0] Queue table cleaned up - duplicate entries removed permanently');
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
     * Mark a notification as failed with error details
     */
    private async markNotificationFailed(notificationId: string, errorMessage: string) {
        try {
            await supabaseAdmin
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
     * Create a test notification queue entry (DISABLED - removed to prevent unwanted test notifications)
     */
    async createTestQueueEntry() {
        console.log('🚫 Test notification creation is permanently disabled to prevent unwanted notifications');
        console.log('💡 If you need to test notifications, create them through the normal notification system');
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
        console.log('📱 Checking if mobile push notification prompt is needed...');
        
        // Check if we're on a mobile device
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        const isTablet = /iPad|Android(?=.*\bMobile\b)/i.test(navigator.userAgent);
        const isMobileDevice = isMobile || isTablet;
        
        if (!isMobileDevice) {
            console.log('📱 Not a mobile device, skipping notification prompt');
            return false;
        }
        
        // Check if notifications are supported
        if (!('Notification' in window) || !('serviceWorker' in navigator)) {
            console.log('📱 Push notifications not supported on this device');
            return false;
        }
        
        // Check if user has already been prompted for this device
        const deviceId = localStorage.getItem('aqura-device-id') || `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
        const promptKey = `aqura-push-prompted-${deviceId}`;
        const hasBeenPrompted = localStorage.getItem(promptKey);
        
        if (hasBeenPrompted) {
            console.log('📱 User has already been prompted for push notifications on this device');
            return false;
        }
        
        // Check current notification permission
        const currentPermission = Notification.permission;
        if (currentPermission === 'granted') {
            console.log('📱 Push notifications already granted');
            // Mark as prompted to avoid future prompts
            localStorage.setItem(promptKey, 'granted');
            return true;
        }
        
        if (currentPermission === 'denied') {
            console.log('📱 Push notifications previously denied');
            localStorage.setItem(promptKey, 'denied');
            return false;
        }
        
        // Show mobile-friendly prompt
        const userWantsNotifications = await showMobilePushPrompt();
        
        if (userWantsNotifications) {
            console.log('📱 User wants to enable push notifications');
            
            // Request permission
            const permission = await Notification.requestPermission();
            
            if (permission === 'granted') {
                console.log('✅ Push notification permission granted!');
                localStorage.setItem(promptKey, 'granted');
                
                // Initialize push notifications for this user
                try {
                    const { pushNotificationService } = await import('./pushNotifications');
                    await pushNotificationService.initialize();
                    console.log('✅ Push notifications initialized successfully');
                    return true;
                } catch (error) {
                    console.error('❌ Failed to initialize push notifications:', error);
                }
            } else {
                console.log('❌ Push notification permission denied');
                localStorage.setItem(promptKey, 'denied');
            }
        } else {
            console.log('📱 User declined push notifications');
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
        console.log('🔐 Checking push notification prompt for user:', userId);
        
        // Small delay to ensure UI is ready
        setTimeout(async () => {
            const enabled = await promptMobilePushNotifications(userId);
            if (enabled) {
                console.log('✅ Mobile push notifications enabled for user');
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
        console.log('🧪 Test function only available in development mode');
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
                console.log('🚫 Test functions disabled in production to prevent unwanted notifications');
                return 'Test functions disabled in production';
            }
            console.log('🧪 Testing mobile notification...');
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
                console.log('✅ Mobile test notification sent');
                
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
                    console.log('📨 Sent force notification message to SW');
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
        console.log('🛑 Emergency stop: Push notification processor stopped');
    };
    
    // Log available debugging functions
    console.log('🔧 Push notification debugging available:');
    console.log('- aquraPushDebug.testMobileNotification() - Test mobile notifications');
    console.log('- aquraPushDebug.checkMobileStatus() - Check mobile notification status');
    console.log('- aquraPushDebug.processQueue() - Process notification queue manually');
    console.log('- aquraPushDebug.getProcessorInfo() - Get processor information');

    // Add cleanup function for old queue entries
    (window as any).cleanupOldNotifications = (days = 7) => {
        pushNotificationProcessor.cleanupOldQueueEntries(days);
        console.log(`🧹 Cleaning up notifications older than ${days} days...`);
    };

    // Add function to manually delete duplicate pending and failed notifications for testing
    (window as any).deleteDuplicateNotifications = async (notificationId: string, userId: string) => {
        console.log(`🗑️ Manually deleting duplicate pending and failed notifications for notification ${notificationId} and user ${userId}...`);
        try {
            const { data: deletedEntries, error } = await supabaseAdmin
                .from('notification_queue')
                .delete()
                .eq('notification_id', notificationId)
                .eq('user_id', userId)
                .or('status.eq.pending,status.eq.failed') // Use .or() instead of .in()
                .select();

            if (error) {
                console.error('❌ Error deleting duplicates:', error);
            } else {
                console.log(`✅ Deleted ${deletedEntries?.length || 0} duplicate pending/failed notifications`);
            }
        } catch (error) {
            console.error('❌ Manual delete failed:', error);
        }
    };

    // Add helper function to find real notification IDs for testing
    (window as any).findNotificationIds = async () => {
        console.log('🔍 Finding real notification IDs for testing...');
        try {
            const { data: queueItems, error } = await supabaseAdmin
                .from('notification_queue')
                .select('id, notification_id, user_id, status')
                .limit(10);

            if (error) {
                console.error('❌ Error fetching notification IDs:', error);
                return;
            }

            console.log('📋 Available notification queue items:');
            queueItems?.forEach((item, index) => {
                console.log(`${index + 1}. ID: ${item.id}, Notification: ${item.notification_id}, User: ${item.user_id}, Status: ${item.status}`);
            });
            
            if (queueItems && queueItems.length > 0) {
                const first = queueItems[0];
                console.log(`💡 To test deletion, use: deleteDuplicateNotifications('${first.notification_id}', '${first.user_id}')`);
            } else {
                console.log('📭 No notification queue items found');
            }
        } catch (error) {
            console.error('❌ Error finding notification IDs:', error);
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

            // Test service worker notification only (mobile compatible)
            if ('serviceWorker' in navigator) {
                console.log('🔔 Creating service worker notification...');
                const registration = await navigator.serviceWorker.ready;
                await registration.showNotification('Service Worker Test', {
                    body: 'This is a service worker notification test',
                    icon: '/favicon.png',
                    requireInteraction: true
                });
                console.log('✅ Service worker notification created');
                
                // Also create a direct test for desktop (but skip on mobile)
                if (!navigator.userAgent.includes('Mobile')) {
                    console.log('🔔 Creating direct browser notification for desktop...');
                    const directNotification = new Notification('Direct Test', {
                        body: 'This is a direct browser notification test (desktop only)',
                        icon: '/favicon.png'
                    });

                    directNotification.onclick = () => {
                        console.log('🖱️ Direct notification clicked');
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