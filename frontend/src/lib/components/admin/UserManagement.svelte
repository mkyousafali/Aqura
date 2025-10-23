<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { userManagement } from '$lib/utils/userManagement';
	import CreateUser from './user/CreateUser.svelte';
	import EditUser from './user/EditUser.svelte';
	import AssignRoles from './user/AssignRoles.svelte';
	import CreateUserRoles from './user/CreateUserRoles.svelte';
	import ManageAdminUsers from './user/ManageAdminUsers.svelte';
	import ManageMasterAdmin from './user/ManageMasterAdmin.svelte';

	// Real user data from database
	let users = [];
	let branches = [];
	let roles = [];
	let loading = true;
	let error = null;

	let searchQuery = '';
	let branchFilter = '';
	let roleFilter = '';
	let statusFilter = '';

	// Load data from database on mount
	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		try {
			loading = true;
			error = null;

			// Load all necessary data concurrently
			const [usersResult, branchesResult, rolesResult] = await Promise.all([
				userManagement.getAllUsers(),
				userManagement.getBranches(),
				userManagement.getUserRoles()
			]);

			users = usersResult;
			branches = branchesResult;
			roles = rolesResult;

			console.log('Loaded users:', users);
			console.log('Loaded branches:', branches);
			console.log('Loaded roles:', roles);
		} catch (err) {
			console.error('Error loading user management data:', err);
			error = err.message;
		} finally {
			loading = false;
		}
	}

	// Get current user from persistent auth store with null safety
	$: currentUserData = $currentUser || { roleType: 'Position-based' };
	$: userRoleType = currentUserData?.roleType || 'Position-based';
	const dashboardButtons = [
		{
			id: 'create-user',
			title: 'Create User',
			icon: '👤',
			description: 'Add new user accounts',
			color: 'bg-blue-500'
		},
		{
			id: 'assign-roles',
			title: 'Assign Roles',
			icon: '🎯',
			description: 'Manage user permissions and roles',
			color: 'bg-green-500'
		},
		{
			id: 'create-user-roles',
			title: 'Create User Roles',
			icon: '🔘',
			description: 'Create custom roles and permissions',
			color: 'bg-indigo-500'
		},
		{
			id: 'manage-admin-users',
			title: 'Manage Admin Users',
			icon: '👥',
			description: 'Administer admin user accounts',
			color: 'bg-orange-500'
		},
		{
			id: 'manage-master-admin',
			title: 'Manage Master Admin',
			icon: '🔐',
			description: 'Master admin management (Master Admin only)',
			color: 'bg-red-500'
		}
	];

	// Generate unique window ID
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	function openUserWindow(buttonId) {
		const button = dashboardButtons.find(b => b.id === buttonId);
		
		const windowId = generateWindowId(buttonId);
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		let component;
		
		switch(buttonId) {
			case 'create-user':
				component = CreateUser;
				break;
			case 'assign-roles':
				component = AssignRoles;
				break;
			case 'manage-admin-users':
				component = ManageAdminUsers;
				break;
			case 'manage-master-admin':
				if (userRoleType !== 'Master Admin') {
					alert('Access denied: Master Admin privileges required');
					return;
				}
				component = ManageMasterAdmin;
				break;
			case 'create-user-roles':
				if (userRoleType !== 'Master Admin' && userRoleType !== 'Admin') {
					alert('Access denied: Admin or Master Admin privileges required');
					return;
				}
				component = CreateUserRoles;
				break;
			default:
				return;
		}

		openWindow({
			id: windowId,
			title: `${button.title} #${instanceNumber}`,
			component: component,
			icon: button.icon,
			size: { width: 1000, height: 700 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: { 
				onDataChanged: loadData // Pass reload function to child components
			}
		});
	}

	async function editUser(user) {
		const windowId = generateWindowId('edit-user');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;

		openWindow({
			id: windowId,
			title: `Edit User: ${user.username} #${instanceNumber}`,
			component: EditUser,
			icon: '✏️',
			size: { width: 900, height: 600 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true,
			props: { 
				user, 
				onDataChanged: loadData // Reload data when user is updated
			}
		});
	}

	async function toggleUserStatus(user) {
		try {
			const newStatus = user.status === 'active' ? 'inactive' : 'active';
			
			await userManagement.updateUser(user.id, {
				status: newStatus
			});
			
			// Reload data to reflect changes
			await loadData();
			
			console.log(`User ${user.username} status changed to ${newStatus}`);
		} catch (err) {
			console.error('Error updating user status:', err);
			alert('Failed to update user status: ' + err.message);
		}
	}

	async function toggleUserLock(user) {
		try {
			const newStatus = user.status === 'locked' ? 'active' : 'locked';
			
			await userManagement.updateUser(user.id, {
				status: newStatus
			});
			
			// Reload data to reflect changes
			await loadData();
			
			console.log(`User ${user.username} lock status changed to ${newStatus}`);
		} catch (err) {
			console.error('Error updating user lock status:', err);
			alert('Failed to update user lock status: ' + err.message);
		}
	}

	// Get unique values for filters
	$: uniqueBranches = [...new Set(users.map(user => user.branch_name).filter(Boolean))];
	$: uniqueRoles = [...new Set(users.map(user => user.role_type).filter(Boolean))];
	$: uniqueStatuses = ['active', 'inactive', 'locked'];

	// Filtered users based on search and filters
	$: filteredUsers = users.filter(user => {
		const matchesSearch = searchQuery === '' || 
			(user.username && user.username.toLowerCase().includes(searchQuery.toLowerCase())) ||
			(user.employee_name && user.employee_name.toLowerCase().includes(searchQuery.toLowerCase())) ||
			(user.branch_name && user.branch_name.toLowerCase().includes(searchQuery.toLowerCase()));
		
		const matchesBranch = branchFilter === '' || user.branch_name === branchFilter;
		const matchesRole = roleFilter === '' || user.role_type === roleFilter;
		const matchesStatus = statusFilter === '' || user.status === statusFilter;

		return matchesSearch && matchesBranch && matchesRole && matchesStatus;
	});
</script>

<div class="user-management">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">User Management Dashboard</h1>
			<p class="subtitle">Comprehensive User Account Administration</p>
		</div>
	</div>

	<!-- Loading State -->
	{#if loading}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>Loading user management data...</p>
		</div>
	{:else if error}
		<div class="error-container">
			<div class="error-message">
				<h3>Error Loading Data</h3>
				<p>{error}</p>
				<button class="retry-btn" on:click={loadData}>
					🔄 Retry
				</button>
			</div>
		</div>
	{:else}
		<!-- Dashboard Grid -->
		<div class="dashboard-grid">
			{#each dashboardButtons as button}
				<!-- Hide Manage Master Admin for non-master admins -->
				{#if button.id !== 'manage-master-admin' || userRoleType === 'Master Admin'}
					<button 
						class="dashboard-card" 
						tabindex="0"
						on:click={() => openUserWindow(button.id)}
						on:keydown={(e) => e.key === 'Enter' && openUserWindow(button.id)}
					>
						<div class="card-icon {button.color}">
							<span class="icon">{button.icon}</span>
						</div>
						<div class="card-content">
							<h3 class="card-title">{button.title}</h3>
							<p class="card-description">{button.description}</p>
						</div>
						<div class="card-arrow">
							<span>→</span>
						</div>
					</button>
				{/if}
			{/each}
		</div>

		<!-- Available Users Section -->
		<div class="users-section">
			<div class="section-header">
				<h2 class="section-title">Available Users ({users.length})</h2>
				<div class="section-controls">
					<div class="search-box">
						<span class="search-icon">🔍</span>
						<input
							type="text"
							placeholder="Search by Username, Employee, Branch..."
							bind:value={searchQuery}
							class="search-input"
						>
					</div>
					<div class="filters">
						<select bind:value={branchFilter} class="filter-select">
							<option value="">All Branches</option>
							{#each uniqueBranches as branch}
								<option value={branch}>{branch}</option>
							{/each}
						</select>
						<select bind:value={roleFilter} class="filter-select">
							<option value="">All Roles</option>
							{#each uniqueRoles as role}
								<option value={role}>{role}</option>
							{/each}
						</select>
						<select bind:value={statusFilter} class="filter-select">
							<option value="">All Status</option>
							{#each uniqueStatuses as status}
								<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
							{/each}
						</select>
					</div>
				</div>
			</div>

			<!-- Users Table -->
			<div class="users-table-container">
				{#if filteredUsers.length === 0}
					<div class="empty-state">
						<div class="empty-icon">👤</div>
						<h3>No Users Found</h3>
						<p>No users match your current search and filter criteria.</p>
						{#if searchQuery || branchFilter || roleFilter || statusFilter}
							<button class="clear-filters-btn" on:click={() => {
								searchQuery = '';
								branchFilter = '';
								roleFilter = '';
								statusFilter = '';
							}}>
								Clear Filters
							</button>
						{/if}
					</div>
				{:else}
					<table class="users-table">
						<thead>
							<tr>
								<th>Avatar</th>
								<th>Username</th>
								<th>Employee</th>
								<th>Branch</th>
								<th>Role Type</th>
								<th>Status</th>
								<th>Last Login</th>
								<th>Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredUsers as user (user.id)}
								<tr>
									<td class="avatar-cell">
										{#if user.avatar}
											<img src={user.avatar} alt="Avatar" class="user-avatar">
										{:else}
											<div class="avatar-placeholder">
												<span class="avatar-initials">
													{user.username.charAt(0).toUpperCase()}
												</span>
											</div>
										{/if}
									</td>
									<td class="username-cell">
										<span class="username">{user.username}</span>
									</td>
									<td class="employee-cell">
										{user.employee_name || 'Not Assigned'}
									</td>
									<td class="branch-cell">
										{user.branch_name || 'Not Assigned'}
									</td>
									<td class="role-cell">
										<span class="role-badge role-{user.role_type.toLowerCase().replace(/\s+/g, '-')}">
											{user.role_type}
										</span>
									</td>
									<td class="status-cell">
										<span class="status-badge status-{user.status}">
											{user.status}
										</span>
									</td>
									<td class="login-cell">
										{#if user.last_login}
											{new Date(user.last_login).toLocaleDateString('en-US', {
												year: 'numeric',
												month: 'short',
												day: 'numeric'
											})}
										{:else}
											<span class="never-logged-in">Never</span>
										{/if}
									</td>
									<td class="actions-cell">
										<div class="action-buttons">
											<button 
												class="action-btn edit-btn" 
												on:click={() => editUser(user)}
												title="Edit User"
											>
												✏️
											</button>
											<button 
												class="action-btn status-btn"
												class:activate={user.status === 'inactive'}
												class:deactivate={user.status === 'active'}
												on:click={() => toggleUserStatus(user)}
												title={user.status === 'active' ? 'Deactivate' : 'Activate'}
												disabled={user.role_type === 'Master Admin'}
											>
												{user.status === 'active' ? '🔴' : '🟢'}
											</button>
											<button 
												class="action-btn lock-btn"
												class:unlock={user.status === 'locked'}
												class:lock={user.status !== 'locked'}
												on:click={() => toggleUserLock(user)}
												title={user.status === 'locked' ? 'Unlock' : 'Lock'}
												disabled={user.role_type === 'Master Admin'}
											>
												{user.status === 'locked' ? '🔓' : '🔒'}
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
	.user-management {
		padding: 24px;
		height: 100%;
		background: #f8fafc;
		overflow-y: auto;
	}

	/* Loading and Error States */
	.loading-container, .error-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		text-align: center;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-left-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.loading-container p {
		color: #6b7280;
		font-size: 16px;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 8px;
		padding: 24px;
		max-width: 400px;
	}

	.error-message h3 {
		color: #dc2626;
		margin: 0 0 8px 0;
	}

	.error-message p {
		color: #7f1d1d;
		margin: 0 0 16px 0;
	}

	.retry-btn {
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.retry-btn:hover {
		background: #b91c1c;
	}

	.empty-state {
		text-align: center;
		padding: 60px 20px;
		color: #6b7280;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
		opacity: 0.5;
	}

	.empty-state h3 {
		font-size: 20px;
		margin: 0 0 8px 0;
		color: #374151;
	}

	.empty-state p {
		margin: 0 0 16px 0;
	}

	.clear-filters-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.clear-filters-btn:hover {
		background: #2563eb;
	}

	.header {
		margin-bottom: 32px;
	}

	.title-section {
		text-align: center;
	}

	.title {
		font-size: 32px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 18px;
		color: #6b7280;
		margin: 0;
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 24px;
		max-width: 1200px;
		margin: 0 auto 40px auto;
	}

	.dashboard-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
		cursor: pointer;
		transition: all 0.3s ease;
		position: relative;
		overflow: hidden;
		display: flex;
		align-items: center;
		gap: 16px;
		text-align: left;
		font-family: inherit;
		font-size: inherit;
		width: 100%;
	}

	.dashboard-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
		border-color: #d1d5db;
	}

	.dashboard-card::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: var(--card-color, #3b82f6);
		transition: all 0.3s ease;
	}

	.dashboard-card:hover::before {
		height: 6px;
	}

	.card-icon {
		font-size: 24px;
		width: 48px;
		height: 48px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(59, 130, 246, 0.1);
		border-radius: 8px;
		flex-shrink: 0;
	}

	.card-content {
		flex: 1;
	}

	.card-title {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.card-description {
		font-size: 14px;
		color: #6b7280;
		margin: 0;
		line-height: 1.4;
	}

	.card-arrow {
		font-size: 18px;
		color: #9ca3af;
		transition: transform 0.3s ease;
		flex-shrink: 0;
	}

	.dashboard-card:hover .card-arrow {
		transform: translateX(4px);
		color: #6b7280;
	}

	/* Card color variants */
	.dashboard-card:nth-child(1) { --card-color: #3b82f6; }
	.dashboard-card:nth-child(2) { --card-color: #10b981; }
	.dashboard-card:nth-child(3) { --card-color: #6366f1; }
	.dashboard-card:nth-child(4) { --card-color: #f59e0b; }
	.dashboard-card:nth-child(5) { --card-color: #ef4444; }

	.dashboard-card:nth-child(1) .card-icon { background: rgba(59, 130, 246, 0.1); }
	.dashboard-card:nth-child(2) .card-icon { background: rgba(16, 185, 129, 0.1); }
	.dashboard-card:nth-child(3) .card-icon { background: rgba(99, 102, 241, 0.1); }
	.dashboard-card:nth-child(4) .card-icon { background: rgba(245, 158, 11, 0.1); }
	.dashboard-card:nth-child(5) .card-icon { background: rgba(239, 68, 68, 0.1); }

	/* Users Section */
	.users-section {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 24px;
		flex-wrap: wrap;
		gap: 16px;
	}

	.section-title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.section-controls {
		display: flex;
		gap: 16px;
		align-items: center;
		flex-wrap: wrap;
	}

	.search-box {
		position: relative;
		min-width: 300px;
	}

	.search-icon {
		position: absolute;
		left: 12px;
		top: 50%;
		transform: translateY(-50%);
		color: #9ca3af;
		font-size: 14px;
	}

	.search-input {
		width: 100%;
		padding: 10px 12px 10px 36px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		outline: none;
		transition: border-color 0.2s;
	}

	.search-input:focus {
		border-color: #3b82f6;
	}

	.filters {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		outline: none;
		cursor: pointer;
		min-width: 120px;
	}

	.filter-select:focus {
		border-color: #3b82f6;
	}

	/* Users Table */
	.users-table-container {
		overflow-x: auto;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.users-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.users-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f3f4f6;
		vertical-align: middle;
	}

	.users-table tr:hover {
		background: #f9fafb;
	}

	.avatar-cell {
		width: 60px;
	}

	.user-avatar {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		object-fit: cover;
	}

	.avatar-placeholder {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		background: #e5e7eb;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.avatar-initials {
		font-size: 14px;
		font-weight: 600;
		color: #6b7280;
	}

	.username {
		font-weight: 600;
		color: #111827;
	}

	.role-badge, .status-badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.role-master-admin {
		background: #fef2f2;
		color: #991b1b;
	}

	.role-admin {
		background: #eff6ff;
		color: #1d4ed8;
	}

	.role-position-based {
		background: #f0fdf4;
		color: #166534;
	}

	.status-active {
		background: #f0fdf4;
		color: #166534;
	}

	.status-inactive {
		background: #fef3c7;
		color: #92400e;
	}

	.status-locked {
		background: #fef2f2;
		color: #991b1b;
	}

	.action-buttons {
		display: flex;
		gap: 8px;
	}

	.action-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		font-size: 16px;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
	}

	.action-btn:hover {
		background: #f3f4f6;
	}

	.action-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.action-btn:disabled:hover {
		background: none;
	}

	.never-logged-in {
		color: #9ca3af;
		font-style: italic;
	}

	.edit-btn:hover {
		background: #eff6ff;
	}

	.status-btn.activate:hover {
		background: #f0fdf4;
	}

	.status-btn.deactivate:hover {
		background: #fef2f2;
	}

	.lock-btn.lock:hover {
		background: #fef2f2;
	}

	.lock-btn.unlock:hover {
		background: #f0fdf4;
	}

	@media (max-width: 768px) {
		.dashboard-grid {
			grid-template-columns: 1fr;
		}

		.section-header {
			flex-direction: column;
			align-items: stretch;
		}

		.section-controls {
			flex-direction: column;
		}

		.search-box {
			min-width: unset;
		}

		.users-table-container {
			font-size: 14px;
		}

		.users-table th,
		.users-table td {
			padding: 8px 12px;
		}
	}
</style>