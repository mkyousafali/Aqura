<script lang="ts">
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { windowManager } from '$lib/stores/windowManager';
	import { loadTasks, assignTasks } from '$lib/stores/taskStore';
	import { db } from '$lib/utils/supabase';

	export let windowId: string = '';

	// Data
	let tasks: any[] = [];
	let branches: any[] = [];
	let users: any[] = [];
	let filteredTasks: any[] = [];
	let filteredUsers: any[] = [];

	// Loading states
	let isLoading = true;
	let isAssigning = false;

	// Search and filters
	let taskSearchTerm = '';
	let userSearchTerm = '';
	let selectedBranch = '';
	let selectedRole = '';
	let taskStatusFilter = '';

	// Selections
	let selectedTasks: Set<string> = new Set();
	let selectedUsers: Set<string> = new Set();
	let selectAllTasks = false;
	let selectAllUsers = false;

	// Assignment settings
	let assignmentSettings = {
		notify_assignees: true,
		set_deadline: false,
		deadline: '',
		add_note: '',
		priority_override: ''
	};

	// Available roles for filtering
	const userRoles = ['Manager', 'Supervisor', 'Employee', 'Trainee'];
	const taskStatuses = ['draft', 'active', 'paused'];

	onMount(async () => {
		await loadData();
		
		// Set default deadline to 3 days from now
		const defaultDeadline = new Date();
		defaultDeadline.setDate(defaultDeadline.getDate() + 3);
		assignmentSettings.deadline = defaultDeadline.toISOString().slice(0, 16);
	});

	async function loadDataFromSupabase() {
		try {
			isLoading = true;
			
			// Load tasks (only assignable ones - active and draft status)
			const taskResult = await loadTasks(100, 0, undefined);
			if (taskResult.success) {
				// Filter for assignable tasks (active and draft)
				tasks = (taskResult.data || []).filter(task => 
					task.status === 'active' || task.status === 'draft'
				);
			}

			// Load branches from Supabase
			const { data: branchData, error: branchError } = await db.branches.getAll();
			if (!branchError && branchData) {
				branches = branchData;
			}

			// Load users from Supabase  
			const { data: userData, error: userError } = await db.users.getAll();
			if (!userError && userData) {
				users = userData;
			}

			// Apply initial filters
			applyFilters();
		} catch (error) {
			console.error('Error loading data:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load assignment data',
				duration: 5000
			});
		} finally {
			isLoading = false;
		}
	}

	function applyFilters() {
		// Filter tasks
		filteredTasks = tasks.filter(task => {
			const matchesSearch = !taskSearchTerm || 
				task.title.toLowerCase().includes(taskSearchTerm.toLowerCase()) ||
				task.description.toLowerCase().includes(taskSearchTerm.toLowerCase());
			
			const matchesStatus = !taskStatusFilter || task.status === taskStatusFilter;

			return matchesSearch && matchesStatus;
		});

		// Filter users
		filteredUsers = users.filter(user => {
			const matchesSearch = !userSearchTerm ||
				user.name.toLowerCase().includes(userSearchTerm.toLowerCase()) ||
				user.email.toLowerCase().includes(userSearchTerm.toLowerCase());

			const matchesBranch = !selectedBranch || user.branch_id === selectedBranch;
			const matchesRole = !selectedRole || user.role === selectedRole;

			return matchesSearch && matchesBranch && matchesRole;
		});

		// Update select all states
		updateSelectAllStates();
	}

	function updateSelectAllStates() {
		selectAllTasks = filteredTasks.length > 0 && filteredTasks.every(task => selectedTasks.has(task.id));
		selectAllUsers = filteredUsers.length > 0 && filteredUsers.every(user => selectedUsers.has(user.id));
	}

	function handleSelectAllTasks() {
		if (selectAllTasks) {
			filteredTasks.forEach(task => selectedTasks.add(task.id));
		} else {
			filteredTasks.forEach(task => selectedTasks.delete(task.id));
		}
		selectedTasks = new Set(selectedTasks);
	}

	function handleSelectAllUsers() {
		if (selectAllUsers) {
			filteredUsers.forEach(user => selectedUsers.add(user.id));
		} else {
			filteredUsers.forEach(user => selectedUsers.delete(user.id));
		}
		selectedUsers = new Set(selectedUsers);
	}

	function handleTaskSelect(taskId: string, checked: boolean) {
		if (checked) {
			selectedTasks.add(taskId);
		} else {
			selectedTasks.delete(taskId);
		}
		selectedTasks = new Set(selectedTasks);
		updateSelectAllStates();
	}

	function handleUserSelect(userId: string, checked: boolean) {
		if (checked) {
			selectedUsers.add(userId);
		} else {
			selectedUsers.delete(userId);
		}
		selectedUsers = new Set(selectedUsers);
		updateSelectAllStates();
	}

	async function assignTasksToUsers() {
		if (selectedTasks.size === 0) {
			notifications.add({
				type: 'warning',
				message: 'Please select at least one task to assign',
				duration: 3000
			});
			return;
		}

		if (selectedUsers.size === 0) {
			notifications.add({
				type: 'warning',
				message: 'Please select at least one user to assign tasks to',
				duration: 3000
			});
			return;
		}

		if (assignmentSettings.set_deadline && !assignmentSettings.deadline) {
			notifications.add({
				type: 'warning',
				message: 'Please set a deadline or disable the deadline option',
				duration: 3000
			});
			return;
		}

		isAssigning = true;

		try {
			// For each selected user, create assignments for all selected tasks
			const taskIds = Array.from(selectedTasks);
			
			for (const userId of selectedUsers) {
				const result = await assignTasks(
					taskIds,
					'user', // assignment type
					'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', // assigned by
					'Admin User', // assigned by name
					userId, // assigned to user ID
					undefined // no branch ID for user assignments
				);
				
				if (!result.success) {
					throw new Error(result.error || 'Failed to assign tasks');
				}
			}

			const result = await response.json();

			if (response.ok && result.success) {
				const assignmentCount = selectedTasks.size * selectedUsers.size;
				notifications.add({
					type: 'success',
					message: `Successfully created ${assignmentCount} task assignment${assignmentCount !== 1 ? 's' : ''}`,
					duration: 5000
				});

				// Reset selections
				selectedTasks.clear();
				selectedUsers.clear();
				selectedTasks = new Set(selectedTasks);
				selectedUsers = new Set(selectedUsers);
				
				// Reset assignment settings
				assignmentSettings.add_note = '';
				assignmentSettings.priority_override = '';

				updateSelectAllStates();
			} else {
				throw new Error(result.error || 'Failed to assign tasks');
			}
		} catch (error) {
			console.error('Error assigning tasks:', error);
			notifications.add({
				type: 'error',
				message: error instanceof Error ? error.message : 'Failed to assign tasks',
				duration: 5000
			});
		} finally {
			isAssigning = false;
		}
	}

	function formatDate(dateString: string) {
		if (!dateString) return '-';
		const date = new Date(dateString);
		return date.toLocaleDateString();
	}

	function getStatusBadgeClass(status: string) {
		switch (status) {
			case 'draft': return 'bg-gray-100 text-gray-800';
			case 'active': return 'bg-green-100 text-green-800';
			case 'paused': return 'bg-yellow-100 text-yellow-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function getPriorityBadgeClass(priority: string) {
		switch (priority) {
			case 'low': return 'bg-gray-100 text-gray-800';
			case 'medium': return 'bg-blue-100 text-blue-800';
			case 'high': return 'bg-yellow-100 text-yellow-800';
			case 'urgent': return 'bg-red-100 text-red-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function closeWindow() {
		if (windowId) {
			windowManager.closeWindow(windowId);
		}
	}

	// Reactive statements
	$: applyFilters();
</script>

<div class="task-assignment-view bg-white rounded-lg shadow-lg p-6 h-full flex flex-col">
	<!-- Header -->
	<div class="flex items-center justify-between border-b pb-4 mb-6">
		<div class="flex items-center space-x-3">
			<div class="bg-purple-100 p-2 rounded-lg">
				<svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
				</svg>
			</div>
			<div>
				<h2 class="text-xl font-bold text-gray-900">Assign Tasks</h2>
				<p class="text-sm text-gray-500">Select tasks and users to create assignments</p>
			</div>
		</div>
		<button
			on:click={loadData}
			class="bg-purple-100 hover:bg-purple-200 text-purple-700 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
			title="Refresh Data"
		>
			<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
			</svg>
			<span>Refresh</span>
		</button>
	</div>

	{#if isLoading}
		<div class="flex items-center justify-center flex-1">
			<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600"></div>
		</div>
	{:else}
		<div class="flex-1 grid grid-cols-1 lg:grid-cols-2 gap-6">
			<!-- Tasks Section -->
			<div class="space-y-4">
				<div class="flex items-center justify-between">
					<h3 class="text-lg font-medium text-gray-900">Select Tasks</h3>
					<span class="text-sm text-gray-500">
						{selectedTasks.size} of {filteredTasks.length} selected
					</span>
				</div>

				<!-- Task Filters -->
				<div class="space-y-3">
					<input
						type="text"
						bind:value={taskSearchTerm}
						placeholder="Search tasks..."
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
					/>
					
					<select
						bind:value={taskStatusFilter}
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
					>
						<option value="">All Task Statuses</option>
						{#each taskStatuses as status}
							<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
						{/each}
					</select>
				</div>

				<!-- Select All Tasks -->
				<label class="flex items-center space-x-2">
					<input
						type="checkbox"
						bind:checked={selectAllTasks}
						on:change={handleSelectAllTasks}
						class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
					/>
					<span class="text-sm text-gray-700">Select all filtered tasks</span>
				</label>

				<!-- Tasks List -->
				<div class="border rounded-lg max-h-96 overflow-y-auto">
					{#each filteredTasks as task}
						<label class="flex items-start space-x-3 p-3 hover:bg-gray-50 border-b last:border-b-0 cursor-pointer">
							<input
								type="checkbox"
								checked={selectedTasks.has(task.id)}
								on:change={(e) => handleTaskSelect(task.id, e.target?.checked || false)}
								class="w-4 h-4 mt-1 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
							/>
							<div class="flex-1 min-w-0">
								<p class="text-sm font-medium text-gray-900 truncate">{task.title}</p>
								<p class="text-xs text-gray-500 mt-1 line-clamp-2">{task.description}</p>
								<div class="flex items-center space-x-2 mt-2">
									<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium {getStatusBadgeClass(task.status)}">
										{task.status.charAt(0).toUpperCase() + task.status.slice(1)}
									</span>
									<span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium {getPriorityBadgeClass(task.priority)}">
										{task.priority.charAt(0).toUpperCase() + task.priority.slice(1)}
									</span>
									{#if task.due_date}
										<span class="text-xs text-gray-500">Due: {formatDate(task.due_date)}</span>
									{/if}
								</div>
							</div>
						</label>
					{/each}
					
					{#if filteredTasks.length === 0}
						<div class="p-8 text-center text-gray-500">
							<svg class="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
							</svg>
							<p>No assignable tasks found</p>
						</div>
					{/if}
				</div>
			</div>

			<!-- Users Section -->
			<div class="space-y-4">
				<div class="flex items-center justify-between">
					<h3 class="text-lg font-medium text-gray-900">Select Users</h3>
					<span class="text-sm text-gray-500">
						{selectedUsers.size} of {filteredUsers.length} selected
					</span>
				</div>

				<!-- User Filters -->
				<div class="space-y-3">
					<input
						type="text"
						bind:value={userSearchTerm}
						placeholder="Search users..."
						class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
					/>
					
					<div class="grid grid-cols-2 gap-3">
						<select
							bind:value={selectedBranch}
							class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						>
							<option value="">All Branches</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name}</option>
							{/each}
						</select>

						<select
							bind:value={selectedRole}
							class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						>
							<option value="">All Roles</option>
							{#each userRoles as role}
								<option value={role}>{role}</option>
							{/each}
						</select>
					</div>
				</div>

				<!-- Select All Users -->
				<label class="flex items-center space-x-2">
					<input
						type="checkbox"
						bind:checked={selectAllUsers}
						on:change={handleSelectAllUsers}
						class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
					/>
					<span class="text-sm text-gray-700">Select all filtered users</span>
				</label>

				<!-- Users List -->
				<div class="border rounded-lg max-h-96 overflow-y-auto">
					{#each filteredUsers as user}
						<label class="flex items-center space-x-3 p-3 hover:bg-gray-50 border-b last:border-b-0 cursor-pointer">
							<input
								type="checkbox"
								checked={selectedUsers.has(user.id)}
								on:change={(e) => handleUserSelect(user.id, e.target?.checked || false)}
								class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
							/>
							<div class="flex-1">
								<p class="text-sm font-medium text-gray-900">{user.name}</p>
								<p class="text-xs text-gray-500">{user.email}</p>
								<div class="flex items-center space-x-2 mt-1">
									<span class="text-xs text-gray-500">{user.role}</span>
									{#if user.branch_name}
										<span class="text-xs text-gray-500">• {user.branch_name}</span>
									{/if}
								</div>
							</div>
						</label>
					{/each}

					{#if filteredUsers.length === 0}
						<div class="p-8 text-center text-gray-500">
							<svg class="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
							</svg>
							<p>No users found</p>
						</div>
					{/if}
				</div>
			</div>
		</div>

		<!-- Assignment Settings -->
		<div class="border-t pt-6 space-y-4">
			<h3 class="text-lg font-medium text-gray-900">Assignment Settings</h3>
			
			<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
				<!-- Left Column -->
				<div class="space-y-4">
					<label class="flex items-center space-x-2">
						<input
							type="checkbox"
							bind:checked={assignmentSettings.notify_assignees}
							class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
						/>
						<span class="text-sm text-gray-700">Notify assignees via email</span>
					</label>

					<label class="flex items-center space-x-2">
						<input
							type="checkbox"
							bind:checked={assignmentSettings.set_deadline}
							class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
						/>
						<span class="text-sm text-gray-700">Set assignment deadline</span>
					</label>

					{#if assignmentSettings.set_deadline}
						<input
							type="datetime-local"
							bind:value={assignmentSettings.deadline}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						/>
					{/if}
				</div>

				<!-- Right Column -->
				<div class="space-y-4">
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Priority Override</label>
						<select
							bind:value={assignmentSettings.priority_override}
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						>
							<option value="">Keep original priority</option>
							<option value="low">Low</option>
							<option value="medium">Medium</option>
							<option value="high">High</option>
							<option value="urgent">Urgent</option>
						</select>
					</div>

					<div>
						<label class="block text-sm font-medium text-gray-700 mb-2">Assignment Note</label>
						<textarea
							bind:value={assignmentSettings.add_note}
							rows="3"
							placeholder="Add a note for assignees..."
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						></textarea>
					</div>
				</div>
			</div>
		</div>

		<!-- Assignment Summary -->
		{#if selectedTasks.size > 0 || selectedUsers.size > 0}
			<div class="bg-purple-50 border border-purple-200 rounded-lg p-4 mt-6">
				<h4 class="text-sm font-medium text-purple-900 mb-2">Assignment Summary</h4>
				<p class="text-sm text-purple-700">
					{selectedTasks.size} task{selectedTasks.size !== 1 ? 's' : ''} will be assigned to 
					{selectedUsers.size} user{selectedUsers.size !== 1 ? 's' : ''}, creating 
					<strong>{selectedTasks.size * selectedUsers.size}</strong> total assignment{selectedTasks.size * selectedUsers.size !== 1 ? 's' : ''}
				</p>
			</div>
		{/if}

		<!-- Action Buttons -->
		<div class="flex justify-end space-x-4 border-t pt-6">
			<button
				on:click={closeWindow}
				class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-500"
				disabled={isAssigning}
			>
				Close
			</button>
			<button
				on:click={assignTasksToUsers}
				disabled={selectedTasks.size === 0 || selectedUsers.size === 0 || isAssigning}
				class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
			>
				{#if isAssigning}
					<svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
					</svg>
					<span>Assigning Tasks...</span>
				{:else}
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
					</svg>
					<span>Assign Tasks</span>
				{/if}
			</button>
		</div>
	{/if}
</div>

<style>
	.task-assignment-view {
		max-height: calc(100vh - 100px);
	}

	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
</style>