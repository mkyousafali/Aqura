<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

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

	let rows: PermRow[] = [];
	let loading = true;
	let searchQuery = '';

	$: filtered = rows.filter(r => {
		if (!searchQuery.trim()) return true;
		const s = searchQuery.toLowerCase();
		return (r.username || '').toLowerCase().includes(s)
			|| (r.employee_name_en || '').toLowerCase().includes(s);
	});

	onMount(async () => {
		await loadPermissions();
	});

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
</div>
