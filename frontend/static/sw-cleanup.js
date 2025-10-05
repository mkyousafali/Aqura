// Service Worker Cleanup Utility
// This runs automatically when the app starts

console.log('🧹 SW Cleanup utility loaded');

// Auto-cleanup on page load
if ('serviceWorker' in navigator) {
    window.addEventListener('load', async () => {
        try {
            // Get all registrations
            const registrations = await navigator.serviceWorker.getRegistrations();
            
            // Count total registrations
            console.log(`Found ${registrations.length} service worker registrations`);
            
            // In development, be more aggressive
            const isDev = window.location.hostname === 'localhost' || 
                         window.location.hostname === '127.0.0.1';
            
            if (isDev && registrations.length > 1) {
                console.log('🚧 Development mode: Cleaning up multiple service workers...');
                
                // Keep only the newest registration
                registrations.sort((a, b) => {
                    const aTime = a.installing?.scriptURL || a.waiting?.scriptURL || a.active?.scriptURL || '';
                    const bTime = b.installing?.scriptURL || b.waiting?.scriptURL || b.active?.scriptURL || '';
                    return bTime.localeCompare(aTime);
                });
                
                // Unregister all but the first (newest)
                for (let i = 1; i < registrations.length; i++) {
                    console.log(`🗑️ Removing old SW: ${registrations[i].scope}`);
                    await registrations[i].unregister();
                }
            }
            
            // Clean up old caches
            const cacheNames = await caches.keys();
            const oldCachePattern = /^(sw-|workbox-|runtime-|precache-)/;
            const currentVersion = 'v2'; // Update this when you want to force cache cleanup
            
            for (const cacheName of cacheNames) {
                if (oldCachePattern.test(cacheName) && !cacheName.includes(currentVersion)) {
                    console.log(`🗑️ Deleting old cache: ${cacheName}`);
                    await caches.delete(cacheName);
                }
            }
            
        } catch (error) {
            console.warn('⚠️ SW cleanup error:', error);
        }
    });
}