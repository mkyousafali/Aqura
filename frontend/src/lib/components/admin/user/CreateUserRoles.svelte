<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { userManagement } from '$lib/utils/userManagement';

	const dispatch = createEventDispatcher();

	// Form data
	let formData = {
		roleName: '',
		roleDescription: '',
		position: '',
		permissions: {}
	};

	// Available positions
	let positions = [
		{ id: 'cashier', name: 'Cashier' },
		{ id: 'supervisor', name: 'Supervisor' },
		{ id: 'inventory_manager', name: 'Inventory Manager' },
		{ id: 'branch_manager', name: 'Branch Manager' },
		{ id: 'accountant', name: 'Accountant' },
		{ id: 'hr_coordinator', name: 'HR Coordinator' },
		{ id: 'sales_representative', name: 'Sales Representative' },
		{ id: 'customer_service', name: 'Customer Service' },
		{ id: 'security_officer', name: 'Security Officer' },
		{ id: 'maintenance_staff', name: 'Maintenance Staff' }
	];

	// System functions/modules
	let systemFunctions = [
		{ id: 'user_management', name: 'User Management', description: 'Manage user accounts and permissions' },
		{ id: 'inventory_management', name: 'Inventory Management', description: 'Track and manage inventory items' },
		{ id: 'sales_transactions', name: 'Sales Transactions', description: 'Process sales and customer transactions' },
		{ id: 'financial_reports', name: 'Financial Reports', description: 'Access financial reports and analytics' },
		{ id: 'customer_management', name: 'Customer Management', description: 'Manage customer information and relationships' },
		{ id: 'supplier_management', name: 'Supplier Management', description: 'Manage supplier information and orders' },
		{ id: 'branch_operations', name: 'Branch Operations', description: 'Manage branch-specific operations' },
		{ id: 'hr_management', name: 'HR Management', description: 'Human resources management functions' },
		{ id: 'system_settings', name: 'System Settings', description: 'Configure system-wide settings' },
		{ id: 'audit_logs', name: 'Audit Logs', description: 'View system audit logs and activity' },
		{ id: 'backup_restore', name: 'Backup & Restore', description: 'Manage system backups and restoration' },
		{ id: 'master_data', name: 'Master Data', description: 'Manage master data and configurations' }
	];

	// Permission types
	let permissionTypes = [
		{ id: 'view', name: 'View', description: 'View and read data' },
		{ id: 'add', name: 'Add', description: 'Create new records' },
		{ id: 'edit', name: 'Edit', description: 'Modify existing records' },
		{ id: 'delete', name: 'Delete', description: 'Remove records' },
		{ id: 'export', name: 'Export', description: 'Export data to external formats' }
	];

	// State variables
	let isLoading = false;
	let errors: Record<string, string> = {};
	let successMessage = '';

	// Mock current user permissions - will be replaced with real authentication
	let currentUser = {
		role_type: 'Master Admin' // or 'Admin'
	};

	// Initialize permissions object
	function initializePermissions() {
		const permissions = {};
		systemFunctions.forEach(func => {
			permissions[func.id] = {
				view: false,
				add: false,
				edit: false,
				delete: false,
				export: false
			};
		});
		formData.permissions = permissions;
	}

	// Initialize permissions on component load
	initializePermissions();

	function validateForm() {
		errors = {};

		if (!formData.roleName.trim()) {
			errors.roleName = 'Role name is required';
		} else if (formData.roleName.length < 3) {
			errors.roleName = 'Role name must be at least 3 characters';
		}

		if (!formData.position) {
			errors.position = 'Position selection is required';
		}

		// Check if at least one permission is granted
		const hasAnyPermission = Object.values(formData.permissions).some(modulePerms =>
			Object.values(modulePerms as any).some(perm => perm === true)
		);

		if (!hasAnyPermission) {
			errors.permissions = 'At least one permission must be granted';
		}

		return Object.keys(errors).length === 0;
	}

	function togglePermission(functionId: string, permissionType: string) {
		if (!formData.permissions[functionId]) {
			formData.permissions[functionId] = {};
		}
		formData.permissions[functionId][permissionType] = !formData.permissions[functionId][permissionType];
		
		// Clear permission errors when permissions are granted
		if (formData.permissions[functionId][permissionType]) {
			delete errors.permissions;
		}
	}

	function selectAllForFunction(functionId: string) {
		if (!formData.permissions[functionId]) {
			formData.permissions[functionId] = {};
		}
		permissionTypes.forEach(perm => {
			formData.permissions[functionId][perm.id] = true;
		});
		delete errors.permissions;
	}

	function clearAllForFunction(functionId: string) {
		if (!formData.permissions[functionId]) {
			formData.permissions[functionId] = {};
		}
		permissionTypes.forEach(perm => {
			formData.permissions[functionId][perm.id] = false;
		});
	}

	function selectAllPermissions() {
		systemFunctions.forEach(func => {
			if (!formData.permissions[func.id]) {
				formData.permissions[func.id] = {};
			}
			permissionTypes.forEach(perm => {
				formData.permissions[func.id][perm.id] = true;
			});
		});
		delete errors.permissions;
	}

	function clearAllPermissions() {
		systemFunctions.forEach(func => {
			if (!formData.permissions[func.id]) {
				formData.permissions[func.id] = {};
			}
			permissionTypes.forEach(perm => {
				formData.permissions[func.id][perm.id] = false;
			});
		});
	}

	async function handleSubmit() {
		if (!validateForm()) return;

		isLoading = true;
		successMessage = '';
		errors = {};

		try {
			// Simulate API call - replace with actual API
			await new Promise(resolve => setTimeout(resolve, 1500));
			
			// Mock successful creation
			console.log('Creating role with data:', formData);
			
			successMessage = `User role "${formData.roleName}" created successfully!`;
			
			// Create audit log entry
			console.log('Audit Log: Role created', {
				action: 'create_user_role',
				role_name: formData.roleName,
				position: formData.position,
				created_by: currentUser.role_type,
				timestamp: new Date().toISOString(),
				permissions_count: Object.values(formData.permissions).reduce((count: number, modulePerms) => 
					count + Object.values(modulePerms as any).filter(perm => perm === true).length, 0
				)
			});

			// Reset form after successful creation
			setTimeout(() => {
				resetForm();
				successMessage = '';
			}, 3000);

		} catch (error) {
			console.error('Error creating role:', error);
			errors.submit = error.message || 'Failed to create user role';
		} finally {
			isLoading = false;
		}
	}

	function resetForm() {
		formData = {
			roleName: '',
			roleDescription: '',
			position: '',
			permissions: {}
		};
		initializePermissions();
		errors = {};
		successMessage = '';
	}

	function closeWindow() {
		dispatch('close');
	}

	// Check if user has permission to create roles
	$: canCreateRoles = currentUser.role_type === 'Master Admin' || currentUser.role_type === 'Admin';

	// Count selected permissions
	$: selectedPermissionsCount = Object.values(formData.permissions).reduce((count: number, modulePerms) => 
		count + Object.values(modulePerms as any).filter(perm => perm === true).length, 0
	);
</script>

<div class="create-user-roles">
	<!-- Header -->
	<div class="header">
		<div class="header-content">
			<div class="title-section">
				<h1 class="title">Create User Role</h1>
				<p class="subtitle">Define custom roles and permissions for different positions</p>
			</div>
			<button class="close-btn" on:click={closeWindow} title="Close Window">
				<span class="close-icon">✕</span>
			</button>
		</div>
	</div>

	{#if !canCreateRoles}
		<div class="access-denied">
			<div class="access-denied-content">
				<span class="access-denied-icon">🚫</span>
				<h2>Access Denied</h2>
				<p>Only Admins and Master Admins can create user roles.</p>
			</div>
		</div>
	{:else}
		<div class="content">
			<form on:submit|preventDefault={handleSubmit} class="role-form">
				<!-- Basic Information -->
				<div class="form-section">
					<h2 class="section-title">Role Information</h2>
					
					<div class="form-grid">
						<div class="form-group">
							<label for="role-name">Role Name *</label>
							<input
								type="text"
								id="role-name"
								bind:value={formData.roleName}
								placeholder="Enter role name (e.g., Store Manager)"
								class="form-input"
								class:error={errors.roleName}
								disabled={isLoading}
							>
							{#if errors.roleName}
								<span class="error-message">{errors.roleName}</span>
							{/if}
						</div>

						<div class="form-group">
							<label for="position">Position *</label>
							<select
								id="position"
								bind:value={formData.position}
								class="form-select"
								class:error={errors.position}
								disabled={isLoading}
							>
								<option value="">Select Position</option>
								{#each positions as position}
									<option value={position.id}>{position.name}</option>
								{/each}
							</select>
							{#if errors.position}
								<span class="error-message">{errors.position}</span>
							{/if}
						</div>
					</div>

					<div class="form-group">
						<label for="role-description">Role Description</label>
						<textarea
							id="role-description"
							bind:value={formData.roleDescription}
							placeholder="Optional description of the role and its responsibilities"
							class="form-textarea"
							rows="3"
							disabled={isLoading}
						></textarea>
					</div>
				</div>

				<!-- Permissions Matrix -->
				<div class="form-section">
					<div class="permissions-header">
						<h2 class="section-title">
							Permissions Matrix
							<span class="permission-count">({selectedPermissionsCount} permissions selected)</span>
						</h2>
						<div class="bulk-actions">
							<button
								type="button"
								class="bulk-btn select-all"
								on:click={selectAllPermissions}
								disabled={isLoading}
							>
								Select All
							</button>
							<button
								type="button"
								class="bulk-btn clear-all"
								on:click={clearAllPermissions}
								disabled={isLoading}
							>
								Clear All
							</button>
						</div>
					</div>

					{#if errors.permissions}
						<div class="error-banner">
							<span class="error-icon">⚠️</span>
							<span>{errors.permissions}</span>
						</div>
					{/if}

					<div class="permissions-table-container">
						<table class="permissions-table">
							<thead>
								<tr>
									<th class="function-col">System Function</th>
									{#each permissionTypes as permType}
										<th class="permission-col">
											<div class="permission-header">
												<span class="permission-name">{permType.name}</span>
												<span class="permission-desc">{permType.description}</span>
											</div>
										</th>
									{/each}
									<th class="actions-col">Actions</th>
								</tr>
							</thead>
							<tbody>
								{#each systemFunctions as func}
									<tr class="function-row">
										<td class="function-cell">
											<div class="function-info">
												<div class="function-name">{func.name}</div>
												<div class="function-desc">{func.description}</div>
											</div>
										</td>
										{#each permissionTypes as permType}
											<td class="permission-cell">
												<label class="permission-checkbox">
													<input
														type="checkbox"
														checked={formData.permissions[func.id]?.[permType.id] || false}
														on:change={() => togglePermission(func.id, permType.id)}
														disabled={isLoading}
													>
													<span class="checkmark"></span>
												</label>
											</td>
										{/each}
										<td class="actions-cell">
											<div class="row-actions">
												<button
													type="button"
													class="row-btn select-all"
													on:click={() => selectAllForFunction(func.id)}
													disabled={isLoading}
													title="Select all permissions for this function"
												>
													All
												</button>
												<button
													type="button"
													class="row-btn clear-all"
													on:click={() => clearAllForFunction(func.id)}
													disabled={isLoading}
													title="Clear all permissions for this function"
												>
													None
												</button>
											</div>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>

				<!-- Success Message -->
				{#if successMessage}
					<div class="success-banner">
						<span class="success-icon">✅</span>
						<div class="success-content">
							<strong>Success!</strong> {successMessage}
						</div>
					</div>
				{/if}

				<!-- Submit Error -->
				{#if errors.submit}
					<div class="error-banner">
						<span class="error-icon">❌</span>
						<div class="error-content">
							<strong>Error:</strong> {errors.submit}
						</div>
					</div>
				{/if}

				<!-- Form Actions -->
				<div class="form-actions">
					<button
						type="button"
						class="cancel-btn"
						on:click={resetForm}
						disabled={isLoading}
					>
						Reset Form
					</button>
					<button
						type="submit"
						class="submit-btn"
						disabled={isLoading}
					>
						{#if isLoading}
							<span class="loading-spinner"></span>
							Creating Role...
						{:else}
							Create Role
						{/if}
					</button>
				</div>
			</form>
		</div>
	{/if}
</div>

<style>
	.create-user-roles {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f8fafc;
	}

	.header {
		background: white;
		border-bottom: 1px solid #e2e8f0;
		padding: 20px 24px;
		flex-shrink: 0;
	}

	.header-content {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		max-width: 1200px;
		margin: 0 auto;
	}

	.title-section {
		flex: 1;
	}

	.title {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 4px 0;
	}

	.subtitle {
		font-size: 14px;
		color: #64748b;
		margin: 0;
	}

	.close-btn {
		background: #f1f5f9;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.2s;
		flex-shrink: 0;
	}

	.close-btn:hover {
		background: #e2e8f0;
		border-color: #cbd5e1;
	}

	.close-icon {
		font-size: 14px;
		color: #64748b;
	}

	.access-denied {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 40px;
	}

	.access-denied-content {
		text-align: center;
		padding: 40px;
		background: white;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
	}

	.access-denied-icon {
		font-size: 48px;
		display: block;
		margin-bottom: 16px;
	}

	.access-denied-content h2 {
		font-size: 20px;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 8px 0;
	}

	.access-denied-content p {
		color: #64748b;
		margin: 0;
	}

	.content {
		flex: 1;
		overflow-y: auto;
		padding: 24px;
	}

	.role-form {
		max-width: 1200px;
		margin: 0 auto;
	}

	.form-section {
		background: white;
		border-radius: 8px;
		padding: 24px;
		margin-bottom: 24px;
		border: 1px solid #e2e8f0;
	}

	.section-title {
		font-size: 18px;
		font-weight: 600;
		color: #1e293b;
		margin: 0 0 20px 0;
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.permission-count {
		font-size: 14px;
		font-weight: 400;
		color: #6366f1;
		background: #eef2ff;
		padding: 2px 8px;
		border-radius: 4px;
	}

	.permissions-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
		flex-wrap: wrap;
		gap: 16px;
	}

	.bulk-actions {
		display: flex;
		gap: 8px;
	}

	.bulk-btn {
		padding: 8px 12px;
		font-size: 12px;
		font-weight: 500;
		border-radius: 6px;
		border: 1px solid;
		cursor: pointer;
		transition: all 0.2s;
	}

	.bulk-btn.select-all {
		background: #f0f9ff;
		color: #0369a1;
		border-color: #0ea5e9;
	}

	.bulk-btn.select-all:hover {
		background: #0ea5e9;
		color: white;
	}

	.bulk-btn.clear-all {
		background: #fef2f2;
		color: #dc2626;
		border-color: #f87171;
	}

	.bulk-btn.clear-all:hover {
		background: #dc2626;
		color: white;
	}

	.bulk-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group label {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.form-input,
	.form-select,
	.form-textarea {
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		transition: border-color 0.2s;
	}

	.form-input:focus,
	.form-select:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.form-input.error,
	.form-select.error {
		border-color: #ef4444;
	}

	.form-textarea {
		resize: vertical;
		min-height: 80px;
	}

	.error-message {
		font-size: 12px;
		color: #ef4444;
		margin-top: 4px;
	}

	.error-banner,
	.success-banner {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px;
		border-radius: 6px;
		margin-bottom: 20px;
		font-size: 14px;
	}

	.error-banner {
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
	}

	.success-banner {
		background: #f0fdf4;
		color: #166534;
		border: 1px solid #bbf7d0;
	}

	.permissions-table-container {
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		overflow: hidden;
	}

	.permissions-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.permissions-table th {
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		font-weight: 600;
		color: #374151;
		text-align: left;
	}

	.function-col {
		width: 250px;
		padding: 12px 16px;
	}

	.permission-col {
		width: 120px;
		padding: 12px 8px;
		text-align: center;
	}

	.actions-col {
		width: 100px;
		padding: 12px 8px;
		text-align: center;
	}

	.permission-header {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.permission-name {
		font-size: 13px;
		font-weight: 600;
	}

	.permission-desc {
		font-size: 11px;
		color: #64748b;
		font-weight: 400;
	}

	.function-row {
		border-bottom: 1px solid #f1f5f9;
	}

	.function-row:hover {
		background: #f9fafb;
	}

	.function-cell {
		padding: 16px;
	}

	.function-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.function-name {
		font-size: 14px;
		font-weight: 500;
		color: #1e293b;
	}

	.function-desc {
		font-size: 12px;
		color: #64748b;
	}

	.permission-cell {
		padding: 16px 8px;
		text-align: center;
	}

	.permission-checkbox {
		display: inline-block;
		position: relative;
		cursor: pointer;
	}

	.permission-checkbox input {
		opacity: 0;
		position: absolute;
		cursor: pointer;
	}

	.checkmark {
		display: inline-block;
		width: 18px;
		height: 18px;
		background: white;
		border: 2px solid #d1d5db;
		border-radius: 3px;
		position: relative;
		transition: all 0.2s;
	}

	.permission-checkbox:hover .checkmark {
		border-color: #6366f1;
	}

	.permission-checkbox input:checked + .checkmark {
		background: #6366f1;
		border-color: #6366f1;
	}

	.permission-checkbox input:checked + .checkmark:after {
		content: '';
		position: absolute;
		left: 5px;
		top: 1px;
		width: 6px;
		height: 10px;
		border: solid white;
		border-width: 0 2px 2px 0;
		transform: rotate(45deg);
	}

	.permission-checkbox input:disabled + .checkmark {
		background: #f3f4f6;
		border-color: #e5e7eb;
		cursor: not-allowed;
	}

	.actions-cell {
		padding: 16px 8px;
	}

	.row-actions {
		display: flex;
		gap: 4px;
		justify-content: center;
	}

	.row-btn {
		padding: 4px 8px;
		font-size: 11px;
		font-weight: 500;
		border-radius: 4px;
		border: 1px solid;
		cursor: pointer;
		transition: all 0.2s;
	}

	.row-btn.select-all {
		background: #eff6ff;
		color: #2563eb;
		border-color: #bfdbfe;
	}

	.row-btn.select-all:hover {
		background: #2563eb;
		color: white;
	}

	.row-btn.clear-all {
		background: #fef2f2;
		color: #dc2626;
		border-color: #fecaca;
	}

	.row-btn.clear-all:hover {
		background: #dc2626;
		color: white;
	}

	.row-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding-top: 24px;
		border-top: 1px solid #e2e8f0;
		margin-top: 24px;
	}

	.cancel-btn,
	.submit-btn {
		padding: 10px 20px;
		font-size: 14px;
		font-weight: 500;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.cancel-btn {
		background: white;
		color: #64748b;
		border: 1px solid #d1d5db;
	}

	.cancel-btn:hover {
		background: #f8fafc;
		border-color: #9ca3af;
	}

	.submit-btn {
		background: #6366f1;
		color: white;
		border: 1px solid #6366f1;
	}

	.submit-btn:hover {
		background: #5b5ad6;
	}

	.cancel-btn:disabled,
	.submit-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.loading-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid transparent;
		border-top: 2px solid currentColor;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@media (max-width: 768px) {
		.form-grid {
			grid-template-columns: 1fr;
		}

		.permissions-header {
			flex-direction: column;
			align-items: stretch;
		}

		.bulk-actions {
			justify-content: center;
		}

		.permissions-table-container {
			overflow-x: auto;
		}

		.function-col {
			width: 200px;
		}

		.permission-col {
			width: 80px;
		}
	}
</style>