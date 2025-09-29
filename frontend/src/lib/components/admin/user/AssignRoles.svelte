<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';

	const dispatch = createEventDispatcher();

	// Props
	export let user: any = null;

	// Real data from database
	let allRoles: Array<{
		id: string;
		name: string;
		code: string;
		description: string;
		level: number;
		category: string;
	}> = [];

	let permissions = [
		{
			category: 'User Management',
			items: [
				{ id: 'user_create', name: 'Create Users', description: 'Create new user accounts' },
				{ id: 'user_edit', name: 'Edit Users', description: 'Modify existing user information' },
				{ id: 'user_delete', name: 'Delete Users', description: 'Remove user accounts' },
				{ id: 'user_view', name: 'View Users', description: 'Access user information' }
			]
		},
		{
			category: 'Employee Management',
			items: [
				{ id: 'employee_create', name: 'Create Employees', description: 'Add new employee records' },
				{ id: 'employee_edit', name: 'Edit Employees', description: 'Update employee information' },
				{ id: 'employee_delete', name: 'Delete Employees', description: 'Remove employee records' },
				{ id: 'employee_view', name: 'View Employees', description: 'Access employee data' }
			]
		},
		{
			category: 'Payroll',
			items: [
				{ id: 'payroll_process', name: 'Process Payroll', description: 'Generate and process payroll' },
				{ id: 'payroll_approve', name: 'Approve Payroll', description: 'Approve payroll runs' },
				{ id: 'payroll_view', name: 'View Payroll', description: 'Access payroll information' },
				{ id: 'payroll_reports', name: 'Payroll Reports', description: 'Generate payroll reports' }
			]
		},
		{
			category: 'Reports',
			items: [
				{ id: 'reports_generate', name: 'Generate Reports', description: 'Create system reports' },
				{ id: 'reports_view', name: 'View Reports', description: 'Access existing reports' },
				{ id: 'reports_export', name: 'Export Reports', description: 'Download and export reports' },
				{ id: 'reports_schedule', name: 'Schedule Reports', description: 'Set up automated reports' }
			]
		},
		{
			category: 'System Administration',
			items: [
				{ id: 'system_settings', name: 'System Settings', description: 'Configure system settings' },
				{ id: 'system_backup', name: 'System Backup', description: 'Manage system backups' },
				{ id: 'system_logs', name: 'System Logs', description: 'Access system audit logs' },
				{ id: 'system_maintenance', name: 'System Maintenance', description: 'Perform system maintenance' }
			]
		}
	];

	// Load data from database
	async function loadRolesData() {
		try {
			const rolesData = await userManagement.getUserRoles();
			
			// Transform the data to match expected format
			allRoles = rolesData.map(role => ({
				id: role.id,
				name: role.role_name,
				code: role.role_code,
				description: getRoleDescription(role.role_code),
				level: getRoleLevel(role.role_code),
				category: getRoleCategory(role.role_code)
			}));
		} catch (error) {
			console.error('Error loading roles data:', error);
			// You might want to show an error message to the user
		}
	}

	// Helper functions to map role codes to descriptions, levels, and categories
	function getRoleDescription(code: string): string {
		const descriptions: { [key: string]: string } = {
			'MASTER_ADMIN': 'Full system access and control',
			'ADMIN': 'System administration with limited controls',
			'HR_MANAGER': 'Human resources management and oversight',
			'BRANCH_MANAGER': 'Complete branch operations management',
			'PAYROLL_MANAGER': 'Payroll processing and management',
			'SUPERVISOR': 'Team supervision and daily operations',
			'EMPLOYEE': 'Basic employee access and functions'
		};
		return descriptions[code] || 'Role-based access and functions';
	}

	function getRoleLevel(code: string): number {
		const levels: { [key: string]: number } = {
			'MASTER_ADMIN': 100,
			'ADMIN': 90,
			'HR_MANAGER': 80,
			'BRANCH_MANAGER': 70,
			'PAYROLL_MANAGER': 60,
			'SUPERVISOR': 50,
			'EMPLOYEE': 10
		};
		return levels[code] || 30;
	}

	function getRoleCategory(code: string): string {
		const categories: { [key: string]: string } = {
			'MASTER_ADMIN': 'system',
			'ADMIN': 'system',
			'HR_MANAGER': 'hr',
			'BRANCH_MANAGER': 'branch',
			'PAYROLL_MANAGER': 'finance',
			'SUPERVISOR': 'operations',
			'EMPLOYEE': 'basic'
		};
		return categories[code] || 'general';
	}

	// Load data when component mounts
	onMount(() => {
		loadRolesData();
	});

	// Current user permissions (mock)
	let currentUser = {
		role_type: 'Master Admin',
		level: 100
	};

	// State variables
	let isLoading = false;
	let errors: any = {};
	let successMessage = '';
	let selectedRoleId = user?.role_id || '';
	let customPermissions = new Set(user?.custom_permissions || []);
	let inheritedPermissions = new Set();
	let searchTerm = '';
	let selectedCategory = 'all';
	let showAdvanced = false;

	// Categories for filtering
	$: categories = ['all', ...new Set(permissions.map(p => p.category))];

	// Filter roles based on current user's level
	$: availableRoles = allRoles.filter(role => {
		if (currentUser.role_type === 'Master Admin') return true;
		return role.level < currentUser.level;
	});

	// Get selected role details
	$: selectedRole = availableRoles.find(role => role.id === selectedRoleId);

	// Update inherited permissions when role changes
	$: if (selectedRole) {
		updateInheritedPermissions();
	}

	// Filter permissions based on search and category
	$: filteredPermissions = permissions
		.filter(category => 
			selectedCategory === 'all' || category.category === selectedCategory
		)
		.map(category => ({
			...category,
			items: category.items.filter(item =>
				searchTerm === '' || 
				item.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
				item.description.toLowerCase().includes(searchTerm.toLowerCase())
			)
		}))
		.filter(category => category.items.length > 0);

	function updateInheritedPermissions() {
		// Mock logic to get inherited permissions based on role
		inheritedPermissions.clear();
		
		if (selectedRole) {
			// Basic permissions for all roles
			inheritedPermissions.add('employee_view');
			inheritedPermissions.add('reports_view');

			// Role-specific permissions
			if (selectedRole.level >= 50) {
				inheritedPermissions.add('employee_edit');
				inheritedPermissions.add('reports_generate');
			}

			if (selectedRole.level >= 70) {
				inheritedPermissions.add('employee_create');
				inheritedPermissions.add('payroll_view');
				inheritedPermissions.add('user_view');
			}

			if (selectedRole.level >= 80) {
				inheritedPermissions.add('employee_delete');
				inheritedPermissions.add('payroll_process');
				inheritedPermissions.add('user_create');
				inheritedPermissions.add('user_edit');
			}

			if (selectedRole.level >= 90) {
				inheritedPermissions.add('payroll_approve');
				inheritedPermissions.add('user_delete');
				inheritedPermissions.add('system_settings');
				inheritedPermissions.add('system_logs');
			}

			if (selectedRole.level >= 100) {
				inheritedPermissions.add('system_backup');
				inheritedPermissions.add('system_maintenance');
			}
		}

		// Trigger reactivity
		inheritedPermissions = new Set(inheritedPermissions);
	}

	function toggleCustomPermission(permissionId: string) {
		if (customPermissions.has(permissionId)) {
			customPermissions.delete(permissionId);
		} else {
			customPermissions.add(permissionId);
		}
		customPermissions = new Set(customPermissions);
	}

	function getPermissionStatus(permissionId: string) {
		const isInherited = inheritedPermissions.has(permissionId);
		const isCustom = customPermissions.has(permissionId);
		
		if (isInherited && isCustom) return 'both';
		if (isInherited) return 'inherited';
		if (isCustom) return 'custom';
		return 'none';
	}

	function selectPreset(preset: string) {
		customPermissions.clear();
		
		switch (preset) {
			case 'minimal':
				customPermissions.add('employee_view');
				customPermissions.add('reports_view');
				break;
			case 'standard':
				customPermissions.add('employee_view');
				customPermissions.add('employee_edit');
				customPermissions.add('reports_view');
				customPermissions.add('reports_generate');
				break;
			case 'manager':
				customPermissions.add('employee_view');
				customPermissions.add('employee_edit');
				customPermissions.add('employee_create');
				customPermissions.add('reports_view');
				customPermissions.add('reports_generate');
				customPermissions.add('payroll_view');
				break;
			case 'admin':
				permissions.forEach(category => {
					category.items.forEach(item => {
						if (!item.id.includes('system_')) {
							customPermissions.add(item.id);
						}
					});
				});
				break;
		}
		
		customPermissions = new Set(customPermissions);
	}

	function validateAssignment() {
		errors = {};

		if (!selectedRoleId) {
			errors.role = 'Please select a role';
			return false;
		}

		// Check if user is trying to assign a role higher than their own
		if (selectedRole && selectedRole.level >= currentUser.level) {
			errors.role = 'You cannot assign a role equal to or higher than your own';
			return false;
		}

		return true;
	}

	async function handleSubmit() {
		if (!validateAssignment()) {
			return;
		}

		isLoading = true;
		successMessage = '';

		try {
			// Simulate API call
			await new Promise(resolve => setTimeout(resolve, 2000));
			
			const assignmentData = {
				userId: user?.id,
				roleId: selectedRoleId,
				customPermissions: Array.from(customPermissions),
				assignedBy: 'current_user_id' // Would come from auth context
			};
			
			console.log('Assigning role with data:', assignmentData);
			
			successMessage = `Role "${selectedRole?.name}" successfully assigned to ${user?.username}!`;

		} catch (error: any) {
			errors.submit = error.message || 'Failed to assign role';
		} finally {
			isLoading = false;
		}
	}

	function handleClose() {
		dispatch('close');
	}

	// Check if current user can assign roles to this user
	let canAssign = true;
	if (user && currentUser.role_type !== 'Master Admin') {
		if (user.role_level && user.role_level >= currentUser.level) {
			canAssign = false;
		}
	}
</script>

<div class="assign-roles">
	<div class="header">
		<h1 class="title">Assign Roles & Permissions</h1>
		<p class="subtitle">Manage access rights for {user?.username || 'Unknown User'}</p>
	</div>

	{#if !canAssign}
		<div class="permission-error">
			<h2>Access Denied</h2>
			<p>You do not have permission to assign roles to this user.</p>
			<button class="close-btn" on:click={handleClose}>Close</button>
		</div>
	{:else}
		<form on:submit|preventDefault={handleSubmit} class="assignment-form">
			<!-- Current User Info -->
			<div class="user-info">
				<div class="user-card">
					<div class="user-avatar">
						{#if user?.avatar_url}
							<img src={user.avatar_url} alt="User Avatar" class="avatar-image">
						{:else}
							<div class="avatar-placeholder">
								<span class="avatar-icon">👤</span>
							</div>
						{/if}
					</div>
					<div class="user-details">
						<h3>{user?.username || 'Unknown User'}</h3>
						<p class="current-role">
							Current Role: <span class="role-badge">{user?.role_name || 'No Role'}</span>
						</p>
						<p class="user-status">Status: {user?.status || 'Unknown'}</p>
					</div>
				</div>
			</div>

			<!-- Role Selection -->
			<div class="form-section">
				<h2 class="section-title">Select Role</h2>
				
				<div class="role-selection">
					{#each availableRoles as role}
						<label class="role-option" class:selected={selectedRoleId === role.id}>
							<input
								type="radio"
								name="role"
								value={role.id}
								bind:group={selectedRoleId}
								class="role-radio"
							>
							<div class="role-card">
								<div class="role-header">
									<h3 class="role-name">{role.name}</h3>
									<span class="role-level">Level {role.level}</span>
								</div>
								<p class="role-description">{role.description}</p>
								<div class="role-meta">
									<span class="role-category">{role.category}</span>
									<span class="role-code">{role.code}</span>
								</div>
							</div>
						</label>
					{/each}
				</div>

				{#if errors.role}
					<span class="error-message">{errors.role}</span>
				{/if}
			</div>

			<!-- Permission Presets -->
			{#if selectedRole}
				<div class="form-section">
					<div class="section-header">
						<h2 class="section-title">Permission Presets</h2>
						<button type="button" class="advanced-toggle" on:click={() => showAdvanced = !showAdvanced}>
							{showAdvanced ? '🔧 Hide Advanced' : '⚡ Quick Setup'}
						</button>
					</div>

					<div class="preset-buttons">
						<button type="button" class="preset-btn" on:click={() => selectPreset('minimal')}>
							📋 Minimal Access
						</button>
						<button type="button" class="preset-btn" on:click={() => selectPreset('standard')}>
							🎯 Standard User
						</button>
						<button type="button" class="preset-btn" on:click={() => selectPreset('manager')}>
							👔 Manager Level
						</button>
						<button type="button" class="preset-btn" on:click={() => selectPreset('admin')}>
							⚙️ Admin Level
						</button>
					</div>
				</div>
			{/if}

			<!-- Detailed Permissions -->
			{#if selectedRole && showAdvanced}
				<div class="form-section">
					<div class="section-header">
						<h2 class="section-title">Detailed Permissions</h2>
						<div class="permission-controls">
							<div class="search-box">
								<input
									type="text"
									placeholder="Search permissions..."
									bind:value={searchTerm}
									class="search-input"
								>
								<span class="search-icon">🔍</span>
							</div>
							<select bind:value={selectedCategory} class="category-filter">
								{#each categories as category}
									<option value={category}>
										{category === 'all' ? 'All Categories' : category}
									</option>
								{/each}
							</select>
						</div>
					</div>

					<div class="permissions-grid">
						{#each filteredPermissions as category}
							<div class="permission-category">
								<h3 class="category-title">{category.category}</h3>
								<div class="permission-items">
									{#each category.items as permission}
										{@const status = getPermissionStatus(permission.id)}
										<label class="permission-item" class:inherited={status === 'inherited'} class:custom={status === 'custom'} class:both={status === 'both'}>
											<div class="permission-check">
												<input
													type="checkbox"
													checked={status === 'custom' || status === 'both'}
													on:change={() => toggleCustomPermission(permission.id)}
													disabled={status === 'inherited'}
													class="permission-checkbox"
												>
												<div class="permission-status">
													{#if status === 'inherited'}
														<span class="status-badge inherited">Inherited</span>
													{:else if status === 'custom'}
														<span class="status-badge custom">Custom</span>
													{:else if status === 'both'}
														<span class="status-badge both">Both</span>
													{/if}
												</div>
											</div>
											<div class="permission-details">
												<h4 class="permission-name">{permission.name}</h4>
												<p class="permission-description">{permission.description}</p>
											</div>
										</label>
									{/each}
								</div>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<!-- Summary -->
			{#if selectedRole}
				<div class="form-section">
					<h2 class="section-title">Assignment Summary</h2>
					
					<div class="assignment-summary">
						<div class="summary-card">
							<h3>Selected Role</h3>
							<div class="summary-role">
								<span class="role-name">{selectedRole.name}</span>
								<span class="role-level">Level {selectedRole.level}</span>
							</div>
							<p class="role-description">{selectedRole.description}</p>
						</div>

						<div class="summary-card">
							<h3>Permission Count</h3>
							<div class="permission-counts">
								<div class="count-item">
									<span class="count">{inheritedPermissions.size}</span>
									<span class="label">Inherited</span>
								</div>
								<div class="count-item">
									<span class="count">{customPermissions.size}</span>
									<span class="label">Custom</span>
								</div>
								<div class="count-item">
									<span class="count">{inheritedPermissions.size + customPermissions.size}</span>
									<span class="label">Total</span>
								</div>
							</div>
						</div>
					</div>
				</div>
			{/if}

			<!-- Messages -->
			{#if errors.submit}
				<div class="error-banner">
					<strong>Error:</strong> {errors.submit}
				</div>
			{/if}

			{#if successMessage}
				<div class="success-banner">
					<strong>Success:</strong> {successMessage}
				</div>
			{/if}

			<!-- Form Actions -->
			<div class="form-actions">
				<button type="button" class="cancel-btn" on:click={handleClose} disabled={isLoading}>
					Cancel
				</button>
				<button 
					type="submit" 
					class="submit-btn" 
					disabled={isLoading || !selectedRoleId}
				>
					{#if isLoading}
						<span class="spinner"></span>
						Assigning Role...
					{:else}
						<span class="icon">🎭</span>
						Assign Role & Permissions
					{/if}
				</button>
			</div>
		</form>
	{/if}
</div>

<style>
	.assign-roles {
		height: 100%;
		background: #f8fafc;
		overflow-y: auto;
		padding: 24px;
	}

	.header {
		text-align: center;
		margin-bottom: 32px;
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

	.permission-error {
		max-width: 400px;
		margin: 0 auto;
		background: white;
		border-radius: 12px;
		padding: 32px;
		text-align: center;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.permission-error h2 {
		color: #ef4444;
		margin-bottom: 16px;
	}

	.permission-error p {
		color: #6b7280;
		margin-bottom: 24px;
	}

	.close-btn {
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 12px 24px;
		font-weight: 500;
		cursor: pointer;
	}

	.assignment-form {
		max-width: 1000px;
		margin: 0 auto;
		background: white;
		border-radius: 12px;
		padding: 32px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.user-info {
		margin-bottom: 32px;
	}

	.user-card {
		display: flex;
		align-items: center;
		gap: 16px;
		padding: 20px;
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.user-avatar {
		width: 64px;
		height: 64px;
		flex-shrink: 0;
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
		font-size: 24px;
	}

	.user-details h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.current-role, .user-status {
		font-size: 14px;
		color: #6b7280;
		margin: 4px 0;
	}

	.role-badge {
		background: #3b82f6;
		color: white;
		padding: 2px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
	}

	.form-section {
		margin-bottom: 32px;
		padding-bottom: 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.form-section:last-of-type {
		border-bottom: none;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
	}

	.section-title {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 20px 0;
	}

	.advanced-toggle {
		background: #f3f4f6;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.advanced-toggle:hover {
		background: #e5e7eb;
	}

	.role-selection {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 16px;
	}

	.role-option {
		cursor: pointer;
		display: block;
	}

	.role-option.selected .role-card {
		border-color: #3b82f6;
		background: #eff6ff;
		transform: scale(1.02);
	}

	.role-radio {
		display: none;
	}

	.role-card {
		background: white;
		border: 2px solid #e5e7eb;
		border-radius: 8px;
		padding: 20px;
		transition: all 0.2s;
	}

	.role-card:hover {
		border-color: #d1d5db;
		transform: translateY(-1px);
	}

	.role-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 8px;
	}

	.role-name {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.role-level {
		background: #f3f4f6;
		color: #374151;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
	}

	.role-description {
		color: #6b7280;
		font-size: 14px;
		margin: 0 0 12px 0;
		line-height: 1.4;
	}

	.role-meta {
		display: flex;
		gap: 12px;
	}

	.role-category {
		background: #e0f2fe;
		color: #0891b2;
		padding: 2px 6px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		text-transform: capitalize;
	}

	.role-code {
		background: #fef3c7;
		color: #d97706;
		padding: 2px 6px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		font-family: monospace;
	}

	.preset-buttons {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.preset-btn {
		background: #f9fafb;
		color: #374151;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		padding: 12px 16px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		text-align: left;
	}

	.preset-btn:hover {
		background: #f3f4f6;
		border-color: #9ca3af;
	}

	.permission-controls {
		display: flex;
		gap: 16px;
		align-items: center;
	}

	.search-box {
		position: relative;
		flex: 1;
		max-width: 300px;
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

	.category-filter {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.permissions-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
		gap: 24px;
	}

	.permission-category {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 20px;
	}

	.category-title {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 16px 0;
	}

	.permission-items {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.permission-item {
		display: flex;
		gap: 12px;
		padding: 12px;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.permission-item:hover {
		border-color: #d1d5db;
	}

	.permission-item.inherited {
		background: #f0fdf4;
		border-color: #bbf7d0;
	}

	.permission-item.custom {
		background: #eff6ff;
		border-color: #bfdbfe;
	}

	.permission-item.both {
		background: #fefce8;
		border-color: #fde68a;
	}

	.permission-check {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
	}

	.permission-checkbox {
		width: 16px;
		height: 16px;
	}

	.permission-checkbox:disabled {
		opacity: 0.5;
	}

	.status-badge {
		font-size: 10px;
		font-weight: 500;
		padding: 2px 6px;
		border-radius: 4px;
		text-transform: uppercase;
	}

	.status-badge.inherited {
		background: #dcfce7;
		color: #166534;
	}

	.status-badge.custom {
		background: #dbeafe;
		color: #1d4ed8;
	}

	.status-badge.both {
		background: #fef3c7;
		color: #92400e;
	}

	.permission-details {
		flex: 1;
	}

	.permission-name {
		font-size: 14px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 4px 0;
	}

	.permission-description {
		font-size: 12px;
		color: #6b7280;
		margin: 0;
		line-height: 1.4;
	}

	.assignment-summary {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 24px;
	}

	.summary-card {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 20px;
	}

	.summary-card h3 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 12px 0;
	}

	.summary-role {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 8px;
	}

	.summary-role .role-name {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
	}

	.summary-role .role-level {
		background: #3b82f6;
		color: white;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
	}

	.permission-counts {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 16px;
	}

	.count-item {
		text-align: center;
	}

	.count-item .count {
		display: block;
		font-size: 24px;
		font-weight: 700;
		color: #111827;
	}

	.count-item .label {
		font-size: 12px;
		color: #6b7280;
		text-transform: uppercase;
		font-weight: 500;
	}

	/* Messages */
	.error-banner, .success-banner {
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 24px;
		font-size: 14px;
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

	.error-message {
		color: #ef4444;
		font-size: 12px;
		margin-top: 8px;
		display: block;
	}

	/* Form Actions */
	.form-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		padding-top: 24px;
		border-top: 1px solid #e5e7eb;
	}

	.cancel-btn, .submit-btn {
		padding: 12px 24px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.cancel-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.submit-btn {
		background: #8b5cf6;
		color: white;
		border-color: #8b5cf6;
	}

	.submit-btn:hover:not(:disabled) {
		background: #7c3aed;
		transform: translateY(-1px);
	}

	.submit-btn:disabled, .cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.icon {
		font-size: 16px;
	}

	@media (max-width: 768px) {
		.role-selection {
			grid-template-columns: 1fr;
		}

		.preset-buttons {
			grid-template-columns: 1fr;
		}

		.permission-controls {
			flex-direction: column;
			align-items: stretch;
		}

		.search-box {
			max-width: none;
		}

		.permissions-grid {
			grid-template-columns: 1fr;
		}

		.assignment-summary {
			grid-template-columns: 1fr;
		}

		.form-actions {
			flex-direction: column-reverse;
		}
	}
</style>