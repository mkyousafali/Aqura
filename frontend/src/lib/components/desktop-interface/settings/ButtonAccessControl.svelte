<script lang="ts">
	import { onMount } from 'svelte';

	// Button Access Control Component
	let selectedBranch = '';
	let selectedRole = '';
	let selectedPosition = '';
	let searchUsername = '';
	let branches: any[] = [];
	let roles: any[] = [];
	let positions: any[] = [];
	let users: any[] = [];
	let loading = false;
	let usersLoading = false;
	let currentPage = 0;
	let pageSize = 17;
	let totalUsers = 0;
	let filterTimeout: any = null;
	let searchTimeout: any = null;
	let selectedUserId: string | null = null;
	let currentStep = 1;

	onMount(async () => {
		// Parallel loading of all filter data
		await Promise.all([
			fetchBranches(),
			fetchRoles(),
			fetchPositions()
		]);
		
		// Load first page of users
		await loadUsers();
	});
	
	$: if (selectedBranch !== undefined && selectedRole !== undefined && selectedPosition !== undefined) {
		currentPage = 0; // Reset to first page on filter change
		clearTimeout(filterTimeout);
		filterTimeout = setTimeout(() => {
			loadUsers();
		}, 300); // Debounce filter changes by 300ms
	}

	$: if (searchUsername !== undefined) {
		currentPage = 0; // Reset to first page on search
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => {
			loadUsers();
		}, 300); // Debounce search by 300ms
	}

	async function fetchRoles() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('users')
				.select('role_type', { count: 'exact' })
				.not('role_type', 'is', null);

			if (!error && data) {
				const uniqueRoles = [...new Set(data.map(u => u.role_type))].sort();
				roles = uniqueRoles.map(role => ({ id: role, role_name: role }));
			}
		} catch (err) {
			console.error('Error fetching roles:', err);
		}
	}

	async function fetchPositions() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('hr_positions')
				.select('id, position_title_en')
				.eq('is_active', true)
				.order('position_title_en', { ascending: true });

			if (!error && data) {
				positions = data.map(p => ({ id: p.id, position_name: p.position_title_en }));
			}
		} catch (err) {
			console.error('Error fetching positions:', err);
		}
	}

	async function fetchBranches() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en', { ascending: true });

			if (!error && data) {
				branches = data;
				selectedBranch = '';
			}
		} catch (err) {
			console.error('Error fetching branches:', err);
		}
	}

	async function loadUsers() {
		usersLoading = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			// Build query with optimized columns
			let countQuery = supabase.from('users').select('id', { count: 'exact' });
			let dataQuery = supabase
				.from('users')
				.select(`id, username, role_type, branch_id, position_id, employee_id, branches (name_en)`, 
					{ count: 'exact' })
				.order('username', { ascending: true })
				.range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

			// Apply filters
			if (selectedBranch && selectedBranch !== '') {
				const branchIdInt = parseInt(selectedBranch);
				countQuery = countQuery.eq('branch_id', branchIdInt);
				dataQuery = dataQuery.eq('branch_id', branchIdInt);
			}
			if (selectedRole && selectedRole !== '') {
				countQuery = countQuery.eq('role_type', selectedRole);
				dataQuery = dataQuery.eq('role_type', selectedRole);
			}
			if (selectedPosition && selectedPosition !== '') {
				countQuery = countQuery.eq('position_id', selectedPosition);
				dataQuery = dataQuery.eq('position_id', selectedPosition);
			}
			if (searchUsername && searchUsername !== '') {
				countQuery = countQuery.ilike('username', `%${searchUsername}%`);
				dataQuery = dataQuery.ilike('username', `%${searchUsername}%`);
			}

			// Execute both queries in parallel
			const [countResult, dataResult] = await Promise.all([
				countQuery,
				dataQuery
			]);

			if (countResult.error) {
				console.error('Count error:', countResult.error);
				return;
			}

			if (dataResult.error) {
				console.error('Data error:', dataResult.error);
				return;
			}

			const data = dataResult.data || [];
			totalUsers = countResult.count || 0;

			if (data.length === 0) {
				users = [];
				return;
			}

			// Extract IDs for parallel lookups
			const employeeIds = [...new Set(data.filter(u => u.employee_id).map(u => u.employee_id))];
			const positionIds = [...new Set(data.filter(u => u.position_id).map(u => u.position_id))];

			// Parallel fetch of related data
			const [employeesResult, positionsResult] = await Promise.all([
				employeeIds.length > 0 
					? supabase.from('hr_employees').select('id, name').in('id', employeeIds)
					: Promise.resolve({ data: [] }),
				positionIds.length > 0 
					? supabase.from('hr_positions').select('id, position_title_en').in('id', positionIds)
					: Promise.resolve({ data: [] })
			]);

			// Build lookup maps
			const employeeMap = {};
			const positionMap = {};

			if (employeesResult.data) {
				employeesResult.data.forEach(e => {
					employeeMap[e.id] = e.name;
				});
			}

			if (positionsResult.data) {
				positionsResult.data.forEach(p => {
					positionMap[p.id] = p.position_title_en;
				});
			}

			// Merge all data
			users = data.map(user => ({
				...user,
				employee_name: employeeMap[user.employee_id] || user.username,
				position_title: positionMap[user.position_id] || null
			}));
		} catch (err) {
			console.error('Error fetching users:', err);
		} finally {
			usersLoading = false;
		}
	}

	function nextPage() {
		if ((currentPage + 1) * pageSize < totalUsers) {
			currentPage++;
			loadUsers();
		}
	}

	function prevPage() {
		if (currentPage > 0) {
			currentPage--;
			loadUsers();
		}
	}

	function selectUser(userId: string) {
		selectedUserId = selectedUserId === userId ? null : userId;
	}

	function goToStep2() {
		if (selectedUserId) {
			currentStep = 2;
		}
	}

	function goBackToStep1() {
		currentStep = 1;
	}


</script>

{#if currentStep === 1}
<!-- Search Bar -->
<div class="search-bar-container">
	<div class="search-input-wrapper">
		<svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
			<circle cx="11" cy="11" r="8"></circle>
			<path d="m21 21-4.35-4.35"></path>
		</svg>
		<input 
			type="text" 
			bind:value={searchUsername}
			placeholder="Search by username or employee name..."
			class="search-input"
		/>
		{#if searchUsername}
			<button 
				class="clear-btn"
				on:click={() => searchUsername = ''}
				title="Clear search"
			>
				✕
			</button>
		{/if}
	</div>
</div>

<!-- Filter Cards -->
<div class="cards-container">
	<div class="card">
		<select bind:value={selectedBranch} class="branch-select">
			<option value="">All Branches</option>
			{#each branches as branch (branch.id)}
				<option value={branch.id}>{branch.name_en}</option>
			{/each}
		</select>
	</div>

	<div class="card">
		<select bind:value={selectedRole} class="branch-select">
			<option value="">All Roles</option>
			{#each roles as role (role.id)}
				<option value={role.id}>{role.role_name}</option>
			{/each}
		</select>
	</div>
	<div class="card">
		<select bind:value={selectedPosition} class="branch-select">
			<option value="">All Positions</option>
			{#each positions as position (position.id)}
				<option value={position.id}>{position.position_name}</option>
			{/each}
		</select>
	</div>
</div>

<!-- Loading Progress Bar -->
{#if usersLoading}
	<div class="progress-container">
		<div class="progress-bar"></div>
	</div>
{/if}

<!-- Users Table -->
<div class="table-container">
	<div class="table-header">
		<h3>Users ({users.length})</h3>
		{#if usersLoading}
			<span class="loading-badge">Loading...</span>
		{/if}
	</div>
	
		{#if usersLoading && users.length === 0}
			<!-- Skeleton Loader -->
			<div class="skeleton-container">
				{#each Array(5) as _}
					<div class="skeleton-row">
						<div class="skeleton-cell" style="width: 40px;"></div>
						<div class="skeleton-cell large"></div>
						<div class="skeleton-cell medium"></div>
						<div class="skeleton-cell medium"></div>
						<div class="skeleton-cell small"></div>
						<div class="skeleton-cell medium"></div>
					</div>
				{/each}
			</div>
	{:else}
		<table class="users-table">
			<thead>
				<tr>
					<th style="width: 40px; text-align: center;">
						<input type="checkbox" disabled title="Select user" />
					</th>
					<th>Employee Name</th>
					<th>Username</th>
					<th>Branch</th>
					<th>Role</th>
				<th>Position</th>
			</tr>
		</thead>
		<tbody>
			{#if users.length === 0}
				<tr class="empty-row">
					<td colspan="6" style="text-align: center; padding: 20px;">
						{usersLoading ? 'Loading users...' : 'No users found'}
					</td>
				</tr>
			{:else}
				{#each users as user (user.id)}
					<tr class={selectedUserId === user.id ? 'selected-row' : ''}>
						<td style="text-align: center;">
							<input 
								type="checkbox" 
								checked={selectedUserId === user.id}
								on:change={() => selectUser(user.id)}
								title="Select this user"
							/>
						</td>
						<td class="name-cell">
							{user.employee_name}
						</td>
						<td>{user.username}</td>
						<td>{user.branches?.name_en || '-'}</td>
						<td>
							<span class="badge" style="background: #dbeafe; color: #1e40af;">
								{user.role_type || '-'}
							</span>
						</td>
						<td>{user.position_title || '-'}</td>
					</tr>
				{/each}
			{/if}
		</tbody>
		</table>
	{/if}

	<!-- Pagination Controls -->
	<div class="pagination-controls">
		<button 
			class="pagination-btn"
			disabled={currentPage === 0 || usersLoading}
			on:click={prevPage}
		>
			← Previous
		</button>
		
		<span class="pagination-info">
			Page {currentPage + 1} of {Math.ceil(totalUsers / pageSize)} 
			({users.length} shown, {totalUsers} total)
		</span>
		
		<button 
			class="pagination-btn"
			disabled={(currentPage + 1) * pageSize >= totalUsers || usersLoading}
			on:click={nextPage}
		>
			Next →
		</button>

		<button 
			class="pagination-btn step-btn"
			disabled={!selectedUserId}
			on:click={goToStep2}
		>
			Proceed to Step 2 ✓
		</button>
	</div>
</div>

{:else if currentStep === 2}
<!-- Step 2: Button Control Configuration -->
<div class="step-2-container">
	<div class="step-header">
		<h2>Step 2: Configure Button Access</h2>
		<p>User: <strong>{users.find(u => u.id === selectedUserId)?.employee_name || 'Unknown'}</strong></p>
	</div>

	<div class="step-content">
		<!-- Placeholder for step 2 content -->
	</div>

	<div class="step-actions">
		<button class="back-btn" on:click={goBackToStep1}>
			← Back to Step 1
		</button>
	</div>
</div>
{/if}

<style>
	.search-bar-container {
		padding: 16px;
		background: white;
		border-bottom: 1px solid #e5e7eb;
	}

	.search-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
		width: 100%;
	}

	.search-icon {
		position: absolute;
		left: 12px;
		width: 18px;
		height: 18px;
		color: #9ca3af;
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 10px 16px 10px 40px;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		font-size: 14px;
		color: #1f2937;
		background: white;
		transition: all 0.2s ease;
	}

	.search-input::placeholder {
		color: #9ca3af;
	}

	.search-input:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.clear-btn {
		position: absolute;
		right: 12px;
		background: none;
		border: none;
		color: #9ca3af;
		font-size: 18px;
		cursor: pointer;
		padding: 4px 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		transition: all 0.2s ease;
	}

	.clear-btn:hover {
		color: #374151;
		background: #f3f4f6;
	}

	.progress-container {
		width: 100%;
		height: 3px;
		background: #e5e7eb;
		position: relative;
		overflow: hidden;
	}

	.progress-bar {
		height: 100%;
		background: linear-gradient(90deg, #10b981, #059669);
		width: 100%;
		animation: progress 2s ease-in-out infinite;
		border-radius: 2px;
	}

	@keyframes progress {
		0% {
			width: 0%;
			box-shadow: none;
		}
		50% {
			width: 100%;
			box-shadow: 0 0 10px rgba(16, 185, 129, 0.5);
		}
		100% {
			width: 100%;
			box-shadow: none;
		}
	}

	.skeleton-container {
		padding: 16px;
	}

	.skeleton-row {
		display: grid;
		grid-template-columns: 1.5fr 1fr 1.2fr 1fr 1.2fr;
		gap: 16px;
		margin-bottom: 16px;
		padding: 12px 16px;
		background: white;
		border-bottom: 1px solid #e5e7eb;
	}

	.skeleton-cell {
		background: linear-gradient(90deg, #e5e7eb, #f3f4f6, #e5e7eb);
		background-size: 200% 100%;
		border-radius: 4px;
		animation: shimmer 1.5s infinite;
		height: 12px;
	}

	.skeleton-cell.large {
		height: 16px;
	}

	.skeleton-cell.medium {
		height: 12px;
	}

	.skeleton-cell.small {
		height: 20px;
		width: 60%;
	}

	@keyframes shimmer {
		0% {
			background-position: 200% 0;
		}
		100% {
			background-position: -200% 0;
		}
	}

	.cards-container {
		display: flex;
		gap: 16px;
		padding: 16px;
	}

	.card {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 40px;
		background: #f9fafb;
		border: 2px solid #10b981;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		min-height: 150px;
	}

	.branch-select {
		width: 100%;
		padding: 12px 16px;
		font-size: 14px;
		font-weight: 600;
		border: 2px solid #10b981;
		border-radius: 6px;
		background: white;
		color: #1f2937;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.branch-select:hover {
		border-color: #059669;
		box-shadow: 0 0 8px rgba(16, 185, 129, 0.2);
	}

	.branch-select:focus {
		outline: none;
		border-color: #059669;
		box-shadow: 0 0 12px rgba(16, 185, 129, 0.3);
	}

	.card-value {
		font-size: 32px;
		font-weight: 700;
		color: #10b981;
		min-height: 40px;
	}

	.table-container {
		padding: 16px;
	}

	.table-header {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
		border-bottom: 2px solid #e5e7eb;
		padding-bottom: 12px;
	}

	.table-header h3 {
		margin: 0;
		font-size: 16px;
		font-weight: 600;
		color: #1f2937;
	}

	.loading-badge {
		padding: 4px 8px;
		background: #fef3c7;
		color: #92400e;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.users-table thead {
		background: #f3f4f6;
		border-bottom: 2px solid #10b981;
	}

	.users-table th {
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		font-size: 13px;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.users-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #e5e7eb;
		font-size: 14px;
		color: #4b5563;
	}

	.users-table tbody tr:hover {
		background: #f9fafb;
	}

	.users-table tbody tr.empty-row:hover {
		background: white;
	}

	.name-cell {
		font-weight: 500;
		color: #1f2937;
	}

	.badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
	}

	.pagination-controls {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 16px;
		padding: 16px;
		background: #f3f4f6;
		border-top: 1px solid #e5e7eb;
		margin-top: 0;
	}

	.pagination-btn {
		padding: 8px 16px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.pagination-btn:hover:not(:disabled) {
		background: #059669;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.pagination-btn:disabled {
		background: #d1d5db;
		cursor: not-allowed;
		opacity: 0.6;
	}

	.pagination-info {
		font-size: 13px;
		color: #4b5563;
		font-weight: 500;
		min-width: 200px;
		text-align: center;
	}

	.step-btn {
		background: #0ea5e9;
		margin-left: auto;
	}

	.step-btn:hover:not(:disabled) {
		background: #0284c7;
	}

	.users-table tbody tr {
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.users-table tbody tr:hover {
		background: #f0fdf4;
	}

	.users-table tbody tr.selected-row {
		background: #dcfce7;
		border-left: 4px solid #10b981;
	}

	.users-table input[type="checkbox"] {
		width: 18px;
		height: 18px;
		cursor: pointer;
		accent-color: #10b981;
	}

	.step-2-container {
		padding: 32px 16px;
		animation: slideIn 0.3s ease;
	}

	.step-header {
		background: white;
		padding: 24px;
		border-radius: 8px;
		border-left: 4px solid #10b981;
		margin-bottom: 24px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.step-header h2 {
		margin: 0 0 12px 0;
		font-size: 24px;
		color: #1f2937;
	}

	.step-header p {
		margin: 0;
		font-size: 14px;
		color: #4b5563;
	}

	.step-content {
		background: white;
		padding: 32px;
		border-radius: 8px;
		margin-bottom: 24px;
		min-height: 300px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.step-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-start;
	}

	.back-btn {
		padding: 10px 16px;
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.back-btn:hover {
		background: #4b5563;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}
</style>
