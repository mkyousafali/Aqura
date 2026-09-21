<script lang="ts">
	import { onMount } from 'svelte';
	import { locale } from '$lib/i18n';

	type PermissionType = 'receiver' | 'depositor' | 'printer';
	type Branch = { id: number; name_en: string; name_ar: string };
	type Employee = { user_id: string; id: string; name_en: string | null; name_ar: string | null };
	type Grant = { id: string; branch_id: number; user_id: string; permission_type: PermissionType;
		userName: string; employeeId: string; addedByName: string; created_at: string };
	const sections: { id: PermissionType; label: string }[] = [
		{ id: 'receiver', label: 'Safe Box Request Receivers' },
		{ id: 'depositor', label: 'Safe Box Depositors' },
		{ id: 'printer', label: 'Safe Box & Cashier Printer Settings Access' }
	];
	let active: PermissionType = 'receiver';
	let branches: Branch[] = [];
	let grants: Grant[] = [];
	let showAdd = false;
	let selectedBranchId = '';
	let search = '';
	let matches: Employee[] = [];
	let selectedUser: Employee | null = null;
	let busy = false;
	let message = '';
	let setupPending = false;
	let searchTimer: ReturnType<typeof setTimeout>;
	let searchSequence = 0;

	$: rows = grants.filter(grant => grant.permission_type === active);
	function branchName(id: number) {
		const branch = branches.find(item => Number(item.id) === Number(id));
		return branch ? ($locale === 'ar' ? branch.name_ar || branch.name_en : branch.name_en || branch.name_ar) : `Branch ${id}`;
	}
	function employeeName(employee: Employee) {
		return ($locale === 'ar' ? employee.name_ar || employee.name_en : employee.name_en || employee.name_ar) || employee.id;
	}
	async function load() {
		try {
			const response = await fetch('/api/safe-box/control', { cache: 'no-store' });
			const result = await response.json();
			setupPending = response.status === 503;
			if (!response.ok) throw new Error(result.error || 'Could not load permissions.');
			message = '';
			branches = result.branches || [];
			grants = result.grants || [];
		} catch (error) { message = error instanceof Error ? error.message : 'Could not load permissions.'; }
	}
	function resetForm() {
		showAdd = false; selectedBranchId = ''; search = ''; matches = []; selectedUser = null;
		searchSequence++; clearTimeout(searchTimer);
	}
	function changeBranch(event: Event) {
		selectedBranchId = (event.currentTarget as HTMLSelectElement).value;
		search = ''; matches = []; selectedUser = null; searchSequence++; clearTimeout(searchTimer);
	}
	function queueSearch() {
		selectedUser = null; matches = []; clearTimeout(searchTimer);
		const sequence = ++searchSequence;
		if (!selectedBranchId || !search.trim()) return;
		searchTimer = setTimeout(async () => {
			try {
				const params = new URLSearchParams({ branchId: selectedBranchId, search: search.trim() });
				const response = await fetch(`/api/safe-box/control/users?${params}`, { cache: 'no-store' });
				const result = await response.json();
				if (!response.ok) throw new Error(result.error || 'Could not search users.');
				if (sequence === searchSequence) matches = result.users || [];
			} catch (error) { if (sequence === searchSequence) message = error instanceof Error ? error.message : 'Could not search users.'; }
		}, 250);
	}
	async function addPermission() {
		if (!selectedBranchId || !selectedUser) { message = 'Select a branch and user.'; return; }
		busy = true; message = '';
		try {
			const response = await fetch('/api/safe-box/control', { method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ branchId: Number(selectedBranchId), userId: selectedUser.user_id, permissionType: active }) });
			const result = await response.json();
			if (!response.ok) throw new Error(result.error || 'Could not add permission.');
			resetForm(); await load();
		} catch (error) { message = error instanceof Error ? error.message : 'Could not add permission.'; }
		finally { busy = false; }
	}
	async function removePermission(id: string) {
		busy = true; message = '';
		try {
			const response = await fetch('/api/safe-box/control', { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ id }) });
			const result = await response.json();
			if (!response.ok) throw new Error(result.error || 'Could not remove permission.');
			await load();
		} catch (error) { message = error instanceof Error ? error.message : 'Could not remove permission.'; }
		finally { busy = false; }
	}
	onMount(() => {
		void load();
		const events = new EventSource('/api/safe-box/control/events');
		events.addEventListener('change', () => void load());
		return () => { events.close(); clearTimeout(searchTimer); };
	});
</script>

<div class="h-full overflow-auto bg-slate-50 p-5 space-y-4">
	<div class="flex flex-wrap gap-2">
		{#each sections as section}
			<button type="button" class="rounded-lg border px-4 py-2 text-sm font-semibold {active === section.id ? 'border-blue-600 bg-blue-600 text-white' : 'border-slate-300 bg-white text-slate-700'}"
				on:click={() => { active = section.id; resetForm(); if (!setupPending) message = ''; }}>{section.label}</button>
		{/each}
	</div>
	<div class="rounded-xl border border-slate-200 bg-white p-5 shadow-sm space-y-4">
		<div class="flex items-center justify-between gap-3">
			<h2 class="text-lg font-bold text-slate-900">{sections.find(section => section.id === active)?.label}</h2>
			<button type="button" class="rounded-lg bg-blue-600 px-3 py-2 text-white font-bold disabled:opacity-50" disabled={setupPending} on:click={() => { resetForm(); showAdd = true; }}>+ Add</button>
		</div>
		{#if showAdd}
			<div class="rounded-lg border border-blue-200 bg-blue-50 p-4 space-y-3">
				<label class="block text-sm font-semibold">Branch
					<select class="mt-1 w-full rounded border border-slate-300 bg-white p-2" value={selectedBranchId} on:change={changeBranch}>
						<option value="">Select branch</option>
						{#each branches as branch}<option value={branch.id}>{branchName(branch.id)}</option>{/each}
					</select>
				</label>
				<label class="block text-sm font-semibold">User from selected branch
					<input class="mt-1 w-full rounded border border-slate-300 bg-white p-2" type="search" placeholder="Search name or employee ID" disabled={!selectedBranchId}
						bind:value={search} on:input={queueSearch} />
				</label>
				{#if matches.length && !selectedUser}
					<div class="max-h-40 overflow-auto rounded border border-slate-200 bg-white">
						{#each matches as employee}<button type="button" class="block w-full p-2 text-left hover:bg-blue-50" on:click={() => { selectedUser = employee; search = employeeName(employee); matches = []; }}>{employeeName(employee)} · {employee.id}</button>{/each}
					</div>
				{/if}
				<div class="flex gap-2"><button type="button" class="rounded bg-blue-600 px-3 py-2 text-white disabled:opacity-50" disabled={busy || !selectedUser} on:click={addPermission}>Save</button>
					<button type="button" class="rounded border border-slate-300 px-3 py-2" on:click={resetForm}>Cancel</button></div>
			</div>
		{/if}
		{#if message}<p role="status" class="text-sm text-red-700">{message}</p>{/if}
		<div class="overflow-x-auto"><table class="w-full text-left text-sm">
			<thead class="bg-slate-100 text-slate-700"><tr><th class="p-2">Branch</th><th class="p-2">User</th><th class="p-2">Employee ID</th><th class="p-2">Added By</th><th class="p-2">Added At</th><th class="p-2">Action</th></tr></thead>
			<tbody>{#each rows as row (row.id)}<tr class="border-t border-slate-200"><td class="p-2">{branchName(row.branch_id)}</td><td class="p-2">{row.userName}</td><td class="p-2">{row.employeeId || '—'}</td><td class="p-2">{row.addedByName}</td><td class="p-2">{new Date(row.created_at).toLocaleString()}</td><td class="p-2"><button type="button" class="text-red-700 font-semibold disabled:opacity-50" disabled={busy} on:click={() => removePermission(row.id)}>Remove</button></td></tr>{:else}<tr><td class="p-4 text-slate-500" colspan="6">No users configured.</td></tr>{/each}</tbody>
		</table></div>
	</div>
</div>
