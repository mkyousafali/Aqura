<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { auth } from '$lib/stores/auth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import CreateNotification from './CreateNotification.svelte';
	import AdminReadStatusModal from './AdminReadStatusModal.svelte';

	// Current user for role-based access
	$: currentUser = $auth?.user;
	$: userRole = currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Notification data from API
	let allNotifications: any[] = [];
	let isLoading = true;
	let errorMessage = '';

	// Convert API response to component format
	function transformNotificationData(apiNotifications: any[]) {
		return apiNotifications.map(notification => ({
			id: notification.id,
			title: notification.title,
			message: notification.message,
			type: notification.type,
			timestamp: formatTimestamp(notification.created_at),
			read: notification.is_read_by_user || false, // Use per-user read state
			priority: notification.priority,
			createdBy: notification.created_by_name,
			targetUsers: notification.target_type,
			targetBranch: 'all', // Simplified for now
			status: notification.status,
			readCount: notification.read_count,
			totalRecipients: notification.total_recipients
		}));
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
			
			if (isAdminOrMaster) {
				// Admin users can see all notifications with their read states
				const apiNotifications = await notificationManagement.getAllNotifications(currentUser?.id || 'default-user');
				allNotifications = transformNotificationData(apiNotifications);
			} else if (currentUser?.id) {
				// Regular users see only their targeted notifications
				const userNotifications = await notificationManagement.getUserNotifications(currentUser.id);
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
		if (!currentUser?.id) return;
		
		try {
			const result = await notificationManagement.markAsRead(id, currentUser.id);
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
		if (!currentUser?.id) return;
		
		try {
			const result = await notificationManagement.markAllAsRead(currentUser.id);
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
			{/if}
			{#if userRole === 'Master Admin'}
				<button class="admin-status-btn" on:click={openAdminReadStatus}>
					<span class="icon">👥</span>
					Read Status
				</button>
			{/if}
			<button class="refresh-btn" on:click={loadNotifications} disabled={isLoading}>
				<span class="icon">🔄</span>
				Refresh
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
					<div class="notification-item {notification.read ? 'read' : 'unread'} {getPriorityColor(notification.priority)}">
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

	.admin-status-btn {
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

	.admin-status-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.admin-status-btn .icon {
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
</style>