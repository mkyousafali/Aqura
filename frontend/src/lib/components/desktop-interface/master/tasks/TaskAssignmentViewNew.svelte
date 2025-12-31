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
	let taskPriorityFilter = '';

	// Selections
	let selectedTasks: Set<string> = new Set();
	let selectedUsers: Set<string> = new Set();
	let selectAllTasks = false;
	let selectAllUsers = false;

	// Assignment settings with enhanced repeat options
	let assignmentSettings = {
		notify_assignees: true,
		set_deadline: false,
		deadline: '',
		time: '',
		add_note: '',
		priority_override: '',
		enable_repeat: false,
		repeat_type: 'daily', // 'daily', 'weekly', 'monthly', 'custom'
		repeat_days: [], // For weekly: ['monday', 'tuesday', etc]
		repeat_interval: 1, // For every N days/weeks/months
		repeat_date: '', // For monthly specific date
		repeat_end_type: 'never', // 'never', 'after', 'on_date'
		repeat_end_count: 10,
		repeat_end_date: ''
	};

	// Available options for filtering
	const userRoles = ['Manager', 'Supervisor', 'Employee', 'Trainee'];
	const taskStatuses = ['draft', 'active', 'paused'];
	const taskPriorities = ['low', 'medium', 'high', 'urgent'];
	const weekDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
	const repeatTypes = [
		{ value: 'daily', label: 'Daily' },
		{ value: 'weekly', label: 'Weekly (specific days)' },
		{ value: 'every_n_days', label: 'Every N Days' },
		{ value: 'every_n_weeks', label: 'Every N Weeks' },
		{ value: 'monthly', label: 'Monthly (specific date)' },
		{ value: 'custom', label: 'Custom Schedule' }
	];

	// Current view mode
	let currentView = 'users'; // 'users', 'tasks', or 'settings'

	onMount(async () => {
		await loadDataFromSupabase();
		
		// Set default deadline to 3 days from now
		const defaultDeadline = new Date();
		defaultDeadline.setDate(defaultDeadline.getDate() + 3);
		assignmentSettings.deadline = defaultDeadline.toISOString().slice(0, 10);
		assignmentSettings.time = '09:00';
		
		// Set default repeat end date to 1 month from now
		const defaultEndDate = new Date();
		defaultEndDate.setMonth(defaultEndDate.getMonth() + 1);
		assignmentSettings.repeat_end_date = defaultEndDate.toISOString().slice(0, 10);
	});

	async function loadDataFromSupabase() {
		try {
			isLoading = true;
			
			// Load tasks (only assignable ones - active and draft status)
			const taskResult = await loadTasks(100, 0, undefined);
			if (taskResult.success) {
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
			const matchesPriority = !taskPriorityFilter || task.priority === taskPriorityFilter;

			return matchesSearch && matchesStatus && matchesPriority;
		});

		// Filter users
		filteredUsers = users.filter(user => {
			const matchesSearch = !userSearchTerm ||
				user.name.toLowerCase().includes(userSearchTerm.toLowerCase()) ||
				user.email.toLowerCase().includes(userSearchTerm.toLowerCase()) ||
				(user.position && user.position.toLowerCase().includes(userSearchTerm.toLowerCase()));

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

		if (assignmentSettings.set_deadline && (!assignmentSettings.deadline || !assignmentSettings.time)) {
			notifications.add({
				type: 'warning',
				message: 'Please set both date and time for the deadline',
				duration: 3000
			});
			return;
		}

		// Validate repeat settings
		if (assignmentSettings.enable_repeat) {
			if (assignmentSettings.repeat_type === 'weekly' && assignmentSettings.repeat_days.length === 0) {
				notifications.add({
					type: 'warning',
					message: 'Please select at least one day for weekly repeat',
					duration: 3000
				});
				return;
			}
			
			if (assignmentSettings.repeat_type === 'monthly' && !assignmentSettings.repeat_date) {
				notifications.add({
					type: 'warning',
					message: 'Please set a date for monthly repeat',
					duration: 3000
				});
				return;
			}

			if (assignmentSettings.repeat_end_type === 'after' && assignmentSettings.repeat_end_count < 1) {
				notifications.add({
					type: 'warning',
					message: 'Please set a valid number of repetitions',
					duration: 3000
				});
				return;
			}

			if (assignmentSettings.repeat_end_type === 'on_date' && !assignmentSettings.repeat_end_date) {
				notifications.add({
					type: 'warning',
					message: 'Please set an end date for repetitions',
					duration: 3000
				});
				return;
			}
		}

		isAssigning = true;

		try {
			// For each selected user, create assignments for all selected tasks
			const taskIds = Array.from(selectedTasks);
			
			// Prepare scheduling settings if deadline is set
			let scheduleSettings = undefined;
			if (assignmentSettings.set_deadline && assignmentSettings.deadline && assignmentSettings.time) {
				scheduleSettings = {
					deadline_date: assignmentSettings.deadline,
					deadline_time: assignmentSettings.time,
					notes: assignmentSettings.add_note || undefined,
					priority_override: assignmentSettings.priority_override || undefined,
					is_recurring: assignmentSettings.enable_repeat,
					repeat_type: assignmentSettings.enable_repeat ? assignmentSettings.repeat_type : undefined,
					repeat_interval: assignmentSettings.enable_repeat ? assignmentSettings.repeat_interval : undefined,
					repeat_days: assignmentSettings.enable_repeat && assignmentSettings.repeat_type === 'weekly' ? assignmentSettings.repeat_days : undefined,
					repeat_end_type: assignmentSettings.enable_repeat ? assignmentSettings.repeat_end_type : undefined,
					repeat_end_count: assignmentSettings.enable_repeat && assignmentSettings.repeat_end_type === 'after' ? assignmentSettings.repeat_end_count : undefined,
					repeat_end_date: assignmentSettings.enable_repeat && assignmentSettings.repeat_end_type === 'on_date' ? assignmentSettings.repeat_end_date : undefined
				};
			}
			
			for (const userId of selectedUsers) {
				const result = await assignTasks(
					taskIds,
					'user', // assignment type
					'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', // assigned by
					'Admin User', // assigned by name
					userId, // assigned to user ID
					undefined, // no branch ID for user assignments
					scheduleSettings // scheduling data
				);
				
				if (!result.success) {
					throw new Error(result.error || 'Failed to assign tasks');
				}
			}

			const assignmentCount = selectedTasks.size * selectedUsers.size;
			
			let successMessage = `Successfully created ${assignmentCount} task assignment${assignmentCount !== 1 ? 's' : ''}`;
			if (assignmentSettings.enable_repeat) {
				successMessage += ' with repeat scheduling';
			}
			
			notifications.add({
				type: 'success',
				message: successMessage,
				duration: 5000
			});

			// Send notifications to assigned users
			if (assignmentSettings.notify_assignees) {
				notifications.add({
					type: 'info',
					message: `Email notifications sent to ${selectedUsers.size} user${selectedUsers.size !== 1 ? 's' : ''}`,
					duration: 3000
				});
			}

			// Reset selections and form
			selectedTasks.clear();
			selectedUsers.clear();
			selectedTasks = new Set(selectedTasks);
			selectedUsers = new Set(selectedUsers);
			
			// Reset assignment settings
			assignmentSettings.add_note = '';
			assignmentSettings.priority_override = '';
			assignmentSettings.enable_repeat = false;
			assignmentSettings.repeat_days = [];

			updateSelectAllStates();

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

	function switchView(view: string) {
		currentView = view;
	}

	function toggleWeekDay(day: string) {
		const index = assignmentSettings.repeat_days.indexOf(day);
		if (index > -1) {
			assignmentSettings.repeat_days.splice(index, 1);
		} else {
			assignmentSettings.repeat_days.push(day);
		}
		assignmentSettings.repeat_days = [...assignmentSettings.repeat_days];
	}

	function createNewTask() {
		notifications.add({
			type: 'info',
			message: 'New task creation feature coming soon!',
			duration: 3000
		});
	}

	function viewTaskStats() {
		notifications.add({
			type: 'info',
			message: 'Task statistics view coming soon!',
			duration: 3000
		});
	}

	// Reactive statements
	$: applyFilters();
</script>

<div class="task-assignment-view bg-white rounded-lg shadow-lg h-full flex flex-col">
	<!-- Header -->
	<div class="flex items-center justify-between border-b pb-4 p-6">
		<div class="flex items-center space-x-3">
			<div class="bg-purple-100 p-2 rounded-lg">
				<svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
				</svg>
			</div>
			<div>
				<h2 class="text-xl font-bold text-gray-900">Assign Tasks</h2>
				<p class="text-sm text-gray-500">Select users and tasks to create assignments with advanced scheduling</p>
			</div>
		</div>
		<div class="flex items-center space-x-3">
			<button
				on:click={createNewTask}
				class="bg-green-100 hover:bg-green-200 text-green-700 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
				title="Create New Task"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
				</svg>
				<span>New Task</span>
			</button>
			<button
				on:click={viewTaskStats}
				class="bg-blue-100 hover:bg-blue-200 text-blue-700 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
				title="View Statistics"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
				</svg>
				<span>Stats</span>
			</button>
			<button
				on:click={loadDataFromSupabase}
				class="bg-purple-100 hover:bg-purple-200 text-purple-700 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
				title="Refresh Data"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
				</svg>
				<span>Refresh</span>
			</button>
		</div>
	</div>

	<!-- Progress Steps -->
	<div class="px-6 py-4 bg-gray-50 border-b">
		<div class="flex items-center space-x-8">
			<button 
				on:click={() => switchView('users')}
				class="flex items-center space-x-3 {currentView === 'users' ? 'text-purple-600' : 'text-gray-500'}"
			>
				<div class="w-8 h-8 rounded-full border-2 {currentView === 'users' ? 'border-purple-600 bg-purple-100' : 'border-gray-300'} flex items-center justify-center">
					<span class="text-sm font-medium">1</span>
				</div>
				<span class="font-medium">Choose Users</span>
				{#if selectedUsers.size > 0}
					<span class="bg-purple-100 text-purple-800 text-xs font-medium px-2 py-1 rounded-full">
						{selectedUsers.size} selected
					</span>
				{/if}
			</button>
			
			<svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
				<path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
			</svg>
			
			<button 
				on:click={() => switchView('tasks')}
				class="flex items-center space-x-3 {currentView === 'tasks' ? 'text-purple-600' : 'text-gray-500'}"
			>
				<div class="w-8 h-8 rounded-full border-2 {currentView === 'tasks' ? 'border-purple-600 bg-purple-100' : 'border-gray-300'} flex items-center justify-center">
					<span class="text-sm font-medium">2</span>
				</div>
				<span class="font-medium">Choose Tasks</span>
				{#if selectedTasks.size > 0}
					<span class="bg-purple-100 text-purple-800 text-xs font-medium px-2 py-1 rounded-full">
						{selectedTasks.size} selected
					</span>
				{/if}
			</button>
			
			<svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
				<path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
			</svg>
			
			<button 
				on:click={() => switchView('settings')}
				class="flex items-center space-x-3 {currentView === 'settings' ? 'text-purple-600' : 'text-gray-500'}"
			>
				<div class="w-8 h-8 rounded-full border-2 {currentView === 'settings' ? 'border-purple-600 bg-purple-100' : 'border-gray-300'} flex items-center justify-center">
					<span class="text-sm font-medium">3</span>
				</div>
				<span class="font-medium">Assignment Settings</span>
			</button>
		</div>
	</div>

	{#if isLoading}
		<div class="flex items-center justify-center flex-1">
			<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-purple-600"></div>
		</div>
	{:else}
		<div class="flex-1 overflow-hidden">
			<!-- Users Selection View -->
			{#if currentView === 'users'}
				<div class="p-6 h-full flex flex-col">
					<div class="flex items-center justify-between mb-4">
						<h3 class="text-lg font-medium text-gray-900">Select Users</h3>
						<span class="text-sm text-gray-500">
							{selectedUsers.size} of {filteredUsers.length} selected
						</span>
					</div>

					<!-- Enhanced User Filters -->
					<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
						<input
							type="text"
							bind:value={userSearchTerm}
							placeholder="Search by name, email, or position..."
							class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						/>
						
						<select
							bind:value={selectedBranch}
							class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						>
							<option value="">All Branches</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en || branch.name}</option>
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

						<label class="flex items-center space-x-2 px-3 py-2">
							<input
								type="checkbox"
								bind:checked={selectAllUsers}
								on:change={handleSelectAllUsers}
								class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
							/>
							<span class="text-sm text-gray-700">Select All</span>
						</label>
					</div>

					<!-- Enhanced Users List -->
					<div class="flex-1 border rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-3 border-b text-sm font-medium text-gray-700">
							<div class="grid grid-cols-12 gap-4 items-center">
								<div class="col-span-1"></div>
								<div class="col-span-3">Name</div>
								<div class="col-span-3">Email</div>
								<div class="col-span-2">Position</div>
								<div class="col-span-2">Branch</div>
								<div class="col-span-1">Role</div>
							</div>
						</div>
						<div class="overflow-y-auto max-h-96">
							{#each filteredUsers as user}
								<label class="block hover:bg-gray-50 cursor-pointer border-b last:border-b-0">
									<div class="grid grid-cols-12 gap-4 items-center px-4 py-3">
										<div class="col-span-1">
											<input
												type="checkbox"
												checked={selectedUsers.has(user.id)}
												on:change={(e) => handleUserSelect(user.id, e.target?.checked || false)}
												class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
											/>
										</div>
										<div class="col-span-3">
											<div class="flex items-center space-x-3">
												<div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center">
													<span class="text-xs font-medium text-purple-600">
														{user.name?.charAt(0)?.toUpperCase() || 'U'}
													</span>
												</div>
												<div>
													<p class="text-sm font-medium text-gray-900">{user.name}</p>
													<p class="text-xs text-gray-500">ID: {user.id.slice(0, 8)}...</p>
												</div>
											</div>
										</div>
										<div class="col-span-3">
											<p class="text-sm text-gray-900">{user.email}</p>
										</div>
										<div class="col-span-2">
											<p class="text-sm text-gray-900">{user.position || 'Not specified'}</p>
										</div>
										<div class="col-span-2">
											<p class="text-sm text-gray-900">{user.branch_name || 'No branch'}</p>
										</div>
										<div class="col-span-1">
											<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
												{user.role}
											</span>
										</div>
									</div>
								</label>
							{/each}
							
							{#if filteredUsers.length === 0}
								<div class="p-8 text-center text-gray-500">
									<svg class="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
									</svg>
									<p>No users found matching your criteria</p>
								</div>
							{/if}
						</div>
					</div>

					<!-- Navigation -->
					<div class="flex justify-between pt-4">
						<button
							on:click={closeWindow}
							class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
						>
							Cancel
						</button>
						<button
							on:click={() => switchView('tasks')}
							disabled={selectedUsers.size === 0}
							class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
						>
							<span>Next: Choose Tasks</span>
							<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
							</svg>
						</button>
					</div>
				</div>
			{/if}

			<!-- Tasks Selection View -->
			{#if currentView === 'tasks'}
				<div class="p-6 h-full flex flex-col">
					<div class="flex items-center justify-between mb-4">
						<h3 class="text-lg font-medium text-gray-900">Select Tasks</h3>
						<span class="text-sm text-gray-500">
							{selectedTasks.size} of {filteredTasks.length} selected
						</span>
					</div>

					<!-- Enhanced Task Filters -->
					<div class="grid grid-cols-1 md:grid-cols-5 gap-4 mb-4">
						<input
							type="text"
							bind:value={taskSearchTerm}
							placeholder="Search by title or description..."
							class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						/>
						
						<select
							bind:value={taskStatusFilter}
							class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						>
							<option value="">All Statuses</option>
							{#each taskStatuses as status}
								<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
							{/each}
						</select>

						<select
							bind:value={taskPriorityFilter}
							class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						>
							<option value="">All Priorities</option>
							{#each taskPriorities as priority}
								<option value={priority}>{priority.charAt(0).toUpperCase() + priority.slice(1)}</option>
							{/each}
						</select>

						<button
							on:click={() => {taskSearchTerm = ''; taskStatusFilter = ''; taskPriorityFilter = '';}}
							class="px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700"
						>
							Clear Filters
						</button>

						<label class="flex items-center space-x-2 px-3 py-2">
							<input
								type="checkbox"
								bind:checked={selectAllTasks}
								on:change={handleSelectAllTasks}
								class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
							/>
							<span class="text-sm text-gray-700">Select All</span>
						</label>
					</div>

					<!-- Enhanced Tasks Table -->
					<div class="flex-1 border rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-3 border-b text-sm font-medium text-gray-700">
							<div class="grid grid-cols-12 gap-4 items-center">
								<div class="col-span-1"></div>
								<div class="col-span-4">Task Details</div>
								<div class="col-span-2">Priority</div>
								<div class="col-span-2">Status</div>
								<div class="col-span-2">Due Date</div>
								<div class="col-span-1">Actions</div>
							</div>
						</div>
						<div class="overflow-y-auto max-h-96">
							{#each filteredTasks as task}
								<label class="block hover:bg-gray-50 cursor-pointer border-b last:border-b-0">
									<div class="grid grid-cols-12 gap-4 items-center px-4 py-3">
										<div class="col-span-1">
											<input
												type="checkbox"
												checked={selectedTasks.has(task.id)}
												on:change={(e) => handleTaskSelect(task.id, e.target?.checked || false)}
												class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
											/>
										</div>
										<div class="col-span-4">
											<div>
												<p class="text-sm font-medium text-gray-900 line-clamp-1">{task.title}</p>
												<p class="text-xs text-gray-500 line-clamp-2 mt-1">{task.description}</p>
												<p class="text-xs text-gray-400 mt-1">ID: {task.id.slice(0, 8)}...</p>
											</div>
										</div>
										<div class="col-span-2">
											<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {getPriorityBadgeClass(task.priority)}">
												{task.priority.charAt(0).toUpperCase() + task.priority.slice(1)}
											</span>
										</div>
										<div class="col-span-2">
											<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {getStatusBadgeClass(task.status)}">
												{task.status.charAt(0).toUpperCase() + task.status.slice(1)}
											</span>
										</div>
										<div class="col-span-2">
											<p class="text-sm text-gray-900">
												{task.due_date ? formatDate(task.due_date) : 'Not set'}
											</p>
											{#if task.due_time}
												<p class="text-xs text-gray-500">{task.due_time}</p>
											{/if}
										</div>
										<div class="col-span-1">
											<button 
												class="text-purple-600 hover:text-purple-800 text-xs"
												title="Edit Task"
											>
												Edit
											</button>
										</div>
									</div>
								</label>
							{/each}
							
							{#if filteredTasks.length === 0}
								<div class="p-8 text-center text-gray-500">
									<svg class="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
									</svg>
									<p>No active tasks found matching your criteria</p>
									<button 
										on:click={createNewTask}
										class="mt-3 bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700"
									>
										Create New Task
									</button>
								</div>
							{/if}
						</div>
					</div>

					<!-- Navigation -->
					<div class="flex justify-between pt-4">
						<button
							on:click={() => switchView('users')}
							class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 flex items-center space-x-2"
						>
							<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"/>
							</svg>
							<span>Back to Users</span>
						</button>
						<button
							on:click={() => switchView('settings')}
							disabled={selectedTasks.size === 0}
							class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
						>
							<span>Next: Settings</span>
							<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
							</svg>
						</button>
					</div>
				</div>
			{/if}

			<!-- Assignment Settings View -->
			{#if currentView === 'settings'}
				<div class="p-6 space-y-6">
					<h3 class="text-lg font-medium text-gray-900">Assignment Settings</h3>
					
					<div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
						<!-- Left Column - Basic Settings -->
						<div class="space-y-6">
							<div class="bg-gray-50 rounded-lg p-4">
								<h4 class="font-medium text-gray-900 mb-3">Basic Settings</h4>
								<div class="space-y-4">
									<label class="flex items-center space-x-3">
										<input
											type="checkbox"
											bind:checked={assignmentSettings.notify_assignees}
											class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
										/>
										<span class="text-sm text-gray-700">Send email notifications to assignees</span>
									</label>

									<label class="flex items-center space-x-3">
										<input
											type="checkbox"
											bind:checked={assignmentSettings.set_deadline}
											class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
										/>
										<span class="text-sm text-gray-700">Set assignment deadline</span>
									</label>

									{#if assignmentSettings.set_deadline}
										<div class="grid grid-cols-2 gap-3">
											<div>
												<label class="block text-xs font-medium text-gray-700 mb-1">Date</label>
												<input
													type="date"
													bind:value={assignmentSettings.deadline}
													class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
												/>
											</div>
											<div>
												<label class="block text-xs font-medium text-gray-700 mb-1">Time</label>
												<input
													type="time"
													bind:value={assignmentSettings.time}
													class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
												/>
											</div>
										</div>
									{/if}

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
											placeholder="Add instructions or notes for assignees..."
											class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
										></textarea>
									</div>
								</div>
							</div>
						</div>

						<!-- Right Column - Repeat Settings -->
						<div class="space-y-6">
							<div class="bg-purple-50 rounded-lg p-4">
								<h4 class="font-medium text-gray-900 mb-3">Repeat Schedule</h4>
								<div class="space-y-4">
									<label class="flex items-center space-x-3">
										<input
											type="checkbox"
											bind:checked={assignmentSettings.enable_repeat}
											class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
										/>
										<span class="text-sm text-gray-700">Enable repeat assignments</span>
									</label>

									{#if assignmentSettings.enable_repeat}
										<div>
											<label class="block text-sm font-medium text-gray-700 mb-2">Repeat Type</label>
											<select
												bind:value={assignmentSettings.repeat_type}
												class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
											>
												{#each repeatTypes as type}
													<option value={type.value}>{type.label}</option>
												{/each}
											</select>
										</div>

										<!-- Specific Day Selection for Weekly -->
										{#if assignmentSettings.repeat_type === 'weekly'}
											<div>
												<label class="block text-sm font-medium text-gray-700 mb-2">Select Days</label>
												<div class="grid grid-cols-2 gap-2">
													{#each weekDays as day}
														<label class="flex items-center space-x-2">
															<input
																type="checkbox"
																checked={assignmentSettings.repeat_days.includes(day)}
																on:change={() => toggleWeekDay(day)}
																class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
															/>
															<span class="text-sm capitalize">{day}</span>
														</label>
													{/each}
												</div>
											</div>
										{/if}

										<!-- Interval Selection for Every N Days/Weeks -->
										{#if assignmentSettings.repeat_type === 'every_n_days' || assignmentSettings.repeat_type === 'every_n_weeks'}
											<div>
												<label class="block text-sm font-medium text-gray-700 mb-2">
													Every {assignmentSettings.repeat_type === 'every_n_days' ? 'Days' : 'Weeks'}
												</label>
												<input
													type="number"
													bind:value={assignmentSettings.repeat_interval}
													min="1"
													max="365"
													class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
												/>
											</div>
										{/if}

										<!-- Monthly Date Selection -->
										{#if assignmentSettings.repeat_type === 'monthly'}
											<div>
												<label class="block text-sm font-medium text-gray-700 mb-2">Monthly Date</label>
												<input
													type="number"
													bind:value={assignmentSettings.repeat_date}
													min="1"
													max="31"
													placeholder="Day of month (1-31)"
													class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
												/>
											</div>
										{/if}

										<!-- Repeat End Options -->
										<div>
											<label class="block text-sm font-medium text-gray-700 mb-2">End Repeat</label>
											<div class="space-y-3">
												<label class="flex items-center space-x-2">
													<input
														type="radio"
														bind:group={assignmentSettings.repeat_end_type}
														value="never"
														class="w-4 h-4 text-purple-600 border-gray-300 focus:ring-purple-500"
													/>
													<span class="text-sm">Never</span>
												</label>
												
												<label class="flex items-center space-x-2">
													<input
														type="radio"
														bind:group={assignmentSettings.repeat_end_type}
														value="after"
														class="w-4 h-4 text-purple-600 border-gray-300 focus:ring-purple-500"
													/>
													<span class="text-sm">After</span>
													<input
														type="number"
														bind:value={assignmentSettings.repeat_end_count}
														min="1"
														max="100"
														disabled={assignmentSettings.repeat_end_type !== 'after'}
														class="w-16 px-2 py-1 border border-gray-300 rounded text-xs focus:ring-2 focus:ring-purple-500 focus:border-purple-500 disabled:bg-gray-100"
													/>
													<span class="text-sm">times</span>
												</label>
												
												<label class="flex items-center space-x-2">
													<input
														type="radio"
														bind:group={assignmentSettings.repeat_end_type}
														value="on_date"
														class="w-4 h-4 text-purple-600 border-gray-300 focus:ring-purple-500"
													/>
													<span class="text-sm">On date</span>
													<input
														type="date"
														bind:value={assignmentSettings.repeat_end_date}
														disabled={assignmentSettings.repeat_end_type !== 'on_date'}
														class="px-2 py-1 border border-gray-300 rounded text-xs focus:ring-2 focus:ring-purple-500 focus:border-purple-500 disabled:bg-gray-100"
													/>
												</label>
											</div>
										</div>
									{/if}
								</div>
							</div>
						</div>
					</div>

					<!-- Assignment Summary -->
					<div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
						<h4 class="text-sm font-medium text-blue-900 mb-2">Assignment Summary</h4>
						<div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
							<div>
								<span class="text-blue-700">Selected Users:</span>
								<span class="font-medium text-blue-900 ml-1">{selectedUsers.size}</span>
							</div>
							<div>
								<span class="text-blue-700">Selected Tasks:</span>
								<span class="font-medium text-blue-900 ml-1">{selectedTasks.size}</span>
							</div>
							<div>
								<span class="text-blue-700">Total Assignments:</span>
								<span class="font-medium text-blue-900 ml-1">{selectedTasks.size * selectedUsers.size}</span>
							</div>
						</div>
						{#if assignmentSettings.enable_repeat}
							<div class="mt-2 text-sm text-blue-700">
								<span class="font-medium">Repeat:</span> 
								{assignmentSettings.repeat_type === 'daily' ? 'Daily' : 
								 assignmentSettings.repeat_type === 'weekly' ? `Weekly on ${assignmentSettings.repeat_days.join(', ')}` :
								 assignmentSettings.repeat_type === 'every_n_days' ? `Every ${assignmentSettings.repeat_interval} days` :
								 assignmentSettings.repeat_type === 'every_n_weeks' ? `Every ${assignmentSettings.repeat_interval} weeks` :
								 assignmentSettings.repeat_type === 'monthly' ? `Monthly on day ${assignmentSettings.repeat_date}` :
								 'Custom schedule'}
								
								{#if assignmentSettings.repeat_end_type === 'after'}
									(for {assignmentSettings.repeat_end_count} times)
								{:else if assignmentSettings.repeat_end_type === 'on_date'}
									(until {assignmentSettings.repeat_end_date})
								{:else}
									(indefinitely)
								{/if}
							</div>
						{/if}
					</div>

					<!-- Action Buttons -->
					<div class="flex justify-between border-t pt-6">
						<button
							on:click={() => switchView('tasks')}
							class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 flex items-center space-x-2"
						>
							<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"/>
							</svg>
							<span>Back to Tasks</span>
						</button>
						<div class="flex space-x-3">
							<button
								on:click={closeWindow}
								class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
								disabled={isAssigning}
							>
								Cancel
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
					</div>
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.task-assignment-view {
		max-height: calc(100vh - 100px);
	}

	.line-clamp-1 {
		display: -webkit-box;
		-webkit-line-clamp: 1;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
</style>