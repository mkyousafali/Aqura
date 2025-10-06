<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { getStatistics } from '$lib/stores/taskStore';
	import TaskCreateForm from './tasks/TaskCreateForm.svelte';
	import TaskViewTable from './tasks/TaskViewTable.svelte';
	import TaskAssignmentView from './tasks/TaskAssignmentView.svelte';
	import MyTasksView from './tasks/MyTasksView.svelte';
	import TaskStatusView from './tasks/TaskStatusView.svelte';
	import MyAssignmentsView from './tasks/MyAssignmentsView.svelte';

	// Task statistics
	let taskStats = {
		total_tasks: 0,
		active_tasks: 0,
		completed_tasks: 0,
		my_assigned_tasks: 0,
		my_completed_tasks: 0
	};

	let isLoading = true;

	// Generate unique window ID using timestamp and random number
	function generateWindowId(type: string): string {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Fetch task statistics from Supabase
	async function fetchTaskStatistics() {
		try {
			isLoading = true;
			const result = await getStatistics('e1fdaee2-97f0-4fc1-872f-9d99c6bd684b');
			
			if (result.success && result.data) {
				taskStats = result.data;
			} else {
				console.error('Error fetching task statistics:', result.error);
			}
		} catch (error) {
			console.error('Error fetching task statistics:', error);
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		fetchTaskStatistics();
		// Refresh statistics every 60 seconds
		const interval = setInterval(fetchTaskStatistics, 60000);
		return () => clearInterval(interval);
	});

	function openCreateTask() {
		const windowId = generateWindowId('create-task');
		
		windowManager.openWindow({
			id: windowId,
			title: 'Create New Task Template',
			component: TaskCreateForm,
			icon: '📝',
			size: { width: 600, height: 500 },
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

	function openViewTasks() {
		const windowId = generateWindowId('view-tasks');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `View Task Templates #${instanceNumber}`,
			component: TaskViewTable,
			icon: '📋',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 50), 
				y: 50 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openAssignTasks() {
		const windowId = generateWindowId('assign-tasks');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `Assign Tasks #${instanceNumber}`,
			component: TaskAssignmentView,
			icon: '👥',
			size: { width: 900, height: 600 },
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

	function openTaskStatus() {
		const windowId = generateWindowId('task-status');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `Task Status #${instanceNumber}`,
			component: TaskStatusView,
			icon: '📊',
			size: { width: 1200, height: 800 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openMyTasks() {
		const windowId = generateWindowId('my-tasks');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `My Tasks #${instanceNumber}`,
			component: MyTasksView,
			icon: '📋',
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openMyAssignments() {
		const windowId = generateWindowId('my-assignments');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		windowManager.openWindow({
			id: windowId,
			title: `My Assignments #${instanceNumber}`,
			component: MyAssignmentsView,
			icon: '👨‍💼',
			size: { width: 1200, height: 800 },
			position: { 
				x: 75 + (Math.random() * 100), 
				y: 75 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function refreshData() {
		fetchTaskStatistics();
	}
</script>

<div class="task-master-dashboard">
	<!-- Dashboard Header -->
	<div class="header">
		<div class="title-section">
			<div class="flex items-center justify-center space-x-3 mb-4">
				<div class="bg-blue-100 p-3 rounded-lg">
					<svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
					</svg>
				</div>
			</div>
			<h1 class="title">Task Master Dashboard</h1>
			<p class="subtitle">Comprehensive Task Management System</p>
			<button
				on:click={refreshData}
				class="refresh-btn"
				title="Refresh Data"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
				</svg>
				<span>Refresh</span>
			</button>
		</div>
	</div>

	<!-- Task Statistics Cards -->
	<div class="stats-grid">
		{#if isLoading}
			{#each Array(5) as _}
				<div class="stat-card loading">
					<div class="loading-bar"></div>
					<div class="loading-number"></div>
				</div>
			{/each}
		{:else}
			<div class="stat-card">
				<div class="stat-content">
					<div class="stat-icon bg-blue-100">
						<svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">Total Tasks</p>
						<p class="stat-value">{taskStats.total_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card">
				<div class="stat-content">
					<div class="stat-icon bg-green-100">
						<svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">Active Tasks</p>
						<p class="stat-value">{taskStats.active_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card">
				<div class="stat-content">
					<div class="stat-icon bg-purple-100">
						<svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">Completed Tasks</p>
						<p class="stat-value">{taskStats.completed_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card">
				<div class="stat-content">
					<div class="stat-icon bg-orange-100">
						<svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">My Assigned</p>
						<p class="stat-value">{taskStats.my_assigned_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card">
				<div class="stat-content">
					<div class="stat-icon bg-teal-100">
						<svg class="w-6 h-6 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">My Completed</p>
						<p class="stat-value">{taskStats.my_completed_tasks}</p>
					</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Action Buttons -->
	<div class="dashboard-grid">
		<div class="dashboard-card" on:click={openCreateTask}>
			<div class="card-icon bg-green-100">
				<span class="icon text-green-600">✨</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">Create Task Template</h3>
				<p class="card-description">Add new task templates with details, criteria, and assignments</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openViewTasks}>
			<div class="card-icon bg-blue-100">
				<span class="icon text-blue-600">📋</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">View Task Templates</h3>
				<p class="card-description">Browse, search, and manage all created task templates</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openMyTasks}>
			<div class="card-icon bg-orange-100">
				<span class="icon text-orange-600">📝</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">View My Tasks</h3>
				<p class="card-description">View and complete tasks assigned to you</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openMyAssignments}>
			<div class="card-icon bg-teal-100">
				<span class="icon text-teal-600">👨‍💼</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">View My Assignments</h3>
				<p class="card-description">Track tasks you assigned to others with progress and completion stats</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openAssignTasks}>
			<div class="card-icon bg-purple-100">
				<span class="icon text-purple-600">👥</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">Assign Tasks</h3>
				<p class="card-description">Assign tasks to users with advanced filtering</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>

		<div class="dashboard-card" on:click={openTaskStatus}>
			<div class="card-icon bg-indigo-100">
				<span class="icon text-indigo-600">📊</span>
			</div>
			<div class="card-content">
				<h3 class="card-title">Task Status</h3>
				<p class="card-description">Monitor task progress, send reminders, and generate warnings</p>
			</div>
			<div class="card-arrow">
				<span>→</span>
			</div>
		</div>
	</div>

	<!-- Quick Info Section -->
	<div class="features-section">
		<div class="features-header">
			<div class="features-icon">
				<svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
				</svg>
			</div>
			<h3 class="features-title">Task Master Features</h3>
		</div>
		<div class="features-grid">
			<div class="feature-item">
				<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
				</svg>
				<span>Create task templates with detailed criteria and attachments</span>
			</div>
			<div class="feature-item">
				<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
				</svg>
				<span>Advanced search and filtering capabilities</span>
			</div>
			<div class="feature-item">
				<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
				</svg>
				<span>View and complete assigned tasks</span>
			</div>
			<div class="feature-item">
				<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
				</svg>
				<span>Bulk task assignment with role-based access</span>
			</div>
			<div class="feature-item">
				<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
				</svg>
				<span>Real-time task status tracking and notifications</span>
			</div>
		</div>
	</div>
</div>

<style>
	.task-master-dashboard {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
		max-width: 1200px;
		margin: 0 auto;
	}

	.header {
		margin-bottom: 32px;
	}

	.title-section {
		text-align: center;
		position: relative;
	}

	.title {
		font-size: 32px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 18px;
		color: #6b7280;
		margin: 0 0 20px 0;
	}

	.refresh-btn {
		display: inline-flex;
		align-items: center;
		space-x: 8px;
		padding: 8px 16px;
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		transition: all 0.2s ease;
		cursor: pointer;
	}

	.refresh-btn:hover {
		background: #e5e7eb;
		border-color: #9ca3af;
	}

	.refresh-btn span {
		margin-left: 8px;
	}

	/* Statistics Grid */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 16px;
		margin-bottom: 32px;
	}

	.stat-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 20px;
		transition: all 0.2s ease;
	}

	.stat-card:hover {
		border-color: #d1d5db;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
	}

	.stat-card.loading {
		animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
	}

	.stat-content {
		display: flex;
		align-items: center;
		space-x: 12px;
	}

	.stat-icon {
		width: 40px;
		height: 40px;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		margin-right: 12px;
	}

	.stat-info {
		flex: 1;
	}

	.stat-label {
		font-size: 14px;
		font-weight: 500;
		color: #6b7280;
		margin: 0 0 4px 0;
	}

	.stat-value {
		font-size: 24px;
		font-weight: 700;
		color: #111827;
		margin: 0;
	}

	.loading-bar {
		height: 16px;
		background: #e5e7eb;
		border-radius: 4px;
		margin-bottom: 8px;
		width: 60%;
	}

	.loading-number {
		height: 20px;
		background: #e5e7eb;
		border-radius: 4px;
		width: 40%;
	}

	/* Dashboard Grid */
	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 24px;
		margin-bottom: 32px;
	}

	.dashboard-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
		cursor: pointer;
		transition: all 0.3s ease;
		position: relative;
		overflow: hidden;
	}

	.dashboard-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
		border-color: #d1d5db;
	}

	.dashboard-card::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: var(--card-color, #3b82f6);
		transition: all 0.3s ease;
	}

	.dashboard-card:hover::before {
		height: 6px;
	}

	.card-content {
		display: flex;
		flex-direction: column;
		position: relative;
		z-index: 1;
	}

	.card-icon {
		font-size: 32px;
		width: 48px;
		height: 48px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 8px;
		flex-shrink: 0;
		margin-bottom: 16px;
	}

	.card-icon .icon {
		font-size: 24px;
	}

	.card-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.5;
	}

	.card-arrow {
		position: absolute;
		top: 50%;
		right: 20px;
		transform: translateY(-50%);
		font-size: 20px;
		color: #9ca3af;
		transition: all 0.3s ease;
	}

	.dashboard-card:hover .card-arrow {
		color: #6b7280;
		transform: translateY(-50%) translateX(4px);
	}

	/* Color variations for different cards */
	.dashboard-card:nth-child(1) { --card-color: #10b981; }
	.dashboard-card:nth-child(2) { --card-color: #3b82f6; }
	.dashboard-card:nth-child(3) { --card-color: #f59e0b; }
	.dashboard-card:nth-child(4) { --card-color: #14b8a6; }
	.dashboard-card:nth-child(5) { --card-color: #8b5cf6; }
	.dashboard-card:nth-child(6) { --card-color: #6366f1; }

	/* Features Section */
	.features-section {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
	}

	.features-header {
		display: flex;
		align-items: center;
		margin-bottom: 20px;
	}

	.features-icon {
		background: #dbeafe;
		padding: 12px;
		border-radius: 8px;
		margin-right: 16px;
	}

	.features-title {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.features-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 16px;
	}

	.feature-item {
		display: flex;
		align-items: center;
		font-size: 14px;
		color: #6b7280;
	}

	.feature-item svg {
		margin-right: 8px;
		flex-shrink: 0;
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: .5;
		}
	}

	@keyframes fadeIn {
		from { 
			opacity: 0; 
			transform: translateY(20px); 
		}
		to { 
			opacity: 1; 
			transform: translateY(0); 
		}
	}

	.task-master-dashboard > * {
		animation: fadeIn 0.6s ease-out;
	}

	@media (max-width: 768px) {
		.dashboard-grid,
		.stats-grid {
			grid-template-columns: 1fr;
		}
		
		.features-grid {
			grid-template-columns: 1fr;
		}
	}
</style>