<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	export let show = false;
	export let currentUserId: string | null = null;

	const dispatch = createEventDispatcher();

	interface EligibleUser { id: string; username: string; employeeName: string; }
	interface GrantedUser { userId: string; username: string; employeeName: string; canEdit: boolean; canViewLogs: boolean; }

	let loadingEligible = false;
	let loadingGranted = false;
	let error = '';
	let eligibleUsers: EligibleUser[] = [];
	let grantedList: GrantedUser[] = [];
	let searchQuery = '';
	let selectedUserId: string | null = null;
	let selectedCanEdit = false;
	let selectedCanViewLogs = false;
	let saving = false;
	let removingUserId: string | null = null;

	$: if (show) { loadEligibleUsers(); loadGranted(); }

	$: filteredEligibleUsers = eligibleUsers.filter(u => {
		if (!searchQuery.trim()) return true;
		const q = searchQuery.toLowerCase();
		return (u.username || '').toLowerCase().includes(q) || (u.employeeName || '').toLowerCase().includes(q);
	});

	async function fetchNameMap(employeeIds: string[]): Promise<Record<string, string>> {
		if (employeeIds.length === 0) return {};
		const { data } = await supabase.from('hr_employees').select('id, name').in('id', employeeIds);
		const map: Record<string, string> = {};
		(data || []).forEach((e: any) => { map[e.id] = e.name; });
		return map;
	}

	// Only users who already hold the SALARY_STATEMENT button permission are
	// eligible — this modal only manages the finer-grained Edit/Log
	// capabilities *inside* the window, not access to the window itself.
	async function loadEligibleUsers() {
		loadingEligible = true;
		error = '';
		try {
			const { data: perms, error: permErr } = await supabase
				.from('button_permissions')
				.select('user_id')
				.eq('button_code', 'SALARY_STATEMENT')
				.eq('is_enabled', true);
			if (permErr) throw permErr;

			const userIds = [...new Set((perms || []).map((p: any) => p.user_id))];
			if (userIds.length === 0) { eligibleUsers = []; return; }

			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.in('id', userIds)
				.order('username', { ascending: true });
			if (usersErr) throw usersErr;

			const empMap = await fetchNameMap([...new Set((users || []).filter((u: any) => u.employee_id).map((u: any) => u.employee_id))]);

			eligibleUsers = (users || []).map((u: any) => ({
				id: u.id,
				username: u.username,
				employeeName: empMap[u.employee_id] || u.username,
			}));
		} catch (e: any) {
			error = e?.message || String(e);
		} finally {
			loadingEligible = false;
		}
	}

	async function loadGranted() {
		loadingGranted = true;
		try {
			const { data, error: gErr } = await supabase
				.from('salary_statement_edit_log_permissions')
				.select('user_id, can_edit, can_view_logs')
				.or('can_edit.eq.true,can_view_logs.eq.true')
				.order('updated_at', { ascending: false });
			if (gErr) throw gErr;

			const rows = data || [];
			const userIds = [...new Set(rows.map((r: any) => r.user_id))];
			let userMap: Record<string, { username: string; employee_id: string }> = {};
			if (userIds.length > 0) {
				const { data: users } = await supabase.from('users').select('id, username, employee_id').in('id', userIds);
				(users || []).forEach((u: any) => { userMap[u.id] = u; });
			}
			const empMap = await fetchNameMap([...new Set(Object.values(userMap).filter(u => u.employee_id).map(u => u.employee_id))]);

			grantedList = rows.map((r: any) => ({
				userId: r.user_id,
				username: userMap[r.user_id]?.username || r.user_id,
				employeeName: empMap[userMap[r.user_id]?.employee_id] || userMap[r.user_id]?.username || r.user_id,
				canEdit: r.can_edit,
				canViewLogs: r.can_view_logs,
			}));
		} catch (e: any) {
			console.error('Error loading granted edit/log permissions:', e);
		} finally {
			loadingGranted = false;
		}
	}

	function selectUser(user: EligibleUser) {
		selectedUserId = user.id;
		const existing = grantedList.find(g => g.userId === user.id);
		selectedCanEdit = existing?.canEdit || false;
		selectedCanViewLogs = existing?.canViewLogs || false;
	}

	function clearSelection() {
		selectedUserId = null;
		selectedCanEdit = false;
		selectedCanViewLogs = false;
	}

	async function savePermission() {
		if (!selectedUserId || saving) return;
		if (!currentUserId) { error = 'Missing requesting user'; return; }
		saving = true;
		error = '';
		try {
			// Writes go through a SECURITY DEFINER RPC (re-checks Master Admin
			// server-side) — anon/authenticated only have SELECT on this table
			// at the Postgres grant level, so a direct .upsert() always 401s.
			const { data, error: upErr } = await supabase.rpc('upsert_salary_statement_edit_log_permission', {
				p_requesting_user_id: currentUserId,
				p_target_user_id: selectedUserId,
				p_can_edit: selectedCanEdit,
				p_can_view_logs: selectedCanViewLogs,
			});
			if (upErr) throw upErr;
			if (!data?.success) throw new Error(data?.error || 'Failed to save permissions');

			const user = eligibleUsers.find(u => u.id === selectedUserId);
			dispatch('permissionSaved', {
				userId: selectedUserId,
				userName: user?.employeeName || user?.username || selectedUserId,
				canEdit: selectedCanEdit,
				canViewLogs: selectedCanViewLogs,
			});

			await loadGranted();
			clearSelection();
		} catch (e: any) {
			error = e?.message || String(e);
			dispatch('permissionSaveFailed', { error: error });
		} finally {
			saving = false;
		}
	}

	async function removePermission(user: GrantedUser) {
		if (removingUserId) return;
		if (!currentUserId) { error = 'Missing requesting user'; return; }
		removingUserId = user.userId;
		try {
			const { data, error: delErr } = await supabase.rpc('delete_salary_statement_edit_log_permission', {
				p_requesting_user_id: currentUserId,
				p_target_user_id: user.userId,
			});
			if (delErr) throw delErr;
			if (!data?.success) throw new Error(data?.error || 'Failed to remove permissions');

			dispatch('permissionRemoved', {
				userId: user.userId,
				userName: user.employeeName || user.username,
				before: { canEdit: user.canEdit, canViewLogs: user.canViewLogs },
			});

			await loadGranted();
			if (selectedUserId === user.userId) clearSelection();
		} catch (e: any) {
			error = e?.message || String(e);
			dispatch('permissionRemoveFailed', { userId: user.userId, error: error });
		} finally {
			removingUserId = null;
		}
	}

	function close() {
		show = false;
		clearSelection();
		searchQuery = '';
		dispatch('close');
	}
</script>

{#if show}
<!-- svelte-ignore a11y-click-events-have-key-events -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div class="fixed inset-0 z-[210] flex items-center justify-center bg-black/40 backdrop-blur-sm" on:click|self={close}>
	<div class="bg-white rounded-2xl shadow-2xl w-[92vw] max-w-[820px] h-[80vh] flex flex-col border border-slate-200 overflow-hidden">

		<!-- Header -->
		<div class="flex items-center justify-between px-6 py-4 bg-gradient-to-r from-indigo-700 to-indigo-600 text-white shrink-0">
			<div class="flex items-center gap-3">
				<div class="w-9 h-9 bg-white/10 rounded-xl flex items-center justify-center">
					<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
					</svg>
				</div>
				<div>
					<h2 class="text-base font-bold tracking-wide">Manage Edit and Log Permission</h2>
					<p class="text-[11px] text-indigo-100">Grant Salary Statement Edit and/or Log access to users</p>
				</div>
			</div>
			<button class="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors text-white text-lg" on:click={close}>×</button>
		</div>

		{#if error}
			<div class="mx-5 mt-3 px-3 py-2 bg-red-50 border border-red-300 rounded text-red-700 text-xs shrink-0">{error}</div>
		{/if}

		<div class="flex-1 flex overflow-hidden">
			<!-- LEFT: search + grant -->
			<div class="w-1/2 flex flex-col border-r border-slate-200 overflow-hidden">
				<div class="p-4 border-b border-slate-100 shrink-0">
					<label for="ss-perm-search" class="block text-[10px] font-bold text-slate-500 uppercase tracking-wide mb-1.5">Search eligible user</label>
					<input
						id="ss-perm-search"
						type="text"
						bind:value={searchQuery}
						placeholder="Search by name or username…"
						class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
					/>
					<p class="text-[10px] text-slate-400 mt-1.5">Only users who already have access to the Salary Statement button are shown.</p>
				</div>

				<div class="flex-1 overflow-y-auto px-2 py-2">
					{#if loadingEligible}
						<div class="flex items-center justify-center h-full text-slate-400 text-sm">Loading users…</div>
					{:else if filteredEligibleUsers.length === 0}
						<div class="flex items-center justify-center h-full text-slate-400 text-sm text-center px-4">
							{eligibleUsers.length === 0 ? 'No users have Salary Statement access yet — grant that in Button Access Control first.' : 'No users match your search.'}
						</div>
					{:else}
						{#each filteredEligibleUsers as user (user.id)}
							{@const granted = grantedList.find(g => g.userId === user.id)}
							<button
								type="button"
								class="w-full text-left px-3 py-2 rounded-lg mb-1 flex items-center justify-between gap-2 transition-colors {selectedUserId === user.id ? 'bg-indigo-100 ring-1 ring-indigo-400' : 'hover:bg-slate-100'}"
								on:click={() => selectUser(user)}
							>
								<div class="min-w-0">
									<div class="text-sm font-semibold text-slate-800 truncate">{user.employeeName}</div>
									<div class="text-[10px] text-slate-400 truncate">{user.username}</div>
								</div>
								{#if granted}
									<div class="flex items-center gap-1 shrink-0">
										{#if granted.canEdit}<span class="text-[9px] px-1.5 py-0.5 rounded-full bg-violet-100 text-violet-700 font-bold">EDIT</span>{/if}
										{#if granted.canViewLogs}<span class="text-[9px] px-1.5 py-0.5 rounded-full bg-slate-200 text-slate-700 font-bold">LOG</span>{/if}
									</div>
								{/if}
							</button>
						{/each}
					{/if}
				</div>

				{#if selectedUserId}
					{@const selUser = eligibleUsers.find(u => u.id === selectedUserId)}
					<div class="p-4 border-t border-slate-200 bg-slate-50 shrink-0">
						<p class="text-xs font-bold text-slate-700 mb-2">{selUser?.employeeName || selectedUserId}</p>
						<div class="flex items-center gap-4 mb-3">
							<label class="flex items-center gap-2 text-sm font-semibold text-slate-700 cursor-pointer">
								<input type="checkbox" bind:checked={selectedCanEdit} class="w-4 h-4 accent-violet-600" />
								Edit permission
							</label>
							<label class="flex items-center gap-2 text-sm font-semibold text-slate-700 cursor-pointer">
								<input type="checkbox" bind:checked={selectedCanViewLogs} class="w-4 h-4 accent-slate-600" />
								Log permission
							</label>
						</div>
						<div class="flex gap-2">
							<button
								type="button"
								on:click={savePermission}
								disabled={saving}
								class="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-sm font-bold transition-colors"
							>
								{saving ? 'Saving…' : 'Save Permissions'}
							</button>
							<button type="button" on:click={clearSelection} class="px-4 py-2 rounded-lg bg-slate-200 hover:bg-slate-300 text-slate-700 text-sm font-semibold transition-colors">Cancel</button>
						</div>
					</div>
				{/if}
			</div>

			<!-- RIGHT: currently granted -->
			<div class="w-1/2 flex flex-col overflow-hidden">
				<div class="px-4 py-3 border-b border-slate-100 shrink-0">
					<span class="text-[10px] font-bold text-slate-500 uppercase tracking-wide">Users with Edit and/or Log access</span>
				</div>
				<div class="flex-1 overflow-y-auto px-3 py-2">
					{#if loadingGranted}
						<div class="flex items-center justify-center h-full text-slate-400 text-sm">Loading…</div>
					{:else if grantedList.length === 0}
						<div class="flex items-center justify-center h-full text-slate-400 text-sm text-center px-4">No users have been granted Edit or Log permission yet.</div>
					{:else}
						{#each grantedList as g (g.userId)}
							<div class="flex items-center justify-between gap-2 px-3 py-2 rounded-lg mb-1.5 bg-slate-50 border border-slate-100">
								<div class="min-w-0">
									<div class="text-sm font-semibold text-slate-800 truncate">{g.employeeName}</div>
									<div class="text-[10px] text-slate-400 truncate">{g.username}</div>
								</div>
								<div class="flex items-center gap-1.5 shrink-0">
									{#if g.canEdit}<span class="text-[9px] px-1.5 py-0.5 rounded-full bg-violet-100 text-violet-700 font-bold">EDIT</span>{/if}
									{#if g.canViewLogs}<span class="text-[9px] px-1.5 py-0.5 rounded-full bg-slate-200 text-slate-700 font-bold">LOG</span>{/if}
									<button
										type="button"
										on:click={() => removePermission(g)}
										disabled={removingUserId === g.userId}
										title="Remove all permissions for this user"
										class="w-6 h-6 rounded-full bg-red-50 hover:bg-red-100 text-red-500 flex items-center justify-center text-sm font-bold transition-colors disabled:opacity-50"
									>×</button>
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>
		</div>
	</div>
</div>
{/if}
