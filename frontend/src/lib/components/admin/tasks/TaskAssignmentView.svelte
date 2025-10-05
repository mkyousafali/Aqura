<script lang="ts">
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { windowManager } from '$lib/stores/windowManager';
	import { loadTasks, assignTasks } from '$lib/stores/taskStoreSupabase';
	import { db } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import TaskCreateForm from './TaskCreateForm.svelte';

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

	// Image modal
	let showImageModal = false;
	let selectedImageUrl = '';

	// Assignment settings with enhanced repeat options
	let assignmentSettings = {
		assignment_type: 'one_time', // 'one_time' or 'repeat'
		notify_assignees: true,
		set_deadline: false,
		deadline: '',
		time: '',
		time_12h: '', // 12-hour format time
		add_note: '',
		priority_override: '',
		enable_reassigning: false, // Allow users to reassign tasks from My Tasks
		enable_repeat: false,
		repeat_type: 'daily', // 'daily', 'weekly', 'monthly', 'custom'
		repeat_days: [], // For weekly: ['monday', 'tuesday', etc]
		repeat_interval: 1, // For every N days/weeks/months
		repeat_date: '', // For monthly specific date
		repeat_end_type: 'never', // 'never', 'after', 'on_date'
		repeat_end_count: 10,
		repeat_end_date: '',
		// Completion criteria
		require_task_finished: true,
		require_photo_upload: false,
		require_erp_reference: false
	};

	// Generate 12-hour time options
	const timeOptions12h = (() => {
		const times = [];
		for (let hour = 1; hour <= 12; hour++) {
			for (let minute of ['00', '15', '30', '45']) {
				times.push(`${hour}:${minute} AM`);
			}
		}
		for (let hour = 1; hour <= 12; hour++) {
			for (let minute of ['00', '15', '30', '45']) {
				times.push(`${hour}:${minute} PM`);
			}
		}
		return times;
	})();

	// Available options for filtering
	const userRoles = ['Master Admin', 'Admin', 'User', 'Manager'];
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
	let currentView = 'users'; // 'users', 'tasks', 'settings', or 'criteria'

	onMount(async () => {
		await loadDataFromSupabase();
		
		// Set default deadline to 3 days from now
		const defaultDeadline = new Date();
		defaultDeadline.setDate(defaultDeadline.getDate() + 3);
		assignmentSettings.deadline = defaultDeadline.toISOString().slice(0, 10);
		assignmentSettings.time = '09:00';
		assignmentSettings.time_12h = '9:00 AM';
		
		// Set default repeat end date to 1 month from now
		const defaultEndDate = new Date();
		defaultEndDate.setMonth(defaultEndDate.getMonth() + 1);
		assignmentSettings.repeat_end_date = defaultEndDate.toISOString().slice(0, 10);
	});

	async function loadDataFromSupabase() {
		try {
			isLoading = true;
			console.log('Starting data load...');
			
			// Load tasks (only assignable ones - active and draft status)
			const taskResult = await loadTasks(100, 0, undefined);
			if (taskResult.success) {
				// Filter for assignable tasks (active and draft)
				tasks = (taskResult.data || []).filter(task => 
					task.status === 'active' || task.status === 'draft'
				);
				
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
				
				console.log('Loaded tasks:', tasks.length);
			} else {
				console.error('Failed to load tasks:', taskResult.error);
			}

			// Load branches from Supabase
			console.log('Loading branches...');
			const { data: branchData, error: branchError } = await db.branches.getAll();
			if (!branchError && branchData) {
				branches = branchData;
				console.log('Loaded branches:', branches.length);
			} else {
				console.error('Branch error:', branchError);
				// Add test branches if none exist
				branches = [
					{ id: 'test-branch-1', name_en: 'Main Branch', name_ar: 'الفرع الرئيسي' },
					{ id: 'test-branch-2', name_en: 'Secondary Branch', name_ar: 'الفرع الثانوي' }
				];
			}

			// Load users with complete employee data using a direct query
			console.log('Loading users with employee details...');
			
			// Use the new flat data structure method
			const { data: userData, error: userError } = await db.users.getAllWithEmployeeDetailsFlat();
			
			console.log('Users query result:', userData, 'Error:', userError);
			
			let allUsers = [];
			
			// Process the flat data structure from our database view
			if (!userError && userData && userData.length > 0) {
				allUsers = userData.map(user => {
					console.log('Processing user:', user.username, 'Data:', user);
					
					// Check if user has employee connection (use correct column names)
					const hasEmployeeData = user.employee_id && user.employee_name;
					
					// Employee display name
					const displayName = user.employee_name || user.username || 'Unknown User';
					
					// Contact information
					const displayEmail = user.email || 'No email';
					const displayPhone = user.contact_number || 'No phone';
					const displayWhatsApp = user.whatsapp_number || 'No WhatsApp';
					
					// Position information
					const displayPosition = user.position_title || (hasEmployeeData ? 'No position assigned' : 'Employee not assigned');
					
					return {
						id: user.id, // Use correct column name from database function
						name: displayName,
						email: displayEmail,
						phone: displayPhone,
						whatsapp: displayWhatsApp,
						position: displayPosition,
						role: user.role_type || 'User',
						branch_id: user.branch_id,
						branch_name: user.branch_name || 'Unknown Branch',
						status: user.status || 'active',
						has_employee_data: hasEmployeeData, // Add this flag
						employee_name: user.employee_name, // Use correct column name
						username: user.username, // Add username (fixed syntax)
						user_type: user.user_type,
						employee_id: user.employee_id, // Use correct column name
						hire_date: user.hire_date, // Now available in our function
						contact_info: {
							email: user.email || null,
							contact_number: user.contact_number || null,
							whatsapp_number: user.whatsapp_number || null
						},
						avatar_url: user.avatar || user.avatar_medium_url,
						is_active: user.status === 'active'
					};
				});
				console.log('Loaded users with employee details:', allUsers.length);
			}
			
			users = allUsers;
			console.log('Final users array:', users.length, 'users loaded');

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
		console.log('🔍 [TaskAssignment] Applying filters to', tasks.length, 'tasks');
		console.log('🔍 [TaskAssignment] Filters:', { taskSearchTerm, taskStatusFilter, taskPriorityFilter });
		
		filteredTasks = tasks.filter(task => {
			const matchesSearch = !taskSearchTerm || 
				task.title.toLowerCase().includes(taskSearchTerm.toLowerCase()) ||
				task.description.toLowerCase().includes(taskSearchTerm.toLowerCase());
			
			const matchesStatus = !taskStatusFilter || task.status === taskStatusFilter;
			const matchesPriority = !taskPriorityFilter || task.priority === taskPriorityFilter;
			
			const result = matchesSearch && matchesStatus && matchesPriority;
			if (!result) {
				console.log('🚫 [TaskAssignment] Task filtered out:', task.title, { matchesSearch, matchesStatus, matchesPriority });
			}
			return result;
		});
		
		console.log('✅ [TaskAssignment] Filtered tasks count:', filteredTasks.length);
		console.log('✅ [TaskAssignment] Filtered tasks:', filteredTasks.map(t => ({ id: t.id, title: t.title, status: t.status })));

		// Filter users
		filteredUsers = users.filter(user => {
			const matchesSearch = !userSearchTerm ||
				(user.name && user.name.toLowerCase().includes(userSearchTerm.toLowerCase())) ||
				(user.username && user.username.toLowerCase().includes(userSearchTerm.toLowerCase())) ||
				(user.email && user.email.toLowerCase().includes(userSearchTerm.toLowerCase())) ||
				(user.phone && user.phone.toLowerCase().includes(userSearchTerm.toLowerCase())) ||
				(user.whatsapp && user.whatsapp.toLowerCase().includes(userSearchTerm.toLowerCase())) ||
				(user.position && user.position.toLowerCase().includes(userSearchTerm.toLowerCase()));

			const matchesBranch = !selectedBranch || user.branch_id === selectedBranch;
			const matchesRole = !selectedRole || user.role === selectedRole;
			const isActive = user.is_active !== false; // Include users that are active or undefined

			return matchesSearch && matchesBranch && matchesRole && isActive;
		});

		// Update select all states
		updateSelectAllStates();
	}

	function updateSelectAllStates() {
		// Update states without triggering reactive bindings
		const newSelectAllTasks = filteredTasks.length > 0 && filteredTasks.every(task => selectedTasks.has(task.id));
		const newSelectAllUsers = filteredUsers.length > 0 && filteredUsers.every(user => selectedUsers.has(user.id));
		
		// Only update if values actually changed to avoid unnecessary reactivity
		if (selectAllTasks !== newSelectAllTasks) {
			selectAllTasks = newSelectAllTasks;
		}
		if (selectAllUsers !== newSelectAllUsers) {
			selectAllUsers = newSelectAllUsers;
		}
	}

	function handleSelectAllTasks() {
		if (selectAllTasks) {
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
		updateSelectAllStates();
	}

	function handleUserSelect(userId: string, checked: boolean) {
		console.log('👤 [TaskAssignment] User select:', userId, checked);
		console.log('👤 [TaskAssignment] Before - selectedUsers:', Array.from(selectedUsers));
		console.log('👤 [TaskAssignment] User object keys available:', Object.keys(filteredUsers[0] || {}));
		console.log('👤 [TaskAssignment] First user sample:', filteredUsers[0]);
		
		if (checked) {
			selectedUsers.add(userId);
		} else {
			selectedUsers.delete(userId);
		}
		selectedUsers = new Set(selectedUsers);
		
		console.log('👤 [TaskAssignment] After - selectedUsers:', Array.from(selectedUsers));
		updateSelectAllStates();
	}

	// Helper function to convert 12-hour time to 24-hour format
	function convert12hTo24h(time12h) {
		const [time, modifier] = time12h.split(' ');
		let [hours, minutes] = time.split(':');
		if (hours === '12') {
			hours = '00';
		}
		if (modifier === 'PM') {
			hours = parseInt(hours, 10) + 12;
		}
		return `${hours.toString().padStart(2, '0')}:${minutes}`;
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

		// Check authentication
		if (!$isAuthenticated || !$currentUser) {
			notifications.add({
				type: 'error',
				message: 'You must be logged in to assign tasks',
				duration: 3000
			});
			return;
		}

		// Validate assignment type selection
		if (!assignmentSettings.assignment_type) {
			notifications.add({
				type: 'warning',
				message: 'Please select an assignment type (One Time or Repeat)',
				duration: 3000
			});
			return;
		}

		// Validate time selection
		if (!assignmentSettings.time_12h) {
			notifications.add({
				type: 'warning',
				message: 'Please select a time for the assignment',
				duration: 3000
			});
			return;
		}

		// Validate one-time assignment settings
		if (assignmentSettings.assignment_type === 'one_time') {
			if (!assignmentSettings.deadline) {
				notifications.add({
					type: 'warning',
					message: 'Please set a date for the one-time assignment',
					duration: 3000
				});
				return;
			}
		}

		// Validate repeat assignment settings
		if (assignmentSettings.assignment_type === 'repeat') {
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

			if (assignmentSettings.repeat_type === 'every_n_days' && (!assignmentSettings.repeat_interval || assignmentSettings.repeat_interval < 1)) {
				notifications.add({
					type: 'warning',
					message: 'Please set a valid interval for repeat every N days',
					duration: 3000
				});
				return;
			}

			if (assignmentSettings.repeat_type === 'every_n_weeks' && (!assignmentSettings.repeat_interval || assignmentSettings.repeat_interval < 1)) {
				notifications.add({
					type: 'warning',
					message: 'Please set a valid interval for repeat every N weeks',
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
			// Convert 12-hour time to 24-hour format for deadline construction
			let time24h = null;
			if (assignmentSettings.time_12h) {
				time24h = convert12hTo24h(assignmentSettings.time_12h);
			}

			// Combine date and time for deadline
			let fullDeadline = null;
			if (assignmentSettings.assignment_type === 'one_time' && assignmentSettings.deadline && time24h) {
				fullDeadline = `${assignmentSettings.deadline}T${time24h}:00`;
			}

			// Prepare schedule settings for the task store
			const scheduleSettings = assignmentSettings.assignment_type === 'one_time' && assignmentSettings.deadline && time24h ? {
				deadline_date: assignmentSettings.deadline,
				deadline_time: time24h,
				notes: assignmentSettings.add_note || undefined,
				priority_override: assignmentSettings.priority_override || undefined,
				require_task_finished: assignmentSettings.require_task_finished,
				require_photo_upload: assignmentSettings.require_photo_upload,
				require_erp_reference: assignmentSettings.require_erp_reference
			} : {
				notes: assignmentSettings.add_note || undefined,
				priority_override: assignmentSettings.priority_override || undefined,
				require_task_finished: assignmentSettings.require_task_finished,
				require_photo_upload: assignmentSettings.require_photo_upload,
				require_erp_reference: assignmentSettings.require_erp_reference
			};

			// Prepare assignment data
			const assignmentData = {
				task_ids: Array.from(selectedTasks),
				user_ids: Array.from(selectedUsers),
				deadline: fullDeadline,
				priority_override: assignmentSettings.priority_override || null,
				note: assignmentSettings.add_note || null,
				notify_assignees: assignmentSettings.notify_assignees,
				repeat_settings: assignmentSettings.assignment_type === 'repeat' ? {
					type: assignmentSettings.repeat_type,
					interval: assignmentSettings.repeat_interval,
					days: assignmentSettings.repeat_days,
					date: assignmentSettings.repeat_date,
					time: time24h,
					end_type: assignmentSettings.repeat_end_type,
					end_count: assignmentSettings.repeat_end_count,
					end_date: assignmentSettings.repeat_end_date
				} : null
			};

			// For each selected user, create assignments for all selected tasks
			const taskIds = Array.from(selectedTasks);
			const createdAssignments = [];
			
			for (const userId of selectedUsers) {
				const result = await assignTasks(
					taskIds,
					'user', // assignment type
					$currentUser?.id || 'unknown', // assigned by - use current user
					$currentUser?.employeeName || $currentUser?.username || 'Admin User', // assigned by name
					userId, // assigned to user ID
					undefined, // no branch ID for user assignments
					scheduleSettings // pass deadline information
				);
				
				if (result.error) {
					throw new Error(result.error.message || 'Failed to assign tasks');
				}
				
				// Store the created assignments for notifications
				if (result.data) {
					createdAssignments.push(...result.data);
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

			// Create notification center notifications for assigned users
			if (assignmentSettings.notify_assignees) {
				try {
					// Create notifications for each task-user combination
					const notificationPromises = [];
					
					for (const taskId of selectedTasks) {
						// Find the task details
						const task = tasks.find(t => t.id === taskId);
						if (!task) continue;

						// Find the assignment ID for this task (use the first one as reference)
						const assignment = createdAssignments.find(a => a.task_id === taskId);
						const assignmentId = assignment ? assignment.id : null;

						// Create notification for all assigned users for this task
						const notificationPromise = notificationManagement.createTaskAssignmentNotification(
							taskId,
							task.title,
							Array.from(selectedUsers),
							$currentUser?.id || 'unknown', // assigned by ID - use current user
							$currentUser?.employeeName || $currentUser?.username || 'Admin User', // assigned by name
							fullDeadline, // deadline
							assignmentSettings.add_note, // notes
							{
								assignmentId: assignmentId,
								require_task_finished: assignmentSettings.require_task_finished,
								require_photo_upload: assignmentSettings.require_photo_upload,
								require_erp_reference: assignmentSettings.require_erp_reference,
								description: task.description
							}
						);
						
						notificationPromises.push(notificationPromise);
					}

					await Promise.all(notificationPromises);
					
					notifications.add({
						type: 'success',
						message: `Notifications sent to ${selectedUsers.size} user${selectedUsers.size !== 1 ? 's' : ''} via Notification Center`,
						duration: 3000
					});
				} catch (notificationError) {
					console.error('Error creating notifications:', notificationError);
					notifications.add({
						type: 'warning',
						message: 'Tasks assigned successfully, but failed to send some notifications',
						duration: 4000
					});
				}
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
			// Reset completion criteria to defaults
			assignmentSettings.require_task_finished = true;
			assignmentSettings.require_photo_upload = false;
			assignmentSettings.require_erp_reference = false;

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

	// Image modal functions
	function openImageModal(imageUrl: string) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}

	function closeImageModal() {
		showImageModal = false;
		selectedImageUrl = '';
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
		// Open TaskCreateForm in a new window
		windowManager.openWindow({
			component: TaskCreateForm,
			title: 'Create New Task',
			props: {
				editMode: false,
				taskData: null,
				onTaskUpdated: (newTask) => {
					// Refresh tasks after creation
					loadDataFromSupabase();
					notifications.add({
						type: 'success',
						message: `Task "${newTask.title}" created successfully!`,
						duration: 3000
					});
				}
			}
		});
	}

	function editTask(task) {
		// Open TaskCreateForm in edit mode
		windowManager.openWindow({
			component: TaskCreateForm,
			title: `Edit Task: ${task.title}`,
			props: {
				editMode: true,
				taskData: task,
				onTaskUpdated: (updatedTask) => {
					// Refresh tasks after update
					loadDataFromSupabase();
					notifications.add({
						type: 'success',
						message: `Task "${updatedTask.title}" updated successfully!`,
						duration: 3000
					});
				}
			}
		});
	}

	function viewTaskStats() {
		// This would show task statistics
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
			
			<svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
				<path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
			</svg>
			
			<div class="flex items-center space-x-3 {currentView === 'criteria' ? 'text-purple-600' : 'text-gray-500'}">
				<div class="w-8 h-8 rounded-full border-2 {currentView === 'criteria' ? 'border-purple-600 bg-purple-100' : 'border-gray-300'} flex items-center justify-center">
					<span class="text-sm font-medium">4</span>
				</div>
				<span class="font-medium">Completion Criteria</span>
			</div>
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
							placeholder="Search by name, username, email, phone, position..."
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
								checked={selectAllUsers}
								on:change={(e) => {
									const checked = (e.target as HTMLInputElement)?.checked || false;
									if (checked) {
										filteredUsers.forEach(user => selectedUsers.add(user.id));
									} else {
										filteredUsers.forEach(user => selectedUsers.delete(user.id));
									}
									selectedUsers = new Set(selectedUsers);
								}}
								class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
							/>
							<span class="text-sm text-gray-700">Select All</span>
						</label>
					</div>

					<!-- Enhanced Users List -->
					<div class="flex-1 border rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-3 border-b text-sm font-medium text-gray-700">
							<div class="grid grid-cols-9 gap-3 items-center">
								<div class="col-span-1 text-center">Select</div>
								<div class="col-span-1">User</div>
								<div class="col-span-1">Employee</div>
								<div class="col-span-1">Email</div>
								<div class="col-span-1">Contact</div>
								<div class="col-span-1">WhatsApp</div>
								<div class="col-span-1">Position</div>
								<div class="col-span-1">Branch</div>
								<div class="col-span-1">Status</div>
							</div>
						</div>
						<div class="overflow-y-auto max-h-96">
							{#each filteredUsers as user}
								<label class="block hover:bg-gray-50 cursor-pointer border-b last:border-b-0">
									<div class="grid grid-cols-9 gap-3 items-center px-4 py-3">
										<div class="col-span-1 flex justify-center">
											<input
												type="checkbox"
												checked={selectedUsers.has(user.id)}
												on:change={(e) => handleUserSelect(user.id, (e.target as HTMLInputElement)?.checked || false)}
												class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
											/>
										</div>
										<div class="col-span-1">
											<div class="flex items-center space-x-2">
												<div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center flex-shrink-0">
													<span class="text-xs font-medium text-blue-600">
														{user.username?.charAt(0)?.toUpperCase() || 'U'}
													</span>
												</div>
												<div class="min-w-0 flex-1">
													<p class="text-sm font-medium text-gray-900 truncate">{user.username}</p>
													<p class="text-xs text-gray-500 truncate">{user.user_type || 'User'}</p>
												</div>
											</div>
										</div>
										<div class="col-span-1">
											{#if user.has_employee_data}
												<div class="flex items-center space-x-2">
													<div class="w-6 h-6 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
														<span class="text-xs font-medium text-purple-600">
															{user.name?.charAt(0)?.toUpperCase() || 'E'}
														</span>
													</div>
													<div class="min-w-0 flex-1">
														<p class="text-sm font-medium text-gray-900 truncate">{user.name}</p>
														{#if user.hire_date}
															<p class="text-xs text-gray-500 truncate">Since: {new Date(user.hire_date).toLocaleDateString()}</p>
														{/if}
													</div>
												</div>
											{:else}
												<span class="text-sm text-gray-400 italic">Employee not assigned</span>
											{/if}
										</div>
										<div class="w-32">
											<p class="text-sm text-gray-900 truncate">{user.email}</p>
										</div>
										<div class="w-28">
											<p class="text-sm text-gray-900 truncate">{user.phone}</p>
										</div>
										<div class="w-28">
											<p class="text-sm text-gray-900 truncate">{user.whatsapp}</p>
										</div>
										<div class="w-32">
											<p class="text-sm text-gray-900 truncate">{user.position}</p>
										</div>
										<div class="w-24">
											<p class="text-sm text-gray-900 truncate">{user.branch_name || 'No branch'}</p>
										</div>
										<div class="w-20">
											<div class="flex flex-col space-y-1">
												<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {user.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}">
													{user.status || 'Active'}
												</span>
												{#if user.has_employee_data}
													<span class="inline-flex items-center px-1 py-0.5 rounded text-xs bg-blue-100 text-blue-600">
														Emp
													</span>
												{/if}
											</div>
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

			<!-- Tasks Selection View -->
			{:else if currentView === 'tasks'}
				<div class="p-6 h-full flex flex-col">
					<!-- Header with Search and Actions -->
					<div class="flex items-center justify-between mb-6">
						<div>
							<h3 class="text-lg font-medium text-gray-900">Select Tasks</h3>
							<p class="text-sm text-gray-500 mt-1">
								{selectedTasks.size} of {filteredTasks.length} selected
							</p>
						</div>
						<div class="flex items-center space-x-3">
							<button
								on:click={createNewTask}
								class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
								</svg>
								<span>New Task</span>
							</button>
							<button
								on:click={loadDataFromSupabase}
								class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-lg transition-colors flex items-center space-x-2"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
								</svg>
								<span>Refresh</span>
							</button>
						</div>
					</div>

					<!-- Enhanced Search and Filters -->
					<div class="bg-white border rounded-lg p-4 mb-6">
						<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
							<!-- Search Input -->
							<div class="col-span-full md:col-span-2">
								<div class="relative">
									<div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
										<svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
										</svg>
									</div>
									<input
										type="text"
										bind:value={taskSearchTerm}
										placeholder="Search by title or description..."
										class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
									/>
								</div>
							</div>

							<!-- Status Filter -->
							<div>
								<select
									bind:value={taskStatusFilter}
									class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
								>
									<option value="">All Statuses</option>
									{#each taskStatuses as status}
										<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
									{/each}
								</select>
							</div>

							<!-- Priority Filter -->
							<div>
								<select
									bind:value={taskPriorityFilter}
									class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
								>
									<option value="">All Priorities</option>
									{#each taskPriorities as priority}
										<option value={priority}>{priority.charAt(0).toUpperCase() + priority.slice(1)}</option>
									{/each}
								</select>
							</div>
						</div>

						<!-- Action Buttons Row -->
						<div class="flex items-center justify-between mt-4 pt-4 border-t">
							<div class="flex items-center space-x-4">
								{#if selectedTasks.size > 0}
									<span class="text-sm text-purple-600 font-medium">
										{selectedTasks.size} task{selectedTasks.size !== 1 ? 's' : ''} selected
									</span>
								{:else}
									<span class="text-sm text-gray-500">
										{filteredTasks.length} task{filteredTasks.length !== 1 ? 's' : ''} available
									</span>
								{/if}
							</div>
							<button
								on:click={() => {taskSearchTerm = ''; taskStatusFilter = ''; taskPriorityFilter = '';}}
								class="text-sm text-gray-500 hover:text-gray-700 underline"
							>
								Clear Filters
							</button>
						</div>
					</div>

					<!-- Tasks Table -->
					<div class="flex-1 overflow-hidden">
						{#if filteredTasks.length === 0}
							<div class="flex flex-col items-center justify-center h-full text-gray-500">
								<svg class="w-16 h-16 mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
								</svg>
								<h3 class="text-lg font-medium text-gray-900 mb-2">No tasks found</h3>
								<p class="text-gray-500 text-center mb-4">
									{taskSearchTerm || taskStatusFilter || taskPriorityFilter 
										? 'No tasks match your current filters.' 
										: 'No active tasks available for assignment.'
									}
								</p>
								<button 
									on:click={createNewTask}
									class="bg-purple-600 text-white px-6 py-2 rounded-lg hover:bg-purple-700 transition-colors"
								>
									Create New Task
								</button>
							</div>
						{:else}
							<!-- Table View -->
							<div class="border rounded-lg overflow-hidden bg-white">
								<!-- Table Header -->
								<div class="bg-gray-50 px-6 py-3 border-b text-sm font-medium text-gray-700">
									<div class="grid grid-cols-12 gap-4 items-center">
										<div class="col-span-1 flex items-center justify-center">
											<input
												type="checkbox"
												bind:checked={selectAllTasks}
												on:change={handleSelectAllTasks}
												class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
											/>
										</div>
										<div class="col-span-1">Image</div>
										<div class="col-span-3">Task Details</div>
										<div class="col-span-2">Priority</div>
										<div class="col-span-2">Status</div>
										<div class="col-span-2">Due Date</div>
										<div class="col-span-1">Actions</div>
									</div>
								</div>
								
								<!-- Table Body -->
								<div class="overflow-y-auto max-h-96">
									{#each filteredTasks as task}
										<div class="block hover:bg-gray-50 border-b last:border-b-0 transition-colors">
											<div class="grid grid-cols-12 gap-4 items-center px-6 py-4">
												<!-- Checkbox -->
												<div class="col-span-1 flex items-center justify-center">
													<input
														type="checkbox"
														checked={selectedTasks.has(task.id)}
														on:change={(e) => handleTaskSelect(task.id, (e.target as HTMLInputElement)?.checked || false)}
														class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
													/>
												</div>
												
												<!-- Image -->
												<div class="col-span-1 flex items-center justify-center">
													{#if task.image_url}
														<button
															on:click|stopPropagation={() => openImageModal(task.image_url)}
															class="w-10 h-10 rounded overflow-hidden hover:shadow-lg transition-shadow duration-200 flex-shrink-0 border border-gray-200"
														>
															<img
																src={task.image_url}
																alt="Task image"
																class="w-full h-full object-cover"
																loading="lazy"
																on:error={(e) => {
																	console.warn(`Failed to load image: ${task.image_url}`);
																	// Hide the image container if image fails to load
																	e.target.parentElement.style.display = 'none';
																}}
															/>
														</button>
													{:else}
														<div class="w-10 h-10 bg-gray-100 rounded flex items-center justify-center border border-gray-200">
															<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
																<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
															</svg>
														</div>
													{/if}
												</div>
												
												<!-- Task Details -->
												<div class="col-span-3">
													<div>
														<h4 class="text-sm font-semibold text-gray-900 line-clamp-1">
															{task.title}
														</h4>
														<p class="text-xs text-gray-500 line-clamp-2 mt-1">
															{task.description || 'No description'}
														</p>
														<p class="text-xs text-gray-400 mt-1">
															ID: {task.id.slice(0, 8)}...
														</p>
													</div>
												</div>
												
												<!-- Priority -->
												<div class="col-span-2">
													<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {getPriorityBadgeClass(task.priority)}">
														{task.priority.charAt(0).toUpperCase() + task.priority.slice(1)}
													</span>
												</div>
												
												<!-- Status -->
												<div class="col-span-2">
													<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {getStatusBadgeClass(task.status)}">
														{task.status.charAt(0).toUpperCase() + task.status.slice(1)}
													</span>
												</div>
												
												<!-- Due Date -->
												<div class="col-span-2">
													<div class="text-sm text-gray-900">
														{task.due_date ? formatDate(task.due_date) : 'Not set'}
													</div>
													{#if task.due_time}
														<div class="text-xs text-gray-500">
															at {task.due_time}
														</div>
													{/if}
												</div>
												
												<!-- Actions -->
												<div class="col-span-1">
													<button 
														on:click|stopPropagation={() => editTask(task)}
														class="text-purple-600 hover:text-purple-800 text-xs font-medium transition-colors"
														title="Edit Task"
													>
														Edit
													</button>
												</div>
											</div>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					</div>

					<!-- Navigation Footer -->
					<div class="flex items-center justify-between pt-6 border-t">
						<button
							on:click={() => switchView('users')}
							class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors flex items-center space-x-2"
						>
							<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"/>
							</svg>
							<span>Back to Users</span>
						</button>
						<button
							on:click={() => {if (selectedTasks.size > 0) currentView = 'settings'}}
							disabled={selectedTasks.size === 0}
							class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center space-x-2"
						>
							<span>Next: Settings</span>
							<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
							</svg>
						</button>
					</div>
				</div>

			<!-- Assignment Settings View -->
			{:else if currentView === 'settings'}
			<div class="flex flex-col h-full">
				<!-- Content area with scrolling -->
				<div class="flex-1 overflow-y-auto p-6 space-y-6">
					<h3 class="text-lg font-medium text-gray-900">Assignment Settings</h3>
				
				<!-- Step 1: Assignment Type Selection -->
				<div class="bg-white border border-gray-200 rounded-lg p-6">
					<h4 class="text-lg font-medium text-gray-900 mb-4">Assignment Type</h4>
					<div class="grid grid-cols-2 gap-4">
						<label class="relative cursor-pointer">
							<input
								type="radio"
								bind:group={assignmentSettings.assignment_type}
								value="one_time"
								class="sr-only"
							/>
							<div class="p-4 border-2 rounded-lg transition-all {assignmentSettings.assignment_type === 'one_time' 
								? 'border-purple-500 bg-purple-50' 
								: 'border-gray-200 hover:border-gray-300'}"
							>
								<div class="flex items-center space-x-3">
									<div class="w-4 h-4 rounded-full border-2 {assignmentSettings.assignment_type === 'one_time' 
										? 'border-purple-500 bg-purple-500' 
										: 'border-gray-300'}"
									>
										{#if assignmentSettings.assignment_type === 'one_time'}
											<div class="w-2 h-2 rounded-full bg-white m-0.5"></div>
										{/if}
									</div>
									<div>
										<div class="font-medium text-gray-900">One Time Assignment</div>
										<div class="text-sm text-gray-600">Assign tasks once with a specific deadline</div>
									</div>
								</div>
							</div>
						</label>
						
						<label class="relative cursor-pointer">
							<input
								type="radio"
								bind:group={assignmentSettings.assignment_type}
								value="repeat"
								class="sr-only"
							/>
							<div class="p-4 border-2 rounded-lg transition-all {assignmentSettings.assignment_type === 'repeat' 
								? 'border-purple-500 bg-purple-50' 
								: 'border-gray-200 hover:border-gray-300'}"
							>
								<div class="flex items-center space-x-3">
									<div class="w-4 h-4 rounded-full border-2 {assignmentSettings.assignment_type === 'repeat' 
										? 'border-purple-500 bg-purple-500' 
										: 'border-gray-300'}"
									>
										{#if assignmentSettings.assignment_type === 'repeat'}
											<div class="w-2 h-2 rounded-full bg-white m-0.5"></div>
										{/if}
									</div>
									<div>
										<div class="font-medium text-gray-900">Recurring Assignment</div>
										<div class="text-sm text-gray-600">Set up recurring tasks with schedule</div>
									</div>
								</div>
							</div>
						</label>
					</div>
				</div>

				<!-- Step 2: Schedule Configuration -->
				{#if assignmentSettings.assignment_type === 'one_time'}
					<!-- One Time Assignment Settings -->
					<div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
						<h4 class="text-lg font-medium text-gray-900 mb-4">Deadline Settings</h4>
						<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
							<div>
								<label for="assignment-date" class="block text-sm font-medium text-gray-700 mb-2">Deadline Date *</label>
								<input
									id="assignment-date"
									type="date"
									bind:value={assignmentSettings.deadline}
									min={new Date().toISOString().split('T')[0]}
									class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
									required
								/>
							</div>
							<div>
								<label for="assignment-time" class="block text-sm font-medium text-gray-700 mb-2">Deadline Time *</label>
								<select
									id="assignment-time"
									bind:value={assignmentSettings.time_12h}
									class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
									required
								>
									<option value="">Select time</option>
									{#each timeOptions12h as time}
										<option value={time}>{time}</option>
									{/each}
								</select>
							</div>
						</div>
						
						<!-- Priority Override -->
						<div class="mt-4">
							<label for="priority-override-one-time" class="block text-sm font-medium text-gray-700 mb-2">Priority Override</label>
							<select
								id="priority-override-one-time"
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
					</div>
				{:else if assignmentSettings.assignment_type === 'repeat'}
					<!-- Recurring Assignment Settings -->
					<div class="bg-purple-50 border border-purple-200 rounded-lg p-6">
						<h4 class="text-lg font-medium text-gray-900 mb-4">Repeat Schedule</h4>
						
						<!-- Repeat Type -->
						<div class="mb-4">
							<label for="repeat-type" class="block text-sm font-medium text-gray-700 mb-2">Repeat Type</label>
							<select
								id="repeat-type"
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
							<div class="mb-4">
								<div class="block text-sm font-medium text-gray-700 mb-2">Select Days</div>
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
							<div class="mb-4">
								<label for="repeat-interval" class="block text-sm font-medium text-gray-700 mb-2">
									Every {assignmentSettings.repeat_type === 'every_n_days' ? 'Days' : 'Weeks'}
								</label>
								<input
									id="repeat-interval"
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
							<div class="mb-4">
								<label for="monthly-date" class="block text-sm font-medium text-gray-700 mb-2">Monthly Date</label>
								<input
									id="monthly-date"
									type="number"
									bind:value={assignmentSettings.repeat_date}
									min="1"
									max="31"
									placeholder="Day of month (1-31)"
									class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
								/>
							</div>
						{/if}

						<!-- Time for Repeat -->
						<div class="mb-4">
							<label for="repeat-time" class="block text-sm font-medium text-gray-700 mb-2">Time *</label>
							<select
								id="repeat-time"
								bind:value={assignmentSettings.time_12h}
								class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
								required
							>
								<option value="">Select time</option>
								{#each timeOptions12h as time}
									<option value={time}>{time}</option>
								{/each}
							</select>
						</div>

						<!-- Repeat End Options -->
						<div class="mb-4">
							<div class="block text-sm font-medium text-gray-700 mb-2">End Repeat</div>
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
						
						<!-- Priority Override -->
						<div>
							<label for="priority-override-repeat" class="block text-sm font-medium text-gray-700 mb-2">Priority Override</label>
							<select
								id="priority-override-repeat"
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
					</div>
				{/if}

				<!-- Enable Reassigning Section -->
				<div class="bg-blue-50 border border-blue-200 rounded-lg p-6">
					<h4 class="text-lg font-medium text-gray-900 mb-4">Task Reassignment</h4>
					<div>
						<label class="flex items-center space-x-3 mb-2">
							<input
								type="checkbox"
								bind:checked={assignmentSettings.enable_reassigning}
								class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
							/>
							<span class="text-sm font-weight-medium text-gray-700">Enable Reassigning</span>
						</label>
						<p class="text-xs text-gray-600 ml-7">
							When enabled, users can reassign this task to other users from their "My Tasks" view
						</p>
					</div>
				</div>

				<!-- Step 3: Assignment Notes -->
				<div class="bg-gray-50 border border-gray-200 rounded-lg p-6">
					<h4 class="text-lg font-medium text-gray-900 mb-4">Assignment Notes</h4>
					<div>
						<label class="flex items-center space-x-3 mb-3">
							<input
								type="checkbox"
								bind:checked={assignmentSettings.notify_assignees}
								class="w-4 h-4 text-purple-600 bg-gray-100 border-gray-300 rounded focus:ring-purple-500"
							/>
							<span class="text-sm text-gray-700">Send email notifications to assignees</span>
						</label>
						
						<label for="assignment-notes" class="block text-sm font-medium text-gray-700 mb-2">Instructions for Assignees</label>
						<textarea
							id="assignment-notes"
							bind:value={assignmentSettings.add_note}
							rows="3"
							placeholder="Add instructions or notes for assignees..."
							class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
						></textarea>
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
					{#if assignmentSettings.assignment_type === 'repeat'}
						<div class="mt-2 text-sm text-blue-700">
							<span class="font-medium">Repeat:</span> 
							{assignmentSettings.repeat_type === 'daily' ? 'Daily' : 
							 assignmentSettings.repeat_type === 'weekly' ? `Weekly on ${assignmentSettings.repeat_days.join(', ')}` :
							 assignmentSettings.repeat_type === 'every_n_days' ? `Every ${assignmentSettings.repeat_interval} days` :
							 assignmentSettings.repeat_type === 'every_n_weeks' ? `Every ${assignmentSettings.repeat_interval} weeks` :
							 assignmentSettings.repeat_type === 'monthly' ? `Monthly on day ${assignmentSettings.repeat_date}` :
							 'Custom schedule'}
							 at {assignmentSettings.time_12h || 'specified time'}
							
							{#if assignmentSettings.repeat_end_type === 'after'}
								(for {assignmentSettings.repeat_end_count} times)
							{:else if assignmentSettings.repeat_end_type === 'on_date'}
								(until {assignmentSettings.repeat_end_date})
							{:else}
								(indefinitely)
							{/if}
						</div>
					{:else if assignmentSettings.assignment_type === 'one_time'}
						<div class="mt-2 text-sm text-blue-700">
							<span class="font-medium">Deadline:</span> 
							{assignmentSettings.deadline || 'Date not set'} at {assignmentSettings.time_12h || 'Time not set'}
						</div>
					{/if}
				</div>
			</div>
			
			<!-- Fixed Action Buttons at bottom -->
			<div class="border-t border-gray-200 bg-white p-6">
				<div class="flex justify-between">
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
							on:click={() => currentView = 'criteria'}
							disabled={selectedTasks.size === 0 || selectedUsers.size === 0}
							class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
						>
							<span>Next: Completion Criteria</span>
							<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
							</svg>
						</button>
					</div>
				</div>
			</div>
		</div>
		{/if}

		<!-- Completion Criteria View -->
		{#if currentView === 'criteria'}
		<div class="flex flex-col h-full">
			<!-- Content area with scrolling -->
			<div class="flex-1 overflow-y-auto p-6 space-y-6">
				<h3 class="text-lg font-medium text-gray-900">Completion Criteria</h3>
				<p class="text-gray-600">Specify what must be completed when users finish these assigned tasks.</p>
				
				<!-- Step 4: Completion Criteria -->
				<div class="bg-green-50 border border-green-200 rounded-lg p-6">
					<h4 class="text-lg font-medium text-gray-900 mb-4">Required for Task Completion</h4>
					<div class="space-y-4">
						<label class="flex items-start space-x-3 cursor-not-allowed opacity-75">
							<input
								type="checkbox"
								bind:checked={assignmentSettings.require_task_finished}
								disabled={true}
								class="w-4 h-4 text-green-600 border-gray-300 rounded focus:ring-green-500 mt-1"
							/>
							<div>
								<span class="text-sm font-medium text-gray-700">Task finished (Required)</span>
								<p class="text-xs text-gray-600 mt-1">
									Users must mark the task as finished. This is always mandatory and cannot be disabled.
								</p>
							</div>
						</label>
						
						<label class="flex items-start space-x-3 cursor-pointer">
							<input
								type="checkbox"
								bind:checked={assignmentSettings.require_photo_upload}
								class="w-4 h-4 text-green-600 border-gray-300 rounded focus:ring-green-500 mt-1"
							/>
							<div>
								<span class="text-sm font-medium text-gray-700">Upload photo or take photo</span>
								<p class="text-xs text-gray-600 mt-1">
									Users must upload or take a photo as proof of completion
								</p>
							</div>
						</label>
						
						<label class="flex items-start space-x-3 cursor-pointer">
							<input
								type="checkbox"
								bind:checked={assignmentSettings.require_erp_reference}
								class="w-4 h-4 text-green-600 border-gray-300 rounded focus:ring-green-500 mt-1"
							/>
							<div>
								<span class="text-sm font-medium text-gray-700">ERP reference number</span>
								<p class="text-xs text-gray-600 mt-1">
									Users must provide an ERP reference number for audit trail
								</p>
							</div>
						</label>
					</div>
				</div>

				<!-- Completion Summary -->
				<div class="bg-green-50 border border-green-200 rounded-lg p-4">
					<h4 class="text-sm font-medium text-green-900 mb-2">Completion Requirements Summary</h4>
					<div class="space-y-1 text-sm text-green-700">
						<div class="flex items-center space-x-2">
							<svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
								<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
							</svg>
							<span>Task finished: Always required</span>
						</div>
						{#if assignmentSettings.require_photo_upload}
							<div class="flex items-center space-x-2">
								<svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
								</svg>
								<span>Photo upload: Required</span>
							</div>
						{/if}
						{#if assignmentSettings.require_erp_reference}
							<div class="flex items-center space-x-2">
								<svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
								</svg>
								<span>ERP reference: Required</span>
							</div>
						{/if}
						{#if !assignmentSettings.require_photo_upload && !assignmentSettings.require_erp_reference}
							<div class="flex items-center space-x-2">
								<svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
								</svg>
								<span>Only task finished confirmation required</span>
							</div>
						{/if}
					</div>
				</div>
			</div>
			
			<!-- Fixed Action Buttons at bottom -->
			<div class="border-t border-gray-200 bg-white p-6">
				<div class="flex justify-between">
					<button
						on:click={() => currentView = 'settings'}
						class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 flex items-center space-x-2"
					>
						<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
							<path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"/>
						</svg>
						<span>Back to Settings</span>
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
							class="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
							title="Selected Tasks: {selectedTasks.size}, Selected Users: {selectedUsers.size}"
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
								<span>Assign Tasks ({selectedTasks.size} tasks, {selectedUsers.size} users)</span>
							{/if}
						</button>
					</div>
				</div>
			</div>
		</div>
		{/if}
	</div>
{/if}

<!-- Image Modal -->
{#if showImageModal}
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75" on:click={closeImageModal}>
		<div class="relative max-w-4xl max-h-4xl p-4">
			<button
				on:click={closeImageModal}
				class="absolute top-2 right-2 z-10 bg-white bg-opacity-80 hover:bg-opacity-100 rounded-full p-2 transition-all duration-200"
			>
				<svg class="w-6 h-6 text-gray-800" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
				</svg>
			</button>
			<img
				src={selectedImageUrl}
				alt="Task image full size"
				class="max-w-full max-h-full object-contain rounded-lg"
				on:click|stopPropagation
			/>
		</div>
	</div>
{/if}
</div>

<!-- Image Modal -->
{#if showImageModal && selectedImageUrl}
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75" on:click={closeImageModal}>
		<div class="relative max-w-4xl max-h-screen p-4" on:click|stopPropagation>
			<button
				on:click={closeImageModal}
				class="absolute top-2 right-2 z-10 bg-black bg-opacity-50 text-white rounded-full p-2 hover:bg-opacity-75 transition-colors"
			>
				<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
				</svg>
			</button>
			<img
				src={selectedImageUrl}
				alt="Task image full size"
				class="max-w-full max-h-full object-contain rounded-lg"
				on:error={() => {
					console.error('Failed to load full-size image:', selectedImageUrl);
					closeImageModal();
				}}
			/>
		</div>
	</div>
{/if}

<style>
	.task-assignment-view {
		max-height: calc(100vh - 100px);
	}

	.line-clamp-1 {
		display: -webkit-box;
		-webkit-line-clamp: 1;
		line-clamp: 1;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.line-clamp-2 {
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
</style>