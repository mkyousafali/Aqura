/**
 * Push Notifications Utility
 * Handles web push notification subscription and management
 */

import { supabase } from './supabase';
import { get } from 'svelte/store';
import { currentUser } from './persistentAuth';

// Per-device manual opt-out. Set when the user explicitly disables push on
// this device via the toggle; cleared when they explicitly re-enable it.
// Prevents autoSubscribePush() from silently re-subscribing this device just
// because it becomes the "latest" one for its interface.
const PUSH_MANUALLY_DISABLED_KEY = 'aqura-push-manually-disabled';

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

    // Explicit user action: clear any prior manual opt-out for this device
    try {
      localStorage.removeItem(PUSH_MANUALLY_DISABLED_KEY);
    } catch {
      // ignore
    }

    // In dev mode, skip SW registration to avoid intercepting Supabase requests
    if (!import.meta.env.PROD) {
      console.log('📬 [Push] Skipping SW registration in dev mode');
      return null;
    }

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
      await savePushSubscription(subscription, { reactivate: true });
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
    await savePushSubscription(subscription, { reactivate: true });

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
        // Mark this device as manually disabled (keeps the DB row, but
        // prevents it from being silently re-activated later) rather than
        // deleting it outright.
        await disablePushSubscriptionForDevice(subscription.endpoint);
        try {
          localStorage.setItem(PUSH_MANUALLY_DISABLED_KEY, '1');
        } catch {
          // ignore
        }
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
 * Save push subscription to database. Makes this endpoint the sole active
 * subscription for this user's interface (mobile/desktop) — any other
 * device previously registered for the same interface is deactivated, so
 * only the latest device per interface receives pushes. Applies to Master
 * Admin too.
 *
 * Pass `reactivate: true` only for an explicit user action (re-enabling the
 * toggle on this device) — it clears a prior manual opt-out. Silent/auto
 * calls (e.g. on login) must leave a manual opt-out in place.
 */
async function savePushSubscription(
  subscription: PushSubscription,
  options: { reactivate?: boolean } = {}
): Promise<void> {
  try {
    const user = get(currentUser);
    if (!user?.id) {
      throw new Error('User not logged in');
    }

    console.log('📬 [Push] Saving subscription to database for user:', user.id);

    const savePromise = supabase.rpc('save_push_subscription_scoped', {
      p_user_id: user.id,
      p_endpoint: subscription.endpoint,
      p_subscription: subscription.toJSON(),
      p_user_agent: navigator.userAgent,
      p_interface_type: user.interfaceType ?? null,
      p_reactivate: options.reactivate ?? false
    });

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

    if (data && data.success === false) {
      throw new Error(data.error || 'Failed to save subscription');
    }

    console.log('📬 [Push] ✅ Subscription saved to database (active:', data?.active, ')');
  } catch (error) {
    console.error('📬 [Push] Error saving subscription:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to save subscription to database');
  }
}

/**
 * Mark this device's subscription as manually disabled — an explicit,
 * per-device opt-out that persists even if this device later becomes the
 * "latest" one for its interface.
 */
async function disablePushSubscriptionForDevice(endpoint: string): Promise<void> {
  try {
    const { error } = await supabase.rpc('disable_push_subscription_device', {
      p_endpoint: endpoint
    });
    if (error) {
      console.error('📬 [Push] Error disabling subscription:', error);
      throw error;
    }
    console.log('📬 [Push] ✅ Subscription manually disabled for this device');
  } catch (error) {
    console.error('📬 [Push] Error disabling subscription:', error);
    throw error;
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

/**
 * Auto-subscribe to push notifications silently on login.
 * Does NOT throw — safe to call fire-and-forget.
 * Works on all devices; each device registers its own subscription.
 */
export async function autoSubscribePush(): Promise<void> {
  try {
    if (!isPushSupported()) {
      console.log('📬 [Push-Auto] Push not supported in this browser, skipping');
      return;
    }

    // Skip in dev mode — service workers don't work with Vite HMR
    if (!import.meta.env.PROD) {
      console.log('📬 [Push-Auto] Skipping in dev mode');
      return;
    }

    const user = get(currentUser);
    if (!user?.id) {
      console.log('📬 [Push-Auto] No user logged in, skipping');
      return;
    }

    // Respect an explicit per-device opt-out — don't silently re-subscribe
    // just because this device becomes the "latest" one for its interface.
    try {
      if (localStorage.getItem(PUSH_MANUALLY_DISABLED_KEY) === '1') {
        console.log('📬 [Push-Auto] Notifications manually disabled on this device, skipping');
        return;
      }
    } catch {
      // ignore storage access errors, proceed as if not disabled
    }

    // Request permission silently (browser may remember previous grant)
    const permission = Notification.permission === 'granted'
      ? 'granted'
      : await Notification.requestPermission();

    if (permission !== 'granted') {
      console.log('📬 [Push-Auto] Permission not granted:', permission);
      return;
    }

    // Get or create service worker registration
    let registration = await navigator.serviceWorker.getRegistration();
    if (!registration) {
      registration = await navigator.serviceWorker.register('/sw.js', { scope: '/' });
      await navigator.serviceWorker.ready;
    }

    // Get or create push subscription
    let subscription = await registration.pushManager.getSubscription();

    if (!subscription) {
      const vapidPublicKey = import.meta.env.VITE_VAPID_PUBLIC_KEY;
      if (!vapidPublicKey) {
        console.warn('📬 [Push-Auto] No VAPID key configured');
        return;
      }
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey)
      });
      console.log('📬 [Push-Auto] New push subscription created');
    }

    // Save / upsert subscription to database for this user + device
    await savePushSubscription(subscription);
    console.log('📬 [Push-Auto] ✅ Push auto-subscribed for user:', user.id);
  } catch (err) {
    console.warn('📬 [Push-Auto] Auto-subscribe failed (non-fatal):', err);
  }
}

/**
 * Unsubscribe from push on this device (called on logout).
 * Does NOT throw.
 */
export async function autoUnsubscribePush(): Promise<void> {
  try {
    if (!isPushSupported()) return;
    if (!import.meta.env.PROD) return;

    const registration = await navigator.serviceWorker.getRegistration();
    if (!registration) return;

    const subscription = await registration.pushManager.getSubscription();
    if (subscription) {
      await subscription.unsubscribe();
      await removePushSubscription(subscription.endpoint);
      console.log('📬 [Push-Auto] ✅ Push unsubscribed on logout');
    }
  } catch (err) {
    console.warn('📬 [Push-Auto] Unsubscribe failed (non-fatal):', err);
  }
}
