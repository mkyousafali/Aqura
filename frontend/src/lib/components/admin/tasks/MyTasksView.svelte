<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { windowManager } from '$lib/stores/windowManager';
	import TaskCompletionModal from './TaskCompletionModal.svelte';
	import TaskDetailsModal from './TaskDetailsModal.svelte';
	
	let tasks = [];
	let filteredTasks = [];
	let loading = true;
	let searchTerm = '';
	let filterStatus = 'all';
	let filterPriority = 'all';
	
	// Live countdown state
	let countdownInterval = null;
	
	// Image modal state
	let showImageModal = false;
	let selectedImageUrl = '';
	
	// Get current user from persistent auth service
	$: currentUserData = $currentUser;
	$: authenticated = $isAuthenticated;
	$: console.log('🔍 [MyTasks] Auth state:', { authenticated, currentUserData });

	// Subscribe to auth changes and reload tasks when user changes
	$: if (authenticated && currentUserData?.id) {
		loadMyTasks();
	}

	onMount(() => {
		// Try to load tasks on mount if user is available
		if (authenticated && currentUserData?.id) {
			loadMyTasks();
		}
		
		// Start live countdown timer
		startCountdownTimer();
		
		// Cleanup on unmount
		return () => {
			stopCountdownTimer();
		};
	});

	async function loadMyTasks() {
		// Get the current user ID from persistent auth
		let userId = currentUserData?.id;
		
		console.log('🔍 [MyTasks] Attempting to get user ID:', {
			currentUserData,
			authenticated,
			userId
		});
		
		if (!authenticated || !userId) {
			console.warn('❌ [MyTasks] No current user ID available or not authenticated');
			loading = false;
			return;
		}
		
		console.log('🔄 [MyTasks] Loading tasks for user:', userId);
		loading = true;
		try {
			// First, fetch task assignments with task details
			const { data, error } = await supabase
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
						created_by_name,
						created_by_role
					)
				`)
				.eq('assigned_to_user_id', userId)
				.order('assigned_at', { ascending: false });

			console.log('📊 [MyTasks] Query result:', { data, error, userID: userId });
			
			if (error) throw error;

			// Load task images and assigned_by user details for each task
			const tasksWithImages = await Promise.all(
				data.map(async (assignment) => {
					// Fetch task images
					const { data: images, error: imageError } = await supabase
						.from('task_images')
						.select('*')
						.eq('task_id', assignment.task.id);
					
					if (imageError) {
						console.error('Error loading task images:', imageError);
					}

					// Fetch assigned_by user details if assigned_by is a valid UUID
					let assignedByName = 'Unknown User';
					if (assignment.assigned_by) {
						// Check if assigned_by looks like a UUID (contains hyphens and is 36 characters)
						if (assignment.assigned_by.includes('-') && assignment.assigned_by.length === 36) {
							try {
								const { data: assignedByUser, error: userError } = await supabase
									.from('users')
									.select(`
										id,
										username,
										hr_employees!employee_id(
											name
										)
									`)
									.eq('id', assignment.assigned_by)
									.single();

								if (!userError && assignedByUser) {
									if (assignedByUser.hr_employees && assignedByUser.hr_employees.length > 0) {
										assignedByName = assignedByUser.hr_employees[0].name;
									} else {
										assignedByName = assignedByUser.username;
									}
								}
							} catch (err) {
								console.error('Error fetching assigned_by user:', err);
							}
						} else {
							// If assigned_by is not a UUID, use it as is (might be a username or name)
							assignedByName = assignment.assigned_by;
						}
					}
					
					// Use assigned_by_name as fallback
					if (assignedByName === 'Unknown User' && assignment.assigned_by_name) {
						assignedByName = assignment.assigned_by_name;
					}

					return {
						...assignment.task,
						assignment_id: assignment.id,
						assignment_status: assignment.status,
						assigned_at: assignment.assigned_at,
						assigned_by: assignment.assigned_by,
						assigned_by_name: assignedByName,
						assigned_to_user_id: assignment.assigned_to_user_id,
						schedule_date: assignment.schedule_date,
						schedule_time: assignment.schedule_time,
						deadline_date: assignment.deadline_date,
						deadline_time: assignment.deadline_time,
						deadline_datetime: assignment.deadline_datetime,
						// Assignment requirements
						require_task_finished: assignment.require_task_finished ?? false,
						require_photo_upload: assignment.require_photo_upload ?? false,
						require_erp_reference: assignment.require_erp_reference ?? false,
						// Task images
						images: images || []
					};
				})
			);

			tasks = tasksWithImages;
			filterTasks();
			console.log('✅ [MyTasks] Successfully loaded tasks:', tasks.length);
		} catch (error) {
			console.error('❌ [MyTasks] Error loading my tasks:', error);
		} finally {
			loading = false;
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

	function openTaskCompletion(task) {
		const windowId = `task-completion-${task.id}`;
		windowManager.openWindow({
			id: windowId,
			title: `Complete Task: ${task.title}`,
			component: TaskCompletionModal,
			props: {
				task: task,
				assignmentId: task.assignment_id,
				// Use actual requirements from the task/assignment data instead of forcing all to true
				requireTaskFinished: task.require_task_finished ?? false,
				requirePhotoUpload: task.require_photo_upload ?? false,
				requireErpReference: task.require_erp_reference ?? false,
				onTaskCompleted: () => {
					loadMyTasks();
					windowManager.closeWindow(windowId);
				}
			},
			icon: '✅',
			size: { width: 600, height: 700 },
			position: { 
				x: 100 + (Math.random() * 200), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openTaskDetails(task) {
		const windowId = `task-details-${task.id}`;
		windowManager.openWindow({
			id: windowId,
			title: `Task Details: ${task.title}`,
			component: TaskDetailsModal,
			props: {
				task: task,
				windowId: windowId,
				onTaskCompleted: () => {
					loadMyTasks();
				}
			},
			icon: '📋',
			size: { width: 800, height: 600 },
			position: { 
				x: 150 + (Math.random() * 100), 
				y: 100 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function formatDate(dateString) {
		if (!dateString) return '';
		return new Date(dateString).toLocaleDateString();
	}

	function formatTime(timeString) {
		if (!timeString) return '';
		return timeString.slice(0, 5);
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return 'text-red-600 bg-red-100';
			case 'medium': return 'text-yellow-600 bg-yellow-100';
			case 'low': return 'text-green-600 bg-green-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}

	function getStatusColor(status) {
		switch (status) {
			case 'pending': return 'text-blue-600 bg-blue-100';
			case 'in_progress': return 'text-yellow-600 bg-yellow-100';
			case 'completed': return 'text-green-600 bg-green-100';
			case 'cancelled': return 'text-red-600 bg-red-100';
			default: return 'text-gray-600 bg-gray-100';
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

	function getDeadlineDisplay(deadlineDate, deadlineTime) {
		if (!deadlineDate) return { text: 'No deadline set', class: 'text-gray-500' };
		
		const isLate = isOverdue(deadlineDate, deadlineTime);
		
		if (isLate) {
			const dateText = formatDate(deadlineDate);
			const timeText = deadlineTime ? ` at ${formatTime(deadlineTime)}` : '';
			return {
				text: `${dateText}${timeText}`,
				class: 'text-red-600 font-semibold',
				isOverdue: true
			};
		}
		
		// Calculate live countdown for non-overdue tasks
		const now = new Date();
		const deadline = new Date(deadlineDate);
		
		if (deadlineTime) {
			const [hours, minutes] = deadlineTime.split(':');
			deadline.setHours(parseInt(hours), parseInt(minutes));
		}
		
		const diffMs = deadline.getTime() - now.getTime();
		
		if (diffMs <= 0) {
			return {
				text: `Overdue`,
				class: 'text-red-600 font-semibold',
				isOverdue: true
			};
		}
		
		// Calculate exact time remaining
		const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
		const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
		const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
		
		// Format the countdown string
		let timeString = '';
		if (days > 0) {
			timeString += `${days} day${days !== 1 ? 's' : ''}`;
		}
		if (hours > 0) {
			if (timeString) timeString += ', ';
			timeString += `${hours} hour${hours !== 1 ? 's' : ''}`;
		}
		if (minutes > 0 || timeString === '') {
			if (timeString) timeString += ', ';
			timeString += `${minutes} minute${minutes !== 1 ? 's' : ''}`;
		}
		
		timeString += ' remaining';
		
		return {
			text: timeString,
			class: days > 1 ? 'text-gray-700' : days >= 1 ? 'text-yellow-600 font-medium' : 'text-red-600 font-semibold',
			isOverdue: false
		};
	}

	function startCountdownTimer() {
		// Clear any existing interval
		if (countdownInterval) {
			clearInterval(countdownInterval);
		}
		
		// Update every minute (60000 ms)
		countdownInterval = setInterval(() => {
			// Force reactivity by updating the tasks array
			tasks = [...tasks];
		}, 60000);
	}

	function stopCountdownTimer() {
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
	}

	function openImageModal(imageUrl) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}

	function closeImageModal() {
		showImageModal = false;
		selectedImageUrl = '';
	}

	// Reactive statements
	$: {
		filterTasks();
	}
</script>

<div class="my-tasks-view h-full flex flex-col bg-gray-50">
	<!-- Header -->
	<div class="bg-white shadow-sm border-b p-6">
		<div class="flex items-center justify-between">
			<div>
				<h1 class="text-2xl font-bold text-gray-900">My Tasks</h1>
				<p class="text-gray-600 mt-1">Tasks assigned to you</p>
			</div>
			<div class="flex items-center space-x-2">
				<span class="text-sm text-gray-500">Total: {filteredTasks.length}</span>
				<button
					on:click={loadMyTasks}
					class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
				>
					Refresh
				</button>
			</div>
		</div>
	</div>

	<!-- Filters -->
	<div class="bg-white border-b p-4 space-y-4">
		<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
				<input
					type="text"
					bind:value={searchTerm}
					placeholder="Search tasks..."
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
				/>
			</div>
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
				<select
					bind:value={filterStatus}
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
				>
					<option value="all">All Status</option>
					<option value="pending">Pending</option>
					<option value="in_progress">In Progress</option>
					<option value="completed">Completed</option>
					<option value="cancelled">Cancelled</option>
				</select>
			</div>
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Priority</label>
				<select
					bind:value={filterPriority}
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
				>
					<option value="all">All Priorities</option>
					<option value="high">High</option>
					<option value="medium">Medium</option>
					<option value="low">Low</option>
				</select>
			</div>
		</div>
	</div>

	<!-- Tasks List -->
	<div class="flex-1 overflow-y-auto p-6">
		{#if loading}
			<div class="flex items-center justify-center h-64">
				<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
			</div>
		{:else if filteredTasks.length === 0}
			<div class="text-center py-12">
				<svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
				</svg>
				<h3 class="text-lg font-medium text-gray-900 mb-2">No tasks found</h3>
				<p class="text-gray-600">No tasks match your current filters.</p>
			</div>
		{:else}
			<div class="grid gap-4">
				{#each filteredTasks as task (task.assignment_id)}
					<div class="bg-white rounded-lg shadow-sm border hover:shadow-md transition-shadow">
						<div class="p-6">
							<div class="flex items-start justify-between">
								<div class="flex-1">
									<div class="flex items-center space-x-3 mb-2">
										<h3 class="text-lg font-semibold text-gray-900">{task.title}</h3>
										<span class="px-2 py-1 rounded-full text-xs font-medium {getPriorityColor(task.priority)}">
											{task.priority?.toUpperCase()}
										</span>
										<span class="px-2 py-1 rounded-full text-xs font-medium {getStatusColor(task.assignment_status)}">
											{task.assignment_status?.replace('_', ' ').toUpperCase()}
										</span>
									</div>
									
									<p class="text-gray-600 mb-3">{task.description}</p>
									
									<!-- Task Images -->
									{#if task.images && task.images.length > 0}
										<div class="mb-4">
											<div class="flex items-center space-x-2 mb-2">
												<svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
												</svg>
												<span class="text-sm font-medium text-gray-700">Task Images ({task.images.length})</span>
											</div>
											<div class="flex flex-wrap gap-2 max-h-32 overflow-y-auto">
												{#each task.images as image (image.id)}
													<div class="relative group">
														<button
															class="relative w-20 h-20 rounded-lg overflow-hidden border-2 border-gray-200 hover:border-blue-400 transition-colors group-hover:shadow-md"
															on:click={() => openImageModal(image.file_url)}
															title="Click to view full size - {image.file_name || 'Image'}"
														>
															<img
																src={image.file_url}
																alt={image.file_name || 'Task image'}
																class="w-full h-full object-cover"
																loading="lazy"
																on:error={(e) => {
																	e.target.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDQgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSIjOUNBM0FGIi8+Cjwvc3ZnPgo=';
																	e.target.classList.add('bg-gray-100');
																}}
															/>
															<div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-20 transition-all flex items-center justify-center">
																<svg class="w-5 h-5 text-white opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
																	<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
																</svg>
															</div>
														</button>
														<!-- Image type indicator -->
														{#if image.image_type}
															<div class="absolute -top-1 -right-1 bg-blue-500 text-white text-xs px-1 py-0.5 rounded-full text-[10px] font-medium">
																{image.image_type.toUpperCase()}
															</div>
														{/if}
													</div>
												{/each}
											</div>
											{#if task.images.length > 8}
												<div class="text-xs text-gray-500 mt-1">
													Showing {Math.min(8, task.images.length)} of {task.images.length} images
												</div>
											{/if}
										</div>
									{/if}
									
									<div class="grid grid-cols-2 gap-4 text-sm text-gray-500">
										<div>
											<span class="font-medium">Priority:</span> {task.priority || 'Not set'}
										</div>
										<div>
											<span class="font-medium">Task Status:</span> {task.status || 'Unknown'}
										</div>
										{#if task.deadline_date}
											{@const deadlineInfo = getDeadlineDisplay(task.deadline_date, task.deadline_time)}
											<div class="col-span-2">
												<span class="font-medium">Deadline:</span> 
												<span class="{deadlineInfo.class}">
													{deadlineInfo.text}
													{#if deadlineInfo.isOverdue}
														<span class="inline-flex items-center px-2 py-0.5 ml-2 text-xs font-medium bg-red-100 text-red-800 rounded-full">
															⚠️ OVERDUE
														</span>
													{/if}
												</span>
											</div>
										{:else}
											<div class="col-span-2">
												<span class="font-medium">Deadline:</span> 
												<span class="text-gray-500">No deadline set</span>
											</div>
										{/if}
										{#if task.schedule_date}
											<div>
												<span class="font-medium">Scheduled:</span> 
												{formatDate(task.schedule_date)}
												{#if task.schedule_time}
													at {formatTime(task.schedule_time)}
												{/if}
											</div>
										{/if}
										<div>
											<span class="font-medium">Assignment Status:</span> 
											<span class="px-2 py-1 rounded-full text-xs font-medium {getStatusColor(task.assignment_status)}">
												{task.assignment_status?.replace('_', ' ').toUpperCase()}
											</span>
										</div>
										<div>
											<span class="font-medium">Assigned by:</span> 
											{task.assigned_by_name || 'Unknown'}
										</div>
										<div>
											<span class="font-medium">Assigned to:</span> 
											{currentUserData?.name || currentUserData?.username || 'You'}
										</div>
										<div>
											<span class="font-medium">Assigned on:</span> 
											{formatDate(task.assigned_at)}
										</div>
										<div>
											<span class="font-medium">Created by:</span> 
											{task.created_by_name || task.created_by || 'Unknown'}
										</div>
									</div>

								</div>
								
								<div class="ml-4 flex flex-col space-y-2">
									{#if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled'}
										<button
											on:click={() => openTaskCompletion(task)}
											class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center space-x-2"
										>
											<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
												<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
											</svg>
											<span>Complete</span>
										</button>
									{/if}
									
									<button
										on:click={() => openTaskDetails(task)}
										class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center space-x-2"
									>
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
										</svg>
										<span>View Details</span>
									</button>
								</div>
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<!-- Enhanced Image Modal -->
{#if showImageModal}
	<div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50" on:click={closeImageModal}>
		<div class="relative max-w-6xl max-h-screen p-4 w-full" on:click|stopPropagation>
			<!-- Close button -->
			<button
				class="absolute top-4 right-4 bg-black bg-opacity-60 text-white rounded-full p-3 hover:bg-opacity-80 transition-all z-10 backdrop-blur-sm"
				on:click={closeImageModal}
				title="Close image viewer"
			>
				<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
				</svg>
			</button>
			
			<!-- Image container -->
			<div class="flex items-center justify-center h-full">
				<div class="relative">
					<img
						src={selectedImageUrl}
						alt="Task image full size"
						class="max-w-full max-h-[90vh] object-contain rounded-lg shadow-2xl"
						loading="lazy"
						on:error={(e) => {
							e.target.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDQgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSIjOUNBM0FGIi8+Cjwvc3ZnPgo=';
						}}
					/>
					
					<!-- Loading indicator -->
					<div class="absolute inset-0 flex items-center justify-center bg-gray-100 rounded-lg" style="display: none;" id="image-loading">
						<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
					</div>
				</div>
			</div>
			
			<!-- Image info overlay -->
			<div class="absolute bottom-4 left-4 bg-black bg-opacity-60 text-white px-4 py-2 rounded-lg backdrop-blur-sm">
				<div class="text-sm">
					<div class="font-medium">Task Image</div>
					<div class="text-gray-300 text-xs">Click outside to close</div>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.my-tasks-view {
		background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
	}
</style>