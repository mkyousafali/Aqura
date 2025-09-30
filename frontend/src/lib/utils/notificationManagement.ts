import { supabase } from './supabase';

// Types for notification management
interface CreateNotificationRequest {
	title: string;
	message: string;
	type: 'info' | 'warning' | 'error' | 'success' | 'announcement' | 'task_assigned' | 'task_completed' | 'task_overdue' | 'system_alert' | 'marketing' | 'assignment_updated' | 'deadline_reminder' | 'assignment_rejected' | 'assignment_approved';
	priority: 'low' | 'medium' | 'high' | 'urgent';
	target_type: 'all_users' | 'all_admins' | 'specific_users' | 'specific_roles' | 'specific_branches';
	target_branches?: number[];
	target_users?: string[];
	target_roles?: string[];
	scheduled_at?: string; // ISO string
	expires_at?: string; // ISO string
}

interface UpdateNotificationRequest {
	title?: string;
	message?: string;
	priority?: 'low' | 'medium' | 'high' | 'urgent';
	status?: 'draft' | 'published' | 'scheduled' | 'expired' | 'cancelled';
	expires_at?: string;
}

interface NotificationItem {
	id: string;
	title: string;
	message: string;
	type: 'info' | 'warning' | 'error' | 'success' | 'announcement' | 'task_assigned' | 'task_completed' | 'task_overdue' | 'system_alert' | 'marketing' | 'assignment_updated' | 'deadline_reminder' | 'assignment_rejected' | 'assignment_approved';
	priority: 'low' | 'medium' | 'high' | 'urgent';
	status: 'draft' | 'published' | 'scheduled' | 'expired' | 'cancelled';
	target_type: string;
	target_branches?: number[];
	target_users?: string[];
	target_roles?: string[];
	scheduled_at?: string;
	expires_at?: string;
	created_at: string;
	updated_at: string;
	created_by: string;
}

interface UserNotificationItem {
	id: string;
	notification_id: string;
	title: string;
	message: string;
	type: 'info' | 'warning' | 'error' | 'success' | 'announcement' | 'task_assigned' | 'task_completed' | 'task_overdue' | 'system_alert' | 'marketing' | 'assignment_updated' | 'deadline_reminder' | 'assignment_rejected' | 'assignment_approved';
	priority: 'low' | 'medium' | 'high' | 'urgent';
	is_read: boolean;
	read_at?: string;
	created_at: string;
	created_by_name?: string;
	recipient_id?: string;
}

export class NotificationManagementService {
	constructor() {
		// Using Supabase directly, no backend URL needed
	}

	/**
	 * Get all notifications (admin view)
	 */
	async getAllNotifications(userId?: string): Promise<NotificationItem[]> {
		try {
			if (userId) {
				// Include read states for the specific user
				const { data, error } = await supabase
					.from('notifications')
					.select(`
						*,
						notification_read_states!left(
							is_read,
							read_at
						)
					`)
					.eq('notification_read_states.user_id', userId)
					.order('created_at', { ascending: false });

				if (error) {
					throw error;
				}

				// Transform to include read status
				return data?.map(notification => ({
					...notification,
					is_read: notification.notification_read_states?.[0]?.is_read || false,
					read_at: notification.notification_read_states?.[0]?.read_at
				})) || [];
			} else {
				// Fallback: get all notifications without read states
				const { data, error } = await supabase
					.from('notifications')
					.select('*')
					.order('created_at', { ascending: false });

				if (error) {
					throw error;
				}

				return data || [];
			}
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
			const { data, error } = await supabase
				.from('notifications')
				.select(`
					*,
					notification_read_states(
						is_read,
						read_at
					)
				`)
				.eq('notification_read_states.user_id', userId)
				.eq('status', 'published')
				.order('created_at', { ascending: false });

			if (error) {
				throw error;
			}

			// Transform data to match UserNotificationItem interface
			const userNotifications = data?.map(notification => ({
				id: notification.id,
				notification_id: notification.id,
				title: notification.title,
				message: notification.message,
				type: notification.type,
				priority: notification.priority,
				is_read: notification.notification_read_states?.[0]?.is_read || false,
				read_at: notification.notification_read_states?.[0]?.read_at,
				created_at: notification.created_at
			})) || [];

			return userNotifications;
		} catch (error) {
			console.error('Error fetching user notifications:', error);
			throw new Error('Failed to fetch user notifications');
		}
	}

	/**
	 * Create a new notification
	 */
	async createNotification(notification: CreateNotificationRequest, createdBy: string): Promise<NotificationItem> {
		try {
			// Get user info for proper attribution
			const { data: userData, error: userError } = await supabase
				.from('users')
				.select('username, role_type')
				.eq('username', createdBy)
				.single();

			const createdByName = userData?.username || createdBy;
			const createdByRole = userData?.role_type || 'Admin';

			const { data, error } = await supabase
				.from('notifications')
				.insert({
					...notification,
					created_by: createdBy,
					created_by_name: createdByName,
					created_by_role: createdByRole,
					status: 'published', // Publish immediately
					has_attachments: false,
					read_count: 0,
					total_recipients: 0
				})
				.select()
				.single();

			if (error) {
				throw error;
			}

			return data;
		} catch (error) {
			console.error('Error creating notification:', error);
			throw new Error('Failed to create notification');
		}
	}

	/**
	 * Update an existing notification
	 */
	async updateNotification(id: string, updates: UpdateNotificationRequest): Promise<NotificationItem> {
		try {
			const { data, error } = await supabase
				.from('notifications')
				.update(updates)
				.eq('id', id)
				.select()
				.single();

			if (error) {
				throw error;
			}

			return data;
		} catch (error) {
			console.error('Error updating notification:', error);
			throw new Error('Failed to update notification');
		}
	}

	/**
	 * Delete a notification
	 */
	async deleteNotification(id: string): Promise<{success: boolean}> {
		try {
			const { error } = await supabase
				.from('notifications')
				.delete()
				.eq('id', id);

			if (error) {
				throw error;
			}

			return { success: true };
		} catch (error) {
			console.error('Error deleting notification:', error);
			throw new Error('Failed to delete notification');
		}
	}

	/**
	 * Mark notification as read for a user
	 */
	async markAsRead(notificationId: string, userId: string): Promise<{success: boolean}> {
		try {
			const { error } = await supabase
				.from('notification_read_states')
				.upsert({
					notification_id: notificationId,
					user_id: userId,
					is_read: true,
					read_at: new Date().toISOString()
				});

			if (error) {
				throw error;
			}

			return { success: true };
		} catch (error) {
			console.error('Error marking notification as read:', error);
			throw new Error('Failed to mark notification as read');
		}
	}

	/**
	 * Mark notification as unread for a user
	 */
	async markAsUnread(notificationId: string, userId: string): Promise<void> {
		try {
			const { error } = await supabase
				.from('notification_read_states')
				.upsert({
					notification_id: notificationId,
					user_id: userId,
					is_read: false,
					read_at: null
				});

			if (error) {
				throw error;
			}
		} catch (error) {
			console.error('Error marking notification as unread:', error);
			throw new Error('Failed to mark notification as unread');
		}
	}

	/**
	 * Mark all notifications as read for a user
	 */
	async markAllAsRead(userId: string): Promise<{success: boolean}> {
		try {
			// First get all active notifications
			const { data: notifications, error: fetchError } = await supabase
				.from('notifications')
				.select('id')
				.eq('status', 'published');

			if (fetchError) {
				throw fetchError;
			}

			// Create read states for all notifications
			const readStates = notifications?.map(notification => ({
				notification_id: notification.id,
				user_id: userId,
				is_read: true,
				read_at: new Date().toISOString()
			})) || [];

			const { error } = await supabase
				.from('notification_read_states')
				.upsert(readStates);

			if (error) {
				throw error;
			}

			return { success: true };
		} catch (error) {
			console.error('Error marking all notifications as read:', error);
			throw new Error('Failed to mark all notifications as read');
		}
	}

	/**
	 * Get notification attachments (placeholder - would need file storage implementation)
	 */
	async getNotificationAttachments(notificationId: string): Promise<any[]> {
		try {
			const { data, error } = await supabase
				.from('notification_attachments')
				.select('*')
				.eq('notification_id', notificationId);

			if (error) {
				throw error;
			}

			return data || [];
		} catch (error) {
			console.error('Error fetching notification attachments:', error);
			throw new Error('Failed to fetch notification attachments');
		}
	}

	/**
	 * Get branches for targeting
	 */
	async getBranches(): Promise<any[]> {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.eq('is_active', true)
				.order('name_en');

			if (error) {
				throw error;
			}

			return data || [];
		} catch (error) {
			console.error('Error fetching branches:', error);
			throw new Error('Failed to fetch branches');
		}
	}

	/**
	 * Get users for targeting
	 */
	async getUsers(): Promise<any[]> {
		try {
			const { data, error } = await supabase
				.from('users')
				.select('*')
				.order('full_name');

			if (error) {
				throw error;
			}

			return data || [];
		} catch (error) {
			console.error('Error fetching users:', error);
			throw new Error('Failed to fetch users');
		}
	}

	/**
	 * Get notification statistics
	 */
	async getNotificationStatistics(): Promise<any> {
		try {
			// Get total notifications
			const { count: totalNotifications, error: totalError } = await supabase
				.from('notifications')
				.select('*', { count: 'exact', head: true });

			if (totalError) {
				throw totalError;
			}

			// Get published notifications
			const { count: publishedNotifications, error: publishedError } = await supabase
				.from('notifications')
				.select('*', { count: 'exact', head: true })
				.eq('status', 'published');

			if (publishedError) {
				throw publishedError;
			}

			// Get scheduled notifications
			const { count: scheduledNotifications, error: scheduledError } = await supabase
				.from('notifications')
				.select('*', { count: 'exact', head: true })
				.eq('status', 'scheduled');

			if (scheduledError) {
				throw scheduledError;
			}

			return {
				total: totalNotifications || 0,
				published: publishedNotifications || 0,
				scheduled: scheduledNotifications || 0,
				draft: (totalNotifications || 0) - (publishedNotifications || 0) - (scheduledNotifications || 0)
			};
		} catch (error) {
			console.error('Error fetching notification statistics:', error);
			throw new Error('Failed to fetch notification statistics');
		}
	}

	/**
	 * Get read status for notifications
	 */
	async getReadStatus(userId: string): Promise<any[]> {
		try {
			const { data, error } = await supabase
				.from('notification_read_states')
				.select('*')
				.eq('user_id', userId);

			if (error) {
				throw error;
			}

			return data || [];
		} catch (error) {
			console.error('Error fetching read status:', error);
			throw new Error('Failed to fetch read status');
		}
	}

	/**
	 * Create notification for task assignment
	 */
	async createTaskAssignmentNotification(
		taskId: string, 
		taskTitle: string, 
		assignedToUserIds: string[], 
		assignedBy: string, 
		assignedByName: string,
		deadline?: string,
		notes?: string,
		taskData?: any
	): Promise<NotificationItem> {
		try {
			// Create notification data with task metadata
			const notificationData: CreateNotificationRequest = {
				title: `New Task Assigned: ${taskTitle}`,
				message: `You have been assigned a new task: "${taskTitle}"${deadline ? ` with deadline: ${new Date(deadline).toLocaleDateString()}` : ''}${notes ? `\n\nNotes: ${notes}` : ''}`,
				type: 'task_assigned',
				priority: 'medium',
				target_type: 'specific_users',
				target_users: assignedToUserIds
			};

			// Create the notification with task metadata
			const { data, error } = await supabase
				.from('notifications')
				.insert({
					...notificationData,
					created_by: assignedBy,
					created_by_name: assignedByName,
					status: 'published',
					metadata: {
						task_id: taskId,
						task_title: taskTitle,
						assignment_id: taskData?.assignmentId,
						require_task_finished: taskData?.require_task_finished || false,
						require_photo_upload: taskData?.require_photo_upload || false,
						require_erp_reference: taskData?.require_erp_reference || false,
						deadline: deadline,
						notes: notes
					}
				})
				.select()
				.single();

			if (error) {
				throw error;
			}

			console.log('Task assignment notification created:', data);
			return data;
		} catch (error) {
			console.error('Error creating task assignment notification:', error);
			throw new Error('Failed to create task assignment notification');
		}
	}
}

// Export singleton instance
export const notificationService = new NotificationManagementService();

// Export the service instance with the expected name for backward compatibility
export const notificationManagement = notificationService;