import { supabase } from './supabase';

// Types for notification management
interface CreateNotificationRequest {
	title: string;
	message: string;
	type: 'info' | 'success' | 'warning' | 'error' | 'announcement';
	priority: 'low' | 'medium' | 'high' | 'urgent';
	target_type: 'all_users' | 'all_admins' | 'all_employees' | 'all_managers' | 'specific_users' | 'specific_roles' | 'specific_branches' | 'specific_positions';
	target_branches?: number[];
	target_users?: string[];
	target_roles?: string[];
	target_positions?: string[];
	scheduled_at?: string; // ISO string
	expires_at?: string; // ISO string
}

interface UpdateNotificationRequest {
	title?: string;
	message?: string;
	priority?: 'low' | 'medium' | 'high' | 'urgent';
	status?: 'draft' | 'sent' | 'scheduled' | 'expired' | 'cancelled';
	expires_at?: string;
}

interface NotificationItem {
	id: string;
	title: string;
	message: string;
	type: 'info' | 'success' | 'warning' | 'error' | 'announcement';
	priority: 'low' | 'medium' | 'high' | 'urgent';
	status: 'draft' | 'sent' | 'scheduled' | 'expired' | 'cancelled';
	created_by: string;
	created_by_name: string;
	created_by_role: string;
	target_type: string;
	has_attachments: boolean;
	read_count: number;
	total_recipients: number;
	created_at: string;
	updated_at: string;
	expires_at?: string;
}

interface UserNotificationItem {
	recipient_id: string;
	user_id: string;
	is_read: boolean;
	read_at?: string;
	is_dismissed: boolean;
	dismissed_at?: string;
	notification_id: string;
	title: string;
	message: string;
	type: 'info' | 'success' | 'warning' | 'error' | 'announcement';
	priority: 'low' | 'medium' | 'high' | 'urgent';
	created_by_name: string;
	created_by_role: string;
	has_attachments: boolean;
	created_at: string;
	expires_at?: string;
	is_active: boolean;
}

interface NotificationAttachment {
	id: string;
	notification_id: string;
	file_name: string;
	file_path: string;
	file_size: number;
	file_type: string;
	mime_type: string;
	is_image: boolean;
	uploaded_by: string;
	created_at: string;
}

export class NotificationManagementService {
	private baseUrl: string;

	constructor() {
		// Use environment variable for backend URL or fallback to localhost
		this.baseUrl = (import.meta as any).env?.VITE_API_BASE_URL || 'http://localhost:8080/api/v1';
	}

	/**
	 * Get all notifications (admin view)
	 */
	async getAllNotifications(userId?: string): Promise<NotificationItem[]> {
		try {
			const headers: Record<string, string> = {
				'Content-Type': 'application/json',
			};
			
			// Add X-User-ID header if userId is provided
			if (userId) {
				headers['X-User-ID'] = userId;
			}

			const response = await fetch(`${this.baseUrl}/admin/notifications`, {
				method: 'GET',
				headers,
			});

			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			if (!result.success) {
				throw new Error(result.error || 'Failed to fetch notifications');
			}

			return result.data || [];
		} catch (error) {
			console.error('Error fetching notifications:', error);
			throw new Error('Failed to fetch notifications');
		}
	}

	/**
	 * Get notifications for a specific user
	 */
	async getUserNotifications(userId: string): Promise<UserNotificationItem[]> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/user/${userId}`, {
				method: 'GET',
				headers: {
					'Content-Type': 'application/json',
				},
			});

			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			if (!result.success) {
				throw new Error(result.error || 'Failed to fetch user notifications');
			}

			return result.data || [];
		} catch (error) {
			console.error('Error fetching user notifications:', error);
			throw new Error('Failed to fetch user notifications');
		}
	}

	/**
	 * Create a new notification
	 */
	async createNotification(notificationData: CreateNotificationRequest): Promise<{ success: boolean; notification?: NotificationItem }> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify(notificationData),
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			if (!result.success) {
				throw new Error(result.error || 'Failed to create notification');
			}

			return {
				success: true,
				notification: result.data
			};
		} catch (error) {
			console.error('Error creating notification:', error);
			return {
				success: false
			};
		}
	}

	/**
	 * Get notification by ID
	 */
	async getNotificationById(id: string): Promise<NotificationItem | null> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/${id}`, {
				method: 'GET',
				headers: {
					'Content-Type': 'application/json',
				},
			});

			if (!response.ok) {
				if (response.status === 404) {
					return null;
				}
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			if (!result.success) {
				throw new Error(result.error || 'Failed to fetch notification');
			}

			return result.data;
		} catch (error) {
			console.error('Error fetching notification:', error);
			throw new Error('Failed to fetch notification');
		}
	}

	/**
	 * Update notification
	 */
	async updateNotification(id: string, updateData: UpdateNotificationRequest): Promise<{ success: boolean }> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/${id}`, {
				method: 'PUT',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify(updateData),
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			return {
				success: result.success
			};
		} catch (error) {
			console.error('Error updating notification:', error);
			return {
				success: false
			};
		}
	}

	/**
	 * Delete notification
	 */
	async deleteNotification(id: string): Promise<{ success: boolean }> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/${id}`, {
				method: 'DELETE',
				headers: {
					'Content-Type': 'application/json',
				},
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			return {
				success: result.success
			};
		} catch (error) {
			console.error('Error deleting notification:', error);
			return {
				success: false
			};
		}
	}

	/**
	 * Mark notification as read for user
	 */
	async markAsRead(notificationId: string, userId: string): Promise<{ success: boolean }> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/${notificationId}/read`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'X-User-ID': userId, // Send user ID in header instead of body
				},
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			return {
				success: result.success
			};
		} catch (error) {
			console.error('Error marking notification as read:', error);
			return {
				success: false
			};
		}
	}

	/**
	 * Mark notification as unread for user
	 */
	async markAsUnread(notificationId: string, userId: string): Promise<{ success: boolean }> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/${notificationId}/unread`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
				},
				body: JSON.stringify({ user_id: userId }),
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			return {
				success: result.success
			};
		} catch (error) {
			console.error('Error marking notification as unread:', error);
			return {
				success: false
			};
		}
	}

	/**
	 * Mark all notifications as read for user
	 */
	async markAllAsRead(userId: string): Promise<{ success: boolean }> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/mark-all-read`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'X-User-ID': userId, // Send user ID in header instead of body
				},
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			return {
				success: result.success
			};
		} catch (error) {
			console.error('Error marking all notifications as read:', error);
			return {
				success: false
			};
		}
	}

	/**
	 * Upload attachment to notification
	 */
	async uploadAttachment(notificationId: string, file: File): Promise<{ success: boolean; attachment?: NotificationAttachment }> {
		try {
			const formData = new FormData();
			formData.append('file', file);

			const response = await fetch(`${this.baseUrl}/admin/notifications/${notificationId}/attachments`, {
				method: 'POST',
				body: formData,
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			return {
				success: result.success,
				attachment: result.data
			};
		} catch (error) {
			console.error('Error uploading attachment:', error);
			return {
				success: false
			};
		}
	}

	/**
	 * Get available branches for targeting (helper method)
	 */
	async getBranches(): Promise<Array<{ id: string; name: string }>> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/branches`, {
				method: 'GET',
				headers: {
					'Content-Type': 'application/json',
				},
			});

			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			const branches = await response.json();
			
			// Transform to expected format
			return branches.map((branch: any) => ({
				id: branch.id || branch.ID,
				name: branch.name_en || branch.NameEn || branch.name
			}));
		} catch (error) {
			console.error('Error fetching branches:', error);
			// Return default branches as fallback
			return [
				{ id: '1', name: 'Main Branch' },
				{ id: '2', name: 'Downtown Branch' },
				{ id: '3', name: 'Westside Branch' }
			];
		}
	}

	/**
	 * Get notification statistics
	 */
	async getNotificationStats(): Promise<{
		total: number;
		unread: number;
		sent_today: number;
		active: number;
	}> {
		try {
			// This would normally be a separate endpoint, but for now we'll calculate from getAllNotifications
			const notifications = await this.getAllNotifications();
			
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			
			return {
				total: notifications.length,
				unread: notifications.filter(n => n.read_count < n.total_recipients).length,
				sent_today: notifications.filter(n => {
					const createdAt = new Date(n.created_at);
					return createdAt >= today;
				}).length,
				active: notifications.filter(n => n.status === 'sent').length
			};
		} catch (error) {
			console.error('Error fetching notification stats:', error);
			return {
				total: 0,
				unread: 0,
				sent_today: 0,
				active: 0
			};
		}
	}

	/**
	 * Get admin read status data - all notifications with read states per user (Master Admin only)
	 */
	async getAdminReadStatus(): Promise<{
		readStates: Array<{
			notification_id: string;
			notification_title: string;
			notification_type: string;
			user_id: string;
			read_at: string;
		}>;
		notifications: Array<{
			id: string;
			title: string;
			type: string;
			priority: string;
			created_at: string;
		}>;
		users: Array<{
			id: string;
			name?: string;
		}>;
	}> {
		try {
			const response = await fetch(`${this.baseUrl}/admin/notifications/read-status`, {
				method: 'GET',
				headers: {
					'Content-Type': 'application/json',
					'X-User-Role': 'Master Admin', // Required for access
				},
			});

			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			const result = await response.json();
			
			if (!result.success) {
				throw new Error(result.error || 'Failed to fetch admin read status');
			}

			return result.data || {
				readStates: [],
				notifications: [],
				users: []
			};
		} catch (error) {
			console.error('Error fetching admin read status:', error);
			throw new Error('Failed to fetch admin read status data');
		}
	}
}

// Export singleton instance
export const notificationManagement = new NotificationManagementService();