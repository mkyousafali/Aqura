<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	let currentUserData = null;
	let tasks = [];
	let filteredTasks = [];
	let isLoading = true;
	let searchTerm = '';
	let filterStatus = 'all';
	let filterPriority = 'all';

	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			await loadTasks();
		}
		isLoading = false;
	});

	async function loadTasks() {
		try {
			const { data: taskAssignments, error } = await supabase
				.from('task_assignments')
				.select(`
					*,
					task:tasks!inner(
						id,
						title,
						description,
						priority,
						due_date,
						due_time,
						status,
						created_at,
						created_by,
						created_by_name
					)
				`)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('assigned_at', { ascending: false });

			if (error) throw error;

			tasks = taskAssignments.map(assignment => ({
				...assignment.task,
				assignment_id: assignment.id,
				assignment_status: assignment.status,
				assigned_at: assignment.assigned_at,
				deadline_date: assignment.deadline_date,
				deadline_time: assignment.deadline_time,
				assigned_by: assignment.assigned_by,
				assigned_by_name: assignment.assigned_by_name
			}));

			filterTasks();
		} catch (error) {
			console.error('Error loading tasks:', error);
		}
	}

	function filterTasks() {
		filteredTasks = tasks.filter(task => {
			const matchesSearch = task.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
				task.description.toLowerCase().includes(searchTerm.toLowerCase());
			
			const matchesStatus = filterStatus === 'all' || task.assignment_status === filterStatus;
			const matchesPriority = filterPriority === 'all' || task.priority === filterPriority;
			
			return matchesSearch && matchesStatus && matchesPriority;
		});
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

	function isOverdue(deadlineDate, deadlineTime) {
		if (!deadlineDate) return false;
		
		const now = new Date();
		const deadline = new Date(deadlineDate);
		
		if (deadlineTime) {
			const [hours, minutes] = deadlineTime.split(':');
			deadline.setHours(parseInt(hours), parseInt(minutes));
		}
		
		return now > deadline;
	}

	async function markAsComplete(task) {
		try {
			// Update assignment status to completed
			const { error } = await supabase
				.from('task_assignments')
				.update({ 
					status: 'completed',
					completed_at: new Date().toISOString()
				})
				.eq('id', task.assignment_id);

			if (error) throw error;

			// Refresh tasks
			await loadTasks();
		} catch (error) {
			console.error('Error marking task as complete:', error);
			alert('Failed to mark task as complete. Please try again.');
		}
	}

	// Reactive filtering
	$: {
		filterTasks();
	}
</script>

<svelte:head>
	<title>My Tasks - Aqura Mobile</title>
</svelte:head>

<div class="mobile-tasks">
	<!-- Header -->
	<header class="page-header">
		<div class="header-content">
			<button class="back-btn" on:click={() => goto('/mobile')}>
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M19 12H5M12 19l-7-7 7-7"/>
				</svg>
			</button>
			<h1>My Tasks</h1>
			<button class="add-btn" on:click={() => goto('/mobile/tasks/create')}>
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="12" y1="5" x2="12" y2="19"/>
					<line x1="5" y1="12" x2="19" y2="12"/>
				</svg>
			</button>
		</div>
	</header>

	<!-- Filters -->
	<div class="filters-section">
		<div class="search-box">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="11" cy="11" r="8"/>
				<path d="M21 21l-4.35-4.35"/>
			</svg>
			<input
				type="text"
				placeholder="Search tasks..."
				bind:value={searchTerm}
				class="search-input"
			/>
		</div>

		<div class="filter-chips">
			<select bind:value={filterStatus} class="filter-select">
				<option value="all">All Status</option>
				<option value="pending">Pending</option>
				<option value="in_progress">In Progress</option>
				<option value="completed">Completed</option>
				<option value="cancelled">Cancelled</option>
			</select>

			<select bind:value={filterPriority} class="filter-select">
				<option value="all">All Priority</option>
				<option value="high">High</option>
				<option value="medium">Medium</option>
				<option value="low">Low</option>
			</select>
		</div>

		<div class="results-count">
			{filteredTasks.length} task{filteredTasks.length !== 1 ? 's' : ''} found
		</div>
	</div>

	<!-- Content -->
	<div class="content-section">
		{#if isLoading}
			<div class="loading-state">
				<div class="loading-spinner"></div>
				<p>Loading tasks...</p>
			</div>
		{:else if filteredTasks.length === 0}
			<div class="empty-state">
				<div class="empty-icon">
					<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
						<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
						<rect x="9" y="7" width="6" height="5"/>
					</svg>
				</div>
				<h2>No tasks found</h2>
				<p>No tasks match your current filters, or you don't have any assigned tasks yet.</p>
				<button class="create-task-btn" on:click={() => goto('/mobile/tasks/create')}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="12" y1="5" x2="12" y2="19"/>
						<line x1="5" y1="12" x2="19" y2="12"/>
					</svg>
					Create New Task
				</button>
			</div>
		{:else}
			<div class="task-list">
				{#each filteredTasks as task (task.assignment_id)}
					<div class="task-card" class:overdue={isOverdue(task.deadline_date, task.deadline_time)}>
						<div class="task-header" on:click={() => goto(`/mobile/tasks/${task.id}`)}>
							<div class="task-title-section">
								<h3>{task.title}</h3>
								<div class="task-meta">
									<span class="task-priority" style="background-color: {getPriorityColor(task.priority)}15; color: {getPriorityColor(task.priority)}">
										{task.priority?.toUpperCase()}
									</span>
									<span class="task-status" style="background-color: {getStatusColor(task.assignment_status)}15; color: {getStatusColor(task.assignment_status)}">
										{task.assignment_status?.replace('_', ' ').toUpperCase()}
									</span>
								</div>
							</div>
							{#if isOverdue(task.deadline_date, task.deadline_time) && task.assignment_status !== 'completed'}
								<div class="overdue-badge">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<line x1="12" y1="8" x2="12" y2="12"/>
										<line x1="12" y1="16" x2="12.01" y2="16"/>
									</svg>
								</div>
							{/if}
						</div>

						<div class="task-content" on:click={() => goto(`/mobile/tasks/${task.id}`)}>
							<p class="task-description">{task.description}</p>
							
							<div class="task-details">
								{#if task.deadline_date}
									<div class="task-detail">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<circle cx="12" cy="12" r="10"/>
											<polyline points="12,6 12,12 16,14"/>
										</svg>
										<span>Due {formatDate(task.deadline_date)}</span>
									</div>
								{/if}
								
								<div class="task-detail">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
										<circle cx="12" cy="7" r="4"/>
									</svg>
									<span>By {task.assigned_by_name || task.created_by_name || 'Unknown'}</span>
								</div>
								
								<div class="task-detail">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<polyline points="12,6 12,12 16,14"/>
									</svg>
									<span>Assigned {formatDate(task.assigned_at)}</span>
								</div>
							</div>
						</div>

						{#if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled'}
							<div class="task-actions">
								<button class="complete-btn" on:click={() => markAsComplete(task)} disabled={isLoading}>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<polyline points="20,6 9,17 4,12"/>
									</svg>
									Mark Complete
								</button>
								<button class="view-btn" on:click={() => goto(`/mobile/tasks/${task.id}`)}>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
										<circle cx="12" cy="12" r="3"/>
									</svg>
									View Details
								</button>
							</div>
						{:else}
							<div class="task-actions">
								<button class="view-btn full-width" on:click={() => goto(`/mobile/tasks/${task.id}`)}>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
										<circle cx="12" cy="12" r="3"/>
									</svg>
									View Details
								</button>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.mobile-tasks {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	/* Header */
	.page-header {
		background: linear-gradient(135deg, #3B82F6 0%, #1D4ED8 100%);
		color: white;
		padding: 1rem 1.5rem;
		padding-top: calc(1rem + env(safe-area-inset-top));
		box-shadow: 0 2px 10px rgba(59, 130, 246, 0.2);
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.header-content {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.back-btn,
	.add-btn {
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

	.back-btn:hover,
	.add-btn:hover {
		background: rgba(255, 255, 255, 0.2);
		transform: scale(1.05);
	}

	.page-header h1 {
		font-size: 1.25rem;
		font-weight: 600;
		margin: 0;
	}

	/* Filters */
	.filters-section {
		padding: 1.5rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.search-box {
		position: relative;
		margin-bottom: 1rem;
	}

	.search-box svg {
		position: absolute;
		left: 1rem;
		top: 50%;
		transform: translateY(-50%);
		color: #9CA3AF;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 1rem 0.75rem 3rem;
		border: 2px solid #E5E7EB;
		border-radius: 12px;
		font-size: 1rem;
		background: #F9FAFB;
		color: #374151;
		transition: all 0.3s ease;
		box-sizing: border-box;
	}

	.search-input:focus {
		outline: none;
		border-color: #3B82F6;
		background: white;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filter-chips {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.filter-select {
		flex: 1;
		padding: 0.5rem 0.75rem;
		border: 2px solid #E5E7EB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		color: #374151;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.results-count {
		font-size: 0.875rem;
		color: #6B7280;
		text-align: center;
	}

	/* Content */
	.content-section {
		padding: 1.5rem;
		padding-bottom: calc(1.5rem + env(safe-area-inset-bottom));
	}

	/* Loading State */
	.loading-state {
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

	/* Empty State */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
	}

	.empty-icon {
		width: 80px;
		height: 80px;
		background: #F3F4F6;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 1.5rem;
		color: #9CA3AF;
	}

	.empty-state h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.5rem 0;
	}

	.empty-state p {
		font-size: 1rem;
		color: #6B7280;
		margin: 0 0 2rem 0;
		line-height: 1.5;
	}

	.create-task-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.create-task-btn:hover {
		background: #2563EB;
		transform: translateY(-1px);
	}

	/* Task List */
	.task-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.task-card {
		background: white;
		border-radius: 16px;
		overflow: hidden;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		transition: all 0.3s ease;
		border: 2px solid transparent;
	}

	.task-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.task-card.overdue {
		border-color: #FEE2E2;
		background: linear-gradient(to right, #FEF2F2, white);
	}

	.task-header {
		padding: 1rem 1rem 0.5rem;
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		cursor: pointer;
		touch-action: manipulation;
	}

	.task-title-section {
		flex: 1;
	}

	.task-header h3 {
		font-size: 1.1rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.75rem 0;
		line-height: 1.4;
	}

	.task-meta {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.task-priority,
	.task-status {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 6px;
		text-transform: uppercase;
	}

	.overdue-badge {
		width: 32px;
		height: 32px;
		background: #FEE2E2;
		color: #DC2626;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.task-content {
		padding: 0 1rem 1rem;
		cursor: pointer;
		touch-action: manipulation;
	}

	.task-description {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0 0 1rem 0;
		line-height: 1.5;
		display: -webkit-box;
		-webkit-line-clamp: 3;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.task-details {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.task-detail {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	.task-detail svg {
		flex-shrink: 0;
	}

	/* Task Actions */
	.task-actions {
		padding: 1rem;
		border-top: 1px solid #F3F4F6;
		display: flex;
		gap: 0.75rem;
	}

	.complete-btn,
	.view-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		border: none;
		border-radius: 10px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.complete-btn {
		background: #10B981;
		color: white;
	}

	.complete-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.complete-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	.view-btn {
		background: #F3F4F6;
		color: #374151;
	}

	.view-btn:hover {
		background: #E5E7EB;
		transform: translateY(-1px);
	}

	.view-btn.full-width {
		flex: unset;
		width: 100%;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.page-header {
			padding: 1rem;
			padding-top: calc(1rem + env(safe-area-inset-top));
		}

		.filters-section,
		.content-section {
			padding: 1rem;
		}

		.filter-chips {
			flex-direction: column;
		}

		.task-card {
			border-radius: 12px;
		}

		.task-actions {
			flex-direction: column;
		}

		.complete-btn,
		.view-btn {
			width: 100%;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.page-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}

		.content-section {
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
	}
</style>