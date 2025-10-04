<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { db } from '$lib/utils/supabase';
	import CreateNotification from './CreateNotification.svelte';
	import AdminReadStatusModal from './AdminReadStatusModal.svelte';
	import TaskCompletionModal from '../tasks/TaskCompletionModal.svelte';

	// Current user for role-based access
	$: userRole = $currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Notification data from API
	let allNotifications: any[] = [];
	let isLoading = true;
	let errorMessage = '';

	// Image modal
	let showImageModal = false;
	let selectedImageUrl = '';

	// Convert API response to component format and load task images
	async function transformNotificationData(apiNotifications: any[]) {
		const transformedNotifications = [];
		
		for (const notification of apiNotifications) {
		const transformed = {
			id: notification.id,
			title: notification.title,
			message: notification.message,
			type: notification.type,
			timestamp: formatTimestamp(notification.created_at),
			read: notification.is_read || false, // Use is_read from notification_read_states
			priority: notification.priority,
			createdBy: notification.created_by_name,
			targetUsers: notification.target_type,
			targetBranch: 'all', // Simplified for now
			status: notification.status,
			readCount: notification.read_count,
			totalRecipients: notification.total_recipients,
			metadata: notification.metadata,
			image_url: null
		};			// Load task image if this is a task-related notification
			if (notification.metadata && notification.metadata.task_id) {
				try {
					console.log(`🖼️ [Notification] Loading image for task ${notification.metadata.task_id}`);
					const imageResult = await db.taskImages.getByTaskId(notification.metadata.task_id);
					
					if (imageResult.data && imageResult.data.length > 0) {
						transformed.image_url = imageResult.data[0].file_url;
						console.log(`✅ [Notification] Found image for task ${notification.metadata.task_id}: ${transformed.image_url}`);
					} else {
						console.log(`📭 [Notification] No image found for task ${notification.metadata.task_id}`);
					}
				} catch (error) {
					console.warn(`❌ [Notification] Failed to load image for task ${notification.metadata.task_id}:`, error);
				}
			}
			
			transformedNotifications.push(transformed);
		}
		
		return transformedNotifications;
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
			
			console.log('🔍 [NotificationCenter] Loading notifications...');
			console.log('🔍 [NotificationCenter] Current user:', currentUser);
			console.log('🔍 [NotificationCenter] User role:', userRole);
			console.log('🔍 [NotificationCenter] Is admin or master:', isAdminOrMaster);
			
			if (isAdminOrMaster) {
				// Admin users can see all notifications with their read states
				console.log('🔍 [NotificationCenter] Loading all notifications for admin user');
				const apiNotifications = await notificationManagement.getAllNotifications(currentUser?.id || 'default-user');
				console.log('🔍 [NotificationCenter] Raw API notifications:', apiNotifications);
				allNotifications = await transformNotificationData(apiNotifications);
				console.log('🔍 [NotificationCenter] Transformed notifications:', allNotifications);
			} else if ($currentUser?.id) {
				// Regular users see only their targeted notifications
				console.log('🔍 [NotificationCenter] Loading user-specific notifications');
				const userNotifications = await notificationManagement.getUserNotifications($currentUser.id);
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
			}
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
			// Clear the current notifications array
			allNotifications = [];
			isLoading = true;
			errorMessage = '';
			
			// Add cache-busting parameter to force fresh data
			const timestamp = Date.now();
			console.log('🔄 [NotificationCenter] Force refreshing notifications at:', new Date().toISOString());
			
			// Force clear any browser cache by adding timestamp to requests
			if (isAdminOrMaster) {
				// Force fresh data by bypassing any cache
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
					timestamp: notification.created_at,
					createdBy: notification.created_by_name,
					attachments: notification.attachments || []
				}));
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
		if (!$currentUser?.id) return;
		
		try {
			const result = await notificationManagement.markAsRead(id, $currentUser.id);
			if (result.success) {
				// Update local state
				allNotifications = allNotifications.map(n => 
					n.id === id ? { ...n, read: true } : n
				);
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

	function openCreateNotification() {
		const windowId = `create-notification-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
		
		windowManager.openWindow({
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
		
		windowManager.openWindow({
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
		
		windowManager.openWindow({
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

	// Refresh notifications periodically
	onMount(() => {
		const interval = setInterval(() => {
			loadNotifications();
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
							
							<!-- Task Image Display -->
							{#if notification.image_url}
								<div class="notification-image">
									<button
										on:click={() => openImageModal(notification.image_url)}
										class="image-thumbnail"
										title="Click to view full image"
									>
										<img
											src={notification.image_url}
											alt="Task image"
											class="notification-img"
											loading="lazy"
											on:error={(e) => {
												console.warn(`Failed to load notification image: ${notification.image_url}`);
												e.target.parentElement.style.display = 'none';
											}}
										/>
									</button>
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
	.notification-image {
		margin-top: 12px;
		padding-left: 32px;
	}

	.image-thumbnail {
		border: none;
		background: none;
		padding: 0;
		cursor: pointer;
		border-radius: 8px;
		overflow: hidden;
		transition: transform 0.2s ease, box-shadow 0.2s ease;
	}

	.image-thumbnail:hover {
		transform: scale(1.02);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.notification-img {
		width: 80px;
		height: 80px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
		transition: border-color 0.2s ease;
	}

	.notification-img:hover {
		border-color: #6366f1;
	}
</style>