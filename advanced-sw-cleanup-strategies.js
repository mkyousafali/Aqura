// Advanced Service Worker Auto-Cleanup Strategy
// Add this to your +layout.svelte for smarter cleanup

// Option 1: Clean up only conflicting/old service workers
async function smartServiceWorkerCleanup() {
    console.log('🔍 Starting smart service worker cleanup...');
    
    if ('serviceWorker' in navigator) {
        try {
            const registrations = await navigator.serviceWorker.getRegistrations();
            
            for (let registration of registrations) {
                const isOldWorker = 
                    registration.scope.includes('/sw-advanced') ||
                    registration.scope.includes('/sw.js') ||
                    (registration.active && registration.active.scriptURL.includes('sw-advanced')) ||
                    (registration.active && registration.active.scriptURL.includes('/sw.js'));
                
                if (isOldWorker) {
                    console.log('🗑️ Removing old/conflicting service worker:', registration.scope);
                    await registration.unregister();
                } else {
                    console.log('✅ Keeping valid service worker:', registration.scope);
                }
            }
            
            // Clear only problematic caches
            const cacheNames = await caches.keys();
            const problemCaches = cacheNames.filter(name => 
                name.includes('sw-advanced') || 
                name.includes('old-cache') ||
                name.startsWith('v1-') // Old version caches
            );
            
            for (let cacheName of problemCaches) {
                await caches.delete(cacheName);
                console.log(`🗑️ Removed problematic cache: ${cacheName}`);
            }
            
        } catch (error) {
            console.warn('⚠️ Smart cleanup failed:', error);
        }
    }
}

// Option 2: Version-based cleanup
async function versionBasedCleanup() {
    const CURRENT_SW_VERSION = '2.0'; // Update this when you want to force cleanup
    const lastCleanupVersion = localStorage.getItem('sw-cleanup-version');
    
    if (lastCleanupVersion !== CURRENT_SW_VERSION) {
        console.log('🔄 New version detected, cleaning up old service workers...');
        
        // Perform full cleanup
        const registrations = await navigator.serviceWorker.getRegistrations();
        for (let registration of registrations) {
            await registration.unregister();
        }
        
        // Clear all caches
        const cacheNames = await caches.keys();
        for (let cacheName of cacheNames) {
            await caches.delete(cacheName);
        }
        
        // Mark cleanup as done for this version
        localStorage.setItem('sw-cleanup-version', CURRENT_SW_VERSION);
        console.log('✅ Version-based cleanup completed');
    }
}

// Option 3: Development mode aggressive cleanup
async function devModeCleanup() {
    // Only run in development
    if (import.meta.env.DEV) {
        console.log('🚧 Development mode: Performing aggressive SW cleanup...');
        
        const registrations = await navigator.serviceWorker.getRegistrations();
        for (let registration of registrations) {
            await registration.unregister();
        }
        
        const cacheNames = await caches.keys();
        for (let cacheName of cacheNames) {
            await caches.delete(cacheName);
        }
        
        // Clear all storage
        localStorage.removeItem('workbox-precache');
        sessionStorage.clear();
        
        console.log('🧹 Development cleanup completed');
    }
}