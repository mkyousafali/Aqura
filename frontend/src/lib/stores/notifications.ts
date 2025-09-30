import { writable } from 'svelte/store';
import { supabase } from '$lib/utils/supabase';

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
export async function fetchNotificationCounts(userId: string = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b') {
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
				(readState: any) => readState.user_id === userId
			);
			return !userReadState?.read_at; // Unread if no read state or no read_at timestamp
		}).length || 0;
		
		// Update store
		notificationCounts.set({
			unread: unreadCount,
			total: totalCount,
			loading: false
		});
	} catch (error) {
		console.error('Error fetching notification counts:', error);
		// Keep previous counts, just update loading state
		notificationCounts.update(counts => ({ ...counts, loading: false }));
	}
}

// Function to refresh counts (can be called from components)
export function refreshNotificationCounts() {
	fetchNotificationCounts();
}