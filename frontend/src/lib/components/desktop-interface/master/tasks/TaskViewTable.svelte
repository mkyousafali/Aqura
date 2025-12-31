<script lang="ts">
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { deleteTask as deleteTaskStore, loadTasks, searchTasks } from '$lib/stores/taskStore';
	import { db } from '$lib/utils/supabase';
	import TaskCreateForm from './TaskCreateForm.svelte';

	export let windowId: string = '';

	// Task data
	let tasks: any[] = [];
	let filteredTasks: any[] = [];
	let isLoading = true;

	// Pagination
	let currentPage = 1;
	let itemsPerPage = 10;
	let totalItems = 0;
	let totalPages = 0;

	// Search and filters
	let searchTerm = '';
	let statusFilter = '';
	let priorityFilter = '';
	let sortBy = 'created_at';
	let sortOrder = 'desc';

	// Selection
	let selectedTasks: Set<string> = new Set();
	let selectAll = false;

	// Image modal
	let showImageModal = false;
	let modalImageUrl = '';

	// Task statuses and priorities
	const taskStatuses = ['draft', 'active', 'paused', 'completed', 'cancelled'];
	const taskPriorities = ['low', 'medium', 'high', 'urgent'];

	onMount(() => {
		loadTasksFromSupabase();
	});

	async function loadTasksFromSupabase() {
		try {
			isLoading = true;
			
			// Calculate offset for pagination
			const offset = (currentPage - 1) * itemsPerPage;
			
			// If there's a search term, use search function
			let result;
			if (searchTerm.trim()) {
				result = await searchTasks(
					searchTerm.trim(), 
					'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', 
					itemsPerPage, 
					offset
				);
			} else {
				result = await loadTasks(itemsPerPage, offset, statusFilter);
			}

			if (result.success) {
				tasks = result.data || [];
				
				// Load image data for each task
				for (let task of tasks) {
					try {
						console.log(`Loading images for task: ${task.id} (${task.title})`);
						const imageResult = await db.taskImages.getByTaskId(task.id);
						console.log(`Image result for task ${task.id}:`, imageResult);
						
						if (imageResult.data && imageResult.data.length > 0) {
							// Get the first image URL - note: column is 'file_url' not 'image_url'
							task.image_url = imageResult.data[0].file_url;
							console.log(`Found image for task ${task.id}: ${task.image_url}`);
						} else {
							console.log(`No images found for task ${task.id}`);
							// Check if task might have image stored differently (for debugging)
							if (task.title.toLowerCase().includes('image')) {
								console.warn(`Task "${task.title}" suggests it has an image but none found in database`);
							}
						}
					} catch (error) {
						console.warn(`Failed to load image for task ${task.id}:`, error);
					}
				}
				
				totalItems = result.total || 0;
				totalPages = Math.ceil(totalItems / itemsPerPage);
				filterTasks();
			} else {
				console.error('Error loading tasks:', result.error);
				notifications.add({
					type: 'error',
					message: 'Failed to load tasks',
					duration: 5000
				});
			}
		} catch (error) {
			console.error('Error loading tasks:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load tasks',
				duration: 5000
			});
		} finally {
			isLoading = false;
		}
	}

	function filterTasks() {
		filteredTasks = [...tasks];
		
		// Update selection state
		updateSelectAllState();
	}

	function updateSelectAllState() {
		if (filteredTasks.length === 0) {
			selectAll = false;
		} else {
			selectAll = filteredTasks.every(task => selectedTasks.has(task.id));
		}
	}

	function handleSelectAll() {
		if (selectAll) {
			filteredTasks.forEach(task => selectedTasks.add(task.id));
		} else {
			filteredTasks.forEach(task => selectedTasks.delete(task.id));
		}
		selectedTasks = new Set(selectedTasks);
	}

	function handleTaskSelect(taskId: string, checked: boolean) {
		if (checked) {
			selectedTasks.add(taskId);
		} else {
			selectedTasks.delete(taskId);
		}
		selectedTasks = new Set(selectedTasks);
		updateSelectAllState();
	}

	function handleSearch() {
		currentPage = 1;
		loadTasksFromSupabase();
	}

	function handleFilterChange() {
		currentPage = 1;
		loadTasksFromSupabase();
	}

	function handleSort(column: string) {
		if (sortBy === column) {
			sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
		} else {
			sortBy = column;
			sortOrder = 'asc';
		}
		loadTasksFromSupabase();
	}

	function changePage(page: number) {
		currentPage = page;
		loadTasksFromSupabase();
	}

	async function deleteTask(taskId: string) {
		if (!confirm('Are you sure you want to delete this task?')) {
			return;
		}

		try {
			const result = await deleteTaskStore(taskId);
			
			if (result.success) {
				notifications.add({
					type: 'success',
					message: 'Task deleted successfully',
					duration: 3000
				});
				loadTasksFromSupabase(); // Reload to sync UI
			} else {
				throw new Error(result.error || 'Failed to delete task');
			}
		} catch (error) {
			notifications.add({
				type: 'error',
				message: error.message || 'Failed to delete task',
				duration: 5000
			});
		}
	}

	function editTask(task: any) {
		// Open the task creation form in edit mode
		openWindow({
			id: `edit-task-${task.id}`,
			title: `Edit Task: ${task.title}`,
			component: TaskCreateForm,
			props: { 
				editMode: true, 
				taskData: task,
				onTaskUpdated: () => {
					loadTasksFromSupabase(); // Refresh the tasks list after update
				}
			},
			size: { width: 800, height: 600 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function updateTaskStatus(taskId: string, newStatus: string) {
		try {
			const { data, error } = await db.tasks.update(taskId, { status: newStatus });

			if (error) {
				throw error;
			}

			notifications.add({
				type: 'success',
				message: `Task status updated to ${newStatus}`,
				duration: 3000
			});
			loadTasksFromSupabase();
		} catch (error) {
			console.error('Failed to update task status:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to update task status',
				duration: 5000
			});
		}
	}

	function formatDate(dateString: string) {
		if (!dateString) return '-';
		const date = new Date(dateString);
		return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	}

	function getStatusBadgeClass(status: string) {
		switch (status) {
			case 'draft': return 'bg-gray-100 text-gray-800';
			case 'active': return 'bg-green-100 text-green-800';
			case 'paused': return 'bg-yellow-100 text-yellow-800';
			case 'completed': return 'bg-blue-100 text-blue-800';
			case 'cancelled': return 'bg-red-100 text-red-800';
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

	function openImageModal(imageUrl: string) {
		console.log('Opening image modal with URL:', imageUrl);
		modalImageUrl = imageUrl;
		showImageModal = true;
	}

	function closeImageModal() {
		showImageModal = false;
		modalImageUrl = '';
	}
</script>

<div class="task-view-table bg-white rounded-lg shadow-lg p-6 h-full flex flex-col">
	<!-- Header -->
	<div class="flex items-center justify-between border-b pb-4 mb-6">
		<div class="flex items-center space-x-3">
			<div class="bg-blue-100 p-2 rounded-lg">
				<svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
				</svg>
			</div>
			<div>
				<h2 class="text-xl font-bold text-gray-900">View Tasks</h2>
				<p class="text-sm text-gray-500">Manage and monitor all created tasks</p>
			</div>
		</div>
		<button
			on:click={loadTasks}
			class="bg-blue-100 hover:bg-blue-200 text-blue-700 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
			title="Refresh Tasks"
		>
			<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
			</svg>
			<span>Refresh</span>
		</button>
	</div>

	<!-- Search and Filters -->
	<div class="flex flex-col lg:flex-row gap-4 mb-6">
		<!-- Search Bar -->
		<div class="flex-1">
			<div class="relative">
				<input
					type="text"
					bind:value={searchTerm}
					on:keydown={(e) => e.key === 'Enter' && handleSearch()}
					placeholder="Search tasks by title, description, or tags..."
					class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
				/>
				<div class="absolute inset-y-0 left-0 pl-3 flex items-center">
					<svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
					</svg>
				</div>
			</div>
		</div>

		<!-- Filters -->
		<div class="flex space-x-4">
			<select
				bind:value={statusFilter}
				on:change={handleFilterChange}
				class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
			>
				<option value="">All Statuses</option>
				{#each taskStatuses as status}
					<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
				{/each}
			</select>

			<select
				bind:value={priorityFilter}
				on:change={handleFilterChange}
				class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
			>
				<option value="">All Priorities</option>
				{#each taskPriorities as priority}
					<option value={priority}>{priority.charAt(0).toUpperCase() + priority.slice(1)}</option>
				{/each}
			</select>

			<button
				on:click={handleSearch}
				class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
				</svg>
				<span>Search</span>
			</button>
		</div>
	</div>

	<!-- Selected Actions -->
	{#if selectedTasks.size > 0}
		<div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
			<div class="flex items-center justify-between">
				<p class="text-sm text-blue-800">
					{selectedTasks.size} task{selectedTasks.size !== 1 ? 's' : ''} selected
				</p>
				<div class="flex space-x-2">
					<button class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-sm">
						Bulk Edit
					</button>
					<button class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded text-sm">
						Delete Selected
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Table -->
	<div class="flex-1 overflow-auto">
		{#if isLoading}
			<div class="flex items-center justify-center h-64">
				<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
			</div>
		{:else if filteredTasks.length === 0}
			<div class="flex items-center justify-center h-64">
				<div class="text-center">
					<svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
					</svg>
					<p class="text-gray-500 text-lg">No tasks found</p>
					<p class="text-gray-400 text-sm mt-1">Try adjusting your search or filters</p>
				</div>
			</div>
		{:else}
			<table class="w-full">
				<thead class="bg-gray-50">
					<tr>
						<th class="px-6 py-3 text-left">
							<input
								type="checkbox"
								bind:checked={selectAll}
								on:change={handleSelectAll}
								class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
							/>
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
							<button
								on:click={() => handleSort('title')}
								class="flex items-center space-x-1 hover:text-gray-700"
							>
								<span>Title</span>
								{#if sortBy === 'title'}
									<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										{#if sortOrder === 'asc'}
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
										{:else}
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
										{/if}
									</svg>
								{/if}
							</button>
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
							Image
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
							Status
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
							Priority
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
							<button
								on:click={() => handleSort('due_date')}
								class="flex items-center space-x-1 hover:text-gray-700"
							>
								<span>Due Date</span>
								{#if sortBy === 'due_date'}
									<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										{#if sortOrder === 'asc'}
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
										{:else}
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
										{/if}
									</svg>
								{/if}
							</button>
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
							<button
								on:click={() => handleSort('created_at')}
								class="flex items-center space-x-1 hover:text-gray-700"
							>
								<span>Created</span>
								{#if sortBy === 'created_at'}
									<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										{#if sortOrder === 'asc'}
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
										{:else}
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
										{/if}
									</svg>
								{/if}
							</button>
						</th>
						<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
							Actions
						</th>
					</tr>
				</thead>
				<tbody class="bg-white divide-y divide-gray-200">
					{#each filteredTasks as task}
						<tr class="hover:bg-gray-50">
							<td class="px-6 py-4">
								<input
									type="checkbox"
									checked={selectedTasks.has(task.id)}
									on:change={(e) => handleTaskSelect(task.id, e.target?.checked || false)}
									class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
								/>
							</td>
							<td class="px-6 py-4">
								<div class="max-w-xs">
									<p class="text-sm font-medium text-gray-900 truncate" title={task.title}>
										{task.title}
									</p>
									{#if task.description}
										<p class="text-xs text-gray-500 truncate mt-1" title={task.description}>
											{task.description}
										</p>
									{/if}
								</div>
							</td>
							<td class="px-6 py-4">
								{#if task.image_url}
									<div class="flex items-center">
										<button
											type="button"
											on:click={() => openImageModal(task.image_url)}
											class="relative group focus:outline-none focus:ring-2 focus:ring-blue-500 rounded-lg"
											title="Click to view full image"
										>
											<img 
												src={task.image_url} 
												alt="Task image for {task.title}"
												class="w-12 h-12 object-cover rounded-lg border border-gray-200 hover:opacity-80 transition-opacity"
												on:error={(e) => {
													console.error('Failed to load image:', task.image_url);
													e.target.style.display = 'none';
													e.target.parentElement.nextElementSibling.style.display = 'flex';
												}}
											/>
											<div class="absolute inset-0 rounded-lg bg-black bg-opacity-0 hover:bg-opacity-10 transition-all flex items-center justify-center opacity-0 hover:opacity-100">
												<svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
												</svg>
											</div>
										</button>
										<div class="w-12 h-12 bg-gray-100 rounded-lg border border-gray-200 flex items-center justify-center text-gray-400 hidden">
											<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
											</svg>
										</div>
									</div>
								{:else}
									<div class="w-12 h-12 bg-gray-100 rounded-lg border border-gray-200 flex items-center justify-center text-gray-400">
										<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
										</svg>
									</div>
								{/if}
							</td>
							<td class="px-6 py-4">
								<select
									value={task.status}
									on:change={(e) => updateTaskStatus(task.id, e.target?.value || task.status)}
									class="text-xs px-2 py-1 rounded-full {getStatusBadgeClass(task.status)}"
								>
									{#each taskStatuses as status}
										<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
									{/each}
								</select>
							</td>
							<td class="px-6 py-4">
								<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getPriorityBadgeClass(task.priority)}">
									{task.priority.charAt(0).toUpperCase() + task.priority.slice(1)}
								</span>
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
								{formatDate(task.due_date)}
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
								{formatDate(task.created_at)}
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
								<div class="flex items-center space-x-2">
									<button
										on:click={() => editTask(task)}
										class="text-blue-600 hover:text-blue-900"
										title="Edit Task"
									>
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
										</svg>
									</button>
									<button
										on:click={() => deleteTask(task.id)}
										class="text-red-600 hover:text-red-900"
										title="Delete Task"
									>
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
										</svg>
									</button>
								</div>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>

	<!-- Pagination -->
	{#if totalPages > 1}
		<div class="flex items-center justify-between border-t bg-white px-4 py-3 sm:px-6 mt-6">
			<div class="flex flex-1 justify-between sm:hidden">
				<button
					on:click={() => changePage(currentPage - 1)}
					disabled={currentPage <= 1}
					class="relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
				>
					Previous
				</button>
				<button
					on:click={() => changePage(currentPage + 1)}
					disabled={currentPage >= totalPages}
					class="relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
				>
					Next
				</button>
			</div>
			<div class="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
				<div>
					<p class="text-sm text-gray-700">
						Showing <span class="font-medium">{(currentPage - 1) * itemsPerPage + 1}</span>
						to <span class="font-medium">{Math.min(currentPage * itemsPerPage, totalItems)}</span>
						of <span class="font-medium">{totalItems}</span> results
					</p>
				</div>
				<div>
					<nav class="isolate inline-flex -space-x-px rounded-md shadow-sm">
						<button
							on:click={() => changePage(currentPage - 1)}
							disabled={currentPage <= 1}
							class="relative inline-flex items-center rounded-l-md border border-gray-300 bg-white px-2 py-2 text-sm font-medium text-gray-500 hover:bg-gray-50 focus:z-20 disabled:opacity-50"
						>
							<span class="sr-only">Previous</span>
							<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
								<path fill-rule="evenodd" d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z" clip-rule="evenodd"/>
							</svg>
						</button>

						{#each Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
							const page = Math.max(1, Math.min(currentPage - 2 + i, totalPages - 4 + i + 1));
							return page;
						}) as page}
							<button
								on:click={() => changePage(page)}
								class="relative inline-flex items-center border border-gray-300 px-4 py-2 text-sm font-medium {currentPage === page ? 'bg-blue-50 text-blue-600 border-blue-500 z-10' : 'bg-white text-gray-500 hover:bg-gray-50'}"
							>
								{page}
							</button>
						{/each}

						<button
							on:click={() => changePage(currentPage + 1)}
							disabled={currentPage >= totalPages}
							class="relative inline-flex items-center rounded-r-md border border-gray-300 bg-white px-2 py-2 text-sm font-medium text-gray-500 hover:bg-gray-50 focus:z-20 disabled:opacity-50"
						>
							<span class="sr-only">Next</span>
							<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
								<path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd"/>
							</svg>
						</button>
					</nav>
				</div>
			</div>
		</div>
	{/if}
</div>

<!-- Image Modal -->
{#if showImageModal}
	<div 
		class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" 
		on:click={closeImageModal}
		on:keydown={(e) => e.key === 'Escape' && closeImageModal()}
		role="dialog"
		aria-modal="true"
		tabindex="-1"
	>
		<div class="bg-white rounded-lg p-4 max-w-4xl max-h-[90vh] overflow-auto" on:click|stopPropagation>
			<div class="flex justify-between items-center mb-4">
				<h3 class="text-lg font-medium text-gray-900">Task Image</h3>
				<button
					on:click={closeImageModal}
					class="text-gray-400 hover:text-gray-600 transition-colors"
					aria-label="Close image modal"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
					</svg>
				</button>
			</div>
			<div class="flex justify-center">
				<img 
					src={modalImageUrl} 
					alt="Task image" 
					class="max-w-full h-auto rounded-lg shadow-lg"
					on:error={() => {
						notifications.add({
							type: 'error',
							message: 'Failed to load image',
							duration: 3000
						});
						closeImageModal();
					}}
				/>
			</div>
		</div>
	</div>
{/if}

<style>
	.task-view-table {
		max-height: calc(100vh - 100px);
	}
</style>
