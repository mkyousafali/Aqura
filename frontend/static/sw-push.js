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

        const options = {
            body: payload.body,
            icon: payload.icon || '/icons/icon-192x192.png',
            badge: payload.badge || '/icons/icon-96x96.png',
            tag: payload.tag || 'aqura-notification',
            data: payload.data || {},
            requireInteraction: true,
            actions: [
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

        event.waitUntil(
            self.registration.showNotification(payload.title, options)
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

self.addEventListener('notificationclick', event => {
    console.log('🖱️ Notification clicked:', event);
    
    event.notification.close();

    if (event.action === 'close') {
        return;
    }

    // Open or focus the app
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clientList => {
            // If there's already a window open, focus it
            for (let client of clientList) {
                if (client.url.includes(self.location.origin) && 'focus' in client) {
                    return client.focus();
                }
            }
            
            // Otherwise, open a new window
            if (clients.openWindow) {
                const url = event.notification.data?.url || '/';
                return clients.openWindow(url);
            }
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