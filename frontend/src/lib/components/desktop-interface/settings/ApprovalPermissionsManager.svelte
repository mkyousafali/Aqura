<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { notificationService } from '$lib/utils/notificationManagement';
	import { currentUser } from '$lib/utils/persistentAuth';

	let users: any[] = [];
	let loading = false;
	let saving = false;
	let searchQuery = '';
	let statusFilter = 'all';
	let permissionFilter = 'all';

	// Tab state
	let activeTab: 'permissions' | 'default-users' = 'permissions';

	// Default incident users tab
	let defaultIncidentUsers: any[] = [];
	let incidentTypes: any[] = [];
	let showAssignPopup = false;
	let assignIncidentTypeId = '';
	let assignSearchQuery = '';
	let savingDefault = false;
	let localAssignedUserIds: Set<string> = new Set();
	let showAssignSuccess = false;
	let assignSuccessMessage = '';

	// Incident type config for display
	const incidentTypeConfig: Record<string, { label: string; icon: string; color: string }> = {
		'IN1': { label: 'Customer Incidents', icon: '🛍️', color: 'blue' },
		'IN2': { label: 'Employee Incidents', icon: '👤', color: 'emerald' },
		'IN3': { label: 'Maintenance Incidents', icon: '🔧', color: 'amber' },
		'IN4': { label: 'Vendor Incidents', icon: '🤝', color: 'purple' },
		'IN5': { label: 'Vehicle Incidents', icon: '🚗', color: 'sky' },
		'IN6': { label: 'Government Incidents', icon: '🏛️', color: 'slate' },
		'IN7': { label: 'Other Incidents', icon: '📌', color: 'gray' },
		'IN8': { label: 'Finance Incidents', icon: '💼', color: 'indigo' },
		'IN9': { label: 'Customer/POS Incidents', icon: '🛒', color: 'rose' },
	};

	// Branches for default users tab (kept for potential use)
	let branches: any[] = [];
	let branchSearchQuery = '';
	let selectedBranchId = '';
	let savingBranch = false;

	// Manage popup state
	let showManagePopup = false;
	let managingUser: any = null;
	let localPermissions: any = {};

	// Copy from user state
	let showCopyPopup = false;
	let copyTargetUser: any = null;
	let copySourceUserId = '';
	let copySearchQuery = '';
	let copying = false;

	$: isMasterAdmin = $currentUser?.isMasterAdmin;

	const permissionSections = [
		{
			title: 'Financial Approvals',
			icon: '💰',
			color: 'blue',
			permissions: [
				{ key: 'can_approve_requisitions', label: 'Approve Requisitions', amountKey: 'requisition_amount_limit', icon: '📋' },
				{ key: 'can_approve_single_bill', label: 'Approve Single Bill', amountKey: 'single_bill_amount_limit', icon: '📄' },
				{ key: 'can_approve_multiple_bill', label: 'Approve Multiple Bill', amountKey: 'multiple_bill_amount_limit', icon: '📑' },
				{ key: 'can_approve_recurring_bill', label: 'Approve Recurring Bill', amountKey: 'recurring_bill_amount_limit', icon: '🔄' },
				{ key: 'can_approve_vendor_payments', label: 'Approve Vendor Payments', amountKey: 'vendor_payment_amount_limit', icon: '💳' },
			]
		},
		{
			title: 'HR Approvals',
			icon: '👥',
			color: 'emerald',
			permissions: [
				{ key: 'can_approve_leave_requests', label: 'Approve Leave Requests', icon: '🏖️' },
				{ key: 'can_approve_purchase_vouchers', label: 'Approve Purchase Vouchers', icon: '🎫' },
				{ key: 'can_add_missing_punches', label: 'Add Missing Punches', icon: '⏱️' },
			]
		},
		{
			title: 'Incident Receivers',
			icon: '🚨',
			color: 'orange',
			permissions: [
				{ key: 'can_receive_customer_incidents', label: 'Customer Incidents', icon: '🛍️' },
				{ key: 'can_receive_employee_incidents', label: 'Employee Incidents', icon: '👤' },
				{ key: 'can_receive_maintenance_incidents', label: 'Maintenance Incidents', icon: '🔧' },
				{ key: 'can_receive_vendor_incidents', label: 'Vendor Incidents', icon: '🤝' },
				{ key: 'can_receive_vehicle_incidents', label: 'Vehicle Incidents', icon: '🚗' },
				{ key: 'can_receive_government_incidents', label: 'Government Incidents', icon: '🏛️' },
				{ key: 'can_receive_other_incidents', label: 'Other Incidents', icon: '📌' },
				{ key: 'can_receive_finance_incidents', label: 'Finance Incidents', icon: '💼' },
				{ key: 'can_receive_pos_incidents', label: 'Customer/POS Incidents', icon: '🛒' },
			]
		}
	];

	let defaultChannel: any = null;

	onMount(async () => {
		if (!isMasterAdmin) {
			alert('Access Denied: Master Admin role required');
			return;
		}
		await Promise.all([loadUsersWithPermissions(), loadBranches(), loadIncidentTypes(), loadDefaultIncidentUsers()]);

		// Subscribe to realtime changes on default_incident_users
		defaultChannel = supabase
			.channel('default_incident_users_changes')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'default_incident_users' }, () => {
				loadDefaultIncidentUsers();
			})
			.subscribe();
	});

	onDestroy(() => {
		if (defaultChannel) {
			supabase.removeChannel(defaultChannel);
		}
	});

	async function loadUsersWithPermissions() {
		try {
			loading = true;

			const { data: usersData, error: usersError } = await supabase
				.from('users')
				.select('id, username, status, employee_id, branch_id')
				.order('username');

			if (usersError) throw usersError;

			const employeeIds = usersData?.filter((u) => u.employee_id).map((u) => u.employee_id) || [];
			let employeeNames: any = {};

			if (employeeIds.length > 0) {
				const { data: employeesData, error: empError } = await supabase
					.from('hr_employees')
					.select('id, name');

				if (!empError && employeesData) {
					employeesData.forEach((emp) => {
						if (employeeIds.includes(emp.id)) {
							employeeNames[emp.id] = emp.name;
						}
					});
				}
			}

			const { data: permissionsData, error: permError } = await supabase
				.from('approval_permissions')
				.select('*');

			if (permError && permError.code !== 'PGRST116') {
				throw permError;
			}

			users = (usersData || []).map((user) => {
				const userPerm = permissionsData?.find((p) => p.user_id === user.id);
				return {
					...user,
					employee_name: user.employee_id ? employeeNames[user.employee_id] : null,
					branch_id: user.branch_id || null,
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
						can_receive_customer_incidents: false,
						can_receive_employee_incidents: false,
						can_receive_maintenance_incidents: false,
						can_receive_vendor_incidents: false,
						can_receive_vehicle_incidents: false,
						can_receive_government_incidents: false,
						can_receive_other_incidents: false,
						can_receive_finance_incidents: false,
						can_receive_pos_incidents: false,
						is_active: true
					}
				};
			});
		} catch (err: any) {
			console.error('Error loading users:', err);
			alert('Error loading users: ' + err.message);
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
				can_receive_customer_incidents: user.permissions.can_receive_customer_incidents === true,
				can_receive_employee_incidents: user.permissions.can_receive_employee_incidents === true,
				can_receive_maintenance_incidents: user.permissions.can_receive_maintenance_incidents === true,
				can_receive_vendor_incidents: user.permissions.can_receive_vendor_incidents === true,
				can_receive_vehicle_incidents: user.permissions.can_receive_vehicle_incidents === true,
				can_receive_government_incidents: user.permissions.can_receive_government_incidents === true,
				can_receive_other_incidents: user.permissions.can_receive_other_incidents === true,
				can_receive_finance_incidents: user.permissions.can_receive_finance_incidents === true,
				can_receive_pos_incidents: user.permissions.can_receive_pos_incidents === true,
				is_active: user.permissions.is_active === true
			};

			const { data: existingPerm, error: checkError } = await supabase
				.from('approval_permissions')
				.select('id')
				.eq('user_id', user.id)
				.maybeSingle();

			if (checkError && checkError.code !== 'PGRST116') {
				throw checkError;
			}

			let updateError;
			if (existingPerm) {
				const { error: err } = await supabase
					.from('approval_permissions')
					.update({
						...permissionData,
						updated_by: $currentUser?.id
					})
					.eq('user_id', user.id);
				updateError = err;
			} else {
				const { error: err } = await supabase
					.from('approval_permissions')
					.insert([{
						user_id: user.id,
						...permissionData,
						updated_at: new Date().toISOString(),
						created_by: $currentUser?.id,
						updated_by: $currentUser?.id
					}]);
				updateError = err;
			}

			if (updateError) throw updateError;

			// Send notification
			try {
				const permissionsList: string[] = [];
				permissionSections.forEach(section => {
					section.permissions.forEach(perm => {
						if (user.permissions[perm.key]) {
							let label = perm.label;
							if ('amountKey' in perm && perm.amountKey) {
								const limit = user.permissions[perm.amountKey];
								label += limit > 0 ? ` (${limit.toLocaleString()} SAR)` : ' (Unlimited)';
							}
							permissionsList.push(label);
						}
					});
				});

				const message = permissionsList.length > 0
					? `Your approval permissions have been updated:\n\n${permissionsList.join('\n')}`
					: 'Your approval permissions have been removed.';

				await notificationService.createNotification({
					title: 'Approval Permissions Updated',
					message,
					type: 'info',
					priority: 'medium',
					target_type: 'specific_users',
					target_users: [user.id]
				}, $currentUser?.username || 'System');
			} catch (notifErr) {
				console.error('Failed to send notification:', notifErr);
			}

			// Refresh the user row
			const { data: updatedPerm, error: refreshErr } = await supabase
				.from('approval_permissions')
				.select('*')
				.eq('user_id', user.id)
				.single();

			if (!refreshErr && updatedPerm) {
				const userIndex = users.findIndex(u => u.id === user.id);
				if (userIndex !== -1) {
					users[userIndex].permissions = updatedPerm;
					users = [...users];
				}
			}
		} catch (err: any) {
			console.error('Error saving permissions:', err);
			alert('Error saving: ' + err.message);
		} finally {
			saving = false;
		}
	}

	function toggleLocalPermission(field: string) {
		localPermissions[field] = !localPermissions[field];
		localPermissions = { ...localPermissions };
	}

	function updateLocalAmountLimit(field: string, value: number) {
		localPermissions[field] = value;
		localPermissions = { ...localPermissions };
	}

	function getDisplayName(user: any): string {
		if (user.employee_name) return `${user.username} (${user.employee_name})`;
		return user.username;
	}

	function countPermissions(user: any): number {
		let count = 0;
		permissionSections.forEach(section => {
			section.permissions.forEach(perm => {
				if (user.permissions[perm.key]) count++;
			});
		});
		return count;
	}

	function getPermissionSummary(user: any): string[] {
		const active: string[] = [];
		permissionSections.forEach(section => {
			section.permissions.forEach(perm => {
				if (user.permissions[perm.key]) active.push(perm.icon);
			});
		});
		return active;
	}

	function openManagePopup(user: any) {
		managingUser = user;
		localPermissions = { ...user.permissions };
		showManagePopup = true;
	}

	function closeManagePopup() {
		showManagePopup = false;
		managingUser = null;
		localPermissions = {};
	}

	$: hasChanges = (() => {
		if (!managingUser) return false;
		const orig = managingUser.permissions;
		for (const section of permissionSections) {
			for (const perm of section.permissions) {
				if (!!localPermissions[perm.key] !== !!orig[perm.key]) return true;
				if ('amountKey' in perm && perm.amountKey) {
					if ((parseFloat(localPermissions[perm.amountKey]) || 0) !== (parseFloat(orig[perm.amountKey]) || 0)) return true;
				}
			}
		}
		return false;
	})();

	function countLocalPermissions(): number {
		let count = 0;
		permissionSections.forEach(section => {
			section.permissions.forEach(perm => {
				if (localPermissions[perm.key]) count++;
			});
		});
		return count;
	}

	async function saveManagePopup() {
		if (!managingUser) return;
		// Apply local permissions to the user
		const allPermKeys = permissionSections.flatMap(s => s.permissions.flatMap(p => {
			const keys = [p.key];
			if ('amountKey' in p && p.amountKey) keys.push(p.amountKey);
			return keys;
		}));
		allPermKeys.forEach(key => {
			managingUser.permissions[key] = localPermissions[key];
		});
		users = [...users];
		await saveUserPermissions(managingUser);
		closeManagePopup();
	}

	function openCopyPopup(user: any) {
		copyTargetUser = user;
		copySourceUserId = '';
		copySearchQuery = '';
		showCopyPopup = true;
	}

	function closeCopyPopup() {
		showCopyPopup = false;
		copyTargetUser = null;
		copySourceUserId = '';
		copySearchQuery = '';
	}

	$: copyFilteredUsers = users.filter(u => {
		if (!copyTargetUser || u.id === copyTargetUser.id) return false;
		if (!copySearchQuery) return true;
		const q = copySearchQuery.toLowerCase();
		return u.username.toLowerCase().includes(q) || u.employee_name?.toLowerCase().includes(q);
	});

	async function copyPermissions() {
		if (!copySourceUserId || !copyTargetUser) return;
		copying = true;

		try {
			const sourceUser = users.find(u => u.id === copySourceUserId);
			if (!sourceUser) throw new Error('Source user not found');

			const allPermKeys = permissionSections.flatMap(s => s.permissions.flatMap(p => {
				const keys = [p.key];
				if ('amountKey' in p && p.amountKey) keys.push(p.amountKey);
				return keys;
			}));

			allPermKeys.forEach(key => {
				copyTargetUser.permissions[key] = sourceUser.permissions[key];
			});

			users = [...users];
			await saveUserPermissions(copyTargetUser);
			closeCopyPopup();
		} catch (err: any) {
			console.error('Error copying permissions:', err);
			alert('Error copying: ' + err.message);
		} finally {
			copying = false;
		}
	}

	$: filteredUsers = users.filter((user) => {
		const searchLower = searchQuery.toLowerCase();
		const matchesSearch =
			searchQuery === '' ||
			user.username.toLowerCase().includes(searchLower) ||
			user.employee_name?.toLowerCase().includes(searchLower);

		const matchesStatus =
			statusFilter === 'all' ||
			(statusFilter === 'active' && user.status === 'active') ||
			(statusFilter === 'inactive' && user.status !== 'active');

		const hasPerms = countPermissions(user) > 0;
		const matchesPermission =
			permissionFilter === 'all' ||
			(permissionFilter === 'with-permissions' && hasPerms) ||
			(permissionFilter === 'without-permissions' && !hasPerms);

		return matchesSearch && matchesStatus && matchesPermission;
	});

	// ===== Default Incident Users Assignment Tab =====
	async function loadIncidentTypes() {
		try {
			const { data, error } = await supabase
				.from('incident_types')
				.select('id, incident_type_en, incident_type_ar, is_active')
				.eq('is_active', true)
				.order('id');
			if (!error && data) {
				incidentTypes = data;
			}
		} catch (err) {
			console.error('Error loading incident types:', err);
		}
	}

	async function loadDefaultIncidentUsers() {
		try {
			const { data, error } = await supabase
				.from('default_incident_users')
				.select('*');
			if (!error && data) {
				defaultIncidentUsers = data;
			}
		} catch (err) {
			console.error('Error loading default incident users:', err);
		}
	}

	function getDefaultUsersForType(typeId: string): any[] {
		const assignedUserIds = defaultIncidentUsers
			.filter(d => d.incident_type_id === typeId)
			.map(d => d.user_id);
		return users.filter(u => assignedUserIds.includes(u.id));
	}

	function getAvailableUsersForType(typeId: string): any[] {
		const assignedUserIds = defaultIncidentUsers
			.filter(d => d.incident_type_id === typeId)
			.map(d => d.user_id);
		return users.filter(u => !assignedUserIds.includes(u.id) && u.status === 'active');
	}

	function openAssignPopup(typeId: string) {
		assignIncidentTypeId = typeId;
		assignSearchQuery = '';
		// Populate local state from current DB
		const currentIds = defaultIncidentUsers
			.filter(d => d.incident_type_id === typeId)
			.map(d => d.user_id);
		localAssignedUserIds = new Set(currentIds);
		showAssignPopup = true;
	}

	function closeAssignPopup() {
		showAssignPopup = false;
		assignIncidentTypeId = '';
		assignSearchQuery = '';
		localAssignedUserIds = new Set();
	}

	function toggleAssignUser(userId: string) {
		if (localAssignedUserIds.has(userId)) {
			localAssignedUserIds.delete(userId);
		} else {
			localAssignedUserIds.add(userId);
		}
		localAssignedUserIds = new Set(localAssignedUserIds);
	}

	$: assignHasChanges = (() => {
		if (!assignIncidentTypeId) return false;
		const currentIds = new Set(defaultIncidentUsers
			.filter(d => d.incident_type_id === assignIncidentTypeId)
			.map(d => d.user_id));
		if (currentIds.size !== localAssignedUserIds.size) return true;
		for (const id of localAssignedUserIds) {
			if (!currentIds.has(id)) return true;
		}
		return false;
	})();

	async function saveAssignPopup() {
		if (!assignIncidentTypeId) return;
		try {
			savingDefault = true;
			const currentIds = new Set(defaultIncidentUsers
				.filter(d => d.incident_type_id === assignIncidentTypeId)
				.map(d => d.user_id));

			// Users to add
			const toAdd = [...localAssignedUserIds].filter(id => !currentIds.has(id));
			// Users to remove
			const toRemove = [...currentIds].filter(id => !localAssignedUserIds.has(id));

			// Batch insert
			if (toAdd.length > 0) {
				const inserts = toAdd.map(uid => ({ user_id: uid, incident_type_id: assignIncidentTypeId, created_by: $currentUser?.id }));
				const { error } = await supabase.from('default_incident_users').upsert(inserts, { onConflict: 'user_id,incident_type_id' });
				if (error) throw error;
			}

			// Batch delete
			if (toRemove.length > 0) {
				const { error } = await supabase.from('default_incident_users').delete()
					.eq('incident_type_id', assignIncidentTypeId)
					.in('user_id', toRemove);
				if (error) throw error;
			}

			await loadDefaultIncidentUsers();

			const typeName = incidentTypes.find(t => t.id === assignIncidentTypeId)?.incident_type_en || assignIncidentTypeId;
			assignSuccessMessage = `Default users for "${typeName}" updated successfully. Added: ${toAdd.length}, Removed: ${toRemove.length}`;
			closeAssignPopup();
			showAssignSuccess = true;
			setTimeout(() => { showAssignSuccess = false; }, 3000);
		} catch (err: any) {
			console.error('Error saving default users:', err);
			alert('Error: ' + err.message);
		} finally {
			savingDefault = false;
		}
	}

	$: assignFilteredUsers = (() => {
		const activeUsers = users.filter(u => u.status === 'active');
		if (!assignSearchQuery) return activeUsers;
		const q = assignSearchQuery.toLowerCase();
		return activeUsers.filter(u => u.username.toLowerCase().includes(q) || u.employee_name?.toLowerCase().includes(q));
	})();

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar, is_active')
				.order('name_en');
			if (!error && data) {
				branches = data;
			}
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	function getBranchName(branch: any): string {
		return `${branch.name_en}${branch.location_en ? ' - ' + branch.location_en : ''}`;
	}

	function getUsersForBranch(branchId: string): any[] {
		return users.filter(u => String(u.branch_id) === String(branchId) && u.status === 'active');
	}

	function getPermittedUsersNotInBranch(branchId: string): any[] {
		return users.filter(u => String(u.branch_id) !== String(branchId) && u.status === 'active' && countPermissions(u) > 0);
	}

	async function assignUserToBranch(userId: string, branchId: string) {
		try {
			savingBranch = true;
			const { error } = await supabase
				.from('users')
				.update({ branch_id: branchId })
				.eq('id', userId);
			if (error) throw error;

			// Update local state
			const idx = users.findIndex(u => u.id === userId);
			if (idx !== -1) {
				users[idx].branch_id = branchId;
				users = [...users];
			}
		} catch (err: any) {
			console.error('Error assigning user to branch:', err);
			alert('Error: ' + err.message);
		} finally {
			savingBranch = false;
		}
	}

	async function removeUserFromBranch(userId: string) {
		try {
			savingBranch = true;
			const { error } = await supabase
				.from('users')
				.update({ branch_id: null })
				.eq('id', userId);
			if (error) throw error;

			const idx = users.findIndex(u => u.id === userId);
			if (idx !== -1) {
				users[idx].branch_id = null;
				users = [...users];
			}
		} catch (err: any) {
			console.error('Error removing user from branch:', err);
			alert('Error: ' + err.message);
		} finally {
			savingBranch = false;
		}
	}

	$: filteredBranches = branches.filter(b => {
		if (!branchSearchQuery) return true;
		const q = branchSearchQuery.toLowerCase();
		return b.name_en?.toLowerCase().includes(q) || b.name_ar?.includes(q) || b.location_en?.toLowerCase().includes(q);
	});
</script>

<div class="h-full flex flex-col gap-2 p-2">
	{#if !isMasterAdmin}
		<div class="bg-red-100 border-2 border-red-300 rounded-2xl p-6 text-center text-red-800 font-semibold">
			Access Denied: Master Admin role required
		</div>
	{:else if loading}
		<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center">
			<div class="animate-spin inline-block">
				<div class="w-12 h-12 border-4 border-red-200 border-t-red-600 rounded-full"></div>
			</div>
			<p class="text-slate-500 mt-4 font-semibold">Loading users...</p>
		</div>
	{:else}
		<!-- Tab Buttons (ShiftAndDayOff style) -->
		<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm rounded-2xl">
			<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
				<button
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wider transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === 'permissions'
						? 'bg-red-600 text-white shadow-lg shadow-red-200 scale-[1.02]'
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => { activeTab = 'permissions'; }}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🛡️</span>
					<span class="relative z-10">Approval Permissions</span>
					{#if activeTab === 'permissions'}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
				<button
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wider transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === 'default-users'
						? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => { activeTab = 'default-users'; }}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🏢</span>
					<span class="relative z-10">Default Users Assignment</span>
					{#if activeTab === 'default-users'}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
			</div>
		</div>

		{#if activeTab === 'permissions'}
		<!-- ===== APPROVAL PERMISSIONS TAB ===== -->
		<!-- Header Bar -->
		<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] px-4 py-3">
			<div class="flex items-center justify-between flex-wrap gap-3">
				<div class="flex items-center gap-3">
					<div class="bg-gradient-to-br from-red-600 to-rose-700 rounded-xl p-2 shadow-lg">
						<svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
						</svg>
					</div>
					<h2 class="text-lg font-black text-slate-800">Approval Permissions</h2>
					<div class="flex items-center gap-2">
						<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-100 text-slate-800 text-xs font-black">{users.length} Users</span>
						<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-100 text-emerald-800 text-xs font-black">{users.filter(u => countPermissions(u) > 0).length} With Perms</span>
					</div>
				</div>
			</div>
		</div>

		<!-- Search + Filters Row -->
		<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] px-4 py-2">
			<div class="flex items-center gap-3 flex-wrap">
				<div class="relative flex-1 min-w-[200px]">
					<input
						type="text"
						bind:value={searchQuery}
						placeholder="Search by username or name..."
						class="w-full pl-8 pr-4 py-2 bg-white/80 border border-slate-200 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent text-xs font-medium text-slate-700 placeholder-slate-400"
					/>
					<svg class="absolute left-2.5 top-2.5 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
					</svg>
				</div>
				<select bind:value={statusFilter} class="px-3 py-2 bg-white/80 border border-slate-200 rounded-lg text-xs font-medium text-slate-700 focus:ring-2 focus:ring-red-500">
					<option value="all">All Status</option>
					<option value="active">Active Only</option>
					<option value="inactive">Inactive Only</option>
				</select>
				<select bind:value={permissionFilter} class="px-3 py-2 bg-white/80 border border-slate-200 rounded-lg text-xs font-medium text-slate-700 focus:ring-2 focus:ring-red-500">
					<option value="all">All Users</option>
					<option value="with-permissions">With Permissions</option>
					<option value="without-permissions">Without Permissions</option>
				</select>
				<span class="text-[11px] font-semibold text-slate-400 whitespace-nowrap">
					{filteredUsers.length}/{users.length}
				</span>
			</div>
		</div>

		<!-- Users Table -->
		<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
			<div class="overflow-x-auto flex-1 max-h-[calc(100vh-220px)] overflow-y-auto">
				<table class="w-full border-collapse [&_th]:border-x [&_th]:border-red-500/30 [&_td]:border-x [&_td]:border-slate-200">
					<thead class="sticky top-0 bg-red-600 text-white shadow-lg z-10">
						<tr>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-red-400 w-10">#</th>
							<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-red-400">User</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-red-400 w-20">Status</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-red-400">Permissions</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-red-400 w-48">Actions</th>
						</tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
						{#each filteredUsers as user, index (user.id)}
							<tr class="hover:bg-red-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {user.status !== 'active' ? 'opacity-50' : ''}">
								<td class="px-3 py-2 text-center text-xs font-bold text-slate-400">{index + 1}</td>
								<td class="px-4 py-2 text-sm text-slate-700">
									<div class="font-bold text-slate-800">{user.username}</div>
									{#if user.employee_name}
										<div class="text-xs text-slate-400">{user.employee_name}</div>
									{/if}
								</td>
								<td class="px-4 py-2 text-center">
									<span class="inline-block px-2 py-0.5 rounded-md text-[10px] font-black {user.status === 'active' ? 'bg-emerald-200 text-emerald-800' : 'bg-slate-200 text-slate-600'}">
										{user.status === 'active' ? 'Active' : 'Inactive'}
									</span>
								</td>
								<td class="px-4 py-2 text-center">
									{#if countPermissions(user) > 0}
										<span class="inline-block px-2 py-0.5 rounded-md text-[10px] font-black bg-blue-600 text-white">{countPermissions(user)}</span>
									{:else}
										<span class="text-xs text-slate-400">0</span>
									{/if}
								</td>
								<td class="px-4 py-2 text-center">
									<div class="flex items-center justify-center gap-1">
										<button
											on:click={() => openManagePopup(user)}
											class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-blue-600 text-white text-[11px] font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 gap-1"
											title="Manage permissions for {user.username}"
										>
											Manage
										</button>
										<button
											on:click={() => openCopyPopup(user)}
											class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-purple-600 text-white text-[11px] font-bold hover:bg-purple-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 gap-1"
											title="Copy permissions from another user"
										>
											Copy From
										</button>
									</div>
								</td>
							</tr>
						{:else}
							<tr>
								<td colspan="5" class="px-6 py-12 text-center text-slate-400 text-sm">No users found matching filters</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
				Total Users: {users.length} | Showing: {filteredUsers.length} | With Permissions: {users.filter(u => countPermissions(u) > 0).length}
			</div>
		</div>

		{:else if activeTab === 'default-users'}
		<!-- ===== DEFAULT USERS ASSIGNMENT TAB ===== -->
		<!-- Header Bar -->
		<div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.06)] px-4 py-3">
			<div class="flex items-center justify-between flex-wrap gap-3">
				<div class="flex items-center gap-3">
					<div class="bg-gradient-to-br from-emerald-600 to-emerald-700 rounded-xl p-2 shadow-lg">
						<svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
						</svg>
					</div>
					<h2 class="text-lg font-black text-slate-800">Default Incident Users</h2>
					<div class="flex items-center gap-2">
						<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-100 text-slate-800 text-xs font-black">{incidentTypes.length} Types</span>
						<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-emerald-100 text-emerald-800 text-xs font-black">{defaultIncidentUsers.length} Assigned</span>
					</div>
				</div>
			</div>
		</div>

		<!-- Incident Types Table -->
		<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
			<div class="overflow-x-auto flex-1 max-h-[calc(100vh-220px)] overflow-y-auto">
				<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
					<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
						<tr>
							<th class="px-3 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400 w-10">#</th>
							<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Incident Type</th>
							<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Default Assigned Users</th>
							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400 w-36">Actions</th>
						</tr>
					</thead>
					<tbody class="divide-y divide-slate-200">
						{#each incidentTypes as type, index (type.id)}
							<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
								<td class="px-3 py-2 text-center text-xs font-bold text-slate-400">{index + 1}</td>
								<td class="px-4 py-2 text-sm text-slate-700">
									<div class="flex items-center gap-2">
										<span class="text-base">{incidentTypeConfig[type.id]?.icon || '📋'}</span>
										<div>
											<div class="font-bold text-slate-800">{type.incident_type_en}</div>
											{#if type.incident_type_ar}
												<div class="text-xs text-slate-400">{type.incident_type_ar}</div>
											{/if}
										</div>
									</div>
								</td>
								<td class="px-4 py-2">
									{#if users.filter(u => defaultIncidentUsers.some(d => d.incident_type_id === type.id && d.user_id === u.id)).length > 0}
										<div class="flex flex-wrap gap-1">
											{#each users.filter(u => defaultIncidentUsers.some(d => d.incident_type_id === type.id && d.user_id === u.id)) as user}
												<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-emerald-100 text-emerald-800 border border-emerald-200">
													{user.username}
													{#if user.employee_name}
														<span class="text-emerald-500">({user.employee_name})</span>
													{/if}
												</span>
											{/each}
										</div>
									{:else}
										<span class="text-xs text-slate-400 italic">No default users</span>
									{/if}
								</td>
								<td class="px-4 py-2 text-center">
									<button
										on:click={() => openAssignPopup(type.id)}
										class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-[11px] font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 gap-1"
										title="Manage default users for {type.incident_type_en}"
									>
										Manage
									</button>
								</td>
							</tr>
						{:else}
							<tr>
								<td colspan="4" class="px-6 py-12 text-center text-slate-400 text-sm">No incident types found</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
				Total Types: {incidentTypes.length} | Assigned: {defaultIncidentUsers.length}
			</div>
		</div>
		{/if}
	{/if}

	<!-- Manage Permissions Popup -->
	{#if showManagePopup && managingUser}
		<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_interactive_supports_focus -->
		<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4" on:click={closeManagePopup}>
			<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_interactive_supports_focus -->
			<div class="bg-white rounded-2xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden flex flex-col" on:click|stopPropagation>
				<!-- Popup Header -->
				<div class="bg-black px-6 py-4 flex items-center justify-between">
					<div>
						<h3 class="text-lg font-black text-white">Manage Permissions</h3>
						<p class="text-white/80 text-sm mt-0.5">
							{managingUser.username}
							{#if managingUser.employee_name}
								<span class="text-white/60">({managingUser.employee_name})</span>
							{/if}
						</p>
					</div>
					<div class="flex items-center gap-2">
						{#if saving}
							<span class="text-white/80 text-xs font-semibold animate-pulse">Saving...</span>
						{/if}
						<button on:click={closeManagePopup} class="w-8 h-8 rounded-lg bg-white/20 text-white hover:bg-white/30 flex items-center justify-center transition-colors font-bold text-lg">&times;</button>
					</div>
				</div>

				<!-- Permissions Content -->
				<div class="flex-1 overflow-y-auto p-4 space-y-4">
					{#each permissionSections as section}
						<div class="border border-slate-200 rounded-xl overflow-hidden">
							<!-- Section Header -->
							<div class="px-4 py-2.5 border-b border-slate-200 {section.color === 'blue' ? 'bg-gradient-to-r from-blue-50 to-blue-100' : section.color === 'emerald' ? 'bg-gradient-to-r from-emerald-50 to-emerald-100' : 'bg-gradient-to-r from-orange-50 to-orange-100'}">
								<h4 class="text-sm font-black {section.color === 'blue' ? 'text-blue-800' : section.color === 'emerald' ? 'text-emerald-800' : 'text-orange-800'}">
									{section.icon} {section.title}
								</h4>
							</div>

							<!-- Permission Rows -->
							<div class="divide-y divide-slate-100">
								{#each section.permissions as perm}
									<label class="px-4 py-3 flex items-center justify-between gap-3 hover:bg-slate-50/50 transition-colors cursor-pointer">
										<div class="flex items-center gap-3 flex-1">
											<!-- Checkbox -->
											<input
												type="checkbox"
												checked={localPermissions[perm.key] || false}
												on:change={() => toggleLocalPermission(perm.key)}
												disabled={saving}
												class="w-5 h-5 rounded border-2 border-slate-300 text-blue-600 focus:ring-blue-500 focus:ring-2 cursor-pointer accent-blue-600"
											/>
											<span class="text-base">{perm.icon}</span>
											<span class="text-sm font-semibold {localPermissions[perm.key] ? 'text-slate-800' : 'text-slate-500'}">{perm.label}</span>
										</div>
										{#if 'amountKey' in perm && perm.amountKey && localPermissions[perm.key]}
											<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
											<div class="flex items-center gap-1 bg-blue-50 border border-blue-200 rounded-lg px-2 py-1" on:click|stopPropagation>
												<span class="text-[10px] font-bold text-blue-600">SAR</span>
												<input
													type="number"
													value={localPermissions[perm.amountKey] || 0}
													on:input={(e) => updateLocalAmountLimit(perm.amountKey, parseFloat((e.target as HTMLInputElement).value) || 0)}
													min="0"
													step="0.01"
													class="w-24 px-2 py-0.5 bg-transparent border-none text-sm font-bold text-blue-800 focus:outline-none text-right"
													placeholder="0 = unlimited"
													disabled={saving}
												/>
											</div>
										{/if}
									</label>
								{/each}
							</div>
						</div>
					{/each}
				</div>

				<!-- Footer -->
				<div class="px-6 py-3 bg-slate-50 border-t border-slate-200 flex items-center justify-between">
					<span class="text-xs font-semibold {hasChanges ? 'text-amber-600' : 'text-slate-500'}">
						{countLocalPermissions()} permissions selected
						{#if hasChanges}
							<span class="ml-1 text-amber-500">• unsaved changes</span>
						{/if}
					</span>
					<div class="flex items-center gap-2">
						<button on:click={closeManagePopup} class="px-4 py-1.5 bg-slate-200 text-slate-700 rounded-lg text-xs font-bold hover:bg-slate-300 transition-colors">Cancel</button>
						<button
							on:click={saveManagePopup}
							disabled={!hasChanges || saving}
							class="px-5 py-1.5 bg-blue-600 text-white rounded-lg text-xs font-bold hover:bg-blue-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1.5 shadow-md hover:shadow-lg"
						>
							{#if saving}
								<svg class="animate-spin w-3.5 h-3.5" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
								Saving...
							{:else}
								✅ Update Permissions
							{/if}
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Copy From User Popup -->
	{#if showCopyPopup && copyTargetUser}
		<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_interactive_supports_focus -->
		<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4" on:click={closeCopyPopup}>
			<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_interactive_supports_focus -->
			<div class="bg-white rounded-2xl shadow-2xl max-w-md w-full max-h-[80vh] overflow-hidden flex flex-col" on:click|stopPropagation>
				<!-- Header -->
				<div class="bg-black px-6 py-4 flex items-center justify-between">
					<div>
						<h3 class="text-lg font-black text-white">Copy Permissions</h3>
						<p class="text-white/80 text-sm mt-0.5">
							To: <span class="font-bold text-white">{copyTargetUser.username}</span>
						</p>
					</div>
					<button on:click={closeCopyPopup} class="w-8 h-8 rounded-lg bg-white/20 text-white hover:bg-white/30 flex items-center justify-center transition-colors font-bold text-lg">&times;</button>
				</div>

				<!-- Search & Select -->
				<div class="p-4 space-y-3 flex-1 overflow-hidden flex flex-col">
					<div class="relative">
						<input
							type="text"
							bind:value={copySearchQuery}
							placeholder="Search source user..."
							class="w-full pl-8 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent text-sm font-medium text-slate-700 placeholder-slate-400"
						/>
						<svg class="absolute left-2.5 top-2.5 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
						</svg>
					</div>

					<div class="flex-1 overflow-y-auto border border-slate-200 rounded-xl divide-y divide-slate-100">
						{#each copyFilteredUsers as user (user.id)}
							<button
								on:click={() => { copySourceUserId = user.id; }}
								class="w-full px-4 py-3 flex items-center justify-between text-left hover:bg-purple-50 transition-colors {copySourceUserId === user.id ? 'bg-purple-100 border-l-4 border-purple-600' : ''}"
							>
								<div>
									<div class="text-sm font-bold text-slate-800">{user.username}</div>
									{#if user.employee_name}
										<div class="text-xs text-slate-400">{user.employee_name}</div>
									{/if}
								</div>
								<div class="flex items-center gap-2">
									{#if countPermissions(user) > 0}
										<span class="inline-block px-2 py-0.5 rounded-full text-[10px] font-black bg-emerald-200 text-emerald-800">{countPermissions(user)}</span>
									{:else}
										<span class="inline-block px-2 py-0.5 rounded-full text-[10px] font-black bg-slate-200 text-slate-500">0</span>
									{/if}
									{#if copySourceUserId === user.id}
										<span class="text-purple-600 font-bold">&#10003;</span>
									{/if}
								</div>
							</button>
						{:else}
							<div class="px-4 py-8 text-center text-slate-400 text-sm">No users found</div>
						{/each}
					</div>
				</div>

				<!-- Footer -->
				<div class="px-6 py-3 bg-slate-50 border-t border-slate-200 flex items-center justify-between gap-3">
					<button on:click={closeCopyPopup} class="px-4 py-1.5 bg-slate-200 text-slate-700 rounded-lg text-xs font-bold hover:bg-slate-300 transition-colors">Cancel</button>
					<button
						on:click={copyPermissions}
						disabled={!copySourceUserId || copying}
						class="px-4 py-1.5 bg-purple-600 text-white rounded-lg text-xs font-bold hover:bg-purple-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
					>
						{#if copying}
							<svg class="animate-spin w-3 h-3" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
							Copying...
						{:else}
							Copy Permissions
						{/if}
					</button>
				</div>
			</div>
		</div>
	{/if}

	<!-- Assign Default User Popup -->
	{#if showAssignPopup && assignIncidentTypeId}
		<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_interactive_supports_focus -->
		<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
			<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_interactive_supports_focus -->
			<div class="bg-white rounded-2xl shadow-2xl max-w-md w-full max-h-[80vh] overflow-hidden flex flex-col">
				<!-- Header -->
				<div class="bg-black px-6 py-4 flex items-center justify-between">
					<div>
						<h3 class="text-lg font-black text-white">Assign Default Users</h3>
						<p class="text-white/80 text-sm mt-0.5">
							{incidentTypeConfig[assignIncidentTypeId]?.icon || '📋'}
							{incidentTypes.find(t => t.id === assignIncidentTypeId)?.incident_type_en || assignIncidentTypeId}
						</p>
					</div>
					<div class="flex items-center gap-2">
						{#if savingDefault}
							<span class="text-white/80 text-xs font-semibold animate-pulse">Saving...</span>
						{/if}
						<button on:click={closeAssignPopup} class="w-8 h-8 rounded-lg bg-white/20 text-white hover:bg-white/30 flex items-center justify-center transition-colors font-bold text-lg">&times;</button>
					</div>
				</div>

				<!-- Search -->
				<div class="px-4 pt-4 pb-2">
					<div class="relative">
						<input
							type="text"
							bind:value={assignSearchQuery}
							placeholder="Search user..."
							class="w-full pl-8 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-transparent text-sm font-medium text-slate-700 placeholder-slate-400"
						/>
						<svg class="absolute left-2.5 top-2.5 w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
						</svg>
					</div>
				</div>

				<!-- User List with Checkboxes -->
				<div class="flex-1 overflow-y-auto px-4 pb-2">
					<div class="border border-slate-200 rounded-xl divide-y divide-slate-100 overflow-hidden">
						{#each assignFilteredUsers as user (user.id)}
							<label class="flex items-center gap-3 px-4 py-3 hover:bg-emerald-50/50 transition-colors cursor-pointer">
								<input
									type="checkbox"
									checked={localAssignedUserIds.has(user.id)}
									on:change={() => toggleAssignUser(user.id)}
									disabled={savingDefault}
									class="w-5 h-5 rounded border-2 border-slate-300 text-emerald-600 focus:ring-emerald-500 focus:ring-2 cursor-pointer accent-emerald-600"
								/>
								<div class="flex-1">
									<div class="text-sm font-bold {localAssignedUserIds.has(user.id) ? 'text-slate-800' : 'text-slate-500'}">{user.username}</div>
									{#if user.employee_name}
										<div class="text-xs text-slate-400">{user.employee_name}</div>
									{/if}
								</div>
							</label>
						{:else}
							<div class="px-4 py-8 text-center text-slate-400 text-sm">No users found</div>
						{/each}
					</div>
				</div>

				<!-- Footer -->
				<div class="px-6 py-3 bg-slate-50 border-t border-slate-200 flex items-center justify-between">
					<span class="text-xs font-semibold {assignHasChanges ? 'text-amber-600' : 'text-slate-500'}">
						{localAssignedUserIds.size} selected
						{#if assignHasChanges}
							<span class="ml-1 text-amber-500">• unsaved changes</span>
						{/if}
					</span>
					<div class="flex items-center gap-2">
						<button on:click={closeAssignPopup} class="px-4 py-1.5 bg-slate-200 text-slate-700 rounded-lg text-xs font-bold hover:bg-slate-300 transition-colors">Cancel</button>
						<button
							on:click={saveAssignPopup}
							disabled={!assignHasChanges || savingDefault}
							class="px-5 py-1.5 bg-emerald-600 text-white rounded-lg text-xs font-bold hover:bg-emerald-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1.5 shadow-md hover:shadow-lg"
						>
							{#if savingDefault}
								<svg class="animate-spin w-3.5 h-3.5" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
								Saving...
							{:else}
								✅ Update
							{/if}
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Success Popup -->
	{#if showAssignSuccess}
		<div class="fixed top-6 right-6 z-[60] bg-emerald-600 text-white px-6 py-4 rounded-2xl shadow-2xl flex items-center gap-3 animate-slide-in">
			<span class="text-2xl">✅</span>
			<div>
				<div class="font-black text-sm">Success!</div>
				<div class="text-xs text-emerald-100">{assignSuccessMessage}</div>
			</div>
			<button on:click={() => { showAssignSuccess = false; }} class="ml-2 text-emerald-200 hover:text-white font-bold">&times;</button>
		</div>
	{/if}
</div>
