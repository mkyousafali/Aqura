<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { cashierUser } from '$lib/stores/cashierAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { db, supabase } from '$lib/utils/supabase';
	import { refreshNotificationCounts } from '$lib/stores/notifications';
	import { notificationSoundManager } from '$lib/utils/inAppNotificationSounds';
	import CreateNotification from './CreateNotification.svelte';
	import AdminReadStatusModal from './AdminReadStatusModal.svelte';
	import TaskCompletionModal from '../tasks/TaskCompletionModal.svelte';
	import FileDownload from '$lib/components/common/FileDownload.svelte';

	// Current user for role-based access (check cashier user first, then desktop user)
	$: activeUser = $cashierUser || $currentUser;
	$: userRole = activeUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// User cache for displaying usernames
	let userCache: Record<string, string> = {};

	// Notification data from API
	let allNotifications: any[] = [];
	let previousNotificationIds: Set<string> = new Set();
	let isLoading = true;
	let errorMessage = '';

	// Image modal
	let showImageModal = false;
	let selectedImageUrl = '';

	// Convert API response to component format and load task images
	async function transformNotificationData(apiNotifications: any[]) {
		if (apiNotifications.length === 0) {
			return [];
		}

		// First, prepare all notifications with basic data
		const transformedNotifications = apiNotifications.map(notification => ({
			id: notification.id,
			title: notification.title,
			message: notification.message,
			type: notification.type,
			timestamp: formatTimestamp(notification.created_at),
			read: notification.is_read || false,
			priority: notification.priority,
			createdBy: notification.created_by_name,
			target_users: notification.target_users,
			target_type: notification.target_type,
			targetBranch: 'all',
			status: notification.status,
			readCount: notification.read_count,
			totalRecipients: notification.total_recipients,
			metadata: notification.metadata,
			image_url: null,
			attachments: []
		}));

		// Batch load all attachments at once (much more efficient)
		try {
			const notificationIds = apiNotifications.map(n => n.id);
			console.log(`🖼️ [Notification] Batch loading attachments for ${notificationIds.length} notifications`);
			
			// Get all attachments for all notifications in one query
			const allAttachmentsResult = await db.notificationAttachments.getBatchByNotificationIds(notificationIds);
			
			if (allAttachmentsResult.data && allAttachmentsResult.data.length > 0) {
				// Group attachments by notification_id
				const attachmentsByNotification = allAttachmentsResult.data.reduce((acc, att) => {
					if (!acc[att.notification_id]) {
						acc[att.notification_id] = [];
					}
					acc[att.notification_id].push({
						...att,
						fileUrl: att.file_path.startsWith('http') 
							? att.file_path 
							: `https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/notification-images/${att.file_path}`,
						fileName: att.file_name,
						fileSize: att.file_size,
						fileType: att.file_type,
						uploadedAt: att.created_at,
						uploadedBy: att.uploaded_by
					});
					return acc;
				}, {});
				
				// Assign attachments to their respective notifications
				transformedNotifications.forEach(transformed => {
					const notificationAttachments = attachmentsByNotification[transformed.id] || [];
					transformed.attachments = notificationAttachments;
					
					// Set the first image as the primary image_url for backward compatibility
					const firstImage = notificationAttachments.find(att => att.file_type.startsWith('image/'));
					if (firstImage) {
						transformed.image_url = firstImage.fileUrl;
					}
				});
				
				console.log(`✅ [Notification] Batch loaded ${allAttachmentsResult.data.length} attachments for ${notificationIds.length} notifications`);
			} else {
				console.log(`📭 [Notification] No attachments found for any notifications`);
			}
		} catch (error) {
			console.warn(`❌ [Notification] Failed to batch load attachments:`, error);
		}

		// Handle task attachments (batch load for performance)
		// Collect all task IDs first
		const taskIds = transformedNotifications
			.filter(transformed => {
				const notification = apiNotifications.find(n => n.id === transformed.id);
				return notification?.metadata?.task_id;
			})
			.map(transformed => {
				const notification = apiNotifications.find(n => n.id === transformed.id);
				return notification.metadata.task_id;
			});

		// Batch load all task attachments if we have any task IDs
		if (taskIds.length > 0) {
			try {
				console.log(`🖼️ [Notification] Batch loading task attachments for ${taskIds.length} tasks`);
				
				// Query all task attachments at once
				const { data: taskAttachments, error } = await supabase
					.from('task_images')
					.select('*')
					.in('task_id', taskIds);

				if (error) {
					console.warn(`❌ [Notification] Failed to batch load task attachments:`, error);
				} else if (taskAttachments && taskAttachments.length > 0) {
					// Group attachments by task_id
					const attachmentsByTaskId = taskAttachments.reduce((acc, attachment) => {
						if (!acc[attachment.task_id]) {
							acc[attachment.task_id] = [];
						}
						acc[attachment.task_id].push({
							id: attachment.id,
							fileName: attachment.file_name || 'Unknown File',
							fileSize: attachment.file_size || 0,
							fileType: attachment.file_type || 'application/octet-stream',
							fileUrl: attachment.file_path && attachment.file_path.startsWith('http') 
								? attachment.file_path 
								: `https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/task-images/${attachment.file_path || ''}`,
							downloadUrl: attachment.file_path && attachment.file_path.startsWith('http') 
								? attachment.file_path 
								: `https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/task-images/${attachment.file_path || ''}`,
							uploadedBy: attachment.uploaded_by_name || attachment.uploaded_by || 'Unknown',
							uploadedAt: attachment.created_at
						});
						return acc;
					}, {});

					// Assign task attachments to their respective notifications
					for (const transformed of transformedNotifications) {
						const notification = apiNotifications.find(n => n.id === transformed.id);
						if (notification?.metadata?.task_id) {
							const taskAttachmentsForNotification = attachmentsByTaskId[notification.metadata.task_id] || [];
							transformed.attachments = [...transformed.attachments, ...taskAttachmentsForNotification];
						}
					}
					
					console.log(`✅ [Notification] Batch loaded ${taskAttachments.length} task attachments`);
				} else {
					console.log(`📭 [Notification] No task attachments found`);
				}
			} catch (error) {
				console.warn(`❌ [Notification] Exception during batch task attachment loading:`, error);
			}
		}

		return transformedNotifications;
	}

	// Function to load and cache user information
	async function loadUserCache() {
		try {
			// Extract all user IDs from notifications that we might need to display
			const userIds = new Set<string>();
			
			for (const notification of allNotifications) {
				const metadata = notification.metadata || {};
				
				// Add assigned_to user
				if (metadata.assigned_to) {
					userIds.add(metadata.assigned_to);
				}
				
				// Add created_by user (this might be the UUID)
				if (notification.created_by && notification.created_by !== 'system') {
					userIds.add(notification.created_by);
				}
				
				// Add target users if available
				let targetUsers = notification.target_users;
				if (typeof targetUsers === 'string') {
					try {
						targetUsers = JSON.parse(targetUsers);
					} catch (e) {
						// Skip invalid JSON
					}
				}
				
				if (Array.isArray(targetUsers)) {
					targetUsers.forEach(userId => {
						if (userId && typeof userId === 'string') {
							userIds.add(userId);
						}
					});
				}
			}
			
			// Fetch user information for all these user IDs
			if (userIds.size > 0) {
				const userIdArray = Array.from(userIds);
				
				// First try to get from hr_employees table (prioritize employee names)
				const { data: employees } = await supabase
					.from('hr_employees')
					.select('id, name, employee_id')
					.in('id', userIdArray);
				
				if (employees) {
					// Populate the cache with names from hr_employees table (highest priority)
					for (const employee of employees) {
						if (employee.name) {
							userCache[employee.id] = employee.name;
						} else if (employee.employee_id) {
							userCache[employee.id] = `Employee ${employee.employee_id}`;
						}
					}
				}
				
				// Then try to get from users table for any missing users
				const missingUserIds = userIdArray.filter(id => !userCache[id]);
				
				if (missingUserIds.length > 0) {
					const { data: users } = await supabase
						.from('users')
						.select('id, username')
						.in('id', missingUserIds);
					
					if (users) {
						// Populate the cache with usernames from users table (fallback)
						for (const user of users) {
							if (user.username) {
								userCache[user.id] = user.username;
							}
						}
					}
					
					console.log(`📝 [Admin Notification] Cached ${Object.keys(userCache).length} user names from ${employees?.length || 0} employees and ${users?.length || 0} users`);
				} else {
					console.log(`📝 [Admin Notification] Cached ${Object.keys(userCache).length} user names from ${employees?.length || 0} employees`);
				}
			}
		} catch (error) {
			console.warn('Failed to load user cache:', error);
		}
	}

	// Helper function to determine if notification is new (within last 30 seconds)
	function isNewNotification(notification: any): boolean {
		// Parse the timestamp correctly - it could be in different formats
		let notificationTime: number;
		if (notification.timestamp instanceof Date) {
			notificationTime = notification.timestamp.getTime();
		} else if (typeof notification.timestamp === 'string') {
			// Try parsing as ISO string first
			const parsed = new Date(notification.timestamp);
			if (!isNaN(parsed.getTime())) {
				notificationTime = parsed.getTime();
			} else {
				// Fallback: treat as already formatted timestamp
				console.warn('Could not parse notification timestamp:', notification.timestamp);
				return false;
			}
		} else {
			console.warn('Invalid notification timestamp format:', notification.timestamp);
			return false;
		}
		
		const currentTime = Date.now();
		const timeDiffSeconds = (currentTime - notificationTime) / 1000;
		
		// Consider notification "new" if it's less than 60 seconds old (increased from 30)
		return timeDiffSeconds <= 60;
	}

	function formatTimestamp(isoString: string): string {
		const date = new Date(isoString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffMins = Math.floor(diffMs / 60000);
		const diffHours = Math.floor(diffMins / 60);
		const diffDays = Math.floor(diffHours / 24);

		if (diffMins < 1) return 'Just now';
		if (diffMins < 60) return `${diffMins} minute${diffMins > 1 ? 's' : ''} ago`;
		if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
		if (diffDays < 7) return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
		return date.toLocaleDateString();
	}

	// Load notifications on mount
	onMount(async () => {
		await loadNotifications();
	});

	async function loadNotifications() {
		try {
			isLoading = true;
			errorMessage = '';
			
			console.log('🔔 [NotificationCenter] Loading notifications for user:', activeUser);
			
			// Store previous notification IDs to detect new ones
			const previousIds = new Set(allNotifications.map(n => n.id));
			
			if (isAdminOrMaster) {
				// Admin users can see all notifications with their read states
				console.log('👑 [NotificationCenter] Loading as admin/master');
				const apiNotifications = await notificationManagement.getAllNotifications(activeUser?.id || 'default-user');
				allNotifications = await transformNotificationData(apiNotifications);
			} else if (activeUser?.id) {
				// Regular users see only their targeted notifications
				console.log('👤 [NotificationCenter] Loading as regular user');
				const userNotifications = await notificationManagement.getUserNotifications(activeUser.id);
				allNotifications = userNotifications.map(notification => ({
					id: notification.notification_id,
					title: notification.title,
					message: notification.message,
					type: notification.type,
					timestamp: formatTimestamp(notification.created_at),
					read: notification.is_read,
					priority: notification.priority,
					createdBy: notification.created_by_name,
					targetUsers: 'user-specific',
					targetBranch: 'user-specific',
					recipientId: notification.recipient_id
				}));
			} else {
				console.warn('⚠️ [NotificationCenter] No active user found');
			}
			
			// Check for new notifications and play sound
			if (previousIds.size > 0) { // Only after initial load
				const newNotifications = allNotifications.filter(n => 
					!previousIds.has(n.id) && 
					!n.read && 
					isNewNotification(n)
				);
				
				console.log(`🔍 [NotificationCenter] Checking for new notifications:`, {
					totalNotifications: allNotifications.length,
					previousCount: previousIds.size,
					newNotificationsFound: newNotifications.length,
					newNotificationIds: newNotifications.map(n => n.id),
					soundManagerAvailable: !!notificationSoundManager
				});
				
				// Play sound for new notifications
				for (const notification of newNotifications) {
					console.log(`🔊 [NotificationCenter] Attempting to play sound for notification:`, {
						id: notification.id,
						title: notification.title,
						type: notification.type,
						priority: notification.priority,
						timestamp: notification.timestamp
					});
					
					if (notificationSoundManager) {
						try {
							await notificationSoundManager.playNotificationSound({
								id: notification.id,
								title: notification.title,
								message: notification.message,
								type: notification.type,
								priority: notification.priority || 'medium',
								timestamp: new Date(notification.timestamp),
								read: notification.read,
								soundEnabled: true
							});
							console.log(`✅ [NotificationCenter] Sound played successfully for: ${notification.title}`);
						} catch (error) {
							console.error(`❌ [NotificationCenter] Failed to play sound for ${notification.title}:`, error);
						}
					} else {
						console.warn(`⚠️ [NotificationCenter] Sound manager not available`);
					}
				}
				
				if (newNotifications.length > 0) {
					console.log(`🔊 [NotificationCenter] Processed ${newNotifications.length} new notifications for sound`);
				}
			} else {
				console.log(`🔍 [NotificationCenter] Initial load - no sound playing (${allNotifications.length} notifications loaded)`);
			}
			
			// Load user cache after notifications are loaded
			await loadUserCache();
		} catch (error) {
			console.error('Error loading notifications:', error);
			errorMessage = 'Failed to load notifications. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	// Force refresh function that clears cache and reloads notifications
	async function forceRefreshNotifications() {
		try {
			// Clear the current notifications array and user cache
			allNotifications = [];
			userCache = {};
			isLoading = true;
			errorMessage = '';
			
			// Add cache-busting parameter to force fresh data
			const timestamp = Date.now();
			console.log('🔄 [NotificationCenter] Force refreshing notifications at:', new Date().toISOString());
			
			// Force clear any browser cache by adding timestamp to requests
			if (isAdminOrMaster) {
				// Force fresh data by bypassing any cache
				const apiNotifications = await notificationManagement.getAllNotifications(activeUser?.id || 'default-user');
				allNotifications = await transformNotificationData(apiNotifications);
				
				// Load user cache after getting notifications
				await loadUserCache();
			} else if (activeUser?.id) {
				const userNotifications = await notificationManagement.getUserNotifications(activeUser.id);
				allNotifications = userNotifications.map(notification => ({
					id: notification.notification_id,
					title: notification.title,
					message: notification.message,
					type: notification.type,
					content: notification.message,
					metadata: notification.metadata || {},
					read: notification.is_read,
					timestamp: notification.created_at,
					createdBy: notification.created_by_name,
					attachments: notification.attachments || []
				}));
				
				// Load user cache after getting notifications
				await loadUserCache();
			}
			
			// Filter out any notifications that might reference non-existent tasks
			const validNotifications = [];
			for (const notification of allNotifications) {
				if (notification.type === 'task_assigned') {
					// Skip this notification if it seems to reference a deleted task
					// This is a client-side safety check
					try {
						if (notification.metadata?.task_id) {
							// Could add a check here to verify task exists
							// For now, include all notifications from the cleaned database
						}
						validNotifications.push(notification);
					} catch (error) {
						console.warn('Skipping potentially invalid notification:', notification.id);
					}
				} else {
					validNotifications.push(notification);
				}
			}
			
			allNotifications = validNotifications;
			console.log('✅ [NotificationCenter] Force refresh completed. Total notifications:', allNotifications.length);
		} catch (error) {
			console.error('❌ [NotificationCenter] Error force refreshing notifications:', error);
			errorMessage = 'Failed to refresh notifications. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	// Filter notifications based on user role and targeting
	$: notifications = allNotifications; // All filtering is now done by API

	let filterType = 'all';
	let showUnreadOnly = true; // Changed: Hide read notifications by default

	// Computed filtered notifications
	$: filteredNotifications = notifications.filter(notification => {
		if (showUnreadOnly && notification.read) return false;
		if (filterType === 'all') return true;
		return notification.type === filterType;
	});

	$: unreadCount = notifications.filter(n => !n.read).length;

	async function markAsRead(id: string) {
		if (!activeUser?.id) return;
		
		try {
			console.log('🔴 [NotificationCenter] Marking notification as read:', id);
			const result = await notificationManagement.markAsRead(id, activeUser.id);
			console.log('🔴 [NotificationCenter] Mark as read result:', result);
			if (result.success) {
				// Update local state
				allNotifications = allNotifications.map(n => 
					n.id === id ? { ...n, read: true } : n
				);
				console.log('🔴 [NotificationCenter] Updated local state for notification:', id);
				// Refresh the notification counts store for taskbar
				refreshNotificationCounts(undefined, true); // Silent refresh
			}
		} catch (error) {
			console.error('Error marking notification as read:', error);
		}
	}

	async function markAllAsRead() {
		if (!activeUser?.id) return;

		try {
			const result = await notificationManagement.markAllAsRead(activeUser.id);
			if (result.success) {
				// Update local state
				allNotifications = allNotifications.map(n => ({ ...n, read: true }));
				// Refresh the notification counts store for taskbar
				refreshNotificationCounts(undefined, true); // Silent refresh
			}
		} catch (error) {
			console.error('Error marking all notifications as read:', error);
		}
	}

	async function deleteNotification(id: string) {
		try {
			const result = await notificationManagement.deleteNotification(id);
			if (result.success) {
				// Update local state
				allNotifications = allNotifications.filter(n => n.id !== id);
			}
		} catch (error) {
			console.error('Error deleting notification:', error);
		}
	}

	function getNotificationIcon(type: string) {
		switch(type) {
			case 'success': return '✅';
			case 'warning': return '⚠️';
			case 'error': return '❌';
			case 'info': return 'ℹ️';
			case 'announcement': return '📢';
			default: return '📢';
		}
	}

	function getPriorityColor(priority: string) {
		switch(priority) {
			case 'urgent': return 'priority-urgent';
			case 'high': return 'priority-high';
			case 'medium': return 'priority-medium';
			case 'low': return 'priority-low';
			default: return 'priority-medium';
		}
	}

	// Image modal functions
	function openImageModal(imageUrl: string) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}

	function closeImageModal() {
		showImageModal = false;
		selectedImageUrl = '';
	}

	// Function to display target users with names from cache
	function getTargetUsersDisplay(notification: any): string {
		try {
			if (!notification.target_users) {
				return 'No specific targets';
			}

			// Handle different data formats
			let targetUserIds: string[] = [];
			
			if (typeof notification.target_users === 'string') {
				try {
					const parsed = JSON.parse(notification.target_users);
					if (Array.isArray(parsed)) {
						targetUserIds = parsed;
					} else if (typeof parsed === 'object' && parsed !== null) {
						// Handle object format with user_ids array
						targetUserIds = parsed.user_ids || [];
					}
				} catch {
					// If JSON parsing fails, treat as a single ID
					targetUserIds = [notification.target_users];
				}
			} else if (Array.isArray(notification.target_users)) {
				targetUserIds = notification.target_users;
			} else if (typeof notification.target_users === 'object' && notification.target_users !== null) {
				targetUserIds = notification.target_users.user_ids || [];
			}

			if (targetUserIds.length === 0) {
				return 'No specific targets';
			}

			// Map user IDs to names using the cache (prioritize employee names, then usernames)
			const userNames = targetUserIds
				.map(id => {
					// First try to get from user cache (includes both usernames and employee names)
					if (userCache[id]) {
						return userCache[id];
					}
					// If not found in cache, show a truncated ID for better readability
					const shortId = id.length > 8 ? id.substring(0, 8) + '...' : id;
					return `ID: ${shortId}`;
				})
				.filter(name => name !== undefined);

			if (userNames.length === 0) {
				return 'Unknown users';
			}

			// Format the display string
			if (userNames.length === 1) {
				return userNames[0];
			} else if (userNames.length <= 3) {
				return userNames.join(', ');
			} else {
				return `${userNames.slice(0, 2).join(', ')} and ${userNames.length - 2} others`;
			}
		} catch (error) {
			console.error('Error displaying target users:', error);
			return 'Error loading targets';
		}
	}

	function openCreateNotification() {
		const windowId = `create-notification-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		
		openWindow({
			id: windowId,
			title: 'Create Notification',
			component: CreateNotification,
			icon: '📝',
			size: { width: 600, height: 700 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openAdminReadStatus() {
		const windowId = `admin-read-status-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		
		openWindow({
			id: windowId,
			title: 'Admin: Read Status Per User',
			component: AdminReadStatusModal,
			icon: '👥',
			size: { width: 800, height: 600 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 100 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function openTaskCompletion(notification: any) {
		const windowId = `task-completion-${notification.id}-${Date.now()}`;
		
		// Parse task data from notification message or metadata
		const taskData = parseTaskDataFromNotification(notification);
		
		// Check if we have a valid task ID
		if (!taskData.taskId) {
			console.error('❌ [NotificationCenter] Cannot open task completion - no task ID found in notification:', notification);
			alert('Error: Cannot complete task. The notification does not contain valid task information. This may be an older notification format.');
			return;
		}
		
		// Initialize variables outside try-catch scope
		let taskObject = null;
		let assignmentData = null;
		
		// If we have task and assignment IDs, fetch the complete data to match MyTasksView format
		if (taskData.taskId && taskData.assignmentId) {
			try {
				console.log('🔍 [NotificationCenter] Fetching complete task data for:', taskData.taskId);
				const taskResult = await db.tasks.getById(taskData.taskId);
				const assignmentResult = await db.taskAssignments.getById(taskData.assignmentId);
				
				if (taskResult.data && assignmentResult.data) {
					// Store assignment data for later use
					assignmentData = assignmentResult.data;
					
					// Create unified task object matching MyTasksView format
					taskObject = {
						...taskResult.data,
						assignment_id: taskData.assignmentId,
						deadline_date: assignmentData.deadline_date,
						deadline_time: assignmentData.deadline_time,
						deadline_datetime: assignmentData.deadline_datetime,
						schedule_date: assignmentData.schedule_date,
						schedule_time: assignmentData.schedule_time,
						assignment_date: assignmentData.assignment_date,
						notes: assignmentData.notes,
						// Assignment requirements
						require_task_finished: assignmentData.require_task_finished ?? false,
						require_photo_upload: assignmentData.require_photo_upload ?? false,
						require_erp_reference: assignmentData.require_erp_reference ?? false
					};
					console.log('✅ [NotificationCenter] Complete task object created:', taskObject);
				}
			} catch (error) {
				console.error('❌ [NotificationCenter] Error fetching complete task data:', error);
			}
		}
		
		openWindow({
			id: windowId,
			title: `Complete Task: ${taskData.title || 'Task'}`,
			component: TaskCompletionModal,
			icon: '✅',
			props: {
				// Use unified task object approach like MyTasksView
				task: taskObject,
				assignmentId: taskData.assignmentId,
				// Use actual requirements from the assignment if available, otherwise default values
				requireTaskFinished: true, // Always required for task finished
				requirePhotoUpload: assignmentData?.require_photo_upload ?? false,
				requireErpReference: assignmentData?.require_erp_reference ?? false,
				notificationId: notification.id,
				onTaskCompleted: () => {
					loadNotifications();
					windowManager.closeWindow(windowId);
				}
			},
			size: { width: 600, height: 700 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function parseTaskDataFromNotification(notification: any) {
		// Debug logging
		console.log('🔍 [NotificationCenter] Parsing notification:', {
			notification,
			metadata: notification.metadata,
			message: notification.message,
			type: notification.type
		});
		
		// Try to extract task information from notification metadata first, then notification properties, then message
		const metadata = notification.metadata || {};
		const message = notification.message || '';
		
		// Check metadata first
		if (metadata.task_id) {
			console.log('✅ [NotificationCenter] Found task_id in metadata:', metadata.task_id);
			return {
				taskId: metadata.task_id,
				title: metadata.task_title || 'Unknown Task',
				description: metadata.notes || '',
				deadline: metadata.deadline || '',
				requireTaskFinished: metadata.require_task_finished || false,
				requirePhotoUpload: metadata.require_photo_upload || false,
				requireErpReference: metadata.require_erp_reference || false,
				assignmentId: metadata.task_assignment_id || null
			};
		}
		
		// Check notification properties (column values)
		if (notification.task_id) {
			console.log('✅ [NotificationCenter] Found task_id in notification properties:', notification.task_id);
			return {
				taskId: notification.task_id,
				title: metadata.task_title || 'Unknown Task',
				description: metadata.notes || '',
				deadline: metadata.deadline || '',
				requireTaskFinished: metadata.require_task_finished || false,
				requirePhotoUpload: metadata.require_photo_upload || false,
				requireErpReference: metadata.require_erp_reference || false,
				assignmentId: notification.task_assignment_id || metadata.task_assignment_id || null
			};
		}
		
		// Fallback to parsing from message for older notifications
		const titleMatch = message.match(/task:\s*"([^"]+)"/i);
		const deadlineMatch = message.match(/deadline:\s*([^.\n]+)/i);
		const notesMatch = message.match(/notes:\s*(.+)/i);
		
		console.warn('⚠️ [NotificationCenter] No task_id in metadata, falling back to message parsing');
		console.log('🔍 [NotificationCenter] Message parsing results:', {
			titleMatch,
			deadlineMatch,
			notesMatch,
			message
		});
		
		return {
			taskId: null, // Changed from 'unknown' to null for safety
			title: titleMatch ? titleMatch[1].trim() : 'Unknown Task',
			description: notesMatch ? notesMatch[1].trim() : '',
			deadline: deadlineMatch ? deadlineMatch[1].trim() : '',
			requireTaskFinished: true,
			requirePhotoUpload: false,
			requireErpReference: false,
			assignmentId: null
		};
	}

	// Silent refresh function for background updates
	async function silentRefreshNotifications() {
		try {
			// Only refresh if user is not actively interacting with the page
			if (document.hidden) return;
			
			const previousNotifications = [...allNotifications];
			
			if (isAdminOrMaster) {
				const apiNotifications = await notificationManagement.getAllNotifications(activeUser?.id || 'default-user');
				const newNotifications = await transformNotificationData(apiNotifications);
				
				// Only update if there are actual changes
				if (JSON.stringify(newNotifications) !== JSON.stringify(previousNotifications)) {
					allNotifications = newNotifications;
				}
			} else if (activeUser?.id) {
				const userNotifications = await notificationManagement.getUserNotifications(activeUser.id);
				const newNotifications = await transformNotificationData(userNotifications);
				
				// Only update if there are actual changes
				if (JSON.stringify(newNotifications) !== JSON.stringify(previousNotifications)) {
					allNotifications = newNotifications;
				}
			}
		} catch (error) {
			// Silent fail - don't show errors during background refresh
			console.warn('Silent notification refresh failed:', error);
		}
	}

	// Refresh notifications periodically
	onMount(() => {
		const interval = setInterval(() => {
			silentRefreshNotifications();
		}, 30000); // Refresh every 30 seconds

		return () => clearInterval(interval);
	});
</script>

<div class="notification-center">
	<!-- Header -->
	<div class="header">
		<h1 class="title">Notification Center</h1>
		<div class="header-actions">
			{#if isAdminOrMaster}
				<button class="create-btn" on:click={openCreateNotification}>
					<span class="icon">📝</span>
					Create Notification
				</button>
				<button class="status-btn" on:click={openAdminReadStatus}>
					<span class="icon">👥</span>
					Read Status
				</button>
			{/if}
			<button class="refresh-btn" on:click={forceRefreshNotifications} disabled={isLoading} title="Force refresh and clear cache">
				<span class="icon">🔄</span>
				{isLoading ? 'Refreshing...' : 'Refresh'}
			</button>
			
			<span class="unread-badge">{unreadCount} Unread</span>
			{#if unreadCount > 0}
				<button class="mark-all-btn" on:click={markAllAsRead}>
					Mark All as Read
				</button>
			{/if}
		</div>
	</div>

	<!-- Error Message -->
	{#if errorMessage}
		<div class="error-banner">
			<span class="error-icon">❌</span>
			{errorMessage}
			<button class="retry-btn" on:click={loadNotifications}>Retry</button>
		</div>
	{/if}

	<!-- Loading State -->
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading notifications...</p>
		</div>
	{:else}
		<!-- Filters -->
		<div class="filters">
			<div class="filter-group">
				<label for="type-filter" class="filter-label">Filter by type:</label>
				<select id="type-filter" bind:value={filterType} class="filter-select">
					<option value="all">All Types</option>
					<option value="success">Success</option>
					<option value="warning">Warning</option>
					<option value="error">Error</option>
					<option value="info">Info</option>
					<option value="announcement">Announcement</option>
				</select>
			</div>
			<label class="checkbox-filter">
				<input type="checkbox" bind:checked={showUnreadOnly}>
				Hide read notifications
			</label>
		</div>

		<!-- Notifications List -->
		<div class="notifications-list">
			{#if filteredNotifications.length === 0}
				<div class="empty-state">
					<div class="empty-icon">🔔</div>
					<h3>No notifications found</h3>
					<p>All caught up! No notifications match your current filters.</p>
				</div>
			{:else}
				{#each filteredNotifications as notification (notification.id)}
					<div class="notification-item {notification.read ? 'read' : 'unread'} {getPriorityColor(notification.priority)}" data-notification-id={notification.id}>
						<div class="notification-content">
							<div class="notification-header">
								<div class="notification-icon">
									{getNotificationIcon(notification.type)}
								</div>
								<div class="notification-meta">
									<h3 class="notification-title">{notification.title}</h3>
									<div class="notification-details">
										<span class="notification-timestamp">{notification.timestamp}</span>
										{#if isAdminOrMaster}
											<span class="notification-creator">• by {notification.createdBy}</span>
											{#if notification.readCount !== undefined && notification.totalRecipients !== undefined}
												<span class="read-stats">• {notification.readCount}/{notification.totalRecipients} read</span>
											{/if}
										{/if}
									</div>
								</div>
								<div class="notification-actions">
									{#if notification.type === 'task_assigned' && !notification.read}
										<button 
											class="action-btn complete-task-btn" 
											on:click={() => openTaskCompletion(notification)}
											title="Complete task"
										>
											✅ Complete
										</button>
									{/if}
									{#if !notification.read}
										<button 
											class="action-btn read-btn" 
											on:click={() => markAsRead(notification.id)}
											title="Mark as read"
										>
											👁️
										</button>
									{/if}
									{#if isAdminOrMaster}
										<button 
											class="action-btn delete-btn" 
											on:click={() => deleteNotification(notification.id)}
											title="Delete notification"
										>
											🗑️
										</button>
									{/if}
								</div>
							</div>
							<div class="notification-message">
								{notification.message}
							</div>
							
							<!-- Target Users Display -->
							{#if isAdminOrMaster && notification.target_users}
								<div class="notification-targets">
									<span class="targets-label">👥 Sent to:</span>
									<span class="targets-list">{getTargetUsersDisplay(notification)}</span>
								</div>
							{/if}
							
							<!-- Notification Image/Attachments Display -->
							{#if notification.image_url || (notification.attachments && notification.attachments.length > 0)}
								<div class="notification-attachments">
									{#if notification.image_url}
										<div class="notification-image">
											<button
												on:click={() => openImageModal(notification.image_url)}
												class="image-thumbnail"
												title="Click to view full image"
												aria-label="View notification image"
											>
												<img
													src={notification.image_url}
													alt="Notification"
													class="notification-img"
													loading="lazy"
													on:error={(e) => {
														console.warn(`Failed to load notification image: ${notification.image_url}`);
														e.target.parentElement.parentElement.style.display = 'none';
													}}
												/>
												<div class="image-overlay">
													<svg class="expand-icon" fill="white" viewBox="0 0 24 24" width="20" height="20">
														<path d="M15 3h6v6l-2-2-4 4-2-2 4-4-2-2zM3 9h6v6l-2-2-4 4-2-2 4-4-2-2z"/>
													</svg>
												</div>
											</button>
											<!-- Download button for image -->
											<a 
												href={notification.image_url} 
												download 
												class="download-button"
												title="Download image"
											>
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
												</svg>
											</a>
										</div>
									{/if}
									
									{#if notification.attachments && notification.attachments.length > 0}
										<div class="file-attachments">
											<FileDownload 
												files={notification.attachments}
												showDetails={false}
												compact={true}
												maxHeight="150px"
												on:download={(e) => console.log('Downloaded:', e.detail.file)}
												on:preview={(e) => console.log('Previewed:', e.detail.file)}
											/>
										</div>
									{/if}
								</div>
							{/if}
						</div>
						{#if !notification.read}
							<div class="unread-indicator"></div>
						{/if}
					</div>
				{/each}
			{/if}
		</div>
	{/if}
</div>

<!-- Image Modal -->
{#if showImageModal}
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75" on:click={closeImageModal}>
		<div class="relative max-w-4xl max-h-4xl p-4">
			<button
				on:click={closeImageModal}
				class="absolute top-2 right-2 z-10 bg-white bg-opacity-80 hover:bg-opacity-100 rounded-full p-2 transition-all duration-200"
			>
				<svg class="w-6 h-6 text-gray-800" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
				</svg>
			</button>
			<img
				src={selectedImageUrl}
				alt="Task image full size"
				class="max-w-full max-h-full object-contain rounded-lg"
				on:click|stopPropagation
			/>
		</div>
	</div>
{/if}

<style>
	.notification-center {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		overflow: hidden;
		padding: 20px;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
		margin-bottom: 20px;
	}

	.title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.header-actions {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.create-btn {
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.create-btn:hover {
		background: #059669;
		transform: translateY(-1px);
	}

	.create-btn .icon {
		font-size: 16px;
	}

	.status-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.status-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.status-btn .icon {
		font-size: 16px;
	}

	.refresh-btn {
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #4b5563;
		transform: translateY(-1px);
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.refresh-btn .icon {
		font-size: 16px;
	}

	.unread-badge {
		background: #ef4444;
		color: white;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.mark-all-btn {
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.mark-all-btn:hover {
		background: #059669;
	}

	.error-banner {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px 16px;
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 8px;
		color: #dc2626;
		margin-bottom: 20px;
	}

	.error-icon {
		font-size: 16px;
	}

	.retry-btn {
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 4px 12px;
		font-size: 12px;
		cursor: pointer;
		margin-left: auto;
	}

	.retry-btn:hover {
		background: #b91c1c;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		color: #6b7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #f3f4f6;
		border-top: 3px solid #10b981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.read-stats {
		font-size: 12px;
		color: #10b981;
		font-weight: 500;
	}

	.filters {
		display: flex;
		align-items: center;
		gap: 20px;
		padding: 16px;
		background: #f9fafb;
		border-radius: 8px;
		margin-bottom: 20px;
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.filter-label {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.filter-select {
		padding: 6px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		color: #374151;
	}

	.checkbox-filter {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 14px;
		color: #374151;
		cursor: pointer;
	}

	.notifications-list {
		flex: 1;
		overflow-y: auto;
		padding-right: 8px;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		text-align: center;
		color: #6b7280;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
		opacity: 0.5;
	}

	.empty-state h3 {
		font-size: 18px;
		font-weight: 600;
		margin: 0 0 8px 0;
		color: #374151;
	}

	.empty-state p {
		font-size: 14px;
		margin: 0;
		max-width: 300px;
	}

	.notification-item {
		position: relative;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		margin-bottom: 12px;
		overflow: hidden;
		transition: all 0.2s ease;
	}

	.notification-item:hover {
		border-color: #d1d5db;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.notification-item.unread {
		border-left: 4px solid #10b981;
		background: #f0fdf4;
	}

	.notification-item.read {
		opacity: 0.8;
	}

	.notification-item.priority-urgent {
		border-left-color: #dc2626;
		background: #fef2f2;
	}

	.notification-item.priority-high {
		border-left-color: #ef4444;
	}

	.notification-item.priority-medium {
		border-left-color: #f59e0b;
	}

	.notification-item.priority-low {
		border-left-color: #6b7280;
	}

	.notification-content {
		padding: 16px;
	}

	.notification-header {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		margin-bottom: 8px;
	}

	.notification-icon {
		font-size: 20px;
		flex-shrink: 0;
		margin-top: 2px;
	}

	.notification-meta {
		flex: 1;
	}

	.notification-title {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
		line-height: 1.3;
	}

	.notification-timestamp {
		font-size: 12px;
		color: #6b7280;
	}

	.notification-details {
		display: flex;
		align-items: center;
		gap: 4px;
		flex-wrap: wrap;
	}

	.notification-creator {
		font-size: 12px;
		color: #10b981;
		font-weight: 500;
	}

	.notification-actions {
		display: flex;
		gap: 8px;
	}

	.action-btn {
		background: none;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		padding: 4px 8px;
		cursor: pointer;
		font-size: 12px;
		transition: all 0.2s;
	}

	.action-btn:hover {
		background: #f3f4f6;
	}

	.read-btn:hover {
		border-color: #10b981;
		color: #10b981;
	}

	.complete-task-btn {
		background: #10b981;
		color: white;
		border: 1px solid #10b981;
	}

	.complete-task-btn:hover {
		background: #059669;
		border-color: #059669;
	}

	.delete-btn:hover {
		border-color: #ef4444;
		color: #ef4444;
	}

	.notification-message {
		color: #374151;
		font-size: 14px;
		line-height: 1.5;
		padding-left: 32px;
	}

	.notification-targets {
		display: flex;
		align-items: center;
		gap: 8px;
		padding-left: 32px;
		margin-top: 8px;
		font-size: 13px;
	}

	.targets-label {
		color: #6b7280;
		font-weight: 500;
	}

	.targets-list {
		color: #374151;
		background-color: #f3f4f6;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 12px;
		max-width: 300px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.unread-indicator {
		position: absolute;
		top: 16px;
		right: 16px;
		width: 8px;
		height: 8px;
		background: #10b981;
		border-radius: 50%;
	}

	/* Scrollbar styling */
	.notifications-list::-webkit-scrollbar {
		width: 6px;
	}

	.notifications-list::-webkit-scrollbar-track {
		background: #f1f5f9;
		border-radius: 3px;
	}

	.notifications-list::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 3px;
	}

	.notifications-list::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}

	/* Image display styles */
	.notification-attachments {
		margin-top: 12px;
		padding-left: 32px;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.notification-image {
		position: relative;
		display: inline-block;
		max-width: 100%;
	}

	.download-button {
		position: absolute;
		top: 8px;
		right: 8px;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.2s ease;
		text-decoration: none;
		opacity: 0.8;
	}

	.download-button:hover {
		background: rgba(0, 0, 0, 0.9);
		transform: scale(1.1);
		opacity: 1;
		color: white;
		text-decoration: none;
	}

	.file-attachments {
		margin-top: 8px;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		overflow: hidden;
	}

	.image-thumbnail {
		border: none;
		background: none;
		padding: 0;
		cursor: pointer;
		border-radius: 8px;
		overflow: hidden;
		transition: transform 0.2s ease, box-shadow 0.2s ease;
		position: relative;
		display: block;
	}

	.image-thumbnail:hover {
		transform: scale(1.02);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.image-thumbnail:hover .image-overlay {
		opacity: 1;
	}

	.notification-img {
		max-width: 300px;
		max-height: 200px;
		min-width: 80px;
		min-height: 80px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
		transition: border-color 0.2s ease;
		display: block;
	}

	.notification-img:hover {
		border-color: #6366f1;
	}

	.image-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.4);
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 8px;
		opacity: 0;
		transition: opacity 0.2s ease;
	}

	.expand-icon {
		filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));
	}

	.attachment-count {
		display: flex;
		align-items: center;
		margin-top: 4px;
	}

	.attachment-badge {
		background: var(--color-primary);
		color: white;
		font-size: 12px;
		padding: 4px 8px;
		border-radius: 12px;
		font-weight: 500;
	}
</style>