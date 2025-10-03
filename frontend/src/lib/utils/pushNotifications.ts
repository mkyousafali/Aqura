import { supabase } from './supabase';
import { browser } from '$app/environment';
import { currentUser as persistentCurrentUser } from './persistentAuth';
import { get } from 'svelte/store';

// Push notification configuration
const VAPID_PUBLIC_KEY = import.meta.env.VITE_VAPID_PUBLIC_KEY || 'your-vapid-public-key'; // Will need to be set
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = import.meta.env.VITE_SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Singleton service role client to avoid multiple instances
let serviceRoleClient: any = null;

interface DeviceRegistration {
	user_id: string;
	device_id: string;
	endpoint: string;
	p256dh: string;
	auth: string;
	device_type: 'mobile' | 'desktop';
	browser_name: string;
	user_agent: string;
	is_active: boolean;
	last_seen: string;
}

interface NotificationPayload {
	title: string;
	body: string;
	icon?: string;
	badge?: string;
	image?: string;
	data?: any;
	actions?: Array<{
		action: string;
		title: string;
		icon?: string;
	}>;
}

export class PushNotificationService {
	private swRegistration: ServiceWorkerRegistration | null = null;
	private subscription: PushSubscription | null = null;

	/**
	 * Initialize push notification service
	 */
	async initialize(): Promise<boolean> {
		if (!browser || !('serviceWorker' in navigator) || !('PushManager' in window)) {
			console.warn('Push notifications not supported in this browser');
			return false;
		}

		try {
			// Register service worker
			this.swRegistration = await navigator.serviceWorker.register('/sw.js', {
				scope: '/'
			});

			console.log('Service Worker registered successfully');

			// Wait for service worker to be ready
			await navigator.serviceWorker.ready;

			// Request notification permission
			const permission = await this.requestPermission();
			if (permission !== 'granted') {
				console.warn('Notification permission not granted');
				return false;
			}

			// Subscribe to push notifications
			await this.subscribeToPush();

			return true;
		} catch (error) {
			console.error('Failed to initialize push notifications:', error);
			return false;
		}
	}

	/**
	 * Request notification permission
	 */
	async requestPermission(): Promise<NotificationPermission> {
		if (!browser || !('Notification' in window)) {
			return 'denied';
		}

		let permission = Notification.permission;

		if (permission === 'default') {
			permission = await Notification.requestPermission();
		}

		return permission;
	}

	/**
	 * Subscribe to push notifications
	 */
	async subscribeToPush(): Promise<PushSubscription | null> {
		if (!this.swRegistration) {
			console.error('Service worker not registered');
			return null;
		}

		try {
			// Validate VAPID key before attempting subscription
			if (!VAPID_PUBLIC_KEY || VAPID_PUBLIC_KEY === 'your-vapid-public-key') {
				console.warn('⚠️ VAPID public key not configured. Push notifications disabled.');
				return null;
			}

			// Check for existing subscription
			this.subscription = await this.swRegistration.pushManager.getSubscription();

			if (!this.subscription) {
				// Create new subscription
				this.subscription = await this.swRegistration.pushManager.subscribe({
					userVisibleOnly: true,
					applicationServerKey: this.urlBase64ToUint8Array(VAPID_PUBLIC_KEY) as BufferSource
				});
			}

			// Register device with backend
			await this.registerDevice();

			return this.subscription;
		} catch (error) {
			console.error('Failed to subscribe to push notifications:', error);
			return null;
		}
	}

	/**
	 * Register device with backend
	 */
	async registerDevice(): Promise<void> {
		if (!this.subscription) {
			console.error('No push subscription available');
			return;
		}

		// Get current user from persistent auth
		const user = get(persistentCurrentUser);
		if (!user) {
			console.error('No user logged in');
			return;
		}

		const deviceId = this.generateDeviceId();

		// Use the actual user ID since it should already be a valid UUID in the database
		const userUUID = user.id;

		const deviceRegistration: Partial<DeviceRegistration> = {
			user_id: userUUID,
			device_id: deviceId,
			endpoint: this.subscription.endpoint,
			p256dh: this.subscription.getKey('p256dh') ? btoa(String.fromCharCode(...new Uint8Array(this.subscription.getKey('p256dh')!))) : '',
			auth: this.subscription.getKey('auth') ? btoa(String.fromCharCode(...new Uint8Array(this.subscription.getKey('auth')!))) : '',
			device_type: this.getDeviceType(),
			browser_name: this.getBrowserName(),
			user_agent: navigator.userAgent,
			is_active: true,
			last_seen: new Date().toISOString()
		};

		console.log('📱 Registering device:', {
			originalUserId: user.id,
			mappedUUID: userUUID,
			deviceId: deviceId,
			deviceType: this.getDeviceType()
		});

		try {
			// Use singleton service role client to avoid multiple instances
			if (!serviceRoleClient) {
				const { createClient } = await import('@supabase/supabase-js');
				serviceRoleClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
			}

			// Upsert device registration using service role
			const { error } = await serviceRoleClient
				.from('push_subscriptions')
				.upsert(deviceRegistration);

			if (error) {
				throw error;
			}

			// Store device ID locally
			localStorage.setItem('aqura-device-id', deviceId);

			console.log('Device registered for push notifications');
		} catch (error) {
			console.error('Failed to register device:', error);
		}
	}

	/**
	 * Unregister device (on logout)
	 */
	async unregisterDevice(): Promise<void> {
		const deviceId = localStorage.getItem('aqura-device-id');
		if (!deviceId) return;

		try {
			// Create service role client for this operation
			const { createClient } = await import('@supabase/supabase-js');
			const serviceSupabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

			// Mark device as inactive
			const { error } = await serviceSupabase
				.from('push_subscriptions')
				.update({ is_active: false })
				.eq('device_id', deviceId);

			if (error) {
				throw error;
			}

			// Unsubscribe from push
			if (this.subscription) {
				await this.subscription.unsubscribe();
				this.subscription = null;
			}

			// Remove local storage
			localStorage.removeItem('aqura-device-id');

			console.log('Device unregistered from push notifications');
		} catch (error) {
			console.error('Failed to unregister device:', error);
		}
	}

	/**
	 * Send a test notification
	 */
	async sendTestNotification(): Promise<void> {
		if (!browser || Notification.permission !== 'granted') {
			console.warn('Cannot send notification - permission not granted');
			return;
		}

		const notification = new Notification('Aqura Test Notification', {
			body: 'Push notifications are working!',
			icon: '/favicon.png',
			badge: '/badge-icon.png',
			tag: 'test-notification'
		});

		// Auto-close after 5 seconds
		setTimeout(() => {
			notification.close();
		}, 5000);
	}

	/**
	 * Show notification when app is open
	 */
	async showNotification(payload: NotificationPayload): Promise<void> {
		if (!browser || Notification.permission !== 'granted') {
			return;
		}

		const notification = new Notification(payload.title, {
			body: payload.body,
			icon: payload.icon || '/favicon.png',
			badge: payload.badge || '/badge-icon.png',
			data: payload.data,
			tag: payload.data?.notification_id || 'aqura-notification',
			requireInteraction: true
		});

		// Handle notification click
		notification.onclick = (event) => {
			event.preventDefault();
			window.focus();
			
			// Navigate to notification if needed
			if (payload.data?.url) {
				window.location.href = payload.data.url;
			}
			
			notification.close();
		};
	}

	/**
	 * Update device last seen
	 */
	async updateLastSeen(): Promise<void> {
		const deviceId = localStorage.getItem('aqura-device-id');
		if (!deviceId) return;

		try {
			// Use singleton service role client to avoid multiple instances
			if (!serviceRoleClient) {
				const { createClient } = await import('@supabase/supabase-js');
				serviceRoleClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
			}

			await serviceRoleClient
				.from('push_subscriptions')
				.update({ 
					last_seen: new Date().toISOString(),
					is_active: true 
				})
				.eq('device_id', deviceId);
		} catch (error) {
			console.error('Failed to update last seen:', error);
		}
	}

	/**
	 * Helper methods
	 */
	private generateDeviceId(): string {
		return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Generate a UUID v4 from a string (for consistent user_id mapping)
	private generateUUIDFromString(str: string): string {
		// Simple UUID v4 generation from string hash
		let hash = 0;
		for (let i = 0; i < str.length; i++) {
			const char = str.charCodeAt(i);
			hash = ((hash << 5) - hash) + char;
			hash = hash & hash; // Convert to 32-bit integer
		}
		
		// Create a proper 32-character hex string from the hash
		const hex = Math.abs(hash).toString(16).padStart(8, '0');
		// Repeat and extend to get 32 chars
		const fullHex = (hex + hex + hex + hex).substring(0, 32);
		
		// Format as proper UUID
		const uuid = `${fullHex.slice(0, 8)}-${fullHex.slice(8, 12)}-4${fullHex.slice(13, 16)}-a${fullHex.slice(17, 20)}-${fullHex.slice(20, 32)}`;
		return uuid;
	}

	private getDeviceType(): 'mobile' | 'desktop' {
		if (!browser) return 'desktop';
		
		const userAgent = navigator.userAgent;
		const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(userAgent);
		return isMobile ? 'mobile' : 'desktop';
	}

	private getBrowserName(): string {
		if (!browser) return 'unknown';
		
		const userAgent = navigator.userAgent;
		
		if (userAgent.includes('Chrome')) return 'Chrome';
		if (userAgent.includes('Firefox')) return 'Firefox';
		if (userAgent.includes('Safari')) return 'Safari';
		if (userAgent.includes('Edge')) return 'Edge';
		
		return 'Unknown';
	}

	private urlBase64ToUint8Array(base64String: string): Uint8Array {
		try {
			const padding = '='.repeat((4 - base64String.length % 4) % 4);
			const base64 = (base64String + padding)
				.replace(/-/g, '+')
				.replace(/_/g, '/');

			const rawData = window.atob(base64);
			const outputArray = new Uint8Array(rawData.length);

			for (let i = 0; i < rawData.length; ++i) {
				outputArray[i] = rawData.charCodeAt(i);
			}
			return outputArray;
		} catch (error) {
			console.error('Failed to decode VAPID key:', error);
			throw new Error('Invalid VAPID public key format');
		}
	}
}

// Singleton instance
export const pushNotificationService = new PushNotificationService();