<script lang="ts">
	import { onMount } from 'svelte';
	import { notificationManagement } from '$lib/utils/notificationManagement';

	// Data structures for admin read status
	let readStatusData: any[] = [];
	let notifications: any[] = [];
	let users: any[] = [];
	let isLoading = true;
	let errorMessage = '';

	// Filters
	let selectedNotification = 'all';
	let selectedUser = 'all';
	let searchTerm = '';

	// Load data on mount
	onMount(async () => {
		await loadReadStatusData();
	});

	async function loadReadStatusData() {
		try {
			isLoading = true;
			errorMessage = '';
			
			// Load the admin read status data from the backend
			const data = await notificationManagement.getAdminReadStatus();
			readStatusData = data.readStates || [];
			notifications = data.notifications || [];
			users = data.users || [];
			
		} catch (error) {
			console.error('Error loading read status data:', error);
			errorMessage = 'Failed to load read status data. Please try again.';
		} finally {
			isLoading = false;
		}
	}

	// Computed filtered data
	$: filteredData = readStatusData.filter(item => {
		if (selectedNotification !== 'all' && item.notification_id !== selectedNotification) return false;
		
		// Fix user filtering to match both user ID and username
		if (selectedUser !== 'all') {
			const matchingUser = users.find(u => u.id === selectedUser);
			if (matchingUser && item.user_id !== matchingUser.id && item.user_id !== matchingUser.username) {
				return false;
			}
		}
		
		if (searchTerm && !item.notification?.title?.toLowerCase().includes(searchTerm.toLowerCase()) && 
		    !item.display_name?.toLowerCase().includes(searchTerm.toLowerCase()) &&
		    !item.user_id?.toLowerCase().includes(searchTerm.toLowerCase())) return false;
		return true;
	});

	// Group data by notification
	$: groupedByNotification = notifications.map(notification => {
		const readStates = filteredData.filter(item => item.notification_id === notification.id);
		const readCount = readStates.length;
		const totalUsers = users.length;
		const unreadCount = totalUsers - readCount;
		
		return {
			...notification,
			readStates,
			readCount,
			totalUsers,
			unreadCount,
			readPercentage: totalUsers > 0 ? Math.round((readCount / totalUsers) * 100) : 0
		};
	}).filter(notification => 
		selectedNotification === 'all' || notification.id === selectedNotification
	);

	// Group data by user
	$: groupedByUser = users.map(user => {
		const userReadStates = filteredData.filter(item => item.user_id === user.id || item.user_id === user.username);
		const readCount = userReadStates.length;
		const totalNotifications = notifications.length;
		const unreadCount = totalNotifications - readCount;
		
		// Get display name from read states or fallback to user data
		const displayName = userReadStates[0]?.display_name || 
		                   (user.hr_employees?.[0]?.name) || 
		                   user.username || 
		                   user.id;
		
		// Create unread notifications list
		const readNotificationIds = userReadStates.map(state => state.notification_id);
		const unreadNotifications = notifications
			.filter(notification => notification && !readNotificationIds.includes(notification.id))
			.map(notification => ({
				notification_id: notification.id,
				notification: {
					title: notification.title,
					type: notification.type,
					priority: notification.priority,
					created_at: notification.created_at
				},
				user_id: user.id,
				is_read: false,
				read_at: null,
				created_at: notification.created_at
			}));
		
		// Combine read and unread notifications
		const allNotifications = [
			...userReadStates.map(state => ({ ...state, is_read: true })),
			...unreadNotifications
		].sort((a, b) => {
			// Safe date extraction with fallbacks
			const dateA = a.notification?.created_at || a.created_at || a.read_at || new Date().toISOString();
			const dateB = b.notification?.created_at || b.created_at || b.read_at || new Date().toISOString();
			return new Date(dateB) - new Date(dateA);
		});
		
		return {
			...user,
			name: displayName, // Override the name with display name
			readStates: userReadStates,
			allNotifications: allNotifications, // Both read and unread
			readCount,
			totalNotifications,
			unreadCount,
			readPercentage: totalNotifications > 0 ? Math.round((readCount / totalNotifications) * 100) : 0
		};
	}).filter(user => 
		selectedUser === 'all' || user.id === selectedUser
	);

	let viewMode = 'by-notification'; // 'by-notification' or 'by-user'

	function formatTimestamp(isoString: string): string {
		if (!isoString) return 'Never';
		const date = new Date(isoString);
		return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
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

	function getReadStatusColor(percentage: number): string {
		if (percentage >= 80) return 'text-green-600';
		if (percentage >= 50) return 'text-yellow-600';
		return 'text-red-600';
	}
</script>

<div class="admin-read-status">
	<!-- Header -->
	<div class="header">
		<h2 class="title">📊 Notification Read Status - Admin View</h2>
		<button class="refresh-btn" on:click={loadReadStatusData} disabled={isLoading}>
			<span class="icon">🔄</span>
			Refresh
		</button>
	</div>

	<!-- Error Message -->
	{#if errorMessage}
		<div class="error-banner">
			<span class="error-icon">❌</span>
			{errorMessage}
			<button class="retry-btn" on:click={loadReadStatusData}>Retry</button>
		</div>
	{/if}

	<!-- Loading State -->
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading read status data...</p>
		</div>
	{:else}
		<!-- Controls -->
		<div class="controls">
			<div class="view-toggle">
				<button 
					class="toggle-btn {viewMode === 'by-notification' ? 'active' : ''}"
					on:click={() => viewMode = 'by-notification'}
				>
					📢 By Notification
				</button>
				<button 
					class="toggle-btn {viewMode === 'by-user' ? 'active' : ''}"
					on:click={() => viewMode = 'by-user'}
				>
					👤 By User
				</button>
			</div>

			<div class="filters">
				<select bind:value={selectedNotification} class="filter-select">
					<option value="all">All Notifications</option>
					{#each notifications as notification}
						<option value={notification.id}>{notification.title}</option>
					{/each}
				</select>

				<select bind:value={selectedUser} class="filter-select">
					<option value="all">All Users</option>
					{#each users as user}
						<option value={user.id}>
							{user.hr_employees?.[0]?.name || user.username || user.id}
						</option>
					{/each}
				</select>

				<input 
					type="text" 
					placeholder="Search..." 
					bind:value={searchTerm}
					class="search-input"
				>
			</div>
		</div>

		<!-- Content -->
		<div class="content">
			{#if viewMode === 'by-notification'}
				<!-- By Notification View -->
				<div class="notification-groups">
					{#each groupedByNotification as notificationGroup}
						<div class="notification-group">
							<div class="notification-header">
								<div class="notification-info">
									<span class="notification-icon">{getNotificationIcon(notificationGroup.type)}</span>
									<div>
										<h3 class="notification-title">{notificationGroup.title}</h3>
										<p class="notification-meta">
											Created: {formatTimestamp(notificationGroup.created_at)} • 
											Type: {notificationGroup.type} • 
											Priority: {notificationGroup.priority}
										</p>
									</div>
								</div>
								<div class="read-stats">
									<div class="stat">
										<span class="stat-number {getReadStatusColor(notificationGroup.readPercentage)}">
											{notificationGroup.readPercentage}%
										</span>
										<span class="stat-label">Read Rate</span>
									</div>
									<div class="stat">
										<span class="stat-number text-green-600">{notificationGroup.readCount}</span>
										<span class="stat-label">Read</span>
									</div>
									<div class="stat">
										<span class="stat-number text-red-600">{notificationGroup.unreadCount}</span>
										<span class="stat-label">Unread</span>
									</div>
								</div>
							</div>

							{#if notificationGroup.readStates.length > 0}
								<div class="read-details">
									<h4 class="details-title">Users who read this notification:</h4>
									<div class="read-list">
										{#each notificationGroup.readStates as readState}
											<div class="read-item">
												<span class="user-id">{readState.display_name || readState.user_name || readState.user_id}</span>
												<span class="read-time">{formatTimestamp(readState.read_at)}</span>
											</div>
										{/each}
									</div>
								</div>
							{/if}
						</div>
					{/each}
				</div>
			{:else}
				<!-- By User View -->
				<div class="user-groups">
					{#each groupedByUser as userGroup}
						<div class="user-group">
							<div class="user-header">
								<div class="user-info">
									<span class="user-icon">👤</span>
									<div>
										<h3 class="user-name">{userGroup.name}</h3>
										<p class="user-meta">User ID: {userGroup.id}</p>
									</div>
								</div>
								<div class="read-stats">
									<div class="stat">
										<span class="stat-number {getReadStatusColor(userGroup.readPercentage)}">
											{userGroup.readPercentage}%
										</span>
										<span class="stat-label">Read Rate</span>
									</div>
									<div class="stat">
										<span class="stat-number text-green-600">{userGroup.readCount}</span>
										<span class="stat-label">Read</span>
									</div>
									<div class="stat">
										<span class="stat-number text-red-600">{userGroup.unreadCount}</span>
										<span class="stat-label">Unread</span>
									</div>
								</div>
							</div>

							{#if userGroup.allNotifications.length > 0}
								<div class="notification-details">
									<h4 class="details-title">All Notifications for this user:</h4>
									<div class="notification-list">
										{#each userGroup.allNotifications as notification}
											<div class="notification-item {notification.is_read ? 'read' : 'unread'}">
												<div class="notification-content">
													<span class="notification-title">{notification.notification?.title || 'Unknown Notification'}</span>
													<span class="notification-type">{notification.notification?.type || ''}</span>
												</div>
												<div class="notification-status">
													{#if notification.is_read}
														<span class="status-badge read">✓ Read</span>
														<span class="read-time">{formatTimestamp(notification.read_at)}</span>
													{:else}
														<span class="status-badge unread">⚪ Unread</span>
														<span class="created-time">{formatTimestamp(notification.notification?.created_at)}</span>
													{/if}
												</div>
											</div>
										{/each}
									</div>
								</div>
							{/if}
						</div>
					{/each}
				</div>
			{/if}

			{#if (viewMode === 'by-notification' ? groupedByNotification : groupedByUser).length === 0}
				<div class="empty-state">
					<div class="empty-icon">📊</div>
					<h3>No data available</h3>
					<p>No read status data matches your current filters.</p>
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.admin-read-status {
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
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0;
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
		border-top: 3px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.controls {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 20px;
		margin-bottom: 20px;
		padding: 16px;
		background: #f9fafb;
		border-radius: 8px;
	}

	.view-toggle {
		display: flex;
		gap: 4px;
		background: white;
		border-radius: 6px;
		padding: 4px;
		border: 1px solid #e5e7eb;
	}

	.toggle-btn {
		background: none;
		border: none;
		padding: 8px 16px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		color: #6b7280;
		transition: all 0.2s;
	}

	.toggle-btn.active {
		background: #3b82f6;
		color: white;
	}

	.toggle-btn:not(.active):hover {
		background: #f3f4f6;
		color: #374151;
	}

	.filters {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.filter-select {
		padding: 6px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		color: #374151;
		min-width: 150px;
	}

	.search-input {
		padding: 6px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		color: #374151;
		min-width: 200px;
	}

	.content {
		flex: 1;
		overflow-y: auto;
		padding-right: 8px;
	}

	.notification-groups, .user-groups {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.notification-group, .user-group {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
	}

	.notification-header, .user-header {
		padding: 16px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.notification-info, .user-info {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.notification-icon, .user-icon {
		font-size: 20px;
	}

	.notification-title, .user-name {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.notification-meta, .user-meta {
		font-size: 12px;
		color: #6b7280;
		margin: 0;
	}

	.read-stats {
		display: flex;
		gap: 20px;
		align-items: center;
	}

	.stat {
		text-align: center;
	}

	.stat-number {
		display: block;
		font-size: 18px;
		font-weight: 700;
	}

	.stat-label {
		display: block;
		font-size: 12px;
		color: #6b7280;
		font-weight: 500;
	}

	.text-green-600 { color: #10b981; }
	.text-yellow-600 { color: #f59e0b; }
	.text-red-600 { color: #ef4444; }

	.read-details {
		padding: 16px;
	}

	.details-title {
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 12px 0;
	}

	.read-list {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.read-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 12px;
		background: #f9fafb;
		border-radius: 4px;
		font-size: 14px;
	}

	/* New notification item styles */
	.notification-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		border-radius: 6px;
		font-size: 14px;
		border-left: 4px solid;
	}

	.notification-item.read {
		background: #f0f9ff;
		border-left-color: #22c55e;
	}

	.notification-item.unread {
		background: #fef3f2;
		border-left-color: #ef4444;
	}

	.notification-content {
		display: flex;
		flex-direction: column;
		gap: 4px;
		flex: 1;
	}

	.notification-type {
		font-size: 12px;
		color: #6b7280;
		text-transform: capitalize;
	}

	.notification-status {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 2px;
	}

	.status-badge {
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 500;
	}

	.status-badge.read {
		background: #dcfce7;
		color: #166534;
	}

	.status-badge.unread {
		background: #fecaca;
		color: #991b1b;
	}

	.created-time {
		font-size: 11px;
		color: #6b7280;
	}

	.user-id, .notification-title {
		font-weight: 500;
		color: #374151;
	}

	.read-time {
		font-size: 12px;
		color: #6b7280;
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

	/* Scrollbar styling */
	.content::-webkit-scrollbar {
		width: 6px;
	}

	.content::-webkit-scrollbar-track {
		background: #f1f5f9;
		border-radius: 3px;
	}

	.content::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 3px;
	}

	.content::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}
</style>