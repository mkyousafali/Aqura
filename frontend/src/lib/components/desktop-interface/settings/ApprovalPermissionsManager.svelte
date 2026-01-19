<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { currentUser } from '$lib/utils/persistentAuth';

	let users: any[] = [];
	let loading = false;
	let saving = false;
	let searchQuery = '';
	let statusFilter = 'all'; // all, active, inactive
	let permissionFilter = 'all'; // all, with-permissions, without-permissions

	// Check if current user is master admin
	$: isMasterAdmin = $currentUser?.isMasterAdmin;

	onMount(async () => {
		if (!isMasterAdmin) {
			alert('🚫 Access Denied: Master Admin role required');
			return;
		}
		await loadUsersWithPermissions();
	});

	async function loadUsersWithPermissions() {
		try {
			loading = true;

			// Load users
			const { data: usersData, error: usersError } = await supabase
				.from('users')
				.select('id, username, status, employee_id')
				.order('username');

			if (usersError) throw usersError;

			// Load all employee names (simpler approach to avoid URL length issues)
			const employeeIds = usersData?.filter((u) => u.employee_id).map((u) => u.employee_id) || [];
			let employeeNames: any = {};

			if (employeeIds.length > 0) {
				// Use supabase to bypass RLS - note: column is 'name' not 'full_name'
				const { data: employeesData, error: empError } = await supabase
					.from('hr_employees')
					.select('id, name');

				if (!empError && employeesData) {
					// Filter to only the ones we need
					employeesData.forEach((emp) => {
						if (employeeIds.includes(emp.id)) {
							employeeNames[emp.id] = emp.name;
						}
					});
				}
			}

			// Load all approval permissions
			const { data: permissionsData, error: permError } = await supabase
				.from('approval_permissions')
				.select('*');

			if (permError && permError.code !== 'PGRST116') {
				throw permError;
			}

			// Merge users with their permissions and employee names
			users = (usersData || []).map((user) => {
				const userPerm = permissionsData?.find((p) => p.user_id === user.id);
				return {
					...user,
					employee_name: user.employee_id ? employeeNames[user.employee_id] : null,
					permissions: userPerm || {
						user_id: user.id,
						can_approve_requisitions: false,
						requisition_amount_limit: 0,
						can_approve_single_bill: false,
						single_bill_amount_limit: 0,
						can_approve_multiple_bill: false,
						multiple_bill_amount_limit: 0,
						can_approve_recurring_bill: false,
						recurring_bill_amount_limit: 0,
						can_approve_vendor_payments: false,
						vendor_payment_amount_limit: 0,
						can_approve_leave_requests: false,
						can_approve_purchase_vouchers: false,
						can_add_missing_punches: false,
						is_active: true
					}
				};
			});
		} catch (err: any) {
			console.error('Error loading users:', err);
			alert(`❌ Error loading users: ${err.message}`);
		} finally {
			loading = false;
		}
	}

	async function saveUserPermissions(user: any) {
		try {
			saving = true;

			const permissionData = {
				can_approve_requisitions: user.permissions.can_approve_requisitions === true,
				requisition_amount_limit: parseFloat(user.permissions.requisition_amount_limit) || 0,
				can_approve_single_bill: user.permissions.can_approve_single_bill === true,
				single_bill_amount_limit: parseFloat(user.permissions.single_bill_amount_limit) || 0,
				can_approve_multiple_bill: user.permissions.can_approve_multiple_bill === true,
				multiple_bill_amount_limit: parseFloat(user.permissions.multiple_bill_amount_limit) || 0,
				can_approve_recurring_bill: user.permissions.can_approve_recurring_bill === true,
				recurring_bill_amount_limit: parseFloat(user.permissions.recurring_bill_amount_limit) || 0,
				can_approve_vendor_payments: user.permissions.can_approve_vendor_payments === true,
				vendor_payment_amount_limit: parseFloat(user.permissions.vendor_payment_amount_limit) || 0,
				can_approve_leave_requests: user.permissions.can_approve_leave_requests === true,
				can_approve_purchase_vouchers: user.permissions.can_approve_purchase_vouchers === true,
				can_add_missing_punches: user.permissions.can_add_missing_punches === true,
				is_active: user.permissions.is_active === true
			};

			console.log('💾 Saving approval permissions for user:', {
				userId: user.id,
				username: user.username,
				permissionData: permissionData,
				originalValues: {
					can_approve_leave_requests: user.permissions.can_approve_leave_requests,
					can_approve_requisitions: user.permissions.can_approve_requisitions
				}
			});

			// Check if permission record exists
			const { data: existingPerm, error: checkError } = await supabase
				.from('approval_permissions')
				.select('id')
				.eq('user_id', user.id)
				.maybeSingle();

			if (checkError && checkError.code !== 'PGRST116') {
				console.error('❌ Error checking existing permissions:', checkError);
				throw checkError;
			}

			console.log('🔍 Existing permission record:', existingPerm ? 'YES - will UPDATE' : 'NO - will INSERT');

			let updateError;
			if (existingPerm) {
				// Update existing record
				console.log('↳ Executing UPDATE query...');
				const { error: err, data: updateData } = await supabase
					.from('approval_permissions')
					.update({
						can_approve_requisitions: permissionData.can_approve_requisitions,
						requisition_amount_limit: permissionData.requisition_amount_limit,
						can_approve_single_bill: permissionData.can_approve_single_bill,
						single_bill_amount_limit: permissionData.single_bill_amount_limit,
						can_approve_multiple_bill: permissionData.can_approve_multiple_bill,
						multiple_bill_amount_limit: permissionData.multiple_bill_amount_limit,
						can_approve_recurring_bill: permissionData.can_approve_recurring_bill,
						recurring_bill_amount_limit: permissionData.recurring_bill_amount_limit,
						can_approve_vendor_payments: permissionData.can_approve_vendor_payments,
						vendor_payment_amount_limit: permissionData.vendor_payment_amount_limit,
						can_approve_leave_requests: permissionData.can_approve_leave_requests,
						can_approve_purchase_vouchers: permissionData.can_approve_purchase_vouchers,
					can_add_missing_punches: permissionData.can_add_missing_punches,
						updated_by: $currentUser?.id
					})
					.eq('user_id', user.id);
				
				updateError = err;
				console.log('↳ UPDATE Result:', { error: err, data: updateData });
			} else {
				// Insert new record
				console.log('↳ Executing INSERT query...');
				const { error: err, data: insertData } = await supabase
					.from('approval_permissions')
					.insert([{
						user_id: user.id,
						can_approve_requisitions: permissionData.can_approve_requisitions,
						requisition_amount_limit: permissionData.requisition_amount_limit,
						can_approve_single_bill: permissionData.can_approve_single_bill,
						single_bill_amount_limit: permissionData.single_bill_amount_limit,
						can_approve_multiple_bill: permissionData.can_approve_multiple_bill,
						multiple_bill_amount_limit: permissionData.multiple_bill_amount_limit,
						can_approve_recurring_bill: permissionData.can_approve_recurring_bill,
						recurring_bill_amount_limit: permissionData.recurring_bill_amount_limit,
						can_approve_vendor_payments: permissionData.can_approve_vendor_payments,
						vendor_payment_amount_limit: permissionData.vendor_payment_amount_limit,
						can_approve_leave_requests: permissionData.can_approve_leave_requests,
						can_approve_purchase_vouchers: permissionData.can_approve_purchase_vouchers,
					can_add_missing_punches: permissionData.can_add_missing_punches,
						updated_at: new Date().toISOString(),
						created_by: $currentUser?.id,
						updated_by: $currentUser?.id
					}]);
				
				updateError = err;
				console.log('↳ INSERT Result:', { error: err, data: insertData });
			}

			if (updateError) {
				console.error('❌ ERROR SAVING PERMISSIONS:', {
					message: updateError.message,
					code: updateError.code,
					details: updateError.details,
					hint: updateError.hint,
					fullError: updateError
				});
				throw updateError;
			}
			
			console.log('✅ Database update/insert successful');

			// Wait a moment for the database to process
			await new Promise(resolve => setTimeout(resolve, 500));

			// Verify what was saved in database
			const { data: verifyData, error: verifyError } = await supabase
				.from('approval_permissions')
				.select('*')
				.eq('user_id', user.id)
				.single();

			if (verifyError) {
				console.warn('⚠️ Error verifying saved data:', verifyError);
			} else if (verifyData) {
				console.log('✅ VERIFIED - Data in database:', {
					userId: verifyData.user_id,
					can_approve_leave_requests: verifyData.can_approve_leave_requests,
					can_approve_requisitions: verifyData.can_approve_requisitions,
					can_approve_single_bill: verifyData.can_approve_single_bill,
					can_approve_vendor_payments: verifyData.can_approve_vendor_payments,
					can_approve_purchase_vouchers: verifyData.can_approve_purchase_vouchers,
					is_active: verifyData.is_active,
					updated_at: verifyData.updated_at,
					updated_by: verifyData.updated_by
				});
			}

		// Send notification to the user whose permissions were updated
		try {
			const permissionsList = [];
			if (user.permissions.can_approve_requisitions) {
				permissionsList.push(`Requisitions (${user.permissions.requisition_amount_limit > 0 ? user.permissions.requisition_amount_limit.toLocaleString() + ' SAR' : 'Unlimited'})`);
			}
			if (user.permissions.can_approve_single_bill) {
				permissionsList.push(`Single Bill (${user.permissions.single_bill_amount_limit > 0 ? user.permissions.single_bill_amount_limit.toLocaleString() + ' SAR' : 'Unlimited'})`);
			}
			if (user.permissions.can_approve_multiple_bill) {
				permissionsList.push(`Multiple Bill (${user.permissions.multiple_bill_amount_limit > 0 ? user.permissions.multiple_bill_amount_limit.toLocaleString() + ' SAR' : 'Unlimited'})`);
			}
			if (user.permissions.can_approve_recurring_bill) {
				permissionsList.push(`Recurring Bill (${user.permissions.recurring_bill_amount_limit > 0 ? user.permissions.recurring_bill_amount_limit.toLocaleString() + ' SAR' : 'Unlimited'})`);
			}
			if (user.permissions.can_approve_vendor_payments) {
				permissionsList.push(`Vendor Payments (${user.permissions.vendor_payment_amount_limit > 0 ? user.permissions.vendor_payment_amount_limit.toLocaleString() + ' SAR' : 'Unlimited'})`);
			}
			if (user.permissions.can_approve_leave_requests) {
				permissionsList.push('Leave Requests');
			}
			if (user.permissions.can_add_missing_punches) {
				permissionsList.push('Add Missing Punches');
			}

			const message = permissionsList.length > 0
				? `Your approval permissions have been updated:\n\n${permissionsList.join('\n')}`
				: 'Your approval permissions have been removed.';

			await notificationService.createNotification({
				title: '🔐 Approval Permissions Updated',
				message: message,
				type: 'info',
				priority: 'normal',
				target_type: 'specific_users',
				target_users: [user.id]
			}, $currentUser?.username || 'System');

			console.log('✅ Notification sent to user:', user.username);
		} catch (notifErr: any) {
			console.error('⚠️ Failed to send notification:', notifErr);
			// Don't fail the save if notification fails
		}

		alert(`✅ Permissions saved for ${getDisplayName(user)}`);
		await loadUsersWithPermissions();
	} catch (err: any) {
			console.error('Error saving permissions:', err);
			alert(`❌ Error saving permissions: ${err.message}`);
		} finally {
			saving = false;
		}
	}

	function togglePermission(user: any, field: string) {
		console.log(`🔄 Toggle ${field} for user ${user.username}:`, user.permissions[field], '→', !user.permissions[field]);
		user.permissions[field] = !user.permissions[field];
		users = [...users]; // Trigger reactivity
		
		// Auto-save after toggle
		console.log('💾 Auto-saving after toggle...');
		setTimeout(() => {
			saveUserPermissions(user);
		}, 300);
	}

	function updateAmountLimit(user: any, field: string, value: number) {
		user.permissions[field] = value;
		users = [...users]; // Trigger reactivity
	}

	// Helper function to get display name
	function getDisplayName(user: any): string {
		if (user.employee_name) {
			return `${user.username} (${user.employee_name})`;
		}
		return user.username;
	}

	function hasAnyPermission(user: any): boolean {
		const perms = user.permissions;
		return (
			perms.can_approve_requisitions ||
			perms.can_approve_single_bill ||
			perms.can_approve_multiple_bill ||
			perms.can_approve_recurring_bill ||
			perms.can_approve_vendor_payments ||
			perms.can_approve_leave_requests ||
			perms.can_approve_purchase_vouchers ||
			perms.can_add_missing_punches
		);
	}

	// Filter users based on search and filters
	$: filteredUsers = users.filter((user) => {
		// Search filter
		const searchLower = searchQuery.toLowerCase();
		const matchesSearch =
			searchQuery === '' ||
			user.username.toLowerCase().includes(searchLower) ||
			user.employee_name?.toLowerCase().includes(searchLower);

		// Status filter
		const matchesStatus =
			statusFilter === 'all' ||
			(statusFilter === 'active' && user.status === 'active') ||
			(statusFilter === 'inactive' && user.status !== 'active');

		// Permission filter
		const matchesPermission =
			permissionFilter === 'all' ||
			(permissionFilter === 'with-permissions' && hasAnyPermission(user)) ||
			(permissionFilter === 'without-permissions' && !hasAnyPermission(user));

		return matchesSearch && matchesStatus && matchesPermission;
	});

</script>

<div class="approval-permissions-manager">
	{#if !isMasterAdmin}
		<div class="error-message">
			<p>❌ Access Denied: Master Admin role required</p>
		</div>
	{:else if loading}
		<div class="loading">Loading users...</div>
	{:else}
		<div class="content">
			<!-- Filters Section -->
			<div class="filters">
				<div class="filter-group">
					<label for="search">🔍 Search:</label>
					<input
						id="search"
						type="text"
						bind:value={searchQuery}
						placeholder="Search by username or name..."
						class="filter-input"
					/>
				</div>

				<div class="filter-group">
					<label for="status-filter">Status:</label>
					<select id="status-filter" bind:value={statusFilter} class="filter-select">
						<option value="all">All Status</option>
						<option value="active">Active Only</option>
						<option value="inactive">Inactive Only</option>
					</select>
				</div>

				<div class="filter-group">
					<label for="permission-filter">Permissions:</label>
					<select id="permission-filter" bind:value={permissionFilter} class="filter-select">
						<option value="all">All Users</option>
						<option value="with-permissions">With Permissions</option>
						<option value="without-permissions">Without Permissions</option>
					</select>
				</div>

				<div class="filter-stats">
					Showing <strong>{filteredUsers.length}</strong> of <strong>{users.length}</strong> users
				</div>
			</div>

			<!-- Table -->
			<div class="table-container">
				<table class="permissions-table">
					<thead>
						<tr>
							<th class="sticky-col">User</th>
							<th>Status</th>
							<th>📋 Requisitions</th>
							<th>📄 Single Bill</th>
							<th>📑 Multiple Bill</th>
							<th>🔄 Recurring Bill</th>
							<th>💰 Vendor Payment</th>
							<th>🏖️ Leave Request</th>
							<th>🎫 Purchase Voucher</th>
							<th>⏱️ Add Missing Punch</th>
							<th class="action-col">Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredUsers as user (user.id)}
							<tr class:inactive={user.status !== 'active'}>
								<td class="sticky-col user-cell">
									<div class="user-info">
										<strong>{user.username}</strong>
										{#if user.employee_name}
											<span class="employee-name">{user.employee_name}</span>
										{/if}
									</div>
								</td>
								<td>
									<span class="status-badge" class:active={user.status === 'active'}>
										{user.status}
									</span>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_approve_requisitions}
												on:change={() =>
													togglePermission(user, 'can_approve_requisitions')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
										{#if user.permissions.can_approve_requisitions}
											<div class="amount-container">
												<span class="amount-label">💰</span>
												<input
													type="number"
													bind:value={user.permissions.requisition_amount_limit}
													on:input={(e) =>
														updateAmountLimit(
															user,
															'requisition_amount_limit',
															parseFloat(e.target.value) || 0
														)}
													min="0"
													step="0.01"
													class="amount-input"
													placeholder="0.00"
													disabled={saving}
												/>
											</div>
										{/if}
									</div>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_approve_single_bill}
												on:change={() => togglePermission(user, 'can_approve_single_bill')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
										{#if user.permissions.can_approve_single_bill}
											<div class="amount-container">
												<span class="amount-label">💰</span>
												<input
													type="number"
													bind:value={user.permissions.single_bill_amount_limit}
													on:input={(e) =>
														updateAmountLimit(
															user,
															'single_bill_amount_limit',
															parseFloat(e.target.value) || 0
														)}
													min="0"
													step="0.01"
													class="amount-input"
													placeholder="0.00"
													disabled={saving}
												/>
											</div>
										{/if}
									</div>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_approve_multiple_bill}
												on:change={() =>
													togglePermission(user, 'can_approve_multiple_bill')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
										{#if user.permissions.can_approve_multiple_bill}
											<div class="amount-container">
												<span class="amount-label">💰</span>
												<input
													type="number"
													bind:value={user.permissions.multiple_bill_amount_limit}
													on:input={(e) =>
														updateAmountLimit(
															user,
															'multiple_bill_amount_limit',
															parseFloat(e.target.value) || 0
														)}
													min="0"
													step="0.01"
													class="amount-input"
													placeholder="0.00"
													disabled={saving}
												/>
											</div>
										{/if}
									</div>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_approve_recurring_bill}
												on:change={() =>
													togglePermission(user, 'can_approve_recurring_bill')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
										{#if user.permissions.can_approve_recurring_bill}
											<div class="amount-container">
												<span class="amount-label">💰</span>
												<input
													type="number"
													bind:value={user.permissions.recurring_bill_amount_limit}
													on:input={(e) =>
														updateAmountLimit(
															user,
															'recurring_bill_amount_limit',
															parseFloat(e.target.value) || 0
														)}
													min="0"
													step="0.01"
													class="amount-input"
													placeholder="0.00"
													disabled={saving}
												/>
											</div>
										{/if}
									</div>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_approve_vendor_payments}
												on:change={() =>
													togglePermission(user, 'can_approve_vendor_payments')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
										{#if user.permissions.can_approve_vendor_payments}
											<div class="amount-container">
												<span class="amount-label">💰</span>
												<input
													type="number"
													bind:value={user.permissions.vendor_payment_amount_limit}
													on:input={(e) =>
														updateAmountLimit(
															user,
															'vendor_payment_amount_limit',
															parseFloat(e.target.value) || 0
														)}
													min="0"
													step="0.01"
													class="amount-input"
													placeholder="0.00"
													disabled={saving}
												/>
											</div>
										{/if}
									</div>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_approve_leave_requests}
												on:change={() =>
													togglePermission(user, 'can_approve_leave_requests')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
									</div>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_approve_purchase_vouchers}
												on:change={() =>
													togglePermission(user, 'can_approve_purchase_vouchers')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
									</div>
								</td>
								<td>
									<div class="permission-cell">
										<label class="toggle-switch">
											<input
												type="checkbox"
												checked={user.permissions.can_add_missing_punches}
												on:change={() =>
													togglePermission(user, 'can_add_missing_punches')}
												disabled={saving}
											/>
											<span class="toggle-slider"></span>
										</label>
									</div>
								</td>
								<td class="action-col">
									<button
										class="btn-save-row"
										on:click={() => saveUserPermissions(user)}
										disabled={saving}
										title="Save permissions for this user"
									>
										{saving ? '...' : '💾'}
									</button>
								</td>
							</tr>
						{:else}
							<tr>
								<td colspan="11" class="no-results">No users found matching filters</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{/if}
</div>

<style>
	.approval-permissions-manager {
		padding: 1.5rem;
		background-color: #f9fafb;
		height: 100%;
		display: flex;
		flex-direction: column;
	}

	.error-message {
		background: rgba(239, 68, 68, 0.15);
		border: 2px solid rgba(239, 68, 68, 0.4);
		padding: 1.25rem;
		border-radius: 8px;
		text-align: center;
		font-weight: 500;
	}

	.loading {
		text-align: center;
		padding: 3rem;
		font-size: 1.1rem;
		font-weight: 500;
	}

	.content {
		background: #ffffff;
		color: #1f2937;
		border-radius: 10px;
		padding: 1.5rem;
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
	}

	/* Filters Section */
	.filters {
		display: flex;
		gap: 1.25rem;
		margin-bottom: 1.25rem;
		flex-wrap: wrap;
		align-items: center;
		padding-bottom: 1.25rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 0.625rem;
	}

	.filter-group label {
		font-weight: 600;
		color: #4b5563;
		font-size: 0.875rem;
		white-space: nowrap;
	}

	.filter-input,
	.filter-select {
		padding: 0.625rem 0.875rem;
		border: 1.5px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		transition: all 0.2s;
		background-color: #ffffff;
	}

	.filter-input {
		min-width: 280px;
	}

	.filter-select {
		min-width: 160px;
	}

	.filter-input:focus,
	.filter-select:focus {
		outline: none;
		border-color: #dc2626;
		box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.1);
	}

	.filter-stats {
		margin-left: auto;
		color: #6b7280;
		font-size: 0.875rem;
		font-weight: 500;
		padding: 0.5rem 1rem;
		background-color: #f9fafb;
		border-radius: 6px;
	}

	.filter-stats strong {
		color: #dc2626;
		font-weight: 700;
	}

	/* Table */
	.table-container {
		flex: 1;
		overflow: auto;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
	}

	.permissions-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
		background-color: #ffffff;
	}

	.permissions-table thead {
		position: sticky;
		top: 0;
		background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
		color: white;
		z-index: 10;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
	}

	.permissions-table th {
		padding: 1rem 0.75rem;
		text-align: left;
		font-weight: 600;
		font-size: 0.8125rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		white-space: nowrap;
		border-bottom: 2px solid rgba(255, 255, 255, 0.2);
	}

	.permissions-table td {
		padding: 1rem 0.75rem;
		border-bottom: 1px solid #f3f4f6;
		vertical-align: middle;
	}

	.permissions-table tbody tr {
		transition: background-color 0.15s;
	}

	.permissions-table tbody tr:hover {
		background-color: #f9fafb;
	}

	.permissions-table tbody tr.inactive {
		opacity: 0.5;
		background-color: #fafafa;
	}

	.permissions-table tbody tr.inactive:hover {
		background-color: #f3f4f6;
	}

	.sticky-col {
		position: sticky;
		left: 0;
		background: white;
		z-index: 5;
		min-width: 200px;
		max-width: 200px;
		box-shadow: 2px 0 4px rgba(0, 0, 0, 0.04);
	}

	.permissions-table thead .sticky-col {
		background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
		z-index: 15;
	}

	.permissions-table tbody tr:hover .sticky-col {
		background-color: #f9fafb;
	}

	.user-cell {
		font-weight: 500;
	}

	.user-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.user-info strong {
		color: #111827;
		font-size: 0.875rem;
	}

	.employee-name {
		font-size: 0.75rem;
		color: #6b7280;
		font-weight: 400;
	}

	.status-badge {
		display: inline-block;
		padding: 0.375rem 0.75rem;
		border-radius: 6px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.025em;
		background-color: #f3f4f6;
		color: #6b7280;
	}

	.status-badge.active {
		background-color: #d1fae5;
		color: #065f46;
	}

	.permission-cell {
		display: flex;
		flex-direction: column;
		gap: 0.625rem;
		align-items: flex-start;
		padding: 0.25rem;
	}

	.amount-container {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.375rem 0.625rem;
		background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
		border: 1.5px solid #fecaca;
		border-radius: 6px;
		transition: all 0.2s;
		box-shadow: 0 1px 3px rgba(220, 38, 38, 0.1);
	}

	.amount-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #991b1b;
		white-space: nowrap;
	}

	/* Toggle Switch */
	.toggle-switch {
		position: relative;
		display: inline-block;
		width: 48px;
		height: 26px;
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
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		transition: 0.3s;
		border-radius: 26px;
		box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.toggle-slider:before {
		position: absolute;
		content: '';
		height: 20px;
		width: 20px;
		left: 3px;
		bottom: 3px;
		background-color: white;
		transition: 0.3s;
		border-radius: 50%;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
	}

	.toggle-switch input:checked + .toggle-slider {
		background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
	}

	.toggle-switch input:checked + .toggle-slider:before {
		transform: translateX(22px);
	}

	.toggle-switch input:disabled + .toggle-slider {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.amount-input {
		width: 110px;
		padding: 0.5rem 0.625rem;
		border: none;
		border-radius: 4px;
		font-size: 0.8125rem;
		transition: all 0.2s;
		font-weight: 600;
		background-color: #ffffff;
		color: #991b1b;
	}

	.amount-input:focus {
		outline: none;
		background-color: #ffffff;
		box-shadow: 0 0 0 2px rgba(220, 38, 38, 0.2);
	}

	.amount-input:disabled {
		background-color: #ffffff;
		cursor: not-allowed;
		opacity: 0.9;
		color: #166534;
	}

	.action-col {
		text-align: center;
		width: 80px;
	}

	.btn-save-row {
		padding: 0.5rem 1rem;
		background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 1.25rem;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 2px 4px rgba(220, 38, 38, 0.2);
		font-weight: 600;
	}

	.btn-save-row:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
	}

	.btn-save-row:active:not(:disabled) {
		transform: translateY(0);
	}

	.btn-save-row:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	.no-results {
		text-align: center;
		padding: 3rem;
		color: #9ca3af;
		font-style: italic;
		font-size: 0.9375rem;
	}
</style>
