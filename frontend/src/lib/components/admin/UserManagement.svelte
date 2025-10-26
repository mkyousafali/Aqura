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

	// Approval limit modal state
	let showApprovalLimitModal = false;
	let editingApprovalUser = null;
	let tempApprovalLimit = 0;

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

	async function toggleApprovalPermission(user) {
		try {
			// Check if current user is Master Admin
			if (userRoleType !== 'Master Admin') {
				alert('❌ Only Master Admins can modify approval permissions');
				return;
			}

			const newValue = !user.can_approve_payments;
			
			await userManagement.updateUser(user.id, {
				can_approve_payments: newValue
			});
			
			// Update local data immediately
			user.can_approve_payments = newValue;
			users = [...users]; // Trigger reactivity
			
			console.log(`User ${user.username} approval permission changed to ${newValue}`);
		} catch (err) {
			console.error('Error updating approval permission:', err);
			alert('Failed to update approval permission: ' + err.message);
		}
	}

	async function updateApprovalLimit(user, newLimit) {
		try {
			// Check if current user is Master Admin
			if (userRoleType !== 'Master Admin') {
				alert('❌ Only Master Admins can modify approval limits');
				return;
			}

			const limitValue = newLimit === '' || newLimit === null ? 0 : parseFloat(newLimit);
			
			if (isNaN(limitValue) || limitValue < 0) {
				alert('Please enter a valid amount (0 or greater)');
				return;
			}
			
			await userManagement.updateUser(user.id, {
				approval_amount_limit: limitValue
			});
			
			// Update local data immediately
			user.approval_amount_limit = limitValue;
			users = [...users]; // Trigger reactivity
			
			console.log(`User ${user.username} approval limit updated to ${limitValue}`);
		} catch (err) {
			console.error('Error updating approval limit:', err);
			alert('Failed to update approval limit: ' + err.message);
		}
	}

	function openApprovalLimitModal(user) {
		// Check if current user is Master Admin
		if (userRoleType !== 'Master Admin') {
			alert('❌ Only Master Admins can modify approval limits');
			return;
		}

		if (!user.can_approve_payments) {
			alert('⚠️ Please enable approval permission first');
			return;
		}

		editingApprovalUser = user;
		tempApprovalLimit = user.approval_amount_limit || 0;
		showApprovalLimitModal = true;
	}

	function closeApprovalLimitModal() {
		showApprovalLimitModal = false;
		editingApprovalUser = null;
		tempApprovalLimit = 0;
	}

	async function saveApprovalLimit() {
		try {
			if (!editingApprovalUser) return;

			const limitValue = parseFloat(tempApprovalLimit);
			
			if (isNaN(limitValue) || limitValue < 0) {
				alert('Please enter a valid amount (0 or greater)');
				return;
			}
			
			await userManagement.updateUser(editingApprovalUser.id, {
				approval_amount_limit: limitValue
			});
			
			// Update local data immediately
			editingApprovalUser.approval_amount_limit = limitValue;
			users = [...users]; // Trigger reactivity
			
			console.log(`User ${editingApprovalUser.username} approval limit updated to ${limitValue}`);
			
			closeApprovalLimitModal();
			alert('✅ Approval limit saved successfully!');
		} catch (err) {
			console.error('Error updating approval limit:', err);
			alert('Failed to update approval limit: ' + err.message);
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
								<th>Approval Permission</th>
								<th>Approval Limit (SAR)</th>
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
									<td class="approval-permission-cell">
										<label class="toggle-switch">
											<input 
												type="checkbox" 
												checked={user.can_approve_payments || false}
												on:change={() => toggleApprovalPermission(user)}
												disabled={user.status !== 'active' || userRoleType !== 'Master Admin'}
											/>
											<span class="toggle-slider"></span>
										</label>
									</td>
									<td class="approval-limit-cell">
										{#if user.can_approve_payments}
											<button 
												class="approval-limit-btn"
												on:click={() => openApprovalLimitModal(user)}
												disabled={userRoleType !== 'Master Admin'}
												title={userRoleType !== 'Master Admin' ? 'Only Master Admins can modify approval limits' : 'Click to set approval limit'}
											>
												{#if user.approval_amount_limit && user.approval_amount_limit > 0}
													<span class="limit-amount">{parseFloat(user.approval_amount_limit).toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})} SAR</span>
												{:else}
													<span class="no-limit">Set Limit</span>
												{/if}
											</button>
										{:else}
											<span class="no-permission">No Permission</span>
										{/if}
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

<!-- Approval Limit Modal -->
{#if showApprovalLimitModal && editingApprovalUser}
	<div class="modal-overlay" on:click={closeApprovalLimitModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2 class="modal-title">💰 Set Approval Limit</h2>
				<button class="modal-close" on:click={closeApprovalLimitModal}>✕</button>
			</div>
			
			<div class="modal-body">
				<div class="user-info">
					<div class="info-row">
						<span class="info-label">User:</span>
						<span class="info-value">{editingApprovalUser.username}</span>
					</div>
					<div class="info-row">
						<span class="info-label">Employee:</span>
						<span class="info-value">{editingApprovalUser.employee_name || 'Not Assigned'}</span>
					</div>
				</div>

				<div class="form-group">
					<label for="approval-limit">Maximum Approval Amount (SAR)</label>
					<div class="amount-input-wrapper">
						<input 
							type="number"
							id="approval-limit"
							bind:value={tempApprovalLimit}
							min="0"
							step="100"
							placeholder="0.00"
							class="modal-amount-input"
							autofocus
						/>
						<span class="currency-label">SAR</span>
					</div>
					<p class="help-text">
						Enter 0 for unlimited approval amount, or specify a maximum limit.
					</p>
				</div>

				<div class="quick-amounts">
					<p class="quick-label">Quick amounts:</p>
					<div class="quick-buttons">
						<button class="quick-btn" on:click={() => tempApprovalLimit = 5000}>5,000</button>
						<button class="quick-btn" on:click={() => tempApprovalLimit = 10000}>10,000</button>
						<button class="quick-btn" on:click={() => tempApprovalLimit = 25000}>25,000</button>
						<button class="quick-btn" on:click={() => tempApprovalLimit = 50000}>50,000</button>
						<button class="quick-btn" on:click={() => tempApprovalLimit = 100000}>100,000</button>
						<button class="quick-btn unlimited" on:click={() => tempApprovalLimit = 0}>Unlimited</button>
					</div>
				</div>
			</div>

			<div class="modal-footer">
				<button class="btn-cancel" on:click={closeApprovalLimitModal}>
					Cancel
				</button>
				<button class="btn-save" on:click={saveApprovalLimit}>
					💾 Save Limit
				</button>
			</div>
		</div>
	</div>
{/if}

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

	/* Toggle Switch Styles */
	.approval-permission-cell {
		text-align: center;
		padding: 12px 16px;
	}

	.toggle-switch {
		position: relative;
		display: inline-block;
		width: 48px;
		height: 24px;
		cursor: pointer;
	}

	.toggle-switch input {
		opacity: 0;
		width: 0;
		height: 0;
	}

	.toggle-slider {
		position: absolute;
		cursor: pointer;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background-color: #d1d5db;
		transition: 0.3s;
		border-radius: 24px;
	}

	.toggle-slider:before {
		position: absolute;
		content: "";
		height: 18px;
		width: 18px;
		left: 3px;
		bottom: 3px;
		background-color: white;
		transition: 0.3s;
		border-radius: 50%;
	}

	.toggle-switch input:checked + .toggle-slider {
		background-color: #10b981;
	}

	.toggle-switch input:checked + .toggle-slider:before {
		transform: translateX(24px);
	}

	.toggle-switch input:disabled + .toggle-slider {
		background-color: #e5e7eb;
		cursor: not-allowed;
		opacity: 0.6;
	}

	/* Amount Input Styles */
	.approval-limit-cell {
		padding: 12px 16px;
		text-align: center;
	}

	.approval-limit-btn {
		padding: 8px 16px;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		background: white;
		cursor: pointer;
		font-size: 14px;
		font-weight: 600;
		transition: all 0.2s ease;
		min-width: 120px;
	}

	.approval-limit-btn:hover:not(:disabled) {
		border-color: #3b82f6;
		background: #eff6ff;
		transform: translateY(-1px);
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.approval-limit-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.limit-amount {
		color: #059669;
		font-family: 'Courier New', monospace;
	}

	.no-limit {
		color: #6b7280;
	}

	.no-permission {
		color: #9ca3af;
		font-style: italic;
		font-size: 13px;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
		backdrop-filter: blur(4px);
		animation: fadeIn 0.2s ease;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.modal-content {
		background: white;
		border-radius: 16px;
		width: 90%;
		max-width: 500px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
		animation: slideUp 0.3s ease;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px 24px 16px;
		border-bottom: 2px solid #f3f4f6;
	}

	.modal-title {
		font-size: 20px;
		font-weight: 700;
		color: #111827;
		margin: 0;
	}

	.modal-close {
		background: none;
		border: none;
		font-size: 24px;
		color: #9ca3af;
		cursor: pointer;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.modal-close:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.modal-body {
		padding: 24px;
	}

	.user-info {
		background: #f9fafb;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 24px;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		padding: 8px 0;
	}

	.info-label {
		font-weight: 600;
		color: #6b7280;
		font-size: 14px;
	}

	.info-value {
		color: #111827;
		font-weight: 600;
		font-size: 14px;
	}

	.form-group {
		margin-bottom: 24px;
	}

	.form-group label {
		display: block;
		font-weight: 600;
		color: #374151;
		margin-bottom: 8px;
		font-size: 14px;
	}

	.amount-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.modal-amount-input {
		width: 100%;
		padding: 14px 60px 14px 14px;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		font-size: 20px;
		font-weight: 700;
		text-align: right;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
		font-family: 'Courier New', monospace;
	}

	.modal-amount-input:focus {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.currency-label {
		position: absolute;
		right: 14px;
		font-weight: 700;
		color: #6b7280;
		font-size: 16px;
		pointer-events: none;
	}

	.help-text {
		margin: 8px 0 0;
		font-size: 13px;
		color: #6b7280;
		line-height: 1.5;
	}

	.quick-amounts {
		background: #f9fafb;
		padding: 16px;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.quick-label {
		font-size: 13px;
		font-weight: 600;
		color: #6b7280;
		margin: 0 0 12px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.quick-buttons {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 8px;
	}

	.quick-btn {
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		background: white;
		color: #374151;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.quick-btn:hover {
		border-color: #3b82f6;
		background: #eff6ff;
		color: #3b82f6;
		transform: translateY(-1px);
	}

	.quick-btn.unlimited {
		grid-column: span 3;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
	}

	.quick-btn.unlimited:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 16px 24px 24px;
		border-top: 2px solid #f3f4f6;
	}

	.btn-cancel {
		padding: 10px 20px;
		border: 2px solid #d1d5db;
		border-radius: 8px;
		background: white;
		color: #374151;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-cancel:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.btn-save {
		padding: 10px 24px;
		border: none;
		border-radius: 8px;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.btn-save:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
	}

	/* Remove spinner arrows from number input */
	.modal-amount-input::-webkit-outer-spin-button,
	.modal-amount-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.modal-amount-input[type=number] {
		-moz-appearance: textfield;
		appearance: textfield;
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