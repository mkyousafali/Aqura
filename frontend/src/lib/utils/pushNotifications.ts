/**
 * Push Notifications Utility
 * Handles web push notification subscription and management
 */

import { supabase } from './supabase';
import { get } from 'svelte/store';
import { currentUser } from './persistentAuth';

// Convert VAPID key from base64 to Uint8Array
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/\-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

/**
 * Check if push notifications are supported in this browser
 */
export function isPushSupported(): boolean {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
}

/**
 * Get current push notification permission status
 */
export function getPermissionStatus(): NotificationPermission {
  if (!isPushSupported()) {
    return 'denied';
  }
  return Notification.permission;
}

/**
 * Request notification permission from the user
 */
export async function requestNotificationPermission(): Promise<NotificationPermission> {
  if (!isPushSupported()) {
    throw new Error('Push notifications are not supported in this browser');
  }

  const permission = await Notification.requestPermission();
  console.log('📬 [Push] Permission result:', permission);
  return permission;
}

/**
 * Subscribe user to push notifications
 * This creates a subscription with the browser's push service
 */
export async function subscribeToPushNotifications(): Promise<PushSubscription | null> {
  try {
    console.log('📬 [Push] Starting subscription process...');
    
    // Check if supported
    if (!isPushSupported()) {
      throw new Error('Push notifications not supported');
    }

    // Check if user is logged in
    const user = get(currentUser);
    if (!user?.id) {
      throw new Error('User not logged in. Please log in first.');
    }
    console.log('📬 [Push] User logged in:', user.id);

    // Request permission if not granted
    console.log('📬 [Push] Requesting permission...');
    const permission = await requestNotificationPermission();
    if (permission !== 'granted') {
      console.log('📬 [Push] Permission denied');
      return null;
    }
    console.log('📬 [Push] Permission granted');

    // Ensure service worker is registered
    console.log('📬 [Push] Checking service worker registration...');
    let registration: ServiceWorkerRegistration;
    
    try {
      // Try to get existing registration
      registration = await navigator.serviceWorker.getRegistration();
      
      if (!registration) {
        console.log('📬 [Push] No service worker found, registering...');
        // Register service worker if not already registered
        registration = await navigator.serviceWorker.register('/sw.js', {
          scope: '/'
        });
        console.log('📬 [Push] Service worker registered');
        
        // Wait for it to be ready
        registration = await navigator.serviceWorker.ready;
      } else {
        console.log('📬 [Push] Service worker already registered');
        // Still wait for ready state
        registration = await Promise.race([
          navigator.serviceWorker.ready,
          new Promise<ServiceWorkerRegistration>((resolve) => {
            // If already active, resolve immediately
            if (registration.active) {
              resolve(registration);
            } else {
              setTimeout(() => resolve(registration), 100);
            }
          })
        ]);
      }
    } catch (swError) {
      console.error('📬 [Push] Service worker error:', swError);
      throw new Error('Service worker is not available. Please refresh the page and try again.');
    }
    
    console.log('📬 [Push] Service worker ready');

    // Check for existing subscription
    let subscription = await registration.pushManager.getSubscription();
    
    if (subscription) {
      console.log('📬 [Push] Existing subscription found');
      // Save to database if not already saved
      await savePushSubscription(subscription);
      return subscription;
    }

    // Create new subscription
    const vapidPublicKey = import.meta.env.VITE_VAPID_PUBLIC_KEY;
    if (!vapidPublicKey) {
      throw new Error('VAPID public key not configured in environment');
    }
    console.log('📬 [Push] VAPID key found, subscribing...');

    const convertedVapidKey = urlBase64ToUint8Array(vapidPublicKey);
    
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: convertedVapidKey
    });

    console.log('📬 [Push] New subscription created');

    // Save subscription to database
    await savePushSubscription(subscription);

    return subscription;
  } catch (error) {
    console.error('📬 [Push] Error subscribing:', error);
    throw error;
  }
}

/**
 * Unsubscribe from push notifications
 */
export async function unsubscribeFromPushNotifications(): Promise<boolean> {
  try {
    if (!isPushSupported()) {
      return false;
    }

    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      // Unsubscribe from push service
      const success = await subscription.unsubscribe();
      
      if (success) {
        console.log('📬 [Push] Unsubscribed successfully');
        // Remove from database
        await removePushSubscription(subscription.endpoint);
        return true;
      }
    }

    return false;
  } catch (error) {
    console.error('📬 [Push] Error unsubscribing:', error);
    return false;
  }
}

/**
 * Save push subscription to database
 */
async function savePushSubscription(subscription: PushSubscription): Promise<void> {
  try {
    const user = get(currentUser);
    if (!user?.id) {
      throw new Error('User not logged in');
    }

    const subscriptionData = {
      user_id: user.id,
      subscription: subscription.toJSON(),
      endpoint: subscription.endpoint,
      user_agent: navigator.userAgent,
      is_active: true
    };

    console.log('📬 [Push] Saving subscription to database for user:', user.id);

    // Upsert with timeout - update if exists, insert if new
    const savePromise = supabase
      .from('push_subscriptions')
      .upsert(subscriptionData, {
        onConflict: 'endpoint'
      })
      .select()
      .single();

    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Database save timeout after 15 seconds')), 15000)
    );

    const { data, error } = await Promise.race([savePromise, timeoutPromise]) as any;

    if (error) {
      console.error('📬 [Push] Database error:', error);
      if (error.code === '42501') {
        throw new Error('Database permission error. Please contact administrator.');
      }
      throw new Error(`Database error: ${error.message}`);
    }

    console.log('📬 [Push] ✅ Subscription saved to database');
  } catch (error) {
    console.error('📬 [Push] Error saving subscription:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to save subscription to database');
  }
}

/**
 * Remove push subscription from database
 */
async function removePushSubscription(endpoint: string): Promise<void> {
  try {
    const { error } = await supabase
      .from('push_subscriptions')
      .delete()
      .eq('endpoint', endpoint);

    if (error) {
      console.error('📬 [Push] Error removing from database:', error);
      throw error;
    }

    console.log('📬 [Push] ✅ Subscription removed from database');
  } catch (error) {
    console.error('📬 [Push] Error removing subscription:', error);
    throw error;
  }
}

/**
 * Check if user has an active push subscription
 */
export async function hasActiveSubscription(): Promise<boolean> {
  try {
    if (!isPushSupported()) {
      return false;
    }

    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    
    return subscription !== null;
  } catch (error) {
    console.error('📬 [Push] Error checking subscription:', error);
    return false;
  }
}

/**
 * Get current push subscription
 */
export async function getCurrentSubscription(): Promise<PushSubscription | null> {
  try {
    if (!isPushSupported()) {
      return null;
    }

    const registration = await navigator.serviceWorker.ready;
    return await registration.pushManager.getSubscription();
  } catch (error) {
    console.error('📬 [Push] Error getting subscription:', error);
    return null;
  }
}

/**
 * Test notification - shows a local notification to test if it's working
 */
export async function sendTestNotification(): Promise<void> {
  try {
    const permission = await requestNotificationPermission();
    if (permission !== 'granted') {
      throw new Error('Notification permission not granted');
    }

    const registration = await navigator.serviceWorker.ready;
    await registration.showNotification('Test Notification', {
      body: 'Push notifications are working! 🎉',
      icon: '/icons/icon-192x192.png',
      badge: '/icons/icon-72x72.png',
      vibrate: [200, 100, 200],
      tag: 'test-notification',
      requireInteraction: false,
      data: {
        url: '/mobile/notifications',
        type: 'test',
        notificationId: 'test-' + Date.now()
      }
    });

    console.log('📬 [Push] Test notification sent');
  } catch (error) {
    console.error('📬 [Push] Error sending test notification:', error);
    throw error;
  }
}
