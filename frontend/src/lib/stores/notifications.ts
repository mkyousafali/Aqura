import { writable } from 'svelte/store';
import { supabase } from '$lib/utils/supabase';
import { currentUser } from '$lib/utils/persistentAuth';
import { get } from 'svelte/store';

// Import notification sound manager for playing sounds when new notifications arrive
let notificationSoundManager: any = null;
if (typeof window !== 'undefined') {
	import('$lib/utils/inAppNotificationSounds').then(module => {
		notificationSoundManager = module.notificationSoundManager;
	});
}

export interface NotificationCounts {
	unread: number;
	total: number;
	loading: boolean;
}

export interface ToastNotification {
	id: string;
	type: 'success' | 'error' | 'warning' | 'info';
	message: string;
	duration?: number;
}

// Create notification counts store
export const notificationCounts = writable<NotificationCounts>({
	unread: 0,
	total: 0,
	loading: true
});

// Track previous counts to detect new notifications
let previousUnreadCount = 0;
let isInitialLoad = true;

// Create toast notifications store
export const toastNotifications = writable<ToastNotification[]>([]);

// Toast notification functions
export const notifications = {
	add: (notification: Omit<ToastNotification, 'id'>) => {
		const id = Date.now().toString() + Math.random().toString(36).substr(2, 9);
		const toast: ToastNotification = {
			id,
			...notification,
			duration: notification.duration || 5000
		};
		
		toastNotifications.update(notifications => [...notifications, toast]);
		
		// Auto remove after duration
		if (toast.duration > 0) {
			setTimeout(() => {
				notifications.remove(id);
			}, toast.duration);
		}
	},
	
	remove: (id: string) => {
		toastNotifications.update(notifications => 
			notifications.filter(notification => notification.id !== id)
		);
	},
	
	clear: () => {
		toastNotifications.set([]);
	}
};

// Function to fetch notification counts from Supabase
export async function fetchNotificationCounts(userId?: string) {
	// Get userId from parameter or current user
	const user = get(currentUser);
	const targetUserId = userId || user?.id;
	
	if (!targetUserId) {
		console.warn('No user ID available for fetching notification counts');
		return;
	}
	
	// Set loading state
	notificationCounts.update(counts => ({ ...counts, loading: true }));
	
	try {
		// Get notifications for user
		const { data: notifications, error } = await supabase
			.from('notifications')
			.select(`
				*,
				notification_read_states(
					read_at,
					user_id
				)
			`)
			.eq('status', 'published');

		if (error) {
			throw error;
		}

		const totalCount = notifications?.length || 0;
		const unreadCount = notifications?.filter((notification: any) => {
			// Check if current user has read this notification
			const userReadState = notification.notification_read_states?.find(
				(readState: any) => readState.user_id === targetUserId
			);
			return !userReadState?.read_at; // Unread if no read state or no read_at timestamp
		}).length || 0;
		
		// Update store
		notificationCounts.set({
			unread: unreadCount,
			total: totalCount,
			loading: false
		});

		// Check for new notifications and play sound (only after initial load)
		if (!isInitialLoad && unreadCount > previousUnreadCount) {
			const newNotificationCount = unreadCount - previousUnreadCount;
			console.log(`🔔 [NotificationStore] Detected ${newNotificationCount} new notifications (${previousUnreadCount} → ${unreadCount})`);
			
			// Play sound for new notifications
			if (notificationSoundManager && newNotificationCount > 0) {
				console.log(`🔊 [NotificationStore] Playing sound for ${newNotificationCount} new notifications`);
				
				// Play sound for each new notification (up to 3 to avoid spam)
				const soundCount = Math.min(newNotificationCount, 3);
				for (let i = 0; i < soundCount; i++) {
					try {
						// Create a notification object for the sound system
						const soundNotification = {
							id: `store-notification-${Date.now()}-${i}`,
							title: `New Notification ${i + 1}`,
							message: `You have ${newNotificationCount} new notification${newNotificationCount > 1 ? 's' : ''}`,
							type: 'info' as const,
							priority: 'medium' as const,
							timestamp: new Date(),
							read: false,
							soundEnabled: true
						};
						
						// Small delay between sounds if playing multiple
						if (i > 0) {
							await new Promise(resolve => setTimeout(resolve, 200));
						}
						
						await notificationSoundManager.playNotificationSound(soundNotification);
						console.log(`✅ [NotificationStore] Sound ${i + 1}/${soundCount} played successfully`);
					} catch (error) {
						console.error(`❌ [NotificationStore] Failed to play sound ${i + 1}:`, error);
					}
				}
			} else if (!notificationSoundManager) {
				console.warn(`⚠️ [NotificationStore] Sound manager not available for ${newNotificationCount} new notifications`);
			}
		} else if (isInitialLoad) {
			console.log(`🔍 [NotificationStore] Initial load - ${unreadCount} unread notifications (no sound)`);
			isInitialLoad = false;
		} else {
			console.log(`🔍 [NotificationStore] No new notifications detected (${previousUnreadCount} → ${unreadCount})`);
		}
		
		// Update previous count for next comparison
		previousUnreadCount = unreadCount;
	} catch (error) {
		console.error('Error fetching notification counts:', error);
		// Keep previous counts, just update loading state
		notificationCounts.update(counts => ({ ...counts, loading: false }));
	}
}

// Function to refresh counts (can be called from components)
export function refreshNotificationCounts(userId?: string) {
	fetchNotificationCounts(userId);
}

// Real-time notification listener for immediate sound playing
export function startNotificationListener() {
	const user = get(currentUser);
	if (!user?.id) {
		console.warn('🔔 [NotificationStore] Cannot start listener - no user ID');
		return;
	}
	
	console.log('🔔 [NotificationStore] Starting real-time notification listener for user:', user.id);
	
	// Subscribe to notification_recipients table for user-specific notifications
	const subscription = supabase
		.channel('user-specific-notifications')
		.on(
			'postgres_changes',
			{
				event: 'INSERT',
				schema: 'public',
				table: 'notification_recipients',
				filter: `user_id=eq.${user.id}`
			},
			async (payload) => {
				console.log('🔔 [NotificationStore] User-specific notification received:', payload.new);
				
				// Get the full notification details
				const { data: notification, error } = await supabase
					.from('notifications')
					.select('*')
					.eq('id', payload.new.notification_id)
					.single();
				
				if (error) {
					console.error('🔔 [NotificationStore] Failed to fetch notification details:', error);
					return;
				}
				
				if (notification) {
					console.log('🔊 [NotificationStore] Playing sound for user-specific notification:', notification.title);
					
					// Play sound immediately
					if (notificationSoundManager) {
						try {
							await notificationSoundManager.playNotificationSound({
								id: notification.id,
								title: notification.title,
								message: notification.message,
								type: notification.type || 'info',
								priority: notification.priority || 'medium',
								timestamp: new Date(notification.created_at || new Date()),
								read: false,
								soundEnabled: true
							});
							console.log('✅ [NotificationStore] Real-time notification sound played');
						} catch (error) {
							console.error('❌ [NotificationStore] Failed to play real-time notification sound:', error);
						}
					}
					
					// Refresh counts after a short delay
					setTimeout(() => refreshNotificationCounts(), 1000);
				}
			}
		)
		.subscribe();
	
	return subscription;
}