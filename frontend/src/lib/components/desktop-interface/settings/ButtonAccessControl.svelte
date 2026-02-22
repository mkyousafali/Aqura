<script lang="ts">
	import { onMount } from 'svelte';

	// ── State ──
	let selectedBranch = '';
	let selectedPosition = '';
	let searchUsername = '';
	let branches: any[] = [];
	let positions: any[] = [];
	let users: any[] = [];
	let usersLoading = false;
	let currentPage = 0;
	let pageSize = 50;
	let totalUsers = 0;
	let filterTimeout: any = null;
	let searchTimeout: any = null;

	// Selected user (single)
	let selectedUserId: string | null = null;
	let selectedUserName: string = '';

	// Permissions panel
	let allButtons: any[] = [];
	let permissionMap: Map<string, boolean> = new Map(); // code → enabled
	let buttonsLoading = false;
	let buttonCodeToIdMap: Map<string, number> = new Map();
	let buttonSearchQuery = '';
	let buttonSectionFilter = '';
	let availableSections: string[] = [];
	let saving = false;
	let saveSuccess = false;
	let pendingChanges: Map<string, boolean> = new Map(); // code → new state
	let showOnlyEnabled = false;
	let showOnlyDisabled = false;

	// Filtered buttons (reactive)
	$: filteredButtons = allButtons.filter(btn => {
		if (buttonSearchQuery) {
			const q = buttonSearchQuery.toLowerCase();
			if (!btn.name.toLowerCase().includes(q) && !btn.code.toLowerCase().includes(q) && !btn.section.toLowerCase().includes(q) && !btn.subsection.toLowerCase().includes(q)) return false;
		}
		if (buttonSectionFilter && btn.section !== buttonSectionFilter) return false;
		if (showOnlyEnabled) {
			const state = pendingChanges.has(btn.code) ? pendingChanges.get(btn.code) : permissionMap.get(btn.code);
			if (!state) return false;
		}
		if (showOnlyDisabled) {
			const state = pendingChanges.has(btn.code) ? pendingChanges.get(btn.code) : permissionMap.get(btn.code);
			if (state) return false;
		}
		return true;
	});

	$: enabledCount = allButtons.filter(btn => {
		const state = pendingChanges.has(btn.code) ? pendingChanges.get(btn.code) : permissionMap.get(btn.code);
		return state === true;
	}).length;

	$: disabledCount = allButtons.length - enabledCount;
	$: changesCount = pendingChanges.size;

	onMount(async () => {
		await Promise.all([fetchBranches(), fetchPositions()]);
		await loadUsers();
	});

	$: if (selectedBranch !== undefined && selectedPosition !== undefined) {
		currentPage = 0;
		clearTimeout(filterTimeout);
		filterTimeout = setTimeout(() => loadUsers(), 300);
	}

	$: if (searchUsername !== undefined) {
		currentPage = 0;
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => loadUsers(), 300);
	}

	async function fetchPositions() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('hr_positions')
				.select('id, position_title_en')
				.eq('is_active', true)
				.order('position_title_en', { ascending: true });
			if (!error && data) {
				positions = data.map(p => ({ id: p.id, position_name: p.position_title_en }));
			}
		} catch (err) {
			console.error('Error fetching positions:', err);
		}
	}

	async function fetchBranches() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase.from('branches').select('id, name_en, name_ar').eq('is_active', true).order('name_en', { ascending: true });
			if (!error && data) {
				branches = data;
				selectedBranch = '';
			}
		} catch (err) {
			console.error('Error fetching branches:', err);
		}
	}

	async function loadUsers() {
		usersLoading = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			let countQuery = supabase.from('users').select('id', { count: 'exact' });
			let dataQuery = supabase
				.from('users')
				.select('id, username, is_master_admin, is_admin, branch_id, position_id, employee_id, branches (name_en)', { count: 'exact' })
				.order('username', { ascending: true })
				.range(currentPage * pageSize, (currentPage + 1) * pageSize - 1);

			if (selectedBranch && selectedBranch !== '') {
				const bId = parseInt(selectedBranch);
				countQuery = countQuery.eq('branch_id', bId);
				dataQuery = dataQuery.eq('branch_id', bId);
			}
			if (selectedPosition && selectedPosition !== '') {
				countQuery = countQuery.eq('position_id', selectedPosition);
				dataQuery = dataQuery.eq('position_id', selectedPosition);
			}
			if (searchUsername && searchUsername !== '') {
				countQuery = countQuery.ilike('username', `%${searchUsername}%`);
				dataQuery = dataQuery.ilike('username', `%${searchUsername}%`);
			}

			const [countResult, dataResult] = await Promise.all([countQuery, dataQuery]);
			if (countResult.error || dataResult.error) return;

			const data = dataResult.data || [];
			totalUsers = countResult.count || 0;
			if (data.length === 0) { users = []; return; }

			const employeeIds = [...new Set(data.filter(u => u.employee_id).map(u => u.employee_id))];
			const positionIds = [...new Set(data.filter(u => u.position_id).map(u => u.position_id))];
			const [empRes, posRes] = await Promise.all([
				employeeIds.length > 0 ? supabase.from('hr_employees').select('id, name').in('id', employeeIds) : Promise.resolve({ data: [] }),
				positionIds.length > 0 ? supabase.from('hr_positions').select('id, position_title_en').in('id', positionIds) : Promise.resolve({ data: [] })
			]);

			const empMap: Record<string, string> = {};
			const posMap: Record<string, string> = {};
			empRes.data?.forEach((e: any) => { empMap[e.id] = e.name; });
			posRes.data?.forEach((p: any) => { posMap[p.id] = p.position_title_en; });

			users = data.map(user => ({
				...user,
				employee_name: empMap[user.employee_id] || user.username,
				position_title: posMap[user.position_id] || null
			}));
		} catch (err) {
			console.error('Error fetching users:', err);
		} finally {
			usersLoading = false;
		}
	}

	function nextPage() {
		if ((currentPage + 1) * pageSize < totalUsers) { currentPage++; loadUsers(); }
	}
	function prevPage() {
		if (currentPage > 0) { currentPage--; loadUsers(); }
	}

	function selectUser(user: any) {
		selectedUserId = user.id;
		selectedUserName = user.employee_name || user.username;
		pendingChanges = new Map();
		saveSuccess = false;
		loadButtonPermissions();
	}

	async function loadButtonPermissions() {
		if (!selectedUserId) return;
		buttonsLoading = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');

			const [btnRes, secRes, subRes] = await Promise.all([
				supabase.from('sidebar_buttons').select('id, button_code, button_name_en, main_section_id, subsection_id').order('button_code'),
				supabase.from('button_main_sections').select('id, section_name_en'),
				supabase.from('button_sub_sections').select('id, subsection_name_en')
			]);

			const mainMap = new Map(secRes.data?.map((s: any) => [s.id, s.section_name_en]) || []);
			const subMap = new Map(subRes.data?.map((s: any) => [s.id, s.subsection_name_en]) || []);

			if (btnRes.error || !btnRes.data?.length) return;

			allButtons = btnRes.data.map((btn: any) => ({
				code: btn.button_code,
				name: btn.button_name_en,
				section: mainMap.get(btn.main_section_id) || 'Unknown',
				subsection: subMap.get(btn.subsection_id) || 'Unknown'
			})).sort((a: any, b: any) => {
				const sc = a.section.localeCompare(b.section);
				return sc !== 0 ? sc : a.name.localeCompare(b.name);
			});

			availableSections = [...new Set(allButtons.map((b: any) => b.section))].sort();

			buttonCodeToIdMap.clear();
			btnRes.data.forEach((btn: any) => { buttonCodeToIdMap.set(btn.button_code, btn.id); });

			const { data: perms } = await supabase
				.from('button_permissions')
				.select('button_id, is_enabled')
				.eq('user_id', selectedUserId);

			const enabledIds = new Set<number>();
			perms?.forEach((p: any) => { if (p.is_enabled) enabledIds.add(p.button_id); });

			permissionMap = new Map();
			allButtons.forEach((btn: any) => {
				const id = buttonCodeToIdMap.get(btn.code);
				permissionMap.set(btn.code, id ? enabledIds.has(id) : false);
			});
			permissionMap = permissionMap; // trigger reactivity
		} catch (err) {
			console.error('Error loading permissions:', err);
		} finally {
			buttonsLoading = false;
		}
	}

	function toggleButton(code: string) {
		const currentState = pendingChanges.has(code) ? pendingChanges.get(code) : permissionMap.get(code);
		const originalState = permissionMap.get(code);
		const newState = !currentState;

		if (newState === originalState) {
			pendingChanges.delete(code);
		} else {
			pendingChanges.set(code, newState);
		}
		pendingChanges = pendingChanges; // reactivity
	}

	function enableAll() {
		for (const btn of filteredButtons) {
			const orig = permissionMap.get(btn.code);
			if (orig) { pendingChanges.delete(btn.code); }
			else { pendingChanges.set(btn.code, true); }
		}
		pendingChanges = pendingChanges;
	}

	function disableAll() {
		for (const btn of filteredButtons) {
			const orig = permissionMap.get(btn.code);
			if (!orig) { pendingChanges.delete(btn.code); }
			else { pendingChanges.set(btn.code, false); }
		}
		pendingChanges = pendingChanges;
	}

	async function savePermissions() {
		if (!selectedUserId || pendingChanges.size === 0) return;
		saving = true;
		saveSuccess = false;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const upserts: any[] = [];
			for (const [code, enabled] of pendingChanges) {
				const buttonId = buttonCodeToIdMap.get(code);
				if (!buttonId) continue;
				upserts.push({ user_id: selectedUserId, button_id: buttonId, is_enabled: enabled });
			}

			if (upserts.length > 0) {
				const { error } = await supabase
					.from('button_permissions')
					.upsert(upserts, { onConflict: 'user_id,button_id' });
				if (error) throw error;
			}

			// Apply pending changes to permission map
			for (const [code, enabled] of pendingChanges) {
				permissionMap.set(code, enabled);
			}
			permissionMap = permissionMap;
			pendingChanges = new Map();
			saveSuccess = true;
			setTimeout(() => { saveSuccess = false; }, 3000);
		} catch (err) {
			console.error('Error saving permissions:', err);
		} finally {
			saving = false;
		}
	}

	function getButtonState(code: string): boolean {
		return pendingChanges.has(code) ? pendingChanges.get(code)! : (permissionMap.get(code) || false);
	}

	function isChanged(code: string): boolean {
		return pendingChanges.has(code);
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Two-Panel Layout -->
	<div class="flex-1 flex overflow-hidden">

		<!-- ═══════════ LEFT PANEL: EMPLOYEES ═══════════ -->
		<div class="flex flex-col border-r border-slate-200 bg-white" style="width: 420px; min-width: 320px;">
			<!-- Panel Header -->
			<div class="px-4 py-3 bg-gradient-to-r from-emerald-600 to-emerald-700 text-white flex items-center gap-2 shadow-md">
				<span class="text-lg">👥</span>
				<span class="text-sm font-black uppercase tracking-wider">Employees</span>
				<span class="ml-auto text-xs font-bold bg-white/20 px-2 py-0.5 rounded-full">{totalUsers}</span>
			</div>

			<!-- Filters -->
			<div class="p-3 border-b border-slate-100 space-y-2 bg-slate-50/50">
				<!-- Search -->
				<div class="relative">
					<svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
					<input type="text" bind:value={searchUsername} placeholder="Search employee..." class="w-full pl-9 pr-8 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all" />
					{#if searchUsername}
						<button class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-sm" on:click={() => searchUsername = ''}>✕</button>
					{/if}
				</div>

				<!-- Dropdowns row -->
				<div class="flex gap-2">
					<select bind:value={selectedBranch} class="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" style="color: #000;">
						<option value="">All Branches</option>
						{#each branches as br (br.id)}
							<option value={br.id}>{br.name_en}</option>
						{/each}
					</select>
					<select bind:value={selectedPosition} class="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" style="color: #000;">
						<option value="">All Positions</option>
						{#each positions as pos (pos.id)}
							<option value={pos.id}>{pos.position_name}</option>
						{/each}
					</select>
				</div>
			</div>

			<!-- Loading bar -->
			{#if usersLoading}
				<div class="h-0.5 w-full bg-slate-100 overflow-hidden">
					<div class="h-full bg-emerald-500 animate-loading-bar"></div>
				</div>
			{/if}

			<!-- Employee List (scrollable) -->
			<div class="flex-1 overflow-y-auto">
				{#if usersLoading && users.length === 0}
					<div class="flex items-center justify-center h-full">
						<div class="animate-spin w-8 h-8 border-3 border-slate-200 border-t-emerald-600 rounded-full"></div>
					</div>
				{:else if users.length === 0}
					<div class="flex items-center justify-center h-full text-slate-400 text-sm">
						<div class="text-center">
							<div class="text-3xl mb-2">📭</div>
							No employees found
						</div>
					</div>
				{:else}
					{#each users as user (user.id)}
						<button
							class="w-full text-left px-4 py-3 border-b border-slate-100 transition-all duration-150 hover:bg-emerald-50/60 flex items-center gap-3 group
								{selectedUserId === user.id ? 'bg-emerald-50 border-l-[3px] border-l-emerald-600' : ''}"
							on:click={() => selectUser(user)}
						>
							<!-- Avatar -->
							<div class="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0
								{selectedUserId === user.id ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-500 group-hover:bg-emerald-100 group-hover:text-emerald-700'}">
								{(user.employee_name || user.username || '?').charAt(0).toUpperCase()}
							</div>
							<div class="min-w-0 flex-1">
								<div class="text-sm font-semibold text-slate-800 truncate">{user.employee_name}</div>
								<div class="flex items-center gap-1.5 mt-0.5">
									<span class="text-[11px] text-slate-400 truncate">{user.branches?.name_en || '-'}</span>
									<span class="text-[10px] px-1.5 py-0 rounded-full font-bold
										{user.is_master_admin ? 'bg-purple-100 text-purple-700' : user.is_admin ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-500'}">
										{user.is_master_admin ? 'Master' : user.is_admin ? 'Admin' : 'User'}
									</span>
								</div>
							</div>
							{#if selectedUserId === user.id}
								<div class="w-2 h-2 rounded-full bg-emerald-500 flex-shrink-0"></div>
							{/if}
						</button>
					{/each}
				{/if}
			</div>

			<!-- Pagination Footer -->
			<div class="px-3 py-2 bg-slate-50 border-t border-slate-200 flex items-center justify-between text-xs text-slate-500">
				<button class="px-2.5 py-1 rounded-lg bg-white border border-slate-200 hover:bg-emerald-50 hover:border-emerald-300 disabled:opacity-40 disabled:cursor-not-allowed transition-all font-semibold" disabled={currentPage === 0 || usersLoading} on:click={prevPage}>← Prev</button>
				<span>Page {currentPage + 1}/{Math.max(1, Math.ceil(totalUsers / pageSize))}</span>
				<button class="px-2.5 py-1 rounded-lg bg-white border border-slate-200 hover:bg-emerald-50 hover:border-emerald-300 disabled:opacity-40 disabled:cursor-not-allowed transition-all font-semibold" disabled={(currentPage + 1) * pageSize >= totalUsers || usersLoading} on:click={nextPage}>Next →</button>
			</div>
		</div>

		<!-- ═══════════ RIGHT PANEL: PERMISSIONS ═══════════ -->
		<div class="flex-1 flex flex-col bg-[#f8fafc] min-w-0">
			{#if !selectedUserId}
				<!-- Empty state -->
				<div class="flex-1 flex items-center justify-center">
					<div class="text-center">
						<div class="w-24 h-24 mx-auto mb-4 rounded-full bg-slate-100 flex items-center justify-center">
							<span class="text-4xl">🔐</span>
						</div>
						<h3 class="text-lg font-bold text-slate-700 mb-1">Select an Employee</h3>
						<p class="text-sm text-slate-400">Choose an employee from the left panel to manage their button permissions</p>
					</div>
				</div>
			{:else}
				<!-- Permission Panel Header -->
				<div class="px-5 py-3 bg-gradient-to-r from-sky-600 to-sky-700 text-white flex items-center gap-3 shadow-md">
					<span class="text-lg">🔐</span>
					<div class="flex-1 min-w-0">
						<div class="text-sm font-black uppercase tracking-wider">Permissions</div>
						<div class="text-xs opacity-80 truncate">{selectedUserName}</div>
					</div>
					<div class="flex items-center gap-2">
						<span class="text-xs font-bold bg-emerald-500/30 px-2 py-0.5 rounded-full">✓ {enabledCount}</span>
						<span class="text-xs font-bold bg-red-500/30 px-2 py-0.5 rounded-full">✕ {disabledCount}</span>
					</div>
				</div>

				<!-- Filters & Actions Bar -->
				<div class="p-3 border-b border-slate-200 bg-white space-y-2">
					<div class="flex gap-2">
						<!-- Search buttons -->
						<div class="relative flex-1">
							<svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
							<input type="text" bind:value={buttonSearchQuery} placeholder="Search buttons..." class="w-full pl-9 pr-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-sky-500 focus:border-transparent transition-all" />
						</div>
						<!-- Section filter -->
						<select bind:value={buttonSectionFilter} class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500 focus:border-transparent" style="color: #000; min-width: 140px;">
							<option value="">All Sections</option>
							{#each availableSections as sec}
								<option value={sec}>{sec}</option>
							{/each}
						</select>
					</div>
					<div class="flex items-center gap-2">
						<!-- Quick filter toggles -->
						<button class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all border {showOnlyEnabled ? 'bg-emerald-100 border-emerald-300 text-emerald-700' : 'bg-white border-slate-200 text-slate-500 hover:bg-emerald-50'}" on:click={() => { showOnlyEnabled = !showOnlyEnabled; showOnlyDisabled = false; }}>
							✓ Enabled
						</button>
						<button class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all border {showOnlyDisabled ? 'bg-red-100 border-red-300 text-red-700' : 'bg-white border-slate-200 text-slate-500 hover:bg-red-50'}" on:click={() => { showOnlyDisabled = !showOnlyDisabled; showOnlyEnabled = false; }}>
							✕ Disabled
						</button>

						<div class="flex-1"></div>

						<!-- Bulk actions -->
						<button class="px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 text-white hover:bg-emerald-700 transition-all shadow-sm" on:click={enableAll} title="Enable all visible buttons">
							Enable All ({filteredButtons.length})
						</button>
						<button class="px-3 py-1.5 rounded-lg text-xs font-bold bg-red-500 text-white hover:bg-red-600 transition-all shadow-sm" on:click={disableAll} title="Disable all visible buttons">
							Disable All
						</button>
					</div>
				</div>

				<!-- Buttons Table -->
				<div class="flex-1 overflow-y-auto">
					{#if buttonsLoading}
						<div class="flex items-center justify-center h-full">
							<div class="text-center">
								<div class="animate-spin inline-block">
									<div class="w-10 h-10 border-4 border-sky-200 border-t-sky-600 rounded-full"></div>
								</div>
								<p class="mt-3 text-slate-500 text-sm font-semibold">Loading permissions...</p>
							</div>
						</div>
					{:else if filteredButtons.length === 0}
						<div class="flex items-center justify-center h-full text-slate-400 text-sm">
							<div class="text-center">
								<div class="text-3xl mb-2">🔍</div>
								No buttons match your filter
							</div>
						</div>
					{:else}
						<table class="w-full border-collapse">
							<thead class="sticky top-0 bg-sky-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-2.5 text-left text-[11px] font-black uppercase tracking-wider" style="width: 40px;">#</th>
									<th class="px-4 py-2.5 text-left text-[11px] font-black uppercase tracking-wider">Button Name</th>
									<th class="px-4 py-2.5 text-left text-[11px] font-black uppercase tracking-wider">Section</th>
									<th class="px-4 py-2.5 text-left text-[11px] font-black uppercase tracking-wider">Subsection</th>
									<th class="px-4 py-2.5 text-center text-[11px] font-black uppercase tracking-wider" style="width: 90px;">Access</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-100">
								{#each filteredButtons as button, idx (button.code)}
									{@const enabled = getButtonState(button.code)}
									{@const changed = isChanged(button.code)}
									<tr class="transition-colors duration-150 {changed ? 'bg-amber-50/60' : idx % 2 === 0 ? 'bg-white' : 'bg-slate-50/40'} hover:bg-sky-50/40">
										<td class="px-4 py-2.5 text-xs text-slate-400 font-semibold">{idx + 1}</td>
										<td class="px-4 py-2.5 text-sm text-slate-800 font-medium">
											{button.name}
											{#if changed}
												<span class="inline-block w-1.5 h-1.5 rounded-full bg-amber-400 ml-1 align-middle" title="Unsaved change"></span>
											{/if}
										</td>
										<td class="px-4 py-2.5 text-xs text-slate-500">{button.section}</td>
										<td class="px-4 py-2.5 text-xs text-slate-500">{button.subsection}</td>
										<td class="px-4 py-2.5 text-center">
											<button
												class="relative w-11 h-6 rounded-full transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-1 {enabled ? 'bg-emerald-500 focus:ring-emerald-400' : 'bg-slate-300 focus:ring-slate-400'}"
												on:click={() => toggleButton(button.code)}
												title={enabled ? 'Click to disable' : 'Click to enable'}
											>
												<span class="absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform duration-200 {enabled ? 'translate-x-5' : 'translate-x-0'}"></span>
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				</div>

				<!-- Save Bar -->
				<div class="px-5 py-3 bg-white border-t border-slate-200 flex items-center gap-3 shadow-[0_-4px_12px_rgba(0,0,0,0.04)]">
					{#if saveSuccess}
						<div class="flex items-center gap-2 text-emerald-600 font-bold text-sm animate-fade-in">
							<span class="text-lg">✅</span> Changes saved successfully!
						</div>
					{/if}

					<div class="flex-1"></div>

					{#if changesCount > 0}
						<span class="text-xs text-amber-600 font-bold bg-amber-50 px-3 py-1 rounded-full border border-amber-200">
							{changesCount} unsaved change{changesCount !== 1 ? 's' : ''}
						</span>
					{/if}

					<button
						class="px-5 py-2 rounded-xl text-sm font-bold transition-all duration-200
							{changesCount > 0
								? 'bg-sky-600 text-white hover:bg-sky-700 shadow-lg shadow-sky-200 hover:shadow-xl'
								: 'bg-slate-100 text-slate-400 cursor-not-allowed'}"
						disabled={changesCount === 0 || saving}
						on:click={savePermissions}
					>
						{#if saving}
							<span class="inline-block animate-spin mr-1">⏳</span> Saving...
						{:else}
							💾 Save Changes
						{/if}
					</button>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	@keyframes loading-bar {
		0% { transform: translateX(-100%); }
		100% { transform: translateX(200%); }
	}
	.animate-loading-bar {
		animation: loading-bar 1.2s ease-in-out infinite;
		width: 40%;
	}
	@keyframes fade-in {
		from { opacity: 0; transform: translateY(4px); }
		to { opacity: 1; transform: translateY(0); }
	}
	.animate-fade-in {
		animation: fade-in 0.3s ease;
	}
</style>
