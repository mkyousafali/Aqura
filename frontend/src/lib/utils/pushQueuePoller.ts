// Client-side push notification queue processor
// This runs in the browser and triggers the Edge Function periodically
// Use this when pg_cron is not available (Supabase free tier)

import { supabaseAdmin } from './supabase';
import { browser } from '$app/environment';

class PushQueuePoller {
    private intervalId: NodeJS.Timeout | null = null;
    private isProcessing = false;
    private pollInterval = 30000; // 30 seconds
    
    /**
     * Start polling the push notification queue
     * Should be called once when the app initializes (for admin users only)
     */
    start() {
        if (!browser) return;
        
        // Only run on one tab (use leader election)
        if (this.intervalId) return;
        
        console.log('🔄 Starting push notification queue poller...');
        
        // Process immediately
        this.processQueue();
        
        // Then poll every 30 seconds
        this.intervalId = setInterval(() => {
            this.processQueue();
        }, this.pollInterval);
    }
    
    /**
     * Stop polling
     */
    stop() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
            console.log('⏹️ Stopped push notification queue poller');
        }
    }
    
    /**
     * Manually trigger queue processing
     */
    async processQueue(): Promise<void> {
        if (this.isProcessing) {
            console.log('⏳ Queue processing already in progress, skipping...');
            return;
        }
        
        this.isProcessing = true;
        
        try {
            const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
            
            const response = await fetch(`${SUPABASE_URL}/functions/v1/process-push-queue`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({})
            });
            
            if (response.ok) {
                const result = await response.json();
                if (result.processed > 0) {
                    console.log(`📤 Push queue processed: ${result.sent} sent, ${result.failed} failed`);
                }
            } else {
                console.warn('⚠️ Push queue processing failed:', response.status);
            }
        } catch (error) {
            // Silently handle errors to avoid console spam
            console.debug('Push queue polling error:', error);
        } finally {
            this.isProcessing = false;
        }
    }
}

// Singleton instance
export const pushQueuePoller = new PushQueuePoller();

// Auto-start for admin users
if (browser) {
    // Start polling when the module loads (will be active on all pages)
    // You can add logic here to only start for admin users
    pushQueuePoller.start();
    
    // Clean up on page unload
    window.addEventListener('beforeunload', () => {
        pushQueuePoller.stop();
    });
}
