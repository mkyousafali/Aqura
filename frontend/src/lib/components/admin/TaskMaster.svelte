<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import TaskCreateForm from './tasks/TaskCreateForm.svelte';
	import TaskViewTable from './tasks/TaskViewTable.svelte';
	import TaskAssignmentView from './tasks/TaskAssignmentView.svelte';

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

	// Fetch task statistics from API
	async function fetchTaskStatistics() {
		try {
			isLoading = true;
			const response = await fetch('http://localhost:8080/api/v1/admin/tasks/statistics', {
				method: 'GET',
				headers: {
					'Content-Type': 'application/json',
					'X-User-ID': 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',
					'X-User-Name': 'Admin User',
					'X-User-Role': 'Master Admin'
				}
			});

			if (response.ok) {
				const data = await response.json();
				if (data.success && data.data) {
					taskStats = data.data;
				}
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
			title: 'Create New Task',
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
			title: `View Created Tasks #${instanceNumber}`,
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

	function refreshData() {
		fetchTaskStatistics();
	}
</script>

<div class="task-master-dashboard p-6 space-y-6">
	<!-- Dashboard Header -->
	<div class="flex items-center justify-between bg-gradient-to-r from-blue-600 to-purple-600 text-white p-6 rounded-xl shadow-lg">
		<div class="flex items-center space-x-3">
			<div class="bg-white/20 p-3 rounded-lg">
				<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
				</svg>
			</div>
			<div>
				<h1 class="text-3xl font-bold">Task Master</h1>
				<p class="text-blue-100 mt-1">Comprehensive Task Management Dashboard</p>
			</div>
		</div>
		<button
			on:click={refreshData}
			class="bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
			title="Refresh Data"
		>
			<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
			</svg>
			<span>Refresh</span>
		</button>
	</div>

	<!-- Task Statistics Cards -->
	<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
		{#if isLoading}
			{#each Array(5) as _}
				<div class="bg-white rounded-lg shadow-lg p-6 animate-pulse">
					<div class="h-4 bg-gray-200 rounded w-3/4 mb-4"></div>
					<div class="h-8 bg-gray-200 rounded w-1/2"></div>
				</div>
			{/each}
		{:else}
			<div class="bg-white rounded-lg shadow-lg p-6 border-l-4 border-blue-500">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm font-medium text-gray-600">Total Tasks</p>
						<p class="text-3xl font-bold text-gray-900">{taskStats.total_tasks}</p>
					</div>
					<div class="bg-blue-100 p-3 rounded-full">
						<svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
						</svg>
					</div>
				</div>
			</div>

			<div class="bg-white rounded-lg shadow-lg p-6 border-l-4 border-green-500">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm font-medium text-gray-600">Active Tasks</p>
						<p class="text-3xl font-bold text-gray-900">{taskStats.active_tasks}</p>
					</div>
					<div class="bg-green-100 p-3 rounded-full">
						<svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
						</svg>
					</div>
				</div>
			</div>

			<div class="bg-white rounded-lg shadow-lg p-6 border-l-4 border-purple-500">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm font-medium text-gray-600">Completed Tasks</p>
						<p class="text-3xl font-bold text-gray-900">{taskStats.completed_tasks}</p>
					</div>
					<div class="bg-purple-100 p-3 rounded-full">
						<svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
					</div>
				</div>
			</div>

			<div class="bg-white rounded-lg shadow-lg p-6 border-l-4 border-orange-500">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm font-medium text-gray-600">My Assigned</p>
						<p class="text-3xl font-bold text-gray-900">{taskStats.my_assigned_tasks}</p>
					</div>
					<div class="bg-orange-100 p-3 rounded-full">
						<svg class="w-8 h-8 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
						</svg>
					</div>
				</div>
			</div>

			<div class="bg-white rounded-lg shadow-lg p-6 border-l-4 border-teal-500">
				<div class="flex items-center justify-between">
					<div>
						<p class="text-sm font-medium text-gray-600">My Completed</p>
						<p class="text-3xl font-bold text-gray-900">{taskStats.my_completed_tasks}</p>
					</div>
					<div class="bg-teal-100 p-3 rounded-full">
						<svg class="w-8 h-8 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
						</svg>
					</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Action Buttons -->
	<div class="grid grid-cols-1 md:grid-cols-3 gap-6">
		<button
			on:click={openCreateTask}
			class="bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700 text-white p-8 rounded-xl shadow-lg transition-all transform hover:scale-105 focus:outline-none focus:ring-4 focus:ring-green-300"
		>
			<div class="flex flex-col items-center space-y-4">
				<div class="bg-white/20 p-4 rounded-full">
					<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
					</svg>
				</div>
				<div class="text-center">
					<h3 class="text-xl font-bold">Create Task</h3>
					<p class="text-green-100 mt-2">Add new tasks with details, criteria, and assignments</p>
				</div>
			</div>
		</button>

		<button
			on:click={openViewTasks}
			class="bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white p-8 rounded-xl shadow-lg transition-all transform hover:scale-105 focus:outline-none focus:ring-4 focus:ring-blue-300"
		>
			<div class="flex flex-col items-center space-y-4">
				<div class="bg-white/20 p-4 rounded-full">
					<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
					</svg>
				</div>
				<div class="text-center">
					<h3 class="text-xl font-bold">View Tasks</h3>
					<p class="text-blue-100 mt-2">Browse, search, and manage all created tasks</p>
				</div>
			</div>
		</button>

		<button
			on:click={openAssignTasks}
			class="bg-gradient-to-r from-purple-500 to-purple-600 hover:from-purple-600 hover:to-purple-700 text-white p-8 rounded-xl shadow-lg transition-all transform hover:scale-105 focus:outline-none focus:ring-4 focus:ring-purple-300"
		>
			<div class="flex flex-col items-center space-y-4">
				<div class="bg-white/20 p-4 rounded-full">
					<svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
					</svg>
				</div>
				<div class="text-center">
					<h3 class="text-xl font-bold">Assign Tasks</h3>
					<p class="text-purple-100 mt-2">Assign tasks to users with advanced filtering</p>
				</div>
			</div>
		</button>
	</div>

	<!-- Quick Info Section -->
	<div class="bg-gradient-to-r from-gray-50 to-gray-100 rounded-xl p-6">
		<div class="flex items-start space-x-4">
			<div class="bg-blue-500 p-3 rounded-lg">
				<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
				</svg>
			</div>
			<div class="flex-1">
				<h3 class="text-lg font-semibold text-gray-900 mb-2">Task Master Features</h3>
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-gray-600">
					<div class="flex items-center space-x-2">
						<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
						</svg>
						<span>Create tasks with detailed criteria and attachments</span>
					</div>
					<div class="flex items-center space-x-2">
						<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
						</svg>
						<span>Advanced search and filtering capabilities</span>
					</div>
					<div class="flex items-center space-x-2">
						<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
						</svg>
						<span>Bulk task assignment with role-based access</span>
					</div>
					<div class="flex items-center space-x-2">
						<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
						</svg>
						<span>Real-time task status tracking and notifications</span>
					</div>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.task-master-dashboard {
		max-width: 1200px;
		margin: 0 auto;
	}

	@keyframes fadeIn {
		from { opacity: 0; transform: translateY(20px); }
		to { opacity: 1; transform: translateY(0); }
	}

	.task-master-dashboard > * {
		animation: fadeIn 0.6s ease-out;
	}
</style>