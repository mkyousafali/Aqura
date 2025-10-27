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
		// Get notifications for user from notification_recipients table
		const { data: recipients, error } = await supabase
			.from('notification_recipients')
			.select(`
				notification_id,
				notifications!inner(
					id,
					title,
					message,
					type,
					priority,
					status,
					created_at
				)
			`)
			.eq('user_id', targetUserId)
			.eq('notifications.status', 'published');

		if (error) {
			throw error;
		}

		// Get read states for these notifications
		const notificationIds = recipients?.map(r => r.notification_id) || [];
		const { data: readStates } = await supabase
			.from('notification_read_states')
			.select('notification_id, read_at')
			.eq('user_id', targetUserId)
			.in('notification_id', notificationIds);

		// Create a set of read notification IDs
		const readNotificationIds = new Set(
			readStates?.filter(rs => rs.read_at).map(rs => rs.notification_id) || []
		);

		const totalCount = recipients?.length || 0;
		const unreadCount = recipients?.filter(r => !readNotificationIds.has(r.notification_id)).length || 0;
		
		// Update store
		notificationCounts.set({
			unread: unreadCount,
			total: totalCount,
			loading: false
		});

		// Update PWA badge with unread notification count
		if (typeof navigator !== 'undefined' && 'setAppBadge' in navigator) {
			try {
				if (unreadCount > 0) {
					await (navigator as any).setAppBadge(unreadCount);
					console.log(`🔔 PWA badge updated: ${unreadCount} unread notifications`);
				} else {
					await (navigator as any).clearAppBadge();
					console.log('🔔 PWA badge cleared - no unread notifications');
				}
			} catch (error) {
				console.warn('Failed to update notification badge:', error);
			}
		}

		// Check for new notifications and play sound (only after initial load)
		if (!isInitialLoad && unreadCount > previousUnreadCount) {
			const newNotificationCount = unreadCount - previousUnreadCount;
			
			
			// Play sound for new notifications
			if (notificationSoundManager && newNotificationCount > 0) {
				
				
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
						
					} catch (error) {
						console.error(`❌ [NotificationStore] Failed to play sound ${i + 1}:`, error);
					}
				}
			} else if (!notificationSoundManager) {
				console.warn(`⚠️ [NotificationStore] Sound manager not available for ${newNotificationCount} new notifications`);
			}
		} else if (isInitialLoad) {
			
			isInitialLoad = false;
		} else {
			
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
export function refreshNotificationCounts(userId?: string, silent = true) {
	if (silent) {
		// Silent refresh - just call fetchNotificationCounts without any special handling
		fetchNotificationCounts(userId);
	} else {
		// Non-silent refresh (explicit user action)
		fetchNotificationCounts(userId);
	}
}

// Real-time notification listener for immediate sound playing
export function startNotificationListener() {
	const user = get(currentUser);
	if (!user?.id) {
		console.warn('🔔 [NotificationStore] Cannot start listener - no user ID');
		return;
	}
	
	
	
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
