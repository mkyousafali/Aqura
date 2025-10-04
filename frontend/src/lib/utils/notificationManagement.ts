import { supabase } from './supabase';
import { pushNotificationService } from './pushNotifications';
import { persistentAuthService, currentUser } from './persistentAuth';
import { pushNotificationProcessor } from './pushNotificationProcessor';

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
						notification_read_states(
							is_read,
							read_at,
							user_id
						)
					`)
					.order('created_at', { ascending: false });

				if (error) {
					throw error;
				}

				// Transform to include read status for the specific user
				return data?.map(notification => {
					// Find read state for this specific user
					const userReadState = notification.notification_read_states?.find(
						(readState: any) => readState.user_id === userId
					);
					
					return {
						...notification,
						is_read: userReadState?.is_read || false,
						read_at: userReadState?.read_at || null
					};
				}) || [];
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
			// Get user UUID instead of username for created_by field
			const { data: userData, error: userError } = await supabase
				.from('users')
				.select('id, username, role_type')
				.eq('username', createdBy)
				.single();

			if (userError || !userData) {
				console.error('❌ [NotificationManagement] Could not find user:', createdBy, userError);
				throw new Error('User not found');
			}

			const currentUserId = userData.id; // Use UUID from database
			const currentUserName = userData.username;
			const currentUserRole = userData.role_type || 'Admin';
			
			// Fix enum values to match database schema
			let validType = notification.type;
			if (!['info', 'warning', 'error', 'success', 'announcement', 'task_assigned', 'task_completed', 'task_overdue', 'system_maintenance', 'policy_update', 'birthday_reminder', 'leave_approved', 'leave_rejected', 'document_uploaded', 'meeting_scheduled'].includes(notification.type)) {
				validType = 'info'; // Default fallback
			}
			
			let validPriority = notification.priority;
			if (!['low', 'medium', 'high', 'urgent', 'critical'].includes(notification.priority)) {
				validPriority = 'medium'; // Default fallback
			}
			
			// Prepare notification data with username for created_by (not UUID)
			const notificationPayload = {
				title: notification.title,
				message: notification.message,
				type: validType,
				priority: validPriority,
				target_type: notification.target_type,
				target_users: notification.target_users || null,
				target_roles: notification.target_roles || null,
				target_branches: notification.target_branches || null,
				created_by: createdBy, // Use username (string) as per schema
				created_by_name: currentUserName,
				created_by_role: currentUserRole,
				status: 'published',
				scheduled_for: notification.scheduled_at ? new Date(notification.scheduled_at).toISOString() : null,
				expires_at: notification.expires_at ? new Date(notification.expires_at).toISOString() : null,
				has_attachments: false,
				read_count: 0,
				total_recipients: notification.target_users?.length || 0
			};

			console.log('📝 [NotificationManagement] Creating notification with username:', notificationPayload);

			const { data, error } = await supabase
				.from('notifications')
				.insert(notificationPayload)
				.select('*')
				.single();

			if (error) {
				console.error('❌ [NotificationManagement] Database error:', error);
				throw error;
			}

			console.log('✅ [NotificationManagement] Notification created successfully:', data);
			
			// Queue the notification for push delivery
			try {
				console.log('📨 [NotificationManagement] Queueing notification for push delivery...');
				const { data: queueResult, error: queueError } = await supabase
					.rpc('queue_push_notification', {
						p_notification_id: data.id
					});
				
				if (queueError) {
					console.error('❌ [NotificationManagement] Failed to queue notification:', queueError);
				} else {
					console.log('✅ [NotificationManagement] Notification queued successfully:', queueResult);
				}
			} catch (error) {
				console.error('❌ [NotificationManagement] Queue function failed:', error);
			}
			
			// Automatically trigger push notification processing
			try {
				console.log('🔄 [NotificationManagement] Triggering automatic push notification processing...');
				// Wait a moment for the queueing to complete, then process
				setTimeout(() => {
					pushNotificationProcessor.processOnce().catch(error => {
						console.error('❌ [NotificationManagement] Auto push processing failed:', error);
					});
				}, 1500); // Increased delay to allow queueing to complete
			} catch (error) {
				console.error('❌ [NotificationManagement] Failed to trigger automatic push processing:', error);
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
				}, {
					onConflict: 'notification_id,user_id'
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
				}, {
					onConflict: 'notification_id,user_id'
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

			// Get existing read states for this user
			const { data: existingReadStates, error: existingError } = await supabase
				.from('notification_read_states')
				.select('notification_id')
				.eq('user_id', userId);

			if (existingError) {
				throw existingError;
			}

			// Create a Set of existing notification IDs for quick lookup
			const existingNotificationIds = new Set(
				existingReadStates?.map(state => state.notification_id) || []
			);

			// Create read states only for notifications that don't already have read states
			const newReadStates = notifications
				?.filter(notification => !existingNotificationIds.has(notification.id))
				?.map(notification => ({
					notification_id: notification.id,
					user_id: userId,
					is_read: true,
					read_at: new Date().toISOString()
				})) || [];

			// Insert new read states if any
			if (newReadStates.length > 0) {
				const { error: insertError } = await supabase
					.from('notification_read_states')
					.insert(newReadStates);

				if (insertError) {
					throw insertError;
				}
			}

			// Update existing read states to mark them as read
			if (existingReadStates && existingReadStates.length > 0) {
				const { error: updateError } = await supabase
					.from('notification_read_states')
					.update({ 
						is_read: true, 
						read_at: new Date().toISOString() 
					})
					.eq('user_id', userId)
					.eq('is_read', false);

				if (updateError) {
					throw updateError;
				}
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
				.order('username');

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
	 * Get read status for notifications (admin view)
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
	 * Get admin read status overview for all notifications and users
	 */
	async getAdminReadStatus(): Promise<{readStates: any[], notifications: any[], users: any[]}> {
		try {
			// Get all published notifications
			const { data: notifications, error: notifyError } = await supabase
				.from('notifications')
				.select('*')
				.eq('status', 'published')
				.order('created_at', { ascending: false });

			if (notifyError) {
				throw notifyError;
			}

			// Get all users with employee information
			const { data: users, error: usersError } = await supabase
				.from('users')
				.select(`
					id, 
					username, 
					role_type,
					employee_id,
					hr_employees(name, employee_id)
				`)
				.order('username');

			if (usersError) {
				throw usersError;
			}

			// Get all read states without joins since there's no FK relationship
			const { data: readStates, error: readError } = await supabase
				.from('notification_read_states')
				.select('*')
				.order('created_at', { ascending: false });

			if (readError) {
				throw readError;
			}

			// Manually join the data on the frontend
			const enrichedReadStates = readStates?.map(state => {
				const notification = notifications?.find(n => n.id === state.notification_id);
				const user = users?.find(u => u.username === state.user_id || u.id === state.user_id);
				
				// Determine display name: Employee name > Username
				let displayName = state.user_id; // fallback to user_id
				if (user) {
					const employee = user.hr_employees?.[0]; // Get first employee record
					if (employee?.name) {
						displayName = employee.name;
					} else {
						displayName = user.username;
					}
				}
				
				return {
					...state,
					display_name: displayName,
					notification: notification ? {
						title: notification.title,
						type: notification.type,
						priority: notification.priority,
						created_at: notification.created_at
					} : null,
					user: user ? {
						username: user.username,
						role_type: user.role_type,
						employee_name: user.hr_employees?.[0]?.name || null,
						employee_id: user.hr_employees?.[0]?.employee_id || null
					} : null
				};
			}) || [];

			return {
				readStates: enrichedReadStates,
				notifications: notifications || [],
				users: users || []
			};
		} catch (error) {
			console.error('Error fetching admin read status:', error);
			throw new Error('Failed to fetch admin read status');
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
			// Check if assignedBy is a UUID (if it contains dashes, assume it's a UUID)
			let assignedByUsername = assignedBy;
			let assignedByUserName = assignedByName;
			
			if (assignedBy.includes('-')) {
				// It's a UUID, we need to get the username
				const { data: userData, error: userError } = await supabase
					.from('users')
					.select('username')
					.eq('id', assignedBy)
					.single();

				if (userError || !userData) {
					console.error('❌ [NotificationManagement] Could not find user for UUID:', assignedBy, userError);
					// Fallback to using the provided name
					assignedByUsername = assignedByName || 'Admin';
				} else {
					assignedByUsername = userData.username;
				}
			}

			// Create notification data with task details in message
			const notificationData: CreateNotificationRequest = {
				title: `New Task Assigned: ${taskTitle}`,
				message: `You have been assigned a new task: "${taskTitle}"${deadline ? ` with deadline: ${new Date(deadline).toLocaleDateString()}` : ''}${notes ? `\n\nNotes: ${notes}` : ''}${taskData?.require_photo_upload ? '\n📷 Photo upload required' : ''}${taskData?.require_erp_reference ? '\n📋 ERP reference required' : ''}`,
				type: 'task_assigned',
				priority: 'medium',
				target_type: 'specific_users',
				target_users: assignedToUserIds
			};

			// Create the notification with proper data types matching the schema
			console.log('🔄 [NotificationManagement] Creating notification with data:', {
				title: notificationData.title,
				type: notificationData.type,
				target_type: notificationData.target_type,
				target_users: assignedToUserIds,
				created_by: assignedByUsername,
				task_id: taskId,
				task_assignment_id: taskData?.assignmentId
			});

			const { data, error } = await supabase
				.from('notifications')
				.insert({
					title: notificationData.title,
					message: notificationData.message,
					type: notificationData.type,
					priority: notificationData.priority,
					target_type: notificationData.target_type,
					target_users: assignedToUserIds, // Keep as array - Supabase will handle JSONB conversion
					created_by: assignedByUsername, // Use username, not UUID
					created_by_name: assignedByUserName,
					created_by_role: 'Admin',
					status: 'published',
					total_recipients: assignedToUserIds.length,
					task_id: taskId, // This should work as UUID string
					task_assignment_id: taskData?.assignmentId || null, // This should work as UUID string
					metadata: {
						task_id: taskId, // Add task_id to metadata for easy access in UI
						task_assignment_id: taskData?.assignmentId || null, // Add assignment_id to metadata
						task_title: taskTitle,
						require_task_finished: taskData?.require_task_finished || false,
						require_photo_upload: taskData?.require_photo_upload || false,
						require_erp_reference: taskData?.require_erp_reference || false,
						deadline: deadline,
						notes: notes
					}
				})
				.select('*')
				.single();

			if (error) {
				throw error;
			}

			console.log('Task assignment notification created:', data);
			
			// Create notification_recipients entries for each assigned user
			try {
				console.log('� [NotificationManagement] Creating notification_recipients entries for task assignment...');
				const recipientEntries = assignedToUserIds.map(userId => ({
					notification_id: data.id,
					user_id: userId,
					is_read: false,
					is_dismissed: false
				}));

				const { error: recipientsError } = await supabase
					.from('notification_recipients')
					.insert(recipientEntries);

				if (recipientsError) {
					console.error('❌ [NotificationManagement] Failed to create notification recipients:', recipientsError);
				} else {
					console.log('✅ [NotificationManagement] Created notification recipients for', assignedToUserIds.length, 'users');
				}
			} catch (recipientsError) {
				console.error('❌ [NotificationManagement] Error creating notification recipients:', recipientsError);
			}
			
			// Manually queue push notifications immediately (don't rely on database trigger)
			try {
				console.log('🔄 [NotificationManagement] Manually queuing push notifications for immediate delivery...');
				
				// Call the queue_push_notification function directly
				const { data: queueResult, error: queueError } = await supabase
					.rpc('queue_push_notification', {
						p_notification_id: data.id
					});
				
				if (queueError) {
					console.error('❌ [NotificationManagement] Failed to queue push notifications:', queueError);
				} else {
					console.log('✅ [NotificationManagement] Push notifications queued successfully');
					
					// Immediately trigger push notification processing
					setTimeout(() => {
						pushNotificationProcessor.processOnce().catch(error => {
							console.error('❌ [NotificationManagement] Failed to process push notifications:', error);
						});
					}, 1000); // Reduced delay for faster task assignment notifications
				}
			} catch (queueError) {
				console.error('❌ [NotificationManagement] Error in manual queue process:', queueError);
			}
			
			return data;
		} catch (error) {
			console.error('Error creating task assignment notification:', error);
			throw new Error('Failed to create task assignment notification');
		}
	}

	/**
	 * Send a push notification to specific users or all users
	 */
	async sendPushNotification(
		title: string,
		body: string,
		userIds?: string[],
		data?: any
	): Promise<void> {
		try {
			// Send browser notification if user is online
			await pushNotificationService.showNotification({
				title,
				body,
				data
			});

			// For offline users, the backend should handle push notifications
			// This would typically be done via a server-side push service
			console.log('Push notification sent:', { title, body, userIds, data });
		} catch (error) {
			console.error('Error sending push notification:', error);
		}
	}

	/**
	 * Register current device for push notifications
	 */
	async registerForPushNotifications(): Promise<boolean> {
		try {
			return await pushNotificationService.initialize();
		} catch (error) {
			console.error('Error registering for push notifications:', error);
			return false;
		}
	}

	/**
	 * Unregister device from push notifications
	 */
	async unregisterFromPushNotifications(): Promise<void> {
		try {
			await pushNotificationService.unregisterDevice();
		} catch (error) {
			console.error('Error unregistering from push notifications:', error);
		}
	}

	/**
	 * Check if push notifications are supported and enabled
	 */
	isPushNotificationSupported(): boolean {
		if (typeof window === 'undefined') return false;
		return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
	}

	/**
	 * Get push notification permission status
	 */
	getPushNotificationPermission(): NotificationPermission {
		if (typeof window === 'undefined') return 'denied';
		return Notification.permission;
	}

	/**
	 * Request push notification permission
	 */
	async requestPushNotificationPermission(): Promise<NotificationPermission> {
		try {
			return await pushNotificationService.requestPermission();
		} catch (error) {
			console.error('Error requesting push notification permission:', error);
			return 'denied';
		}
	}

	/**
	 * Send test notification
	 */
	async sendTestNotification(): Promise<void> {
		try {
			await pushNotificationService.sendTestNotification();
		} catch (error) {
			console.error('Error sending test notification:', error);
		}
	}

	/**
	 * Listen for real-time notifications and show push notifications
	 */
	async startRealtimeNotificationListener(): Promise<void> {
		try {
			const currentUser = await this.getCurrentUser();
			if (!currentUser) return;

			// Subscribe to new notifications for this user
			const subscription = supabase
				.channel('user-notifications')
				.on(
					'postgres_changes',
					{
						event: 'INSERT',
						schema: 'public',
						table: 'notification_recipients',
						filter: `user_id=eq.${currentUser.id}`
					},
					async (payload) => {
						console.log('New notification received:', payload);
						
						// Get notification details
						const { data: notification } = await supabase
							.from('notifications')
							.select('*')
							.eq('id', payload.new.notification_id)
							.single();

						if (notification) {
							// Show push notification
							await this.sendPushNotification(
								notification.title,
								notification.message,
								[currentUser.id],
								{
									notification_id: notification.id,
									url: `/notifications?id=${notification.id}`
								}
							);
						}
					}
				)
				.subscribe();

			console.log('Real-time notification listener started');
		} catch (error) {
			console.error('Error starting real-time notification listener:', error);
		}
	}

	/**
	 * Get current user from persistent auth
	 */
	private async getCurrentUser(): Promise<any> {
		return new Promise((resolve) => {
			let unsubscribe: () => void;
			unsubscribe = currentUser.subscribe((user) => {
				if (unsubscribe) unsubscribe();
				resolve(user);
			});
		});
	}
}

// Export singleton instance
export const notificationService = new NotificationManagementService();

// Export the service instance with the expected name for backward compatibility
export const notificationManagement = notificationService;