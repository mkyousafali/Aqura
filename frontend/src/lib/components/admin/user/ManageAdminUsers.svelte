<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';

	const dispatch = createEventDispatcher();

	// Real data from database
	let adminUsers: Array<any> = [];

	// Load admin users from database
	async function loadAdminUsers() {
		try {
			const users = await userManagement.getAllUsers();
			// Filter for admin users only
			adminUsers = users.filter(user => 
				user.role_type === 'Master Admin' || user.role_type === 'Admin'
			);
		} catch (error) {
			console.error('Error loading admin users:', error);
		}
	}

	onMount(() => {
		loadAdminUsers();
	});
	// Current user context (mock)
	let currentUser = {
		id: '1',
		role_type: 'Master Admin',
		role_level: 100
	};

	// State variables
	let isLoading = false;
	let errors: any = {};
	let successMessage = '';
	let searchTerm = '';
	let statusFilter = 'all';
	let roleFilter = 'all';
	let sortBy = 'username';
	let sortOrder = 'asc';
	let selectedUsers = new Set();
	let showBulkActions = false;
	let bulkAction = '';

	// Filter and sort options
	let statusOptions = [
		{ value: 'all', label: 'All Statuses' },
		{ value: 'active', label: 'Active' },
		{ value: 'inactive', label: 'Inactive' },
		{ value: 'locked', label: 'Locked' }
	];

	let roleOptions = [
		{ value: 'all', label: 'All Roles' },
		{ value: 'Master Admin', label: 'Master Admin' },
		{ value: 'Admin', label: 'Admin' }
	];

	let sortOptions = [
		{ value: 'username', label: 'Username' },
		{ value: 'full_name', label: 'Full Name' },
		{ value: 'role_type', label: 'Role' },
		{ value: 'status', label: 'Status' },
		{ value: 'last_login', label: 'Last Login' },
		{ value: 'created_at', label: 'Created Date' }
	];

	let bulkActions = [
		{ value: 'activate', label: '✅ Activate Users', color: '#059669' },
		{ value: 'deactivate', label: '❌ Deactivate Users', color: '#dc2626' },
		{ value: 'unlock', label: '🔓 Unlock Users', color: '#0891b2' },
		{ value: 'reset_password', label: '🔐 Reset Passwords', color: '#f59e0b' },
		{ value: 'delete', label: '🗑️ Delete Users', color: '#dc2626' }
	];

	// Computed values
	$: filteredUsers = adminUsers.filter(user => {
		// Search filter
		const matchesSearch = searchTerm === '' || 
			user.username.toLowerCase().includes(searchTerm.toLowerCase()) ||
			user.full_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
			user.email.toLowerCase().includes(searchTerm.toLowerCase());

		// Status filter
		const matchesStatus = statusFilter === 'all' || user.status === statusFilter;

		// Role filter
		const matchesRole = roleFilter === 'all' || user.role_type === roleFilter;

		return matchesSearch && matchesStatus && matchesRole;
	}).sort((a, b) => {
		let aValue = a[sortBy];
		let bValue = b[sortBy];

		// Handle date sorting
		if (sortBy === 'last_login' || sortBy === 'created_at') {
			aValue = new Date(aValue).getTime();
			bValue = new Date(bValue).getTime();
		}

		// Handle string sorting
		if (typeof aValue === 'string') {
			aValue = aValue.toLowerCase();
			bValue = bValue.toLowerCase();
		}

		if (sortOrder === 'asc') {
			return aValue > bValue ? 1 : -1;
		} else {
			return aValue < bValue ? 1 : -1;
		}
	});

	$: selectedCount = selectedUsers.size;
	$: canModifyUser = (user: any) => {
		// Master Admin can modify anyone except themselves if it's the last active Master Admin
		if (currentUser.role_type === 'Master Admin') {
			if (user.role_type === 'Master Admin' && user.id !== currentUser.id) return true;
			if (user.role_type === 'Admin') return true;
			if (user.id === currentUser.id) {
				// Check if this is the last active Master Admin
				const activeMasterAdmins = adminUsers.filter(u => 
					u.role_type === 'Master Admin' && u.status === 'active'
				);
				return activeMasterAdmins.length > 1;
			}
		}
		// Regular Admin cannot modify Master Admins or other Admins
		return false;
	};

	function formatDate(dateString: string) {
		const date = new Date(dateString);
		return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	}

	function getStatusColor(status: string) {
		switch (status) {
			case 'active': return '#059669';
			case 'inactive': return '#6b7280';
			case 'locked': return '#dc2626';
			default: return '#6b7280';
		}
	}

	function getStatusIcon(status: string) {
		switch (status) {
			case 'active': return '✅';
			case 'inactive': return '⏸️';
			case 'locked': return '🔒';
			default: return '❓';
		}
	}

	function toggleUserSelection(userId: string) {
		if (selectedUsers.has(userId)) {
			selectedUsers.delete(userId);
		} else {
			selectedUsers.add(userId);
		}
		selectedUsers = new Set(selectedUsers);
	}

	function toggleSelectAll() {
		if (selectedUsers.size === filteredUsers.length) {
			selectedUsers.clear();
		} else {
			selectedUsers = new Set(filteredUsers.map(user => user.id));
		}
		selectedUsers = new Set(selectedUsers);
	}

	function clearSelection() {
		selectedUsers.clear();
		selectedUsers = new Set(selectedUsers);
		showBulkActions = false;
	}

	async function handleUserAction(user: any, action: string) {
		if (!canModifyUser(user)) {
			errors.action = 'You do not have permission to modify this user';
			return;
		}

		isLoading = true;
		errors = {};
		successMessage = '';

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 1000));

			switch (action) {
				case 'activate':
					user.status = 'active';
					user.is_locked = false;
					user.login_attempts = 0;
					successMessage = `${user.username} has been activated`;
					break;
				case 'deactivate':
					user.status = 'inactive';
					successMessage = `${user.username} has been deactivated`;
					break;
				case 'unlock':
					user.status = 'active';
					user.is_locked = false;
					user.login_attempts = 0;
					successMessage = `${user.username} has been unlocked`;
					break;
				case 'lock':
					user.status = 'locked';
					user.is_locked = true;
					successMessage = `${user.username} has been locked`;
					break;
				case 'reset_password':
					successMessage = `Password reset email sent to ${user.email}`;
					break;
				case 'delete':
					adminUsers = adminUsers.filter(u => u.id !== user.id);
					successMessage = `${user.username} has been deleted`;
					break;
			}

			// Clear success message after 3 seconds
			setTimeout(() => successMessage = '', 3000);

		} catch (error: any) {
			errors.action = error.message || 'Action failed';
		} finally {
			isLoading = false;
		}
	}

	async function handleBulkAction() {
		if (!bulkAction || selectedUsers.size === 0) return;

		isLoading = true;
		errors = {};
		successMessage = '';

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 2000));

			const selectedUsersList = adminUsers.filter(user => selectedUsers.has(user.id));
			let actionCount = 0;

			for (const user of selectedUsersList) {
				if (canModifyUser(user)) {
					switch (bulkAction) {
						case 'activate':
							user.status = 'active';
							user.is_locked = false;
							user.login_attempts = 0;
							actionCount++;
							break;
						case 'deactivate':
							user.status = 'inactive';
							actionCount++;
							break;
						case 'unlock':
							user.status = 'active';
							user.is_locked = false;
							user.login_attempts = 0;
							actionCount++;
							break;
						case 'reset_password':
							actionCount++;
							break;
						case 'delete':
							adminUsers = adminUsers.filter(u => u.id !== user.id);
							actionCount++;
							break;
					}
				}
			}

			successMessage = `Bulk action completed on ${actionCount} users`;
			clearSelection();
			bulkAction = '';

			// Clear success message after 3 seconds
			setTimeout(() => successMessage = '', 3000);

		} catch (error: any) {
			errors.bulk = error.message || 'Bulk action failed';
		} finally {
			isLoading = false;
		}
	}

	function editUser(user: any) {
		dispatch('editUser', user);
	}

	function assignRoles(user: any) {
		dispatch('assignRoles', user);
	}

	function createUser() {
		dispatch('createUser');
	}

	function handleClose() {
		dispatch('close');
	}

	function exportData() {
		// Mock export functionality
		const dataToExport = filteredUsers.map(user => ({
			username: user.username,
			email: user.email,
			full_name: user.full_name,
			role: user.role_type,
			status: user.status,
			last_login: user.last_login,
			created_at: user.created_at
		}));

		const csvContent = "data:text/csv;charset=utf-8," 
			+ "Username,Email,Full Name,Role,Status,Last Login,Created At\n"
			+ dataToExport.map(row => Object.values(row).join(",")).join("\n");

		const link = document.createElement("a");
		link.setAttribute("href", encodeURI(csvContent));
		link.setAttribute("download", "admin_users.csv");
		link.click();
	}
</script>

<div class="manage-admin-users">
	<div class="header">
		<h1 class="title">Manage Administrator Users</h1>
		<p class="subtitle">Monitor and manage all administrative user accounts</p>
	</div>

	<!-- Controls Bar -->
	<div class="controls-bar">
		<div class="search-section">
			<div class="search-box">
				<input
					type="text"
					placeholder="Search users..."
					bind:value={searchTerm}
					class="search-input"
				>
				<span class="search-icon">🔍</span>
			</div>
		</div>

		<div class="filters-section">
			<select bind:value={statusFilter} class="filter-select">
				{#each statusOptions as option}
					<option value={option.value}>{option.label}</option>
				{/each}
			</select>

			<select bind:value={roleFilter} class="filter-select">
				{#each roleOptions as option}
					<option value={option.value}>{option.label}</option>
				{/each}
			</select>

			<select bind:value={sortBy} class="filter-select">
				{#each sortOptions as option}
					<option value={option.value}>{option.label}</option>
				{/each}
			</select>

			<button 
				class="sort-order-btn" 
				on:click={() => sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'}
				title="Toggle sort order"
			>
				{sortOrder === 'asc' ? '↑' : '↓'}
			</button>
		</div>

		<div class="actions-section">
			<button class="action-btn export" on:click={exportData}>
				📊 Export
			</button>
			<button class="action-btn create" on:click={createUser}>
				➕ Create Admin
			</button>
		</div>
	</div>

	<!-- Bulk Actions Bar -->
	{#if selectedCount > 0}
		<div class="bulk-actions-bar">
			<div class="selection-info">
				<span class="selected-count">{selectedCount} selected</span>
				<button class="clear-selection" on:click={clearSelection}>Clear</button>
			</div>

			<div class="bulk-controls">
				<select bind:value={bulkAction} class="bulk-select">
					<option value="">Choose Action</option>
					{#each bulkActions as action}
						<option value={action.value}>{action.label}</option>
					{/each}
				</select>
				<button 
					class="bulk-apply-btn" 
					disabled={!bulkAction || isLoading}
					on:click={handleBulkAction}
				>
					{#if isLoading}
						<span class="spinner"></span>
					{:else}
						Apply
					{/if}
				</button>
			</div>
		</div>
	{/if}

	<!-- Users Table -->
	<div class="users-container">
		<div class="users-table">
			<div class="table-header">
				<div class="header-cell checkbox-cell">
					<input
						type="checkbox"
						checked={selectedCount === filteredUsers.length && filteredUsers.length > 0}
						indeterminate={selectedCount > 0 && selectedCount < filteredUsers.length}
						on:change={toggleSelectAll}
						class="select-checkbox"
					>
				</div>
				<div class="header-cell">Avatar</div>
				<div class="header-cell">User Info</div>
				<div class="header-cell">Role & Status</div>
				<div class="header-cell">Activity</div>
				<div class="header-cell">Security</div>
				<div class="header-cell">Actions</div>
			</div>

			<div class="table-body">
				{#each filteredUsers as user}
					<div class="table-row" class:selected={selectedUsers.has(user.id)}>
						<div class="table-cell checkbox-cell">
							<input
								type="checkbox"
								checked={selectedUsers.has(user.id)}
								on:change={() => toggleUserSelection(user.id)}
								class="select-checkbox"
							>
						</div>

						<div class="table-cell">
							<div class="user-avatar">
								{#if user.avatar_url}
									<img src={user.avatar_url} alt="Avatar" class="avatar-image">
								{:else}
									<div class="avatar-placeholder">
										<span class="avatar-icon">👤</span>
									</div>
								{/if}
							</div>
						</div>

						<div class="table-cell">
							<div class="user-info">
								<h3 class="username">{user.username}</h3>
								<p class="full-name">{user.full_name}</p>
								<p class="email">{user.email}</p>
								<p class="branch">{user.branch_name}</p>
							</div>
						</div>

						<div class="table-cell">
							<div class="role-status">
								<div class="role-badge" class:master={user.role_type === 'Master Admin'}>
									{user.role_type}
								</div>
								<div class="status-badge" style="color: {getStatusColor(user.status)}">
									{getStatusIcon(user.status)} {user.status}
								</div>
							</div>
						</div>

						<div class="table-cell">
							<div class="activity-info">
								<div class="activity-item">
									<span class="label">Last Login:</span>
									<span class="value">{formatDate(user.last_login)}</span>
								</div>
								<div class="activity-item">
									<span class="label">Created:</span>
									<span class="value">{formatDate(user.created_at)}</span>
								</div>
							</div>
						</div>

						<div class="table-cell">
							<div class="security-info">
								<div class="security-item" class:warning={user.login_attempts > 0}>
									<span class="label">Login Attempts:</span>
									<span class="value">{user.login_attempts}</span>
								</div>
								<div class="security-item" class:danger={user.is_locked}>
									<span class="label">Account:</span>
									<span class="value">{user.is_locked ? '🔒 Locked' : '🔓 Open'}</span>
								</div>
							</div>
						</div>

						<div class="table-cell">
							<div class="user-actions">
								<div class="action-group">
									<button
										class="action-btn small edit"
										on:click={() => editUser(user)}
										disabled={!canModifyUser(user)}
										title="Edit User"
									>
										✏️
									</button>
									<button
										class="action-btn small roles"
										on:click={() => assignRoles(user)}
										disabled={!canModifyUser(user)}
										title="Assign Roles"
									>
										🎭
									</button>
								</div>

								<div class="dropdown">
									<button class="dropdown-btn" disabled={!canModifyUser(user)}>⋮</button>
									<div class="dropdown-content">
										{#if user.status === 'active'}
											<button on:click={() => handleUserAction(user, 'deactivate')}>
												❌ Deactivate
											</button>
										{:else}
											<button on:click={() => handleUserAction(user, 'activate')}>
												✅ Activate
											</button>
										{/if}

										{#if user.is_locked}
											<button on:click={() => handleUserAction(user, 'unlock')}>
												🔓 Unlock
											</button>
										{:else}
											<button on:click={() => handleUserAction(user, 'lock')}>
												🔒 Lock
											</button>
										{/if}

										<button on:click={() => handleUserAction(user, 'reset_password')}>
											🔐 Reset Password
										</button>

										{#if user.id !== currentUser.id}
											<button 
												on:click={() => handleUserAction(user, 'delete')}
												class="danger"
											>
												🗑️ Delete
											</button>
										{/if}
									</div>
								</div>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>

		{#if filteredUsers.length === 0}
			<div class="empty-state">
				<div class="empty-icon">👥</div>
				<h3>No administrators found</h3>
				<p>No users match your current search and filter criteria.</p>
				<button class="action-btn create" on:click={createUser}>
					Create First Admin User
				</button>
			</div>
		{/if}
	</div>

	<!-- Messages -->
	{#if errors.action || errors.bulk}
		<div class="error-banner">
			<strong>Error:</strong> {errors.action || errors.bulk}
		</div>
	{/if}

	{#if successMessage}
		<div class="success-banner">
			<strong>Success:</strong> {successMessage}
		</div>
	{/if}

	<!-- Summary Stats -->
	<div class="stats-bar">
		<div class="stat-item">
			<span class="stat-value">{adminUsers.filter(u => u.status === 'active').length}</span>
			<span class="stat-label">Active</span>
		</div>
		<div class="stat-item">
			<span class="stat-value">{adminUsers.filter(u => u.status === 'inactive').length}</span>
			<span class="stat-label">Inactive</span>
		</div>
		<div class="stat-item">
			<span class="stat-value">{adminUsers.filter(u => u.is_locked).length}</span>
			<span class="stat-label">Locked</span>
		</div>
		<div class="stat-item">
			<span class="stat-value">{adminUsers.filter(u => u.role_type === 'Master Admin').length}</span>
			<span class="stat-label">Master Admins</span>
		</div>
		<div class="stat-item">
			<span class="stat-value">{filteredUsers.length}</span>
			<span class="stat-label">Showing</span>
		</div>
	</div>

	<!-- Close Button -->
	<div class="window-actions">
		<button class="close-window-btn" on:click={handleClose}>
			Close Window
		</button>
	</div>
</div>

<style>
	.manage-admin-users {
		height: 100%;
		background: #f8fafc;
		display: flex;
		flex-direction: column;
		padding: 24px;
	}

	.header {
		text-align: center;
		margin-bottom: 24px;
	}

	.title {
		font-size: 28px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.controls-bar {
		display: flex;
		gap: 16px;
		align-items: center;
		background: white;
		padding: 16px;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		margin-bottom: 16px;
	}

	.search-section {
		flex: 1;
		max-width: 300px;
	}

	.search-box {
		position: relative;
	}

	.search-input {
		width: 100%;
		padding: 8px 12px 8px 32px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-icon {
		position: absolute;
		left: 10px;
		top: 50%;
		transform: translateY(-50%);
		color: #9ca3af;
		font-size: 14px;
	}

	.filters-section {
		display: flex;
		gap: 8px;
		align-items: center;
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		min-width: 120px;
	}

	.sort-order-btn {
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 8px 12px;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.sort-order-btn:hover {
		background: #e5e7eb;
	}

	.actions-section {
		display: flex;
		gap: 8px;
	}

	.action-btn {
		padding: 8px 16px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.action-btn.export {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	.action-btn.create {
		background: #059669;
		color: white;
		border-color: #059669;
	}

	.action-btn:hover {
		transform: translateY(-1px);
	}

	.bulk-actions-bar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: #fef3c7;
		border: 1px solid #fbbf24;
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 16px;
	}

	.selection-info {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.selected-count {
		font-weight: 600;
		color: #92400e;
	}

	.clear-selection {
		background: none;
		border: none;
		color: #92400e;
		text-decoration: underline;
		cursor: pointer;
		font-size: 14px;
	}

	.bulk-controls {
		display: flex;
		gap: 8px;
		align-items: center;
	}

	.bulk-select {
		padding: 6px 12px;
		border: 1px solid #d97706;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.bulk-apply-btn {
		background: #d97706;
		color: white;
		border: 1px solid #d97706;
		border-radius: 6px;
		padding: 6px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.bulk-apply-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.users-container {
		flex: 1;
		background: white;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		margin-bottom: 16px;
	}

	.users-table {
		height: 100%;
		display: flex;
		flex-direction: column;
	}

	.table-header, .table-row {
		display: grid;
		grid-template-columns: 40px 60px 2fr 1fr 1fr 1fr 120px;
		gap: 12px;
		align-items: center;
		padding: 12px 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.table-header {
		background: #f9fafb;
		font-weight: 600;
		color: #374151;
		font-size: 14px;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.table-row.selected {
		background: #eff6ff;
		border-left: 3px solid #3b82f6;
	}

	.table-body {
		flex: 1;
		overflow-y: auto;
	}

	.header-cell, .table-cell {
		display: flex;
		align-items: center;
	}

	.checkbox-cell {
		justify-content: center;
	}

	.select-checkbox {
		width: 16px;
		height: 16px;
	}

	.user-avatar {
		width: 40px;
		height: 40px;
	}

	.avatar-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 50%;
		border: 2px solid #e5e7eb;
	}

	.avatar-placeholder {
		width: 100%;
		height: 100%;
		border-radius: 50%;
		border: 2px solid #d1d5db;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #f3f4f6;
	}

	.avatar-icon {
		font-size: 16px;
	}

	.user-info h3 {
		font-size: 14px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 2px 0;
	}

	.user-info p {
		font-size: 12px;
		color: #6b7280;
		margin: 1px 0;
	}

	.role-status {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.role-badge {
		background: #e0e7ff;
		color: #3730a3;
		padding: 2px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		text-align: center;
	}

	.role-badge.master {
		background: #fef3c7;
		color: #92400e;
	}

	.status-badge {
		font-size: 11px;
		font-weight: 500;
		text-align: center;
	}

	.activity-info, .security-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.activity-item, .security-item {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.activity-item .label, .security-item .label {
		font-size: 10px;
		color: #9ca3af;
		text-transform: uppercase;
		font-weight: 500;
	}

	.activity-item .value, .security-item .value {
		font-size: 11px;
		color: #374151;
	}

	.security-item.warning .value {
		color: #f59e0b;
		font-weight: 600;
	}

	.security-item.danger .value {
		color: #dc2626;
		font-weight: 600;
	}

	.user-actions {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.action-group {
		display: flex;
		gap: 2px;
	}

	.action-btn.small {
		padding: 4px 6px;
		font-size: 12px;
		border-radius: 4px;
		min-width: auto;
	}

	.action-btn.small.edit {
		background: #f59e0b;
		color: white;
		border-color: #f59e0b;
	}

	.action-btn.small.roles {
		background: #8b5cf6;
		color: white;
		border-color: #8b5cf6;
	}

	.dropdown {
		position: relative;
	}

	.dropdown-btn {
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		padding: 4px 8px;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.dropdown-btn:hover {
		background: #e5e7eb;
	}

	.dropdown-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.dropdown:hover .dropdown-content {
		display: block;
	}

	.dropdown-content {
		display: none;
		position: absolute;
		right: 0;
		top: 100%;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		z-index: 10;
		min-width: 150px;
	}

	.dropdown-content button {
		display: block;
		width: 100%;
		padding: 8px 12px;
		text-align: left;
		border: none;
		background: none;
		cursor: pointer;
		font-size: 12px;
		color: #374151;
		transition: background-color 0.2s;
	}

	.dropdown-content button:hover {
		background: #f3f4f6;
	}

	.dropdown-content button.danger {
		color: #dc2626;
	}

	.dropdown-content button.danger:hover {
		background: #fef2f2;
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px 24px;
		text-align: center;
	}

	.empty-icon {
		font-size: 48px;
		margin-bottom: 16px;
		opacity: 0.5;
	}

	.empty-state h3 {
		font-size: 18px;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.empty-state p {
		color: #6b7280;
		margin: 0 0 24px 0;
	}

	.stats-bar {
		display: flex;
		gap: 24px;
		justify-content: center;
		background: white;
		padding: 16px;
		border-radius: 8px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		margin-bottom: 16px;
	}

	.stat-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
	}

	.stat-value {
		font-size: 20px;
		font-weight: 700;
		color: #111827;
	}

	.stat-label {
		font-size: 12px;
		color: #6b7280;
		text-transform: uppercase;
		font-weight: 500;
	}

	.window-actions {
		text-align: center;
	}

	.close-window-btn {
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 12px 24px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-window-btn:hover {
		background: #4b5563;
		transform: translateY(-1px);
	}

	/* Messages */
	.error-banner, .success-banner {
		position: fixed;
		top: 20px;
		right: 20px;
		padding: 12px 16px;
		border-radius: 8px;
		font-size: 14px;
		z-index: 50;
		max-width: 400px;
	}

	.error-banner {
		background: #fef2f2;
		color: #991b1b;
		border: 1px solid #fecaca;
	}

	.success-banner {
		background: #f0fdf4;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	@media (max-width: 1200px) {
		.table-header, .table-row {
			grid-template-columns: 40px 60px 2fr 1fr 120px;
		}

		.activity-info, .security-info {
			display: none;
		}
	}

	@media (max-width: 768px) {
		.controls-bar {
			flex-direction: column;
			gap: 12px;
		}

		.filters-section, .actions-section {
			width: 100%;
			justify-content: center;
		}

		.search-section {
			max-width: none;
			width: 100%;
		}

		.table-header, .table-row {
			grid-template-columns: 40px 60px 2fr 120px;
		}

		.role-status {
			display: none;
		}

		.stats-bar {
			flex-wrap: wrap;
			gap: 16px;
		}
	}
</style>