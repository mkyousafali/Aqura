<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
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
			// Query to get overall task statistics (regular tasks)
			const { data: regularTasks, error: regularError } = await supabase
				.from('task_assignments')
				.select(`
					id,
					status,
					deadline_datetime,
					assigned_at
				`);

			if (regularError) throw regularError;

			// Query to get quick task statistics
			const { data: quickTaskAssignments, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select(`
					id,
					status,
					completed_at,
					created_at,
					quick_tasks(deadline_datetime)
				`);

			if (quickError) throw quickError;

			const now = new Date();
			
			// Process regular tasks
			const regularTotal = regularTasks.length;
			const regularCompleted = regularTasks.filter(t => t.status === 'completed').length;
			const regularOverdue = regularTasks.filter(t => {
				return t.deadline_datetime && 
					   new Date(t.deadline_datetime) < now && 
					   t.status !== 'completed';
			}).length;

			// Process quick tasks
			const quickTotal = quickTaskAssignments.length;
			const quickCompleted = quickTaskAssignments.filter(t => t.status === 'completed').length;
			const quickOverdue = quickTaskAssignments.filter(t => {
				return t.quick_tasks?.deadline_datetime && 
					   new Date(t.quick_tasks.deadline_datetime) < now && 
					   t.status !== 'completed';
			}).length;

			// Combine statistics
			const total = regularTotal + quickTotal;
			const completed = regularCompleted + quickCompleted;
			const overdue = regularOverdue + quickOverdue;

			taskStats = {
				totalAssigned: total,
				totalCompleted: completed,
				totalOverdue: overdue,
				completionPercentage: total > 0 ? Math.round((completed / total) * 100) : 0,
				overduePercentage: total > 0 ? Math.round((overdue / total) * 100) : 0
			};
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
			// Load regular task assignments
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
				`);

			if (regularError) throw regularError;

			// Load quick task assignments
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
				`);

			if (quickError) throw quickError;

			// Get all unique user IDs from both regular and quick tasks
			const userIds = [...new Set([
				...regularAssignments.map(a => a.assigned_by).filter(id => id && typeof id === 'string' && id.length === 36),
				...regularAssignments.map(a => a.assigned_to_user_id).filter(id => id && typeof id === 'string' && id.length === 36),
				...quickAssignments.map(a => a.assigned_to_user_id).filter(id => id && typeof id === 'string' && id.length === 36),
				...quickAssignments.map(a => a.quick_tasks?.assigned_by).filter(id => id && typeof id === 'string' && id.length === 36)
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

			// Transform regular assignments
			const processedRegularAssignments = regularAssignments.map(assignment => {
				const assignedByUser = usersData.find(u => u.id === assignment.assigned_by);
				const assignedToUser = usersData.find(u => u.id === assignment.assigned_to_user_id);
				
				const now = new Date();
				const deadline = assignment.deadline_datetime ? new Date(assignment.deadline_datetime) : null;
				const isOverdue = deadline && deadline < now && assignment.status !== 'completed';
				const isNearDeadline = deadline && !isOverdue && 
					((deadline.getTime() - now.getTime()) / (1000 * 60 * 60)) <= 24; // 24 hours

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
					assigned_to_branch: assignedToUser?.branches?.name_en || 'Unknown',
					status: assignment.status,
					deadline: assignment.deadline_datetime,
					assigned_at: assignment.assigned_at,
					is_overdue: isOverdue,
					is_near_deadline: isNearDeadline,
					warning_level: isOverdue ? 'critical' : isNearDeadline ? 'warning' : 'normal'
				};
			});

			// Transform quick task assignments
			const processedQuickAssignments = quickAssignments.map(assignment => {
				const assignedByUser = usersData.find(u => u.id === assignment.quick_tasks?.assigned_by);
				const assignedToUser = usersData.find(u => u.id === assignment.assigned_to_user_id);
				
				const now = new Date();
				const deadline = assignment.quick_tasks?.deadline_datetime ? new Date(assignment.quick_tasks.deadline_datetime) : null;
				const isOverdue = deadline && deadline < now && assignment.status !== 'completed';
				const isNearDeadline = deadline && !isOverdue && 
					((deadline.getTime() - now.getTime()) / (1000 * 60 * 60)) <= 24; // 24 hours

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
					assigned_to_branch: assignedToUser?.branches?.name_en || 'Unknown',
					status: assignment.status,
					deadline: assignment.quick_tasks?.deadline_datetime,
					assigned_at: assignment.created_at,
					accepted_at: assignment.accepted_at,
					started_at: assignment.started_at,
					completed_at: assignment.completed_at,
					is_overdue: isOverdue,
					is_near_deadline: isNearDeadline,
					warning_level: isOverdue ? 'critical' : isNearDeadline ? 'warning' : 'normal'
				};
			});

			// Combine and sort assignments
			assignmentData = [...processedRegularAssignments, ...processedQuickAssignments]
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
		windowManager.openWindow({
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
				<h2 class="section-title">Task Assignments</h2>
				
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
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredAssignmentData as assignment}
								<tr class="assignment-row {assignment.warning_level}">
									<td>
										<span class="task-type-badge {assignment.type}">
											{assignment.type === 'regular' ? 'Regular' : 'Quick'}
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
												{new Date(assignment.deadline).toLocaleDateString()}
												<div class="deadline-time">
													{new Date(assignment.deadline).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
												</div>
											</div>
										{:else}
											<span class="no-deadline">No deadline</span>
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
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 32px;
		padding-bottom: 20px;
		border-bottom: 1px solid #e5e7eb;
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
		margin-bottom: 32px;
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
		margin-bottom: 32px;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
		flex-wrap: wrap;
		gap: 16px;
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
	}

	.assignments-table {
		width: 100%;
		border-collapse: collapse;
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