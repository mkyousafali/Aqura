<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { cashierUser, isCashierAuthenticated } from '$lib/stores/cashierAuth';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import TaskCompletionModal from './TaskCompletionModal.svelte';
	import TaskDetailsModal from './TaskDetailsModal.svelte';
	import QuickTaskDetailsModal from './QuickTaskDetailsModal.svelte';
	import QuickTaskCompletionDialog from './QuickTaskCompletionDialog.svelte';
	import ReceivingTaskDetailsModal from './ReceivingTaskDetailsModal.svelte';
	import ReceivingTaskCompletionDialog from '$lib/components/desktop-interface/master/operations/receiving/ReceivingTaskCompletionDialog.svelte';
	
	let tasks = [];
	let filteredTasks = [];
	let loading = false; // Don't load by default
	let searchTerm = '';
	let filterStatus = 'all';
	let filterPriority = 'all';
	let filterTaskType = 'all';
	let filterDateRange = 'all'; // 'all', 'today', 'week', 'month', 'overdue'
	let showCompleted = false;
	
	// Track which task types are loaded to avoid duplicate loads
	let loadedTaskTypes = new Set(); // Start with empty set - lazy load
	let hasInitialized = false; // Track if we've shown the view once
	
	// Live countdown state
	let countdownInterval = null;
	
	// Get current user from persistent auth service (check cashier first, then desktop)
	$: activeUser = $cashierUser || $currentUser;
	$: authenticated = $isCashierAuthenticated || $isAuthenticated;
	$: currentUserData = activeUser;
	$: console.log('🔍 [MyTasks] Auth state:', { authenticated, currentUserData, isCashier: !!$cashierUser });

	// Subscribe to auth changes - don't auto-load, wait for filter change
	$: if (authenticated && activeUser?.id && !hasInitialized) {
		hasInitialized = true;
	}

	// Reactive filtering when any filter changes
	$: searchTerm, filterStatus, filterPriority, filterTaskType, filterDateRange, showCompleted, filterTasks();

	// Load task types when filter changes
	$: if (authenticated && activeUser?.id && hasInitialized) {
		if (filterTaskType === 'all') {
			loadTasksByType('all'); // Load all types when 'all' is selected
		} else if (filterTaskType !== 'all') {
			loadTasksByType(filterTaskType);
		}
	}

	// Load completed tasks when checkbox is checked
	$: if (showCompleted && authenticated && activeUser?.id && !loadedTaskTypes.has('completed')) {
		loadCompletedTasks();
	}

	onMount(() => {
		// Don't load anything on mount - let user trigger it via filter selection
		startCountdownTimer();
		
		// Cleanup on unmount
		return () => {
			stopCountdownTimer();
		};
	});

	// Function to smoothly remove a completed task from the list
	function removeCompletedTask(taskId) {
		console.log('✨ [MyTasks] Smoothly removing completed task:', taskId);
		tasks = tasks.filter(t => t.id !== taskId);
		filterTasks();
	}

	async function loadTasksByType(taskType) {
		let userId = activeUser?.id;
		
		if (!authenticated || !userId) {
			console.warn('❌ [MyTasks] No user ID available');
			return;
		}

		// Determine which task types to load
		const typesToLoad = [];
		
		if (taskType === 'all') {
			if (!loadedTaskTypes.has('receiving')) typesToLoad.push('receiving');
			if (!loadedTaskTypes.has('regular')) typesToLoad.push('regular');
			if (!loadedTaskTypes.has('quick_task')) typesToLoad.push('quick_task');
		} else if (taskType === 'receiving' && !loadedTaskTypes.has('receiving')) {
			typesToLoad.push('receiving');
		} else if (taskType === 'regular' && !loadedTaskTypes.has('regular')) {
			typesToLoad.push('regular');
		} else if (taskType === 'quick_task' && !loadedTaskTypes.has('quick_task')) {
			typesToLoad.push('quick_task');
		}

		if (typesToLoad.length === 0) {
			console.log('📦 [MyTasks] Task types already loaded, skipping load');
			return;
		}

		console.log('🔄 [MyTasks] Loading task types on demand:', typesToLoad);
		loading = true;
		
		try {
			let newTasks = [];

			// Load Receiving Tasks if needed - MINIMAL columns only + pagination
			if (typesToLoad.includes('receiving')) {
				console.log('📥 [MyTasks] Loading receiving tasks...');
				const startTime = performance.now();
				
				// CRITICAL: Only load PENDING and IN_PROGRESS tasks, not all 1261
				const { data: receivingTasks, error: receivingError } = await supabase
					.from('receiving_tasks')
					.select('id, title, description, priority, task_status, created_at, due_date, assigned_user_id, role_type, receiving_record_id, clearance_certificate_url, requires_original_bill_upload, requires_erp_reference')
					.eq('assigned_user_id', userId)
					.in('task_status', ['pending', 'in_progress'])  // ONLY load active tasks
					.limit(200);  // Hard limit to prevent huge queries

				if (receivingError) {
					console.warn('⚠️ [MyTasks] Error loading receiving tasks:', receivingError);
				}

				if (receivingTasks) {
					const loadTime = performance.now() - startTime;
					console.log(`⏱️ Receiving tasks loaded in ${loadTime.toFixed(0)}ms`, { count: receivingTasks.length });
					const receivingTasksFormatted = receivingTasks.map(task => ({
						id: task.id,
						title: task.title,
						description: task.description,
						priority: task.priority,
						status: task.task_status,
						created_at: task.created_at,
						due_date: task.due_date,
						due_time: null,
						deadline_datetime: task.due_date,
						assignment_id: task.id,
						assignment_status: task.task_status,
						assigned_at: task.created_at,
						assigned_by: null,
						assigned_by_name: 'System (Receiving)',
						assigned_to_user_id: task.assigned_user_id,
						schedule_date: null,
						schedule_time: null,
						role_type: task.role_type,
						receiving_record_id: task.receiving_record_id,
						clearance_certificate_url: task.clearance_certificate_url,
						require_task_finished: true,
						require_photo_upload: task.requires_original_bill_upload || false,
						require_erp_reference: task.requires_erp_reference || false,
						images: [],
						task_type: 'receiving'
					}));
					newTasks.push(...receivingTasksFormatted);
					loadedTaskTypes.add('receiving');
					console.log('✅ [MyTasks] Loaded receiving tasks:', { count: receivingTasksFormatted.length });
				}
			}

			// Load Regular Tasks if needed - SKIP nested joins and heavy operations
			if (typesToLoad.includes('regular')) {
				console.log('📝 [MyTasks] Loading regular tasks...');
				const startTime = performance.now();
				const { data: regularTasks, error: regularError } = await supabase
					.from('task_assignments')
					.select('id, task_id, assigned_to_user_id, status, assigned_at, deadline_datetime, assigned_by, assigned_by_name')
					.eq('assigned_to_user_id', userId)
					.in('status', ['pending', 'assigned', 'in_progress'])  // ONLY active tasks
					.limit(200);  // Hard limit

				if (regularError) {
					console.warn('⚠️ [MyTasks] Error loading regular tasks:', regularError);
				}

				if (regularTasks && regularTasks.length > 0) {
					// Get task details separately without join
					const taskIds = regularTasks.map(a => a.task_id);
					const { data: taskDetails } = await supabase
						.from('tasks')
						.select('id, title, description, priority, status, created_at')
						.in('id', taskIds);

					const taskMap = {};
					(taskDetails || []).forEach(t => {
						taskMap[t.id] = t;
					});

					const regularTasksFormatted = regularTasks.map(assignment => {
						const taskData = taskMap[assignment.task_id] || {};
						return {
							id: assignment.task_id,
							title: taskData.title || 'Untitled Task',
							description: taskData.description || '',
							priority: taskData.priority || 'medium',
							status: taskData.status || 'pending',
							created_at: taskData.created_at || assignment.assigned_at,
							due_date: null,
							due_time: null,
							deadline_datetime: assignment.deadline_datetime,
							assignment_id: assignment.id,
							assignment_status: assignment.status,
							assigned_at: assignment.assigned_at,
							assigned_by: assignment.assigned_by,
							assigned_by_name: assignment.assigned_by_name || 'Unknown User',
							assigned_to_user_id: assignment.assigned_to_user_id,
							schedule_date: null,
							schedule_time: null,
							require_task_finished: false,
							require_photo_upload: false,
							require_erp_reference: false,
							images: [],
							task_type: 'regular'
						};
					});

					const loadTime = performance.now() - startTime;
					console.log(`⏱️ Regular tasks loaded in ${loadTime.toFixed(0)}ms`, { count: regularTasksFormatted.length });
					newTasks.push(...regularTasksFormatted);
					loadedTaskTypes.add('regular');
					console.log('✅ [MyTasks] Loaded regular tasks:', { count: regularTasksFormatted.length });
				}
			}

			// Load Quick Tasks if needed - MINIMAL approach
			if (typesToLoad.includes('quick_task')) {
				console.log('⚡ [MyTasks] Loading quick tasks...');
				const startTime = performance.now();
				const { data: quickTasks, error: quickError } = await supabase
					.from('quick_task_assignments')
					.select('id, quick_task_id, assigned_to_user_id, status, created_at')
					.eq('assigned_to_user_id', userId)
					.in('status', ['assigned', 'in_progress'])  // ONLY active assignments
					.limit(200);  // Hard limit

				if (quickError) {
					console.warn('⚠️ [MyTasks] Error loading quick tasks:', quickError);
				}

				if (quickTasks && quickTasks.length > 0) {
					// Get quick task details separately
					const quickTaskIds = quickTasks.map(a => a.quick_task_id);
					const { data: qtDetails } = await supabase
						.from('quick_tasks')
						.select('id, title, description, priority, status, created_at, deadline_datetime, assigned_by')
						.in('id', quickTaskIds);

					const qtMap = {};
					(qtDetails || []).forEach(qt => {
						qtMap[qt.id] = qt;
					});

					const quickTasksFormatted = quickTasks.map(assignment => {
						const qt = qtMap[assignment.quick_task_id] || {};
						return {
							id: assignment.quick_task_id,
							title: qt.title || 'Untitled Quick Task',
							description: qt.description || '',
							priority: qt.priority || 'medium',
							status: qt.status || 'pending',
							created_at: qt.created_at || assignment.created_at,
							due_date: null,
							due_time: null,
							deadline_datetime: qt.deadline_datetime,
							assignment_id: assignment.id,
							assignment_status: assignment.status,
							assigned_at: assignment.created_at,
							assigned_by: qt.assigned_by,
							assigned_by_name: 'Assigned By',
							assigned_to_user_id: assignment.assigned_to_user_id,
							schedule_date: null,
							schedule_time: null,
							require_task_finished: false,
							require_photo_upload: false,
							require_erp_reference: false,
							images: [],
							task_type: 'quick_task'
						};
					});

					const loadTime = performance.now() - startTime;
					console.log(`⏱️ Quick tasks loaded in ${loadTime.toFixed(0)}ms`, { count: quickTasksFormatted.length });
					newTasks.push(...quickTasksFormatted);
					loadedTaskTypes.add('quick_task');
					console.log('✅ [MyTasks] Loaded quick tasks:', { count: quickTasksFormatted.length });
				}
			}

			// Merge with existing tasks
			tasks = [...tasks, ...newTasks];
			tasks.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
			filterTasks();
			
			console.log('✅ [MyTasks] Successfully loaded all tasks:', { 
				total: tasks.length, 
				loadedTypes: Array.from(loadedTaskTypes)
			});
		} catch (error) {
			console.error('❌ [MyTasks] Error loading tasks:', error);
		} finally {
			loading = false;
		}
	}

	async function loadCompletedTasks() {
		let userId = activeUser?.id;
		
		if (!authenticated || !userId) {
			console.warn('❌ [MyTasks] No user ID available');
			return;
		}

		console.log('⏳ [MyTasks] Loading completed tasks...');
		loading = true;
		
		try {
			let completedTasks = [];
			const startTime = performance.now();

			// Load completed receiving tasks
			const { data: completedReceiving, error: rcvError } = await supabase
				.from('receiving_tasks')
				.select('id, title, description, priority, task_status, created_at, due_date, assigned_user_id, role_type, receiving_record_id, clearance_certificate_url, requires_original_bill_upload, requires_erp_reference')
				.eq('assigned_user_id', userId)
				.eq('task_status', 'completed')
				.limit(100);

			if (rcvError) {
				console.warn('⚠️ [MyTasks] Error loading completed receiving tasks:', rcvError);
			}

			if (completedReceiving) {
				const completed = completedReceiving.map(task => ({
					id: task.id,
					title: task.title,
					description: task.description,
					priority: task.priority,
					status: task.task_status,
					created_at: task.created_at,
					due_date: task.due_date,
					due_time: null,
					deadline_datetime: task.due_date,
					assignment_id: task.id,
					assignment_status: task.task_status,
					assigned_at: task.created_at,
					assigned_by: null,
					assigned_by_name: 'System (Receiving)',
					assigned_to_user_id: task.assigned_user_id,
					schedule_date: null,
					schedule_time: null,
					role_type: task.role_type,
					receiving_record_id: task.receiving_record_id,
					clearance_certificate_url: task.clearance_certificate_url,
					require_task_finished: true,
					require_photo_upload: task.requires_original_bill_upload || false,
					require_erp_reference: task.requires_erp_reference || false,
					images: [],
					task_type: 'receiving'
				}));
				completedTasks.push(...completed);
				console.log('✅ Loaded completed receiving tasks:', { count: completed.length });
			}

			// Load completed regular tasks
			const { data: completedRegular, error: regError } = await supabase
				.from('task_assignments')
				.select('id, task_id, assigned_to_user_id, status, assigned_at, deadline_datetime, assigned_by, assigned_by_name')
				.eq('assigned_to_user_id', userId)
				.neq('status', 'pending')
				.neq('status', 'assigned')
				.neq('status', 'in_progress')
				.limit(100);

			if (regError) {
				console.warn('⚠️ [MyTasks] Error loading completed regular tasks:', regError);
			}

			if (completedRegular && completedRegular.length > 0) {
				const taskIds = completedRegular.map(a => a.task_id);
				const { data: taskDetails } = await supabase
					.from('tasks')
					.select('id, title, description, priority, status, created_at')
					.in('id', taskIds);

				const taskMap = {};
				(taskDetails || []).forEach(t => {
					taskMap[t.id] = t;
				});

				const completed = completedRegular.map(assignment => {
					const taskData = taskMap[assignment.task_id] || {};
					return {
						id: assignment.task_id,
						title: taskData.title || 'Untitled Task',
						description: taskData.description || '',
						priority: taskData.priority || 'medium',
						status: taskData.status || assignment.status,
						created_at: taskData.created_at || assignment.assigned_at,
						due_date: null,
						due_time: null,
						deadline_datetime: assignment.deadline_datetime,
						assignment_id: assignment.id,
						assignment_status: assignment.status,
						assigned_at: assignment.assigned_at,
						assigned_by: assignment.assigned_by,
						assigned_by_name: assignment.assigned_by_name || 'Unknown User',
						assigned_to_user_id: assignment.assigned_to_user_id,
						schedule_date: null,
						schedule_time: null,
						require_task_finished: false,
						require_photo_upload: false,
						require_erp_reference: false,
						images: [],
						task_type: 'regular'
					};
				});
				completedTasks.push(...completed);
				console.log('✅ Loaded completed regular tasks:', { count: completed.length });
			}

			// Load completed quick tasks
			const { data: completedQuick, error: qtError } = await supabase
				.from('quick_task_assignments')
				.select('id, quick_task_id, assigned_to_user_id, status, created_at')
				.eq('assigned_to_user_id', userId)
				.neq('status', 'assigned')
				.neq('status', 'in_progress')
				.limit(100);

			if (qtError) {
				console.warn('⚠️ [MyTasks] Error loading completed quick tasks:', qtError);
			}

			if (completedQuick && completedQuick.length > 0) {
				const quickTaskIds = completedQuick.map(a => a.quick_task_id);
				const { data: qtDetails } = await supabase
					.from('quick_tasks')
					.select('id, title, description, priority, status, created_at, deadline_datetime, assigned_by')
					.in('id', quickTaskIds);

				const qtMap = {};
				(qtDetails || []).forEach(qt => {
					qtMap[qt.id] = qt;
				});

				const completed = completedQuick.map(assignment => {
					const qt = qtMap[assignment.quick_task_id] || {};
					return {
						id: assignment.quick_task_id,
						title: qt.title || 'Untitled Quick Task',
						description: qt.description || '',
						priority: qt.priority || 'medium',
						status: qt.status || assignment.status,
						created_at: qt.created_at || assignment.created_at,
						due_date: null,
						due_time: null,
						deadline_datetime: qt.deadline_datetime,
						assignment_id: assignment.id,
						assignment_status: assignment.status,
						assigned_at: assignment.created_at,
						assigned_by: qt.assigned_by,
						assigned_by_name: 'Assigned By',
						assigned_to_user_id: assignment.assigned_to_user_id,
						schedule_date: null,
						schedule_time: null,
						require_task_finished: false,
						require_photo_upload: false,
						require_erp_reference: false,
						images: [],
						task_type: 'quick_task'
					};
				});
				completedTasks.push(...completed);
				console.log('✅ Loaded completed quick tasks:', { count: completed.length });
			}

			const loadTime = performance.now() - startTime;
			console.log(`⏱️ Completed tasks loaded in ${loadTime.toFixed(0)}ms`, { count: completedTasks.length });

			// Merge with existing tasks
			tasks = [...tasks, ...completedTasks];
			tasks.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
			loadedTaskTypes.add('completed');
			filterTasks();

			console.log('✅ [MyTasks] Successfully loaded completed tasks:', { total: tasks.length });
		} catch (error) {
			console.error('❌ [MyTasks] Error loading completed tasks:', error);
		} finally {
			loading = false;
		}
	}

	async function loadMyTasks() {
		// Refresh all currently loaded task types
		console.log('🔄 [MyTasks] Refreshing tasks...');
		loading = true;
		
		try {
			tasks = []; // Clear existing tasks
			loadedTaskTypes.clear(); // Reset loaded types
			
			// Reload completed tasks if they were being shown
			if (showCompleted) {
				await loadCompletedTasks();
			}
			
			// Reload task types that were previously loaded
			if (loadedTaskTypes.size === 0 && filterTaskType !== 'all') {
				await loadTasksByType(filterTaskType);
			} else if (filterTaskType !== 'all') {
				await loadTasksByType(filterTaskType);
			}
			
			console.log('✅ [MyTasks] Tasks refreshed successfully');
		} catch (error) {
			console.error('❌ [MyTasks] Error refreshing tasks:', error);
		} finally {
			loading = false;
			filterTasks();
		}
	}

	function filterTasks() {
		filteredTasks = tasks.filter(task => {
			// Hide completed tasks unless showCompleted is true
			if (!showCompleted && task.assignment_status === 'completed') {
				return false;
			}

			const matchesSearch = task.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
				task.description.toLowerCase().includes(searchTerm.toLowerCase());
			
			const matchesStatus = filterStatus === 'all' || task.assignment_status === filterStatus;
			const matchesPriority = filterPriority === 'all' || task.priority === filterPriority;
			const matchesTaskType = filterTaskType === 'all' || 
				task.task_type === filterTaskType;
			
			// Date range filtering
			let matchesDateRange = true;
			if (filterDateRange !== 'all' && task.deadline_datetime) {
				const now = new Date();
				const deadline = new Date(task.deadline_datetime);
				const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
				const taskDate = new Date(deadline.getFullYear(), deadline.getMonth(), deadline.getDate());
				
				if (filterDateRange === 'overdue') {
					matchesDateRange = deadline < now;
				} else if (filterDateRange === 'today') {
					matchesDateRange = taskDate.getTime() === today.getTime();
				} else if (filterDateRange === 'week') {
					const weekFromNow = new Date(today);
					weekFromNow.setDate(weekFromNow.getDate() + 7);
					matchesDateRange = taskDate >= today && taskDate < weekFromNow;
				} else if (filterDateRange === 'month') {
					const monthFromNow = new Date(today);
					monthFromNow.setMonth(monthFromNow.getMonth() + 1);
					matchesDateRange = taskDate >= today && taskDate < monthFromNow;
				}
			}
			
			return matchesSearch && matchesStatus && matchesPriority && matchesTaskType && matchesDateRange;
		});
	}

	function openTaskCompletion(task) {
		if (task.task_type === 'quick_task') {
			openQuickTaskCompletion(task);
		} else if (task.task_type === 'receiving') {
			openReceivingTaskCompletion(task);
		} else {
			const windowId = `task-completion-${task.id}`;
			openWindow({
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
						removeCompletedTask(task.id);
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
	}

	async function openQuickTaskCompletion(task) {
		// Open a proper completion modal instead of simple confirm
		const windowId = `quick-task-completion-${task.assignment_id}`;
		openWindow({
			id: windowId,
			title: `Complete Quick Task: ${task.title}`,
			component: QuickTaskCompletionDialog,
			props: {
				task: task,
				assignmentId: task.assignment_id,
				onComplete: () => {
					windowManager.closeWindow(windowId);
					removeCompletedTask(task.id);
				}
			},
			icon: '⚡',
			size: { width: 600, height: 700 },
			position: { 
				x: window.innerWidth / 2 - 300, 
				y: window.innerHeight / 2 - 350 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	async function openReceivingTaskCompletion(task) {
		const windowId = `receiving-task-completion-${task.id}`;
		openWindow({
			id: windowId,
			title: 'Complete Receiving Task',
			component: ReceivingTaskCompletionDialog,
			props: {
				taskId: task.id,
				receivingRecordId: task.receiving_record_id,
				onComplete: () => {
					windowManager.closeWindow(windowId);
					removeCompletedTask(task.id); // Smooth removal instead of full reload
				}
			},
			icon: '✅',
			size: { width: 500, height: 300 },
			position: { 
				x: window.innerWidth / 2 - 250, 
				y: window.innerHeight / 2 - 150 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function openTaskDetails(task) {
		if (task.task_type === 'quick_task') {
			openQuickTaskDetails(task);
		} else if (task.task_type === 'receiving') {
			openReceivingTaskDetails(task);
		} else {
			const windowId = `task-details-${task.id}`;
			openWindow({
				id: windowId,
				title: `Task Details: ${task.title}`,
				component: TaskDetailsModal,
				props: {
					task: task,
					windowId: windowId,
					onTaskCompleted: () => {
						removeCompletedTask(task.id);
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
	}

	function openQuickTaskDetails(task) {
		const windowId = `quick-task-details-${task.id}`;
		openWindow({
			id: windowId,
			title: `⚡ Quick Task Details: ${task.title}`,
			component: QuickTaskDetailsModal,
			props: {
				task: task,
				windowId: windowId,
				onTaskCompleted: () => {
					removeCompletedTask(task.id);
				}
			},
			icon: '⚡',
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

	function openReceivingTaskDetails(task) {
		const windowId = `receiving-task-details-${task.id}`;
		openWindow({
			id: windowId,
			title: `📦 Receiving Task: ${task.title}`,
			component: ReceivingTaskDetailsModal,
			props: {
				task: task,
				windowId: windowId,
				onTaskCompleted: () => {
					removeCompletedTask(task.id);
				}
			},
			icon: '📦',
			size: { width: 800, height: 600 },
			position: { 
				x: 100 + (Math.random() * 100), 
				y: 50 + (Math.random() * 50) 
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

	function getDeadlineDisplayFromDatetime(deadlineDatetime) {
		if (!deadlineDatetime) return { text: 'No deadline set', class: 'text-gray-500' };
		
		const now = new Date();
		const deadline = new Date(deadlineDatetime);
		
		// Check if overdue
		const isLate = now > deadline;
		
		if (isLate) {
			return {
				text: `Overdue since ${formatDate(deadline.toISOString().split('T')[0])} at ${formatTime(deadline.toTimeString().substring(0, 5))}`,
				class: 'text-red-600 font-semibold',
				isOverdue: true
			};
		}
		
		// Calculate time remaining
		const diffMs = deadline.getTime() - now.getTime();
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
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Task Type</label>
				<select
					bind:value={filterTaskType}
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
				>
					<option value="all">All Types</option>
					<option value="regular">Regular Tasks</option>
					<option value="quick">Quick Tasks</option>
					<option value="receiving">Receiving Tasks</option>
				</select>
			</div>
			<div>
				<label class="block text-sm font-medium text-gray-700 mb-1">Date Range</label>
				<select
					bind:value={filterDateRange}
					class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
				>
					<option value="all">All Dates</option>
					<option value="overdue">⚠️ Overdue</option>
					<option value="today">📅 Today</option>
					<option value="week">📆 This Week</option>
					<option value="month">🗓️ This Month</option>
				</select>
			</div>
		</div>
		
		<!-- Show Completed Toggle -->
		<div class="mt-4 px-6 bg-blue-50 border border-blue-200 rounded-lg p-3">
			<div class="flex items-start space-x-3">
				<div class="flex-1">
					<label class="flex items-center space-x-2 cursor-pointer">
						<input 
							type="checkbox" 
							bind:checked={showCompleted}
							class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
						/>
						<span class="text-sm font-medium text-gray-700">Show completed tasks</span>
					</label>
					<p class="text-xs text-gray-600 mt-1">💡 Only active tasks are loaded for performance. Load completed tasks if needed.</p>
				</div>
			</div>
		</div>
	</div>

	<!-- Tasks List -->
	<div class="flex-1 overflow-y-auto p-6">
		{#if loading}
			<div class="flex items-center justify-center h-64">
				<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
			</div>
		{:else if tasks.length === 0}
			<div class="text-center py-12">
				<svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
				</svg>
				<h3 class="text-lg font-medium text-gray-900 mb-2">No tasks loaded yet</h3>
				<p class="text-gray-600 mb-4">Select a task type from the filters above to load your tasks</p>
				<button 
					on:click={() => filterTaskType = 'receiving'}
					class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
				>
					Load Receiving Tasks
				</button>
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
										{#if task.task_type === 'quick_task'}
											<span class="px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
												⚡ QUICK TASK
											</span>
										{/if}
										<span class="px-2 py-1 rounded-full text-xs font-medium {getPriorityColor(task.priority)}">
											{task.priority?.toUpperCase()}
										</span>
										<span class="px-2 py-1 rounded-full text-xs font-medium {getStatusColor(task.assignment_status)}">
											{task.assignment_status?.replace('_', ' ').toUpperCase()}
										</span>
									</div>
									
									<p class="text-gray-600 mb-3">{task.description}</p>
									
									<!-- Quick Task specific fields -->
									{#if task.task_type === 'quick_task'}
										<div class="mb-3 p-3 bg-purple-50 rounded-lg border border-purple-200">
											<div class="grid grid-cols-2 gap-2 text-sm">
												{#if task.issue_type}
													<div>
														<span class="font-medium text-purple-700">Issue Type:</span>
														<span class="text-purple-900">{task.issue_type.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}</span>
													</div>
												{/if}
												{#if task.price_tag}
													<div>
														<span class="font-medium text-purple-700">Price Tag:</span>
														<span class="text-purple-900">{task.price_tag.toUpperCase()}</span>
													</div>
												{/if}
											</div>
										</div>
									{/if}
									
									<!-- Task Attachments Indicator -->
									{#if task.images && task.images.length > 0}
										<div class="mb-4">
											<div class="inline-flex items-center space-x-2 px-3 py-2 bg-blue-50 text-blue-700 rounded-lg border border-blue-200">
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
												</svg>
												<span class="text-sm font-medium">
													{task.task_type === 'quick_task' ? 'Quick task has' : 'Task has'} {task.images.length} attachment{task.images.length !== 1 ? 's' : ''}
												</span>
											</div>
										</div>
									{/if}
									
									<div class="grid grid-cols-2 gap-4 text-sm text-gray-500">
										<div>
											<span class="font-medium">Priority:</span> {task.priority || 'Not set'}
										</div>
										<div>
											<span class="font-medium">Task Status:</span> {task.status || 'Unknown'}
										</div>
										{#if (task.task_type === 'quick_task' || task.task_type === 'receiving') && task.deadline_datetime}
											{@const deadlineInfo = getDeadlineDisplayFromDatetime(task.deadline_datetime)}
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
										{:else if task.deadline_date}
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
											<span class="font-medium">Assigned by:</span> 
											{task.assigned_by_name || 'Unknown'}
										</div>
									</div>

								</div>
								
								<div class="ml-4 flex flex-col space-y-2">
									{#if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled' && task.assigned_to_user_id === currentUserData?.id}
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

<style>
	.my-tasks-view {
		background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
	}
</style>