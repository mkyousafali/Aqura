// Stop All Service Workers via JavaScript Console
// Run this in your browser's console (F12 -> Console tab)

// Function to unregister all service workers
async function stopAllServiceWorkers() {
    console.log('🔄 Starting service worker cleanup...');
    
    if ('serviceWorker' in navigator) {
        try {
            // Get all registrations
            const registrations = await navigator.serviceWorker.getRegistrations();
            console.log(`Found ${registrations.length} service worker(s)`);
            
            // Unregister each one
            for (let registration of registrations) {
                console.log('Unregistering:', registration.scope);
                await registration.unregister();
            }
            
            console.log('✅ All service workers unregistered');
            
            // Clear caches
            if ('caches' in window) {
                const cacheNames = await caches.keys();
                console.log(`Found ${cacheNames.length} cache(s)`);
                
                for (let cacheName of cacheNames) {
                    console.log('Deleting cache:', cacheName);
                    await caches.delete(cacheName);
                }
                console.log('✅ All caches cleared');
            }
            
            // Clear local storage
            localStorage.clear();
            sessionStorage.clear();
            console.log('✅ Storage cleared');
            
            console.log('🎉 Complete cleanup finished! Please refresh the page.');
            
        } catch (error) {
            console.error('❌ Error during cleanup:', error);
        }
    } else {
        console.log('❌ Service workers not supported');
    }
}

// Run the cleanup
stopAllServiceWorkers();