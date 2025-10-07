<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { db, supabase } from '$lib/utils/supabase';
	import { refreshNotificationCounts } from '$lib/stores/notifications';
	import TaskCompletionModal from './TaskCompletionModal.svelte';

	// Current user for role-based access
	$: userRole = $currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// User cache for displaying usernames
	let userCache: Record<string, string> = {};

	// Notification data from API
	let allNotifications: any[] = [];
	let isLoading = true;
	let errorMessage = '';

	// Image modal
	let showImageModal = false;
	let selectedImageUrl = '';

	// Task completion modal
	let showTaskCompletionModal = false;
	let selectedTaskForCompletion = null;
	let selectedAssignmentForCompletion = null;

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
			console.log(`🖼️ [Mobile Notification] Batch loading attachments for ${notificationIds.length} notifications`);
			
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
				
				console.log(`✅ [Mobile Notification] Batch loaded ${allAttachmentsResult.data.length} attachments for ${notificationIds.length} notifications`);
			} else {
				console.log(`📭 [Mobile Notification] No attachments found for any notifications`);
			}
		} catch (error) {
			console.warn(`❌ [Mobile Notification] Failed to batch load attachments:`, error);
		}

		return transformedNotifications;
	}

	function formatTimestamp(timestamp: string) {
		const date = new Date(timestamp);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffMins = Math.floor(diffMs / (1000 * 60));
		const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
		const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

		if (diffMins < 1) return 'Just now';
		if (diffMins < 60) return `${diffMins} minute${diffMins > 1 ? 's' : ''} ago`;
		if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
		if (diffDays < 7) return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
		return date.toLocaleDateString();
	}

	// Load notifications on mount
	onMount(async () => {
		await loadNotifications();
		
		// Listen for refresh events from the global header
		const handleRefresh = () => {
			forceRefreshNotifications();
		};
		
		window.addEventListener('refreshNotifications', handleRefresh);
		
		// Cleanup on component destroy
		return () => {
			window.removeEventListener('refreshNotifications', handleRefresh);
		};
	});

	async function loadNotifications() {
		try {
			isLoading = true;
			errorMessage = '';
			
			if (isAdminOrMaster) {
				// Admin users can see all notifications with their read states
				const apiNotifications = await notificationManagement.getAllNotifications($currentUser?.id || 'default-user');
				allNotifications = await transformNotificationData(apiNotifications);
			} else if ($currentUser?.id) {
				// Regular users see only their targeted notifications
				const userNotifications = await notificationManagement.getUserNotifications($currentUser.id);
				allNotifications = userNotifications.map(notification => ({
					id: notification.notification_id,
					title: notification.title,
					message: notification.message,
					type: notification.type,
					content: notification.message,
					metadata: notification.metadata || {},
					read: notification.is_read,
					timestamp: formatTimestamp(notification.created_at),
					createdBy: notification.created_by_name,
					attachments: notification.attachments || []
				}));
			}

			console.log('✅ [Mobile Notification] Loaded notifications:', allNotifications.length);
		} catch (error) {
			console.error('❌ [Mobile Notification] Error loading notifications:', error);
			errorMessage = 'Failed to load notifications. Please try again.';
		} finally {
			isLoading = false;
		}
		
		// Load user cache for displaying usernames
		await loadUserCache();
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
				let targetUsers = notification.target_users || notification.targetUsers;
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
			
			// Fetch usernames for all these user IDs from both users and hr_employees tables
			if (userIds.size > 0) {
				const userIdArray = Array.from(userIds);
				
				// First try to get from users table
				const { data: users } = await supabase
					.from('users')
					.select('id, username')
					.in('id', userIdArray);
				
				if (users) {
					// Populate the cache with usernames from users table
					for (const user of users) {
						if (user.username) {
							userCache[user.id] = user.username;
						}
					}
				}
				
				// Then try to get from hr_employees table for any missing users
				const missingUserIds = userIdArray.filter(id => !userCache[id]);
				if (missingUserIds.length > 0) {
					const { data: employees } = await supabase
						.from('hr_employees')
						.select('id, name, employee_id')
						.in('id', missingUserIds);
					
					if (employees) {
						// Populate the cache with names from hr_employees table
						for (const employee of employees) {
							if (employee.name) {
								userCache[employee.id] = employee.name;
							} else if (employee.employee_id) {
								userCache[employee.id] = `Employee ${employee.employee_id}`;
							}
						}
					}
					
					console.log(`📝 [Mobile Notification] Cached ${Object.keys(userCache).length} user names from ${users?.length || 0} users and ${employees?.length || 0} employees`);
				} else {
					console.log(`📝 [Mobile Notification] Cached ${Object.keys(userCache).length} user names from ${users?.length || 0} users`);
				}
			}
		} catch (error) {
			console.warn('Failed to load user cache:', error);
		}
	}

	export async function forceRefreshNotifications() {
		try {
			isLoading = true;
			errorMessage = '';
			
			console.log('🔄 [Mobile Notification] Force refreshing notifications...');
			
			if (isAdminOrMaster) {
				const apiNotifications = await notificationManagement.getAllNotifications($currentUser?.id || 'default-user');
				allNotifications = await transformNotificationData(apiNotifications);
			} else if ($currentUser?.id) {
				const userNotifications = await notificationManagement.getUserNotifications($currentUser.id);
				allNotifications = userNotifications.map(notification => ({
					id: notification.notification_id,
					title: notification.title,
					message: notification.message,
					type: notification.type,
					content: notification.message,
					metadata: notification.metadata || {},
					read: notification.is_read,
					timestamp: formatTimestamp(notification.created_at),
					createdBy: notification.created_by_name,
					attachments: notification.attachments || []
				}));
			}
			
			console.log('✅ [Mobile Notification] Force refresh completed. Total notifications:', allNotifications.length);
			
			// Reload user cache after refresh
			await loadUserCache();
		} catch (error) {
			console.error('❌ [Mobile Notification] Error force refreshing notifications:', error);
			errorMessage = 'Failed to refresh notifications. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	// Filter notifications based on user role and targeting
	$: notifications = allNotifications;

	let filterType = 'all';
	let showUnreadOnly = true; // Hide read notifications by default

	// Computed filtered notifications
	$: filteredNotifications = notifications.filter(notification => {
		if (showUnreadOnly && notification.read) return false;
		if (filterType === 'all') return true;
		return notification.type === filterType;
	});

	$: unreadCount = notifications.filter(n => !n.read).length;

	async function markAsRead(id: string) {
		if (!$currentUser?.id) return;
		
		try {
			console.log('🔴 [Mobile Notification] Marking notification as read:', id);
			const result = await notificationManagement.markAsRead(id, $currentUser.id);
			if (result.success) {
				// Update local state
				allNotifications = allNotifications.map(n => 
					n.id === id ? { ...n, read: true } : n
				);
				// Refresh the notification counts store for taskbar
				refreshNotificationCounts();
			}
		} catch (error) {
			console.error('Error marking notification as read:', error);
		}
	}

	async function markAllAsRead() {
		if (!$currentUser?.id) return;
		
		try {
			const result = await notificationManagement.markAllAsRead($currentUser.id);
			if (result.success) {
				// Update local state
				allNotifications = allNotifications.map(n => ({ ...n, read: true }));
				// Refresh the notification counts store for taskbar
				refreshNotificationCounts();
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
			case 'task_assigned': return '📋';
			case 'task_completed': return '✅';
			case 'task_overdue': return '⏰';
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

	// Function to format target users for display
	function getTargetUsersDisplay(notification: any) {
		try {
			
			// Check different possible locations for target user information
			let targetUsers = notification.target_users || notification.targetUsers;
			
			// Handle empty or undefined target_users, or if it contains target_type values
			if (!targetUsers || 
				targetUsers === '' || 
				targetUsers === 'specific_users' ||
				targetUsers === 'all_users' ||
				targetUsers === 'role_based' ||
				targetUsers === 'branch_based') {
				
				// If no target_users data, try to get from metadata first
				const metadata = notification.metadata || {};
				if (metadata.assigned_to_name) {
					return metadata.assigned_to_name;
				}
				
				// Try to get from cached user data
				if (metadata.assigned_to && userCache[metadata.assigned_to]) {
					return userCache[metadata.assigned_to];
				}
				
				return 'Unknown User';
			}
			
			// If target_users is a JSON string and NOT a target_type value, parse it
			if (typeof targetUsers === 'string') {
				try {
					targetUsers = JSON.parse(targetUsers);
				} catch (e) {
					console.warn('Failed to parse target_users:', targetUsers);
					// If parsing fails, try to get from metadata
					const metadata = notification.metadata || {};
					if (metadata.assigned_to_name) {
						return metadata.assigned_to_name;
					}
					
					// Try cached user data
					if (metadata.assigned_to && userCache[metadata.assigned_to]) {
						return userCache[metadata.assigned_to];
					}
					
					return 'Unknown User';
				}
			}
			
			// Handle different target types
			if (notification.target_type === 'all_users') {
				return 'All Users';
			} else if (notification.target_type === 'specific_users' && Array.isArray(targetUsers)) {
				if (targetUsers.length === 1) {
					// For single user, try to get username from metadata if available
					const metadata = notification.metadata || {};
					const assignedToName = metadata.assigned_to_name;
					if (assignedToName) {
						return assignedToName;
					}
					
					// Try to get from cached user data
					const userId = targetUsers[0];
					if (userId && userCache[userId]) {
						return userCache[userId];
					}
					
					return `User (${targetUsers.length})`;
				} else if (targetUsers.length <= 3) {
					// For small groups, try to get cached usernames
					const usernames: string[] = [];
					for (const userId of targetUsers) {
						if (userCache[userId]) {
							usernames.push(userCache[userId]);
						}
					}
					
					if (usernames.length > 0) {
						return usernames.join(', ');
					}
					
					return `${targetUsers.length} Users`;
				} else {
					return `${targetUsers.length} Users`;
				}
			} else if (notification.target_type === 'role_based') {
				return notification.target_roles ? `Role: ${notification.target_roles}` : 'Role-based';
			} else if (notification.target_type === 'branch_based') {
				return notification.target_branches ? `Branch: ${notification.target_branches}` : 'Branch-based';
			}
			
			// Final fallback - check metadata for any user information
			const metadata = notification.metadata || {};
			if (metadata.assigned_to_name) {
				return metadata.assigned_to_name;
			}
			
			// Try cached user data for assigned_to user
			if (metadata.assigned_to && userCache[metadata.assigned_to]) {
				return userCache[metadata.assigned_to];
			}
			
			return 'Unknown User';
		} catch (error) {
			console.warn('Error formatting target users:', error);
			// Try metadata fallback even in error case
			try {
				const metadata = notification.metadata || {};
				if (metadata.assigned_to_name) {
					return metadata.assigned_to_name;
				}
				
				// Try cached user data in error case too
				if (metadata.assigned_to && userCache[metadata.assigned_to]) {
					return userCache[metadata.assigned_to];
				}
			} catch (e) {
				// If even metadata parsing fails, return default
			}
			return 'Unknown User';
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

	async function openTaskCompletion(notification: any) {
		console.log('🔍 [Mobile Notification] Opening task completion for notification:', notification);
		
		// Simple task data extraction from notification
		const metadata = notification.metadata || {};
		console.log('🔍 [Mobile Notification] Full metadata object:', metadata);
		
		// Extract IDs - quick tasks use quick_task_id, normal tasks use task_id
		const quickTaskId = metadata.quick_task_id;
		const taskId = metadata.task_id || notification.task_id;
		const assignmentId = metadata.task_assignment_id || metadata.quick_task_assignment_id || notification.task_assignment_id;
		
		console.log('📋 [Mobile Notification] Extracted IDs:', { taskId, quickTaskId, assignmentId, metadata });
		
		// If metadata is empty, try to detect quick task from title/message
		const isQuickTaskByContent = notification.title && notification.title.includes('Quick Task') ||
		                            notification.message && notification.message.includes('quick task');
		
		const isNormalTaskByContent = notification.title && notification.title.includes('Task Assigned') ||
		                             notification.message && notification.message.includes('You have been assigned a new task') ||
		                             notification.type === 'task_assigned';
		
		if (isQuickTaskByContent && !quickTaskId) {
			console.log('🔍 [Mobile Notification] Detected quick task by content, searching database...');
			
			try {
				// Extract task title from notification message
				const titleMatch = notification.message.match(/"([^"]+)"/);
				const taskTitle = titleMatch ? titleMatch[1] : '';
				
				console.log('🔍 [Mobile Notification] Searching for quick task with title:', taskTitle);
				
				if (taskTitle && $currentUser?.id) {
					// Find the quick task assignment for this user and task title
					console.log('🔍 [Mobile Notification] Querying database with user ID:', $currentUser.id);
					
					const { data: assignments, error } = await supabase
						.from('quick_task_assignments')
						.select(`
							id,
							quick_task_id,
							status,
							quick_task:quick_tasks!inner(
								id,
								title,
								description,
								priority,
								deadline_datetime
							)
						`)
						.eq('assigned_to_user_id', $currentUser.id)
						.eq('quick_tasks.title', taskTitle)
						.limit(1);
					
					console.log('🔍 [Mobile Notification] Database query result:', { data: assignments, error });
					
					if (error) {
						console.error('❌ [Mobile Notification] Database error:', error);
						// Try a simpler query as fallback
						console.log('🔄 [Mobile Notification] Trying simpler query...');
						
						const { data: quickTasks, error: simpleError } = await supabase
							.from('quick_tasks')
							.select('id, title')
							.eq('title', taskTitle)
							.limit(1);
							
						console.log('🔍 [Mobile Notification] Simple query result:', { data: quickTasks, error: simpleError });
						
						if (!simpleError && quickTasks && quickTasks.length > 0) {
							const quickTaskId = quickTasks[0].id;
							console.log('✅ [Mobile Notification] Found quick task via simple query:', quickTaskId);
							await goto(`/mobile/quick-tasks/${quickTaskId}/complete`);
							return;
						}
					} else if (assignments && assignments.length > 0) {
						const assignment = assignments[0];
						console.log('✅ [Mobile Notification] Found quick task assignment:', assignment);
						
						// Navigate to quick task completion page
						await goto(`/mobile/quick-tasks/${assignment.quick_task_id}/complete`);
						return;
					} else {
						console.warn('⚠️ [Mobile Notification] No quick task assignment found for title:', taskTitle);
					}
				} else {
					console.warn('⚠️ [Mobile Notification] Missing task title or user ID:', { taskTitle, userId: $currentUser?.id });
				}
			} catch (error) {
				console.error('❌ [Mobile Notification] Error searching for quick task:', error);
			}
		}
		
		// Handle normal tasks when metadata is empty
		if (isNormalTaskByContent && !taskId && !quickTaskId) {
			console.log('🔍 [Mobile Notification] Detected normal task by content, searching database...');
			
			try {
				// Extract task title from notification message
				const titleMatch = notification.message.match(/"([^"]+)"/);
				const taskTitle = titleMatch ? titleMatch[1] : '';
				
				console.log('🔍 [Mobile Notification] Searching for normal task with title:', taskTitle);
				
				if (taskTitle && $currentUser?.id) {
					// Find the task assignment for this user and task title
					console.log('🔍 [Mobile Notification] Querying normal tasks with user ID:', $currentUser.id);
					
					const { data: assignments, error } = await supabase
						.from('task_assignments')
						.select(`
							id,
							task_id,
							status,
							task:tasks!inner(
								id,
								title,
								description,
								priority
							)
						`)
						.eq('assigned_to_user_id', $currentUser.id)
						.eq('tasks.title', taskTitle)
						.limit(1);
					
					console.log('🔍 [Mobile Notification] Normal task query result:', { data: assignments, error });
					
					if (error) {
						console.error('❌ [Mobile Notification] Normal task database error:', error);
						// Try a simpler query as fallback
						console.log('🔄 [Mobile Notification] Trying simpler normal task query...');
						
						const { data: tasks, error: simpleError } = await supabase
							.from('tasks')
							.select('id, title')
							.eq('title', taskTitle)
							.limit(1);
							
						console.log('🔍 [Mobile Notification] Simple normal task query result:', { data: tasks, error: simpleError });
						
						if (!simpleError && tasks && tasks.length > 0) {
							const normalTaskId = tasks[0].id;
							console.log('✅ [Mobile Notification] Found normal task via simple query:', normalTaskId);
							await goto(`/mobile/tasks/${normalTaskId}/complete`);
							return;
						}
					} else if (assignments && assignments.length > 0) {
						const assignment = assignments[0];
						console.log('✅ [Mobile Notification] Found normal task assignment:', assignment);
						
						// Navigate to normal task completion page
						await goto(`/mobile/tasks/${assignment.task_id}/complete`);
						return;
					} else {
						console.warn('⚠️ [Mobile Notification] No normal task assignment found for title:', taskTitle);
					}
				} else {
					console.warn('⚠️ [Mobile Notification] Missing task title or user ID for normal task:', { taskTitle, userId: $currentUser?.id });
				}
			} catch (error) {
				console.error('❌ [Mobile Notification] Error searching for normal task:', error);
			}
		}
		
		// Check if this is a quick task notification with metadata
		if (quickTaskId) {
			// Navigate to quick task completion page
			console.log('🚀 [Mobile Notification] Navigating to quick task completion:', quickTaskId);
			await goto(`/mobile/quick-tasks/${quickTaskId}/complete`);
			return;
		}
		
		// If no quick task ID, check if there's a normal task ID
		if (!taskId && !quickTaskId && !isQuickTaskByContent && !isNormalTaskByContent) {
			console.error('❌ No task_id or quick_task_id found in notification and could not determine task type');
			alert('Error: No task information found in this notification.');
			return;
		}
		
		try {
			// Get task details
			console.log('🔍 Loading task:', taskId);
			const taskResult = await db.tasks.getById(taskId);
			if (!taskResult.data) {
				console.error('❌ Task not found:', taskId);
				alert('Error: Task not found.');
				return;
			}
			
			console.log('✅ Task loaded:', taskResult.data);
			
			// Get assignment details
			let assignmentData = null;
			if (assignmentId) {
				console.log('🔍 Loading assignment:', assignmentId);
				const assignmentResult = await db.taskAssignments.getById(assignmentId);
				assignmentData = assignmentResult.data;
			} else {
				console.log('🔍 Looking up assignments for task:', taskId);
				// Find assignment for current user
				const assignmentsResult = await db.taskAssignments.getByTaskId(taskId);
				if (assignmentsResult.data && assignmentsResult.data.length > 0) {
					assignmentData = assignmentsResult.data.find(a => a.assigned_to === $currentUser?.id) || assignmentsResult.data[0];
				}
			}
			
			if (!assignmentData) {
				console.error('❌ No assignment found');
				alert('Error: No assignment found for this task.');
				return;
			}
			
			console.log('✅ Assignment loaded:', assignmentData);
			console.log('📋 Assignment requirements:', {
				require_task_finished: assignmentData.require_task_finished,
				require_photo_upload: assignmentData.require_photo_upload,
				require_erp_reference: assignmentData.require_erp_reference
			});
			
			// Override requirements based on notification message if they indicate requirements
			const message = notification.message || '';
			const photoRequired = message.includes('📷 Photo upload required') || message.includes('Photo upload required');
			const erpRequired = message.includes('📋 ERP reference required') || message.includes('ERP reference required');
			
			console.log('📝 Message-based requirements:', {
				photoRequired,
				erpRequired,
				message
			});
			
			// Use message-based requirements if they indicate requirements, otherwise use database values
			const finalRequirePhotoUpload = photoRequired || assignmentData.require_photo_upload;
			const finalRequireErpReference = erpRequired || assignmentData.require_erp_reference;
			
			console.log('🎯 Final requirements:', {
				photo: finalRequirePhotoUpload,
				erp: finalRequireErpReference
			});
			
			// Set up mobile completion modal
			selectedTaskForCompletion = {
				...taskResult.data,
				assignment_id: assignmentData.id,
				deadline_date: assignmentData.deadline_date,
				deadline_time: assignmentData.deadline_time,
				require_task_finished: assignmentData.require_task_finished ?? true,
				require_photo_upload: finalRequirePhotoUpload,
				require_erp_reference: finalRequireErpReference
			};
			
			selectedAssignmentForCompletion = {
				id: assignmentData.id,
				require_task_finished: assignmentData.require_task_finished ?? true,
				require_photo_upload: finalRequirePhotoUpload,
				require_erp_reference: finalRequireErpReference,
				deadline_date: assignmentData.deadline_date,
				deadline_time: assignmentData.deadline_time
			};
			
			console.log('🎯 Opening modal with data:', {
				task: selectedTaskForCompletion,
				assignment: selectedAssignmentForCompletion
			});
			
			showTaskCompletionModal = true;
			
		} catch (error) {
			console.error('❌ Error loading task data:', error);
			alert('Error: Failed to load task details.');
		}
	}

	function closeTaskCompletionModal() {
		showTaskCompletionModal = false;
		selectedTaskForCompletion = null;
		selectedAssignmentForCompletion = null;
	}

	async function onTaskCompleted() {
		// Refresh notifications after task completion
		await loadNotifications();
		// Close the modal
		closeTaskCompletionModal();
	}

	// Silent refresh function for background updates
	async function silentRefreshNotifications() {
		try {
			if (document.hidden) return;
			
			const previousNotifications = [...allNotifications];
			
			if (isAdminOrMaster) {
				const apiNotifications = await notificationManagement.getAllNotifications($currentUser?.id || 'default-user');
				const newNotifications = await transformNotificationData(apiNotifications);
				
				if (JSON.stringify(newNotifications) !== JSON.stringify(previousNotifications)) {
					allNotifications = newNotifications;
					// Update cache if notifications changed
					await loadUserCache();
				}
			} else if ($currentUser?.id) {
				const userNotifications = await notificationManagement.getUserNotifications($currentUser.id);
				const newNotifications = userNotifications.map(notification => ({
					id: notification.notification_id,
					title: notification.title,
					message: notification.message,
					type: notification.type,
					content: notification.message,
					metadata: notification.metadata || {},
					read: notification.is_read,
					timestamp: formatTimestamp(notification.created_at),
					createdBy: notification.created_by_name,
					attachments: notification.attachments || []
				}));
				
				if (JSON.stringify(newNotifications) !== JSON.stringify(previousNotifications)) {
					allNotifications = newNotifications;
					// Update cache if notifications changed
					await loadUserCache();
				}
			}
		} catch (error) {
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

<div class="mobile-notification-center">
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
		<div class="filters-section">
			<div class="filter-row">
				<select bind:value={filterType} class="filter-select">
					<option value="all">All Types</option>
					<option value="success">Success</option>
					<option value="warning">Warning</option>
					<option value="error">Error</option>
					<option value="info">Info</option>
					<option value="announcement">Announcement</option>
					<option value="task_assigned">Task Assigned</option>
					<option value="task_completed">Task Completed</option>
				</select>
				
				<label class="checkbox-filter">
					<input type="checkbox" bind:checked={showUnreadOnly}>
					<span class="checkmark"></span>
					Hide Read
				</label>
			</div>
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
											{#if notification.createdBy}
												<span class="notification-creator">• from: {notification.createdBy}</span>
											{/if}
											{#if notification.targetUsers || notification.target_users}
												<span class="notification-receiver">• to: {getTargetUsersDisplay(notification)}</span>
											{/if}
										{/if}
									</div>
								</div>
								{#if !notification.read}
									<div class="unread-dot"></div>
								{/if}
							</div>
							
							<div class="notification-message">
								{notification.message}
							</div>
							
							<!-- Notification Image/Attachments Display -->
							{#if notification.image_url || (notification.attachments && notification.attachments.length > 0)}
								<div class="notification-attachments">
									{#if notification.image_url}
										<div class="notification-image">
											<button
												on:click={() => openImageModal(notification.image_url)}
												class="image-thumbnail"
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
										</div>
									{/if}
									
									{#if notification.attachments && notification.attachments.length > 0}
										<div class="file-attachments">
											{#each notification.attachments as attachment}
												<a 
													href={attachment.fileUrl} 
													download={attachment.fileName}
													class="attachment-link"
												>
													<span class="attachment-icon">📎</span>
													<span class="attachment-name">{attachment.fileName}</span>
												</a>
											{/each}
										</div>
									{/if}
								</div>
							{/if}
							
							<!-- Action Buttons -->
							<div class="notification-actions">
								{#if (notification.type === 'task_assigned' || notification.type === 'task_assignment') && !notification.read}
									<button 
										class="action-btn complete-task-btn" 
										on:click={() => openTaskCompletion(notification)}
									>
										✅ Complete Task
									</button>
								{/if}
								{#if !notification.read}
									<button 
										class="action-btn read-btn" 
										on:click={() => markAsRead(notification.id)}
									>
										👁️ Mark Read
									</button>
								{/if}
								{#if isAdminOrMaster}
									<button 
										class="action-btn delete-btn" 
										on:click={() => deleteNotification(notification.id)}
									>
										🗑️ Delete
									</button>
								{/if}
							</div>
						</div>
					</div>
				{/each}
			{/if}
		</div>
	{/if}
</div>

<!-- Image Modal -->
{#if showImageModal}
	<div class="image-modal-overlay" on:click={closeImageModal} role="button" tabindex="0" on:keydown={(e) => e.key === 'Escape' && closeImageModal()}>
		<div class="image-modal-content" on:click|stopPropagation>
			<button
				on:click={closeImageModal}
				class="image-modal-close"
				aria-label="Close image"
			>
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M18 6L6 18M6 6l12 12"/>
				</svg>
			</button>
			<img
				src={selectedImageUrl}
				alt="Notification image"
				class="modal-image"
				on:click|stopPropagation
			/>
		</div>
	</div>
{/if}

<!-- Task Completion Modal -->
{#if showTaskCompletionModal && selectedTaskForCompletion && selectedAssignmentForCompletion}
	<TaskCompletionModal
		task={selectedTaskForCompletion}
		assignment={selectedAssignmentForCompletion}
		onClose={closeTaskCompletionModal}
		onTaskCompleted={onTaskCompleted}
	/>
{/if}

<style>
	.mobile-notification-center {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.error-banner {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem;
		margin: 1rem;
		background: #FEF2F2;
		border: 1px solid #FECACA;
		border-radius: 8px;
		color: #DC2626;
		font-size: 0.875rem;
	}

	.retry-btn {
		background: #DC2626;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 0.25rem 0.75rem;
		font-size: 0.75rem;
		cursor: pointer;
		margin-left: auto;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		color: #6B7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #F3F4F6;
		border-top: 3px solid #10B981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	.filters-section {
		padding: 1rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.filter-row {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.filter-select {
		flex: 1;
		padding: 0.75rem;
		border: 2px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3B82F6;
	}

	.checkbox-filter {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #374151;
		cursor: pointer;
		white-space: nowrap;
	}

	.checkbox-filter input {
		display: none;
	}

	.checkmark {
		width: 18px;
		height: 18px;
		border: 2px solid #D1D5DB;
		border-radius: 4px;
		background: white;
		position: relative;
		transition: all 0.2s;
	}

	.checkbox-filter input:checked + .checkmark {
		background: #10B981;
		border-color: #10B981;
	}

	.checkbox-filter input:checked + .checkmark::after {
		content: '✓';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		color: white;
		font-size: 12px;
		font-weight: bold;
	}

	.notifications-list {
		flex: 1;
		padding: 1rem;
		gap: 1rem;
		display: flex;
		flex-direction: column;
		padding-bottom: calc(1rem + env(safe-area-inset-bottom));
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		text-align: center;
		color: #6B7280;
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
		background: white;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
		overflow: hidden;
		transition: all 0.2s;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.notification-item.unread {
		border-left: 4px solid #10B981;
	}

	.notification-item.priority-urgent {
		border-left-color: #DC2626;
	}

	.notification-item.priority-high {
		border-left-color: #F59E0B;
	}

	.notification-item.priority-medium {
		border-left-color: #3B82F6;
	}

	.notification-item.priority-low {
		border-left-color: #6B7280;
	}

	.notification-content {
		padding: 1rem;
	}

	.notification-header {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.notification-icon {
		font-size: 1.25rem;
		flex-shrink: 0;
		margin-top: 0.125rem;
	}

	.notification-meta {
		flex: 1;
		min-width: 0;
	}

	.notification-title {
		margin: 0 0 0.25rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
		line-height: 1.4;
	}

	.notification-details {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.25rem;
		font-size: 0.75rem;
		color: #6B7280;
	}

	.notification-timestamp {
		font-weight: 500;
	}

	.notification-creator {
		color: #9CA3AF;
	}

	.notification-receiver {
		color: #6366F1;
		font-weight: 500;
	}

	.unread-dot {
		width: 8px;
		height: 8px;
		background: #10B981;
		border-radius: 50%;
		flex-shrink: 0;
		margin-top: 0.375rem;
	}

	.notification-message {
		color: #374151;
		font-size: 0.875rem;
		line-height: 1.5;
		margin-bottom: 0.75rem;
	}

	.notification-attachments {
		margin-bottom: 0.75rem;
	}

	.notification-image {
		margin-bottom: 0.5rem;
	}

	.image-thumbnail {
		position: relative;
		display: block;
		background: none;
		border: none;
		cursor: pointer;
		border-radius: 8px;
		overflow: hidden;
		width: 100%;
		max-width: 200px;
	}

	.notification-img {
		width: 100%;
		height: auto;
		max-height: 150px;
		object-fit: cover;
		display: block;
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

	.image-thumbnail:hover .image-overlay {
		opacity: 1;
	}

	.expand-icon {
		filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.3));
	}

	.file-attachments {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.attachment-link {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem;
		background: #F3F4F6;
		border-radius: 6px;
		text-decoration: none;
		color: #374151;
		font-size: 0.875rem;
		transition: background 0.2s;
	}

	.attachment-link:hover {
		background: #E5E7EB;
	}

	.attachment-icon {
		flex-shrink: 0;
	}

	.attachment-name {
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.notification-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.action-btn {
		padding: 0.5rem 0.75rem;
		border: none;
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.complete-task-btn {
		background: #10B981;
		color: white;
	}

	.complete-task-btn:hover {
		background: #059669;
	}

	.read-btn {
		background: #3B82F6;
		color: white;
	}

	.read-btn:hover {
		background: #2563EB;
	}

	.delete-btn {
		background: #EF4444;
		color: white;
	}

	.delete-btn:hover {
		background: #DC2626;
	}

	/* Image Modal */
	.image-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.image-modal-content {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.image-modal-close {
		position: absolute;
		top: -3rem;
		right: 0;
		background: rgba(255, 255, 255, 0.9);
		border: none;
		border-radius: 50%;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background 0.2s;
		z-index: 10;
	}

	.image-modal-close:hover {
		background: white;
	}

	.modal-image {
		max-width: 100%;
		max-height: 100%;
		object-fit: contain;
		border-radius: 8px;
	}

	/* Mobile optimizations */
	@media (max-width: 640px) {
		.filter-row {
			flex-direction: column;
			align-items: stretch;
			gap: 0.75rem;
		}

		.checkbox-filter {
			justify-content: center;
		}

		.notification-actions {
			flex-direction: column;
		}

		.action-btn {
			width: 100%;
			justify-content: center;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.notification-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}

		.notifications-list {
			padding-bottom: max(1rem, env(safe-area-inset-bottom));
		}
	}
</style>