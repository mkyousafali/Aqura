<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	export let show = false;
	export let currentUserId: string | null = null;
	// When true, renders as a plain panel filling its container instead of a
	// fixed full-screen modal — used to embed this component inside a tab
	// (e.g. the App Permissions window) rather than opening it as a popup.
	export let embedded = false;

	const dispatch = createEventDispatcher();

	interface Row { userId: string; username: string; employeeName: string; canEdit: boolean; canViewLogs: boolean; saving: boolean; }

	let loading = false;
	let error = '';
	let rows: Row[] = [];
	let searchQuery = '';

	$: if (show) { loadRows(); }

	$: filtered = rows.filter(r => {
		if (!searchQuery.trim()) return true;
		const q = searchQuery.toLowerCase();
		return (r.username || '').toLowerCase().includes(q) || (r.employeeName || '').toLowerCase().includes(q);
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
	// Every eligible user is shown, left-joined with their current Edit/Log
	// grant (defaulting to both off when they don't have a row yet).
	async function loadRows() {
		loading = true;
		error = '';
		try {
			const { data: perms, error: permErr } = await supabase
				.from('button_permissions')
				.select('user_id')
				.eq('button_code', 'SALARY_STATEMENT')
				.eq('is_enabled', true);
			if (permErr) throw permErr;

			const userIds = [...new Set((perms || []).map((p: any) => p.user_id))];
			if (userIds.length === 0) { rows = []; return; }

			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.in('id', userIds)
				.order('username', { ascending: true });
			if (usersErr) throw usersErr;

			const { data: grants, error: grantsErr } = await supabase
				.from('salary_statement_edit_log_permissions')
				.select('user_id, can_edit, can_view_logs');
			if (grantsErr) throw grantsErr;
			const grantMap = new Map<string, any>((grants || []).map((g: any) => [g.user_id, g]));

			const empMap = await fetchNameMap([...new Set((users || []).filter((u: any) => u.employee_id).map((u: any) => u.employee_id))]);

			rows = (users || []).map((u: any) => {
				const grant = grantMap.get(u.id);
				return {
					userId: u.id,
					username: u.username,
					employeeName: empMap[u.employee_id] || u.username,
					canEdit: grant?.can_edit ?? false,
					canViewLogs: grant?.can_view_logs ?? false,
					saving: false,
				};
			});
		} catch (e: any) {
			error = e?.message || String(e);
		} finally {
			loading = false;
		}
	}

	async function toggle(row: Row, field: 'canEdit' | 'canViewLogs') {
		if (!currentUserId || row.saving) return;
		row.saving = true;
		rows = rows;
		const newValue = !row[field];
		try {
			// Writes go through a SECURITY DEFINER RPC (re-checks Master Admin
			// server-side) — anon/authenticated only have SELECT on this table
			// at the Postgres grant level, so a direct .upsert() always 401s.
			const { data, error: upErr } = await supabase.rpc('upsert_salary_statement_edit_log_permission', {
				p_requesting_user_id: currentUserId,
				p_target_user_id: row.userId,
				p_can_edit: field === 'canEdit' ? newValue : row.canEdit,
				p_can_view_logs: field === 'canViewLogs' ? newValue : row.canViewLogs,
			});
			if (upErr) throw upErr;
			if (!data?.success) throw new Error(data?.error || 'Failed to update permission');
			row[field] = newValue;
			dispatch('permissionSaved', { userId: row.userId, userName: row.employeeName || row.username, canEdit: row.canEdit, canViewLogs: row.canViewLogs });
		} catch (e: any) {
			error = e?.message || String(e);
			dispatch('permissionSaveFailed', { error: error });
		} finally {
			row.saving = false;
			rows = rows;
		}
	}

	function close() {
		show = false;
		searchQuery = '';
		dispatch('close');
	}
</script>

{#if show}
<!-- svelte-ignore a11y-click-events-have-key-events -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div
	class={embedded ? 'w-full h-full flex flex-col bg-white' : 'fixed inset-0 z-[210] flex items-center justify-center bg-black/40 backdrop-blur-sm'}
	on:click={embedded ? undefined : (e) => { if (e.target === e.currentTarget) close(); }}
>
	<div class={embedded ? 'w-full h-full flex flex-col overflow-hidden' : 'bg-white rounded-2xl shadow-2xl w-[92vw] max-w-[820px] h-[80vh] flex flex-col border border-slate-200 overflow-hidden'}>

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
			{#if !embedded}
				<button class="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors text-white text-lg" on:click={close}>×</button>
			{/if}
		</div>

		{#if error}
			<div class="mx-5 mt-3 px-3 py-2 bg-red-50 border border-red-300 rounded text-red-700 text-xs shrink-0">{error}</div>
		{/if}

		<!-- Search -->
		<div class="p-4 border-b border-slate-200 shrink-0">
			<input
				type="text"
				bind:value={searchQuery}
				placeholder="Search by name or username…"
				class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
			/>
			<p class="text-[10px] text-slate-400 mt-1.5">Only users who already have access to the Salary Statement button are shown.</p>
		</div>

		<!-- All eligible users table -->
		<div class="flex-1 overflow-y-auto">
			{#if loading}
				<div class="flex items-center justify-center h-40 text-slate-400 text-sm">Loading…</div>
			{:else if filtered.length === 0}
				<div class="flex items-center justify-center h-40 text-slate-400 text-sm text-center px-6">
					{rows.length === 0 ? 'No users have Salary Statement access yet — grant that in Button Access Control first.' : 'No users match your search.'}
				</div>
			{:else}
				<table class="w-full text-sm border-collapse">
					<thead class="sticky top-0 z-10 bg-slate-100">
						<tr>
							<th class="px-4 py-3 text-left font-black text-slate-700 border-b border-slate-200 w-[50%]">User</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Edit</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">View Logs</th>
						</tr>
					</thead>
					<tbody>
						{#each filtered as row (row.userId)}
							<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors {row.saving ? 'opacity-60' : ''}">
								<td class="px-4 py-3">
									<div class="font-semibold text-slate-900">{row.employeeName}</div>
									{#if row.username.toLowerCase() !== row.employeeName.toLowerCase()}
										<div class="text-xs text-slate-400">@{row.username}</div>
									{/if}
								</td>
								<td class="px-4 py-3 text-center">
									<button
										type="button"
										class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
											{row.canEdit ? 'bg-violet-500' : 'bg-slate-300'}"
										on:click={() => toggle(row, 'canEdit')}
										disabled={row.saving}
									>
										<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
											{row.canEdit ? 'translate-x-6' : 'translate-x-1'}"></span>
									</button>
								</td>
								<td class="px-4 py-3 text-center">
									<button
										type="button"
										class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
											{row.canViewLogs ? 'bg-slate-600' : 'bg-slate-300'}"
										on:click={() => toggle(row, 'canViewLogs')}
										disabled={row.saving}
									>
										<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
											{row.canViewLogs ? 'translate-x-6' : 'translate-x-1'}"></span>
									</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			{/if}
		</div>
	</div>
</div>
{/if}
