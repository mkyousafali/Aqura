// Custom Service Worker for Push Notifications
// This handles push notification events

self.addEventListener('push', event => {
    console.log('🔔 Push event received:', event);
    
    if (!event.data) {
        console.warn('Push event has no data');
        return;
    }

    try {
        const payload = event.data.json();
        console.log('📨 Push notification payload:', payload);

        // Mobile and PWA-optimized notification options
        const isMobile = payload.data?.isMobile || false;
        const isPWA = payload.data?.isPWA || false;
        const displayMode = payload.data?.displayMode || 'browser';
        
        console.log(`📱 Notification environment - Mobile: ${isMobile}, PWA: ${isPWA}, Display: ${displayMode}`);

        const options = {
            body: payload.body,
            icon: payload.icon || '/icons/icon-192x192.png',
            badge: (isPWA && payload.badge) ? payload.badge : '/icons/icon-96x96.png',
            tag: payload.tag || 'aqura-notification',
            data: {
                ...payload.data,
                timestamp: Date.now(),
                source: 'push-event',
                environment: isPWA ? 'pwa' : isMobile ? 'mobile' : 'desktop',
                displayMode: displayMode
            },
            requireInteraction: isPWA || isMobile, // PWA and mobile require interaction
            silent: false,
            // Enhanced vibration patterns
            vibrate: (isPWA && isMobile) ? [300, 100, 300, 100, 300] : 
                     isMobile ? [200, 100, 200, 100, 200] : [200, 100, 200],
            // Environment-specific actions
            actions: (isPWA && !isMobile) ? [
                {
                    action: 'open',
                    title: 'Open App',
                    icon: '/icons/icon-96x96.png'
                },
                {
                    action: 'view',
                    title: 'View Details',
                    icon: '/icons/icon-96x96.png'
                }
            ] : (isPWA || isMobile) ? [
                {
                    action: 'open',
                    title: 'Open',
                    icon: '/icons/icon-96x96.png'
                }
            ] : [
                {
                    action: 'open',
                    title: 'View',
                    icon: '/icons/icon-96x96.png'
                },
                {
                    action: 'close',
                    title: 'Close',
                    icon: '/icons/icon-96x96.png'
                }
            ]
        };

        console.log('🔔 Showing push notification with options:', options);

        event.waitUntil(
            self.registration.showNotification(payload.title, options)
                .then(() => {
                    console.log('✅ Push notification shown successfully');
                })
                .catch(error => {
                    console.error('❌ Failed to show push notification:', error);
                    // Fallback notification
                    return self.registration.showNotification('New Notification', {
                        body: 'You have a new notification from Aqura',
                        icon: '/icons/icon-192x192.png',
                        badge: '/icons/icon-96x96.png',
                        requireInteraction: isMobile
                    });
                })
        );
    } catch (error) {
        console.error('❌ Error handling push event:', error);
        // Fallback notification
        event.waitUntil(
            self.registration.showNotification('New Notification', {
                body: 'You have a new notification from Aqura',
                icon: '/icons/icon-192x192.png',
                badge: '/icons/icon-96x96.png'
            })
        );
    }
});

// Handle messages from the main thread (for mobile force notifications)
self.addEventListener('message', event => {
    console.log('📨 Service Worker received message:', event.data);
    
    if (event.data.type === 'FORCE_SHOW_NOTIFICATION') {
        console.log('📱 Force showing notification');
        const { title, options, isMobile, isPWA, displayMode } = event.data;
        
        console.log(`📱 Environment - Mobile: ${isMobile}, PWA: ${isPWA}, Display: ${displayMode}`);
        
        // Enhanced options based on environment
        const enhancedOptions = {
            ...options,
            requireInteraction: isPWA || isMobile, // PWA and mobile should require interaction
            silent: false,
            // Enhanced vibration for PWA on mobile
            vibrate: (isPWA && isMobile) ? [300, 100, 300, 100, 300] : 
                     isMobile ? [200, 100, 200, 100, 200] : [200, 100, 200],
            // PWA-optimized badge
            badge: isPWA ? '/icons/badge-icon.png' : (options.badge || '/icons/icon-96x96.png'),
            data: {
                ...options.data,
                source: 'force-show',
                timestamp: Date.now(),
                environment: isPWA ? 'pwa' : isMobile ? 'mobile' : 'desktop',
                displayMode: displayMode || 'browser',
                serviceWorkerForced: true
            },
            // PWA can have more sophisticated actions
            actions: (isPWA && !isMobile) ? [
                {
                    action: 'open',
                    title: 'Open App',
                    icon: '/icons/icon-96x96.png'
                },
                {
                    action: 'view',
                    title: 'View Details'
                }
            ] : (isPWA || isMobile) ? [
                {
                    action: 'open',
                    title: 'Open',
                    icon: '/icons/icon-96x96.png'
                }
            ] : [
                {
                    action: 'open',
                    title: 'View',
                    icon: '/icons/icon-96x96.png'
                },
                {
                    action: 'close',
                    title: 'Close'
                }
            ]
        };
        
        event.waitUntil(
            self.registration.showNotification(title, enhancedOptions)
                .then(() => {
                    console.log(`✅ Force notification shown successfully for ${isPWA ? 'PWA' : isMobile ? 'mobile' : 'desktop'}`);
                    // Send confirmation back to main thread
                    if (event.ports && event.ports[0]) {
                        event.ports[0].postMessage({ 
                            success: true, 
                            message: 'Notification shown',
                            environment: isPWA ? 'pwa' : isMobile ? 'mobile' : 'desktop'
                        });
                    }
                })
                .catch(error => {
                    console.error('❌ Force notification failed:', error);
                    if (event.ports && event.ports[0]) {
                        event.ports[0].postMessage({ success: false, error: error.message });
                    }
                })
        );
    }
});

self.addEventListener('notificationclick', event => {
    console.log('🖱️ Notification clicked:', event);
    console.log('🖱️ Notification data:', event.notification.data);
    
    event.notification.close();

    if (event.action === 'close') {
        console.log('🖱️ Close action clicked');
        return;
    }

    const isPWA = event.notification.data?.environment === 'pwa' || 
                  event.notification.data?.displayMode === 'standalone';
    const targetUrl = event.notification.data?.url || '/';
    
    console.log(`🖱️ Opening URL: ${targetUrl} in ${isPWA ? 'PWA' : 'browser'} mode`);

    // Enhanced window handling for PWA vs browser
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
            console.log(`🖱️ Found ${clientList.length} existing clients`);
            
            // For PWA, prioritize finding existing PWA windows
            if (isPWA) {
                for (let client of clientList) {
                    // Check if client is in standalone mode (PWA)
                    if (client.url.includes(self.location.origin)) {
                        console.log('🖱️ Found existing PWA window, focusing it');
                        if ('focus' in client) {
                            return client.focus().then(client => {
                                // Navigate to specific URL if provided
                                if (targetUrl !== '/' && 'postMessage' in client) {
                                    client.postMessage({
                                        type: 'NOTIFICATION_CLICK_NAVIGATE',
                                        url: targetUrl,
                                        isPWA: true
                                    });
                                }
                                return client;
                            });
                        }
                    }
                }
            } else {
                // For browser notifications, find any matching window
                for (let client of clientList) {
                    if (client.url.includes(self.location.origin) && 'focus' in client) {
                        console.log('🖱️ Found existing browser window, focusing it');
                        return client.focus().then(client => {
                            if (targetUrl !== '/' && 'postMessage' in client) {
                                client.postMessage({
                                    type: 'NOTIFICATION_CLICK_NAVIGATE',
                                    url: targetUrl,
                                    isPWA: false
                                });
                            }
                            return client;
                        });
                    }
                }
            }
            
            // No existing window found, open a new one
            if (clients.openWindow) {
                console.log(`🖱️ Opening new ${isPWA ? 'PWA' : 'browser'} window`);
                const fullUrl = new URL(targetUrl, self.location.origin).href;
                return clients.openWindow(fullUrl);
            }
        }).catch(error => {
            console.error('🖱️ Error handling notification click:', error);
        })
    );
});

self.addEventListener('notificationclose', event => {
    console.log('🔔 Notification closed:', event);
});

// Install event
self.addEventListener('install', event => {
    console.log('🚀 Push Service Worker installed');
    // Force immediate activation without waiting for old worker to finish
    event.waitUntil(self.skipWaiting());
});

// Activate event
self.addEventListener('activate', event => {
    console.log('✅ Push Service Worker activated');
    // Take control of all clients immediately
    event.waitUntil(
        self.clients.claim().then(() => {
            console.log('🎯 Push Service Worker now controlling all clients');
        })
    );
});