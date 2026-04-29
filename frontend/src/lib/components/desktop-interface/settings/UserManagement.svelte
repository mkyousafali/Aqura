<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { userManagement } from '$lib/utils/userManagement';
	import { supabase } from '$lib/utils/supabase';
	import EditUser from '$lib/components/desktop-interface/settings/user/EditUser.svelte';
	import ErpCredentialsModal from '$lib/components/desktop-interface/settings/ErpCredentialsModal.svelte';

	// Real user data from database
	let users = [];
	let branches = [];
	let employeeMasterMap = new Map(); // Map user_id to hr_employee_master name
	let loading = true;
	let error = null;

	let searchQuery = '';
	let branchFilter = '';
	let statusFilter = '';

	// ERP Credentials modal state
	let showErpCredentialsModal = false;
	let erpCredentialsUser = null;

	function openErpCredentials(user) {
		erpCredentialsUser = user;
		showErpCredentialsModal = true;
	}

	function closeErpCredentials() {
		showErpCredentialsModal = false;
		erpCredentialsUser = null;
	}

	// Change Branch modal state
	let showChangeBranchModal = false;
	let changeBranchUser = null;
	let selectedBranchId = '';
	let changeBranchLoading = false;
	let changeBranchError = '';

	// Load data from database on mount
	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		try {
			loading = true;
			error = null;

			// Load all necessary data concurrently
			const [usersResult, branchesResult, employeeMasterResult] = await Promise.all([
				userManagement.getAllUsers(),
				userManagement.getBranches(),
				loadEmployeeMasterData()
			]);

			users = usersResult;
			branches = branchesResult;

			// Create a map of user_id to employee data from hr_employee_master
			employeeMasterMap = new Map();
			if (employeeMasterResult && employeeMasterResult.length > 0) {
				employeeMasterResult.forEach(emp => {
					if (emp.user_id) {
						employeeMasterMap.set(emp.user_id, {
							id: emp.id,
							name_en: emp.name_en,
							name_ar: emp.name_ar,
							whatsapp_number: emp.whatsapp_number,
							email: emp.email
						});
					}
				});
			}

			console.log('Loaded users:', users);
			console.log('Loaded branches:', branches);
			console.log('Loaded employee master map:', employeeMasterMap);
		} catch (err) {
			console.error('Error loading user management data:', err);
			error = err.message;
		} finally {
			loading = false;
		}
	}

	async function loadEmployeeMasterData() {
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, user_id, name_en, name_ar, whatsapp_number, email');

			if (error) {
				console.error('Error loading employee master data:', error);
				return [];
			}

			return data || [];
		} catch (err) {
			console.error('Error in loadEmployeeMasterData:', err);
			return [];
		}
	}

	// Get current user from persistent auth store with null safety
	$: currentUserData = $currentUser || { isMasterAdmin: false, isAdmin: false };
	$: userIsAdmin = currentUserData?.isMasterAdmin || currentUserData?.isAdmin || false;

	// Generate unique window ID
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
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
	// Build branch list from users, keyed by branch_id to avoid duplicates
	$: uniqueBranchesMap = new Map();
	$: {
		uniqueBranchesMap.clear();
		users.forEach(user => {
			if (user.branch_id && user.branch_name) {
				uniqueBranchesMap.set(user.branch_id, user.branch_name);
			}
		});
	}
	// Convert map to array: [{ id: branchId, name: branchName }, ...]
	$: uniqueBranches = Array.from(uniqueBranchesMap.entries()).map(([id, name]) => ({ id, name }));
	
	$: uniqueStatuses = ['active', 'inactive', 'locked'];

	// Function to get employee name with fallback
	function getEmployeeName(user) {
		// First try to get from hr_employee_master via user_id mapping
		if (employeeMasterMap.has(user.id)) {
			return employeeMasterMap.get(user.id);
		}
		// Fallback to hr_employees data
		return user.employee_name || 'Not Assigned';
	}

	// Function to get employee name object with English and Arabic
	function getEmployeeNameFull(user) {
		// First try to get from hr_employee_master via user_id mapping
		const masterData = Array.from(employeeMasterMap.entries()).find(([userId]) => userId === user.id);
		if (masterData && masterData[1]) {
			return masterData[1]; // Returns the full object with id, name_en and name_ar
		}
		// Fallback to hr_employees data
		return { 
			id: null,
			name_en: user.employee_name || null, 
			name_ar: null,
			whatsapp_number: null,
			email: null
		};
	}

	// Function to get employee ID from hr_employee_master
	function getEmployeeId(user) {
		const employeeData = getEmployeeNameFull(user);
		// Return id from hr_employee_master if available, otherwise fallback to employee_code
		return employeeData.id || user.employee_code || null;
	}

	// Build branch lookup map for location info
	$: branchLocationMap = new Map(branches.map(b => [b.id.toString(), { location_en: b.location_en, location_ar: b.location_ar }]));

	// Open Change Branch modal
	function openChangeBranch(user) {
		changeBranchUser = user;
		selectedBranchId = user.branch_id ? user.branch_id.toString() : '';
		changeBranchError = '';
		showChangeBranchModal = true;
	}

	// Save branch change
	async function saveBranchChange() {
		if (!changeBranchUser || !selectedBranchId) return;

		changeBranchLoading = true;
		changeBranchError = '';

		try {
			const branchIdNum = parseInt(selectedBranchId);

			// 1. Update users table branch_id
			const { error: userError } = await supabase
				.from('users')
				.update({ branch_id: branchIdNum })
				.eq('id', changeBranchUser.id);

			if (userError) {
				throw new Error('Failed to update user branch: ' + userError.message);
			}

			// 2. Update hr_employee_master current_branch_id
			const { error: empError } = await supabase
				.from('hr_employee_master')
				.update({ current_branch_id: branchIdNum })
				.eq('user_id', changeBranchUser.id);

			if (empError) {
				console.warn('Could not update hr_employee_master:', empError.message);
			}

			// Close modal and reload data
			showChangeBranchModal = false;
			changeBranchUser = null;
			await loadData();
		} catch (err) {
			console.error('Error changing branch:', err);
			changeBranchError = err.message || 'Failed to change branch';
		} finally {
			changeBranchLoading = false;
		}
	}

	// Filtered users based on search and filters
	$: filteredUsers = users.filter(user => {
		const employeeNameObj = getEmployeeNameFull(user);
		const employeeNameEn = employeeNameObj.name_en || '';
		const employeeNameAr = employeeNameObj.name_ar || '';
		
		const matchesSearch = searchQuery === '' || 
			(user.username && user.username.toLowerCase().includes(searchQuery.toLowerCase())) ||
			(employeeNameEn && employeeNameEn.toLowerCase().includes(searchQuery.toLowerCase())) ||
			(employeeNameAr && employeeNameAr.toLowerCase().includes(searchQuery.toLowerCase())) ||
			(user.branch_name && user.branch_name.toLowerCase().includes(searchQuery.toLowerCase()));
		
		// Filter by branch_id when a filter is selected
		const matchesBranch = branchFilter === '' || (user.branch_id && user.branch_id.toString() === branchFilter.toString());
		const matchesStatus = statusFilter === '' || user.status === statusFilter;

		return matchesSearch && matchesBranch && matchesStatus;
	});
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div>
			<h1 class="text-xl font-black text-slate-800 uppercase tracking-wide">👤 User Management</h1>
			<p class="text-xs text-slate-400 font-semibold mt-0.5">Comprehensive User Account Administration</p>
		</div>
		<div class="flex items-center gap-3">
			<button class="inline-flex items-center gap-2 px-5 py-2 rounded-xl font-black text-sm text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
				on:click={loadData}>
				🔄 Refresh
			</button>
		</div>
	</div>

	<!-- Loading State -->
	{#if loading}
		<div class="flex-1 flex items-center justify-center">
			<div class="text-center">
				<div class="animate-spin inline-block">
					<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
				</div>
				<p class="mt-4 text-slate-600 font-semibold">Loading user management data...</p>
			</div>
		</div>
	{:else if error}
		<div class="flex-1 flex items-center justify-center p-8">
			<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center max-w-md">
				<div class="text-4xl mb-3">⚠️</div>
				<h3 class="text-red-800 font-black text-lg mb-2">Error Loading Data</h3>
				<p class="text-red-700 font-semibold text-sm mb-4">{error}</p>
				<button class="px-6 py-2 rounded-lg font-black text-white bg-red-600 hover:bg-red-700 hover:shadow-lg transition transform hover:scale-105" on:click={loadData}>
					🔄 Retry
				</button>
			</div>
		</div>
	{:else}
		<!-- Main Content Area -->
		<div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
			<!-- Decorative background blurs -->
			<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
			<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

			<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
				<!-- Filters Row -->
				<div class="mb-4 flex gap-3 flex-wrap items-end">
					<div class="flex-1 min-w-[250px]">
						<label for="user-search" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">🔍 Search</label>
						<input
							id="user-search"
							type="text"
							placeholder="Search by Username, Employee, Branch..."
							bind:value={searchQuery}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
						>
					</div>
					<div class="min-w-[180px]">
						<label for="branch-filter" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">🏢 Branch</label>
						<select id="branch-filter" bind:value={branchFilter} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" style="color: #000000 !important; background-color: #ffffff !important;">
							<option value="">All Branches</option>
							{#each branches as branch}
								<option value={branch.id.toString()}>{branch.name_en} - {branch.location_en}</option>
							{/each}
						</select>
					</div>
					<div class="min-w-[140px]">
						<label for="status-filter" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">📊 Status</label>
						<select id="status-filter" bind:value={statusFilter} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" style="color: #000000 !important; background-color: #ffffff !important;">
							<option value="">All Status</option>
							{#each uniqueStatuses as status}
								<option value={status}>{status.charAt(0).toUpperCase() + status.slice(1)}</option>
							{/each}
						</select>
					</div>
					{#if searchQuery || branchFilter || statusFilter}
						<button class="px-4 py-2.5 rounded-xl font-bold text-sm text-slate-700 bg-slate-200 hover:bg-slate-300 transition" on:click={() => { searchQuery = ''; branchFilter = ''; statusFilter = ''; }}>
							✕ Clear
						</button>
					{/if}
				</div>

				<!-- Users Table Card -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					{#if filteredUsers.length === 0}
						<div class="flex items-center justify-center h-64">
							<div class="text-center">
								<div class="text-5xl mb-4">📭</div>
								<p class="text-slate-600 font-semibold">No Users Found</p>
								<p class="text-slate-400 text-sm mt-2">No users match your current search and filter criteria.</p>
							</div>
						</div>
					{:else}
						<div class="overflow-auto flex-1">
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Avatar</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Username</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee ID</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">WhatsApp</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Email</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Position</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Branch</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Quick Access</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Admin Status</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Status</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Last Login</th>
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Actions</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredUsers as user, index (user.id)}
										<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<td class="px-4 py-3">
												{#if user.avatar}
													<img src={user.avatar} alt="Avatar" class="w-8 h-8 rounded-full object-cover ring-2 ring-emerald-200">
												{:else}
													<div class="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center ring-2 ring-emerald-200">
														<span class="text-sm font-black text-emerald-700">{user.username.charAt(0).toUpperCase()}</span>
													</div>
												{/if}
											</td>
											<td class="px-4 py-3">
												<span class="text-sm font-bold text-slate-800">{user.username}</span>
											</td>
											<td class="px-4 py-3">
												{#if getEmployeeNameFull(user).name_en || getEmployeeNameFull(user).name_ar}
													<div class="flex flex-col gap-0.5">
														{#if getEmployeeNameFull(user).name_en}
															<span class="text-sm font-semibold text-slate-800">{getEmployeeNameFull(user).name_en}</span>
														{/if}
														{#if getEmployeeNameFull(user).name_ar}
															<span class="text-xs text-slate-400" dir="rtl">{getEmployeeNameFull(user).name_ar}</span>
														{/if}
													</div>
												{:else}
													<span class="text-xs text-slate-400 italic">Not Assigned</span>
												{/if}
											</td>
											<td class="px-4 py-3">
												{#if getEmployeeId(user)}
													<code class="px-2 py-0.5 bg-blue-50 text-blue-700 rounded-md text-xs font-bold font-mono">{getEmployeeId(user)}</code>
												{:else}
													<span class="text-xs text-slate-400">-</span>
												{/if}
											</td>
											<td class="px-4 py-3">
												{#if getEmployeeNameFull(user).whatsapp_number}
													<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold bg-green-100 text-green-700">📱 {getEmployeeNameFull(user).whatsapp_number}</span>
												{:else}
													<span class="text-xs text-slate-400">-</span>
												{/if}
											</td>
											<td class="px-4 py-3">
												{#if getEmployeeNameFull(user).email}
													<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold bg-blue-100 text-blue-700">📧 {getEmployeeNameFull(user).email}</span>
												{:else}
													<span class="text-xs text-slate-400">-</span>
												{/if}
											</td>
											<td class="px-4 py-3 text-sm text-slate-700">
												{user.position_title || 'Not Assigned'}
											</td>
											<td class="px-4 py-3">
												{#if user.branch_name}
													<div class="flex flex-col gap-0.5">
														<span class="text-sm font-semibold text-slate-800">{user.branch_name}</span>
														{#if user.branch_id && branchLocationMap.has(user.branch_id.toString())}
															<span class="text-xs text-slate-400">{branchLocationMap.get(user.branch_id.toString()).location_en}</span>
														{/if}
														<button class="inline-flex items-center gap-1 mt-0.5 px-2 py-0.5 rounded-lg text-[10px] font-bold bg-blue-50 text-blue-600 border border-blue-200 hover:bg-blue-100 hover:shadow transition-all" on:click={() => openChangeBranch(user)}>🔄 Change</button>
													</div>
												{:else}
													<span class="text-xs text-slate-400 italic">Not Assigned</span>
													<button class="inline-flex items-center gap-1 mt-0.5 px-2 py-0.5 rounded-lg text-[10px] font-bold bg-emerald-50 text-emerald-600 border border-emerald-200 hover:bg-emerald-100 hover:shadow transition-all" on:click={() => openChangeBranch(user)}>➕ Assign</button>
												{/if}
											</td>
											<td class="px-4 py-3">
												{#if user.quick_access_code}
													<code class="px-2 py-0.5 bg-slate-100 text-slate-700 rounded-md text-xs font-bold font-mono">{user.quick_access_code}</code>
												{:else}
													<span class="text-xs text-slate-400">None</span>
												{/if}
											</td>
											<td class="px-4 py-3">
												{#if user.is_master_admin}
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-red-100 text-red-800">👑 Master Admin</span>
												{:else if user.is_admin}
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-blue-100 text-blue-800">🔑 Admin</span>
												{:else}
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-600">👤 User</span>
												{/if}
											</td>
											<td class="px-4 py-3">
												{#if user.status === 'active'}
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800">✅ Active</span>
												{:else if user.status === 'inactive'}
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-orange-100 text-orange-800">⏸️ Inactive</span>
												{:else if user.status === 'locked'}
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-red-100 text-red-800">🔒 Locked</span>
												{:else}
													<span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-600">{user.status}</span>
												{/if}
											</td>
											<td class="px-4 py-3 text-sm text-slate-600">
												{#if user.last_login}
													{new Date(user.last_login).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}
												{:else}
													<span class="text-xs text-slate-400 italic">Never</span>
												{/if}
											</td>
											<td class="px-4 py-3">
												<div class="flex items-center gap-1.5">
													<button 
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-600 text-white font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
														on:click={() => editUser(user)}
														title="Edit User"
													>✏️</button>
													<button 
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg font-bold hover:shadow-lg transition-all duration-200 transform hover:scale-110 {user.status === 'active' ? 'bg-red-600 text-white hover:bg-red-700' : 'bg-emerald-600 text-white hover:bg-emerald-700'}"
														on:click={() => toggleUserStatus(user)}
														title={user.status === 'active' ? 'Deactivate' : 'Activate'}
														disabled={user.is_master_admin}
													>{user.status === 'active' ? '🔴' : '🟢'}</button>
													<button 
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg font-bold hover:shadow-lg transition-all duration-200 transform hover:scale-110 {user.status === 'locked' ? 'bg-emerald-600 text-white hover:bg-emerald-700' : 'bg-orange-600 text-white hover:bg-orange-700'}"
														on:click={() => toggleUserLock(user)}
														title={user.status === 'locked' ? 'Unlock' : 'Lock'}
														disabled={user.is_master_admin}
													>{user.status === 'locked' ? '🔓' : '🔒'}</button>												{#if userIsAdmin}
												<button 
													class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-violet-600 text-white font-bold hover:bg-violet-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
													on:click={() => openErpCredentials(user)}
													title="Manage ERP Credentials"
													aria-label="Manage ERP Credentials"
												>🔑</button>
												{/if}												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						<!-- Table Footer -->
						<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
							Showing {filteredUsers.length} of {users.length} users
						</div>
					{/if}
				</div>
			</div>
		</div>
	{/if}
</div>

<!-- ERP Credentials Modal -->
{#if showErpCredentialsModal && erpCredentialsUser}
	<ErpCredentialsModal
		user={erpCredentialsUser}
		{branches}
		onClose={closeErpCredentials}
	/>
{/if}

<!-- Change Branch Modal -->
{#if showChangeBranchModal}
	<div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50 animate-in fade-in duration-200"
		on:click|self={() => showChangeBranchModal = false}
		on:keydown|self={(e) => { if (e.key === 'Escape') showChangeBranchModal = false; }}
		role="dialog"
		aria-modal="true"
		tabindex="-1"
	>
		<div class="bg-white rounded-3xl shadow-2xl max-w-md w-full mx-4 overflow-hidden scale-in">
			<!-- Modal Header -->
			<div class="bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-4">
				<h3 class="text-xl font-black text-white">🔄 Change Branch</h3>
				<p class="text-emerald-100 text-sm mt-1">Reassign user to a different branch</p>
			</div>
			<!-- Modal Body -->
			<div class="p-6 space-y-4">
				<div class="bg-slate-50 rounded-xl p-4 space-y-2">
					<div class="flex justify-between items-center">
						<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">User</span>
						<span class="text-sm font-bold text-slate-800">{changeBranchUser?.username}</span>
					</div>
					<div class="flex justify-between items-center">
						<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">Current Branch</span>
						<span class="text-sm font-bold text-slate-800">{changeBranchUser?.branch_name || 'Not Assigned'}</span>
					</div>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2" for="branch-select">Select New Branch</label>
					<select id="branch-select" bind:value={selectedBranchId} class="w-full px-4 py-2.5 bg-white border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" style="color: #000000 !important; background-color: #ffffff !important;">
						<option value="">-- Select Branch --</option>
						{#each branches as branch}
							<option value={branch.id.toString()}>{branch.name_en} - {branch.location_en}</option>
						{/each}
					</select>
				</div>
				{#if changeBranchError}
					<div class="bg-red-50 border border-red-200 rounded-lg px-4 py-2 text-sm text-red-700 font-semibold">{changeBranchError}</div>
				{/if}
			</div>
			<!-- Modal Footer -->
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
				<button class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition" on:click={() => showChangeBranchModal = false} disabled={changeBranchLoading}>Cancel</button>
				<button class="px-6 py-2 rounded-lg font-black text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed" on:click={saveBranchChange} disabled={changeBranchLoading || !selectedBranchId}>
					{changeBranchLoading ? '⏳ Saving...' : '✅ Save'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to { opacity: 1; transform: scale(1); }
	}

	.animate-in {
		animation: fadeIn 0.2s ease-out;
	}

	.scale-in {
		animation: scaleIn 0.3s ease-out;
	}
</style>