<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

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

	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			await loadDashboardData();
		}
		isLoading = false;
	});

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
					t.status === 'pending' || t.status === 'in_progress'
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
			const { data: notifications, error: notificationError } = await supabase
				.from('notification_recipients')
				.select(`
					*,
					notification:notifications!inner(
						id,
						title,
						message,
						type,
						priority,
						created_at
					)
				`)
				.eq('recipient_id', currentUserData.id)
				.order('created_at', { ascending: false });

			if (!notificationError && notifications) {
				stats.unreadNotifications = notifications.filter(n => !n.read_at).length;
				
				// Get recent notifications (last 5)
				recentNotifications = notifications.slice(0, 5).map(recipient => ({
					...recipient.notification,
					read_at: recipient.read_at,
					recipient_id: recipient.id
				}));
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
			case 'pending': return '#3B82F6';
			case 'in_progress': return '#F59E0B';
			case 'completed': return '#10B981';
			case 'cancelled': return '#EF4444';
			default: return '#6B7280';
		}
	}

	function logout() {
		localStorage.removeItem('aqura-interface-preference');
		goto('/login');
	}
</script>

<svelte:head>
	<title>Dashboard - Aqura Mobile</title>
</svelte:head>

<div class="mobile-dashboard">
	<!-- Header -->
	<header class="mobile-header">
		<div class="header-content">
			<div class="user-info">
				<div class="user-avatar">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
						<circle cx="12" cy="7" r="4"/>
					</svg>
				</div>
				<div class="user-details">
					<h1>Welcome back!</h1>
					<p>{currentUserData?.name || currentUserData?.username || 'User'}</p>
				</div>
			</div>
			<div class="header-actions">
				<button class="logout-btn" on:click={logout}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
						<polyline points="16,17 21,12 16,7"/>
						<line x1="21" y1="12" x2="9" y2="12"/>
					</svg>
				</button>
			</div>
		</div>
	</header>

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

				<div class="stat-card notifications">
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

		<!-- Quick Actions -->
		<section class="actions-section">
			<h2>Quick Actions</h2>
			<div class="actions-grid">
				<button class="action-btn primary" on:click={() => goto('/mobile/tasks')}>
					<div class="action-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
							<rect x="9" y="7" width="6" height="5"/>
						</svg>
					</div>
					<span>My Tasks</span>
				</button>

				<button class="action-btn secondary" on:click={() => goto('/mobile/tasks/create')}>
					<div class="action-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<line x1="12" y1="8" x2="12" y2="16"/>
							<line x1="8" y1="12" x2="16" y2="12"/>
						</svg>
					</div>
					<span>Create Task</span>
				</button>

				<button class="action-btn accent" on:click={() => goto('/mobile/notifications')}>
					<div class="action-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
							<path d="M13.73 21a2 2 0 0 1-3.46 0"/>
						</svg>
					</div>
					<span>Notifications</span>
				</button>

				<button class="action-btn success" on:click={() => goto('/mobile/notifications/create')}>
					<div class="action-icon">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M12 2L2 7v10c0 5.55 3.84 9.74 9 11 5.16-1.26 9-5.45 9-11V7l-10-5z"/>
							<line x1="9" y1="12" x2="15" y2="12"/>
							<line x1="12" y1="9" x2="12" y2="15"/>
						</svg>
					</div>
					<span>Send Alert</span>
				</button>
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
									{task.assignment_status?.replace('_', ' ').toUpperCase()}
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
						<div class="notification-card" class:unread={!notification.read_at} on:click={() => goto(`/mobile/notifications/${notification.id}`)}>
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

<style>
	.mobile-dashboard {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	/* Header */
	.mobile-header {
		background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%);
		color: white;
		padding: 1rem 1.5rem;
		padding-top: calc(1rem + env(safe-area-inset-top));
		box-shadow: 0 2px 10px rgba(59, 130, 246, 0.2);
	}

	.header-content {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.user-info {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.user-avatar {
		width: 48px;
		height: 48px;
		background: rgba(255, 255, 255, 0.2);
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		backdrop-filter: blur(10px);
	}

	.user-details h1 {
		font-size: 1.25rem;
		font-weight: 600;
		margin: 0 0 0.25rem 0;
	}

	.user-details p {
		font-size: 0.875rem;
		opacity: 0.8;
		margin: 0;
	}

	.logout-btn {
		width: 40px;
		height: 40px;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 10px;
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		backdrop-filter: blur(10px);
	}

	.logout-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
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
		padding: 1.5rem;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.stat-card {
		background: white;
		border-radius: 16px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		align-items: center;
		gap: 1rem;
		transition: all 0.3s ease;
	}

	.stat-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.stat-icon {
		width: 48px;
		height: 48px;
		border-radius: 12px;
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

	.stat-card.total .stat-icon {
		background: rgba(107, 114, 128, 0.1);
		color: #6B7280;
	}

	.stat-info h3 {
		font-size: 2rem;
		font-weight: 700;
		margin: 0 0 0.25rem 0;
		color: #1F2937;
	}

	.stat-info p {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0;
	}

	/* Actions Section */
	.actions-section {
		padding: 0 1.5rem 1.5rem;
	}

	.actions-section h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 1rem 0;
	}

	.actions-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 1rem;
	}

	.action-btn {
		background: white;
		border: none;
		border-radius: 16px;
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
		text-align: center;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		touch-action: manipulation;
		color: #374151;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.action-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.action-icon {
		width: 48px;
		height: 48px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.action-btn.primary .action-icon {
		background: rgba(59, 130, 246, 0.1);
		color: #3B82F6;
	}

	.action-btn.secondary .action-icon {
		background: rgba(99, 102, 241, 0.1);
		color: #6366F1;
	}

	.action-btn.accent .action-icon {
		background: rgba(245, 158, 11, 0.1);
		color: #F59E0B;
	}

	.action-btn.success .action-icon {
		background: rgba(16, 185, 129, 0.1);
		color: #10B981;
	}

	/* Recent Sections */
	.recent-section {
		padding: 0 1.5rem 1.5rem;
	}

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1rem;
	}

	.section-header h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
	}

	.view-all-btn {
		background: none;
		border: none;
		color: #3B82F6;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 6px;
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
		gap: 0.75rem;
	}

	.task-card {
		background: white;
		border-radius: 12px;
		padding: 1rem;
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
		margin-bottom: 0.5rem;
		gap: 0.75rem;
	}

	.task-header h3 {
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
		flex: 1;
		line-height: 1.4;
	}

	.task-priority {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 6px;
		text-transform: uppercase;
		flex-shrink: 0;
	}

	.task-description {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0 0 0.75rem 0;
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
		.actions-section,
		.recent-section {
			padding-left: 1rem;
			padding-right: 1rem;
		}

		.stat-card,
		.action-btn {
			padding: 1rem;
		}

		.stat-icon,
		.action-icon {
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
</style>