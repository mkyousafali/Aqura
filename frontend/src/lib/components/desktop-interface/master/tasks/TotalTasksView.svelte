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
	let customDateFrom = '';
	let customDateTo = '';
	let selectedTask: any = null;
	let showTaskDetail = false;

	let users: any[] = [];
	let branches: any[] = [];
	
	// 🚀 PAGINATION & OPTIMIZATION
	const PAGE_SIZE = 50;
	let currentPage = 0;
	let totalTaskCount = 0;
	let isLoadingMore = false;
	let hasMorePages = true;
	let allLoadedTasks: any[] = [];
	
	// Track offsets for each table separately
	let taskAssignmentsOffset = 0;
	let quickTaskAssignmentsOffset = 0;
	let receivingTasksOffset = 0;
	
	// Track total counts for each table
	let taskAssignmentsTotal = 0;
	let quickTaskAssignmentsTotal = 0;
	let receivingTasksTotal = 0;

	onMount(async () => {
		await loadFiltersInParallel();
		await loadTasks();
	});

	// 🚀 OPTIMIZATION: Load filters in parallel
	async function loadFiltersInParallel() {
		try {
			console.log('🔄 [TotalTasksView] Loading filters in parallel...');
			
			const [usersResult, branchesResult] = await Promise.allSettled([
				supabase
					.from('users')
					.select('id, username')
					.order('username')
					.limit(1000),
				supabase
					.from('branches')
					.select('id, name_en, name_ar')
					.order('name_en')
					.limit(500)
			]);

			if (usersResult.status === 'fulfilled' && usersResult.value.data) {
				users = usersResult.value.data;
				console.log('✅ [TotalTasksView] Loaded users:', users.length);
			}

			if (branchesResult.status === 'fulfilled' && branchesResult.value.data) {
				branches = branchesResult.value.data;
				console.log('✅ [TotalTasksView] Loaded branches:', branches.length);
			}

		} catch (error) {
			console.error('❌ [TotalTasksView] Error loading filters:', error);
		}
	}

	// 🚀 OPTIMIZATION: Pagination-based task loading
	async function loadTasks() {
		try {
			isLoading = true;
			currentPage = 0;
			allLoadedTasks = [];
			tasks = [];
			
			// Reset all offsets
			taskAssignmentsOffset = 0;
			quickTaskAssignmentsOffset = 0;
			receivingTasksOffset = 0;
			taskAssignmentsTotal = 0;
			quickTaskAssignmentsTotal = 0;
			receivingTasksTotal = 0;

			const user = $currentUser;
			if (!user) return;

			// Load first page
			await loadTasksPage(0);
		} catch (error) {
			console.error('❌ [TotalTasksView] Error loading tasks:', error);
		} finally {
			isLoading = false;
		}
	}

	// 🚀 OPTIMIZATION: Load tasks by page
	async function loadTasksPage(page: number) {
		try {
			isLoadingMore = true;
			const startIndex = page * PAGE_SIZE;

			await loadTotalTasksPage(startIndex);

			// Show ALL loaded tasks in one continuous table (not just current page)
			tasks = allLoadedTasks;
			currentPage = page;
			applyFilters();
		} catch (error) {
			console.error('❌ [TotalTasksView] Error loading task page:', error);
		} finally {
			isLoadingMore = false;
		}
	}

	// Load next page
	async function loadNextPage() {
		const user = $currentUser;
		if (user && hasMorePages) {
			await loadTasksPage(currentPage + 1);
		}
	}

	async function loadTotalTasksPage(startIndex: number) {
		console.log('🔍 [TotalTasksView] Loading total tasks page starting at index:', startIndex);
		
		try {
			const pageSize = 100;
			
			// Reset offsets on first load
			if (startIndex === 0) {
				taskAssignmentsOffset = 0;
				quickTaskAssignmentsOffset = 0;
				receivingTasksOffset = 0;
			}
			
		const results = await Promise.allSettled([
			// Load task_assignments
			supabase
				.from('task_assignments')
				.select('*, assigned_by_user:assigned_by(id, username), assigned_to_user:assigned_to_user_id(id, username), task:task_id(id, title, description), branches:assigned_to_branch_id(id, name_en)', { count: 'exact' })
				.order('assigned_at', { ascending: false })
				.range(taskAssignmentsOffset, taskAssignmentsOffset + pageSize - 1),				// Load quick_task_assignments
				supabase
					.from('quick_task_assignments')
					.select('*', { count: 'exact' })
					.order('created_at', { ascending: false })
					.range(quickTaskAssignmentsOffset, quickTaskAssignmentsOffset + pageSize - 1),
				
				// Load receiving_tasks
				supabase
					.from('receiving_tasks')
					.select('*', { count: 'exact' })
					.order('created_at', { ascending: false })
					.range(receivingTasksOffset, receivingTasksOffset + pageSize - 1)
			]);

			// Extract results
			let taskAssignmentsData: any[] = [];
			let quickAssignmentsData: any[] = [];
			let receivingTasksData: any[] = [];
			
			let totalTaskAssignmentCount = 0;
			let totalQuickCount = 0;
			let totalReceivingCount = 0;

			if (results[0].status === 'fulfilled') {
				const res = results[0].value;
				if (res.error) {
					console.error('❌ [TotalTasksView] Error loading task_assignments:', res.error);
				} else {
					taskAssignmentsData = res.data || [];
					totalTaskAssignmentCount = res.count || 0;
					taskAssignmentsTotal = totalTaskAssignmentCount;
					console.log(`📋 [TotalTasksView] Loaded task_assignments: ${taskAssignmentsData.length}/${totalTaskAssignmentCount} (offset: ${taskAssignmentsOffset})`);
					taskAssignmentsOffset += taskAssignmentsData.length;
				}
			}

			if (results[1].status === 'fulfilled') {
				const res = results[1].value;
				if (res.error) {
					console.error('❌ [TotalTasksView] Error loading quick_task_assignments:', res.error);
				} else {
					quickAssignmentsData = res.data || [];
					totalQuickCount = res.count || 0;
					quickTaskAssignmentsTotal = totalQuickCount;
					console.log(`⚡ [TotalTasksView] Loaded quick_task_assignments: ${quickAssignmentsData.length}/${totalQuickCount} (offset: ${quickTaskAssignmentsOffset})`);
					quickTaskAssignmentsOffset += quickAssignmentsData.length;
				}
			}

			if (results[2].status === 'fulfilled') {
				const res = results[2].value;
				if (res.error) {
					console.error('❌ [TotalTasksView] Error loading receiving_tasks:', res.error);
				} else {
					receivingTasksData = res.data || [];
					totalReceivingCount = res.count || 0;
					receivingTasksTotal = totalReceivingCount;
					console.log(`📦 [TotalTasksView] Loaded receiving_tasks: ${receivingTasksData.length}/${totalReceivingCount} (offset: ${receivingTasksOffset})`);
					receivingTasksOffset += receivingTasksData.length;
				}
			}

			// Update total count
			totalTaskCount = totalTaskAssignmentCount + totalQuickCount + totalReceivingCount;
			
			// Check if any table has more data
			const hasMoreTaskAssignments = taskAssignmentsOffset < totalTaskAssignmentCount;
			const hasMoreQuickAssignments = quickTaskAssignmentsOffset < totalQuickCount;
			const hasMoreReceivingTasks = receivingTasksOffset < totalReceivingCount;
			hasMorePages = hasMoreTaskAssignments || hasMoreQuickAssignments || hasMoreReceivingTasks;

		// Process and add tasks
		if (taskAssignmentsData.length > 0) {
			console.log(`📋 [TotalTasksView] Processing ${taskAssignmentsData.length} task assignments`, taskAssignmentsData.slice(0, 2));
			
			// Fetch branches separately if not included in the response
			const branchIds = [...new Set(taskAssignmentsData.map(ta => ta.assigned_to_branch_id).filter(Boolean))];
			console.log(`🔑 [TotalTasksView] Branch IDs to fetch: ${JSON.stringify(branchIds)}`);
			let branchMap = new Map();

			if (branchIds.length > 0) {
				const { data: branchesData } = await supabase
					.from('branches')
					.select('id, name_en')
					.in('id', branchIds);

				console.log(`📍 [TotalTasksView] Branches fetched:`, branchesData);
				if (branchesData) {
					branchesData.forEach(branch => {
						branchMap.set(branch.id, branch.name_en);
					});
				}
			}


		const processedTasks = taskAssignmentsData.map(ta => {
			// Try to get branch name from nested relation first, then from map
			const branchName = ta.branches?.name_en || branchMap.get(ta.assigned_to_branch_id) || 'No Branch';
			console.log(`🔍 Task ${ta.id}: branches=${JSON.stringify(ta.branches)}, branch_id=${ta.assigned_to_branch_id}, final=${branchName}`);
			return {
				...ta,
				task_title: ta.task?.title || `📋 Task Assignment #${ta.id.slice(-8)}`,
				task_description: ta.task?.description || 'Regular task assignment',
				task_type: 'regular',
				branch_name: branchName,
				branch_id: ta.assigned_to_branch_id,
				assigned_date: ta.assigned_at,
				deadline: ta.deadline_datetime || ta.deadline_date,
				assigned_by_name: ta.assigned_by_user?.username || 'System',
				assigned_to_name: ta.assigned_to_user?.username || 'Unassigned',
				assigned_to_user_id: ta.assigned_to_user_id
			};
		});
		allLoadedTasks = [...allLoadedTasks, ...processedTasks];
	}			if (quickAssignmentsData.length > 0) {
			// Fetch quick_tasks and user data
			const quickTaskIds = quickAssignmentsData
				.map(qa => qa.quick_task_id)
				.filter((id, index, self) => id && self.indexOf(id) === index);				const assignedUserIds = quickAssignmentsData
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
						task_title: quickTask.title || `⚡ Quick Task #${qa.id.slice(-8)}`,
						task_description: quickTask.description || 'Quick task assignment',
						task_type: 'quick',
						branch_name: branchMap.get(quickTask.assigned_to_branch_id) || 'No Branch',
						branch_id: quickTask.assigned_to_branch_id,
						assigned_date: qa.created_at,
						deadline: quickTask.deadline_datetime,
						priority: quickTask.priority || 'medium',
						assigned_by_name: userMap.get(`creator:${quickTask.assigned_by}`) || 'System',
						assigned_to_name: userMap.get(`assigned:${qa.assigned_to_user_id}`) || 'Unassigned',
						assigned_to_user_id: qa.assigned_to_user_id
					};
				});
				allLoadedTasks = [...allLoadedTasks, ...processedQuickTasks];
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
					task_title: rt.title || `📦 Receiving Task #${rt.id.slice(-8)}`,
					task_description: rt.description || 'Receiving task',
					task_type: 'receiving',
					branch_name: userMap.get(`branch:${record.branch_id}`) || 'No Branch',
					branch_id: record.branch_id,
					assigned_date: rt.created_at,
					deadline: rt.due_date,
					assigned_by_name: userMap.get(`creator:${record.user_id}`) || 'System',
					assigned_to_name: rt.assigned_user_id ? userMap.get(`assigned:${rt.assigned_user_id}`) || 'Unassigned' : 'Unassigned',
					assigned_to_user_id: rt.assigned_user_id
				};
			});
			allLoadedTasks = [...allLoadedTasks, ...processedReceivingTasks];
		}			console.log(`✅ [TotalTasksView] Page ${Math.floor(startIndex / pageSize)}: Total tasks loaded=${allLoadedTasks.length}, HasMore=${hasMorePages}`);

		} catch (error) {
			console.error('❌ [TotalTasksView] Error loading total tasks page:', error);
		}
	}

	function applyFilters() {
		console.log('🔍 [TotalTasksView] Applying filters to', tasks.length, 'tasks');
		
		filteredTasks = tasks.filter(task => {
			const matchesSearch = 
				!searchQuery || 
				task.task_title?.toLowerCase().includes(searchQuery.toLowerCase()) ||
				task.task_description?.toLowerCase().includes(searchQuery.toLowerCase());

			const matchesBranch = !selectedBranch || task.branch_id === parseInt(selectedBranch);
			const matchesUser = !selectedUser || task.assigned_to_user_id === selectedUser;

			const matchesDate = checkDateFilter(task);

			return matchesSearch && matchesBranch && matchesUser && matchesDate;
		});

		console.log('✅ [TotalTasksView] Filtered tasks result:', filteredTasks.length, 'out of', tasks.length);

		// Sort by assigned date descending
		filteredTasks.sort((a, b) => {
			const dateA = new Date(a.assigned_date || 0).getTime();
			const dateB = new Date(b.assigned_date || 0).getTime();
			return dateB - dateA;
		});
	}

	function checkDateFilter(task: any): boolean {
		if (dateFilter === 'all') return true;
		
		const taskDate = new Date(task.assigned_date || task.created_at);
		const today = new Date();
		today.setHours(0, 0, 0, 0);

		if (dateFilter === 'today') {
			const taskDateOnly = new Date(taskDate);
			taskDateOnly.setHours(0, 0, 0, 0);
			return taskDateOnly.getTime() === today.getTime();
		}

		if (dateFilter === 'week') {
			const weekAgo = new Date(today);
			weekAgo.setDate(weekAgo.getDate() - 7);
			return taskDate >= weekAgo;
		}

		if (dateFilter === 'month') {
			const monthAgo = new Date(today);
			monthAgo.setMonth(monthAgo.getMonth() - 1);
			return taskDate >= monthAgo;
		}

		if (dateFilter === 'custom') {
			if (customDateFrom && customDateTo) {
				const from = new Date(customDateFrom);
				const to = new Date(customDateTo);
				to.setHours(23, 59, 59, 999);
				return taskDate >= from && taskDate <= to;
			}
		}

		return true;
	}

	function formatDate(date: any): string {
		if (!date) return 'N/A';
		try {
			const d = new Date(date);
			const dateStr = d.toLocaleDateString();
			const timeStr = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
			return `${dateStr} ${timeStr}`;
		} catch {
			return 'Invalid';
		}
	}

	function getDueStatus(deadline: any): { text: string; class: string } {
		if (!deadline) return { text: 'No Deadline', class: 'status-no-deadline' };
		
		const now = new Date();
		const deadlineDate = new Date(deadline);
		const timeDiff = deadlineDate.getTime() - now.getTime();
		const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24));
		const timeStr = deadlineDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

		if (daysDiff < 0) return { text: `Overdue (${timeStr})`, class: 'status-overdue' };
		if (daysDiff === 0) return { text: `Due Today (${timeStr})`, class: 'status-due-today' };
		if (daysDiff === 1) return { text: `Due Tomorrow (${timeStr})`, class: 'status-due-tomorrow' };
		if (daysDiff <= 3) return { text: `Urgent (${timeStr})`, class: 'status-urgent' };
		if (daysDiff <= 7) return { text: `This Week (${timeStr})`, class: 'status-warning' };
		return { text: `Upcoming (${timeStr})`, class: 'status-safe' };
	}

	function viewTaskDetails(task: any) {
		selectedTask = task;
		showTaskDetail = true;
	}
</script>

<div class="task-details-view">
	<div class="filters-section">
		<div class="search-box">
			<svg class="search-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
			</svg>
			<input 
				type="text" 
				class="search-input" 
				placeholder="Search tasks..." 
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

			<select class="filter-select" bind:value={dateFilter} on:change={() => applyFilters()}>
				<option value="all">All Dates</option>
				<option value="today">Today</option>
				<option value="week">Last 7 Days</option>
				<option value="month">Last 30 Days</option>
				<option value="custom">Custom Range</option>
			</select>

			{#if dateFilter === 'custom'}
				<input 
					type="date" 
					class="date-input" 
					bind:value={customDateFrom}
					on:change={() => applyFilters()}
				/>
				<input 
					type="date" 
					class="date-input" 
					bind:value={customDateTo}
					on:change={() => applyFilters()}
				/>
			{/if}
		</div>
	</div>

	<div class="results-info">
		<p>Showing {filteredTasks.length} filtered tasks | Loaded: {allLoadedTasks.length} of {totalTaskCount} total tasks available</p>
	</div>

	<div class="table-container">
		{#if isLoading}
			<div class="loading">Loading tasks...</div>
		{:else if filteredTasks.length === 0}
			<div class="no-data">No tasks found</div>
		{:else}
			<table class="tasks-table">
				<thead>
					<tr>
						<th>Task Title</th>
						<th>Type</th>
						<th>Branch</th>
						<th>Assigned By</th>
						<th>Assigned To</th>
						<th>Assigned Date</th>
						<th>Deadline</th>
						<th>Due Status</th>
						<th>Status</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredTasks as task, index (`${task.task_type}-${task.id}-${index}`)}
						<tr class="clickable-row" on:click={() => viewTaskDetails(task)}>
							<td>
								<div class="task-title-cell">
									<strong>{task.task_title}</strong>
									{#if task.task_description}
										<span class="task-desc">{task.task_description.substring(0, 80)}{task.task_description.length > 80 ? '...' : ''}</span>
									{/if}
								</div>
							</td>
							<td>
								<span class="badge {task.task_type === 'quick' ? 'badge-quick' : task.task_type === 'receiving' ? 'badge-receiving' : 'badge-regular'}">
									{task.task_type === 'quick' ? 'Quick' : task.task_type === 'receiving' ? 'Receiving' : 'Regular'}
								</span>
							</td>
							<td>{task.branch_name}</td>
							<td>{task.assigned_by_name || 'N/A'}</td>
							<td>{task.assigned_to_name || 'N/A'}</td>
							<td>{formatDate(task.assigned_date)}</td>
							<td>{formatDate(task.deadline)}</td>
							<td>
								{#if task.status === 'completed'}
									<span class="due-status-badge status-completed">Completed</span>
								{:else if task.deadline}
									{@const dueStatus = getDueStatus(task.deadline)}
									<span class="due-status-badge {dueStatus.class}">
										{dueStatus.text}
									</span>
								{:else}
									<span class="due-status-badge status-no-deadline">No Deadline</span>
								{/if}
							</td>
							<td>
								<span class="badge badge-{task.status || 'pending'}">
									{(task.status || 'pending').charAt(0).toUpperCase() + (task.status || 'pending').slice(1)}
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
				{isLoadingMore ? 'Loading...' : `Load More Tasks (${allLoadedTasks.length} loaded)`}
			</button>
			<span class="page-info">
				{allLoadedTasks.length} of {totalTaskCount} tasks loaded | Remaining: {totalTaskCount - allLoadedTasks.length}
			</span>
		</div>
	{/if}
</div>

<style>
	.task-details-view {
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
		position: relative;
		margin-bottom: 16px;
	}

	.search-icon {
		position: absolute;
		left: 12px;
		top: 50%;
		transform: translateY(-50%);
		width: 20px;
		height: 20px;
		color: #9ca3af;
	}

	.search-input {
		width: 100%;
		padding: 12px 12px 12px 44px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		transition: all 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.filters-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.filter-select,
	.date-input {
		padding: 10px 12px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		background: white;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.filter-select:focus,
	.date-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.results-info {
		padding: 12px 24px;
		background: #f3f4f6;
		font-size: 14px;
		color: #6b7280;
		font-weight: 500;
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
		font-size: 16px;
	}

	.tasks-table {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
		background: white;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		border-radius: 8px;
	}

	.tasks-table thead {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.tasks-table th {
		padding: 14px 16px;
		text-align: left;
		font-weight: 600;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		position: sticky;
		top: 0;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		z-index: 10;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
	}

	.tasks-table tbody tr {
		border-bottom: 1px solid #e5e7eb;
		transition: background 0.2s ease;
	}

	.tasks-table tbody tr:hover {
		background: #f9fafb;
	}

	.clickable-row {
		cursor: pointer;
	}

	.clickable-row:hover {
		background: #f3f4f6 !important;
	}

	.tasks-table td {
		padding: 14px 16px;
		font-size: 14px;
		color: #374151;
	}

	.task-title-cell {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.task-desc {
		font-size: 12px;
		color: #6b7280;
	}

	.badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		text-transform: capitalize;
	}

	.badge-quick {
		background: #dbeafe;
		color: #1e40af;
	}

	.badge-receiving {
		background: #dcfce7;
		color: #166534;
	}

	.badge-regular {
		background: #f3e8ff;
		color: #6b21a8;
	}

	.badge-assigned,
	.badge-pending {
		background: #fef3c7;
		color: #92400e;
	}

	.badge-completed {
		background: #d1fae5;
		color: #065f46;
	}

	.due-status-badge {
		display: inline-block;
		padding: 6px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		white-space: nowrap;
	}

	.status-overdue {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fca5a5;
		animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}

	.status-due-today {
		background: #fef3c7;
		color: #92400e;
		border: 1px solid #fcd34d;
		font-weight: 700;
	}

	.status-due-tomorrow {
		background: #fed7aa;
		color: #c2410c;
		border: 1px solid #fb923c;
	}

	.status-urgent {
		background: #fecaca;
		color: #b91c1c;
		border: 1px solid #f87171;
	}

	.status-warning {
		background: #fef3c7;
		color: #a16207;
		border: 1px solid #fbbf24;
	}

	.status-safe {
		background: #d1fae5;
		color: #065f46;
		border: 1px solid #6ee7b7;
	}

	.status-completed {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #4ade80;
		font-weight: 600;
	}

	.status-no-deadline {
		background: #e5e7eb;
		color: #4b5563;
		border: 1px solid #d1d5db;
	}

	.pagination-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		padding: 24px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
		text-align: center;
	}

	.load-more-btn {
		padding: 12px 32px;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 15px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		display: inline-flex;
		align-items: center;
		gap: 8px;
		min-width: 200px;
		justify-content: center;
	}

	.load-more-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	.load-more-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.page-info {
		font-size: 13px;
		color: #6b7280;
		font-weight: 500;
	}
</style>
