<script lang="ts">
	// Both tabs share the same live ERP Users table (User ID + User Name) pulled
	// via each branch's tunnel. Login's action column links a row to an Aqura
	// user; Authorization's sets that same (user, branch) row's password.
	// Both persist to user_erp_credentials — one row per (user_id,
	// aqura_branch_id), see supabase/migrations/20260901_recreate_user_erp_credentials.sql.
	// This is the admin-side counterpart to the mobile ERP Access page, which
	// reads the same table to render the user's own QR codes.
	let activeTab: 'login' | 'authorization' | 'linked-login' | 'linked-auth' = 'login';

	const tabs = [
		{ id: 'login' as const, icon: '🔑', label: 'Login' },
		{ id: 'authorization' as const, icon: '🛡️', label: 'Authorization' },
		{ id: 'linked-login' as const, icon: '👤', label: 'Login Linked Users' },
		{ id: 'linked-auth' as const, icon: '🔐', label: 'Authorization Users' }
	];

	interface ErpConnection {
		branch_id: number;
		branch_name: string;
		tunnel_url: string;
		erp_branch_id: number;
	}

	interface ErpUserRow {
		branch_id: number;      // Aqura branch id
		branch_name: string;
		erp_branch_id: number;  // ERP's own branch id
		UserID: string | number;
		UserName: string;
	}

	let erpConnections: ErpConnection[] = [];
	let selectedBranchId: number | 'all' = 'all';
	let erpUsers: ErpUserRow[] = [];
	let loadingUsers = false;
	let usersError = '';
	let hasLoaded = false;
	// Shared across both tabs, same as the branch filter — search by ERP username.
	let userSearch = '';
	$: filteredErpUsers = erpUsers.filter((u) =>
		!userSearch.trim() || u.UserName.toLowerCase().includes(userSearch.trim().toLowerCase())
	);

	async function loadErpConnections() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('erp_connections')
				.select('branch_id, branch_name, tunnel_url, erp_branch_id')
				.eq('is_active', true)
				.order('branch_name');
			if (error) throw error;
			erpConnections = (data || []).filter((c: ErpConnection) => c.tunnel_url);
		} catch (err: any) {
			console.error('Error loading ERP connections:', err);
		}
	}

	async function queryBranchUsers(conn: ErpConnection): Promise<ErpUserRow[]> {
		const sql = `SELECT UserID, UserName FROM Users WHERE BranchID=${conn.erp_branch_id} ORDER BY UserID`;
		const response = await fetch('/api/erp-products', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ action: 'query', tunnelUrl: conn.tunnel_url, sql })
		});
		const data = await response.json();
		if (!data.success) throw new Error(data.error || `Query failed for ${conn.branch_name}`);
		return (data.recordset || []).map((r: any) => ({
			branch_id: conn.branch_id,
			branch_name: conn.branch_name,
			erp_branch_id: conn.erp_branch_id,
			UserID: r.UserID,
			UserName: r.UserName
		}));
	}

	// Numeric-aware UserID comparison — falls back to string comparison if
	// either side isn't a plain number, so this sorts correctly (1, 2, ... 10)
	// regardless of how the ERP column is typed/collated.
	function compareUserId(a: ErpUserRow, b: ErpUserRow): number {
		const aNum = Number(a.UserID);
		const bNum = Number(b.UserID);
		if (!Number.isNaN(aNum) && !Number.isNaN(bNum)) return aNum - bNum;
		return String(a.UserID).localeCompare(String(b.UserID));
	}

	async function loadErpUsers() {
		loadingUsers = true;
		usersError = '';
		erpUsers = [];
		try {
			if (selectedBranchId === 'all') {
				const results = await Promise.allSettled(erpConnections.map((c) => queryBranchUsers(c)));
				const failedBranches: string[] = [];
				const allRows: ErpUserRow[] = [];
				results.forEach((r, i) => {
					if (r.status === 'fulfilled') allRows.push(...r.value);
					else failedBranches.push(erpConnections[i].branch_name);
				});
				erpUsers = allRows.sort((a, b) => a.branch_name.localeCompare(b.branch_name) || compareUserId(a, b));
				if (failedBranches.length) usersError = `Failed to load: ${failedBranches.join(', ')}`;
			} else {
				const conn = erpConnections.find((c) => c.branch_id === selectedBranchId);
				if (!conn) { usersError = 'No ERP tunnel configured for this branch'; return; }
				erpUsers = (await queryBranchUsers(conn)).sort(compareUserId);
			}
		} catch (err: any) {
			usersError = err.message || 'Failed to load ERP users';
		} finally {
			loadingUsers = false;
			hasLoaded = true;
		}
	}

	async function init() {
		await loadErpConnections();
		await Promise.all([loadErpUsers(), loadCredentials(), loadAquraUsers()]);
	}
	init();

	function rowKey(row: ErpUserRow): string {
		return `${row.branch_id}-${row.UserID}`;
	}

	// ── Aqura users (for the link picker + resolving display names) ──
	interface AquraUser {
		id: string;
		username: string;
		employee_name: string;
	}

	let aquraUsers: AquraUser[] = [];
	let aquraUsersLoading = false;
	let aquraSearch = '';

	$: aquraUsersById = Object.fromEntries(aquraUsers.map((u) => [u.id, u]));
	$: filteredAquraUsers = aquraUsers.filter((u) => {
		if (!aquraSearch.trim()) return true;
		const q = aquraSearch.trim().toLowerCase();
		return u.username.toLowerCase().includes(q) || u.employee_name.toLowerCase().includes(q);
	});

	function aquraUserLabel(id: string): string {
		const u = aquraUsersById[id];
		if (!u) return 'Linked';
		return u.employee_name || u.username;
	}

	async function loadAquraUsers() {
		aquraUsersLoading = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('users')
				.select('id, username, employee_id')
				.order('username', { ascending: true });
			if (error) throw error;

			const employeeIds = [...new Set((data || []).filter((u: any) => u.employee_id).map((u: any) => u.employee_id))];
			const empMap: Record<string, string> = {};
			if (employeeIds.length > 0) {
				const { data: empData } = await supabase.from('hr_employees').select('id, name').in('id', employeeIds);
				empData?.forEach((e: any) => { empMap[e.id] = e.name; });
			}

			aquraUsers = (data || []).map((u: any) => ({
				id: u.id,
				username: u.username,
				employee_name: empMap[u.employee_id] || ''
			}));
		} catch (err: any) {
			console.error('Error loading Aqura users:', err);
		} finally {
			aquraUsersLoading = false;
		}
	}

	// ── ERP credential links (real persistence — user_erp_credentials) ──
	interface CredentialRow {
		user_id: string;
		aqura_branch_id: number;
		erp_branch_id: number;
		erp_user_id: string;
		erp_username: string | null;
		erp_login_password: string | null;
		erp_password: string | null;
	}

	let credentialsByRowKey: Record<string, CredentialRow> = {};

	async function loadCredentials() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const branchIds = erpConnections.map((c) => c.branch_id);
			if (branchIds.length === 0) { credentialsByRowKey = {}; return; }
			const { data, error } = await supabase
				.from('user_erp_credentials')
				.select('user_id, aqura_branch_id, erp_branch_id, erp_user_id, erp_username, erp_login_password, erp_password')
				.in('aqura_branch_id', branchIds);
			if (error) throw error;
			const map: Record<string, CredentialRow> = {};
			(data || []).forEach((row: CredentialRow) => {
				if (row.erp_user_id) map[`${row.aqura_branch_id}-${row.erp_user_id}`] = row;
			});
			credentialsByRowKey = map;
		} catch (err: any) {
			console.error('Error loading ERP credential links:', err);
		}
	}

	function branchNameFor(aquraBranchId: number): string {
		return erpConnections.find((c) => c.branch_id === aquraBranchId)?.branch_name || `Branch ${aquraBranchId}`;
	}

	// Rebuilds the minimal ErpUserRow shape the Link/password flows expect,
	// from a saved credential row — so the two "who's linked" review tabs can
	// reuse the same openUserPicker/openPasswordFlow actions as the live tabs.
	function credentialToRow(c: CredentialRow): ErpUserRow {
		return {
			branch_id: c.aqura_branch_id,
			branch_name: branchNameFor(c.aqura_branch_id),
			erp_branch_id: c.erp_branch_id,
			UserID: c.erp_user_id,
			UserName: c.erp_username || ''
		};
	}

	$: loginLinkedRows = Object.values(credentialsByRowKey)
		.filter((c) => c.erp_username)
		.sort((a, b) => branchNameFor(a.aqura_branch_id).localeCompare(branchNameFor(b.aqura_branch_id)) || (a.erp_username || '').localeCompare(b.erp_username || ''));

	$: authorizedRows = Object.values(credentialsByRowKey)
		.filter((c) => c.erp_password)
		.sort((a, b) => branchNameFor(a.aqura_branch_id).localeCompare(branchNameFor(b.aqura_branch_id)) || (a.erp_username || '').localeCompare(b.erp_username || ''));

	async function upsertCredential(row: ErpUserRow, extra: { user_id: string; erp_login_password?: string; erp_password?: string }) {
		const { supabase } = await import('$lib/utils/supabase');
		const payload: any = {
			user_id: extra.user_id,
			aqura_branch_id: row.branch_id,
			erp_branch_id: row.erp_branch_id,
			erp_user_id: String(row.UserID),
			erp_username: row.UserName
		};
		if (extra.erp_login_password) payload.erp_login_password = extra.erp_login_password;
		if (extra.erp_password) payload.erp_password = extra.erp_password;
		const { error } = await supabase
			.from('user_erp_credentials')
			.upsert(payload, { onConflict: 'user_id,aqura_branch_id' });
		if (error) throw error;
		await loadCredentials();
	}

	// ── Aqura-user picker modal — shared by Login and Authorization, both of
	// which now always end in the password modal (Login asks for a login
	// password too, not just the username link). ──
	let showPickerModal = false;
	let pickerRow: ErpUserRow | null = null;
	let pickerPurpose: 'login' | 'authorization' = 'login';
	let pickerError = '';

	function openUserPicker(row: ErpUserRow, purpose: 'login' | 'authorization') {
		pickerRow = row;
		pickerPurpose = purpose;
		pickerError = '';
		aquraSearch = '';
		showPickerModal = true;
	}

	function closePickerModal() {
		showPickerModal = false;
		pickerRow = null;
		pickerError = '';
	}

	function selectAquraUser(u: AquraUser) {
		if (!pickerRow) return;
		const row = pickerRow;
		const purpose = pickerPurpose;
		closePickerModal();
		openPasswordModalFor(row, u.id, purpose);
	}

	// ── Password modal — shared by Login (erp_login_password) and
	// Authorization (erp_password). ──
	let showPasswordModal = false;
	let passwordRow: ErpUserRow | null = null;
	let passwordTargetUserId: string | null = null;
	let passwordPurpose: 'login' | 'authorization' = 'login';
	let passwordInput = '';
	let passwordSaving = false;
	let passwordError = '';

	function openPasswordModalFor(row: ErpUserRow, userId: string, purpose: 'login' | 'authorization') {
		passwordRow = row;
		passwordTargetUserId = userId;
		passwordPurpose = purpose;
		passwordInput = '';
		passwordError = '';
		showPasswordModal = true;
	}

	function openPasswordFlow(row: ErpUserRow, purpose: 'login' | 'authorization') {
		const existing = credentialsByRowKey[rowKey(row)];
		if (existing?.user_id) {
			openPasswordModalFor(row, existing.user_id, purpose);
		} else {
			openUserPicker(row, purpose);
		}
	}

	function closePasswordModal() {
		showPasswordModal = false;
		passwordRow = null;
		passwordTargetUserId = null;
		passwordInput = '';
		passwordError = '';
	}

	async function saveCredentialPassword() {
		if (!passwordRow || !passwordTargetUserId || !passwordInput) return;
		passwordSaving = true;
		try {
			const extra = passwordPurpose === 'login'
				? { user_id: passwordTargetUserId, erp_login_password: passwordInput }
				: { user_id: passwordTargetUserId, erp_password: passwordInput };
			await upsertCredential(passwordRow, extra);
			closePasswordModal();
		} catch (err: any) {
			passwordError = err.message || 'Failed to save password';
		} finally {
			passwordSaving = false;
		}
	}
</script>

<div class="erp-credentials">
	<!-- ── Tab Bar ─────────────────────────────────────────────────────── -->
	<div class="tab-bar">
		{#each tabs as tab}
			<button
				class="tab-btn"
				class:active={activeTab === tab.id}
				on:click={() => activeTab = tab.id}
			>
				<span class="tab-icon">{tab.icon}</span>
				<span class="tab-label">{tab.label}</span>
			</button>
		{/each}
	</div>

	<!-- ── Tab Content ─────────────────────────────────────────────────── -->
	<div class="tab-content">
		{#if activeTab === 'login'}
			<div class="login-panel">
				<div class="users-toolbar">
					<label for="erp-branch-filter">Branch</label>
					<select id="erp-branch-filter" bind:value={selectedBranchId} on:change={loadErpUsers} disabled={loadingUsers}>
						<option value="all">All Branches</option>
						{#each erpConnections as conn}
							<option value={conn.branch_id}>{conn.branch_name}</option>
						{/each}
					</select>
					<button class="refresh-btn" on:click={loadErpUsers} disabled={loadingUsers}>
						{loadingUsers ? '⏳' : '🔄'} Refresh
					</button>
					<input
						class="user-search"
						type="text"
						placeholder="Search by username…"
						bind:value={userSearch}
					/>
					{#if hasLoaded && !loadingUsers}
						<span class="users-count">{filteredErpUsers.length} user{filteredErpUsers.length === 1 ? '' : 's'}</span>
					{/if}
				</div>

				{#if usersError}
					<div class="users-error">⚠️ {usersError}</div>
				{/if}

				<div class="users-table-wrap">
					{#if loadingUsers}
						<div class="users-loading">Loading ERP users…</div>
					{:else if erpUsers.length === 0}
						<div class="users-empty">No users found.</div>
					{:else if filteredErpUsers.length === 0}
						<div class="users-empty">No matching users.</div>
					{:else}
						<table class="users-table">
							<thead>
								<tr>
									{#if selectedBranchId === 'all'}
										<th>Branch</th>
									{/if}
									<th>ERP User ID</th>
									<th>User Name</th>
									<th>Aqura User</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredErpUsers as u}
									<tr>
										{#if selectedBranchId === 'all'}
											<td>{u.branch_name}</td>
										{/if}
										<td>{u.UserID}</td>
										<td>{u.UserName}</td>
										<td>
											{#if credentialsByRowKey[rowKey(u)]?.erp_username}
												<span class="linked-user">
													👤 {aquraUserLabel(credentialsByRowKey[rowKey(u)].user_id)}
												</span>
												{#if credentialsByRowKey[rowKey(u)]?.erp_login_password}
													<button class="link-btn linked" on:click={() => openUserPicker(u, 'login')}>Change</button>
												{:else}
													<button class="link-btn" on:click={() => openUserPicker(u, 'login')}>Set Password</button>
												{/if}
											{:else}
												<button class="link-btn" on:click={() => openUserPicker(u, 'login')}>🔗 Link</button>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				</div>
			</div>
		{:else if activeTab === 'authorization'}
			<div class="login-panel">
				<div class="users-toolbar">
					<label for="erp-branch-filter-auth">Branch</label>
					<select id="erp-branch-filter-auth" bind:value={selectedBranchId} on:change={loadErpUsers} disabled={loadingUsers}>
						<option value="all">All Branches</option>
						{#each erpConnections as conn}
							<option value={conn.branch_id}>{conn.branch_name}</option>
						{/each}
					</select>
					<button class="refresh-btn" on:click={loadErpUsers} disabled={loadingUsers}>
						{loadingUsers ? '⏳' : '🔄'} Refresh
					</button>
					<input
						class="user-search"
						type="text"
						placeholder="Search by username…"
						bind:value={userSearch}
					/>
					{#if hasLoaded && !loadingUsers}
						<span class="users-count">{filteredErpUsers.length} user{filteredErpUsers.length === 1 ? '' : 's'}</span>
					{/if}
				</div>

				{#if usersError}
					<div class="users-error">⚠️ {usersError}</div>
				{/if}

				<div class="users-table-wrap">
					{#if loadingUsers}
						<div class="users-loading">Loading ERP users…</div>
					{:else if erpUsers.length === 0}
						<div class="users-empty">No users found.</div>
					{:else if filteredErpUsers.length === 0}
						<div class="users-empty">No matching users.</div>
					{:else}
						<table class="users-table">
							<thead>
								<tr>
									{#if selectedBranchId === 'all'}
										<th>Branch</th>
									{/if}
									<th>ERP User ID</th>
									<th>User Name</th>
									<th>Authorization Password</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredErpUsers as u}
									<tr>
										{#if selectedBranchId === 'all'}
											<td>{u.branch_name}</td>
										{/if}
										<td>{u.UserID}</td>
										<td>{u.UserName}</td>
										<td>
											{#if credentialsByRowKey[rowKey(u)]?.erp_password}
												<span class="linked-user">🔒 ••••••••</span>
												<button class="link-btn linked" on:click={() => openPasswordFlow(u, 'authorization')}>Change</button>
											{:else}
												<button class="link-btn" on:click={() => openPasswordFlow(u, 'authorization')}>Add Authorization Password</button>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				</div>
			</div>
		{:else if activeTab === 'linked-login'}
			<div class="login-panel">
				<div class="users-toolbar">
					<span class="users-count">{loginLinkedRows.length} linked user{loginLinkedRows.length === 1 ? '' : 's'}</span>
				</div>
				<div class="users-table-wrap">
					{#if loginLinkedRows.length === 0}
						<div class="users-empty">No users have an ERP login linked yet.</div>
					{:else}
						<table class="users-table">
							<thead>
								<tr>
									<th>Branch</th>
									<th>ERP User ID</th>
									<th>ERP Username</th>
									<th>Aqura User</th>
									<th>Login Password</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each loginLinkedRows as c}
									<tr>
										<td>{branchNameFor(c.aqura_branch_id)}</td>
										<td>{c.erp_user_id}</td>
										<td>{c.erp_username}</td>
										<td>{aquraUserLabel(c.user_id)}</td>
										<td>{c.erp_login_password ? '🔒 Set' : '—'}</td>
										<td><button class="link-btn" on:click={() => openUserPicker(credentialToRow(c), 'login')}>Change</button></td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				</div>
			</div>
		{:else if activeTab === 'linked-auth'}
			<div class="login-panel">
				<div class="users-toolbar">
					<span class="users-count">{authorizedRows.length} authorized user{authorizedRows.length === 1 ? '' : 's'}</span>
				</div>
				<div class="users-table-wrap">
					{#if authorizedRows.length === 0}
						<div class="users-empty">No users have an authorization password saved yet.</div>
					{:else}
						<table class="users-table">
							<thead>
								<tr>
									<th>Branch</th>
									<th>ERP User ID</th>
									<th>ERP Username</th>
									<th>Aqura User</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each authorizedRows as c}
									<tr>
										<td>{branchNameFor(c.aqura_branch_id)}</td>
										<td>{c.erp_user_id}</td>
										<td>{c.erp_username}</td>
										<td>{aquraUserLabel(c.user_id)}</td>
										<td><button class="link-btn" on:click={() => openPasswordFlow(credentialToRow(c), 'authorization')}>Change</button></td>
									</tr>
								{/each}
							</tbody>
						</table>
					{/if}
				</div>
			</div>
		{/if}
	</div>

	<!-- ── Aqura user picker modal — Login link, or Authorization's first
	     step when the row isn't linked to anyone yet. ──────────────────── -->
	{#if showPickerModal}
		<div class="modal-overlay" on:click={closePickerModal}>
			<div class="modal-panel" on:click|stopPropagation>
				<div class="modal-header">
					<h3>{pickerPurpose === 'login' ? 'Link to Aqura User' : 'Select Aqura User'}</h3>
					<button class="modal-close" on:click={closePickerModal}>✕</button>
				</div>
				{#if pickerRow}
					<p class="modal-subtitle">
						ERP user <strong>{pickerRow.UserName}</strong> (ID {pickerRow.UserID}) — {pickerRow.branch_name}
					</p>
				{/if}
				{#if pickerError}
					<div class="users-error" style="margin: 10px 20px 0;">⚠️ {pickerError}</div>
				{/if}

				<input
					class="modal-search"
					type="text"
					placeholder="Search by username or employee name…"
					bind:value={aquraSearch}
				/>

				<div class="modal-table-wrap">
					{#if aquraUsersLoading}
						<div class="users-loading">Loading Aqura users…</div>
					{:else if filteredAquraUsers.length === 0}
						<div class="users-empty">No matching users.</div>
					{:else}
						<table class="users-table">
							<thead>
								<tr>
									<th>Username</th>
									<th>Employee Name</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each filteredAquraUsers as u}
									<tr>
										<td>{u.username}</td>
										<td>{u.employee_name || '—'}</td>
										<td>
											<button class="link-btn" on:click={() => selectAquraUser(u)}>Select</button>
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

	<!-- ── Password modal — Login password or Authorization password ─────── -->
	{#if showPasswordModal}
		<div class="modal-overlay" on:click={closePasswordModal}>
			<div class="modal-panel" on:click|stopPropagation>
				<div class="modal-header">
					<h3>{passwordPurpose === 'login' ? 'Login Password' : 'Authorization Password'}</h3>
					<button class="modal-close" on:click={closePasswordModal}>✕</button>
				</div>
				{#if passwordRow}
					<p class="modal-subtitle">
						ERP user <strong>{passwordRow.UserName}</strong> (ID {passwordRow.UserID}) — {passwordRow.branch_name}
						{#if passwordTargetUserId}
							<br />Linked to: <strong>{aquraUserLabel(passwordTargetUserId)}</strong>
						{/if}
					</p>
				{/if}
				{#if passwordError}
					<div class="users-error" style="margin: 10px 20px 0;">⚠️ {passwordError}</div>
				{/if}

				<input
					class="modal-search"
					type="password"
					placeholder={passwordPurpose === 'login' ? 'Enter login password…' : 'Enter authorization password…'}
					bind:value={passwordInput}
				/>

				<div class="modal-actions">
					<button class="cancel-btn" on:click={closePasswordModal}>Cancel</button>
					<button class="save-btn" on:click={saveCredentialPassword} disabled={!passwordInput || passwordSaving}>
						{passwordSaving ? 'Saving…' : 'Save'}
					</button>
				</div>
			</div>
		</div>
	{/if}
</div>


<style>
	.erp-credentials {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: linear-gradient(135deg, rgba(255,255,255,0.72) 0%, rgba(241,245,249,0.80) 100%);
		backdrop-filter: blur(18px);
		-webkit-backdrop-filter: blur(18px);
		font-family: inherit;
		color: #1e293b;
		overflow: hidden;
	}

	.tab-bar {
		display: flex;
		gap: 6px;
		padding: 14px 18px 0;
		border-bottom: 1.5px solid rgba(148, 163, 184, 0.3);
		background: rgba(255,255,255,0.55);
		flex-shrink: 0;
	}

	.tab-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 9px 16px;
		border: 1.5px solid transparent;
		border-bottom: none;
		border-radius: 10px 10px 0 0;
		background: transparent;
		cursor: pointer;
		font-size: 0.82rem;
		font-weight: 500;
		color: #64748b;
		transition: all 0.18s ease;
		white-space: nowrap;
		position: relative;
		bottom: -1.5px;
	}

	.tab-btn:hover {
		background: rgba(226,232,240,0.6);
		color: #334155;
	}

	.tab-btn.active {
		background: rgba(255,255,255,0.95);
		border-color: rgba(148,163,184,0.35);
		color: #0f172a;
		font-weight: 600;
		box-shadow: 0 -2px 8px rgba(0,0,0,0.05);
	}

	.tab-content {
		flex: 1;
		overflow-y: auto;
		display: flex;
	}

	.login-panel {
		display: flex;
		flex-direction: column;
		width: 100%;
		padding: 18px 22px;
		gap: 14px;
	}

	.users-toolbar {
		display: flex;
		align-items: center;
		gap: 10px;
		flex-wrap: wrap;
	}

	.users-toolbar label {
		font-size: 0.8rem;
		font-weight: 600;
		color: #475569;
	}

	.users-toolbar select {
		padding: 7px 12px;
		border: 1.5px solid rgba(148,163,184,0.4);
		border-radius: 8px;
		background: rgba(255,255,255,0.9);
		font-size: 0.85rem;
		color: #1e293b;
	}

	.refresh-btn {
		padding: 7px 14px;
		border: none;
		border-radius: 8px;
		background: #6366f1;
		color: white;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.15s ease;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #4f46e5;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.user-search {
		padding: 7px 12px;
		border: 1.5px solid rgba(148,163,184,0.4);
		border-radius: 8px;
		background: rgba(255,255,255,0.9);
		font-size: 0.85rem;
		color: #1e293b;
		min-width: 200px;
	}

	.users-count {
		font-size: 0.78rem;
		color: #64748b;
		font-weight: 600;
		margin-left: auto;
	}

	.users-error {
		padding: 10px 14px;
		border-radius: 8px;
		background: rgba(239,68,68,0.08);
		border: 1.5px solid rgba(239,68,68,0.25);
		color: #b91c1c;
		font-size: 0.82rem;
	}

	.users-table-wrap {
		flex: 1;
		overflow-y: auto;
		border: 1.5px solid rgba(148,163,184,0.3);
		border-radius: 10px;
		background: rgba(255,255,255,0.7);
	}

	.users-loading,
	.users-empty {
		padding: 30px;
		text-align: center;
		color: #94a3b8;
		font-size: 0.85rem;
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.83rem;
	}

	.users-table thead th {
		position: sticky;
		top: 0;
		background: rgba(241,245,249,0.95);
		text-align: left;
		padding: 9px 14px;
		font-size: 0.72rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: #64748b;
		border-bottom: 1.5px solid rgba(148,163,184,0.3);
	}

	.users-table tbody td {
		padding: 8px 14px;
		border-bottom: 1px solid rgba(226,232,240,0.6);
		color: #1e293b;
	}

	.users-table tbody tr:hover {
		background: rgba(99,102,241,0.05);
	}

	.link-btn {
		padding: 5px 12px;
		border: 1.5px solid rgba(99,102,241,0.35);
		border-radius: 7px;
		background: rgba(99,102,241,0.08);
		color: #4f46e5;
		font-size: 0.78rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s ease;
		white-space: nowrap;
	}

	.link-btn:hover {
		background: rgba(99,102,241,0.16);
	}

	.link-btn.linked {
		margin-left: 8px;
		border-color: rgba(148,163,184,0.4);
		background: transparent;
		color: #64748b;
	}

	.linked-user {
		font-size: 0.82rem;
		color: #1e293b;
		font-weight: 600;
	}

	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(15,23,42,0.45);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-panel {
		width: min(560px, 92vw);
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		border-radius: 14px;
		box-shadow: 0 20px 60px rgba(0,0,0,0.25);
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 20px;
		border-bottom: 1.5px solid rgba(148,163,184,0.25);
	}

	.modal-header h3 {
		margin: 0;
		font-size: 1rem;
		font-weight: 700;
		color: #0f172a;
	}

	.modal-close {
		border: none;
		background: transparent;
		font-size: 0.95rem;
		color: #64748b;
		cursor: pointer;
		padding: 4px 8px;
		border-radius: 6px;
	}

	.modal-close:hover {
		background: rgba(148,163,184,0.15);
	}

	.modal-subtitle {
		margin: 0;
		padding: 12px 20px 0;
		font-size: 0.82rem;
		color: #64748b;
	}

	.modal-search {
		margin: 14px 20px 0;
		padding: 8px 12px;
		border: 1.5px solid rgba(148,163,184,0.4);
		border-radius: 8px;
		font-size: 0.85rem;
		color: #1e293b;
	}

	.modal-table-wrap {
		flex: 1;
		overflow-y: auto;
		margin: 12px 20px 20px;
		border: 1.5px solid rgba(148,163,184,0.3);
		border-radius: 10px;
	}

	.modal-actions {
		display: flex;
		justify-content: flex-end;
		gap: 10px;
		padding: 16px 20px 20px;
	}

	.cancel-btn {
		padding: 8px 16px;
		border: 1.5px solid rgba(148,163,184,0.4);
		border-radius: 8px;
		background: transparent;
		color: #64748b;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
	}

	.cancel-btn:hover {
		background: rgba(148,163,184,0.1);
	}

	.save-btn {
		padding: 8px 18px;
		border: none;
		border-radius: 8px;
		background: #6366f1;
		color: white;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.15s ease;
	}

	.save-btn:hover:not(:disabled) {
		background: #4f46e5;
	}

	.save-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

</style>
