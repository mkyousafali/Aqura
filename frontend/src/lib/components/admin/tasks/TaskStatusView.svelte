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
			// Query to get overall task statistics
			const { data, error } = await supabase
				.from('task_assignments')
				.select(`
					id,
					status,
					deadline_datetime,
					assigned_at
				`);

			if (error) throw error;

			const now = new Date();
			const total = data.length;
			const completed = data.filter(t => t.status === 'completed').length;
			const overdue = data.filter(t => {
				return t.deadline_datetime && 
					   new Date(t.deadline_datetime) < now && 
					   t.status !== 'completed';
			}).length;

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
			// First, get basic assignment data
			const { data: assignments, error: assignmentError } = await supabase
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
					assigned_at
				`);

			if (assignmentError) throw assignmentError;

			// Get all unique user IDs to fetch user details
			const userIds = [...new Set([
				...assignments.map(a => a.assigned_by).filter(Boolean),
				...assignments.map(a => a.assigned_to_user_id).filter(Boolean)
			])];

			// Get user details for assigned_by and assigned_to users
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

				if (!usersError) {
					usersData = users || [];
				}
			}

			// Get branch details for assignments
			const branchIds = [...new Set(assignments.map(a => a.assigned_to_branch_id).filter(Boolean))];
			let branchesData = [];
			if (branchIds.length > 0) {
				const { data: branches, error: branchesError } = await supabase
					.from('branches')
					.select('id, name_en as name')
					.in('id', branchIds);

				if (!branchesError) {
					branchesData = branches || [];
				}
			}

			// Process and group the data
			const grouped = {};
			const now = new Date();

			// Create lookup maps for users and branches
			const usersMap = {};
			usersData.forEach(user => {
				usersMap[user.id] = user;
			});

			const branchesMap = {};
			branchesData.forEach(branch => {
				branchesMap[branch.id] = branch;
			});

			assignments.forEach(assignment => {
				const assignedByUser = usersMap[assignment.assigned_by];
				const assignedToUser = usersMap[assignment.assigned_to_user_id];
				const assignedToBranch = branchesMap[assignment.assigned_to_branch_id];

				let key, assignedByName, assignedToName;

				// Get assigned by name: prioritize employee name from HR table, then username, then UUID
				assignedByName = assignedByUser?.hr_employees?.name || assignedByUser?.username || assignment.assigned_by;

				if (assignment.assignment_type === 'user' && assignment.assigned_to_user_id) {
					key = `${assignment.assigned_by}-${assignment.assigned_to_user_id}`;
					assignedToName = assignedToUser?.hr_employees?.name || assignedToUser?.username || `User ${assignment.assigned_to_user_id}`;
				} else if (assignment.assignment_type === 'branch' && assignment.assigned_to_branch_id) {
					key = `${assignment.assigned_by}-branch-${assignment.assigned_to_branch_id}`;
					assignedToName = `Branch: ${assignedToBranch?.name || assignment.assigned_to_branch_id}`;
				} else if (assignment.assignment_type === 'all') {
					key = `${assignment.assigned_by}-all`;
					assignedToName = 'All Users';
				} else {
					// Skip invalid assignments
					return;
				}
				
				if (!grouped[key]) {
					grouped[key] = {
						assignedBy: assignedByName,
						assignedTo: assignedToName,
						assignedToEmployee: assignedToUser?.hr_employees?.name || '',
						branch: assignedToBranch?.name || assignedToUser?.branches?.name_en || '',
						totalAssigned: 0,
						totalCompleted: 0,
						totalOverdue: 0,
						totalReassigned: 0,
						assignedToUserId: assignment.assigned_to_user_id,
						assignedByUserId: assignment.assigned_by,
						assignmentType: assignment.assignment_type,
						assignedToBranchId: assignment.assigned_to_branch_id
					};
				}

				const group = grouped[key];
				group.totalAssigned++;

				if (assignment.status === 'completed') {
					group.totalCompleted++;
				}

				if (assignment.deadline_datetime && 
					new Date(assignment.deadline_datetime) < now && 
					assignment.status !== 'completed') {
					group.totalOverdue++;
				}

				if (assignment.reassigned_from) {
					group.totalReassigned++;
				}
			});

			assignmentData = Object.values(grouped);
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
				message: `Reminder: You have pending tasks assigned by ${assignment.assignedBy}.\n\nPlease check your tasks and complete them as soon as possible.`,
				type: 'info',
				priority: 'medium',
				target_type: 'specific_users',
				target_users: [assignment.assignedToUserId]
			};

			await notificationManagement.createNotification(notificationData, assignment.assignedBy);

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
					loadDataFromSupabase();
				}
			},
			width: 600,
			height: 700,
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
								<th>Assigned By</th>
								<th>Assigned To</th>
								<th>Branch</th>
								<th>Assigned</th>
								<th>Completed</th>
								<th>Overdue</th>
								<th>Reassigned</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredAssignmentData as assignment}
								<tr>
									<td class="font-medium">{assignment.assignedBy}</td>
									<td>
										<div class="user-info">
											<span class="username">{assignment.assignedTo}</span>
											{#if assignment.assignedToEmployee}
												<span class="employee-name">{assignment.assignedToEmployee}</span>
											{/if}
										</div>
									</td>
									<td>{assignment.branch}</td>
									<td>
										<span class="count-badge count-total">{assignment.totalAssigned}</span>
									</td>
									<td>
										<span class="count-badge count-completed">{assignment.totalCompleted}</span>
									</td>
									<td>
										<span class="count-badge count-overdue">{assignment.totalOverdue}</span>
									</td>
									<td>
										<span class="count-badge count-reassigned">{assignment.totalReassigned}</span>
									</td>
									<td>
										<div class="action-buttons">
											<button 
												class="action-btn reminder-btn"
												on:click={() => sendReminder(assignment)}
												title="Send Reminder Notification"
											>
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5z"/>
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6l2 2H9V7z"/>
												</svg>
												Reminder
											</button>
											<button 
												class="action-btn warning-btn"
												on:click={() => openWarningModal(assignment)}
												title="Send Warning"
											>
												<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-2.694-.833-3.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z"/>
												</svg>
												Warning
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