<script>
	import { createEventDispatcher } from 'svelte';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let show = false;
	// When true, renders as a plain panel filling its container instead of a
	// fixed full-screen modal — used to embed this component inside a tab
	// (e.g. the App Permissions window) rather than opening it as a popup.
	export let embedded = false;

	const dispatch = createEventDispatcher();

	// Only users who already hold the RECEIVING_RECORDS button permission are
	// shown — no point granting ERP-reference/edit/delete rights to someone
	// who can't open the Receiving Records window at all. Every eligible user
	// is left-joined with their receiving_records_permissions row (defaulting
	// to all-false when they don't have one yet).
	let rows = [];
	let loading = false;
	let error = '';
	let searchQuery = '';

	$: filtered = (() => {
		const q = searchQuery.trim().toLowerCase();
		if (!q) return rows;
		return rows.filter((r) => (r.displayName || '').toLowerCase().includes(q) || (r.username || '').toLowerCase().includes(q));
	})();

	$: if (show) {
		loadRows();
	}

	async function fetchNameMap(employeeIds) {
		if (employeeIds.length === 0) return {};
		const { data } = await supabase.from('hr_employee_master').select('id, name_en').in('id', employeeIds);
		const map = {};
		(data || []).forEach((e) => { map[e.id] = e.name_en; });
		return map;
	}

	async function loadRows() {
		loading = true;
		error = '';
		try {
			const { data: access, error: accessErr } = await supabase
				.from('button_permissions')
				.select('user_id')
				.eq('button_code', 'RECEIVING_RECORDS')
				.eq('is_enabled', true);
			if (accessErr) throw accessErr;

			const eligibleIds = [...new Set((access || []).map((a) => a.user_id))];
			if (eligibleIds.length === 0) { rows = []; return; }

			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.eq('status', 'active')
				.in('id', eligibleIds)
				.order('username', { ascending: true });
			if (usersErr) throw usersErr;

			const { data: perms, error: permsErr } = await supabase
				.from('receiving_records_permissions')
				.select('user_id, can_edit_erp_reference, can_edit_record, can_delete');
			if (permsErr) throw permsErr;

			const permMap = new Map((perms || []).map((p) => [p.user_id, p]));

			const empIds = [...new Set((users || []).filter((u) => u.employee_id).map((u) => u.employee_id))];
			const empMap = await fetchNameMap(empIds);

			rows = (users || []).map((u) => {
				const perm = permMap.get(u.id);
				return {
					user_id: u.id,
					username: u.username,
					displayName: (u.employee_id && empMap[u.employee_id]) || u.username,
					can_edit_erp_reference: perm?.can_edit_erp_reference ?? false,
					can_edit_record: perm?.can_edit_record ?? false,
					can_delete: perm?.can_delete ?? false,
					saving: false
				};
			});
		} catch (e) {
			error = e?.message || String(e);
		} finally {
			loading = false;
		}
	}

	async function toggle(row, field) {
		const requestingUserId = get(currentUser)?.id;
		if (!requestingUserId || row.saving) return;
		row.saving = true;
		rows = rows;
		const newValue = !row[field];
		try {
			const { data, error: upErr } = await supabase.rpc('upsert_receiving_records_permission', {
				p_requesting_user_id: requestingUserId,
				p_target_user_id: row.user_id,
				p_can_edit_erp_reference: field === 'can_edit_erp_reference' ? newValue : row.can_edit_erp_reference,
				p_can_edit_record: field === 'can_edit_record' ? newValue : row.can_edit_record,
				p_can_delete: field === 'can_delete' ? newValue : row.can_delete
			});
			if (upErr) throw upErr;
			if (!data?.success) throw new Error(data?.error || 'Failed to update permission');
			row[field] = newValue;
		} catch (e) {
			error = e?.message || String(e);
		} finally {
			row.saving = false;
			rows = rows;
		}
	}

	function close() {
		show = false;
		searchQuery = '';
		error = '';
		dispatch('close');
	}
</script>

{#if show}
<!-- svelte-ignore a11y-click-events-have-key-events -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div
	class={embedded ? 'w-full h-full flex flex-col bg-white' : 'fixed inset-0 z-[220] flex items-center justify-center bg-black/40 backdrop-blur-sm'}
	on:click={embedded ? undefined : (e) => { if (e.target === e.currentTarget) close(); }}
>
	<div class={embedded ? 'w-full h-full flex flex-col overflow-hidden' : 'bg-white rounded-2xl shadow-2xl w-[92vw] max-w-[760px] h-[80vh] flex flex-col border border-slate-200 overflow-hidden'}>

		<!-- Header -->
		<div class="flex items-center justify-between px-6 py-4 bg-gradient-to-r from-indigo-700 to-indigo-600 text-white shrink-0">
			<div>
				<h2 class="text-base font-bold tracking-wide">Receiving Records — Edit Permission</h2>
				<p class="text-[11px] text-indigo-100">Master Admins always have full access. Toggle what each user can do below.</p>
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
			<p class="text-[10px] text-slate-400 mt-1.5">Only users who already have access to the Receiving Records button are shown.</p>
		</div>

		<!-- Eligible users table -->
		<div class="flex-1 overflow-y-auto">
			{#if loading}
				<div class="flex items-center justify-center h-40 text-slate-400 text-sm">Loading…</div>
			{:else if filtered.length === 0}
				<div class="flex items-center justify-center h-40 text-slate-400 text-sm text-center px-6">
					{rows.length === 0 ? 'No users have Receiving Records access yet — grant that in Button Access Control first.' : 'No users match your search.'}
				</div>
			{:else}
				<table class="w-full text-sm border-collapse">
					<thead class="sticky top-0 z-10 bg-slate-100">
						<tr>
							<th class="px-4 py-3 text-left font-black text-slate-700 border-b border-slate-200 w-[35%]">User</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Edit ERP Reference</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Edit Record</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Allow Delete</th>
						</tr>
					</thead>
					<tbody>
						{#each filtered as row (row.user_id)}
							<tr class="border-b border-slate-100 hover:bg-slate-50 transition-colors {row.saving ? 'opacity-60' : ''}">
								<td class="px-4 py-3">
									<div class="font-semibold text-slate-900">{row.displayName}</div>
									{#if row.username.toLowerCase() !== row.displayName.toLowerCase()}
										<div class="text-xs text-slate-400">@{row.username}</div>
									{/if}
								</td>
								<td class="px-4 py-3 text-center">
									<button
										type="button"
										class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
											{row.can_edit_erp_reference ? 'bg-emerald-500' : 'bg-slate-300'}"
										on:click={() => toggle(row, 'can_edit_erp_reference')}
										disabled={row.saving}
									>
										<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
											{row.can_edit_erp_reference ? 'translate-x-6' : 'translate-x-1'}"></span>
									</button>
								</td>
								<td class="px-4 py-3 text-center">
									<button
										type="button"
										class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
											{row.can_edit_record ? 'bg-blue-500' : 'bg-slate-300'}"
										on:click={() => toggle(row, 'can_edit_record')}
										disabled={row.saving}
									>
										<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
											{row.can_edit_record ? 'translate-x-6' : 'translate-x-1'}"></span>
									</button>
								</td>
								<td class="px-4 py-3 text-center">
									<button
										type="button"
										class="relative inline-flex items-center w-11 h-6 rounded-full transition-colors focus:outline-none
											{row.can_delete ? 'bg-red-500' : 'bg-slate-300'}"
										on:click={() => toggle(row, 'can_delete')}
										disabled={row.saving}
									>
										<span class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform
											{row.can_delete ? 'translate-x-6' : 'translate-x-1'}"></span>
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
