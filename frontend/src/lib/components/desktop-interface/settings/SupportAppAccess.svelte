<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';

	type Tab = 'pcLockGuard' | 'actionSync' | 'camChecker';
	let activeTab: Tab = 'camChecker';

	let supabase: any = null;

	// ── Cam Checker access list ──────────────────────────────────────────
	interface AccessRow {
		id: string;
		user_id: string;
		username: string;
		employee_name: string | null;
		granted_by_username: string | null;
		created_at: string;
	}

	let accessList: AccessRow[] = [];
	let listLoading = true;
	let listError = '';

	// ── Add User popup ───────────────────────────────────────────────────
	let showAddModal = false;
	let searchQuery = '';
	let searchResults: any[] = [];
	let selectedUserIds = new Set<string>();
	let searchTimeout: any = null;
	let adding = false;
	let addError = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadAccessList();
	});

	async function loadAccessList() {
		listLoading = true;
		listError = '';
		try {
			const { data, error } = await supabase.rpc('get_cam_checker_access_list');
			if (error) throw error;
			accessList = data ?? [];
		} catch (e: any) {
			listError = e.message ?? 'Failed to load access list';
		} finally {
			listLoading = false;
		}
	}

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleDateString(undefined, {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function openAddModal() {
		showAddModal = true;
		searchQuery = '';
		searchResults = [];
		selectedUserIds = new Set();
		addError = '';
		searchUsers('');
	}

	function closeAddModal() {
		showAddModal = false;
	}

	async function searchUsers(query: string) {
		const { data: users, error } = await supabase
			.from('users')
			.select('id, username, employee_id')
			.order('username')
			.ilike('username', query ? `%${query}%` : '%%')
			.limit(20);
		if (error || !users) { searchResults = []; return; }

		const employeeIds = [...new Set(users.filter((u: any) => u.employee_id).map((u: any) => u.employee_id))];
		let employeeNames: Record<string, string> = {};
		if (employeeIds.length > 0) {
			const { data: emps } = await supabase.from('hr_employees').select('id, name').in('id', employeeIds);
			(emps ?? []).forEach((e: any) => (employeeNames[e.id] = e.name));
		}
		searchResults = users.map((u: any) => ({ ...u, employee_name: u.employee_id ? employeeNames[u.employee_id] : null }));
	}

	function onSearchInput() {
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => searchUsers(searchQuery), 250);
	}

	function toggleSelectUser(id: string) {
		if (selectedUserIds.has(id)) selectedUserIds.delete(id);
		else selectedUserIds.add(id);
		selectedUserIds = selectedUserIds;
	}

	async function addSelectedUsers() {
		if (selectedUserIds.size === 0) return;
		adding = true;
		addError = '';
		try {
			const { data, error } = await supabase.rpc('grant_cam_checker_access', {
				p_requesting_user_id: $currentUser?.id,
				p_user_ids: Array.from(selectedUserIds)
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Failed to grant access');
			await loadAccessList();
			closeAddModal();
		} catch (e: any) {
			addError = e.message ?? 'Failed to grant access';
		} finally {
			adding = false;
		}
	}

	async function removeUser(userId: string) {
		if (!confirm('Remove this user\'s access to Aqura Cam Checker?')) return;
		try {
			const { data, error } = await supabase.rpc('revoke_cam_checker_access', {
				p_requesting_user_id: $currentUser?.id,
				p_user_id: userId
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Failed to revoke access');
			await loadAccessList();
		} catch (e: any) {
			listError = e.message ?? 'Failed to revoke access';
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Tabs -->
	<div class="flex items-center gap-2 px-4 pt-4 pb-2 bg-white border-b border-slate-200">
		<button
			type="button"
			class="px-4 py-2 rounded-full text-sm font-bold transition-all {activeTab === 'pcLockGuard' ? 'bg-red-500 text-white shadow' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}"
			on:click={() => (activeTab = 'pcLockGuard')}
		>
			🔒 Aqura PC Lock Guard
		</button>
		<button
			type="button"
			class="px-4 py-2 rounded-full text-sm font-bold transition-all {activeTab === 'actionSync' ? 'bg-red-500 text-white shadow' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}"
			on:click={() => (activeTab = 'actionSync')}
		>
			🔄 Aqura Action Sync
		</button>
		<button
			type="button"
			class="px-4 py-2 rounded-full text-sm font-bold transition-all {activeTab === 'camChecker' ? 'bg-red-500 text-white shadow' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}"
			on:click={() => (activeTab = 'camChecker')}
		>
			📷 Aqura Cam Checker
		</button>
	</div>

	<div class="flex-1 overflow-y-auto p-5">
		{#if activeTab === 'pcLockGuard'}
			<div class="flex flex-col items-center justify-center h-full text-slate-400 gap-2">
				<span class="text-4xl">🔒</span>
				<p class="text-sm font-bold">Aqura PC Lock Guard — Coming Soon</p>
			</div>
		{:else if activeTab === 'actionSync'}
			<div class="flex flex-col items-center justify-center h-full text-slate-400 gap-2">
				<span class="text-4xl">🔄</span>
				<p class="text-sm font-bold">Aqura Action Sync — Coming Soon</p>
			</div>
		{:else if activeTab === 'camChecker'}
			<div class="flex items-center justify-between mb-4">
				<h2 class="text-base font-black text-slate-700">Aqura Cam Checker — Access List</h2>
				<button
					type="button"
					class="px-4 py-2 rounded-xl text-sm font-bold text-white bg-red-500 hover:bg-red-600 shadow transition-all"
					on:click={openAddModal}
				>
					+ Add User
				</button>
			</div>

			<p class="text-xs text-slate-500 mb-4">
				Only users listed below (plus Master Admins) can log into the Aqura Cam Checker desktop app.
			</p>

			{#if listError}
				<div class="px-3 py-2 rounded-lg bg-red-50 border border-red-200 text-xs text-red-600 font-semibold mb-3">{listError}</div>
			{/if}

			{#if listLoading}
				<p class="text-sm text-slate-400">Loading…</p>
			{:else if accessList.length === 0}
				<p class="text-sm text-slate-400">No users have been granted access yet.</p>
			{:else}
				<div class="overflow-x-auto rounded-xl border border-slate-200">
					<table class="w-full text-sm">
						<thead class="bg-slate-50 text-slate-500 text-xs uppercase font-bold">
							<tr>
								<th class="text-left px-4 py-2">Username</th>
								<th class="text-left px-4 py-2">Employee</th>
								<th class="text-left px-4 py-2">Granted By</th>
								<th class="text-left px-4 py-2">Granted At</th>
								<th class="text-right px-4 py-2">Actions</th>
							</tr>
						</thead>
						<tbody>
							{#each accessList as row (row.id)}
								<tr class="border-t border-slate-100">
									<td class="px-4 py-2 font-semibold text-slate-700">{row.username}</td>
									<td class="px-4 py-2 text-slate-500">{row.employee_name ?? '—'}</td>
									<td class="px-4 py-2 text-slate-500">{row.granted_by_username ?? '—'}</td>
									<td class="px-4 py-2 text-slate-500">{formatDate(row.created_at)}</td>
									<td class="px-4 py-2 text-right">
										<button
											type="button"
											class="px-3 py-1 rounded-lg text-xs font-bold text-red-600 hover:bg-red-50"
											on:click={() => removeUser(row.user_id)}
										>
											Remove
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		{/if}
	</div>
</div>

{#if showAddModal}
	<div
		class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm flex items-center justify-center z-[9999]"
		on:click|self={closeAddModal}
		on:keydown={(e) => { if (e.key === 'Escape') closeAddModal(); }}
		role="presentation"
	>
		<div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 overflow-hidden">
			<div class="px-5 py-4 bg-red-500 text-white flex items-center justify-between">
				<h3 class="text-sm font-black uppercase tracking-wide">📷 Add User — Cam Checker Access</h3>
				<button class="text-white/80 hover:text-white text-lg leading-none" on:click={closeAddModal}>✕</button>
			</div>
			<div class="p-5 space-y-3">
				<input
					type="text"
					class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-400"
					placeholder="Search username..."
					bind:value={searchQuery}
					on:input={onSearchInput}
					style="color:#000;"
				/>
				<div class="max-h-64 overflow-y-auto border border-slate-100 rounded-xl divide-y divide-slate-50">
					{#each searchResults as u (u.id)}
						<label class="flex items-center gap-2 px-3 py-2 text-sm hover:bg-red-50 cursor-pointer">
							<input type="checkbox" checked={selectedUserIds.has(u.id)} on:change={() => toggleSelectUser(u.id)} />
							<span class="font-semibold text-slate-700">{u.username}</span>
							{#if u.employee_name}<span class="text-slate-400">— {u.employee_name}</span>{/if}
						</label>
					{:else}
						<p class="px-3 py-4 text-sm text-slate-400 text-center">No users found.</p>
					{/each}
				</div>
				{#if addError}
					<div class="px-3 py-2 rounded-lg bg-red-50 border border-red-200 text-xs text-red-600 font-semibold">{addError}</div>
				{/if}
			</div>
			<div class="px-5 py-4 bg-slate-50 border-t border-slate-100 flex items-center justify-end gap-2">
				<button class="px-4 py-2 rounded-xl text-sm font-bold text-slate-500 hover:bg-slate-100 transition-all" on:click={closeAddModal}>Cancel</button>
				<button
					class="px-5 py-2 rounded-xl text-sm font-bold text-white transition-all
						{selectedUserIds.size > 0 && !adding ? 'bg-red-500 hover:bg-red-600 shadow-lg shadow-red-200' : 'bg-slate-300 cursor-not-allowed'}"
					disabled={selectedUserIds.size === 0 || adding}
					on:click={addSelectedUsers}
				>
					{adding ? 'Adding…' : `Add ${selectedUserIds.size > 0 ? selectedUserIds.size : ''}`}
				</button>
			</div>
		</div>
	</div>
{/if}
