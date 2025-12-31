<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { supabase } from '$lib/utils/supabase';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import SendWarningModal from './SendWarningModal.svelte';
	
	let loading = true;
	let error = null;
	
	// Task Statistics (Section 1)
	let taskStats = {
		totalAssigned: 0,
		totalCompleted: 0,
		totalOverdue: 0,
		completionPercentage: 0,
		overduePercentage: 0
	};
	
	// Branch Filter
	let branches = [];
	let selectedBranch = 'all';
	let branchFilterMode = 'all'; // 'all' or 'choose'
	
	// Task Assignment Data (Section 2)
	let assignmentData = [];
	let filteredAssignmentData = [];

	// Initialize variables to prevent undefined errors
	$: if (!Array.isArray(filteredAssignmentData)) {
		filteredAssignmentData = [];
	}

	onMount(() => {
		loadData();
	});

	async function loadData() {
		loading = true;
		error = null;
		
		try {
			await Promise.all([
				loadTaskStatistics(),
				loadBranches(),
				loadAssignmentData()
			]);
		} catch (err) {
			error = 'Failed to load task status data: ' + err.message;
			console.error('Error loading task status data:', err);
		} finally {
			loading = false;
		}
	}

	async function loadTaskStatistics() {
		try {
			// Get total tasks count as sum of task_assignments, quick_task_assignments, and receiving_tasks
			// This matches TaskMaster's counting approach
			const [taskAssignRes, quickAssignRes, receivingTasksRes] = await Promise.all([
				supabase.from('task_assignments').select('*', { count: 'exact', head: true }),
				supabase.from('quick_task_assignments').select('*', { count: 'exact', head: true }),
				supabase.from('receiving_tasks').select('*', { count: 'exact', head: true })
			]);

			if (taskAssignRes.error) throw taskAssignRes.error;
			if (quickAssignRes.error) throw quickAssignRes.error;
			if (receivingTasksRes.error) throw receivingTasksRes.error;

			const totalTasksCount = (taskAssignRes.count || 0) + (quickAssignRes.count || 0) + (receivingTasksRes.count || 0);

			// Get completed tasks count as sum of task_completions, quick_task_completions, and completed receiving_tasks
			// This matches TaskMaster's completed counting approach
			const [taskCompRes, quickCompRes, receivingCompRes] = await Promise.all([
				supabase.from('task_completions').select('*', { count: 'exact', head: true }),
				supabase.from('quick_task_completions').select('*', { count: 'exact', head: true }),
				supabase.from('receiving_tasks').select('*', { count: 'exact', head: true }).eq('task_status', 'completed')
			]);

			if (taskCompRes.error) throw taskCompRes.error;
			if (quickCompRes.error) throw quickCompRes.error;
			if (receivingCompRes.error) throw receivingCompRes.error;

			const completedTasksCount = (taskCompRes.count || 0) + (quickCompRes.count || 0) + (receivingCompRes.count || 0);

			// For overdue tasks, we need to fetch data to check deadlines
			// Query to get overdue task statistics (regular tasks)
			const { data: regularTasks, error: regularError } = await supabase
				.from('task_assignments')
				.select(`
					id,
					status,
					deadline_datetime
				`)
				.neq('status', 'completed');

			if (regularError) throw regularError;

			// Query to get overdue quick task statistics
			const { data: quickTaskAssignments, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select(`
					id,
					status,
					quick_tasks(deadline_datetime)
				`)
				.neq('status', 'completed');

			if (quickError) throw quickError;

			// Query to get overdue receiving task statistics
			const { data: receivingTasks, error: receivingError } = await supabase
				.from('receiving_tasks')
				.select(`
					id,
					task_status,
					due_date
				`)
				.neq('task_status', 'completed');

			if (receivingError) throw receivingError;

			const now = new Date();
			
			// Process overdue regular tasks
			const regularOverdue = regularTasks.filter(t => {
				return t.deadline_datetime && 
					   new Date(t.deadline_datetime) < now;
			}).length;

			// Process overdue quick tasks
			const quickOverdue = quickTaskAssignments.filter(t => {
				return t.quick_tasks?.deadline_datetime && 
					   new Date(t.quick_tasks.deadline_datetime) < now;
			}).length;

			// Process overdue receiving tasks
			const receivingOverdue = receivingTasks.filter(t => {
				return t.due_date && 
					   new Date(t.due_date) < now;
			}).length;

			// Combine overdue statistics from all three task types
			const totalOverdue = regularOverdue + quickOverdue + receivingOverdue;

			taskStats = {
				totalAssigned: totalTasksCount,
				totalCompleted: completedTasksCount,
				totalOverdue: totalOverdue,
				completionPercentage: totalTasksCount > 0 ? Math.round((completedTasksCount / totalTasksCount) * 100) : 0,
				overduePercentage: totalTasksCount > 0 ? Math.round((totalOverdue / totalTasksCount) * 100) : 0
			};

			console.log('📊 Task statistics loaded:', {
				total: totalTasksCount,
				completed: completedTasksCount,
				overdue: totalOverdue,
				percentages: { completion: taskStats.completionPercentage, overdue: taskStats.overduePercentage }
			});
		} catch (err) {
			console.error('Error loading task statistics:', err);
			throw err;
		}
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en')
				.order('name_en');

			if (error) throw error;
			
			// Map the data to include 'name' field for compatibility
			branches = (data || []).map(branch => ({
				id: branch.id,
				name: branch.name_en
			}));
		} catch (err) {
			console.error('Error loading branches:', err);
			throw err;
		}
	}

	async function loadAssignmentData() {
		try {
			// Load regular task assignments (only overdue ones)
			const { data: regularAssignments, error: regularError } = await supabase
				.from('task_assignments')
				.select(`
					id,
					assigned_by,
					assigned_by_name,
					assigned_to_user_id,
					assigned_to_branch_id,
					assignment_type,
					status,
					deadline_datetime,
					reassigned_from,
					assigned_at,
					tasks(id, title, description, priority)
				`)
				.neq('status', 'completed') // Exclude completed tasks
				.not('deadline_datetime', 'is', null); // Only tasks with deadlines

			if (regularError) throw regularError;

			// Load quick task assignments (only overdue ones)
			const { data: quickAssignments, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select(`
					id,
					assigned_to_user_id,
					status,
					accepted_at,
					started_at,
					completed_at,
					created_at,
					quick_tasks(
						id,
						title,
						description,
						priority,
						issue_type,
						deadline_datetime,
						assigned_by,
						assigned_to_branch_id,
						created_at
					)
				`)
				.neq('status', 'completed'); // Exclude completed tasks

			if (quickError) throw quickError;

			// Load receiving task assignments (only overdue ones)
			const { data: receivingAssignments, error: receivingError } = await supabase
				.from('receiving_tasks')
				.select(`
					id,
					assigned_user_id,
					task_status,
					due_date,
					created_at,
					completed_at,
					completed_by_user_id,
					title,
					description,
					priority,
					receiving_record_id,
					receiving_records(
						id,
						bill_number,
						bill_amount,
						vendor_id,
						branch_id,
						user_id,
						branch:branch_id(id, name_en)
					)
				`)
				.neq('task_status', 'completed') // Exclude completed tasks
				.not('due_date', 'is', null); // Only tasks with deadlines

			if (receivingError) throw receivingError;

			// Get unique vendor IDs and branch IDs from receiving assignments to fetch vendor names
			const vendorKeys = [...new Set(receivingAssignments
				.filter(a => a.receiving_records?.vendor_id && a.receiving_records?.branch_id)
				.map(a => `${a.receiving_records.vendor_id}-${a.receiving_records.branch_id}`)
			)];

			// Get vendor details for the composite keys
			let vendorsData = [];
			if (vendorKeys.length > 0) {
				const vendorFilters = vendorKeys.map(key => {
					const [vendor_id, branch_id] = key.split('-');
					return { erp_vendor_id: parseInt(vendor_id), branch_id: parseInt(branch_id) };
				});

				// Build OR condition for vendor lookup
				const { data: vendors, error: vendorsError } = await supabase
					.from('vendors')
					.select('erp_vendor_id, branch_id, vendor_name')
					.or(vendorFilters.map(v => `and(erp_vendor_id.eq.${v.erp_vendor_id},branch_id.eq.${v.branch_id})`).join(','));

				if (vendorsError) {
					console.warn('Failed to load vendor names:', vendorsError);
				} else {
					vendorsData = vendors || [];
				}
			}

			// Get all unique user IDs from all three task types
			const userIds = [...new Set([
				...regularAssignments.map(a => a.assigned_by).filter(id => id && typeof id === 'string' && id.length === 36),
				...regularAssignments.map(a => a.assigned_to_user_id).filter(id => id && typeof id === 'string' && id.length === 36),
				...quickAssignments.map(a => a.assigned_to_user_id).filter(id => id && typeof id === 'string' && id.length === 36),
				...quickAssignments.map(a => a.quick_tasks?.assigned_by).filter(id => id && typeof id === 'string' && id.length === 36),
				...receivingAssignments.map(a => a.assigned_user_id).filter(id => id && typeof id === 'string' && id.length === 36),
				...receivingAssignments.map(a => a.completed_by_user_id).filter(id => id && typeof id === 'string' && id.length === 36),
				...receivingAssignments.map(a => a.receiving_records?.user_id).filter(id => id && typeof id === 'string' && id.length === 36)
			])].filter(Boolean);

			// Get user details
			let usersData = [];
			if (userIds.length > 0) {
				const { data: users, error: usersError } = await supabase
					.from('users')
					.select(`
						id,
						username,
						employee_id,
						branch_id,
						hr_employees(id, name),
						branches(id, name_en)
					`)
					.in('id', userIds);

				if (usersError) throw usersError;
				usersData = users || [];
			}

			// Fetch completions for assignments (so we can compute status from actual completions)
			let completionsMap = {};
			try {
				const allAssignmentIds = [
					...new Set([
						...regularAssignments.map(a => a.id),
						...quickAssignments.map(a => a.id),
						...receivingAssignments.map(a => a.id)
					])
				].filter(Boolean);

				if (allAssignmentIds.length > 0) {
					const { data: completions, error: completionsError } = await supabase
						.from('task_completions')
						.select('assignment_id, completed_at')
						.in('assignment_id', allAssignmentIds);

					if (completionsError) {
						console.warn('Failed to load task completions for status computation:', completionsError);
					} else {
						completionsMap = (completions || []).reduce((acc, c) => {
							if (c && c.assignment_id) acc[c.assignment_id] = c;
							return acc;
						}, {});
					}
				}
			} catch (err) {
				console.warn('Error while fetching completions map:', err);
			}

			// Define current time for overdue filtering
			const now = new Date();

			// Transform regular assignments (filter for overdue only)
			const processedRegularAssignments = regularAssignments
				.filter(assignment => {
					const deadline = assignment.deadline_datetime ? new Date(assignment.deadline_datetime) : null;
					return deadline && deadline < now; // Only overdue tasks
				})
				.map(assignment => {
					const assignedByUser = usersData.find(u => u.id === assignment.assigned_by);
					const assignedToUser = usersData.find(u => u.id === assignment.assigned_to_user_id);
					
					const deadline = new Date(assignment.deadline_datetime);
					// Determine if assignment has a completion record (prefer completions table)
					const completionRecord = completionsMap[assignment.id];
					const isCompleted = !!completionRecord;
					const isOverdue = true; // All tasks in this list are overdue

					return {
						id: assignment.id,
						type: 'regular',
						task_title: assignment.tasks?.title || 'Unknown Task',
						task_description: assignment.tasks?.description || '',
						priority: assignment.tasks?.priority || 'Medium',
						assigned_by: assignedByUser?.hr_employees?.name || assignedByUser?.username || assignment.assigned_by_name || 'Unknown',
						assigned_by_id: assignment.assigned_by,
						assigned_to: assignedToUser?.hr_employees?.name || assignedToUser?.username || 'Unknown',
						assigned_to_id: assignment.assigned_to_user_id,
						assigned_to_username: assignedToUser?.username || 'Unknown',
						assigned_to_branch: assignedToUser?.branches?.name_en || 'Unknown',
						status: assignment.status,
						completed_at: completionRecord?.completed_at || null,
						deadline: assignment.deadline_datetime,
						assigned_at: assignment.assigned_at,
						is_overdue: isOverdue,
						is_near_deadline: false,
						warning_level: 'critical'
					};
				});

			// Transform quick task assignments (filter for overdue only)
			const processedQuickAssignments = quickAssignments
				.filter(assignment => {
					const deadline = assignment.quick_tasks?.deadline_datetime ? new Date(assignment.quick_tasks.deadline_datetime) : null;
					return deadline && deadline < now; // Only overdue tasks
				})
				.map(assignment => {
					const assignedByUser = usersData.find(u => u.id === assignment.quick_tasks?.assigned_by);
					const assignedToUser = usersData.find(u => u.id === assignment.assigned_to_user_id);
					
					const deadline = new Date(assignment.quick_tasks.deadline_datetime);
					// Check for completion record in completions map, or existing completed_at on quick assignment
					const completionRecord = completionsMap[assignment.id];
					const isCompleted = !!completionRecord || !!assignment.completed_at;
					const isOverdue = true; // All tasks in this list are overdue

					return {
						id: assignment.id,
						type: 'quick',
						task_title: assignment.quick_tasks?.title || 'Unknown Quick Task',
						task_description: assignment.quick_tasks?.description || '',
						priority: assignment.quick_tasks?.priority || 'Medium',
						issue_type: assignment.quick_tasks?.issue_type || '',
						assigned_by: assignedByUser?.hr_employees?.name || assignedByUser?.username || 'Unknown',
						assigned_by_id: assignment.quick_tasks?.assigned_by,
						assigned_to: assignedToUser?.hr_employees?.name || assignedToUser?.username || 'Unknown',
						assigned_to_id: assignment.assigned_to_user_id,
						assigned_to_username: assignedToUser?.username || 'Unknown',
						assigned_to_branch: assignedToUser?.branches?.name_en || 'Unknown',
						status: assignment.status,
						completed_at: completionRecord?.completed_at || assignment.completed_at || null,
						deadline: assignment.quick_tasks?.deadline_datetime,
						assigned_at: assignment.created_at,
						accepted_at: assignment.accepted_at,
						started_at: assignment.started_at,
						is_overdue: isOverdue,
						is_near_deadline: false,
						warning_level: 'critical'
					};
				});

			// Transform receiving task assignments (filter for overdue only)
			const processedReceivingAssignments = receivingAssignments
				.filter(assignment => {
					const deadline = assignment.due_date ? new Date(assignment.due_date) : null;
					return deadline && deadline < now; // Only overdue tasks
				})
				.map(assignment => {
					const assignedToUser = usersData.find(u => u.id === assignment.assigned_user_id);
					const createdByUser = usersData.find(u => u.id === assignment.receiving_records?.user_id);
					
					// Find vendor name from vendorsData
					const vendor = vendorsData.find(v => 
						v.erp_vendor_id === assignment.receiving_records?.vendor_id && 
						v.branch_id === assignment.receiving_records?.branch_id
					);
					
					const deadline = new Date(assignment.due_date);
					const isCompleted = !!assignment.completed_at;
					const isOverdue = true; // All tasks in this list are overdue

					return {
						id: assignment.id,
						type: 'receiving',
						task_title: assignment.title || `Receiving Task - ${vendor?.vendor_name || 'Unknown Vendor'}`,
						task_description: assignment.description || `Bill: ${assignment.receiving_records?.bill_number || 'N/A'} - Amount: ${assignment.receiving_records?.bill_amount || 'N/A'}`,
						priority: assignment.priority || 'Medium',
						assigned_by: createdByUser?.hr_employees?.name || createdByUser?.username || 'System',
						assigned_by_id: assignment.receiving_records?.user_id || null,
						assigned_to: assignment.assigned_user_id ? (assignedToUser?.hr_employees?.name || assignedToUser?.username || 'Unknown') : 'Unassigned',
						assigned_to_id: assignment.assigned_user_id,
						assigned_to_username: assignment.assigned_user_id ? (assignedToUser?.username || 'Unknown') : 'Unassigned',
						assigned_to_branch: assignment.receiving_records?.branch?.name_en || assignedToUser?.branches?.name_en || 'Unknown',
						status: assignment.task_status,
						completed_at: assignment.completed_at,
						deadline: assignment.due_date,
						assigned_at: assignment.created_at,
						is_overdue: isOverdue,
						is_near_deadline: false,
						warning_level: 'critical'
					};
				});

			// Combine and sort all assignments
			assignmentData = [...processedRegularAssignments, ...processedQuickAssignments, ...processedReceivingAssignments]
				.sort((a, b) => {
					// Sort by warning level first (critical, warning, normal)
					const warningOrder = { critical: 0, warning: 1, normal: 2 };
					if (warningOrder[a.warning_level] !== warningOrder[b.warning_level]) {
						return warningOrder[a.warning_level] - warningOrder[b.warning_level];
					}
					// Then by deadline
					if (a.deadline && b.deadline) {
						return new Date(a.deadline).getTime() - new Date(b.deadline).getTime();
					}
					if (a.deadline) return -1;
					if (b.deadline) return 1;
					// Finally by assigned date
					return new Date(b.assigned_at).getTime() - new Date(a.assigned_at).getTime();
				});

			// Apply branch filter
			applyBranchFilter();

		} catch (err) {
			console.error('Error loading assignment data:', err);
			// Initialize empty arrays to prevent undefined errors
			assignmentData = [];
			filteredAssignmentData = [];
			throw err;
		}
	}

	function applyBranchFilter() {
		if (branchFilterMode === 'all' || selectedBranch === 'all') {
			filteredAssignmentData = [...assignmentData];
		} else {
			filteredAssignmentData = assignmentData.filter(item => {
				// Filter by selected branch - you'll need to implement branch matching logic
				return true; // For now, show all
			});
		}
	}

	function setBranchFilter(mode) {
		branchFilterMode = mode;
		if (mode === 'all') {
			selectedBranch = 'all';
		}
		applyBranchFilter();
	}

	function handleBranchChange() {
		applyBranchFilter();
	}

	async function sendReminder(assignment) {
		try {
			// Create reminder notification using notificationManagement for proper push notification support
			const notificationData = {
				title: 'Task Reminder',
				message: `Reminder: You have pending tasks assigned by ${assignment.assigned_by}.\n\nTask: ${assignment.task_title}\n\nPlease check your tasks and complete them as soon as possible.`,
				type: 'info',
				priority: 'medium',
				target_type: 'specific_users',
				target_users: [assignment.assigned_to_id]
			};

			// Pass the assigned_by name instead of assigned_by_id (UUID)
			// @ts-ignore - type inference issue with literal types in JavaScript context
			await notificationManagement.createNotification(notificationData, assignment.assigned_by);

			alert('Reminder notification sent successfully with push notification!');
		} catch (err) {
			console.error('Error sending reminder:', err);
			alert('Failed to send reminder notification: ' + err.message);
		}
	}

	function openWarningModal(assignment) {
		// Open SendWarningModal as a window instead of a modal
		openWindow({
			component: SendWarningModal,
			title: 'Generate Warning',
			props: {
				assignment: assignment,
				onClose: () => {
					// Refresh the data when warning is completed
					loadTaskStatistics();
					loadAssignmentData();
				}
			},
			resizable: true
		});
	}
</script>

<div class="task-status-view">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">Task Status Dashboard</h1>
			<p class="subtitle">Monitor task progress and send notifications</p>
		</div>
		<button on:click={loadData} class="refresh-btn" disabled={loading}>
			<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
			</svg>
			<span>Refresh</span>
		</button>
	</div>

	{#if error}
		<div class="error-message">
			{error}
		</div>
	{/if}

	{#if loading}
		<div class="loading-section">
			<div class="loading-spinner"></div>
			<p>Loading task status data...</p>
		</div>
	{:else}
		<!-- Section 1: Task Statistics -->
		<div class="stats-section">
			<h2 class="section-title">Task Overview</h2>
			<div class="stats-grid">
				<div class="stat-card">
					<div class="stat-icon bg-blue-100">
						<svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
						</svg>
					</div>
					<div class="stat-content">
						<h3 class="stat-label">Total Assigned Tasks</h3>
						<p class="stat-value">{taskStats.totalAssigned}</p>
					</div>
				</div>

				<div class="stat-card">
					<div class="stat-icon bg-green-100">
						<svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
					</div>
					<div class="stat-content">
						<h3 class="stat-label">Total Completed Tasks</h3>
						<p class="stat-value">{taskStats.totalCompleted}</p>
						<span class="stat-percentage text-green-600">{taskStats.completionPercentage}%</span>
					</div>
				</div>

				<div class="stat-card">
					<div class="stat-icon bg-red-100">
						<svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
						</svg>
					</div>
					<div class="stat-content">
						<h3 class="stat-label">Total Overdue Tasks</h3>
						<p class="stat-value">{taskStats.totalOverdue}</p>
						<span class="stat-percentage text-red-600">{taskStats.overduePercentage}%</span>
					</div>
				</div>
			</div>
		</div>

		<!-- Section 2: Branch Filter and Assignment Table -->
		<div class="assignments-section">
			<div class="section-header">
				<h2 class="section-title">Overdue Task Assignments ({filteredAssignmentData.length})</h2>
				
				<!-- Branch Filter Buttons -->
				<div class="branch-filter">
					<button 
						class="filter-btn {branchFilterMode === 'all' ? 'active' : ''}"
						on:click={() => setBranchFilter('all')}
					>
						All Branches
					</button>
					<button 
						class="filter-btn {branchFilterMode === 'choose' ? 'active' : ''}"
						on:click={() => setBranchFilter('choose')}
					>
						Choose Branch
					</button>
					
					{#if branchFilterMode === 'choose'}
						<select bind:value={selectedBranch} on:change={handleBranchChange} class="branch-select">
							<option value="all">All Branches</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name}</option>
							{/each}
						</select>
					{/if}
				</div>
			</div>

			<!-- Assignment Table -->
			<div class="table-container">
				{#if filteredAssignmentData.length === 0}
					<div class="empty-state">
						<svg class="w-16 h-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
						</svg>
						<h3>No Task Assignments Found</h3>
						<p>No task assignments match the current filter criteria.</p>
					</div>
				{:else}
					<table class="assignments-table">
						<thead>
							<tr>
								<th>Task Type</th>
								<th>Task Details</th>
								<th>Assigned By</th>
								<th>Assigned To</th>
								<th>Branch</th>
								<th>Status</th>
								<th>Deadline</th>
								<th>Time Overdue</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredAssignmentData as assignment}
								<tr class="assignment-row {assignment.warning_level}">
									<td>
										<span class="task-type-badge {assignment.type}">
											{assignment.type === 'regular' ? 'Regular' : assignment.type === 'quick' ? 'Quick' : 'Receiving'}
										</span>
									</td>
									<td>
										<div class="task-details">
											<div class="task-title">{assignment.task_title}</div>
											{#if assignment.task_description}
												<div class="task-description">{assignment.task_description}</div>
											{/if}
											<div class="task-priority">Priority: {assignment.priority}</div>
											{#if assignment.warning_level === 'critical'}
												<div class="warning-badge critical">⚠️ OVERDUE</div>
											{:else if assignment.warning_level === 'warning'}
												<div class="warning-badge warning">⏰ Due Soon</div>
											{/if}
										</div>
									</td>
									<td class="font-medium">{assignment.assigned_by}</td>
									<td>
										<div class="user-info">
											<span class="username">{assignment.assigned_to}</span>
										</div>
									</td>
									<td>{assignment.assigned_to_branch}</td>
									<td>
										<span class="status-badge {assignment.status}">
											{assignment.status.charAt(0).toUpperCase() + assignment.status.slice(1)}
										</span>
									</td>
									<td>
										{#if assignment.deadline}
											<div class="deadline-info">
												{new Date(assignment.deadline).toLocaleDateString('en-GB', {
													day: '2-digit',
													month: '2-digit', 
													year: 'numeric'
												})}
												<div class="deadline-time">
													{new Date(assignment.deadline).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
												</div>
											</div>
										{:else}
											<span class="no-deadline">No deadline</span>
										{/if}
									</td>
									<td>
										{#if assignment.deadline && new Date(assignment.deadline) < new Date()}
											{@const overdueDuration = Math.floor((new Date() - new Date(assignment.deadline)) / 1000)}
											{@const days = Math.floor(overdueDuration / 86400)}
											{@const hours = Math.floor((overdueDuration % 86400) / 3600)}
											<div class="overdue-time critical">
												{#if days > 0}
													{days}d {hours}h
												{:else if hours > 0}
													{hours}h
												{:else}
													&lt;1h
												{/if}
												<div class="overdue-label">overdue</div>
											</div>
										{:else}
											<span class="not-overdue">-</span>
										{/if}
									</td>
									<td>
										<div class="action-buttons">
											<button 
												class="action-btn reminder-btn"
												on:click={() => sendReminder(assignment)}
											>
												📧 Reminder
											</button>
											<button 
												class="action-btn warning-btn"
												on:click={() => openWarningModal(assignment)}
											>
												⚠️ Warning
											</button>
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.task-status-view {
		padding: 0;
		height: calc(100vh - 50px);
		max-height: calc(100vh - 50px);
		background: white;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		box-sizing: border-box;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0;
		padding: 24px 24px 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		flex-shrink: 0;
		background: white;
		z-index: 10;
	}

	.title-section h1.title {
		font-size: 28px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #e5e7eb;
		border-color: #9ca3af;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 16px;
		border-radius: 8px;
		margin-bottom: 24px;
	}

	.loading-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 64px;
		color: #6b7280;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.stats-section {
		margin-bottom: 0;
		padding: 24px;
		flex-shrink: 0;
		background: white;
		border-bottom: 1px solid #e5e7eb;
	}

	.section-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 16px 0;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 20px;
	}

	.stat-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 20px;
		display: flex;
		align-items: center;
		gap: 16px;
		transition: all 0.2s ease;
	}

	.stat-card:hover {
		border-color: #d1d5db;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
	}

	.stat-icon {
		width: 48px;
		height: 48px;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.stat-content {
		flex: 1;
	}

	.stat-label {
		font-size: 14px;
		font-weight: 500;
		color: #6b7280;
		margin: 0 0 4px 0;
	}

	.stat-value {
		font-size: 28px;
		font-weight: 700;
		color: #111827;
		margin: 0;
	}

	.stat-percentage {
		font-size: 14px;
		font-weight: 600;
		margin-left: 8px;
	}

	.assignments-section {
		margin-bottom: 0;
		flex: 1;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		padding: 0 24px 24px 24px;
		min-height: 0;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
		flex-wrap: wrap;
		gap: 16px;
		flex-shrink: 0;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.branch-filter {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.filter-btn {
		padding: 8px 16px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.filter-btn:hover {
		border-color: #9ca3af;
	}

	.filter-btn.active {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	.branch-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		min-width: 160px;
	}

	.table-container {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
		flex: 1;
		display: flex;
		flex-direction: column;
		min-height: 0;
	}

	.assignments-table {
		width: 100%;
		border-collapse: collapse;
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: hidden;
	}

	.assignments-table thead {
		display: block;
		background: #f9fafb;
		flex-shrink: 0;
		z-index: 5;
	}

	.assignments-table tbody {
		display: block;
		overflow-y: auto;
		overflow-x: hidden;
		flex: 1;
		min-height: 0;
	}

	.assignments-table thead tr,
	.assignments-table tbody tr {
		display: table;
		width: 100%;
		table-layout: fixed;
	}

	.assignments-table th,
	.assignments-table td {
		padding: 12px 16px;
		text-align: left;
		border-bottom: 1px solid #e5e7eb;
	}

	.assignments-table th {
		background: #f9fafb;
		font-weight: 600;
		color: #374151;
		font-size: 14px;
	}

	.assignments-table td {
		font-size: 14px;
		color: #6b7280;
	}

	.assignments-table tbody tr:hover {
		background: #f9fafb;
	}

	.user-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.username {
		font-weight: 500;
		color: #111827;
	}

	.employee-name {
		font-size: 12px;
		color: #6b7280;
	}

	.count-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 32px;
		height: 24px;
		padding: 0 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.count-total {
		background: #dbeafe;
		color: #1d4ed8;
	}

	.count-completed {
		background: #d1fae5;
		color: #065f46;
	}

	.count-overdue {
		background: #fee2e2;
		color: #dc2626;
	}

	.count-reassigned {
		background: #fef3c7;
		color: #d97706;
	}

	.action-buttons {
		display: flex;
		gap: 8px;
	}

	.action-btn {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 6px 12px;
		border: 1px solid;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.reminder-btn {
		border-color: #3b82f6;
		color: #3b82f6;
		background: white;
	}

	.reminder-btn:hover {
		background: #3b82f6;
		color: white;
	}

	.warning-btn {
		border-color: #f59e0b;
		color: #f59e0b;
		background: white;
	}

	.warning-btn:hover {
		background: #f59e0b;
		color: white;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 64px;
		color: #6b7280;
		text-align: center;
	}

	.empty-state h3 {
		font-size: 18px;
		font-weight: 600;
		color: #374151;
		margin: 16px 0 8px 0;
	}

	/* Task Type and Warning Badges */
	.task-type-badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.task-type-badge.regular {
		background: #dbeafe;
		color: #1d4ed8;
	}

	.task-type-badge.quick {
		background: #fef3c7;
		color: #d97706;
	}

	.task-type-badge.receiving {
		background: #dcfce7;
		color: #16a34a;
	}

	.task-details {
		max-width: 300px;
	}

	.task-title {
		font-weight: 600;
		color: #111827;
		margin-bottom: 4px;
	}

	.task-description {
		font-size: 12px;
		color: #6b7280;
		margin-bottom: 4px;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.task-priority {
		font-size: 11px;
		color: #9ca3af;
		margin-bottom: 4px;
	}

	.warning-badge {
		display: inline-block;
		padding: 2px 6px;
		border-radius: 8px;
		font-size: 10px;
		font-weight: 600;
		margin-top: 4px;
	}

	.warning-badge.critical {
		background: #fecaca;
		color: #dc2626;
	}

	.warning-badge.warning {
		background: #fed7aa;
		color: #ea580c;
	}

	.status-badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		text-transform: capitalize;
	}

	.status-badge.pending {
		background: #fef3c7;
		color: #d97706;
	}

	.status-badge.in_progress {
		background: #dbeafe;
		color: #2563eb;
	}

	.status-badge.completed {
		background: #dcfce7;
		color: #16a34a;
	}

	.status-badge.overdue {
		background: #fecaca;
		color: #dc2626;
	}

	.deadline-info {
		font-size: 12px;
	}

	.deadline-time {
		font-size: 10px;
		color: #6b7280;
	}

	.no-deadline {
		font-size: 12px;
		color: #9ca3af;
		font-style: italic;
	}

	.overdue-time {
		font-size: 12px;
		font-weight: 600;
		text-align: center;
	}

	.overdue-time.critical {
		color: #dc2626;
	}

	.overdue-label {
		font-size: 10px;
		font-weight: 400;
		color: #991b1b;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.not-overdue {
		font-size: 12px;
		color: #9ca3af;
		text-align: center;
	}

	.assignment-row.critical {
		background: #fef2f2;
		border-left: 4px solid #dc2626;
	}

	.assignment-row.warning {
		background: #fffbeb;
		border-left: 4px solid #f59e0b;
	}

	.assignment-row.normal {
		background: white;
	}

	@media (max-width: 768px) {
		.stats-grid {
			grid-template-columns: 1fr;
		}
		
		.section-header {
			flex-direction: column;
			align-items: stretch;
		}
		
		.branch-filter {
			justify-content: center;
		}
		
		.assignments-table {
			font-size: 12px;
		}
		
		.action-buttons {
			flex-direction: column;
		}
	}
</style>