<script lang="ts">
	import { onMount } from 'svelte';
	import { taskCounts, taskCountService } from '$lib/stores/taskCount';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { goto } from '$app/navigation';
	
	// Store subscriptions
	$: counts = $taskCounts;
	$: user = $currentUser;
	
	// Task data
	let regularTasks: any[] = [];
	let quickTasks: any[] = [];
	let isLoading = true;
	let error = '';
	
	onMount(async () => {
		await loadTasks();
	});
	
	async function loadTasks() {
		if (!user) return;
		
		isLoading = true;
		error = '';
		
		try {
			// Load regular task assignments (simplified, no complex joins)
			const { data: regularData, error: regularError } = await supabase
				.from('task_assignments')
				.select('id, status, assigned_at, deadline_date, deadline_time, notes, task_id, assigned_by')
				.eq('assigned_to_user_id', user.id)
				.in('status', ['assigned', 'in_progress', 'pending'])
				.order('assigned_at', { ascending: false })
				.limit(20);
			
			if (regularError) {
				console.error('Error loading regular tasks:', regularError);
				error = 'Failed to load regular tasks';
			} else {
				// Fetch task details separately to avoid complex joins
				if (regularData && regularData.length > 0) {
					const taskIds = regularData.map(t => t.task_id);
					const { data: taskDetails } = await supabase
						.from('tasks')
						.select('id, title, description, priority, price_tag, issue_type')
						.in('id', taskIds);
					
					// Merge the data
					regularTasks = regularData.map(assignment => {
						const task = taskDetails?.find(t => t.id === assignment.task_id);
						return {
							...assignment,
							task: task || { title: 'Unknown Task', description: '' }
						};
					});
				} else {
					regularTasks = [];
				}
			}
			
			// Load quick task assignments (simplified, no complex joins)
			const { data: quickData, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select('id, status, created_at, quick_task_id')
				.eq('assigned_to_user_id', user.id)
				.in('status', ['assigned', 'in_progress', 'pending'])
				.order('created_at', { ascending: false })
				.limit(20);
			
			if (quickError) {
				console.error('Error loading quick tasks:', quickError);
				error = error ? `${error}; Failed to load quick tasks` : 'Failed to load quick tasks';
			} else {
				// Fetch quick task details separately to avoid complex joins
				if (quickData && quickData.length > 0) {
					const quickTaskIds = quickData.map(t => t.quick_task_id);
					const { data: quickTaskDetails } = await supabase
						.from('quick_tasks')
						.select('id, title, description, priority, price_tag, issue_type, deadline_datetime, assigned_by')
						.in('id', quickTaskIds);
					
					// Merge the data
					quickTasks = quickData.map(assignment => {
						const quickTask = quickTaskDetails?.find(t => t.id === assignment.quick_task_id);
						return {
							...assignment,
							quick_task: quickTask || { title: 'Unknown Quick Task', description: '' }
						};
					});
				} else {
					quickTasks = [];
				}
			}
			
		} catch (err) {
			console.error('Error loading tasks:', err);
			error = 'Failed to load tasks';
		} finally {
			isLoading = false;
		}
	}
	
	function formatDateTime(date: string, time?: string) {
		if (!date) return 'No deadline';
		const dateTime = time ? `${date}T${time}` : `${date}T23:59:59`;
		return new Date(dateTime).toLocaleString();
	}
	
	function isOverdue(date: string, time?: string) {
		if (!date) return false;
		const dateTime = time ? `${date}T${time}` : `${date}T23:59:59`;
		return new Date(dateTime) < new Date();
	}
	
	function getPriorityColor(priority: string) {
		switch (priority?.toLowerCase()) {
			case 'high': return 'text-red-600 bg-red-100';
			case 'medium': return 'text-yellow-600 bg-yellow-100';
			case 'low': return 'text-green-600 bg-green-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}
	
	function getStatusColor(status: string) {
		switch (status?.toLowerCase()) {
			case 'assigned': return 'text-blue-600 bg-blue-100';
			case 'in_progress': return 'text-orange-600 bg-orange-100';
			case 'pending': return 'text-yellow-600 bg-yellow-100';
			case 'completed': return 'text-green-600 bg-green-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}
	
	function navigateToTask(task: any, isQuickTask = false) {
		if (isQuickTask) {
			goto(`/mobile/quick-tasks/${task.quick_task.id}/complete`);
		} else {
			goto(`/mobile/tasks/${task.task.id}/complete`);
		}
	}
	
	async function refreshTasks() {
		await loadTasks();
		await taskCountService.refreshTaskCounts();
	}
</script>

<div class="tasks-window">
	<div class="tasks-header">
		<div class="tasks-title">
			<h1>📋 My Tasks</h1>
			<div class="task-summary">
				{#if counts.loading}
					<span class="loading">Loading...</span>
				{:else}
					<span class="total-count">Total: {counts.total}</span>
					{#if counts.overdue > 0}
						<span class="overdue-count">Overdue: {counts.overdue}</span>
					{/if}
					{#if counts.inProgress > 0}
						<span class="in-progress-count">In Progress: {counts.inProgress}</span>
					{/if}
				{/if}
			</div>
		</div>
		<button class="refresh-btn" on:click={refreshTasks} disabled={isLoading}>
			🔄 Refresh
		</button>
	</div>
	
	<div class="tasks-content">
		{#if isLoading}
			<div class="loading-state">
				<div class="loading-spinner"></div>
				<p>Loading your tasks...</p>
			</div>
		{:else if error}
			<div class="error-state">
				<p>❌ {error}</p>
				<button on:click={loadTasks}>Try Again</button>
			</div>
		{:else if regularTasks.length === 0 && quickTasks.length === 0}
			<div class="empty-state">
				<div class="empty-icon">📝</div>
				<h3>No Active Tasks</h3>
				<p>You don't have any active tasks assigned at the moment.</p>
			</div>
		{:else}
			<div class="tasks-list">
				<!-- Quick Tasks Section -->
				{#if quickTasks.length > 0}
					<div class="task-section">
						<h2>⚡ Quick Tasks ({quickTasks.length})</h2>
						<div class="task-cards">
							{#each quickTasks as assignment}
								<div class="task-card quick-task" class:overdue={isOverdue(assignment.quick_task.deadline_datetime)}>
									<div class="task-header">
										<h3>{assignment.quick_task.title}</h3>
										<div class="task-badges">
											<span class="priority-badge {getPriorityColor(assignment.quick_task.priority)}">
												{assignment.quick_task.priority?.toUpperCase() || 'MEDIUM'}
											</span>
											<span class="status-badge {getStatusColor(assignment.status)}">
												{assignment.status?.replace('_', ' ').toUpperCase() || 'PENDING'}
											</span>
											{#if isOverdue(assignment.quick_task.deadline_datetime)}
												<span class="overdue-badge">⚠️ OVERDUE</span>
											{/if}
										</div>
									</div>
									
									{#if assignment.quick_task.description}
										<p class="task-description">{assignment.quick_task.description}</p>
									{/if}
									
									<div class="task-meta">
										<div class="task-info">
											<span>📅 Deadline: {formatDateTime(assignment.quick_task.deadline_datetime)}</span>
											<span>👤 Assigned by: {assignment.quick_task.assigned_by || 'Unknown'}</span>
											{#if assignment.quick_task.price_tag}
												<span>💰 Price: {assignment.quick_task.price_tag}</span>
											{/if}
											{#if assignment.quick_task.issue_type}
												<span>🏷️ Type: {assignment.quick_task.issue_type}</span>
											{/if}
										</div>
										
										<button class="complete-btn" on:click={() => navigateToTask(assignment, true)}>
											Complete Task →
										</button>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/if}
				
				<!-- Regular Tasks Section -->
				{#if regularTasks.length > 0}
					<div class="task-section">
						<h2>📋 Regular Tasks ({regularTasks.length})</h2>
						<div class="task-cards">
							{#each regularTasks as assignment}
								<div class="task-card regular-task" class:overdue={isOverdue(assignment.deadline_date, assignment.deadline_time)}>
									<div class="task-header">
										<h3>{assignment.task.title}</h3>
										<div class="task-badges">
											<span class="priority-badge {getPriorityColor(assignment.task.priority)}">
												{assignment.task.priority?.toUpperCase() || 'MEDIUM'}
											</span>
											<span class="status-badge {getStatusColor(assignment.status)}">
												{assignment.status?.replace('_', ' ').toUpperCase() || 'PENDING'}
											</span>
											{#if isOverdue(assignment.deadline_date, assignment.deadline_time)}
												<span class="overdue-badge">⚠️ OVERDUE</span>
											{/if}
										</div>
									</div>
									
									{#if assignment.task.description}
										<p class="task-description">{assignment.task.description}</p>
									{/if}
									
									<div class="task-meta">
										<div class="task-info">
											<span>📅 Deadline: {formatDateTime(assignment.deadline_date, assignment.deadline_time)}</span>
											<span>👤 Assigned by: {assignment.assigned_by || 'Unknown'}</span>
											{#if assignment.task.price_tag}
												<span>💰 Price: {assignment.task.price_tag}</span>
											{/if}
											{#if assignment.task.issue_type}
												<span>🏷️ Type: {assignment.task.issue_type}</span>
											{/if}
										</div>
										
										<button class="complete-btn" on:click={() => navigateToTask(assignment, false)}>
											Complete Task →
										</button>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>

<style>
	.tasks-window {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		border-radius: 8px;
		overflow: hidden;
	}
	
	.tasks-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		background: linear-gradient(135deg, #3b82f6, #1e40af);
		color: white;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}
	
	.tasks-title h1 {
		margin: 0;
		font-size: 1.5rem;
		font-weight: 600;
	}
	
	.task-summary {
		display: flex;
		gap: 1rem;
		align-items: center;
		font-size: 0.875rem;
		margin-top: 0.25rem;
	}
	
	.total-count {
		background: rgba(255, 255, 255, 0.2);
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
	}
	
	.overdue-count {
		background: #ef4444;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		animation: pulse 2s infinite;
	}
	
	.in-progress-count {
		background: #f59e0b;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
	}
	
	.refresh-btn {
		background: rgba(255, 255, 255, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.3);
		color: white;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s ease;
	}
	
	.refresh-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.3);
		transform: translateY(-1px);
	}
	
	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	
	.tasks-content {
		flex: 1;
		overflow-y: auto;
		padding: 1rem;
	}
	
	.loading-state, .error-state, .empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 200px;
		text-align: center;
	}
	
	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top: 3px solid #3b82f6;
		border-radius: 50%;
		margin-bottom: 1rem;
		animation: spin 1s linear infinite;
	}
	
	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
	
	.empty-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
	}
	
	.task-section {
		margin-bottom: 2rem;
	}
	
	.task-section h2 {
		margin: 0 0 1rem 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
		padding-bottom: 0.5rem;
	}
	
	.task-cards {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	
	.task-card {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1rem;
		transition: all 0.2s ease;
	}
	
	.task-card:hover {
		background: #f3f4f6;
		border-color: #d1d5db;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}
	
	.task-card.quick-task {
		border-left: 4px solid #8b5cf6;
	}
	
	.task-card.regular-task {
		border-left: 4px solid #3b82f6;
	}
	
	.task-card.overdue {
		border-left-color: #ef4444;
		background: #fef2f2;
	}
	
	.task-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.75rem;
	}
	
	.task-header h3 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 600;
		color: #111827;
		flex: 1;
		margin-right: 1rem;
	}
	
	.task-badges {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}
	
	.priority-badge, .status-badge, .overdue-badge {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		text-transform: uppercase;
	}
	
	.overdue-badge {
		background: #ef4444;
		color: white;
		animation: pulse 2s infinite;
	}
	
	.task-description {
		margin: 0 0 0.75rem 0;
		color: #6b7280;
		font-size: 0.875rem;
		line-height: 1.4;
	}
	
	.task-meta {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		gap: 1rem;
	}
	
	.task-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		font-size: 0.75rem;
		color: #6b7280;
		flex: 1;
	}
	
	.complete-btn {
		background: #3b82f6;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		white-space: nowrap;
	}
	
	.complete-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}
	
	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}
</style>