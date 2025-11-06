<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	// Component states
	let activeTab: 'users' | 'customers' | 'registration' = 'users';
	let isLoading = false;
	let errorMessage = '';
	let successMessage = '';

	// Data
	let users = [];
	let customers = [];
	let customerMasterAccess = true; // Global customer access toggle
	
	// Registration settings
	let registrationSettings = {
		enabled: true,
		requireApproval: true,
		autoGenerateAccessCode: true,
		whatsappIntegration: true,
		welcomeMessage: 'Welcome! Your customer account has been approved.',
		maxRegistrationsPerDay: 100
	};

	// Pagination and filtering
	let userSearchTerm = '';
	let customerSearchTerm = '';
	let userCurrentPage = 1;
	let customerCurrentPage = 1;
	let itemsPerPage = 10;

	// Modals
	let showPermissionModal = false;
	let selectedUser = null;
	let permissionChanges = {};

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		isLoading = true;
		errorMessage = '';

		try {
			await Promise.all([
				loadUsers(),
				loadCustomers(),
				loadMasterSettings(),
				loadRegistrationSettings()
			]);
		} catch (error) {
			errorMessage = error.message || 'Failed to load data';
		} finally {
			isLoading = false;
		}
	}

	async function loadUsers() {
		try {
			console.log('🔄 Loading users...');
			
			// Load all users first
			const { data: allUsers, error: allUsersError } = await supabase
				.from('users')
				.select(`
					id,
					username,
					user_type,
					status
				`)
				.order('username', { ascending: true });

			if (allUsersError) {
				console.error('❌ All users query error:', allUsersError);
				throw allUsersError;
			}

			// Load all permissions in a single query
			const userIds = allUsers.map(user => user.id);
			const { data: allPermissions, error: permissionsError } = await supabase
				.from('interface_permissions')
				.select(`
					user_id,
					desktop_enabled,
					mobile_enabled,
					customer_enabled,
					updated_at,
					notes
				`)
				.in('user_id', userIds);

			if (permissionsError) {
				console.error('❌ Permissions query error:', permissionsError);
				// Don't throw error, just log it and continue without permissions
			}

			// Create a map of permissions by user_id for quick lookup
			const permissionsMap = {};
			(allPermissions || []).forEach(perm => {
				permissionsMap[perm.user_id] = perm;
			});

			// Combine users with their permissions
			const usersWithPermissions = allUsers.map(user => ({
				...user,
				name: user.username, // Use username as display name
				interface_permissions: permissionsMap[user.id] ? [permissionsMap[user.id]] : []
			}));
			
			users = usersWithPermissions;
			console.log('✅ Loaded users:', users.length);
		} catch (err) {
			console.error('❌ loadUsers error:', err);
			throw err;
		}
	}

	async function loadCustomers() {
		try {
			console.log('🔄 Loading customers...');
			
			// Load all customers first
			const { data: customersData, error: customersError } = await supabase
				.from('customers')
				.select(`
					id,
					access_code,
					whatsapp_number,
					registration_status,
					approved_at,
					last_login_at,
					user_id
				`);

			if (customersError) {
				console.error('❌ Customers query error:', customersError);
				throw customersError;
			}

			if (!customersData || customersData.length === 0) {
				customers = [];
				console.log('✅ Loaded customers: 0');
				return;
			}

			// Get all unique user IDs
			const userIds = [...new Set(customersData.map(c => c.user_id).filter(Boolean))];

			// Load all user data in one query
			const { data: usersData, error: usersError } = await supabase
				.from('users')
				.select(`
					id,
					username,
					status
				`)
				.in('id', userIds);

			if (usersError) {
				console.error('❌ Users query error:', usersError);
			}

			// Load all permissions in one query
			const { data: permissionsData, error: permissionsError } = await supabase
				.from('interface_permissions')
				.select(`
					user_id,
					desktop_enabled,
					mobile_enabled,
					customer_enabled,
					updated_at
				`)
				.in('user_id', userIds);

			if (permissionsError) {
				console.error('❌ Permissions query error:', permissionsError);
			}

			// Create lookup maps
			const usersMap = {};
			(usersData || []).forEach(user => {
				usersMap[user.id] = {
					...user,
					name: user.username // Use username as name
				};
			});

			const permissionsMap = {};
			(permissionsData || []).forEach(perm => {
				permissionsMap[perm.user_id] = perm;
			});

			// Combine all data
			const customersWithData = customersData.map(customer => ({
				...customer,
				users: usersMap[customer.user_id] || null,
				interface_permissions: permissionsMap[customer.user_id] || null
			}));

			customers = customersWithData;
			
			// Sort customers by user name client-side
			customers.sort((a, b) => {
				const nameA = a.users?.name || '';
				const nameB = b.users?.name || '';
				return nameA.localeCompare(nameB);
			});

			console.log('✅ Loaded customers:', customers.length);
		} catch (err) {
			console.error('❌ loadCustomers error:', err);
			throw err;
		}
	}

	async function loadMasterSettings() {
		// For now, we'll use a simple approach
		// In a real app, you might store this in a settings table
		customerMasterAccess = true;
	}

	async function loadRegistrationSettings() {
		// Load registration settings from database or config
		// For now, use defaults
		registrationSettings = {
			enabled: true,
			requireApproval: true,
			autoGenerateAccessCode: true,
			whatsappIntegration: true,
			welcomeMessage: 'Welcome! Your customer account has been approved.',
			maxRegistrationsPerDay: 100
		};
	}

	async function updateRegistrationSettings(newSettings) {
		isLoading = true;
		errorMessage = '';

		try {
			// In a real app, save to database
			registrationSettings = { ...registrationSettings, ...newSettings };
			
			successMessage = 'Registration settings updated successfully';
			
			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = error.message || 'Failed to update registration settings';
		} finally {
			isLoading = false;
		}
	}

	async function updateUserPermissions(userId, permissions) {
		isLoading = true;
		errorMessage = '';

		try {
			console.log('🔐 Current user from store:', $currentUser);

			// Use the current user ID from the store
			const updatedById = $currentUser?.id;
			
			if (!updatedById) {
				console.warn('⚠️ No current user ID available, proceeding without updated_by');
			}

			const updateData = {
				user_id: userId,
				...permissions,
				updated_at: new Date().toISOString()
			};

			// Only add updated_by if we have a valid ID
			if (updatedById) {
				updateData.updated_by = updatedById;
			}

			console.log('📝 Updating permissions with data:', updateData);

			const { data, error } = await supabase
				.from('interface_permissions')
				.upsert(updateData, { 
					onConflict: 'user_id',
					ignoreDuplicates: false 
				});

			if (error) {
				console.error('Permission update error:', error);
				throw error;
			}

			console.log('✅ Permission updated successfully');
			successMessage = 'Permissions updated successfully';
			await loadUsers();
			
			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = error.message || 'Failed to update permissions';
		} finally {
			isLoading = false;
		}
	}

	async function updateCustomerPermissions(customerId, enabled) {
		isLoading = true;
		errorMessage = '';

		try {
			// Get customer's user_id first
			const customer = customers.find(c => c.id === customerId);
			if (!customer) throw new Error('Customer not found');

			console.log('🔐 Current user from store:', $currentUser);

			// Use the current user ID from the store
			const updatedById = $currentUser?.id;

			const updateData = {
				user_id: customer.users.id,
				desktop_enabled: false,
				mobile_enabled: false,
				customer_enabled: enabled,
				updated_at: new Date().toISOString()
			};

			// Only add updated_by if we have a valid ID
			if (updatedById) {
				updateData.updated_by = updatedById;
			}

			const { data, error } = await supabase
				.from('interface_permissions')
				.upsert(updateData, { 
					onConflict: 'user_id',
					ignoreDuplicates: false 
				});

			if (error) throw error;

			successMessage = `Customer access ${enabled ? 'enabled' : 'disabled'}`;
			await loadCustomers();
			
			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = error.message || 'Failed to update customer permissions';
		} finally {
			isLoading = false;
		}
	}

	async function toggleMasterCustomerAccess() {
		isLoading = true;
		errorMessage = '';

		try {
			console.log('🔐 Current user from store:', $currentUser);

			// Use the current user ID from the store
			const updatedById = $currentUser?.id;

			// Update all customer permissions
			for (const customer of customers) {
				const updateData = {
					user_id: customer.users.id,
					desktop_enabled: false,
					mobile_enabled: false,
					customer_enabled: customerMasterAccess,
					updated_at: new Date().toISOString()
				};

				// Only add updated_by if we have a valid ID
				if (updatedById) {
					updateData.updated_by = updatedById;
				}

				await supabase
					.from('interface_permissions')
					.upsert(updateData, { 
						onConflict: 'user_id',
						ignoreDuplicates: false 
					});
			}

			successMessage = `Customer access ${customerMasterAccess ? 'enabled' : 'disabled'} for all customers`;
			await loadCustomers();

			setTimeout(() => {
				successMessage = '';
			}, 3000);

		} catch (error) {
			errorMessage = error.message || 'Failed to update master customer access';
		} finally {
			isLoading = false;
		}
	}

	function openPermissionModal(user) {
		selectedUser = user;
		permissionChanges = {
			desktop_enabled: user.interface_permissions[0]?.desktop_enabled ?? true,
			mobile_enabled: user.interface_permissions[0]?.mobile_enabled ?? true,
			customer_enabled: user.interface_permissions[0]?.customer_enabled ?? false
		};
		showPermissionModal = true;
	}

	function closePermissionModal() {
		showPermissionModal = false;
		selectedUser = null;
		permissionChanges = {};
	}

	async function savePermissionChanges() {
		if (!selectedUser) return;
		
		await updateUserPermissions(selectedUser.id, permissionChanges);
		closePermissionModal();
	}

	// Filter functions
	$: filteredUsers = userSearchTerm.trim() === '' 
		? users 
		: users.filter(user => {
			const searchLower = userSearchTerm.toLowerCase().trim();
			return (
				user.name?.toLowerCase().includes(searchLower) ||
				user.username?.toLowerCase().includes(searchLower) ||
				(user.email && user.email.toLowerCase().includes(searchLower))
			);
		});

	$: filteredCustomers = customerSearchTerm.trim() === ''
		? customers
		: customers.filter(customer => {
			const searchLower = customerSearchTerm.toLowerCase().trim();
			return (
				customer.users?.name?.toLowerCase().includes(searchLower) ||
				customer.whatsapp_number?.includes(customerSearchTerm)
			);
		});

	// Debug search functionality
	$: {
		console.log('🔍 User search term:', userSearchTerm);
		console.log('👥 Total users:', users.length);
		console.log('🔍 Filtered users:', filteredUsers.length);
	}

	// Pagination
	$: userTotalPages = Math.ceil(filteredUsers.length / itemsPerPage);
	$: customerTotalPages = Math.ceil(filteredCustomers.length / itemsPerPage);

	$: paginatedUsers = filteredUsers.slice(
		(userCurrentPage - 1) * itemsPerPage,
		userCurrentPage * itemsPerPage
	);

	$: paginatedCustomers = filteredCustomers.slice(
		(customerCurrentPage - 1) * itemsPerPage,
		customerCurrentPage * itemsPerPage
	);

	function formatDate(dateString) {
		if (!dateString) return 'Never';
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getStatusColor(status) {
		switch (status) {
			case 'active': return 'text-green-600 bg-green-100';
			case 'pending': return 'text-yellow-600 bg-yellow-100';
			case 'suspended': return 'text-red-600 bg-red-100';
			case 'approved': return 'text-green-600 bg-green-100';
			case 'rejected': return 'text-red-600 bg-red-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}
</script>

<div class="interface-access-manager">
	<div class="header">
		<h1>Interface Access Manager</h1>
		<p>Manage user and customer interface permissions</p>
	</div>

	<!-- Tab Navigation -->
	<div class="tab-navigation">
		<button 
			class="tab-btn"
			class:active={activeTab === 'users'}
			on:click={() => activeTab = 'users'}
		>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
				<circle cx="12" cy="7" r="4"/>
			</svg>
			Users ({users.length})
		</button>
		<button 
			class="tab-btn"
			class:active={activeTab === 'customers'}
			on:click={() => activeTab = 'customers'}
		>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="12" cy="12" r="3"/>
				<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1 1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
			</svg>
			Customers ({customers.length})
		</button>
		<button 
			class="tab-btn"
			class:active={activeTab === 'registration'}
			on:click={() => activeTab = 'registration'}
		>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
				<circle cx="9" cy="7" r="4"/>
				<path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
				<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
			</svg>
			Registration Settings
		</button>
	</div>

	{#if activeTab === 'users'}
		<!-- Users Tab -->
		<div class="tab-content">
			<div class="content-header">
				<div class="search-section">
					<div class="search-input-group">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="11" cy="11" r="8"/>
							<path d="M21 21l-4.35-4.35"/>
						</svg>
						<input 
							type="text" 
							placeholder="Search users..." 
							bind:value={userSearchTerm}
							class="search-input"
						/>
					</div>
				</div>
				<div class="content-actions">
					<button class="refresh-btn" on:click={loadData} disabled={isLoading}>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="23 4 23 10 17 10"/>
							<polyline points="1 20 1 14 7 14"/>
							<path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"/>
						</svg>
						Refresh
					</button>
				</div>
			</div>

			<!-- Users Table -->
			<div class="table-container">
				<table class="data-table">
					<thead>
						<tr>
							<th>User</th>
							<th>Status</th>
							<th>Desktop</th>
							<th>Mobile</th>
							<th>Customer</th>
							<th>Last Updated</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each paginatedUsers as user}
							<tr>
								<td>
									<div class="user-info">
										<div class="user-avatar">
											{user.name?.charAt(0)?.toUpperCase() || 'U'}
										</div>
										<div class="user-details">
											<div class="user-name">{user.name || 'Unknown'}</div>
											<div class="user-username">@{user.username}</div>
											{#if user.email}
												<div class="user-email">{user.email}</div>
											{/if}
										</div>
									</div>
								</td>
								<td>
									<span class="status-badge {getStatusColor(user.status)}">
										{user.status || 'unknown'}
									</span>
								</td>
								<td>
									<label class="toggle-switch">
										<input 
											type="checkbox" 
											checked={user.interface_permissions[0]?.desktop_enabled ?? true}
											on:change={(e) => updateUserPermissions(user.id, {
												desktop_enabled: e.target.checked,
												mobile_enabled: user.interface_permissions[0]?.mobile_enabled ?? true,
												customer_enabled: user.interface_permissions[0]?.customer_enabled ?? false
											})}
											disabled={isLoading}
										/>
										<span class="toggle-slider"></span>
									</label>
								</td>
								<td>
									<label class="toggle-switch">
										<input 
											type="checkbox" 
											checked={user.interface_permissions[0]?.mobile_enabled ?? true}
											on:change={(e) => updateUserPermissions(user.id, {
												desktop_enabled: user.interface_permissions[0]?.desktop_enabled ?? true,
												mobile_enabled: e.target.checked,
												customer_enabled: user.interface_permissions[0]?.customer_enabled ?? false
											})}
											disabled={isLoading}
										/>
										<span class="toggle-slider"></span>
									</label>
								</td>
								<td>
									<label class="toggle-switch">
										<input 
											type="checkbox" 
											checked={user.interface_permissions[0]?.customer_enabled ?? false}
											on:change={(e) => updateUserPermissions(user.id, {
												desktop_enabled: user.interface_permissions[0]?.desktop_enabled ?? true,
												mobile_enabled: user.interface_permissions[0]?.mobile_enabled ?? true,
												customer_enabled: e.target.checked
											})}
											disabled={isLoading}
										/>
										<span class="toggle-slider"></span>
									</label>
								</td>
								<td>
									{formatDate(user.interface_permissions[0]?.updated_at)}
								</td>
								<td>
									<button 
										class="action-btn edit-btn"
										on:click={() => openPermissionModal(user)}
										disabled={isLoading}
									>
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
											<path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
										</svg>
									</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>

				{#if filteredUsers.length === 0}
					<div class="empty-state">
						<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="11" cy="11" r="8"/>
							<path d="M21 21l-4.35-4.35"/>
						</svg>
						<h3>No users found</h3>
						<p>Try adjusting your search criteria</p>
					</div>
				{/if}
			</div>

			<!-- Users Pagination -->
			{#if userTotalPages > 1}
				<div class="pagination">
					<button 
						class="pagination-btn"
						disabled={userCurrentPage === 1}
						on:click={() => userCurrentPage = Math.max(1, userCurrentPage - 1)}
					>
						Previous
					</button>
					<span class="pagination-info">
						Page {userCurrentPage} of {userTotalPages}
					</span>
					<button 
						class="pagination-btn"
						disabled={userCurrentPage === userTotalPages}
						on:click={() => userCurrentPage = Math.min(userTotalPages, userCurrentPage + 1)}
					>
						Next
					</button>
				</div>
			{/if}
		</div>

	{:else}
		<!-- Customers Tab -->
		<div class="tab-content">
			<div class="content-header">
				<div class="search-section">
					<div class="search-input-group">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="11" cy="11" r="8"/>
							<path d="M21 21l-4.35-4.35"/>
						</svg>
						<input 
							type="text" 
							placeholder="Search customers..." 
							bind:value={customerSearchTerm}
							class="search-input"
						/>
					</div>
				</div>
				<div class="content-actions">
					<div class="master-toggle">
						<label class="master-toggle-label">
							<span>Master Customer Access</span>
							<label class="toggle-switch master">
								<input 
									type="checkbox" 
									bind:checked={customerMasterAccess}
									on:change={toggleMasterCustomerAccess}
									disabled={isLoading}
								/>
								<span class="toggle-slider"></span>
							</label>
						</label>
					</div>
					<button class="refresh-btn" on:click={loadData} disabled={isLoading}>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="23 4 23 10 17 10"/>
							<polyline points="1 20 1 14 7 14"/>
							<path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"/>
						</svg>
						Refresh
					</button>
				</div>
			</div>

			<!-- Customers Table -->
			<div class="table-container">
				<table class="data-table">
					<thead>
						<tr>
							<th>Customer</th>
							<th>Access Code</th>
							<th>WhatsApp</th>
							<th>Status</th>
							<th>Access Enabled</th>
							<th>Last Login</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each paginatedCustomers as customer}
							<tr>
								<td>
									<div class="user-info">
										<div class="user-avatar">
											{customer.users?.name?.charAt(0)?.toUpperCase() || 'C'}
										</div>
										<div class="user-details">
											<div class="user-name">{customer.users?.name || 'Unknown'}</div>
											<div class="user-username">@{customer.users?.username || 'unknown'}</div>
										</div>
									</div>
								</td>
								<td>
									{#if customer.access_code}
										<code class="access-code">{customer.access_code}</code>
									{:else}
										<span class="no-code">No code</span>
									{/if}
								</td>
								<td>
									{#if customer.whatsapp_number}
										<a href="https://wa.me/{customer.whatsapp_number.replace(/\D/g, '')}" target="_blank" class="whatsapp-link">
											{customer.whatsapp_number}
										</a>
									{:else}
										<span class="no-whatsapp">No number</span>
									{/if}
								</td>
								<td>
									<span class="status-badge {getStatusColor(customer.registration_status)}">
										{customer.registration_status}
									</span>
								</td>
								<td>
									<label class="toggle-switch">
										<input 
											type="checkbox" 
											checked={customer.interface_permissions?.customer_enabled ?? false}
											on:change={(e) => updateCustomerPermissions(customer.id, e.target.checked)}
											disabled={isLoading || !customerMasterAccess}
										/>
										<span class="toggle-slider"></span>
									</label>
								</td>
								<td>
									{formatDate(customer.last_login_at)}
								</td>
								<td>
									<button 
										class="action-btn view-btn"
										disabled={isLoading}
									>
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
											<circle cx="12" cy="12" r="3"/>
										</svg>
									</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>

				{#if filteredCustomers.length === 0}
					<div class="empty-state">
						<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="3"/>
							<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1 1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
						</svg>
						<h3>No customers found</h3>
						<p>Try adjusting your search criteria</p>
					</div>
				{/if}
			</div>

			<!-- Customers Pagination -->
			{#if customerTotalPages > 1}
				<div class="pagination">
					<button 
						class="pagination-btn"
						disabled={customerCurrentPage === 1}
						on:click={() => customerCurrentPage = Math.max(1, customerCurrentPage - 1)}
					>
						Previous
					</button>
					<span class="pagination-info">
						Page {customerCurrentPage} of {customerTotalPages}
					</span>
					<button 
						class="pagination-btn"
						disabled={customerCurrentPage === customerTotalPages}
						on:click={() => customerCurrentPage = Math.min(customerTotalPages, customerCurrentPage + 1)}
					>
						Next
					</button>
				</div>
			{/if}
		</div>

	{:else if activeTab === 'registration'}
		<!-- Registration Settings Tab -->
		<div class="tab-content">
			<div class="content-header">
				<div class="header-info">
					<h2>Customer Registration Settings</h2>
					<p>Configure how customer registration and approval workflow operates</p>
				</div>
				<div class="content-actions">
					<button class="refresh-btn" on:click={loadData} disabled={isLoading}>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="23 4 23 10 17 10"/>
							<polyline points="1 20 1 14 7 14"/>
							<path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"/>
						</svg>
						Refresh
					</button>
				</div>
			</div>

			<div class="settings-grid">
				<!-- Registration Control -->
				<div class="settings-section">
					<div class="settings-header">
						<div class="settings-icon">
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
								<circle cx="9" cy="7" r="4"/>
								<path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
								<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
							</svg>
						</div>
						<div>
							<h3>Registration Control</h3>
							<p>Enable or disable customer registration</p>
						</div>
					</div>
					<div class="settings-controls">
						<label class="setting-item">
							<div class="setting-info">
								<span class="setting-label">Allow New Registrations</span>
								<span class="setting-description">Allow customers to submit registration requests</span>
							</div>
							<label class="toggle-switch">
								<input 
									type="checkbox" 
									bind:checked={registrationSettings.enabled}
									on:change={() => updateRegistrationSettings({ enabled: registrationSettings.enabled })}
									disabled={isLoading}
								/>
								<span class="toggle-slider"></span>
							</label>
						</label>
						
						<label class="setting-item">
							<div class="setting-info">
								<span class="setting-label">Require Admin Approval</span>
								<span class="setting-description">New registrations need admin approval before activation</span>
							</div>
							<label class="toggle-switch">
								<input 
									type="checkbox" 
									bind:checked={registrationSettings.requireApproval}
									on:change={() => updateRegistrationSettings({ requireApproval: registrationSettings.requireApproval })}
									disabled={isLoading || !registrationSettings.enabled}
								/>
								<span class="toggle-slider"></span>
							</label>
						</label>

						<div class="setting-item">
							<div class="setting-info">
								<span class="setting-label">Daily Registration Limit</span>
								<span class="setting-description">Maximum number of registrations allowed per day</span>
							</div>
							<input 
								type="number" 
								class="setting-input"
								bind:value={registrationSettings.maxRegistrationsPerDay}
								on:change={() => updateRegistrationSettings({ maxRegistrationsPerDay: registrationSettings.maxRegistrationsPerDay })}
								min="1"
								max="1000"
								disabled={isLoading || !registrationSettings.enabled}
							/>
						</div>
					</div>
				</div>

				<!-- Access Code Settings -->
				<div class="settings-section">
					<div class="settings-header">
						<div class="settings-icon">
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
								<circle cx="12" cy="16" r="1"/>
								<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
							</svg>
						</div>
						<div>
							<h3>Access Code Management</h3>
							<p>Configure how access codes are generated and managed</p>
						</div>
					</div>
					<div class="settings-controls">
						<label class="setting-item">
							<div class="setting-info">
								<span class="setting-label">Auto-Generate Access Codes</span>
								<span class="setting-description">Automatically create 6-digit codes when approving customers</span>
							</div>
							<label class="toggle-switch">
								<input 
									type="checkbox" 
									bind:checked={registrationSettings.autoGenerateAccessCode}
									on:change={() => updateRegistrationSettings({ autoGenerateAccessCode: registrationSettings.autoGenerateAccessCode })}
									disabled={isLoading}
								/>
								<span class="toggle-slider"></span>
							</label>
						</label>
					</div>
				</div>

				<!-- WhatsApp Integration -->
				<div class="settings-section">
					<div class="settings-header">
						<div class="settings-icon">
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
							</svg>
						</div>
						<div>
							<h3>WhatsApp Integration</h3>
							<p>Configure credential sharing via WhatsApp</p>
						</div>
					</div>
					<div class="settings-controls">
						<label class="setting-item">
							<div class="setting-info">
								<span class="setting-label">Enable WhatsApp Sharing</span>
								<span class="setting-description">Show WhatsApp share button for sending login credentials</span>
							</div>
							<label class="toggle-switch">
								<input 
									type="checkbox" 
									bind:checked={registrationSettings.whatsappIntegration}
									on:change={() => updateRegistrationSettings({ whatsappIntegration: registrationSettings.whatsappIntegration })}
									disabled={isLoading}
								/>
								<span class="toggle-slider"></span>
							</label>
						</label>
					</div>
				</div>

				<!-- Welcome Message -->
				<div class="settings-section full-width">
					<div class="settings-header">
						<div class="settings-icon">
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
							</svg>
						</div>
						<div>
							<h3>Welcome Message</h3>
							<p>Message sent to customers when their account is approved</p>
						</div>
					</div>
					<div class="settings-controls">
						<div class="setting-item full-width">
							<label class="setting-label">Approval Message</label>
							<textarea 
								class="setting-textarea"
								bind:value={registrationSettings.welcomeMessage}
								on:change={() => updateRegistrationSettings({ welcomeMessage: registrationSettings.welcomeMessage })}
								placeholder="Enter welcome message for approved customers..."
								rows="4"
								disabled={isLoading}
							></textarea>
						</div>
					</div>
				</div>

				<!-- Registration URL -->
				<div class="settings-section full-width">
					<div class="settings-header">
						<div class="settings-icon">
							<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.72"/>
								<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.72-1.72"/>
							</svg>
						</div>
						<div>
							<h3>Registration URL</h3>
							<p>Direct link for customers to register</p>
						</div>
					</div>
					<div class="settings-controls">
						<div class="url-display">
							<div class="url-box">
								<code>{window?.location?.origin || 'https://yourapp.com'}/register</code>
								<button 
									class="copy-btn"
									on:click={() => {
										navigator.clipboard.writeText(`${window?.location?.origin || 'https://yourapp.com'}/register`);
										successMessage = 'Registration URL copied to clipboard';
										setTimeout(() => successMessage = '', 3000);
									}}
									disabled={isLoading}
								>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
										<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
									</svg>
								</button>
							</div>
							<p class="url-description">
								Share this URL with potential customers to allow them to register for an account.
								{#if !registrationSettings.enabled}
									<span class="url-warning">⚠️ Registration is currently disabled</span>
								{/if}
							</p>
						</div>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Status Messages -->
	{#if errorMessage}
		<div class="status-message error" role="alert">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="12" cy="12" r="10"/>
				<line x1="15" y1="9" x2="9" y2="15"/>
				<line x1="9" y1="9" x2="15" y2="15"/>
			</svg>
			{errorMessage}
		</div>
	{/if}

	{#if successMessage}
		<div class="status-message success" role="status">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M9 12l2 2 4-4"/>
				<circle cx="12" cy="12" r="10"/>
			</svg>
			{successMessage}
		</div>
	{/if}

	<!-- Loading Overlay -->
	{#if isLoading}
		<div class="loading-overlay">
			<div class="loading-spinner"></div>
		</div>
	{/if}
</div>

<!-- Permission Modal -->
{#if showPermissionModal && selectedUser}
	<div class="modal-overlay" on:click={closePermissionModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>Edit Permissions: {selectedUser.name}</h3>
				<button class="modal-close" on:click={closePermissionModal}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<div class="modal-body">
				<div class="permission-group">
					<label class="permission-item">
						<div class="permission-info">
							<div class="permission-title">Desktop Interface</div>
							<div class="permission-description">Full windowed management system</div>
						</div>
						<label class="toggle-switch">
							<input 
								type="checkbox" 
								bind:checked={permissionChanges.desktop_enabled}
							/>
							<span class="toggle-slider"></span>
						</label>
					</label>

					<label class="permission-item">
						<div class="permission-info">
							<div class="permission-title">Mobile Interface</div>
							<div class="permission-description">Optimized mobile experience</div>
						</div>
						<label class="toggle-switch">
							<input 
								type="checkbox" 
								bind:checked={permissionChanges.mobile_enabled}
							/>
							<span class="toggle-slider"></span>
						</label>
					</label>

					<label class="permission-item">
						<div class="permission-info">
							<div class="permission-title">Customer Interface</div>
							<div class="permission-description">Customer access portal</div>
						</div>
						<label class="toggle-switch">
							<input 
								type="checkbox" 
								bind:checked={permissionChanges.customer_enabled}
							/>
							<span class="toggle-slider"></span>
						</label>
					</label>
				</div>
			</div>

			<div class="modal-footer">
				<button class="btn btn-secondary" on:click={closePermissionModal}>
					Cancel
				</button>
				<button class="btn btn-primary" on:click={savePermissionChanges}>
					Save Changes
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.interface-access-manager {
		padding: 2rem;
		max-width: 1200px;
		margin: 0 auto;
		position: relative;
	}

	.header {
		margin-bottom: 2rem;
	}

	.header h1 {
		font-size: 2rem;
		font-weight: 700;
		color: #1E293B;
		margin-bottom: 0.5rem;
	}

	.header p {
		color: #64748B;
		font-size: 1rem;
	}

	/* Tab Navigation */
	.tab-navigation {
		display: flex;
		gap: 0.25rem;
		margin-bottom: 2rem;
		border-bottom: 2px solid #E5E7EB;
	}

	.tab-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem 1.5rem;
		background: transparent;
		border: none;
		color: #64748B;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		border-bottom: 2px solid transparent;
		position: relative;
		top: 2px;
	}

	.tab-btn:hover {
		color: #475569;
		background: #F8FAFC;
	}

	.tab-btn.active {
		color: #15A34A;
		border-bottom-color: #15A34A;
		background: #F0FDF4;
	}

	/* Tab Content */
	.tab-content {
		background: #FFFFFF;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
		overflow: hidden;
	}

	.content-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
		background: #F8FAFC;
	}

	.search-section {
		flex: 1;
		max-width: 400px;
	}

	.search-input-group {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-input-group svg {
		position: absolute;
		left: 0.75rem;
		color: #9CA3AF;
		z-index: 1;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 0.75rem 0.75rem 2.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: #FFFFFF;
		transition: all 0.3s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
	}

	.content-actions {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.master-toggle {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.master-toggle-label {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #15A34A;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #166534;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	/* Data Table */
	.table-container {
		overflow-x: auto;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
	}

	.data-table th {
		text-align: left;
		padding: 1rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		background: #F9FAFB;
		border-bottom: 1px solid #E5E7EB;
	}

	.data-table td {
		padding: 1rem;
		border-bottom: 1px solid #F3F4F6;
		vertical-align: middle;
	}

	.data-table tr:hover {
		background: #F8FAFC;
	}

	/* User Info */
	.user-info {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.user-avatar {
		width: 40px;
		height: 40px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.user-details {
		flex: 1;
	}

	.user-name {
		font-weight: 600;
		color: #1E293B;
		font-size: 0.875rem;
	}

	.user-username {
		color: #64748B;
		font-size: 0.75rem;
		margin-top: 0.125rem;
	}

	.user-email {
		color: #9CA3AF;
		font-size: 0.75rem;
		margin-top: 0.125rem;
	}

	/* Status Badge */
	.status-badge {
		padding: 0.25rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 500;
		text-transform: capitalize;
	}

	/* Toggle Switch */
	.toggle-switch {
		position: relative;
		display: inline-block;
		width: 44px;
		height: 24px;
	}

	.toggle-switch.master {
		width: 48px;
		height: 28px;
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
		background-color: #CBD5E1;
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

	.toggle-switch.master .toggle-slider:before {
		height: 22px;
		width: 22px;
	}

	input:checked + .toggle-slider {
		background-color: #15A34A;
	}

	input:focus + .toggle-slider {
		box-shadow: 0 0 1px #15A34A;
	}

	input:checked + .toggle-slider:before {
		transform: translateX(20px);
	}

	input:disabled + .toggle-slider {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Access Code */
	.access-code {
		background: #F3F4F6;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		font-family: 'JetBrains Mono', monospace;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.no-code {
		color: #9CA3AF;
		font-style: italic;
		font-size: 0.875rem;
	}

	/* WhatsApp Link */
	.whatsapp-link {
		color: #25D366;
		text-decoration: none;
		font-weight: 500;
		font-size: 0.875rem;
	}

	.whatsapp-link:hover {
		text-decoration: underline;
	}

	.no-whatsapp {
		color: #9CA3AF;
		font-style: italic;
		font-size: 0.875rem;
	}

	/* Action Buttons */
	.action-btn {
		padding: 0.5rem;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.3s ease;
		display: inline-flex;
		align-items: center;
		justify-content: center;
	}

	.edit-btn {
		background: #3B82F6;
		color: white;
	}

	.edit-btn:hover:not(:disabled) {
		background: #2563EB;
	}

	.view-btn {
		background: #64748B;
		color: white;
	}

	.view-btn:hover:not(:disabled) {
		background: #475569;
	}

	.action-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Empty State */
	.empty-state {
		text-align: center;
		padding: 3rem 2rem;
		color: #64748B;
	}

	.empty-state svg {
		margin-bottom: 1rem;
		opacity: 0.5;
	}

	.empty-state h3 {
		font-size: 1.125rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
		color: #374151;
	}

	.empty-state p {
		font-size: 0.875rem;
	}

	/* Pagination */
	.pagination {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #E5E7EB;
		background: #F8FAFC;
	}

	.pagination-btn {
		padding: 0.5rem 1rem;
		background: #FFFFFF;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		color: #374151;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.pagination-btn:hover:not(:disabled) {
		background: #F9FAFB;
		border-color: #9CA3AF;
	}

	.pagination-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.pagination-info {
		font-size: 0.875rem;
		color: #64748B;
	}

	/* Status Messages */
	.status-message {
		position: fixed;
		top: 2rem;
		right: 2rem;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 1.25rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		z-index: 1000;
		animation: slideInRight 0.3s ease-out;
	}

	@keyframes slideInRight {
		from {
			opacity: 0;
			transform: translateX(100%);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	.status-message.error {
		background: #FEF2F2;
		border: 1px solid #FECACA;
		color: #DC2626;
	}

	.status-message.success {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		color: #16A34A;
	}

	/* Loading Overlay */
	.loading-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(255, 255, 255, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #E5E7EB;
		border-top: 4px solid #15A34A;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Modal */
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
		z-index: 1000;
		padding: 1rem;
	}

	.modal-content {
		background: #FFFFFF;
		border-radius: 12px;
		width: 100%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.modal-header h3 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1E293B;
	}

	.modal-close {
		background: none;
		border: none;
		color: #64748B;
		cursor: pointer;
		padding: 0.25rem;
		border-radius: 4px;
		transition: all 0.3s ease;
	}

	.modal-close:hover {
		background: #F1F5F9;
		color: #374151;
	}

	.modal-body {
		padding: 1.5rem;
	}

	.permission-group {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.permission-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem;
		background: #F8FAFC;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.permission-item:hover {
		background: #F1F5F9;
	}

	.permission-info {
		flex: 1;
	}

	.permission-title {
		font-weight: 500;
		color: #1E293B;
		font-size: 0.875rem;
	}

	.permission-description {
		color: #64748B;
		font-size: 0.75rem;
		margin-top: 0.25rem;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
		padding: 1.5rem;
		border-top: 1px solid #E5E7EB;
		background: #F8FAFC;
	}

	.btn {
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		border: none;
	}

	.btn-secondary {
		background: #F1F5F9;
		color: #475569;
	}

	.btn-secondary:hover {
		background: #E2E8F0;
	}

	.btn-primary {
		background: #15A34A;
		color: white;
	}

	.btn-primary:hover {
		background: #166534;
	}

	/* Registration Settings Styles */
	.header-info h2 {
		font-size: 1.5rem;
		font-weight: 600;
		color: #1E293B;
		margin-bottom: 0.5rem;
	}

	.header-info p {
		color: #64748B;
		font-size: 0.875rem;
	}

	.settings-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
		gap: 1.5rem;
		padding: 1.5rem;
	}

	.settings-section {
		background: #F8FAFC;
		border: 1px solid #E2E8F0;
		border-radius: 12px;
		overflow: hidden;
	}

	.settings-section.full-width {
		grid-column: 1 / -1;
	}

	.settings-header {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1.5rem;
		background: #FFFFFF;
		border-bottom: 1px solid #E2E8F0;
	}

	.settings-icon {
		padding: 0.75rem;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.settings-header h3 {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1E293B;
		margin-bottom: 0.25rem;
	}

	.settings-header p {
		color: #64748B;
		font-size: 0.875rem;
	}

	.settings-controls {
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.setting-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		cursor: pointer;
	}

	.setting-item.full-width {
		flex-direction: column;
		align-items: stretch;
		gap: 0.75rem;
		cursor: default;
	}

	.setting-info {
		flex: 1;
		padding-right: 1rem;
	}

	.setting-label {
		font-weight: 500;
		color: #1E293B;
		font-size: 0.875rem;
		display: block;
		margin-bottom: 0.25rem;
	}

	.setting-description {
		color: #64748B;
		font-size: 0.75rem;
		line-height: 1.4;
	}

	.setting-input {
		padding: 0.5rem 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		font-size: 0.875rem;
		background: #FFFFFF;
		color: #1E293B;
		width: 100px;
		transition: all 0.3s ease;
	}

	.setting-input:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
	}

	.setting-input:disabled {
		background: #F3F4F6;
		color: #9CA3AF;
		cursor: not-allowed;
	}

	.setting-textarea {
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: #FFFFFF;
		color: #1E293B;
		resize: vertical;
		min-height: 100px;
		font-family: inherit;
		transition: all 0.3s ease;
	}

	.setting-textarea:focus {
		outline: none;
		border-color: #15A34A;
		box-shadow: 0 0 0 3px rgba(21, 163, 74, 0.1);
	}

	.setting-textarea:disabled {
		background: #F3F4F6;
		color: #9CA3AF;
		cursor: not-allowed;
	}

	.url-display {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.url-box {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
	}

	.url-box code {
		flex: 1;
		font-family: 'JetBrains Mono', monospace;
		font-size: 0.875rem;
		color: #374151;
		background: none;
		padding: 0;
	}

	.copy-btn {
		padding: 0.5rem;
		background: #15A34A;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.3s ease;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.copy-btn:hover:not(:disabled) {
		background: #166534;
	}

	.copy-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.url-description {
		font-size: 0.875rem;
		color: #64748B;
		line-height: 1.5;
	}

	.url-warning {
		color: #DC2626;
		font-weight: 500;
	}

	/* Responsive adjustments for settings */
	@media (max-width: 1024px) {
		.settings-grid {
			grid-template-columns: 1fr;
		}
	}

	@media (max-width: 768px) {
		.settings-grid {
			padding: 1rem;
			gap: 1rem;
		}

		.settings-header {
			padding: 1rem;
			flex-direction: column;
			text-align: center;
			gap: 0.75rem;
		}

		.settings-controls {
			padding: 1rem;
		}

		.setting-item {
			flex-direction: column;
			align-items: stretch;
			gap: 0.75rem;
		}

		.setting-info {
			padding-right: 0;
		}

		.url-box {
			flex-direction: column;
			align-items: stretch;
			gap: 0.75rem;
		}

		.url-box code {
			text-align: center;
			word-break: break-all;
		}
	}

	/* Responsive Design */
	@media (max-width: 768px) {
		.interface-access-manager {
			padding: 1rem;
		}

		.content-header {
			flex-direction: column;
			gap: 1rem;
			align-items: stretch;
		}

		.search-section {
			max-width: none;
		}

		.content-actions {
			justify-content: space-between;
		}

		.data-table {
			font-size: 0.875rem;
		}

		.data-table th,
		.data-table td {
			padding: 0.75rem 0.5rem;
		}

		.user-info {
			gap: 0.5rem;
		}

		.user-avatar {
			width: 32px;
			height: 32px;
			font-size: 0.75rem;
		}

		.modal-content {
			margin: 1rem;
		}

		.status-message {
			position: relative;
			top: auto;
			right: auto;
			margin: 1rem 0;
		}
	}
</style>