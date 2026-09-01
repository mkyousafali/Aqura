<script>
	import { createEventDispatcher } from 'svelte';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let show = false;

	const dispatch = createEventDispatcher();

	// All active users, for the "add user" search (anyone can be granted —
	// there's no prerequisite button permission for this table).
	let allUsers = [];
	let loadingUsers = false;

	// Rows currently in receiving_records_permissions, joined with a display name.
	let grantedRows = [];
	let loadingGranted = false;

	let error = '';
	let searchQuery = '';
	let addingUserId = null;
	let removingUserId = null;

	$: grantedUserIds = new Set(grantedRows.map((r) => r.user_id));
	$: searchResults = (() => {
		const q = searchQuery.trim().toLowerCase();
		if (!q) return [];
		return allUsers
			.filter((u) => !grantedUserIds.has(u.id))
			.filter((u) => (u.displayName || '').toLowerCase().includes(q) || (u.username || '').toLowerCase().includes(q))
			.slice(0, 25);
	})();

	$: if (show) {
		loadUsers();
		loadGranted();
	}

	async function fetchNameMap(employeeIds) {
		if (employeeIds.length === 0) return {};
		const { data } = await supabase.from('hr_employee_master').select('id, name_en').in('id', employeeIds);
		const map = {};
		(data || []).forEach((e) => { map[e.id] = e.name_en; });
		return map;
	}

	async function loadUsers() {
		loadingUsers = true;
		error = '';
		try {
			const { data: users, error: usersErr } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.eq('status', 'active')
				.order('username', { ascending: true });
			if (usersErr) throw usersErr;

			const empIds = [...new Set((users || []).filter((u) => u.employee_id).map((u) => u.employee_id))];
			const empMap = await fetchNameMap(empIds);

			allUsers = (users || []).map((u) => ({
				id: u.id,
				username: u.username,
				displayName: (u.employee_id && empMap[u.employee_id]) || u.username
			}));
		} catch (e) {
			error = e?.message || String(e);
		} finally {
			loadingUsers = false;
		}
	}

	async function loadGranted() {
		loadingGranted = true;
		try {
			const { data, error: gErr } = await supabase
				.from('receiving_records_permissions')
				.select('user_id, can_edit_erp_reference, can_edit_record, can_delete')
				.order('updated_at', { ascending: false });
			if (gErr) throw gErr;

			const rows = data || [];
			const userIds = rows.map((r) => r.user_id);
			let userMap = {};
			if (userIds.length > 0) {
				const { data: users } = await supabase.from('users').select('id, username, employee_id').in('id', userIds);
				(users || []).forEach((u) => { userMap[u.id] = u; });
			}
			const empIds = [...new Set(Object.values(userMap).filter((u) => u.employee_id).map((u) => u.employee_id))];
			const empMap = await fetchNameMap(empIds);

			grantedRows = rows.map((r) => {
				const u = userMap[r.user_id];
				return {
					user_id: r.user_id,
					username: u?.username || r.user_id,
					displayName: (u?.employee_id && empMap[u.employee_id]) || u?.username || r.user_id,
					can_edit_erp_reference: r.can_edit_erp_reference,
					can_edit_record: r.can_edit_record,
					can_delete: r.can_delete,
					saving: false
				};
			});
		} catch (e) {
			console.error('Error loading receiving records permissions:', e);
		} finally {
			loadingGranted = false;
		}
	}

	async function addUser(user) {
		const requestingUserId = get(currentUser)?.id;
		if (!requestingUserId || addingUserId) return;
		addingUserId = user.id;
		error = '';
		try {
			const { data, error: upErr } = await supabase.rpc('upsert_receiving_records_permission', {
				p_requesting_user_id: requestingUserId,
				p_target_user_id: user.id,
				p_can_edit_erp_reference: false,
				p_can_edit_record: false,
				p_can_delete: false
			});
			if (upErr) throw upErr;
			if (!data?.success) throw new Error(data?.error || 'Failed to add user');

			searchQuery = '';
			await loadGranted();
		} catch (e) {
			error = e?.message || String(e);
		} finally {
			addingUserId = null;
		}
	}

	async function toggle(row, field) {
		const requestingUserId = get(currentUser)?.id;
		if (!requestingUserId || row.saving) return;
		row.saving = true;
		grantedRows = grantedRows;
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
			grantedRows = grantedRows;
		}
	}

	async function removeUser(row) {
		const requestingUserId = get(currentUser)?.id;
		if (!requestingUserId || removingUserId) return;
		removingUserId = row.user_id;
		error = '';
		try {
			const { data, error: delErr } = await supabase.rpc('delete_receiving_records_permission', {
				p_requesting_user_id: requestingUserId,
				p_target_user_id: row.user_id
			});
			if (delErr) throw delErr;
			if (!data?.success) throw new Error(data?.error || 'Failed to remove user');
			await loadGranted();
		} catch (e) {
			error = e?.message || String(e);
		} finally {
			removingUserId = null;
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
<div class="fixed inset-0 z-[220] flex items-center justify-center bg-black/40 backdrop-blur-sm" on:click|self={close}>
	<div class="bg-white rounded-2xl shadow-2xl w-[92vw] max-w-[760px] h-[80vh] flex flex-col border border-slate-200 overflow-hidden">

		<!-- Header -->
		<div class="flex items-center justify-between px-6 py-4 bg-gradient-to-r from-indigo-700 to-indigo-600 text-white shrink-0">
			<div>
				<h2 class="text-base font-bold tracking-wide">Receiving Records — Edit Permission</h2>
				<p class="text-[11px] text-indigo-100">Master Admins always have full access. Add users below and toggle what they can do.</p>
			</div>
			<button class="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition-colors text-white text-lg" on:click={close}>×</button>
		</div>

		{#if error}
			<div class="mx-5 mt-3 px-3 py-2 bg-red-50 border border-red-300 rounded text-red-700 text-xs shrink-0">{error}</div>
		{/if}

		<!-- Add user -->
		<div class="p-4 border-b border-slate-200 shrink-0 relative z-20">
			<label for="rr-perm-search" class="block text-[10px] font-bold text-slate-500 uppercase tracking-wide mb-1.5">Add user</label>
			<input
				id="rr-perm-search"
				type="text"
				bind:value={searchQuery}
				placeholder="Search by name or username…"
				class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
			/>
			{#if searchQuery.trim()}
				<div class="absolute left-4 right-4 mt-1 bg-white border border-slate-200 rounded-lg shadow-lg max-h-56 overflow-y-auto z-30">
					{#if loadingUsers}
						<div class="px-3 py-2 text-sm text-slate-400">Loading users…</div>
					{:else if searchResults.length === 0}
						<div class="px-3 py-2 text-sm text-slate-400">No matching users</div>
					{:else}
						{#each searchResults as user (user.id)}
							<button
								type="button"
								class="w-full text-left px-3 py-2 hover:bg-slate-50 flex items-center justify-between gap-2 disabled:opacity-50"
								disabled={addingUserId === user.id}
								on:click={() => addUser(user)}
							>
								<div class="min-w-0">
									<div class="text-sm font-semibold text-slate-800 truncate">{user.displayName}</div>
									<div class="text-[10px] text-slate-400 truncate">{user.username}</div>
								</div>
								<span class="text-[10px] font-bold text-indigo-600 shrink-0">{addingUserId === user.id ? 'Adding…' : '+ Add'}</span>
							</button>
						{/each}
					{/if}
				</div>
			{/if}
		</div>

		<!-- Granted users table -->
		<div class="flex-1 overflow-y-auto">
			{#if loadingGranted}
				<div class="flex items-center justify-center h-40 text-slate-400 text-sm">Loading…</div>
			{:else if grantedRows.length === 0}
				<div class="flex items-center justify-center h-40 text-slate-400 text-sm text-center px-6">No users added yet — search above to add one.</div>
			{:else}
				<table class="w-full text-sm border-collapse">
					<thead class="sticky top-0 z-10 bg-slate-100">
						<tr>
							<th class="px-4 py-3 text-left font-black text-slate-700 border-b border-slate-200 w-[34%]">User</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Edit ERP Reference</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Edit Record</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200">Allow Delete</th>
							<th class="px-4 py-3 text-center font-black text-slate-700 border-b border-slate-200 w-10"></th>
						</tr>
					</thead>
					<tbody>
						{#each grantedRows as row (row.user_id)}
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
								<td class="px-4 py-3 text-center">
									<button
										type="button"
										on:click={() => removeUser(row)}
										disabled={removingUserId === row.user_id}
										title="Remove this user (revokes all three permissions)"
										class="w-6 h-6 rounded-full bg-red-50 hover:bg-red-100 text-red-500 flex items-center justify-center text-sm font-bold transition-colors disabled:opacity-50"
									>×</button>
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
