<script lang="ts">
	import { onMount } from 'svelte';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface PermRow {
		user_id: string;
		username: string;
		employee_name_en: string | null;
		can_see_one_branch: boolean;
		can_see_all_branches: boolean;
		can_edit: boolean;
		read_only: boolean;
		saving?: boolean;
	}

	interface ApproverRow {
		user_id: string;
		username: string;
		employee_name_en: string | null;
		is_active: boolean;
		saving?: boolean;
	}

	interface ClosureRow {
		user_id: string;
		username: string;
		employee_name_en: string | null;
		branch_id: number | null;
		all_branches_enabled: boolean;
		branch_specific_enabled: boolean;
		grantedCount: number;
		saving?: boolean;
	}

	interface BranchOption {
		id: number;
		name_en: string;
		name_ar: string;
	}

	let activeTab: 'permission' | 'approvers' | 'closures' = 'permission';

	let rows: PermRow[] = [];
	let loading = true;
	let searchQuery = '';

	let approverRows: ApproverRow[] = [];
	let approversLoading = true;
	let approverSearchQuery = '';

	$: filtered = rows.filter(r => {
		if (!searchQuery.trim()) return true;
		const s = searchQuery.toLowerCase();
		return (r.username || '').toLowerCase().includes(s)
			|| (r.employee_name_en || '').toLowerCase().includes(s);
	});

	$: filteredApprovers = approverRows.filter(r => {
		if (!approverSearchQuery.trim()) return true;
		const s = approverSearchQuery.toLowerCase();
		return (r.username || '').toLowerCase().includes(s)
			|| (r.employee_name_en || '').toLowerCase().includes(s);
	});

	onMount(async () => {
		await loadPermissions();
		await loadApprovers();
		await loadClosureRows();
	});

	async function loadApprovers() {
		approversLoading = true;
		try {
			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.eq('status', 'active')
				.order('username');
			if (usersErr) throw usersErr;

			const { data: approvers } = await supabase
				.from('complete_box_approvers')
				.select('*');
			const approverMap = new Map((approvers || []).map((a: any) => [a.user_id, a]));

			const empIds = (users || []).map((u: any) => u.employee_id).filter(Boolean);
			let empMap = new Map<string, any>();
			if (empIds.length > 0) {
				const { data: emps } = await supabase
					.from('hr_employee_master')
					.select('id, name_en')
					.in('id', empIds);
				empMap = new Map((emps || []).map((e: any) => [String(e.id), e]));
			}

			approverRows = (users || []).map((u: any) => {
				const approver = approverMap.get(u.id);
				const emp = u.employee_id ? empMap.get(String(u.employee_id)) : null;
				return {
					user_id: u.id,
					username: u.username,
					employee_name_en: emp?.name_en || null,
					is_active: approver?.is_active ?? false,
					saving: false
				};
			});
		} catch (err) {
			console.error('Error loading complete box approvers:', err);
		} finally {
			approversLoading = false;
		}
	}

	async function toggleApprover(row: ApproverRow) {
		const requestingUserId = get(currentUser)?.id;
		if (!requestingUserId) return;
		row.saving = true;
		approverRows = approverRows;
		const newState = !row.is_active;
		try {
			const { data, error } = await supabase.rpc('upsert_complete_box_approver', {
				p_requesting_user_id: requestingUserId,
				p_target_user_id: row.user_id,
				p_is_active: newState
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Failed to update approver');
			row.is_active = newState;
		} catch (err) {
			console.error('Error saving complete box approver:', err);
		} finally {
			row.saving = false;
			approverRows = approverRows;
		}
	}

	function getApproverDisplayName(row: ApproverRow): string {
		return row.employee_name_en || row.username;
	}

	// ============================================================
	// PERMITTED CLOSURES — who may click "Start Closing" on a Complete Box,
	// per branch. Deliberately no Master Admin/Admin bypass on the
	// enforcement side (can_user_close_branch) — everyone needs an explicit
	// grant, checked in CompleteBox.svelte.
	// ============================================================
	let closureRows: ClosureRow[] = [];
	let closureLoading = true;
	let closureSearchQuery = '';

	$: filteredClosureRows = closureRows.filter(r => {
		if (!closureSearchQuery.trim()) return true;
		const s = closureSearchQuery.toLowerCase();
		return (r.username || '').toLowerCase().includes(s)
			|| (r.employee_name_en || '').toLowerCase().includes(s);
	});

	let allBranches: BranchOption[] = [];
	let showBranchModal = false;
	let branchModalUser: ClosureRow | null = null;
	let branchModalGranted: Set<number> = new Set();
	let branchModalLoading = false;
	let branchModalSavingBranchId: number | null = null;

	async function loadClosureRows() {
		closureLoading = true;
		try {
			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id, branch_id')
				.eq('status', 'active')
				.order('username');
			if (usersErr) throw usersErr;

			const { data: perms } = await supabase.from('complete_box_closure_permissions').select('*');
			const permMap = new Map((perms || []).map((p: any) => [p.user_id, p]));

			const { data: grants } = await supabase.from('complete_box_closure_branch_grants').select('user_id');
			const grantCountMap = new Map<string, number>();
			(grants || []).forEach((g: any) => grantCountMap.set(g.user_id, (grantCountMap.get(g.user_id) || 0) + 1));

			const empIds = (users || []).map((u: any) => u.employee_id).filter(Boolean);
			let empMap = new Map<string, any>();
			if (empIds.length > 0) {
				const { data: emps } = await supabase
					.from('hr_employee_master')
					.select('id, name_en')
					.in('id', empIds);
				empMap = new Map((emps || []).map((e: any) => [String(e.id), e]));
			}

			closureRows = (users || []).map((u: any) => {
				const perm = permMap.get(u.id);
				const emp = u.employee_id ? empMap.get(String(u.employee_id)) : null;
				return {
					user_id: u.id,
					username: u.username,
					employee_name_en: emp?.name_en || null,
					branch_id: u.branch_id,
					all_branches_enabled: perm?.all_branches_enabled ?? false,
					branch_specific_enabled: perm?.branch_specific_enabled ?? false,
					grantedCount: grantCountMap.get(u.id) || 0,
					saving: false
				};
			});
		} catch (err) {
			console.error('Error loading closure permissions:', err);
		} finally {
			closureLoading = false;
		}
	}

	async function toggleClosureField(row: ClosureRow, field: 'all_branches_enabled' | 'branch_specific_enabled') {
		const requestingUserId = get(currentUser)?.id;
		if (!requestingUserId) return;
		row.saving = true;
		closureRows = closureRows;
		const newState = !row[field];
		try {
			const payload: any = { p_requesting_user_id: requestingUserId, p_target_user_id: row.user_id };
			if (field === 'all_branches_enabled') payload.p_all_branches_enabled = newState;
			else payload.p_branch_specific_enabled = newState;
			const { data, error } = await supabase.rpc('upsert_complete_box_closure_permission', payload);
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Failed to update');
			row[field] = newState;
		} catch (err) {
			console.error('Error toggling closure permission:', err);
		} finally {
			row.saving = false;
			closureRows = closureRows;
		}
	}

	function getClosureDisplayName(row: ClosureRow): string {
		return row.employee_name_en || row.username;
	}

	async function openBranchModal(row: ClosureRow) {
		branchModalUser = row;
		showBranchModal = true;
		branchModalLoading = true;
		const requestingUserId = get(currentUser)?.id;
		try {
			if (allBranches.length === 0) {
				const { data: branches } = await supabase
					.from('branches')
					.select('id, name_en, name_ar')
					.eq('is_active', true)
					.order('name_en');
				allBranches = branches || [];
			}

			// The user's own assigned branch should already be checked —
			// auto-grant it (idempotent) the first time this opens for them.
			if (requestingUserId && row.branch_id != null) {
				await supabase.rpc('ensure_own_branch_closure_grant', {
					p_requesting_user_id: requestingUserId,
					p_target_user_id: row.user_id
				});
			}

			const { data: grants } = await supabase
				.from('complete_box_closure_branch_grants')
				.select('branch_id')
				.eq('user_id', row.user_id);
			branchModalGranted = new Set((grants || []).map((g: any) => g.branch_id));
			row.grantedCount = branchModalGranted.size;
			closureRows = closureRows;
		} catch (err) {
			console.error('Error loading branch permissions:', err);
		} finally {
			branchModalLoading = false;
		}
	}

	function closeBranchModal() {
		showBranchModal = false;
		branchModalUser = null;
		branchModalGranted = new Set();
	}

	async function toggleBranchGrant(branchId: number) {
		const requestingUserId = get(currentUser)?.id;
		if (!requestingUserId || !branchModalUser || branchModalSavingBranchId !== null) return;
		branchModalSavingBranchId = branchId;
		const currentlyGranted = branchModalGranted.has(branchId);
		try {
			const { data, error } = await supabase.rpc('set_complete_box_closure_branch_grant', {
				p_requesting_user_id: requestingUserId,
				p_target_user_id: branchModalUser.user_id,
				p_branch_id: branchId,
				p_granted: !currentlyGranted
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Failed to update branch permission');
			if (currentlyGranted) branchModalGranted.delete(branchId);
			else branchModalGranted.add(branchId);
			branchModalGranted = new Set(branchModalGranted);
			branchModalUser.grantedCount = branchModalGranted.size;
			closureRows = closureRows;
		} catch (err) {
			console.error('Error toggling branch grant:', err);
		} finally {
			branchModalSavingBranchId = null;
		}
	}

	async function loadPermissions() {
		loading = true;
		try {
			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.eq('status', 'active')
				.order('username');

			if (usersErr) throw usersErr;

			const { data: perms } = await supabase
				.from('denomination_permissions')
				.select('*');

			const permMap = new Map((perms || []).map((p: any) => [p.user_id, p]));

			const empIds = (users || []).map((u: any) => u.employee_id).filter(Boolean);
			let empMap = new Map<string, any>();
			if (empIds.length > 0) {
				const { data: emps } = await supabase
					.from('hr_employee_master')
					.select('id, name_en')
					.in('id', empIds);
				empMap = new Map((emps || []).map((e: any) => [String(e.id), e]));
			}

			rows = (users || []).map((u: any) => {
				const perm = permMap.get(u.id);
				const emp = u.employee_id ? empMap.get(String(u.employee_id)) : null;
				return {
					user_id: u.id,
					username: u.username,
					employee_name_en: emp?.name_en || null,
					can_see_one_branch: perm?.can_see_one_branch ?? false,
					can_see_all_branches: perm?.can_see_all_branches ?? false,
					can_edit: perm?.can_edit ?? false,
					read_only: perm?.read_only ?? false,
					saving: false
				};
			});
		} catch (err) {
			console.error('Error loading denomination permissions:', err);
		} finally {
			loading = false;
		}
	}

	async function saveRow(row: PermRow) {
		row.saving = true;
		rows = rows;
		try {
			const { error } = await supabase
				.from('denomination_permissions')
				.upsert({
					user_id: row.user_id,
					can_see_one_branch: row.can_see_one_branch,
					can_see_all_branches: row.can_see_all_branches,
					can_edit: row.can_edit,
					read_only: row.read_only,
					updated_at: new Date().toISOString()
				}, { onConflict: 'user_id' });
			if (error) throw error;
		} catch (err) {
			console.error('Error saving denomination permission:', err);
		} finally {
			row.saving = false;
			rows = rows;
		}
	}

	function toggle(row: PermRow, field: 'can_see_one_branch' | 'can_see_all_branches' | 'can_edit' | 'read_only') {
		// can_see_all_branches implies can_see_one_branch
		if (field === 'can_see_all_branches' && !(row as any)[field]) {
			row.can_see_one_branch = true;
		}
		// If disabling can_see_all_branches, don't auto-disable one_branch
		(row as any)[field] = !(row as any)[field];
		// read_only and can_edit are mutually exclusive
		if (field === 'can_edit' && row.can_edit) row.read_only = false;
		if (field === 'read_only' && row.read_only) row.can_edit = false;
		rows = rows;
		saveRow(row);
	}

	function getDisplayName(row: PermRow): string {
		return row.employee_name_en || row.username;
	}
</script>

<div class="h-full flex flex-col bg-white">
	<!-- Tabs -->
	<div class="flex border-b border-slate-200 bg-slate-50 px-2 pt-2 gap-1">
		<button
			type="button"
			class="px-4 py-2 text-sm font-bold rounded-t-lg transition-colors {activeTab === 'permission' ? 'bg-white text-indigo-700 border border-slate-200 border-b-white -mb-px' : 'text-slate-500 hover:text-slate-700'}"
			on:click={() => (activeTab = 'permission')}
		>
			Denomination Permission
		</button>
		<button
			type="button"
			class="px-4 py-2 text-sm font-bold rounded-t-lg transition-colors {activeTab === 'approvers' ? 'bg-white text-indigo-700 border border-slate-200 border-b-white -mb-px' : 'text-slate-500 hover:text-slate-700'}"
			on:click={() => (activeTab = 'approvers')}
		>
			Complete Box Approvers
		</button>
		<button
			type="button"
			class="px-4 py-2 text-sm font-bold rounded-t-lg transition-colors {activeTab === 'closures' ? 'bg-white text-indigo-700 border border-slate-200 border-b-white -mb-px' : 'text-slate-500 hover:text-slate-700'}"
			on:click={() => (activeTab = 'closures')}
		>
			Permitted Closures
		</button>
	</div>

{#if activeTab === 'permission'}
	<!-- Header -->
	<div class="px-6 py-4 border-b border-slate-200 flex items-center justify-between gap-4 bg-slate-50">
		<div>
			<h2 class="text-lg font-black text-slate-900">Denomination Permission Manager</h2>
			<p class="text-xs text-slate-500 mt-0.5">Control which users can access the Denomination module and what they can do</p>
		</div>
		<input
			type="text"
			bind:value={searchQuery}
			placeholder="Search users..."
			class="px-4 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 w-56"
		/>
	</div>

	<!-- Table -->
	<div class="flex-1 overflow-auto">
		{#if loading}
			<div class="flex items-center justify-center h-40 text-slate-400">Loading...</div>
		{:else}
			<table class="w-full text-sm border-collapse">
				<thead class="sticky top-0 z-10 bg-slate-100">
					<tr>
						<th class="px-4 py-3 text-left font-black text-slate-700 border-b border-slate-200 w-[35%]">User</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">One Branch</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">All Branches</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Can Edit</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Read Only</th>
					</tr>
				</thead>
				<tbody>
					{#each filtered as row (row.user_id)}
						<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors {row.saving ? 'opacity-60' : ''}">
							<td class="px-4 py-3">
								<div class="font-semibold text-slate-900">{getDisplayName(row)}</div>
								{#if row.username.toLowerCase() !== getDisplayName(row).toLowerCase()}
									<div class="text-xs text-slate-400">@{row.username}</div>
								{/if}
							</td>

							<!-- Can See One Branch -->
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.can_see_one_branch ? 'bg-blue-500' : 'bg-slate-300'}"
									on:click={() => toggle(row, 'can_see_one_branch')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.can_see_one_branch ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>

							<!-- Can See All Branches -->
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.can_see_all_branches ? 'bg-purple-500' : 'bg-slate-300'}"
									on:click={() => toggle(row, 'can_see_all_branches')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.can_see_all_branches ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>

							<!-- Can Edit -->
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.can_edit ? 'bg-emerald-500' : 'bg-slate-300'}"
									on:click={() => toggle(row, 'can_edit')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.can_edit ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>

							<!-- Read Only -->
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.read_only ? 'bg-amber-500' : 'bg-slate-300'}"
									on:click={() => toggle(row, 'read_only')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.read_only ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
			{#if filtered.length === 0}
				<div class="text-center py-12 text-slate-400">No users found</div>
			{/if}
		{/if}
	</div>

	<!-- Legend -->
	<div class="px-6 py-3 border-t border-slate-100 bg-slate-50 flex gap-6 text-xs text-slate-500 flex-wrap">
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-blue-500 inline-block"></span>One Branch: Can see their assigned branch only</span>
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-purple-500 inline-block"></span>All Branches: Can see all branches</span>
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-emerald-500 inline-block"></span>Can Edit: Can modify denomination data</span>
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-amber-500 inline-block"></span>Read Only: View only, no edits</span>
	</div>
{:else if activeTab === 'approvers'}
	<!-- Complete Box Approvers tab -->
	<div class="px-6 py-4 border-b border-slate-200 flex items-center justify-between gap-4 bg-slate-50">
		<div>
			<h2 class="text-lg font-black text-slate-900">Complete Box Approvers</h2>
			<p class="text-xs text-slate-500 mt-0.5">Users who can approve editing a Complete Box record by email OTP. Any one active approver's code unlocks editing.</p>
		</div>
		<input
			type="text"
			bind:value={approverSearchQuery}
			placeholder="Search users..."
			class="px-4 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 w-56"
		/>
	</div>

	<div class="flex-1 overflow-auto">
		{#if approversLoading}
			<div class="flex items-center justify-center h-40 text-slate-400">Loading...</div>
		{:else}
			<table class="w-full text-sm border-collapse">
				<thead class="sticky top-0 z-10 bg-slate-100">
					<tr>
						<th class="px-4 py-3 text-left font-black text-slate-700 border-b border-slate-200 w-[70%]">User</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Approver</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredApprovers as row (row.user_id)}
						<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors {row.saving ? 'opacity-60' : ''}">
							<td class="px-4 py-3">
								<div class="font-semibold text-slate-900">{getApproverDisplayName(row)}</div>
								{#if row.username.toLowerCase() !== getApproverDisplayName(row).toLowerCase()}
									<div class="text-xs text-slate-400">@{row.username}</div>
								{/if}
							</td>
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.is_active ? 'bg-emerald-500' : 'bg-slate-300'}"
									on:click={() => toggleApprover(row)}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.is_active ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
			{#if filteredApprovers.length === 0}
				<div class="text-center py-12 text-slate-400">No users found</div>
			{/if}
		{/if}
	</div>

	<div class="px-6 py-3 border-t border-slate-100 bg-slate-50 text-xs text-slate-500">
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-emerald-500 inline-block"></span>Approver: receives the 6-digit OTP email whenever someone requests to edit a Complete Box record</span>
	</div>
{:else}
	<!-- Permitted Closures tab -->
	<div class="px-6 py-4 border-b border-slate-200 flex items-center justify-between gap-4 bg-slate-50">
		<div>
			<h2 class="text-lg font-black text-slate-900">Permitted Closures</h2>
			<p class="text-xs text-slate-500 mt-0.5">Controls who may start closing a Complete Box, per branch. No exceptions for Admin/Master Admin — everyone needs an explicit grant here.</p>
		</div>
		<input
			type="text"
			bind:value={closureSearchQuery}
			placeholder="Search users..."
			class="px-4 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 w-56"
		/>
	</div>

	<div class="flex-1 overflow-auto">
		{#if closureLoading}
			<div class="flex items-center justify-center h-40 text-slate-400">Loading...</div>
		{:else}
			<table class="w-full text-sm border-collapse">
				<thead class="sticky top-0 z-10 bg-slate-100">
					<tr>
						<th class="px-4 py-3 text-left font-black text-slate-700 border-b border-slate-200 w-[40%]">User</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">All Branches</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Branch-Specific</th>
						<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Branch Permissions</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredClosureRows as row (row.user_id)}
						<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors {row.saving ? 'opacity-60' : ''}">
							<td class="px-4 py-3">
								<div class="font-semibold text-slate-900">{getClosureDisplayName(row)}</div>
								{#if row.username.toLowerCase() !== getClosureDisplayName(row).toLowerCase()}
									<div class="text-xs text-slate-400">@{row.username}</div>
								{/if}
							</td>
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.all_branches_enabled ? 'bg-emerald-500' : 'bg-slate-300'}"
									on:click={() => toggleClosureField(row, 'all_branches_enabled')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.all_branches_enabled ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
										{row.branch_specific_enabled ? 'bg-blue-500' : 'bg-slate-300'}"
									on:click={() => toggleClosureField(row, 'branch_specific_enabled')}
									disabled={row.saving}
								>
									<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
										{row.branch_specific_enabled ? 'translate-x-6' : 'translate-x-1'}"></span>
								</button>
							</td>
							<td class="px-4 py-3 text-center">
								<button
									type="button"
									class="px-3 py-1.5 rounded-lg text-xs font-bold bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition-colors"
									on:click={() => openBranchModal(row)}
								>
									Select Branch Permissions {row.grantedCount > 0 ? `(${row.grantedCount})` : ''}
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
			{#if filteredClosureRows.length === 0}
				<div class="text-center py-12 text-slate-400">No users found</div>
			{/if}
		{/if}
	</div>

	<div class="px-6 py-3 border-t border-slate-100 bg-slate-50 flex gap-6 text-xs text-slate-500 flex-wrap">
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-emerald-500 inline-block"></span>All Branches: may start closing at any branch</span>
		<span class="flex items-center gap-1.5"><span class="w-3 h-3 rounded-full bg-blue-500 inline-block"></span>Branch-Specific: honors the branches selected below</span>
	</div>
{/if}
</div>

{#if showBranchModal && branchModalUser}
<!-- svelte-ignore a11y-click-events-have-key-events -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div class="fixed inset-0 z-[220] flex items-center justify-center bg-black/40 backdrop-blur-sm" on:click|self={closeBranchModal}>
	<div class="bg-white rounded-2xl shadow-2xl w-[92vw] max-w-[520px] max-h-[80vh] flex flex-col border border-slate-200 overflow-hidden">
		<div class="flex items-center justify-between px-5 py-4 bg-gradient-to-r from-indigo-700 to-indigo-600 text-white shrink-0">
			<div>
				<h3 class="text-sm font-bold">Branch Permissions</h3>
				<p class="text-[11px] text-indigo-100">{getClosureDisplayName(branchModalUser)}</p>
			</div>
			<button class="w-7 h-7 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white text-lg" on:click={closeBranchModal}>×</button>
		</div>
		<div class="flex-1 overflow-y-auto px-3 py-2">
			{#if branchModalLoading}
				<div class="flex items-center justify-center h-32 text-slate-400 text-sm">Loading...</div>
			{:else if allBranches.length === 0}
				<div class="flex items-center justify-center h-32 text-slate-400 text-sm">No branches found</div>
			{:else}
				{#each allBranches as branchOpt (branchOpt.id)}
					{@const isOwnBranch = branchModalUser.branch_id === branchOpt.id}
					<button
						type="button"
						class="w-full text-left px-3 py-2 rounded-lg mb-1 flex items-center justify-between gap-2 transition-colors hover:bg-slate-100 disabled:opacity-60"
						disabled={branchModalSavingBranchId === branchOpt.id}
						on:click={() => toggleBranchGrant(branchOpt.id)}
					>
						<div class="flex items-center gap-2 min-w-0">
							<input type="checkbox" checked={branchModalGranted.has(branchOpt.id)} class="w-4 h-4 accent-indigo-600 pointer-events-none" />
							<div class="min-w-0">
								<div class="text-sm font-semibold text-slate-800 truncate">{branchOpt.name_en}</div>
								<div class="text-[10px] text-slate-400 truncate">{branchOpt.name_ar}</div>
							</div>
						</div>
						{#if isOwnBranch}
							<span class="text-[9px] px-1.5 py-0.5 rounded-full bg-amber-100 text-amber-700 font-bold shrink-0">OWN BRANCH</span>
						{/if}
					</button>
				{/each}
			{/if}
		</div>
	</div>
</div>
{/if}
