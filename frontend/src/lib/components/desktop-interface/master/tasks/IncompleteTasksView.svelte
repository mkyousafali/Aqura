<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let onClose: () => void;

	let tasks: any[] = [];
	let filteredTasks: any[] = [];
	let isLoading = true;
	let searchQuery = '';
	let selectedUser = '';
	let selectedBranch = '';
	let dateFilter = 'all';

	let users: any[] = [];
	let branches: any[] = [];
	
	const PAGE_SIZE = 50;
	let currentPage = 0;
	let totalTaskCount = 0;
	let isLoadingMore = false;
	let hasMorePages = true;
	let allLoadedTasks: any[] = [];
	
	let taskAssignmentsOffset = 0;
	let quickTaskAssignmentsOffset = 0;
	let receivingTasksOffset = 0;

	// Track unique task keys to prevent duplicates
	let loadedTaskKeys = new Set<string>();

	function addTasksToLoaded(newTasks: any[]) {
		const tasksToAdd = newTasks.filter(task => {
			if (loadedTaskKeys.has(task._unique_key)) {
				console.warn(`⚠️ [IncompleteTasksView] Skipping duplicate task: ${task._unique_key}`);
				return false;
			}
			loadedTaskKeys.add(task._unique_key);
			return true;
		});
		allLoadedTasks = [...allLoadedTasks, ...tasksToAdd];
	}

	onMount(async () => {
		await loadFiltersInParallel();
		await loadTasks();
	});

	async function loadFiltersInParallel() {
		try {
			console.log('🔄 [IncompleteTasksView] Loading filters in parallel...');
			
			const [usersResult, branchesResult] = await Promise.allSettled([
				supabase.from('users').select('id, username').order('username').limit(1000),
				supabase.from('branches').select('id, name_en, name_ar').order('name_en').limit(500)
			]);

			if (usersResult.status === 'fulfilled' && usersResult.value.data) {
				users = usersResult.value.data;
				console.log('✅ [IncompleteTasksView] Loaded users:', users.length);
			}

			if (branchesResult.status === 'fulfilled' && branchesResult.value.data) {
				branches = branchesResult.value.data;
				console.log('✅ [IncompleteTasksView] Loaded branches:', branches.length);
			}

		} catch (error) {
			console.error('❌ [IncompleteTasksView] Error loading filters:', error);
		}
	}

	async function loadTasks() {
		try {
			isLoading = true;
			currentPage = 0;
			allLoadedTasks = [];
			tasks = [];
			loadedTaskKeys.clear();
			taskAssignmentsOffset = 0;
			quickTaskAssignmentsOffset = 0;
			receivingTasksOffset = 0;

			const user = $currentUser;
			if (!user) return;

			await loadTasksPage(0);
		} catch (error) {
			console.error('❌ [IncompleteTasksView] Error loading tasks:', error);
		} finally {
			isLoading = false;
		}
	}

	async function loadTasksPage(page: number) {
		try {
			isLoadingMore = true;
			const startIndex = page * PAGE_SIZE;

			await loadIncompleteTasksPage(startIndex);

			tasks = allLoadedTasks.slice(0, (page + 1) * PAGE_SIZE);
			currentPage = page;
			applyFilters();
		} catch (error) {
			console.error('❌ [IncompleteTasksView] Error loading task page:', error);
		} finally {
			isLoadingMore = false;
		}
	}

	async function loadNextPage() {
		const user = $currentUser;
		if (user && hasMorePages) {
			await loadTasksPage(currentPage + 1);
		}
	}

	async function loadIncompleteTasksPage(startIndex: number) {
		console.log('🔍 [IncompleteTasksView] Loading incomplete tasks page starting at index:', startIndex);
		
		try {
			const pageSize = 100;
			
			if (startIndex === 0) {
				taskAssignmentsOffset = 0;
				quickTaskAssignmentsOffset = 0;
				receivingTasksOffset = 0;
			}
			
		const results = await Promise.allSettled([
		supabase
			.from('task_assignments')
			.select('*, assigned_by_user:assigned_by(id, username), assigned_to_user:assigned_to_user_id(id, username), task:task_id(id, title, description), branches:assigned_to_branch_id(id, name_en)', { count: 'exact' })
			.neq('status', 'completed')
			.neq('status', 'cancelled')
					.order('assigned_at', { ascending: false })
					.range(taskAssignmentsOffset, taskAssignmentsOffset + pageSize - 1),
				
				supabase
					.from('quick_task_assignments')
					.select('*', { count: 'exact' })
					.neq('status', 'completed')
					.neq('status', 'cancelled')
					.order('created_at', { ascending: false })
					.range(quickTaskAssignmentsOffset, quickTaskAssignmentsOffset + pageSize - 1),
				
				supabase
					.from('receiving_tasks')
					.select('*', { count: 'exact' })
					.neq('task_status', 'completed')
					.order('created_at', { ascending: false })
					.range(receivingTasksOffset, receivingTasksOffset + pageSize - 1)
			]);

			let taskAssignmentsData: any[] = [];
			let quickAssignmentsData: any[] = [];
			let receivingTasksData: any[] = [];
			let totalCounts = [0, 0, 0];

			if (results[0].status === 'fulfilled') {
				const res = results[0].value;
				taskAssignmentsData = res.data || [];
				totalCounts[0] = res.count || 0;
				console.log(`📋 [IncompleteTasksView] Loaded incomplete task_assignments: ${taskAssignmentsData.length}/${totalCounts[0]}`);
				taskAssignmentsOffset += taskAssignmentsData.length;
			}

			if (results[1].status === 'fulfilled') {
				const res = results[1].value;
				quickAssignmentsData = res.data || [];
				totalCounts[1] = res.count || 0;
				console.log(`⚡ [IncompleteTasksView] Loaded incomplete quick_task_assignments: ${quickAssignmentsData.length}/${totalCounts[1]}`);
				quickTaskAssignmentsOffset += quickAssignmentsData.length;
			}

			if (results[2].status === 'fulfilled') {
				const res = results[2].value;
				receivingTasksData = res.data || [];
				totalCounts[2] = res.count || 0;
				console.log(`📦 [IncompleteTasksView] Loaded incomplete receiving_tasks: ${receivingTasksData.length}/${totalCounts[2]}`);
				receivingTasksOffset += receivingTasksData.length;
			}

			totalTaskCount = totalCounts[0] + totalCounts[1] + totalCounts[2];
			hasMorePages = (taskAssignmentsOffset < totalCounts[0]) || (quickTaskAssignmentsOffset < totalCounts[1]) || (receivingTasksOffset < totalCounts[2]);

			// Process incomplete tasks
			if (taskAssignmentsData.length > 0) {
				// Fetch branches separately if not included in the response
				const branchIds = [...new Set(taskAssignmentsData.map(ta => ta.assigned_to_branch_id).filter(Boolean))];
				let branchMap = new Map();

				if (branchIds.length > 0) {
					const { data: branchesData } = await supabase
						.from('branches')
						.select('id, name_en')
						.in('id', branchIds);

					if (branchesData) {
						branchesData.forEach(branch => {
							branchMap.set(branch.id, branch.name_en);
						});
					}
				}

			const processedTasks = taskAssignmentsData.map(ta => {
				// Try to get branch name from nested relation first, then from map
				const branchName = ta.branches?.name_en || branchMap.get(ta.assigned_to_branch_id) || 'No Branch';
				console.log(`⏳ Incomplete Task ${ta.id}: branches=${JSON.stringify(ta.branches)}, branch_id=${ta.assigned_to_branch_id}, final=${branchName}`);
				return {
					...ta,
					_unique_key: `task_assignment:${ta.id}`,
					task_title: ta.task?.title || `📋 Task Assignment #${ta.id.slice(-8)}`,
					task_description: ta.task?.description || 'Incomplete task',
					task_type: 'regular',
					branch_name: branchName,
					branch_id: ta.assigned_to_branch_id,
					assigned_date: ta.assigned_at,
					deadline: ta.deadline_datetime || ta.deadline_date,
					assigned_by_name: ta.assigned_by_user?.username || 'System',
					assigned_to_name: ta.assigned_to_user?.username || 'Unassigned'
					};
				});
				addTasksToLoaded(processedTasks);
			}

			if (quickAssignmentsData.length > 0) {
				// Fetch quick_tasks and user data
				const quickTaskIds = quickAssignmentsData
					.map(qa => qa.quick_task_id)
					.filter((id, index, self) => id && self.indexOf(id) === index);

				const assignedUserIds = quickAssignmentsData
					.map(qa => qa.assigned_to_user_id)
					.filter((id, index, self) => id && self.indexOf(id) === index);

				let quickTaskMap = new Map();
				let userMap = new Map();
				let branchMap = new Map();

				// Fetch quick_tasks
				if (quickTaskIds.length > 0) {
					const { data: quickTasksData } = await supabase
						.from('quick_tasks')
						.select('id, title, description, priority, deadline_datetime, assigned_by, assigned_to_branch_id')
						.in('id', quickTaskIds);

					if (quickTasksData) {
						quickTaskMap = new Map(quickTasksData.map(qt => [qt.id, qt]));

						// Fetch branches
						const branchIds = [...new Set(quickTasksData.map(qt => qt.assigned_to_branch_id).filter(Boolean))];
						if (branchIds.length > 0) {
							const { data: branchesData } = await supabase
								.from('branches')
								.select('id, name_en')
								.in('id', branchIds);
							if (branchesData) {
								branchesData.forEach(branch => {
									branchMap.set(branch.id, branch.name_en);
								});
							}
						}

						// Fetch assigned_by users
						const creatorUserIds = [...new Set(quickTasksData.map(qt => qt.assigned_by).filter(Boolean))];
						if (creatorUserIds.length > 0) {
							const { data: creatorUsersData } = await supabase
								.from('users')
								.select('id, username')
								.in('id', creatorUserIds);
							if (creatorUsersData) {
								creatorUsersData.forEach(user => {
									userMap.set(`creator:${user.id}`, user.username);
								});
							}
						}
					}
				}

				// Fetch assigned_to users
				if (assignedUserIds.length > 0) {
					const { data: assignedUsersData } = await supabase
						.from('users')
						.select('id, username')
						.in('id', assignedUserIds);
					if (assignedUsersData) {
						assignedUsersData.forEach(user => {
							userMap.set(`assigned:${user.id}`, user.username);
						});
					}
				}

				const processedQuickTasks = quickAssignmentsData.map(qa => {
					const quickTask = quickTaskMap.get(qa.quick_task_id) || {};
					return {
						...qa,
						_unique_key: `quick_task_assignment:${qa.id}`,
						task_title: quickTask.title || `⚡ Quick Task #${qa.id.slice(-8)}`,
						task_description: quickTask.description || 'Incomplete quick task',
						task_type: 'quick',
						branch_name: branchMap.get(quickTask.assigned_to_branch_id) || 'No Branch',
						branch_id: quickTask.assigned_to_branch_id,
						assigned_date: qa.created_at,
						deadline: quickTask.deadline_datetime,
						priority: quickTask.priority || 'medium',
						assigned_by_name: userMap.get(`creator:${quickTask.assigned_by}`) || 'System',
						assigned_to_name: userMap.get(`assigned:${qa.assigned_to_user_id}`) || 'Unassigned'
					};
				});
				addTasksToLoaded(processedQuickTasks);
			}

			if (receivingTasksData.length > 0) {
				// Fetch receiving records and user information
				const receivingRecordIds = receivingTasksData
					.map(rt => rt.receiving_record_id)
					.filter((id, index, self) => id && self.indexOf(id) === index);

				const assignedUserIds = receivingTasksData
					.map(rt => rt.assigned_user_id)
					.filter((id, index, self) => id && self.indexOf(id) === index);

				let recordMap = new Map();
				let userMap = new Map();

				// Fetch receiving records with their branches and creator users
				if (receivingRecordIds.length > 0) {
					const { data: recordsData } = await supabase
						.from('receiving_records')
						.select('id, user_id, branch_id')
						.in('id', receivingRecordIds);

					if (recordsData) {
						recordMap = new Map(recordsData.map(r => [r.id, { user_id: r.user_id, branch_id: r.branch_id }]));

						// Fetch branches
						const branchIds = [...new Set(recordsData.map(r => r.branch_id).filter(Boolean))];
						if (branchIds.length > 0) {
							const { data: branchesData } = await supabase
								.from('branches')
								.select('id, name_en')
								.in('id', branchIds);
							if (branchesData) {
								branchesData.forEach(branch => {
									userMap.set(`branch:${branch.id}`, branch.name_en);
								});
							}
						}

						// Fetch creator users
						const creatorUserIds = [...new Set(recordsData.map(r => r.user_id).filter(Boolean))];
						if (creatorUserIds.length > 0) {
							const { data: creatorUsersData } = await supabase
								.from('users')
								.select('id, username')
								.in('id', creatorUserIds);
							if (creatorUsersData) {
								creatorUsersData.forEach(user => {
									userMap.set(`creator:${user.id}`, user.username);
								});
							}
						}
					}
				}

				// Fetch assigned users
				if (assignedUserIds.length > 0) {
					const { data: usersData } = await supabase
						.from('users')
						.select('id, username')
						.in('id', assignedUserIds);
					if (usersData) {
						usersData.forEach(user => {
							userMap.set(`assigned:${user.id}`, user.username);
						});
					}
				}

				const processedReceivingTasks = receivingTasksData.map(rt => {
					const record = recordMap.get(rt.receiving_record_id) || {};
					return {
						...rt,
						_unique_key: `receiving_task:${rt.id}`,
						task_title: rt.title || `📦 Receiving Task #${rt.id.slice(-8)}`,
						task_description: rt.description || 'Incomplete receiving task',
						task_type: 'receiving',
						branch_name: userMap.get(`branch:${record.branch_id}`) || 'No Branch',
						branch_id: record.branch_id,
						assigned_date: rt.created_at,
						deadline: rt.due_date,
						assigned_by_name: userMap.get(`creator:${record.user_id}`) || 'System',
						assigned_to_name: rt.assigned_user_id ? userMap.get(`assigned:${rt.assigned_user_id}`) || 'Unassigned' : 'Unassigned'
					};
				});
				addTasksToLoaded(processedReceivingTasks);
			}

			console.log(`✅ [IncompleteTasksView] Total incomplete tasks loaded=${allLoadedTasks.length}`);

		} catch (error) {
			console.error('❌ [IncompleteTasksView] Error loading incomplete tasks page:', error);
		}
	}

	function applyFilters() {
		filteredTasks = tasks.filter(task => {
			const matchesSearch = 
				!searchQuery || 
				task.task_title?.toLowerCase().includes(searchQuery.toLowerCase()) ||
				task.task_description?.toLowerCase().includes(searchQuery.toLowerCase());

			const matchesBranch = !selectedBranch || task.branch_id === parseInt(selectedBranch);
			const matchesUser = !selectedUser || task.assigned_to_user_id === selectedUser;

			return matchesSearch && matchesBranch && matchesUser;
		});

		filteredTasks.sort((a, b) => {
			const dateA = new Date(a.assigned_date || 0).getTime();
			const dateB = new Date(b.assigned_date || 0).getTime();
			return dateB - dateA;
		});
	}

	function formatDate(date: any): string {
		if (!date) return 'N/A';
		try {
			const d = new Date(date);
			const day = String(d.getDate()).padStart(2, '0');
			const month = String(d.getMonth() + 1).padStart(2, '0');
			const year = d.getFullYear();
			let hours = d.getHours();
			const minutes = String(d.getMinutes()).padStart(2, '0');
			const ampm = hours >= 12 ? 'PM' : 'AM';
			hours = hours % 12;
			hours = hours ? hours : 12;
			const hoursStr = String(hours).padStart(2, '0');
			return `${day}/${month}/${year} ${hoursStr}:${minutes} ${ampm}`;
		} catch {
			return 'Invalid';
		}
	}

	function getDueStatus(deadline: any): { text: string; class: string } {
		if (!deadline) return { text: 'No Deadline', class: 'status-safe' };
		
		const now = new Date();
		const deadlineDate = new Date(deadline);
		const timeDiff = deadlineDate.getTime() - now.getTime();
		const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24));
		const timeStr = deadlineDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

		if (daysDiff < 0) return { text: `Overdue (${timeStr})`, class: 'status-overdue' };
		if (daysDiff === 0) return { text: `Due Today (${timeStr})`, class: 'status-due-today' };
		if (daysDiff <= 3) return { text: `Urgent (${timeStr})`, class: 'status-urgent' };
		return { text: `Due Soon (${timeStr})`, class: 'status-warning' };
	}
</script>

<div class="task-view">
	<div class="filters-section">
		<div class="search-box">
			<input 
				type="text" 
				class="search-input" 
				placeholder="Search incomplete tasks..." 
				bind:value={searchQuery}
				on:input={() => applyFilters()}
			/>
		</div>

		<div class="filters-grid">
			<select class="filter-select" bind:value={selectedBranch} on:change={() => applyFilters()}>
				<option value="">All Branches</option>
				{#each branches as branch}
					<option value={branch.id}>{branch.name_en}</option>
				{/each}
			</select>

			<select class="filter-select" bind:value={selectedUser} on:change={() => applyFilters()}>
				<option value="">All Users</option>
				{#each users as user}
					<option value={user.id}>{user.username}</option>
				{/each}
			</select>
		</div>
	</div>

	<div class="results-info">
		<p>Showing {filteredTasks.length} of {tasks.length} incomplete tasks</p>
	</div>

	<div class="table-container">
		{#if isLoading}
			<div class="loading">Loading incomplete tasks...</div>
		{:else if filteredTasks.length === 0}
			<div class="no-data">No incomplete tasks found</div>
		{:else}
			<table class="tasks-table">
				<thead>
					<tr>
						<th>Task Title</th>
						<th>Type</th>
						<th>Branch</th>
						<th>Assigned To</th>
						<th>Assigned Date</th>
						<th>Deadline</th>
						<th>Status</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredTasks as task, index (task._unique_key || `${task.id}:${task.task_type}`)}
						<tr class="clickable-row">
							<td>
								<strong>{task.task_title}</strong>
								{#if task.task_description}
									<span class="task-desc">{task.task_description.substring(0, 60)}...</span>
								{/if}
							</td>
							<td>
								<span class="badge {task.task_type === 'quick' ? 'badge-quick' : 'badge-regular'}">
									{task.task_type === 'quick' ? 'Quick' : task.task_type === 'receiving' ? 'Receiving' : 'Regular'}
								</span>
							</td>
						<td>{task.branch_name}</td>
						<td>{task.assigned_to_name || 'N/A'}</td>
						<td>{formatDate(task.assigned_date)}</td>
						<td>
								{#if task.deadline}
									{@const dueStatus = getDueStatus(task.deadline)}
									<span class="badge {dueStatus.class}">
										{dueStatus.text}
									</span>
								{:else}
									<span class="badge badge-safe">No Deadline</span>
								{/if}
							</td>
							<td>
								<span class="badge badge-pending">
									{task.status || 'Pending'}
								</span>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>

	{#if !isLoading && hasMorePages && filteredTasks.length > 0}
		<div class="pagination-container">
			<button 
				class="load-more-btn"
				on:click={loadNextPage}
				disabled={isLoadingMore}
			>
				{isLoadingMore ? 'Loading...' : 'Load More Tasks'}
			</button>
		</div>
	{/if}
</div>

<style>
	.task-view {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		height: 100%;
	}

	.filters-section {
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.search-box {
		margin-bottom: 16px;
	}

	.search-input {
		width: 100%;
		padding: 12px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
	}

	.search-input:focus {
		outline: none;
		border-color: #f59e0b;
		box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.1);
	}

	.filters-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.filter-select {
		padding: 10px 12px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		background: white;
		cursor: pointer;
	}

	.results-info {
		padding: 12px 24px;
		background: #f3f4f6;
		font-size: 14px;
		color: #6b7280;
	}

	.table-container {
		flex: 1;
		overflow-y: auto;
		padding: 0 24px 24px 24px;
	}

	.loading,
	.no-data {
		text-align: center;
		padding: 60px 20px;
		color: #9ca3af;
	}

	.tasks-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		border-radius: 8px;
	}

	.tasks-table thead {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		color: white;
	}

	.tasks-table th {
		padding: 14px 16px;
		text-align: left;
		font-weight: 600;
		font-size: 13px;
	}

	.tasks-table td {
		padding: 14px 16px;
		font-size: 14px;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
	}

	.tasks-table tbody tr:hover {
		background: #f9fafb;
	}

	.clickable-row {
		cursor: pointer;
	}

	.task-desc {
		font-size: 12px;
		color: #6b7280;
		display: block;
	}

	.badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.badge-quick {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-regular {
		background: #f3e8ff;
		color: #6b21a8;
	}

	.badge-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.badge-safe {
		background: #d1fae5;
		color: #065f46;
	}

	.status-overdue {
		background: #fee2e2;
		color: #991b1b;
	}

	.status-due-today {
		background: #fef3c7;
		color: #92400e;
	}

	.status-urgent {
		background: #fecaca;
		color: #b91c1c;
	}

	.status-warning {
		background: #fed7aa;
		color: #c2410c;
	}

	.pagination-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		padding: 24px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
	}

	.load-more-btn {
		padding: 12px 32px;
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 15px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.load-more-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(245, 158, 11, 0.4);
	}

	.load-more-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
