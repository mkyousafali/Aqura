<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';

	import TaskCreateForm from './tasks/TaskCreateForm.svelte';
	import TaskViewTable from './tasks/TaskViewTable.svelte';
	import TaskAssignmentView from './tasks/TaskAssignmentView.svelte';
	import MyTasksView from './tasks/MyTasksView.svelte';
	import TaskStatusView from './tasks/TaskStatusView.svelte';
	import MyAssignmentsView from './tasks/MyAssignmentsView.svelte';
	import QuickTaskWindow from './tasks/QuickTaskWindow.svelte';
	import TaskDetailsView from './tasks/TaskDetailsView.svelte';

	// Task statistics
	let taskStats = {
		total_tasks: 0,
		active_tasks: 0,
		completed_tasks: 0,
		incomplete_tasks: 0,
		my_assigned_tasks: 0,
		my_completed_tasks: 0,
		my_assignments: 0,
		my_assignments_completed: 0
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
			
			// Import supabase inside the function to avoid circular dependencies  
			const { supabase } = await import('$lib/utils/supabase');
			const { currentUser } = await import('$lib/utils/persistentAuth');
			const { get } = await import('svelte/store');
			
			const user = get(currentUser);
			if (!user) {
				console.error('No current user found');
				isLoading = false;
				return;
			}

			// Get total tasks count as sum of task_assignments, quick_task_assignments, and receiving_tasks
			// Migration 33 -> task_assignments, Migration 23 -> quick_task_assignments, receiving_tasks
			const [taskAssignRes, quickAssignRes, receivingTasksRes] = await Promise.all([
				supabase.from('task_assignments').select('*', { count: 'exact', head: true }),
				supabase.from('quick_task_assignments').select('*', { count: 'exact', head: true }),
				supabase.from('receiving_tasks').select('*', { count: 'exact', head: true })
			]);

			if (taskAssignRes.error) {
				console.error('Error fetching task_assignments count:', taskAssignRes.error);
			}

			if (quickAssignRes.error) {
				console.error('Error fetching quick_task_assignments count:', quickAssignRes.error);
			}

			if (receivingTasksRes.error) {
				console.error('Error fetching receiving_tasks count:', receivingTasksRes.error);
			}

			const totalTasksCount = (taskAssignRes.count || 0) + (quickAssignRes.count || 0) + (receivingTasksRes.count || 0);
			console.log('📊 Total tasks:', totalTasksCount, 'task_assignments:', taskAssignRes.count, 'quick_task_assignments:', quickAssignRes.count, 'receiving_tasks:', receivingTasksRes.count);

			// Get active tasks count
			const { count: activeTasksCount, error: activeError } = await supabase
				.from('tasks')
				.select('*', { count: 'exact', head: true })
				.eq('status', 'active');

			if (activeError) {
				console.error('Error fetching active tasks:', activeError);
			}

			// Get completed tasks count as sum of task_completions, quick_task_completions, and completed receiving_tasks
			// Migration 34 -> task_completions, Migration 24 -> quick_task_completions, receiving_tasks (completed status)
			const [taskCompRes, quickCompRes, receivingCompRes] = await Promise.all([
				supabase.from('task_completions').select('*', { count: 'exact', head: true }),
				supabase.from('quick_task_completions').select('*', { count: 'exact', head: true }),
				supabase.from('receiving_tasks').select('*', { count: 'exact', head: true }).eq('task_status', 'completed')
			]);

			if (taskCompRes.error) {
				console.error('Error fetching task_completions count:', taskCompRes.error);
			}

			if (quickCompRes.error) {
				console.error('Error fetching quick_task_completions count:', quickCompRes.error);
			}

			if (receivingCompRes.error) {
				console.error('Error fetching completed receiving_tasks count:', receivingCompRes.error);
			}

			const completedTasksCount = (taskCompRes.count || 0) + (quickCompRes.count || 0) + (receivingCompRes.count || 0);
			console.log('✅ Completed tasks:', completedTasksCount, 'task_completions:', taskCompRes.count, 'quick_task_completions:', quickCompRes.count, 'receiving_tasks_completed:', receivingCompRes.count);

			// Get tasks assigned to current user from task_assignments, quick_task_assignments, and receiving_tasks
			const [myTaskAssignRes, myQuickAssignRes, myReceivingAssignRes] = await Promise.all([
				supabase.from('task_assignments')
					.select('*', { count: 'exact', head: true })
					.eq('assigned_to_user_id', user.id)
					.in('status', ['assigned', 'in_progress', 'pending']),
				supabase.from('quick_task_assignments')
					.select('*', { count: 'exact', head: true })
					.eq('assigned_to_user_id', user.id)
					.in('status', ['assigned', 'in_progress', 'pending']),
				supabase.from('receiving_tasks')
					.select('*', { count: 'exact', head: true })
					.eq('assigned_user_id', user.id)
					.in('task_status', ['pending', 'in_progress'])
			]);

			if (myTaskAssignRes.error) {
				console.error('Error fetching my task_assignments:', myTaskAssignRes.error);
			}

			if (myQuickAssignRes.error) {
				console.error('Error fetching my quick_task_assignments:', myQuickAssignRes.error);
			}

			if (myReceivingAssignRes.error) {
				console.error('Error fetching my receiving_tasks assignments:', myReceivingAssignRes.error);
			}

			const myAssignedCount = (myTaskAssignRes.count || 0) + (myQuickAssignRes.count || 0) + (myReceivingAssignRes.count || 0);
			console.log('👤 My assigned tasks:', myAssignedCount, 'task_assignments:', myTaskAssignRes.count, 'quick_task_assignments:', myQuickAssignRes.count, 'receiving_tasks:', myReceivingAssignRes.count);

			// Get tasks completed by current user from task_completions, quick_task_completions, and receiving_tasks
			// Note: task_completions uses 'completed_by' (text), quick_task_completions uses 'completed_by_user_id' (uuid)
			// receiving_tasks uses 'completed_by_user_id' (uuid)
			const [myTaskCompRes, myQuickCompRes, myReceivingCompRes] = await Promise.all([
				supabase.from('task_completions')
					.select('*', { count: 'exact', head: true })
					.eq('completed_by', user.id),
				supabase.from('quick_task_completions')
					.select('*', { count: 'exact', head: true })
					.eq('completed_by_user_id', user.id),
				supabase.from('receiving_tasks')
					.select('*', { count: 'exact', head: true })
					.eq('completed_by_user_id', user.id)
					.eq('task_status', 'completed')
			]);

			if (myTaskCompRes.error) {
				console.error('Error fetching my task_completions:', myTaskCompRes.error);
			}

			if (myQuickCompRes.error) {
				console.error('Error fetching my quick_task_completions:', myQuickCompRes.error);
			}

			if (myReceivingCompRes.error) {
				console.error('Error fetching my completed receiving_tasks:', myReceivingCompRes.error);
			}

			const myCompletedCount = (myTaskCompRes.count || 0) + (myQuickCompRes.count || 0) + (myReceivingCompRes.count || 0);
			console.log('✔️ My completed tasks:', myCompletedCount, 'task_completions:', myTaskCompRes.count, 'quick_task_completions:', myQuickCompRes.count, 'receiving_tasks_completed:', myReceivingCompRes.count);

			// Get tasks assigned BY current user to others (My Assignments)
			// task_assignments uses 'assigned_by' (text), need to join quick_task_assignments with quick_tasks
			const [myTaskAssignedByRes, myQuickAssignedByRes] = await Promise.all([
				supabase.from('task_assignments')
					.select('*', { count: 'exact', head: true })
					.eq('assigned_by', user.id),
				supabase.from('quick_task_assignments')
					.select('quick_tasks!inner(assigned_by)', { count: 'exact', head: true })
					.eq('quick_tasks.assigned_by', user.id)
			]);

			if (myTaskAssignedByRes.error) {
				console.error('Error fetching my task_assignments (assigned by):', myTaskAssignedByRes.error);
			}

			if (myQuickAssignedByRes.error) {
				console.error('Error fetching my quick_task_assignments (assigned by):', myQuickAssignedByRes.error);
			}

			const myAssignmentsCount = (myTaskAssignedByRes.count || 0) + (myQuickAssignedByRes.count || 0);
			console.log('📋 My assignments (assigned by me):', myAssignmentsCount, 'task_assignments:', myTaskAssignedByRes.count, 'quick_task_assignments:', myQuickAssignedByRes.count);

			// Get tasks assigned BY current user that have been completed by others
			// Join task_completions with task_assignments where assigned_by = user.id
			// Join quick_task_completions with quick_task_assignments + quick_tasks where assigned_by = user.id
			const [myTaskAssignCompRes, myQuickAssignCompRes] = await Promise.all([
				supabase.from('task_completions')
					.select('task_assignments!inner(assigned_by)', { count: 'exact', head: true })
					.eq('task_assignments.assigned_by', user.id),
				supabase.from('quick_task_completions')
					.select('quick_task_assignments!inner(quick_tasks!inner(assigned_by))', { count: 'exact', head: true })
					.eq('quick_task_assignments.quick_tasks.assigned_by', user.id)
			]);

			if (myTaskAssignCompRes.error) {
				console.error('Error fetching my task assignments completed:', myTaskAssignCompRes.error);
			}

			if (myQuickAssignCompRes.error) {
				console.error('Error fetching my quick task assignments completed:', myQuickAssignCompRes.error);
			}

			const myAssignmentsCompletedCount = (myTaskAssignCompRes.count || 0) + (myQuickAssignCompRes.count || 0);
			console.log('✅ My assignments completed by users:', myAssignmentsCompletedCount, 'task_completions:', myTaskAssignCompRes.count, 'quick_task_completions:', myQuickAssignCompRes.count);

			// Update task statistics
			taskStats = {
				total_tasks: totalTasksCount || 0,
				active_tasks: activeTasksCount || 0,
				completed_tasks: completedTasksCount || 0,
				incomplete_tasks: (totalTasksCount || 0) - (completedTasksCount || 0),
				my_assigned_tasks: myAssignedCount || 0,
				my_completed_tasks: myCompletedCount || 0,
				my_assignments: myAssignmentsCount || 0,
				my_assignments_completed: myAssignmentsCompletedCount || 0
			};

			console.log('✅ Task statistics loaded:', taskStats);
			
		} catch (error) {
			console.error('Error fetching task statistics:', error);
			// Set default values on error
			taskStats = {
				total_tasks: 0,
				active_tasks: 0,
				completed_tasks: 0,
				incomplete_tasks: 0,
				my_assigned_tasks: 0,
				my_completed_tasks: 0,
				my_assignments: 0,
				my_assignments_completed: 0
			};
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
		
		openWindow({
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
		
		openWindow({
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
		
		openWindow({
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
		
		openWindow({
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

	function openTaskDetails(cardType: string) {
		const windowId = generateWindowId('task-details');
		const cardTitles = {
			total_tasks: 'Total Tasks',
			active_tasks: 'Active Tasks',
			completed_tasks: 'Total Completed Tasks',
			incomplete_tasks: 'Total Incomplete Tasks',
			my_assigned_tasks: 'My Assigned Tasks',
			my_completed_tasks: 'My Completed Tasks',
			my_assignments: 'My Assignments',
			my_assignments_completed: 'My Assignments Completed'
		};
		
		openWindow({
			id: windowId,
			title: cardTitles[cardType] || 'Task Details',
			component: TaskDetailsView,
			props: { cardType },
			icon: '📋',
			size: { width: 1200, height: 700 },
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
		
		openWindow({
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
		
		openWindow({
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

	function openQuickTaskWindow() {
		const windowId = generateWindowId('quick-task');
		openWindow({
			id: windowId,
			title: 'Quick Task',
			component: QuickTaskWindow
		});
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
			<div class="header-buttons">
				<button
					on:click={openQuickTaskWindow}
					class="quick-task-btn"
					title="Create Quick Task"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
					</svg>
					<span>Quick Task</span>
				</button>
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
			<div class="stat-card clickable" role="button" tabindex="0" 
				on:click={() => openTaskDetails('total_tasks')}
				on:keydown={(e) => e.key === 'Enter' && openTaskDetails('total_tasks')}>
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

			<div class="stat-card clickable" role="button" tabindex="0"
				on:click={() => openTaskDetails('completed_tasks')}
				on:keydown={(e) => e.key === 'Enter' && openTaskDetails('completed_tasks')}>
				<div class="stat-content">
					<div class="stat-icon bg-purple-100">
						<svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">Total Completed Tasks</p>
						<p class="stat-value">{taskStats.completed_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card clickable" role="button" tabindex="0"
				on:click={() => openTaskDetails('incomplete_tasks')}
				on:keydown={(e) => e.key === 'Enter' && openTaskDetails('incomplete_tasks')}>
				<div class="stat-content">
					<div class="stat-icon bg-red-100">
						<svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">Total Incomplete Tasks</p>
						<p class="stat-value">{taskStats.incomplete_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card clickable" role="button" tabindex="0"
				on:click={() => openTaskDetails('my_assigned_tasks')}
				on:keydown={(e) => e.key === 'Enter' && openTaskDetails('my_assigned_tasks')}>
				<div class="stat-content">
					<div class="stat-icon bg-orange-100">
						<svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">My Assigned Tasks</p>
						<p class="stat-value">{taskStats.my_assigned_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card clickable" role="button" tabindex="0"
				on:click={() => openTaskDetails('my_completed_tasks')}
				on:keydown={(e) => e.key === 'Enter' && openTaskDetails('my_completed_tasks')}>
				<div class="stat-content">
					<div class="stat-icon bg-teal-100">
						<svg class="w-6 h-6 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">My Completed Tasks</p>
						<p class="stat-value">{taskStats.my_completed_tasks}</p>
					</div>
				</div>
			</div>

			<div class="stat-card clickable" role="button" tabindex="0"
				on:click={() => openTaskDetails('my_assignments')}
				on:keydown={(e) => e.key === 'Enter' && openTaskDetails('my_assignments')}>
				<div class="stat-content">
					<div class="stat-icon bg-indigo-100">
						<svg class="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">My Assignments</p>
						<p class="stat-value">{taskStats.my_assignments}</p>
					</div>
				</div>
			</div>

			<div class="stat-card clickable" role="button" tabindex="0"
				on:click={() => openTaskDetails('my_assignments_completed')}
				on:keydown={(e) => e.key === 'Enter' && openTaskDetails('my_assignments_completed')}>
				<div class="stat-content">
					<div class="stat-icon bg-teal-100">
						<svg class="w-6 h-6 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
					</div>
					<div class="stat-info">
						<p class="stat-label">My Assignments Completed</p>
						<p class="stat-value">{taskStats.my_assignments_completed}</p>
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
		width: 100%;
		box-sizing: border-box;
	}

	.header {
		margin-bottom: 32px;
		max-width: 1200px;
		margin-left: auto;
		margin-right: auto;
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

	/* Header Buttons Container */
	.header-buttons {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	/* Quick Task Button */
	.quick-task-btn {
		display: flex;
		align-items: center;
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: 1px solid #3b82f6;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.quick-task-btn:hover {
		background: #2563eb;
		border-color: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
	}

	.quick-task-btn span {
		margin-left: 8px;
	}

	/* Statistics Grid */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 16px;
		margin-bottom: 32px;
		max-width: 1200px;
		margin-left: auto;
		margin-right: auto;
	}

	.stat-card {
		background: linear-gradient(135deg, #ffffff 0%, #f9fafb 100%);
		border: 2px solid transparent;
		border-radius: 16px;
		padding: 20px;
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
		position: relative;
		overflow: hidden;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
		min-height: 120px;
		display: flex;
		flex-direction: column;
		justify-content: center;
	}

	.stat-card.clickable {
		cursor: pointer;
	}

	.stat-card.clickable:active {
		transform: translateY(-2px) scale(0.98);
	}

	.stat-card.clickable:focus {
		outline: 3px solid #667eea;
		outline-offset: 2px;
	}

	.stat-card::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: linear-gradient(90deg, #3b82f6, #8b5cf6, #ec4899);
		opacity: 0;
		transition: opacity 0.3s ease;
	}

	.stat-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 12px 24px rgba(0, 0, 0, 0.12);
		border-color: rgba(59, 130, 246, 0.2);
	}

	.stat-card:hover::before {
		opacity: 1;
	}

	.stat-card.loading {
		animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
	}

	.stat-content {
		display: flex;
		align-items: center;
		gap: 14px;
	}

	.stat-icon {
		width: 48px;
		height: 48px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		position: relative;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
		transition: transform 0.3s ease;
	}

	.stat-card:hover .stat-icon {
		transform: scale(1.1) rotate(5deg);
	}

	.stat-info {
		flex: 1;
		min-width: 0;
	}

	.stat-label {
		font-size: 11px;
		font-weight: 600;
		color: #9ca3af;
		margin: 0 0 8px 0;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		line-height: 1.2;
	}

	.stat-value {
		font-size: 28px;
		font-weight: 800;
		background: linear-gradient(135deg, #111827 0%, #4b5563 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
		margin: 0;
		line-height: 1.1;
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
		max-width: 1200px;
		margin-left: auto;
		margin-right: auto;
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
		max-width: 1200px;
		margin-left: auto;
		margin-right: auto;
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