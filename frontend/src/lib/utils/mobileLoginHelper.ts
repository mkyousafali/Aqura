/**
 * Mobile Login Helper
 * This utility helps integrate push notification prompts into the login flow
 */

import { checkAndPromptPushNotifications } from './pushNotificationProcessor';

/**
 * Call this function after a successful user login
 * It will automatically check if the user should be prompted for push notifications
 */
export async function handleUserLogin(userId: string, isFirstLogin?: boolean): Promise<void> {
    try {
        console.log('🔐 User logged in:', userId);
        
        // If this is explicitly marked as first login, or we detect mobile device
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        
        if (isMobile || isFirstLogin) {
            console.log('📱 Mobile device detected or first login, checking push notification prompt...');
            await checkAndPromptPushNotifications(userId);
        }
        
    } catch (error) {
        console.error('❌ Error in user login handler:', error);
    }
}

/**
 * Manually trigger push notification prompt for current user
 * Useful for settings page or manual activation
 */
export async function manuallyPromptPushNotifications(userId: string): Promise<boolean> {
    try {
        const { promptMobilePushNotifications } = await import('./pushNotificationProcessor');
        return await promptMobilePushNotifications(userId);
    } catch (error) {
        console.error('❌ Error in manual push notification prompt:', error);
        return false;
    }
}

/**
 * Check if user has already been prompted for push notifications on this device
 */
export function hasBeenPromptedForPushNotifications(): boolean {
    const deviceId = localStorage.getItem('aqura-device-id');
    if (!deviceId) return false;
    
    const promptKey = `aqura-push-prompted-${deviceId}`;
    return localStorage.getItem(promptKey) !== null;
}

/**
 * Get the push notification prompt status for this device
 */
export function getPushNotificationPromptStatus(): 'never' | 'granted' | 'denied' | 'declined' {
    const deviceId = localStorage.getItem('aqura-device-id');
    if (!deviceId) return 'never';
    
    const promptKey = `aqura-push-prompted-${deviceId}`;
    const status = localStorage.getItem(promptKey);
    
    if (!status) return 'never';
    return status as 'granted' | 'denied' | 'declined';
}

/**
 * Reset push notification prompt status (for testing or settings reset)
 */
export function resetPushNotificationPromptStatus(): void {
    const deviceId = localStorage.getItem('aqura-device-id');
    if (deviceId) {
        const promptKey = `aqura-push-prompted-${deviceId}`;
        localStorage.removeItem(promptKey);
        console.log('🔄 Push notification prompt status reset');
    }
}