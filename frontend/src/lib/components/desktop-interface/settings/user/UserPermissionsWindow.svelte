<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { t } from '$lib/i18n';

	interface User {
		id: string;
		username: string;
		role_type: string;
		employee_name: string;
		branch_name: string;
		branch_id: string;
		status: string;
	}

	interface FunctionWithPermissions {
		function_code: string;
		function_name: string;
		category: string;
		can_view: boolean;
		can_add: boolean;
		can_edit: boolean;
		can_delete: boolean;
		can_export: boolean;
	}

	// State
	let users: User[] = [];
	let branches: Array<{id: string, name: string}> = [];
	let selectedBranch: string = '';
	let selectedUserId: string = '';
	let selectedUser: User | null = null;
	let functionPermissions: FunctionWithPermissions[] = [];
	let loading = false;
	let saving = false;
	let error = '';
	let successMessage = '';
	let searchQuery = '';

	$: filteredUsers = users.filter(u => {
		const matchesSearch = u.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
			u.employee_name.toLowerCase().includes(searchQuery.toLowerCase());
		const matchesBranch = selectedBranch === '' || u.branch_id === selectedBranch;
		return matchesSearch && matchesBranch;
	});

	onMount(async () => {
		await loadBranches();
		await loadUsers();
	});

	async function loadBranches() {
		try {
			const { data, error: err } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (err) throw err;
			branches = (data || []).map((b: any) => ({
				id: b.id.toString(),
				name: b.name_en || b.name_ar || 'Unknown Branch'
			}));
		} catch (err) {
			console.error('Failed to load branches:', err);
		}
	}

	async function loadUsers() {
		try {
			loading = true;
			const { data, error: err } = await supabase
				.from('users')
				.select(`
					id,
					username,
					role_type,
					branch_id,
					status
				`)
				.order('username');

			if (err) throw err;
			
			// If no branches from DB, extract unique branch_ids from users
			if (branches.length === 0 && data && data.length > 0) {
				const uniqueBranchIds = new Set<any>();
				data.forEach((u: any) => {
					if (u.branch_id) {
						uniqueBranchIds.add(u.branch_id);
					}
				});
				
				// Create synthetic branch objects
				branches = Array.from(uniqueBranchIds).map((id: any) => ({
					id: id.toString(),
					name: `Branch ${id}`
				}));
			}
			
			// Build lookup map of branch IDs to names
			const branchMap = new Map(branches.map(b => [b.id, b.name]));
			
			users = (data || []).map((u: any) => ({
				id: u.id,
				username: u.username,
				role_type: u.role_type,
				branch_id: u.branch_id ? u.branch_id.toString() : '',
				employee_name: u.username,
				branch_name: u.branch_id ? (branchMap.get(u.branch_id.toString()) || `Branch ${u.branch_id}`) : 'No Branch',
				status: u.status || 'active'
			}));
		} catch (err) {
			error = 'Failed to load users: ' + (err instanceof Error ? err.message : 'Unknown error');
		} finally {
			loading = false;
		}
	}

	async function selectUser(userId: string) {
		try {
			loading = true;
			error = '';
			successMessage = '';
			selectedUserId = userId;
			selectedUser = users.find(u => u.id === userId) || null;

			if (!selectedUser) return;

			// Get all active functions
			const { data: functions, error: funcErr } = await supabase
				.from('app_functions')
				.select('id, function_code, function_name, category, is_active')
				.eq('is_active', true)
				.order('category');

			if (funcErr) throw funcErr;

			// Find the role_id by matching role_type to user_roles
			// Convert role_type "Master Admin" to "MASTER_ADMIN" format
			const roleCodeFromType = selectedUser.role_type
				.toUpperCase()
				.replace(/\s+/g, '_')
				.replace(/[&()]/g, '');

			// Try to find role_id - use maybeSingle() to handle 404 gracefully
			const { data: roleData, error: roleErr } = await supabase
				.from('user_roles')
				.select('id')
				.eq('role_code', roleCodeFromType)
				.maybeSingle();

			// If role not found or has no permissions configured, show default (no permissions)
			if (!roleData) {
				functionPermissions = (functions || []).map(f => ({
					function_code: f.function_code,
					function_name: f.function_name,
					category: f.category,
					can_view: false,
					can_add: false,
					can_edit: false,
					can_delete: false,
					can_export: false
				}));
				error = `Note: Role "${selectedUser.role_type}" has no specific permissions configured yet. Showing all functions with no permissions.`;
				return;
			}

			// Get role permissions based on role_id
			const { data: rolePerms, error: permErr } = await supabase
				.from('role_permissions')
				.select('function_id, can_view, can_add, can_edit, can_delete, can_export')
				.eq('role_id', roleData.id);

			if (permErr && permErr.code !== 'PGRST116') {
				throw permErr;
			}

			// Build permissions map
			const permMap = new Map();
			if (rolePerms) {
				rolePerms.forEach((p: any) => {
					permMap.set(p.function_id, {
						can_view: p.can_view,
						can_add: p.can_add,
						can_edit: p.can_edit,
						can_delete: p.can_delete,
						can_export: p.can_export
					});
				});
			}

			// Build function permissions with values from role
			functionPermissions = (functions || []).map(f => {
				const rolePerm = permMap.get(f.id) || {
					can_view: false,
					can_add: false,
					can_edit: false,
					can_delete: false,
					can_export: false
				};
				return {
					function_code: f.function_code,
					function_name: f.function_name,
					category: f.category,
					can_view: rolePerm.can_view,
					can_add: rolePerm.can_add,
					can_edit: rolePerm.can_edit,
					can_delete: rolePerm.can_delete,
					can_export: rolePerm.can_export
				};
			});
		} catch (err) {
			error = 'Failed to load permissions: ' + (err instanceof Error ? err.message : 'Unknown error');
		} finally {
			loading = false;
		}
	}

	function updatePermission(functionCode: string, action: string, value: boolean) {
		const perm = functionPermissions.find(p => p.function_code === functionCode);
		if (perm) {
			perm[action as keyof FunctionWithPermissions] = value as never;
			functionPermissions = functionPermissions;
		}
	}

	async function savePermissions() {
		if (!selectedUserId || !selectedUser) return;

		try {
			saving = true;
			error = '';
			successMessage = '';

			// Find the role_id by matching role_type to user_roles
			const roleCodeFromType = selectedUser.role_type
				.toUpperCase()
				.replace(/\s+/g, '_')
				.replace(/[&()]/g, '');

			const { data: roleData, error: roleErr } = await supabase
				.from('user_roles')
				.select('id')
				.eq('role_code', roleCodeFromType)
				.maybeSingle();

			if (!roleData) {
				error = `Cannot save permissions: Role "${selectedUser.role_type}" does not exist in system.`;
				return;
			}

			// Get all function IDs
			const { data: functions, error: funcErr } = await supabase
				.from('app_functions')
				.select('id, function_code');

			if (funcErr) throw funcErr;

			const functionMap = new Map(functions.map((f: any) => [f.function_code, f.id]));

			// Delete existing role permissions for this role
			await supabase
				.from('role_permissions')
				.delete()
				.eq('role_id', roleData.id);

			// Build permissions to insert
			const permissionsToInsert = functionPermissions
				.filter(p => p.can_view || p.can_add || p.can_edit || p.can_delete || p.can_export)
				.map(p => ({
					role_id: roleData.id,
					function_id: functionMap.get(p.function_code),
					can_view: p.can_view,
					can_add: p.can_add,
					can_edit: p.can_edit,
					can_delete: p.can_delete,
					can_export: p.can_export
				}));

			if (permissionsToInsert.length > 0) {
				const { error: insertErr } = await supabase
					.from('role_permissions')
					.insert(permissionsToInsert);

				if (insertErr) throw insertErr;
			}

			successMessage = `✅ Permissions saved for ${selectedUser?.username}`;
			setTimeout(() => { successMessage = ''; }, 3000);
		} catch (err) {
			error = '❌ Failed to save: ' + (err instanceof Error ? err.message : 'Unknown error');
		} finally {
			saving = false;
		}
	}

	function selectAllForCategory(category: string) {
		functionPermissions = functionPermissions.map(p => {
			if (p.category === category) {
				return {
					...p,
					can_view: true,
					can_add: true,
					can_edit: true,
					can_delete: false,
					can_export: true
				};
			}
			return p;
		});
	}

	function deselectAllForCategory(category: string) {
		functionPermissions = functionPermissions.map(p => {
			if (p.category === category) {
				return {
					...p,
					can_view: false,
					can_add: false,
					can_edit: false,
					can_delete: false,
					can_export: false
				};
			}
			return p;
		});
	}

	function selectAll() {
		functionPermissions = functionPermissions.map(p => ({
			...p,
			can_view: true,
			can_add: true,
			can_edit: true,
			can_delete: false,
			can_export: true
		}));
	}

	function deselectAll() {
		functionPermissions = functionPermissions.map(p => ({
			...p,
			can_view: false,
			can_add: false,
			can_edit: false,
			can_delete: false,
			can_export: false
		}));
	}

	$: isMasterAdmin = $currentUser?.isMasterAdmin;
</script>

{#if !isMasterAdmin}
	<div class="access-denied">
		<div class="denied-icon">🔐</div>
		<h2>Access Denied</h2>
		<p>Only Master Admin users can manage user permissions.</p>
	</div>
{:else}
	<div class="permission-manager">
		<!-- Left Panel: Users List -->
		<div class="users-panel">
			<h2>Users</h2>

			<div class="filters-section">
				<div class="branch-filter">
					<label>Branch:</label>
					<select bind:value={selectedBranch} class="branch-select">
						<option value="">All Branches</option>
						{#each branches as branch (branch.id)}
							<option value={branch.id}>{branch.name}</option>
						{/each}
					</select>
				</div>
			</div>

			<div class="search-box">
				<input
					type="text"
					placeholder="Search users..."
					bind:value={searchQuery}
					class="search-input"
				/>
			</div>

			<div class="users-list">
				{#if loading}
					<div class="loading">Loading users...</div>
				{:else if filteredUsers.length === 0}
					<div class="empty-state">No users found</div>
				{:else}
					{#each filteredUsers as user (user.id)}
						<button
							class="user-item"
							class:active={selectedUserId === user.id}
							on:click={() => selectUser(user.id)}
						>
							<div class="user-name">{user.username}</div>
							<div class="user-meta">
								<span class="user-role">{user.role_type}</span>
								<span class="user-branch">{user.branch_name}</span>
							</div>
							<div class="user-status" class:active={user.status === 'active'}>
								{user.status}
							</div>
						</button>
					{/each}
				{/if}
			</div>
		</div>

		<!-- Right Panel: Permissions -->
		<div class="permissions-panel">
			{#if !selectedUser}
				<div class="no-selection">
					<div class="icon">👤</div>
					<p>Select a user to manage their permissions</p>
				</div>
			{:else}
				<!-- User Info Header -->
				<div class="user-header">
					<div class="user-info">
						<h2>{selectedUser.username}</h2>
						<p>{selectedUser.employee_name}</p>
						<p class="meta">{selectedUser.branch_name} • {selectedUser.role_type}</p>
					</div>
				</div>

				<!-- Messages -->
				{#if error}
					<div class="error-message">{error}</div>
				{/if}
				{#if successMessage}
					<div class="success-message">{successMessage}</div>
				{/if}

				<!-- Bulk Actions -->
				<div class="bulk-actions">
					<button class="action-btn" on:click={selectAll}>
						✓ Select All
					</button>
					<button class="action-btn" on:click={deselectAll}>
						✗ Deselect All
					</button>
				</div>

				<!-- Functions & Permissions -->
				<div class="functions-section">
					{#if loading}
						<div class="loading">Loading permissions...</div>
					{:else if functionPermissions.length === 0}
						<div class="empty-state">No functions available</div>
					{:else}
						{#each [...new Set(functionPermissions.map(p => p.category))].sort() as category}
							<div class="category-group">
								<div class="category-header">
									<h3>{category}</h3>
									<div class="category-actions">
										<button
											class="category-action-btn"
											on:click={() => selectAllForCategory(category)}
										>
											Select All
										</button>
										<button
											class="category-action-btn"
											on:click={() => deselectAllForCategory(category)}
										>
											Deselect All
										</button>
									</div>
								</div>

								<div class="functions-table">
									<div class="table-header">
										<div class="col-name">Function</div>
										<div class="col-permissions">
											<span>View</span>
											<span>Create</span>
											<span>Edit</span>
											<span>Delete</span>
											<span>Export</span>
										</div>
									</div>

									{#each functionPermissions.filter(p => p.category === category) as perm (perm.function_code)}
										<div class="table-row">
											<div class="col-name">
												<div class="function-name">{perm.function_name}</div>
												<div class="function-code">{perm.function_code}</div>
											</div>
											<div class="col-permissions">
												<label class="permission-checkbox">
													<input
														type="checkbox"
														checked={perm.can_view}
														on:change={(e) => updatePermission(perm.function_code, 'can_view', e.currentTarget.checked)}
													/>
													<span class="checkmark"></span>
												</label>
												<label class="permission-checkbox">
													<input
														type="checkbox"
														checked={perm.can_add}
														on:change={(e) => updatePermission(perm.function_code, 'can_add', e.currentTarget.checked)}
													/>
													<span class="checkmark"></span>
												</label>
												<label class="permission-checkbox">
													<input
														type="checkbox"
														checked={perm.can_edit}
														on:change={(e) => updatePermission(perm.function_code, 'can_edit', e.currentTarget.checked)}
													/>
													<span class="checkmark"></span>
												</label>
												<label class="permission-checkbox">
													<input
														type="checkbox"
														checked={perm.can_delete}
														on:change={(e) => updatePermission(perm.function_code, 'can_delete', e.currentTarget.checked)}
													/>
													<span class="checkmark"></span>
												</label>
												<label class="permission-checkbox">
													<input
														type="checkbox"
														checked={perm.can_export}
														on:change={(e) => updatePermission(perm.function_code, 'can_export', e.currentTarget.checked)}
													/>
													<span class="checkmark"></span>
												</label>
											</div>
										</div>
									{/each}
								</div>
							</div>
						{/each}
					{/if}
				</div>

				<!-- Save Button -->
				<div class="save-section">
					<button
						class="save-btn"
						on:click={savePermissions}
						disabled={saving}
					>
						{#if saving}
							Saving...
						{:else}
							💾 Save Permissions
						{/if}
					</button>
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	.access-denied {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		gap: 1rem;
		color: #6b7280;
	}

	.denied-icon {
		font-size: 3rem;
		opacity: 0.5;
	}

	.denied-icon + h2 {
		color: #374151;
		margin: 0;
	}

	.permission-manager {
		display: grid;
		grid-template-columns: 300px 1fr;
		gap: 1.5rem;
		height: 100%;
		padding: 1.5rem;
		background: white;
		overflow: hidden;
	}

	/* Users Panel */
	.users-panel {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 10px;
		padding: 1.5rem;
		min-height: 0;
	}

	.users-panel h2 {
		margin: 0;
		font-size: 1.1rem;
		color: #1f2937;
	}

	.search-box {
		display: flex;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 0.9rem;
		transition: border-color 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.filters-section {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.branch-filter {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.branch-filter label {
		font-size: 0.85rem;
		font-weight: 600;
		color: #4b5563;
	}

	.branch-select {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 0.9rem;
		background: white;
		cursor: pointer;
		transition: border-color 0.2s;
	}

	.branch-select:hover {
		border-color: #9ca3af;
	}

	.branch-select:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.users-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		overflow-y: auto;
		flex: 1;
		min-height: 0;
	}

	.user-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		padding: 0.75rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s;
		text-align: left;
	}

	.user-item:hover {
		background: #f3f4f6;
		border-color: #d1d5db;
	}

	.user-item.active {
		background: linear-gradient(135deg, #667eea15 0%, #764ba215 100%);
		border-color: #667eea;
	}

	.user-name {
		font-weight: 600;
		color: #1f2937;
		font-size: 0.95rem;
	}

	.user-meta {
		display: flex;
		gap: 0.5rem;
		font-size: 0.75rem;
		color: #6b7280;
	}

	.user-role {
		background: #dbeafe;
		color: #1e40af;
		padding: 0.125rem 0.5rem;
		border-radius: 4px;
	}

	.user-branch {
		color: #6b7280;
	}

	.user-status {
		font-size: 0.75rem;
		color: #d97706;
		text-transform: capitalize;
	}

	.user-status.active {
		color: #059669;
	}

	.loading,
	.empty-state {
		text-align: center;
		color: #6b7280;
		padding: 2rem 1rem;
	}

	/* Permissions Panel */
	.permissions-panel {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 10px;
		padding: 1.5rem;
		min-height: 0;
		overflow-y: auto;
	}

	.no-selection {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 300px;
		color: #9ca3af;
		gap: 1rem;
	}

	.no-selection .icon {
		font-size: 3rem;
		opacity: 0.3;
	}

	.user-header {
		border-bottom: 1px solid #e5e7eb;
		padding-bottom: 1.5rem;
	}

	.user-info h2 {
		margin: 0 0 0.25rem 0;
		color: #1f2937;
		font-size: 1.5rem;
	}

	.user-info p {
		margin: 0;
		color: #6b7280;
		font-size: 0.9rem;
	}

	.user-info .meta {
		margin-top: 0.5rem;
		font-size: 0.85rem;
		color: #9ca3af;
	}

	.error-message {
		padding: 1rem;
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #fecaca;
		border-radius: 8px;
		font-size: 0.9rem;
	}

	.success-message {
		padding: 1rem;
		background: #dcfce7;
		color: #166534;
		border: 1px solid #bbf7d0;
		border-radius: 8px;
		font-size: 0.9rem;
	}

	.bulk-actions {
		display: flex;
		gap: 0.5rem;
	}

	.action-btn {
		padding: 0.5rem 1rem;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		transition: all 0.2s;
	}

	.action-btn:hover {
		background: #e5e7eb;
		border-color: #9ca3af;
	}

	.functions-section {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		min-height: 0;
		overflow-y: auto;
	}

	.category-group {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.category-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 0.75rem;
		border-bottom: 2px solid #f3f4f6;
	}

	.category-header h3 {
		margin: 0;
		color: #374151;
		font-size: 1rem;
		font-weight: 600;
	}

	.category-actions {
		display: flex;
		gap: 0.5rem;
	}

	.category-action-btn {
		padding: 0.375rem 0.75rem;
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.8rem;
		transition: all 0.2s;
	}

	.category-action-btn:hover {
		background: #f3f4f6;
		border-color: #d1d5db;
	}

	.functions-table {
		display: flex;
		flex-direction: column;
		gap: 0;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
	}

	.table-header {
		display: grid;
		grid-template-columns: 1fr 300px;
		gap: 0;
		padding: 0.75rem 1rem;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
		font-weight: 600;
		font-size: 0.85rem;
		color: #6b7280;
	}

	.col-name {
		display: flex;
		align-items: center;
	}

	.col-permissions {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 0.5rem;
		text-align: center;
	}

	.table-row {
		display: grid;
		grid-template-columns: 1fr 300px;
		gap: 0;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #f3f4f6;
		align-items: center;
		transition: background 0.2s;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.table-row:last-child {
		border-bottom: none;
	}

	.function-name {
		font-weight: 500;
		color: #1f2937;
		font-size: 0.95rem;
	}

	.function-code {
		font-size: 0.8rem;
		color: #9ca3af;
		font-family: monospace;
		margin-top: 0.125rem;
	}

	.permission-checkbox {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		position: relative;
		width: 24px;
		height: 24px;
	}

	.permission-checkbox input {
		opacity: 0;
		width: 100%;
		height: 100%;
		cursor: pointer;
		position: absolute;
	}

	.permission-checkbox .checkmark {
		width: 20px;
		height: 20px;
		border: 2px solid #d1d5db;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
		background: white;
	}

	.permission-checkbox input:checked ~ .checkmark {
		background: #667eea;
		border-color: #667eea;
		color: white;
		font-size: 0.75rem;
	}

	.permission-checkbox input:checked ~ .checkmark::after {
		content: '✓';
		color: white;
		font-weight: bold;
		font-size: 0.75rem;
	}

	.save-section {
		display: flex;
		justify-content: flex-end;
		padding-top: 1rem;
		border-top: 1px solid #e5e7eb;
	}

	.save-btn {
		padding: 0.75rem 1.5rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: transform 0.2s, box-shadow 0.2s;
		font-size: 0.95rem;
	}

	.save-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 16px rgba(102, 126, 234, 0.3);
	}

	.save-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}

	@media (max-width: 1024px) {
		.permission-manager {
			grid-template-columns: 1fr;
		}

		.col-permissions {
			grid-template-columns: repeat(3, 1fr);
		}

		.category-actions {
			flex-direction: column;
		}
	}
</style>
