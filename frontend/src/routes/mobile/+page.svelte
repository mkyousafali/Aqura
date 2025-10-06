<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';
	import { supabase } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import CreateNotification from '$lib/components/admin/communication/CreateNotification.svelte';

	let currentUserData = null;
	let stats = {
		pendingTasks: 0,
		completedTasks: 0,
		unreadNotifications: 0,
		totalTasks: 0
	};
	let recentTasks = [];
	let recentNotifications = [];
	let isLoading = true;
	
	// Create notification modal
	let showCreateNotificationModal = false;
	
	// Computed role check
	$: userRole = currentUserData?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Reactive refresh when returning to dashboard
	$: if ($page.url.pathname === '/mobile' && currentUserData) {
		refreshNotificationCount();
	}

	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			await loadDashboardData();
		}
		isLoading = false;
		
		// Set up automatic refresh for notification count every 30 seconds
		const refreshInterval = setInterval(async () => {
			if (currentUserData) {
				await refreshNotificationCount();
			}
		}, 30000);
		
		// Refresh when page becomes visible (user returns to dashboard)
		const handleVisibilityChange = async () => {
			if (!document.hidden && currentUserData) {
				await refreshNotificationCount();
			}
		};
		
		document.addEventListener('visibilitychange', handleVisibilityChange);
		
		// Cleanup on component destroy
		return () => {
			clearInterval(refreshInterval);
			document.removeEventListener('visibilitychange', handleVisibilityChange);
		};
	});

	async function refreshNotificationCount() {
		try {
			const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
			if (userNotifications && userNotifications.length > 0) {
				stats.unreadNotifications = userNotifications.filter(n => !n.is_read).length;
			} else {
				stats.unreadNotifications = 0;
			}
		} catch (error) {
			console.error('Error refreshing notification count:', error);
		}
	}

	async function loadDashboardData() {
		try {
			// Load task statistics
			const { data: taskAssignments, error: taskError } = await supabase
				.from('task_assignments')
				.select(`
					*,
					task:tasks!inner(
						id,
						title,
						description,
						priority,
						due_date,
						status,
						created_at
					)
				`)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('assigned_at', { ascending: false });

			if (!taskError && taskAssignments) {
				stats.totalTasks = taskAssignments.length;
				stats.pendingTasks = taskAssignments.filter(t => 
					t.status === 'assigned' || t.status === 'in_progress'
				).length;
				stats.completedTasks = taskAssignments.filter(t => 
					t.status === 'completed'
				).length;
				
				// Get recent tasks (last 5)
				recentTasks = taskAssignments.slice(0, 5).map(assignment => ({
					...assignment.task,
					assignment_status: assignment.status,
					assignment_id: assignment.id,
					assigned_at: assignment.assigned_at
				}));
			}

			// Load notification statistics
			try {
				const userNotifications = await notificationManagement.getUserNotifications(currentUserData.id);
				console.log('📱 [Mobile Dashboard] Loaded notifications:', userNotifications);
				
				if (userNotifications && userNotifications.length > 0) {
					// Count unread notifications
					stats.unreadNotifications = userNotifications.filter(n => !n.is_read).length;
					
					// Get recent notifications (last 5)
					recentNotifications = userNotifications.slice(0, 5).map(notification => ({
						id: notification.notification_id,
						title: notification.title,
						message: notification.message,
						type: notification.type,
						read_at: notification.is_read ? notification.created_at : null,
						created_at: notification.created_at
					}));
					
					console.log('📊 [Mobile Dashboard] Unread count:', stats.unreadNotifications);
				} else {
					stats.unreadNotifications = 0;
					recentNotifications = [];
				}
			} catch (error) {
				console.error('❌ [Mobile Dashboard] Error loading notifications:', error);
				stats.unreadNotifications = 0;
				recentNotifications = [];
			}

		} catch (error) {
			console.error('Error loading dashboard data:', error);
		}
	}

	function formatDate(dateString) {
		if (!dateString) return '';
		const date = new Date(dateString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
		
		if (diffHours < 1) {
			const diffMinutes = Math.floor(diffMs / (1000 * 60));
			return diffMinutes < 1 ? 'Just now' : `${diffMinutes}m ago`;
		} else if (diffHours < 24) {
			return `${diffHours}h ago`;
		} else {
			const diffDays = Math.floor(diffHours / 24);
			return diffDays === 1 ? 'Yesterday' : `${diffDays}d ago`;
		}
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return '#EF4444';
			case 'medium': return '#F59E0B';
			case 'low': return '#10B981';
			default: return '#6B7280';
		}
	}

	function getStatusColor(status) {
		switch (status) {
			case 'assigned': return '#3B82F6';
			case 'in_progress': return '#F59E0B';
			case 'completed': return '#10B981';
			case 'cancelled': return '#EF4444';
			default: return '#6B7280';
		}
	}

	function getStatusDisplayText(status) {
		switch (status) {
			case 'assigned': return 'PENDING';
			case 'in_progress': return 'IN PROGRESS';
			case 'completed': return 'COMPLETED';
			case 'cancelled': return 'CANCELLED';
			case 'escalated': return 'ESCALATED';
			case 'reassigned': return 'REASSIGNED';
			default: return status?.replace('_', ' ').toUpperCase() || 'UNKNOWN';
		}
	}

	function logout() {
		// Clear interface preference to allow user to choose again
		interfacePreferenceService.clearPreference(currentUserData?.id);
		
		// Logout from persistent auth service
		persistentAuthService.logout().then(() => {
			// Redirect to login page to choose interface again
			goto('/login');
		}).catch((error) => {
			console.error('Logout error:', error);
			// Still redirect even if logout fails
			goto('/login');
		});
	}

	function openCreateNotification() {
		showCreateNotificationModal = true;
	}

	function closeCreateNotification() {
		showCreateNotificationModal = false;
		// Refresh notifications after creating a new one
		loadDashboardData();
	}
</script>

<svelte:head>
	<title>Dashboard - Aqura Mobile</title>
</svelte:head>

<div class="mobile-dashboard">
	{#if isLoading}
		<div class="loading-content">
			<div class="loading-spinner"></div>
			<p>Loading dashboard...</p>
		</div>
	{:else}
		<!-- Stats Grid -->
		<section class="stats-section">
			<div class="stats-grid">
				<div class="stat-card pending">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<polyline points="12,6 12,12 16,14"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.pendingTasks}</h3>
						<p>Pending Tasks</p>
					</div>
				</div>

				<div class="stat-card completed">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
							<polyline points="22,4 12,14.01 9,11.01"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.completedTasks}</h3>
						<p>Completed</p>
					</div>
				</div>

				<div class="stat-card notifications" on:click={() => goto('/mobile/notifications')} role="button" tabindex="0">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
							<path d="M13.73 21a2 2 0 0 1-3.46 0"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.unreadNotifications}</h3>
						<p>Notifications</p>
					</div>
				</div>

				<div class="stat-card total">
					<div class="stat-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
							<rect x="9" y="7" width="6" height="5"/>
						</svg>
					</div>
					<div class="stat-info">
						<h3>{stats.totalTasks}</h3>
						<p>Total Tasks</p>
					</div>
				</div>
			</div>
		</section>

		<!-- Recent Tasks -->
		{#if recentTasks.length > 0}
			<section class="recent-section">
				<div class="section-header">
					<h2>Recent Tasks</h2>
					<button class="view-all-btn" on:click={() => goto('/mobile/tasks')}>
						View All
					</button>
				</div>
				<div class="task-list">
					{#each recentTasks as task}
						<div class="task-card" on:click={() => goto(`/mobile/tasks/${task.id}`)}>
							<div class="task-header">
								<h3>{task.title}</h3>
								<span class="task-priority" style="background-color: {getPriorityColor(task.priority)}15; color: {getPriorityColor(task.priority)}">
									{task.priority?.toUpperCase()}
								</span>
							</div>
							<p class="task-description">{task.description}</p>
							<div class="task-footer">
								<span class="task-status" style="background-color: {getStatusColor(task.assignment_status)}15; color: {getStatusColor(task.assignment_status)}">
									{getStatusDisplayText(task.assignment_status)}
								</span>
								<span class="task-date">{formatDate(task.assigned_at)}</span>
							</div>
						</div>
					{/each}
				</div>
			</section>
		{/if}

		<!-- Recent Notifications -->
		{#if recentNotifications.length > 0}
			<section class="recent-section">
				<div class="section-header">
					<h2>Recent Notifications</h2>
					<button class="view-all-btn" on:click={() => goto('/mobile/notifications')}>
						View All
					</button>
				</div>
				<div class="notification-list">
					{#each recentNotifications as notification}
						<div class="notification-card" class:unread={!notification.read_at} on:click={() => goto('/mobile/notifications')}>
							<div class="notification-header">
								<h3>{notification.title}</h3>
								{#if !notification.read_at}
									<div class="unread-badge"></div>
								{/if}
							</div>
							<p class="notification-message">{notification.message}</p>
							<div class="notification-footer">
								<span class="notification-type">{notification.type}</span>
								<span class="notification-date">{formatDate(notification.created_at)}</span>
							</div>
						</div>
					{/each}
				</div>
			</section>
		{/if}
	{/if}
</div>

<!-- Create Notification Modal -->
{#if showCreateNotificationModal}
	<div class="modal-overlay">
		<div class="modal-container">
			<div class="modal-header">
				<h2>Create Notification</h2>
				<button class="close-btn" on:click={closeCreateNotification}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
			<div class="modal-content">
				<CreateNotification />
			</div>
		</div>
	</div>
{/if}

<style>
	.mobile-dashboard {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	/* Loading */
	.loading-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		color: #6B7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Stats Section */
	.stats-section {
		padding: 1.2rem; /* Reduced from 1.5rem (20% smaller) */
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 0.8rem; /* Reduced from 1rem (20% smaller) */
	}

	.stat-card {
		background: white;
		border-radius: 13px; /* Reduced from 16px (20% smaller) */
		padding: 1.2rem; /* Reduced from 1.5rem (20% smaller) */
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		align-items: center;
		gap: 0.8rem; /* Reduced from 1rem (20% smaller) */
		transition: all 0.3s ease;
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.stat-icon {
		width: 38px; /* Reduced from 48px (20% smaller) */
		height: 38px; /* Reduced from 48px (20% smaller) */
		border-radius: 10px; /* Reduced from 12px (20% smaller) */
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.stat-card.pending .stat-icon {
		background: rgba(59, 130, 246, 0.1);
		color: #3B82F6;
	}

	.stat-card.completed .stat-icon {
		background: rgba(16, 185, 129, 0.1);
		color: #10B981;
	}

	.stat-card.notifications .stat-icon {
		background: rgba(245, 158, 11, 0.1);
		color: #F59E0B;
	}

	.stat-card.notifications {
		cursor: pointer;
	}

	.stat-card.notifications:hover {
		transform: translateY(-3px);
		box-shadow: 0 6px 16px rgba(245, 158, 11, 0.2);
	}

	.stat-card.notifications:active {
		transform: translateY(-1px);
	}

	.stat-card.total .stat-icon {
		background: rgba(107, 114, 128, 0.1);
		color: #6B7280;
	}

	.stat-info h3 {
		font-size: 1.6rem; /* Reduced from 2rem (20% smaller) */
		font-weight: 700;
		margin: 0 0 0.2rem 0; /* Reduced from 0.25rem */
		color: #1F2937;
	}

	.stat-info p {
		font-size: 0.7rem; /* Reduced from 0.875rem (20% smaller) */
		color: #6B7280;
		margin: 0;
	}

	/* Recent Sections */
	.recent-section {
		padding: 0 1.2rem 1.2rem; /* Reduced from 1.5rem (20% smaller) */
	}

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.8rem; /* Reduced from 1rem (20% smaller) */
	}

	.section-header h2 {
		font-size: 1rem; /* Reduced from 1.25rem (20% smaller) */
		font-weight: 600;
		color: #1F2937;
		margin: 0;
	}

	.view-all-btn {
		background: none;
		border: none;
		color: #3B82F6;
		font-size: 0.7rem; /* Reduced from 0.875rem (20% smaller) */
		font-weight: 500;
		cursor: pointer;
		padding: 0.4rem; /* Reduced from 0.5rem (20% smaller) */
		border-radius: 5px; /* Reduced from 6px */
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.view-all-btn:hover {
		background: rgba(59, 130, 246, 0.1);
	}

	/* Task Cards */
	.task-list {
		display: flex;
		flex-direction: column;
		gap: 0.6rem; /* Reduced from 0.75rem (20% smaller) */
	}

	.task-card {
		background: white;
		border-radius: 10px; /* Reduced from 12px (20% smaller) */
		padding: 0.8rem; /* Reduced from 1rem (20% smaller) */
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.task-card:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.task-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		margin-bottom: 0.4rem; /* Reduced from 0.5rem (20% smaller) */
		gap: 0.6rem; /* Reduced from 0.75rem (20% smaller) */
	}

	.task-header h3 {
		font-size: 0.8rem; /* Reduced from 1rem (20% smaller) */
		font-weight: 600;
		color: #1F2937;
		margin: 0;
		flex: 1;
		line-height: 1.4;
	}

	.task-priority {
		font-size: 0.6rem; /* Reduced from 0.75rem (20% smaller) */
		font-weight: 600;
		padding: 0.2rem 0.4rem; /* Reduced from 0.25rem 0.5rem */
		border-radius: 5px; /* Reduced from 6px */
		text-transform: uppercase;
		flex-shrink: 0;
	}

	.task-description {
		font-size: 0.7rem; /* Reduced from 0.875rem (20% smaller) */
		color: #6B7280;
		margin: 0 0 0.6rem 0; /* Reduced from 0.75rem */
		line-height: 1.4;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.task-footer {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
	}

	.task-status {
		font-size: 0.75rem;
		font-weight: 500;
		padding: 0.25rem 0.5rem;
		border-radius: 6px;
		text-transform: uppercase;
	}

	.task-date {
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	/* Notification Cards */
	.notification-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.notification-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		position: relative;
	}

	.notification-card:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.notification-card.unread {
		border-left: 4px solid #3B82F6;
	}

	.notification-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		margin-bottom: 0.5rem;
		gap: 0.75rem;
	}

	.notification-header h3 {
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
		flex: 1;
		line-height: 1.4;
	}

	.unread-badge {
		width: 8px;
		height: 8px;
		background: #3B82F6;
		border-radius: 50%;
		flex-shrink: 0;
		margin-top: 0.25rem;
	}

	.notification-message {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0 0 0.75rem 0;
		line-height: 1.4;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.notification-footer {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
	}

	.notification-type {
		font-size: 0.75rem;
		font-weight: 500;
		color: #6B7280;
		text-transform: capitalize;
	}

	.notification-date {
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.mobile-header {
			padding: 1rem;
			padding-top: calc(1rem + env(safe-area-inset-top));
		}

		.stats-section,
		.recent-section {
			padding-left: 1rem;
			padding-right: 1rem;
		}

		.stat-card {
			padding: 1rem;
		}

		.stat-icon {
			width: 40px;
			height: 40px;
		}

		.stat-info h3 {
			font-size: 1.5rem;
		}
	}

	/* Safe area handling for iOS */
	@supports (padding: max(0px)) {
		.mobile-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}

	.modal-container {
		background: white;
		border-radius: 12px;
		max-width: 500px;
		width: 100%;
		max-height: 90vh;
		overflow: hidden;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.5rem;
		border-bottom: 1px solid #E5E7EB;
		background: #F9FAFB;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}

	.close-btn {
		background: none;
		border: none;
		padding: 0.5rem;
		cursor: pointer;
		border-radius: 6px;
		color: #6B7280;
		transition: all 0.2s ease;
	}

	.close-btn:hover {
		background: #E5E7EB;
		color: #374151;
	}

	.modal-content {
		padding: 0;
		overflow-y: auto;
		max-height: calc(90vh - 80px);
	}
</style>