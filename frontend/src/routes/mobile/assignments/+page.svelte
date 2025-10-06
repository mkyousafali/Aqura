<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';

	// Data
	let assignments = [];
	let filteredAssignments = [];
	let totalStats = {
		total: 0,
		completed: 0,
		in_progress: 0,
		assigned: 0,
		overdue: 0
	};

	// Loading states
	let isLoading = true;

	// Search and filters
	let searchTerm = '';
	let statusFilter = '';
	let priorityFilter = '';

	// UI state
	let showFilters = false;

	onMount(async () => {
		await loadMyAssignments();
	});

	async function loadMyAssignments() {
		if (!$currentUser) return;

		try {
			isLoading = true;

			// Get all task assignments where current user is the assigner
			const { data: assignmentData, error: assignmentError } = await supabase
				.from('task_assignments')
				.select('*')
				.eq('assigned_by', $currentUser.id)
				.order('assigned_at', { ascending: false });

			if (assignmentError) {
				throw new Error(assignmentError.message);
			}

			if (!assignmentData || assignmentData.length === 0) {
				assignments = [];
				calculateStats();
				applyFilters();
				return;
			}

			// Get unique task IDs and user IDs
			const taskIds = [...new Set(assignmentData.map(a => a.task_id))];
			const userIds = [...new Set(assignmentData.map(a => a.assigned_to_user_id).filter(Boolean))];

			// Fetch tasks
			const { data: tasksData, error: tasksError } = await supabase
				.from('tasks')
				.select('id, title, description, priority, due_date, status, created_at')
				.in('id', taskIds);

			if (tasksError) {
				throw new Error(tasksError.message);
			}

			// Fetch users - handle both ID and username approaches
			let usersData = [];
			if (userIds.length > 0) {
				// Try as IDs first
				const { data: userData1, error: userError1 } = await supabase
					.from('users')
					.select('id, username')
					.in('id', userIds);

				if (userError1) {
					// If that fails, try as usernames
					const { data: userData2, error: userError2 } = await supabase
						.from('users')
						.select('id, username')
						.in('username', userIds);

					if (userError2) {
						throw new Error(userError2.message);
					}
					usersData = userData2 || [];
				} else {
					usersData = userData1 || [];
				}
			}

			// Create lookup maps
			const tasksMap = new Map(tasksData?.map(task => [task.id, task]) || []);
			
			const usersMap = new Map();
			usersData?.forEach(user => {
				usersMap.set(user.id, user);
				usersMap.set(user.username, user);
			});

			// Combine the data
			assignments = assignmentData.map(assignment => ({
				...assignment,
				task: tasksMap.get(assignment.task_id),
				assigned_user: usersMap.get(assignment.assigned_to_user_id)
			}));
			
			// Calculate statistics
			calculateStats();
			
			// Apply initial filters
			applyFilters();

		} catch (error) {
			console.error('Error loading assignments:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load assignments: ' + error.message,
				duration: 5000
			});
		} finally {
			isLoading = false;
		}
	}

	function calculateStats() {
		totalStats.total = assignments.length;
		totalStats.completed = assignments.filter(a => a.status === 'completed').length;
		totalStats.in_progress = assignments.filter(a => a.status === 'in_progress').length;
		totalStats.assigned = assignments.filter(a => a.status === 'assigned').length;
		
		// Calculate overdue
		const now = new Date();
		totalStats.overdue = assignments.filter(a => {
			if (a.status === 'completed') return false;
			if (!a.deadline_date) return false;
			
			const deadline = new Date(a.deadline_date);
			if (a.deadline_time) {
				const [hours, minutes] = a.deadline_time.split(':');
				deadline.setHours(parseInt(hours), parseInt(minutes));
			}
			
			return deadline < now;
		}).length;
	}

	function applyFilters() {
		filteredAssignments = assignments.filter(assignment => {
			// Search filter
			if (searchTerm) {
				const searchLower = searchTerm.toLowerCase();
				const taskTitle = assignment.task?.title?.toLowerCase() || '';
				const userName = assignment.assigned_user?.username?.toLowerCase() || '';
				
				if (!taskTitle.includes(searchLower) && !userName.includes(searchLower)) {
					return false;
				}
			}

			// Status filter
			if (statusFilter && assignment.status !== statusFilter) {
				return false;
			}

			// Priority filter
			if (priorityFilter && assignment.task?.priority !== priorityFilter) {
				return false;
			}

			return true;
		});
	}

	function clearFilters() {
		searchTerm = '';
		statusFilter = '';
		priorityFilter = '';
		showFilters = false;
		applyFilters();
	}

	function toggleFilters() {
		showFilters = !showFilters;
	}

	function formatDate(dateString) {
		if (!dateString) return 'No deadline';
		const date = new Date(dateString);
		return date.toLocaleDateString();
	}

	function formatDateTime(dateString, timeString) {
		if (!dateString) return 'No deadline';
		const date = new Date(dateString);
		if (timeString) {
			const [hours, minutes] = timeString.split(':');
			date.setHours(parseInt(hours), parseInt(minutes));
			return date.toLocaleString();
		}
		return date.toLocaleDateString();
	}

	function getStatusColor(status) {
		switch (status) {
			case 'assigned': return 'bg-blue-100 text-blue-800';
			case 'in_progress': return 'bg-yellow-100 text-yellow-800';
			case 'completed': return 'bg-green-100 text-green-800';
			case 'cancelled': return 'bg-red-100 text-red-800';
			case 'escalated': return 'bg-purple-100 text-purple-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return 'bg-red-100 text-red-800';
			case 'medium': return 'bg-yellow-100 text-yellow-800';
			case 'low': return 'bg-green-100 text-green-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function getStatusDisplayText(status) {
		switch (status) {
			case 'assigned': return 'ASSIGNED';
			case 'in_progress': return 'IN PROGRESS';
			case 'completed': return 'COMPLETED';
			case 'cancelled': return 'CANCELLED';
			case 'escalated': return 'ESCALATED';
			case 'reassigned': return 'REASSIGNED';
			default: return status?.replace('_', ' ').toUpperCase() || 'UNKNOWN';
		}
	}

	function isOverdue(assignment) {
		if (assignment.status === 'completed') return false;
		if (!assignment.deadline_date) return false;
		
		const now = new Date();
		const deadline = new Date(assignment.deadline_date);
		if (assignment.deadline_time) {
			const [hours, minutes] = assignment.deadline_time.split(':');
			deadline.setHours(parseInt(hours), parseInt(minutes));
		}
		
		return deadline < now;
	}

	// Reactive statements
	$: {
		searchTerm, statusFilter, priorityFilter;
		applyFilters();
	}
</script>

<svelte:head>
	<title>My Assignments - Aqura Mobile</title>
</svelte:head>

<div class="mobile-assignments">

	<!-- Statistics Cards -->
	<section class="stats-section">
		<div class="stats-grid">
			<div class="stat-card total">
				<div class="stat-number">{totalStats.total}</div>
				<div class="stat-label">Total</div>
			</div>
			<div class="stat-card completed">
				<div class="stat-number">{totalStats.completed}</div>
				<div class="stat-label">Completed</div>
			</div>
			<div class="stat-card progress">
				<div class="stat-number">{totalStats.in_progress}</div>
				<div class="stat-label">In Progress</div>
			</div>
			<div class="stat-card pending">
				<div class="stat-number">{totalStats.assigned}</div>
				<div class="stat-label">Pending</div>
			</div>
			<div class="stat-card overdue">
				<div class="stat-number">{totalStats.overdue}</div>
				<div class="stat-label">Overdue</div>
			</div>
		</div>
	</section>

	<!-- Filters (collapsible) -->
	{#if showFilters}
		<section class="filters-section">
			<div class="filters-content">
				<div class="search-box">
					<input
						type="text"
						bind:value={searchTerm}
						placeholder="Search tasks or users..."
						class="search-input"
					/>
				</div>
				
				<div class="filter-row">
					<select bind:value={statusFilter} class="filter-select">
						<option value="">All Statuses</option>
						<option value="assigned">Assigned</option>
						<option value="in_progress">In Progress</option>
						<option value="completed">Completed</option>
						<option value="cancelled">Cancelled</option>
						<option value="escalated">Escalated</option>
					</select>

					<select bind:value={priorityFilter} class="filter-select">
						<option value="">All Priorities</option>
						<option value="high">High</option>
						<option value="medium">Medium</option>
						<option value="low">Low</option>
					</select>
				</div>

				<button class="clear-filters-btn" on:click={clearFilters}>
					Clear Filters
				</button>
			</div>
		</section>
	{/if}

	<!-- Content -->
	<main class="assignments-content">
		{#if isLoading}
			<div class="loading-state">
				<div class="loading-spinner"></div>
				<p>Loading assignments...</p>
			</div>
		{:else if filteredAssignments.length === 0}
			<div class="empty-state">
				<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
					<path d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
				</svg>
				<h3>No assignments found</h3>
				<p>
					{assignments.length === 0 ? 'You haven\'t assigned any tasks yet.' : 'No assignments match your current filters.'}
				</p>
			</div>
		{:else}
			<div class="assignments-list">
				{#each filteredAssignments as assignment}
					<div class="assignment-card" class:overdue={isOverdue(assignment)}>
						<div class="card-header">
							<h3 class="task-title">{assignment.task?.title || 'Unknown Task'}</h3>
							<div class="card-badges">
								{#if assignment.task?.priority}
									<span class="priority-badge {getPriorityColor(assignment.task.priority)}">
										{assignment.task.priority.toUpperCase()}
									</span>
								{/if}
								{#if isOverdue(assignment)}
									<span class="overdue-badge">OVERDUE</span>
								{/if}
							</div>
						</div>

						{#if assignment.task?.description}
							<p class="task-description">{assignment.task.description}</p>
						{/if}

						<div class="assignment-details">
							<div class="detail-item">
								<span class="detail-label">Assigned To:</span>
								<span class="detail-value">{assignment.assigned_user?.username || 'Unknown User'}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">Status:</span>
								<span class="status-badge {getStatusColor(assignment.status)}">
									{getStatusDisplayText(assignment.status)}
								</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">Assigned:</span>
								<span class="detail-value">{formatDate(assignment.assigned_at)}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">Deadline:</span>
								<span class="detail-value">{formatDateTime(assignment.deadline_date, assignment.deadline_time)}</span>
							</div>
						</div>

						{#if assignment.notes}
							<div class="assignment-notes">
								<span class="notes-label">Notes:</span>
								<p class="notes-text">{assignment.notes}</p>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</main>

	<!-- Footer Stats -->
	<footer class="mobile-footer">
		<div class="footer-stats">
			<span>Showing {filteredAssignments.length} of {assignments.length}</span>
			<span>Completion Rate: {assignments.length > 0 ? Math.round((totalStats.completed / assignments.length) * 100) : 0}%</span>
		</div>
	</footer>
</div>

<style>
	.mobile-assignments {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
		padding-bottom: 5rem; /* Space for bottom nav */
	}

	/* Statistics */
	.stats-section {
		padding: 1rem 1.5rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 0.75rem;
	}

	.stat-card {
		text-align: center;
		padding: 0.75rem 0.5rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.stat-card.total { background: #F3F4F6; }
	.stat-card.completed { background: #ECFDF5; border-color: #D1FAE5; }
	.stat-card.progress { background: #FFFBEB; border-color: #FDE68A; }
	.stat-card.pending { background: #EFF6FF; border-color: #DBEAFE; }
	.stat-card.overdue { background: #FEF2F2; border-color: #FECACA; }

	.stat-number {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1F2937;
	}

	.stat-label {
		font-size: 0.75rem;
		color: #6B7280;
		margin-top: 0.25rem;
	}

	/* Filters */
	.filters-section {
		background: white;
		border-bottom: 1px solid #E5E7EB;
		padding: 1rem 1.5rem;
	}

	.search-box {
		margin-bottom: 1rem;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 1rem;
	}

	.filter-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.filter-select {
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		background: white;
		font-size: 0.875rem;
	}

	.clear-filters-btn {
		width: 100%;
		padding: 0.75rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		color: #374151;
		font-weight: 500;
		cursor: pointer;
	}

	/* Content */
	.assignments-content {
		flex: 1;
		padding: 1rem 1.5rem;
		overflow-y: auto;
	}

	.loading-state, .empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: 4rem 2rem;
		color: #6B7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top: 3px solid #4F46E5;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	.empty-state svg {
		color: #9CA3AF;
		margin-bottom: 1rem;
	}

	.empty-state h3 {
		font-size: 1.125rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	/* Assignment Cards */
	.assignments-list {
		space-y: 1rem;
	}

	.assignment-card {
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 12px;
		padding: 1rem;
		margin-bottom: 1rem;
		transition: all 0.3s ease;
	}

	.assignment-card.overdue {
		border-color: #F87171;
		background: #FEF2F2;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.75rem;
		gap: 0.75rem;
	}

	.task-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1F2937;
		flex: 1;
		margin: 0;
	}

	.card-badges {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		flex-shrink: 0;
	}

	.priority-badge, .overdue-badge, .status-badge {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		text-align: center;
	}

	.overdue-badge {
		background: #FEE2E2;
		color: #DC2626;
	}

	.task-description {
		color: #6B7280;
		font-size: 0.875rem;
		margin: 0 0 1rem 0;
		line-height: 1.5;
	}

	.assignment-details {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.detail-label {
		font-size: 0.75rem;
		font-weight: 500;
		color: #6B7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-value {
		font-size: 0.875rem;
		color: #1F2937;
		font-weight: 500;
	}

	.assignment-notes {
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		padding: 0.75rem;
	}

	.notes-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.notes-text {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0.25rem 0 0 0;
		line-height: 1.4;
	}

	/* Footer */
	.mobile-footer {
		background: white;
		border-top: 1px solid #E5E7EB;
		padding: 0.75rem 1.5rem;
		margin-top: auto;
	}

	.footer-stats {
		display: flex;
		justify-content: space-between;
		font-size: 0.75rem;
		color: #6B7280;
	}

	/* Responsive */
	@media (max-width: 480px) {
		.stats-grid {
			grid-template-columns: repeat(3, 1fr);
			gap: 0.5rem;
		}

		.stat-card {
			padding: 0.5rem 0.25rem;
		}

		.stat-number {
			font-size: 1rem;
		}

		.stat-label {
			font-size: 0.625rem;
		}

		.assignment-details {
			grid-template-columns: 1fr;
			gap: 0.5rem;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.mobile-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}
	}
</style>