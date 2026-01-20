<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { db, supabase } from '$lib/utils/supabase';
	import { refreshNotificationCounts } from '$lib/stores/notifications';
	import TaskCompletionModal from '../tasks/TaskCompletionModal.svelte';
	import { locale, getTranslation } from '$lib/i18n';

	// Current user for role-based access
	$: userRole = $currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// User cache for displaying usernames
	let userCache: Record<string, string> = {};

	// Notification data from API
	let allNotifications: any[] = [];
	let isLoading = true;
	let errorMessage = '';

	// Pagination
	let currentPage = 0;
	let pageSize = 30;
	let hasMoreNotifications = true;
	let isLoadingMore = false;

	// Image modal
	let showImageModal = false;
	let selectedImageUrl = '';

	// Task completion modal
	let showTaskCompletionModal = false;
	let selectedTaskForCompletion = null;
	let selectedAssignmentForCompletion = null;

	// Swipe gesture state
	let swipeStartX = 0;
	let swipeCurrentX = 0;
	let swipeThreshold = 100; // Minimum distance for swipe
	let isSwipeActive = false;
	let swipeTargetNotification = null;

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
			
			// Get all attachments for all notifications in one query
			const allAttachmentsResult = await db.notificationAttachments.getBatchByNotificationIds(notificationIds);
			
			if (allAttachmentsResult.error) {
				console.warn(`⚠️ [Notification] Error fetching attachments, continuing without them:`, allAttachmentsResult.error);
			}
			
			if (allAttachmentsResult.data && allAttachmentsResult.data.length > 0) {
				// Group attachments by notification_id
				const attachmentsByNotification = allAttachmentsResult.data.reduce((acc, att) => {
					if (!acc[att.notification_id]) {
						acc[att.notification_id] = [];
					}
					acc[att.notification_id].push({
						...att,
						type: 'notification_attachment',
						fileUrl: att.file_path && att.file_path.startsWith('http') 
							? att.file_path 
							: `https://supabase.urbanaqura.com/storage/v1/object/public/notification-images/${att.file_path}`,
						fileName: att.file_name,
						fileSize: att.file_size,
						fileType: att.file_type,
						uploadedAt: att.created_at,
						uploadedBy: att.uploaded_by,
						isImage: att.file_type && att.file_type.startsWith('image/')
					});
					return acc;
				}, {});
				
				// Assign attachments to their respective notifications
				transformedNotifications.forEach(transformed => {
					const notificationAttachments = attachmentsByNotification[transformed.id] || [];
					transformed.attachments = notificationAttachments;
					
					// Set the first image as the primary image_url for backward compatibility
					const firstImage = notificationAttachments.find(att => att.file_type && att.file_type.startsWith('image/'));
					if (firstImage) {
						transformed.image_url = firstImage.fileUrl;
					}
				});
				
				
			} else {
				
			}
		} catch (error) {
			console.warn(`❌ [Notification] Failed to batch load attachments:`, error);
			// Continue without attachments
		}

		// Process each notification for attachments (both task-related and quick task)
		for (let transformed of transformedNotifications) {
			const originalNotification = apiNotifications.find(n => n.id === transformed.id);
			if (!originalNotification) continue;

			// Initialize a consolidated attachments array with existing notification attachments
			const allAttachments = [...(transformed.attachments || [])];

			// 1. Load task images for task-related notifications
			if (originalNotification.task_id || originalNotification.task_assignment_id) {
				
				
				const taskAttachments = [];
				
				// Get task images from task_id
				if (originalNotification.task_id) {
					try {
						const { data: taskImages, error } = await supabase
							.from('task_images')
						.select('*')
						.eq('task_id', originalNotification.task_id);
						
						if (error) {
							console.warn(`⚠️ [Notification] Error fetching task images for task ${originalNotification.task_id}:`, error);
						}
					
						if (taskImages && taskImages.length > 0) {
							taskAttachments.push(...taskImages.map(img => ({
								...img,
								type: 'task_image',
								fileUrl: `https://supabase.urbanaqura.com/storage/v1/object/public/task-images/${img.file_url || img.file_path}`,
								fileName: img.file_name,
								fileSize: img.file_size,
								fileType: img.file_type,
								isImage: true,
								source: 'Task'
							})));
						}
					} catch (taskError) {
						console.warn(`⚠️ [Notification] Exception loading task images for task ${originalNotification.task_id}:`, taskError);
					}
				}
				
				// Get task images from task_assignment_id
				if (originalNotification.task_assignment_id) {
					try {
						const { data: assignment, error: assignmentError } = await supabase
							.from('task_assignments')
							.select('task_id')
							.eq('id', originalNotification.task_assignment_id)
							.single();
						
						if (assignmentError) {
							console.warn(`⚠️ [Notification] Error fetching assignment:`, assignmentError);
						}
						
						if (assignment && assignment.task_id) {
							const { data: taskImages, error: imageError } = await supabase
								.from('task_images')
								.select('*')
								.eq('task_id', assignment.task_id);
							
							if (imageError) {
								console.warn(`⚠️ [Notification] Error fetching task images for assignment:`, imageError);
							}
							
							if (taskImages && taskImages.length > 0) {
								taskAttachments.push(...taskImages.map(img => ({
									...img,
									type: 'task_image',
									fileUrl: `https://supabase.urbanaqura.com/storage/v1/object/public/task-images/${img.file_url || img.file_path}`,
									fileName: img.file_name,
									fileSize: img.file_size,
									fileType: img.file_type,
									isImage: true,
									source: 'Task Assignment'
								})));
							}
						}
					} catch (assignmentError) {
						console.warn(`⚠️ [Notification] Exception loading task assignment images:`, assignmentError);
					}
				}
				
				// Add task attachments to consolidated array
				if (taskAttachments.length > 0) {
					allAttachments.push(...taskAttachments);
					
					// Set first image as primary if not already set
					if (!transformed.image_url) {
						const firstImage = taskAttachments.find(att => att.isImage);
						if (firstImage) {
							transformed.image_url = firstImage.fileUrl;
						}
					}
				}
			}

				// 2. Get quick task files if this is a quick task notification
				let quickTaskAttachments = [];
				console.log(`🔍 [Quick Task Debug] Checking notification ${transformed.id}:`, {
					title: originalNotification.title,
					message: originalNotification.message,
					metadata: originalNotification.metadata,
					titleLower: originalNotification.title?.toLowerCase(),
					messageLower: originalNotification.message?.toLowerCase(),
					titleMatch: originalNotification.title?.toLowerCase().includes('quick task'),
					messageMatch: originalNotification.message?.toLowerCase().includes('quick task'),
					hasNoTask: !originalNotification.task_id && !originalNotification.task_assignment_id,
					hasNotificationAttachments: originalNotification.has_notification_attachments,
					taskId: originalNotification.task_id,
					taskAssignmentId: originalNotification.task_assignment_id
				});
				
				// Check for quick task notifications - either by text content or by pattern (no task but has attachments)
				const isQuickTaskByText = (originalNotification.message && originalNotification.message.toLowerCase().includes('quick task')) ||
										 (originalNotification.title && originalNotification.title.toLowerCase().includes('quick task'));
				
				// For pattern-based detection, check if notification has no task IDs (typical for quick tasks)
				const hasNoTaskConnection = !originalNotification.task_id && !originalNotification.task_assignment_id;
				const isQuickTaskByPattern = hasNoTaskConnection; // Simplified pattern detection
				
				console.log(`🔍 [Quick Task Detection] For notification ${transformed.id}:`, {
					isQuickTaskByText,
					isQuickTaskByPattern,
					willProcess: isQuickTaskByText || isQuickTaskByPattern,
					hasAttachments: originalNotification.has_notification_attachments,
					noTaskId: !originalNotification.task_id,
					noAssignmentId: !originalNotification.task_assignment_id,
					title: originalNotification.title,
					message: originalNotification.message
				});
				
				if (isQuickTaskByText || isQuickTaskByPattern) {
					console.log(`🖼️ [Mobile Notification] Loading quick task files for notification: ${transformed.id}`, {
						detectionMethod: isQuickTaskByText ? 'text-based' : 'pattern-based',
						reason: isQuickTaskByText ? 'contains "quick task" in title/message' : 'has attachments but no task IDs'
					});
					
					// Try to get quick task ID from metadata first
					let quickTaskId = null;
					if (originalNotification.metadata && originalNotification.metadata.quick_task_id) {
						quickTaskId = originalNotification.metadata.quick_task_id;
						
					}
					
					let quickTaskFiles = [];
					if (quickTaskId) {
						// Get files for specific quick task only
						const { data: specificFiles } = await supabase
							.from('quick_task_files')
							.select('*')
							.eq('quick_task_id', quickTaskId);
						quickTaskFiles = specificFiles || [];
						
					} else {
						// No specific quick task ID found, cannot load attachments
						
					}
					
					if (quickTaskFiles && quickTaskFiles.length > 0) {
						quickTaskAttachments = quickTaskFiles.map(file => ({
							...file,
							type: 'quick_task_file',
							fileUrl: `https://supabase.urbanaqura.com/storage/v1/object/public/quick-task-files/${file.storage_path}`,
							fileName: file.file_name,
							fileSize: file.file_size,
							fileType: file.file_type,
							isImage: file.file_type && file.file_type.startsWith('image/'),
							source: 'Quick Task'
						}));
						
						// Add quick task attachments to consolidated array
						allAttachments.push(...quickTaskAttachments);
						
						// Set first image as primary if not already set
						if (!transformed.image_url) {
							const firstImage = quickTaskAttachments.find(att => att.isImage);
							if (firstImage) {
								transformed.image_url = firstImage.fileUrl;
							}
						}
					}
				}

				// Remove duplicates based on file URL and assign final attachments array
				const uniqueAttachments = allAttachments.filter((att, index, self) => 
					index === self.findIndex(a => a.fileUrl === att.fileUrl)
				);
				transformed.attachments = uniqueAttachments;
			}

		// Debug: Log final notification structure
		console.log(`📎 [Mobile Notification] Final notifications with attachments:`, transformedNotifications.map(n => ({
			id: n.id,
			title: n.title,
			attachmentCount: n.attachments ? n.attachments.length : 0,
			attachments: n.attachments ? n.attachments.map(a => ({ fileName: a.fileName, fileType: a.fileType, fileUrl: a.fileUrl })) : []
		})));

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

	// Reactive statement to load notifications when user is available
	$: if ($currentUser?.id && allNotifications.length === 0 && !isLoading) {
		loadNotifications();
	}

	// Load notifications on mount
	onMount(async () => {
		// Initial load
		if ($currentUser?.id) {
			await loadNotifications();
		}
		
		// Listen for refresh events from the global header
		const handleRefresh = () => {
			forceRefreshNotifications(true); // Silent refresh by default
		};
		
		window.addEventListener('refreshNotifications', handleRefresh);
		
		// Add scroll listener for infinite scroll
		const handleScroll = () => {
			const scrollContainer = document.querySelector('.notifications-list');
			if (!scrollContainer) return;
			
			const scrollTop = scrollContainer.scrollTop;
			const scrollHeight = scrollContainer.scrollHeight;
			const clientHeight = scrollContainer.clientHeight;
			
			// Load more when user is 200px from bottom
			if (scrollHeight - scrollTop - clientHeight < 200 && hasMoreNotifications && !isLoadingMore) {
				loadMoreNotifications();
			}
		};
		
		const scrollContainer = document.querySelector('.notifications-list');
		scrollContainer?.addEventListener('scroll', handleScroll);
		
		// Cleanup on component destroy
		return () => {
			window.removeEventListener('refreshNotifications', handleRefresh);
			scrollContainer?.removeEventListener('scroll', handleScroll);
		};
	});

	async function loadNotifications() {
		// Don't load if user is not available yet
		if (!$currentUser?.id) {
			isLoading = false;
			return;
		}

		try {
			isLoading = true;
			errorMessage = '';
			currentPage = 0;
			
			// All users should get the same notification format with full details
			const apiNotifications = await notificationManagement.getAllNotifications($currentUser.id, currentPage, pageSize);
			allNotifications = await transformNotificationData(apiNotifications);
			hasMoreNotifications = apiNotifications.length === pageSize;

		} catch (error) {
			console.error('❌ [Mobile Notification] Error loading notifications:', error);
			errorMessage = 'Failed to load notifications. Please try again.';
		} finally {
			isLoading = false;
		}
		
		// Load user cache for displaying usernames
		await loadUserCache();
	}

	// Load more notifications (infinite scroll)
	async function loadMoreNotifications() {
		if (isLoadingMore || !hasMoreNotifications) return;
		
		try {
			isLoadingMore = true;
			currentPage++;
			
			if ($currentUser?.id) {
				const apiNotifications = await notificationManagement.getAllNotifications($currentUser.id, currentPage, pageSize);
				const newNotifications = await transformNotificationData(apiNotifications);
				allNotifications = [...allNotifications, ...newNotifications];
				hasMoreNotifications = apiNotifications.length === pageSize;
				
				// Load user cache for new notifications
				await loadUserCache();
			}
		} catch (error) {
			console.error('❌ [Mobile Notification] Error loading more notifications:', error);
		} finally {
			isLoadingMore = false;
		}
	}

	// Function to load and cache user information with batch optimization
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
			
			// Only fetch users not already in cache
			const uncachedUserIds = Array.from(userIds).filter(id => !userCache[id]);
			
			if (uncachedUserIds.length === 0) {
				return; // All users already cached
			}
			
			// Batch load users in chunks of 50 to avoid URL length issues
			const BATCH_SIZE = 50;
			for (let i = 0; i < uncachedUserIds.length; i += BATCH_SIZE) {
				const batch = uncachedUserIds.slice(i, i + BATCH_SIZE);
				
				// Parallel fetch users and employees
				const [usersResult, employeesResult] = await Promise.all([
					supabase
						.from('users')
						.select('id, username, employee_id')
						.in('id', batch),
					supabase
						.from('hr_employees')
						.select('id, name, employee_id')
						.in('id', batch)
				]);
				
				const users = usersResult.data || [];
				const employees = employeesResult.data || [];
				
				// Create employee map for quick lookup
				const employeeMap = Object.fromEntries(
					employees.map(emp => [emp.id, emp])
				);
				
				// Cache users with employee names
				for (const user of users) {
					let displayName = 'Unknown User';
					const employee = user.employee_id ? employeeMap[user.employee_id] : employeeMap[user.id];
					
					if (employee?.name) {
						displayName = employee.name;
					} else if (user.username) {
						displayName = user.username;
					} else {
						displayName = `User ${user.id.substring(0, 8)}`;
					}
					
					userCache[user.id] = displayName;
				}
				
				// Cache employees not found in users table
				for (const employee of employees) {
					if (!userCache[employee.id]) {
						userCache[employee.id] = employee.name || `Employee ${employee.employee_id || employee.id.substring(0, 8)}`;
					}
				}
				
				// Fallback for still missing users
				batch.forEach(id => {
					if (!userCache[id]) {
						userCache[id] = `User ${id.substring(0, 8)}`;
					}
				});
			}
			
			console.log(`✅ [User Cache] Successfully cached ${Object.keys(userCache).length} users`);
		} catch (error) {
			console.warn('Failed to load user cache:', error);
		}
	}

	export async function forceRefreshNotifications(silent = true) {
		try {
			if (!silent) {
				isLoading = true;
			}
			errorMessage = '';
			currentPage = 0;
			
			if (!silent) {
				
			}
			
			if (isAdminOrMaster) {
				const apiNotifications = await notificationManagement.getAllNotifications($currentUser?.id || 'default-user', currentPage, pageSize);
				allNotifications = await transformNotificationData(apiNotifications);
				hasMoreNotifications = apiNotifications.length === pageSize;
			} else if ($currentUser?.id) {
				const userNotifications = await notificationManagement.getUserNotifications($currentUser.id, currentPage, pageSize);
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
				hasMoreNotifications = userNotifications.length === pageSize;
			}
			
			if (!silent) {
				
			}
			
			// Reload user cache after refresh (always silent)
			await loadUserCache();
		} catch (error) {
			if (!silent) {
				console.error('❌ [Mobile Notification] Error force refreshing notifications:', error);
				errorMessage = 'Failed to refresh notifications. Please try again.';
			}
		} finally {
			if (!silent) {
				isLoading = false;
			}
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
			
			const result = await notificationManagement.markAsRead(id, $currentUser.id);
			if (result.success) {
				// Update local state
				allNotifications = allNotifications.map(n => 
					n.id === id ? { ...n, read: true } : n
				);
				// Refresh the notification counts store for taskbar
				refreshNotificationCounts(undefined, true); // Silent refresh
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
				// Update local state - mark all notifications as read
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

	// Download function for attachments
	function downloadFile(attachment: any) {
		if (attachment.fileUrl) {
			const link = document.createElement('a');
			link.href = attachment.fileUrl;
			link.download = attachment.fileName || 'download';
			link.target = '_blank';
			link.rel = 'noopener noreferrer';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
		}
	}

	async function openTaskCompletion(notification: any) {
		
		
		// Simple task data extraction from notification
		const metadata = notification.metadata || {};
		
		
		// Extract IDs - quick tasks use quick_task_id, normal tasks use task_id
		const quickTaskId = metadata.quick_task_id;
		const taskId = metadata.task_id || notification.task_id;
		const assignmentId = metadata.task_assignment_id || metadata.quick_task_assignment_id || notification.task_assignment_id;
		
		
		
		// If metadata is empty, try to detect quick task from title/message
		const isQuickTaskByContent = notification.title && notification.title.includes('Quick Task') ||
		                            notification.message && notification.message.includes('quick task');
		
		const isNormalTaskByContent = notification.title && notification.title.includes('Task Assigned') ||
		                             notification.message && notification.message.includes('You have been assigned a new task') ||
		                             notification.type === 'task_assigned';
		
		if (isQuickTaskByContent && !quickTaskId) {
			
			
			try {
				// Extract task title from notification message
				const titleMatch = notification.message.match(/"([^"]+)"/);
				const taskTitle = titleMatch ? titleMatch[1] : '';
				
				
				
				if (taskTitle && $currentUser?.id) {
					// Find the quick task assignment for this user and task title
					
					
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
						.or(`assigned_to_user_id.eq.${$currentUser.id},quick_tasks.assigned_by_user_id.eq.${$currentUser.id}`)
						.eq('quick_tasks.title', taskTitle)
						.limit(1);
					
					
					
					if (error) {
						console.error('❌ [Mobile Notification] Database error:', error);
						// Try a simpler query as fallback
						
						
						const { data: quickTasks, error: simpleError } = await supabase
							.from('quick_tasks')
							.select('id, title')
							.eq('title', taskTitle)
							.limit(1);
							
						
						
						if (!simpleError && quickTasks && quickTasks.length > 0) {
							const quickTaskId = quickTasks[0].id;
							
							await goto(`/mobile-interface/quick-tasks/${quickTaskId}/complete`);
							return;
						}
					} else if (assignments && assignments.length > 0) {
						const assignment = assignments[0];
						
						
						// Navigate to quick task completion page
						await goto(`/mobile-interface/quick-tasks/${assignment.quick_task_id}/complete`);
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
			
			
			try {
				// Extract task title from notification message
				const titleMatch = notification.message.match(/"([^"]+)"/);
				const taskTitle = titleMatch ? titleMatch[1] : '';
				
				
				
				if (taskTitle && $currentUser?.id) {
					// Find the task assignment for this user and task title
					
					
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
						.or(`assigned_to_user_id.eq.${$currentUser.id},tasks.assigned_by_user_id.eq.${$currentUser.id}`)
						.eq('tasks.title', taskTitle)
						.limit(1);
					
					
					
					if (error) {
						console.error('❌ [Mobile Notification] Normal task database error:', error);
						// Try a simpler query as fallback
						
						
						const { data: tasks, error: simpleError } = await supabase
							.from('tasks')
							.select('id, title')
							.eq('title', taskTitle)
							.limit(1);
							
						
						
						if (!simpleError && tasks && tasks.length > 0) {
							const normalTaskId = tasks[0].id;
							
							await goto(`/mobile-interface/tasks/${normalTaskId}/complete`);
							return;
						}
					} else if (assignments && assignments.length > 0) {
						const assignment = assignments[0];
						
						
						// Navigate to normal task completion page
						await goto(`/mobile-interface/tasks/${assignment.task_id}/complete`);
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
			
			await goto(`/mobile-interface/quick-tasks/${quickTaskId}/complete`);
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
			
			const taskResult = await db.tasks.getById(taskId);
			if (!taskResult.data) {
				console.error('❌ Task not found:', taskId);
				alert('Error: Task not found.');
				return;
			}
			
			
			
			// Get assignment details
			let assignmentData = null;
			if (assignmentId) {
				
				const assignmentResult = await db.taskAssignments.getById(assignmentId);
				assignmentData = assignmentResult.data;
			} else {
				
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

	function openCreateNotification() {
		// Navigate to mobile create notification page
		goto('/mobile-interface/notifications/create');
	}

	// Silent refresh function for background updates
	async function silentRefreshNotifications() {
		try {
			if (document.hidden) return;
			
			const previousNotifications = [...allNotifications];
			
			// All users get the same notification format
			if ($currentUser?.id) {
				const apiNotifications = await notificationManagement.getAllNotifications($currentUser.id);
				const newNotifications = await transformNotificationData(apiNotifications);
				
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

	// Swipe gesture functions
	function handleTouchStart(event, notification) {
		if (notification.read) return; // Only allow swipe on unread notifications
		
		swipeStartX = event.touches[0].clientX;
		swipeCurrentX = swipeStartX;
		isSwipeActive = true;
		swipeTargetNotification = notification;
	}

	function handleTouchMove(event) {
		if (!isSwipeActive || !swipeTargetNotification) return;
		
		swipeCurrentX = event.touches[0].clientX;
		const deltaX = swipeCurrentX - swipeStartX;
		
		// Only allow left swipe (negative delta)
		if (deltaX < 0) {
			event.preventDefault();
			// Apply transform to show visual feedback
			const element = event.currentTarget;
			element.style.transform = `translateX(${Math.max(deltaX, -120)}px)`;
			element.style.opacity = Math.max(0.5, 1 + deltaX / 200);
		}
	}

	function handleTouchEnd(event) {
		if (!isSwipeActive || !swipeTargetNotification) return;
		
		const deltaX = swipeCurrentX - swipeStartX;
		const element = event.currentTarget;
		
		// Reset transform
		element.style.transform = '';
		element.style.opacity = '';
		
		// Check if swipe distance meets threshold for mark as read
		if (deltaX < -swipeThreshold) {
			markAsRead(swipeTargetNotification.id);
		}
		
		// Reset swipe state
		isSwipeActive = false;
		swipeTargetNotification = null;
		swipeStartX = 0;
		swipeCurrentX = 0;
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
		<!-- Create Notification Button (Admin Only) -->
		{#if isAdminOrMaster}
			<div class="action-header">
				<button class="create-notification-btn" on:click={openCreateNotification}>
					<span class="btn-icon">📝</span>
					{getTranslation('mobile.assignContent.createNotification')}
				</button>
			</div>
		{/if}

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
			
			{#if unreadCount > 0}
				<div class="action-row">
					<button class="mark-all-read-btn" on:click={markAllAsRead}>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M20 6L9 17l-5-5"/>
						</svg>
						Mark all {unreadCount} as read
					</button>
				</div>
				<div class="swipe-hint">
					💡 Tip: Swipe left on any unread notification to mark it as read
				</div>
			{/if}
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
					<div class="notification-item {notification.read ? 'read' : 'unread'} {getPriorityColor(notification.priority)}" 
						 data-notification-id={notification.id}
						 on:touchstart={!notification.read ? (e) => handleTouchStart(e, notification) : null}
						 on:touchmove={handleTouchMove}
						 on:touchend={handleTouchEnd}>
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
							{#if notification.attachments && notification.attachments.length > 0}
								<div class="notification-attachments">
									<div class="attachments-grid">
										{#each notification.attachments as attachment}
											<div class="attachment-item">
												{#if attachment.file_type && attachment.file_type.startsWith('image/')}
													<div class="attachment-image-container">
														<img 
															src={attachment.fileUrl} 
															alt={attachment.fileName}
															class="attachment-image-preview"
															loading="lazy"
															on:click={() => openImageModal(attachment.fileUrl)}
														/>
														<div class="attachment-info">
															<span class="attachment-filename">{attachment.fileName}</span>
															<button 
																class="download-btn"
																on:click={() => downloadFile(attachment)}
																title="Download {attachment.fileName}"
															>
																<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																	<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
																	<polyline points="7,10 12,15 17,10"/>
																	<line x1="12" y1="15" x2="12" y2="3"/>
																</svg>
															</button>
														</div>
													</div>
												{:else}
													<div class="attachment-file-container">
														<div class="file-icon">
															<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																<path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"/>
															</svg>
														</div>
														<div class="attachment-info">
															<span class="attachment-filename">{attachment.fileName}</span>
															<button 
																class="download-btn"
																on:click={() => downloadFile(attachment)}
																title="Download {attachment.fileName}"
															>
																<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																	<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
																	<polyline points="7,10 12,15 17,10"/>
																	<line x1="12" y1="15" x2="12" y2="3"/>
																</svg>
															</button>
														</div>
													</div>
												{/if}
											</div>
										{/each}
									</div>
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
				
				<!-- Load More Indicator -->
				{#if isLoadingMore}
					<div class="loading-more">
						<div class="spinner"></div>
						<p>Loading more notifications...</p>
					</div>
				{/if}
				
				{#if !hasMoreNotifications && filteredNotifications.length > 0}
					<div class="end-message">
						<p>✓ All notifications loaded</p>
					</div>
				{/if}
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

	.action-header {
		padding: 1rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
		margin-bottom: 0.5rem;
	}

	.create-notification-btn {
		width: 100%;
		background: linear-gradient(135deg, #10B981, #059669);
		color: white;
		border: none;
		border-radius: 12px;
		padding: 14px 20px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 10px;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.25);
	}

	.create-notification-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 20px rgba(16, 185, 129, 0.4);
	}

	.create-notification-btn:active {
		transform: translateY(0);
	}

	.create-notification-btn .btn-icon {
		font-size: 18px;
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

	.action-row {
		margin-top: 0.75rem;
		display: flex;
		justify-content: center;
	}

	.mark-all-read-btn {
		background: #10B981;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 0.75rem 1.5rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.25);
	}

	.mark-all-read-btn:hover {
		background: #059669;
		transform: translateY(-2px);
		box-shadow: 0 4px 16px rgba(16, 185, 129, 0.4);
	}

	.mark-all-read-btn:active {
		transform: translateY(0);
	}

	.swipe-hint {
		text-align: center;
		font-size: 0.75rem;
		color: #6B7280;
		margin-top: 0.5rem;
		padding: 0.5rem;
		background: #F9FAFB;
		border-radius: 6px;
		border: 1px solid #E5E7EB;
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
		touch-action: pan-y; /* Allow vertical scrolling but handle horizontal swipes */
		position: relative;
	}

	.notification-item.unread {
		border-left: 4px solid #10B981;
		background: linear-gradient(135deg, #ffffff 0%, #f0fdf4 100%);
	}

	.notification-item.read {
		opacity: 0.8;
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

	.attachments-grid {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.attachment-item {
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		overflow: hidden;
	}

	.attachment-image-container {
		position: relative;
		display: flex;
		align-items: center;
		gap: 0.80rem;
		padding: 0.75rem;
	}

	.attachment-image-preview {
		width: 80px;
		height: 80px;
		object-fit: cover;
		border-radius: 6px;
		cursor: pointer;
		transition: transform 0.2s ease;
		flex-shrink: 0;
	}

	.attachment-image-preview:hover {
		transform: scale(1.05);
	}

	.attachment-file-container {
		display: flex;
		align-items: center;
		gap: 0.80rem;
		padding: 0.75rem;
	}

	.file-icon {
		width: 80px;
		height: 80px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #E5E7EB;
		border-radius: 6px;
		color: #6B7280;
		flex-shrink: 0;
	}

	.attachment-info {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		min-width: 0;
	}

	.attachment-filename {
		flex: 1;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.download-btn {
		background: #10B981;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.5rem;
		cursor: pointer;
		transition: background 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.download-btn:hover {
		background: #059669;
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

	/* Loading More Indicator */
	.loading-more {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		gap: 0.5rem;
	}

	.loading-more .spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.loading-more p {
		font-size: 0.875rem;
		color: #6B7280;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.end-message {
		text-align: center;
		padding: 2rem 1rem;
		color: #6B7280;
		font-size: 0.875rem;
	}

	.end-message p {
		margin: 0;
		opacity: 0.7;
	}
</style>

