<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';

	export let windowId: string = '';

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
	let isRefreshing = false;

	// Search and filters
	let searchTerm = '';
	let statusFilter = '';
	let priorityFilter = '';
	let selectedUser = '';
	let selectedTask = '';

	// Get unique users and tasks for filters
	let uniqueUsers = [];
	let uniqueTasks = [];

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
				extractUniqueFilters();
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

			// Fetch users - since assigned_to_user_id might be username (text), try both approaches
			let usersData = [];
			if (userIds.length > 0) {
				// First try as IDs
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
			
			// Create user lookup map that handles both ID and username lookups
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
			
			// Extract unique users and tasks for filters
			extractUniqueFilters();
			
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
		
		// Calculate overdue (assignments with deadline passed and not completed)
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

	function extractUniqueFilters() {
		// Get unique users
		const userMap = new Map();
		assignments.forEach(assignment => {
			if (assignment.assigned_user) {
				const user = assignment.assigned_user;
				userMap.set(user.id, {
					id: user.id,
					name: user.username
				});
			}
		});
		uniqueUsers = Array.from(userMap.values());

		// Get unique tasks
		const taskMap = new Map();
		assignments.forEach(assignment => {
			if (assignment.task) {
				const task = assignment.task;
				taskMap.set(task.id, {
					id: task.id,
					title: task.title
				});
			}
		});
		uniqueTasks = Array.from(taskMap.values());
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

			// User filter
			if (selectedUser && assignment.assigned_to_user_id !== selectedUser) {
				return false;
			}

			// Task filter
			if (selectedTask && assignment.task_id !== selectedTask) {
				return false;
			}

			return true;
		});
	}

	function clearFilters() {
		searchTerm = '';
		statusFilter = '';
		priorityFilter = '';
		selectedUser = '';
		selectedTask = '';
		applyFilters();
	}

	async function refreshData() {
		isRefreshing = true;
		await loadMyAssignments();
		isRefreshing = false;
		
		notifications.add({
			type: 'success',
			message: 'Assignments refreshed successfully',
			duration: 3000
		});
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
		searchTerm, statusFilter, priorityFilter, selectedUser, selectedTask;
		applyFilters();
	}
</script>

<div class="my-assignments-view bg-white rounded-lg shadow-lg h-full flex flex-col">
	<!-- Header -->
	<div class="flex items-center justify-between border-b pb-4 p-6">
		<div class="flex items-center space-x-3">
			<div class="bg-indigo-100 p-2 rounded-lg">
				<svg class="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
				</svg>
			</div>
			<div>
				<h2 class="text-xl font-bold text-gray-900">My Assignments</h2>
				<p class="text-sm text-gray-500">Tasks assigned by you to other users</p>
			</div>
		</div>
		<div class="flex items-center space-x-3">
			<button
				on:click={refreshData}
				disabled={isRefreshing}
				class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2 disabled:opacity-50"
				title="Refresh Data"
			>
				<svg class="w-4 h-4 {isRefreshing ? 'animate-spin' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
				</svg>
				<span>Refresh</span>
			</button>
		</div>
	</div>

	<!-- Statistics Cards -->
	<div class="p-6 border-b">
		<div class="grid grid-cols-5 gap-4">
			<div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-center">
				<div class="text-2xl font-bold text-blue-600">{totalStats.total}</div>
				<div class="text-sm text-blue-700">Total Assigned</div>
			</div>
			<div class="bg-green-50 border border-green-200 rounded-lg p-4 text-center">
				<div class="text-2xl font-bold text-green-600">{totalStats.completed}</div>
				<div class="text-sm text-green-700">Completed</div>
			</div>
			<div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-center">
				<div class="text-2xl font-bold text-yellow-600">{totalStats.in_progress}</div>
				<div class="text-sm text-yellow-700">In Progress</div>
			</div>
			<div class="bg-purple-50 border border-purple-200 rounded-lg p-4 text-center">
				<div class="text-2xl font-bold text-purple-600">{totalStats.assigned}</div>
				<div class="text-sm text-purple-700">Pending</div>
			</div>
			<div class="bg-red-50 border border-red-200 rounded-lg p-4 text-center">
				<div class="text-2xl font-bold text-red-600">{totalStats.overdue}</div>
				<div class="text-sm text-red-700">Overdue</div>
			</div>
		</div>
	</div>

	<!-- Filters -->
	<div class="p-6 border-b bg-gray-50">
		<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
			<!-- Search -->
			<div class="lg:col-span-2">
				<label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
				<input
					type="text"
					bind:value={searchTerm}
					placeholder="Search tasks or users..."
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
				/>
			</div>

			<!-- Status Filter -->
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
				<select bind:value={statusFilter} class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
					<option value="">All Statuses</option>
					<option value="assigned">Assigned</option>
					<option value="in_progress">In Progress</option>
					<option value="completed">Completed</option>
					<option value="cancelled">Cancelled</option>
					<option value="escalated">Escalated</option>
				</select>
			</div>

			<!-- Priority Filter -->
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Priority</label>
				<select bind:value={priorityFilter} class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
					<option value="">All Priorities</option>
					<option value="high">High</option>
					<option value="medium">Medium</option>
					<option value="low">Low</option>
				</select>
			</div>

			<!-- User Filter -->
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Assigned To</label>
				<select bind:value={selectedUser} class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
					<option value="">All Users</option>
					{#each uniqueUsers as user}
						<option value={user.id}>{user.name}</option>
					{/each}
				</select>
			</div>

			<!-- Clear Filters -->
			<div class="flex items-end">
				<button
					on:click={clearFilters}
					class="w-full px-4 py-2 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg transition-colors"
				>
					Clear Filters
				</button>
			</div>
		</div>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-auto p-6">
		{#if isLoading}
			<div class="flex items-center justify-center h-64">
				<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
			</div>
		{:else if filteredAssignments.length === 0}
			<div class="text-center py-12">
				<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
				</svg>
				<h3 class="mt-2 text-lg font-medium text-gray-900">No assignments found</h3>
				<p class="mt-1 text-gray-500">
					{assignments.length === 0 ? 'You haven\'t assigned any tasks yet.' : 'No assignments match your current filters.'}
				</p>
			</div>
		{:else}
			<div class="space-y-4">
				{#each filteredAssignments as assignment}
					<div class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow {isOverdue(assignment) ? 'border-red-300 bg-red-50' : ''}">
						<div class="flex items-start justify-between">
							<div class="flex-1">
								<!-- Task Title -->
								<div class="flex items-center space-x-3 mb-2">
									<h3 class="text-lg font-semibold text-gray-900">{assignment.task?.title || 'Unknown Task'}</h3>
									{#if assignment.task?.priority}
										<span class="px-2 py-1 text-xs font-medium rounded-full {getPriorityColor(assignment.task.priority)}">
											{assignment.task.priority.toUpperCase()}
										</span>
									{/if}
									{#if isOverdue(assignment)}
										<span class="px-2 py-1 text-xs font-medium rounded-full bg-red-100 text-red-800">
											OVERDUE
										</span>
									{/if}
								</div>

								<!-- Task Description -->
								{#if assignment.task?.description}
									<p class="text-gray-600 mb-3 line-clamp-2">{assignment.task.description}</p>
								{/if}

								<!-- Assignment Details -->
								<div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
									<div>
										<span class="font-medium text-gray-700">Assigned To:</span>
										<p class="text-gray-900">
											{assignment.assigned_user?.username || 'Unknown User'}
										</p>
									</div>
									<div>
										<span class="font-medium text-gray-700">Assigned Date:</span>
										<p class="text-gray-900">{formatDate(assignment.assigned_at)}</p>
									</div>
									<div>
										<span class="font-medium text-gray-700">Deadline:</span>
										<p class="text-gray-900">{formatDateTime(assignment.deadline_date, assignment.deadline_time)}</p>
									</div>
									<div>
										<span class="font-medium text-gray-700">Status:</span>
										<span class="px-2 py-1 text-xs font-medium rounded-full {getStatusColor(assignment.status)}">
											{getStatusDisplayText(assignment.status)}
										</span>
									</div>
								</div>

								<!-- Notes -->
								{#if assignment.notes}
									<div class="mt-3 p-3 bg-gray-50 rounded-lg">
										<span class="font-medium text-gray-700">Notes:</span>
										<p class="text-gray-900 mt-1">{assignment.notes}</p>
									</div>
								{/if}
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Footer -->
	<div class="border-t p-4 bg-gray-50">
		<div class="flex items-center justify-between text-sm text-gray-600">
			<span>Showing {filteredAssignments.length} of {assignments.length} assignments</span>
			<span>Total Completion Rate: {assignments.length > 0 ? Math.round((totalStats.completed / assignments.length) * 100) : 0}%</span>
		</div>
	</div>
</div>

<style>
	.line-clamp-2 {
		overflow: hidden;
		display: -webkit-box;
		-webkit-box-orient: vertical;
		-webkit-line-clamp: 2;
	}
</style>