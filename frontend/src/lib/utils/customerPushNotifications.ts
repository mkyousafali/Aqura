/**
 * Customer Push Notifications Utility
 * Handles web push notification subscription for customer interface
 * Uses customer_id instead of user_id in push_subscriptions table
 */

import { supabase } from './supabase';

// VAPID public key - same as staff push notifications
const VAPID_PUBLIC_KEY = 'BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8';

// Convert VAPID key from base64 to Uint8Array
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

/**
 * Get customer ID from localStorage session
 */
function getCustomerId(): string | null {
  try {
    const customerSessionRaw = localStorage.getItem('customer_session');
    if (customerSessionRaw) {
      const customerSession = JSON.parse(customerSessionRaw);
      if (customerSession?.customer_id && customerSession?.registration_status === 'approved') {
        return customerSession.customer_id;
      }
    }
    const raw = localStorage.getItem('aqura-device-session');
    if (!raw) return null;
    const session = JSON.parse(raw);
    const currentId = session?.currentUserId;
    const user = Array.isArray(session?.users)
      ? session.users.find((u: any) => u.id === currentId && u.isActive)
      : null;
    return user?.customerId || null;
  } catch (e) {
    return null;
  }
}

/**
 * Check if push notifications are supported
 */
export function isCustomerPushSupported(): boolean {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
}

/**
 * Check if customer already has an active push subscription
 */
export async function hasCustomerPushSubscription(): Promise<boolean> {
  try {
    if (!isCustomerPushSupported()) return false;
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    return subscription !== null;
  } catch {
    return false;
  }
}

/**
 * Subscribe customer to push notifications
 * Auto-registers service worker if needed, creates push subscription,
 * and saves to push_subscriptions table with customer_id
 */
export async function subscribeCustomerToPush(): Promise<boolean> {
  try {
    console.log('📬 [CustomerPush] Starting subscription...');

    if (!isCustomerPushSupported()) {
      console.log('📬 [CustomerPush] Push not supported in this browser');
      return false;
    }

    const customerId = getCustomerId();
    if (!customerId) {
      console.log('📬 [CustomerPush] No customer ID found');
      return false;
    }

    // Request notification permission
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      console.log('📬 [CustomerPush] Permission denied:', permission);
      return false;
    }
    console.log('📬 [CustomerPush] Permission granted');

    // Get service worker registration
    let registration = await navigator.serviceWorker.getRegistration();
    if (!registration) {
      console.log('📬 [CustomerPush] Registering service worker...');
      registration = await navigator.serviceWorker.register('/sw.js', { scope: '/' });
    }
    registration = await navigator.serviceWorker.ready;
    console.log('📬 [CustomerPush] Service worker ready');

    // Check for existing subscription
    let subscription = await registration.pushManager.getSubscription();

    if (!subscription) {
      // Create new subscription
      const convertedVapidKey = urlBase64ToUint8Array(VAPID_PUBLIC_KEY);
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: convertedVapidKey as BufferSource
      });
      console.log('📬 [CustomerPush] New push subscription created');
    } else {
      console.log('📬 [CustomerPush] Existing push subscription found');
    }

    // Save to database with customer_id
    const subscriptionData = {
      customer_id: customerId,
      subscription: subscription.toJSON(),
      endpoint: subscription.endpoint,
      user_agent: navigator.userAgent,
      is_active: true
    };

    const { error } = await supabase
      .from('push_subscriptions')
      .upsert(subscriptionData, { onConflict: 'endpoint' });

    if (error) {
      console.error('📬 [CustomerPush] DB error saving subscription:', error);
      return false;
    }

    console.log('📬 [CustomerPush] ✅ Subscription saved for customer:', customerId);
    localStorage.setItem('customer_push_subscribed', 'true');
    return true;
  } catch (error) {
    console.error('📬 [CustomerPush] Error subscribing:', error);
    return false;
  }
}

/**
 * Unsubscribe customer from push notifications
 */
export async function unsubscribeCustomerFromPush(): Promise<boolean> {
  try {
    if (!isCustomerPushSupported()) return false;

    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      // Remove from DB
      await supabase
        .from('push_subscriptions')
        .delete()
        .eq('endpoint', subscription.endpoint);

      // Unsubscribe from browser
      await subscription.unsubscribe();
      console.log('📬 [CustomerPush] ✅ Unsubscribed');
    }

    localStorage.removeItem('customer_push_subscribed');
    return true;
  } catch (error) {
    console.error('📬 [CustomerPush] Error unsubscribing:', error);
    return false;
  }
}

/**
 * Check if customer has previously subscribed (localStorage flag)
 */
export function wasCustomerPushSubscribed(): boolean {
  return localStorage.getItem('customer_push_subscribed') === 'true';
}
