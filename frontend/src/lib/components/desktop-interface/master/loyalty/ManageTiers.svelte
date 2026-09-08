<script lang="ts">
	import { _ as t } from '$lib/i18n';
	import { onMount } from 'svelte';

	// ── Active Tab ──────────────────────────────────────────────────────────────
	type Tab = 'tier-settings' | 'rewards-setup' | 'customer-rules' | 'automation' | 'analytics' | 'customer-bills';
	let activeTab: Tab = 'tier-settings';

	const tabs: { id: Tab; label: string; icon: string }[] = [
		{ id: 'tier-settings',   label: 'Tier Settings',   icon: '🏅' },
		{ id: 'rewards-setup',   label: 'Rewards Setup',   icon: '🎁' },
		{ id: 'customer-rules',  label: 'Customer Rules',  icon: '📋' },
		{ id: 'automation',      label: 'Automation',      icon: '⚡' },
		{ id: 'analytics',       label: 'Analytics',       icon: '📊' },
		{ id: 'customer-bills',  label: 'Customer Bills',  icon: '🧾' },
	];

	// ── Tier Data ────────────────────────────────────────────────────────────────
	interface Tier {
		id: string;
		name: string;
		name_ar: string;
		color: string;
		sort_order: number;
		total_purchase_from: number;
		total_purchase_to: number | null;
		points_percentage: number;
		min_redeem_points: number;
		is_active: boolean;
	}

	let tiers: Tier[] = [];
	let tiersLoading = false;
	let tiersError = '';

	// ── Edit Modal ───────────────────────────────────────────────────────────────
	let showEditModal = false;
	let editingTier: Tier | null = null;
	let editForm = {
		name: '', name_ar: '', color: '#cd7f32',
		total_purchase_from: 0, total_purchase_to: null as number | null,
		points_percentage: 0, min_redeem_points: 0, is_active: true,
	};
	let editSaving = false;
	let editError = '';

	// ── Helpers ──────────────────────────────────────────────────────────────────
	function formatCurrency(v: number): string {
		return v.toLocaleString('en-US');
	}

	async function loadTiers() {
		if (!supabase) return;
		tiersLoading = true;
		tiersError = '';
		try {
			const { data, error } = await supabase
				.from('loyalty_tiers')
				.select('*')
				.order('sort_order');
			if (error) throw error;
			tiers = data || [];
		} catch (e: any) {
			tiersError = e.message || 'Failed to load tiers';
		} finally {
			tiersLoading = false;
		}
	}

	function handleEdit(tier: Tier) {
		editingTier = { ...tier };
		editForm = {
			name: tier.name,
			name_ar: tier.name_ar || '',
			color: tier.color || '#cd7f32',
			total_purchase_from: Number(tier.total_purchase_from),
			total_purchase_to: tier.total_purchase_to != null ? Number(tier.total_purchase_to) : null,
			points_percentage: Number(tier.points_percentage),
			min_redeem_points: Number(tier.min_redeem_points),
			is_active: tier.is_active,
		};
		editError = '';
		showEditModal = true;
	}

	async function saveEdit() {
		if (!editingTier || !supabase) return;
		editSaving = true;
		editError = '';
		try {
			const { error } = await supabase.rpc('update_loyalty_tier', {
				p_id:                  editingTier.id,
				p_name:                editForm.name.trim(),
				p_name_ar:             editForm.name_ar.trim(),
				p_color:               editForm.color,
				p_total_purchase_from: editForm.total_purchase_from,
				p_total_purchase_to:   editForm.total_purchase_to,
				p_points_percentage:   editForm.points_percentage,
				p_min_redeem_points:   editForm.min_redeem_points,
				p_is_active:           editForm.is_active,
			});
			if (error) throw error;
			showEditModal = false;
			editingTier = null;
			await loadTiers();
		} catch (e: any) {
			editError = e.message || 'Save failed';
		} finally {
			editSaving = false;
		}
	}

	function handleDelete(tier: Tier) {
		if (confirm(`Delete tier "${tier.name}"?`)) {
			supabase.rpc('delete_loyalty_tier', { p_id: tier.id }).then(() => loadTiers());
		}
	}

	function handleAddTier() {
		alert('Add Tier form coming soon.');
	}

	// ── Customer Bills ───────────────────────────────────────────────────────────
	interface Bill {
		id: string;
		whatsapp_number: string;
		customer_id: string | null;
		employee_id: string | null;
		erp_branch_id: string | null;
		bill_date: string;
		bill_time: string;
		bill_number: string | null;
		bill_gross_total: number;
		bill_net_total: number;
		points_earned: number;
		created_at: string;
		total_count: number;
	}

	const PAGE_SIZE = 50;
	let bills: Bill[] = [];
	let billsLoading = false;
	let billsLoadingMore = false;
	let billsError = '';
	let billsSearch = '';
	let billsOffset = 0;
	let billsHasMore = true;
	let billsTotalCount = 0;
	let billsInitialized = false;
	let tableWrapEl: HTMLElement;
	let searchTimer: ReturnType<typeof setTimeout>;
	let supabase: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadTiers();
	});

	$: if (activeTab === 'customer-bills' && supabase && !billsInitialized && !billsLoading) {
		billsInitialized = true;
		loadBills(true);
	}

	function onSearchInput() {
		clearTimeout(searchTimer);
		searchTimer = setTimeout(() => {
			bills = [];
			billsOffset = 0;
			billsHasMore = true;
			billsTotalCount = 0;
			loadBills(true);
		}, 350);
	}

	async function loadBills(reset: boolean) {
		if (!supabase) return;
		if (reset) {
			billsLoading = true;
			billsError = '';
		} else {
			if (!billsHasMore || billsLoadingMore) return;
			billsLoadingMore = true;
		}
		try {
			const { data, error } = await supabase.rpc('get_loyalty_customer_bills', {
				p_search: billsSearch.trim(),
				p_limit:  PAGE_SIZE,
				p_offset: reset ? 0 : billsOffset,
			});
			if (error) throw error;
			const rows: Bill[] = data ?? [];
			if (rows.length > 0) billsTotalCount = Number(rows[0].total_count);
			if (reset) {
				bills = rows;
				billsOffset = rows.length;
			} else {
				bills = [...bills, ...rows];
				billsOffset += rows.length;
			}
			billsHasMore = billsOffset < billsTotalCount;
		} catch (e: any) {
			billsError = e.message ?? 'Failed to load bills';
		} finally {
			billsLoading = false;
			billsLoadingMore = false;
		}
	}

	function onTableScroll() {
		if (!tableWrapEl) return;
		const { scrollTop, scrollHeight, clientHeight } = tableWrapEl;
		if (scrollHeight - scrollTop - clientHeight < 250 && billsHasMore && !billsLoadingMore && !billsLoading) {
			loadBills(false);
		}
	}

	function resetAndLoad() {
		bills = [];
		billsOffset = 0;
		billsHasMore = true;
		billsTotalCount = 0;
		billsInitialized = true;
		loadBills(true);
	}

	// ── Sync Tiers ───────────────────────────────────────────────────────────
	let syncing = false;
	let syncMessage = '';
	let syncIsError = false;

	async function syncTiers() {
		if (!supabase || syncing) return;
		syncing = true;
		syncMessage = '';
		syncIsError = false;
		try {
			const { data, error } = await supabase.rpc('sync_loyalty_tiers');
			if (error) throw error;
			const updated = data?.updated ?? 0;
			syncMessage = `✓ Synced successfully — ${updated} customer${updated !== 1 ? 's' : ''} updated`;
		} catch (e: any) {
			syncIsError = true;
			syncMessage = `⚠️ ${e.message ?? 'Sync failed'}`;
		} finally {
			syncing = false;
			setTimeout(() => { syncMessage = ''; }, 6000);
		}
	}

	function formatDate(dt: string) {
		return new Date(dt).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
	}
</script>

<div class="manage-tiers">
	<!-- ── Tab Bar ─────────────────────────────────────────────────────────────── -->
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

	<!-- ── Tab Content ────────────────────────────────────────────────────────── -->
	<div class="tab-content">

		{#if activeTab === 'tier-settings'}
			<!-- Tier Settings ──────────────────────────────────────────────────── -->
			<div class="section-header">
				<div class="section-title">
					<span class="section-icon">🏅</span>
					<h3>Tier Settings</h3>
					<span class="badge">{tiers.length} tiers</span>
				</div>
				<button class="add-btn" on:click={handleAddTier}>
					<span>＋</span> Add Tier
				</button>
			</div>

			{#if tiersLoading}
				<div class="tiers-state"><div class="spinner"></div><p>Loading tiers…</p></div>
			{:else if tiersError}
				<div class="tiers-state error">⚠️ {tiersError}</div>
			{:else}
			<div class="table-wrap">
				<table class="tier-table">
					<thead>
						<tr>
							<th>Tier</th>
							<th>Lifetime Purchase From</th>
							<th>Lifetime Purchase To</th>
							<th>Points % per Bill</th>
							<th>Point Value</th>
							<th>Min. Points to Redeem</th>
							<th>Active</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each tiers as tier (tier.id)}
							<tr>
								<td>
									<div class="tier-name-cell">
										<span class="tier-dot" style="background:{tier.color}"></span>
										<span class="tier-name">{tier.name}</span>
										{#if tier.name_ar}<span class="tier-name-ar">({tier.name_ar})</span>{/if}
									</div>
								</td>
								<td class="num-cell">
									<span class="currency">SAR</span> {formatCurrency(Number(tier.total_purchase_from))}
								</td>
								<td class="num-cell">
									{#if tier.total_purchase_to != null}
										<span class="currency">SAR</span> {formatCurrency(Number(tier.total_purchase_to))}
									{:else}
										<span class="unlimited">Unlimited ∞</span>
									{/if}
								</td>
								<td class="num-cell">
									<span class="pct-badge">{Number(tier.points_percentage)}%</span>
								</td>
								<td class="num-cell">
									<span class="ecash-badge">1 pt = 1 SAR</span>
								</td>
								<td class="num-cell">
									<span class="redeem-badge">{tier.min_redeem_points} pts</span>
								</td>
								<td class="num-cell">
									<span class="active-dot" class:active={tier.is_active}></span>
								</td>
								<td class="actions-cell">
									<button class="action-btn edit" on:click={() => handleEdit(tier)} title="Edit">✏️</button>
									<button class="action-btn delete" on:click={() => handleDelete(tier)} title="Delete">🗑️</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			{/if}

		{:else if activeTab === 'rewards-setup'}
			<div class="placeholder-panel">
				<div class="placeholder-icon">🎁</div>
				<h3>Rewards Setup</h3>
				<p>Configure reward types, point values, and redemption rules.</p>
				<span class="coming-soon-tag">Coming Soon</span>
			</div>

		{:else if activeTab === 'customer-rules'}
			<div class="placeholder-panel">
				<div class="placeholder-icon">📋</div>
				<h3>Customer Rules</h3>
				<p>Define eligibility conditions and tier upgrade/downgrade rules.</p>
				<span class="coming-soon-tag">Coming Soon</span>
			</div>

		{:else if activeTab === 'automation'}
			<div class="placeholder-panel">
				<div class="placeholder-icon">⚡</div>
				<h3>Automation</h3>
				<p>Automate point expiry, tier transitions, and customer notifications.</p>
				<span class="coming-soon-tag">Coming Soon</span>
			</div>

		{:else if activeTab === 'analytics'}
			<div class="placeholder-panel">
				<div class="placeholder-icon">📊</div>
				<h3>Analytics</h3>
				<p>Track tier distribution, point issuance trends, and redemption rates.</p>
				<span class="coming-soon-tag">Coming Soon</span>
			</div>

		{:else if activeTab === 'customer-bills'}
			<!-- Customer Bills ───────────────────────────────────────────────────── -->
			<div class="bills-panel">
				<div class="section-header">
					<div class="section-title">
						<span class="section-icon">🧾</span>
						<h3>Customer Bills</h3>
						{#if billsTotalCount > 0}<span class="badge">{bills.length} / {billsTotalCount}</span>{/if}
					</div>
					<div class="bills-toolbar">
						<div class="search-wrap">
							<span class="search-icon">🔍</span>
							<input
								class="search-input"
								type="text"
								bind:value={billsSearch}
								on:input={onSearchInput}
								placeholder="Search by WhatsApp, customer ID, bill number, date…"
							/>
							{#if billsSearch}
								<button class="clear-btn" on:click={() => { billsSearch = ''; resetAndLoad(); }}>✕</button>
							{/if}
						</div>
						<button class="refresh-btn" on:click={resetAndLoad} title="Refresh">
							🔄 Refresh
						</button>
						<button class="sync-btn" on:click={syncTiers} disabled={syncing} title="Assign/update points % for all customers based on their lifetime purchases">
							{#if syncing}
								<span class="spinner-sm" style="border-top-color:#fff"></span> Syncing…
							{:else}
								🔄 Sync Tiers
							{/if}
						</button>
					</div>
				</div>

				{#if syncMessage}
					<div class="sync-message" class:error={syncIsError}>{syncMessage}</div>
				{/if}

				{#if billsLoading}
					<div class="bills-state">
						<div class="spinner"></div>
						<p>Loading bills…</p>
					</div>
				{:else if billsError}
					<div class="bills-state error">
						<span>⚠️ {billsError}</span>
						<button class="refresh-btn" on:click={resetAndLoad}>Retry</button>
					</div>
				{:else if bills.length === 0}
					<div class="bills-state">
						<span style="font-size:2rem">🧾</span>
						<p>{billsSearch ? 'No records match your search.' : 'No bills uploaded yet.'}</p>
					</div>
				{:else}
					<div class="table-wrap bills-table-wrap" bind:this={tableWrapEl} on:scroll={onTableScroll}>
						<table class="tier-table bills-table">
							<thead>
								<tr>
									<th>#</th>
										<th>Bill Date</th>
										<th>Bill Time</th>
										<th>Bill No.</th>
										<th>WhatsApp</th>
										<th>Employee ID</th>
										<th>ERP Branch ID</th>
										<th>Gross Total</th>
										<th>Net Total</th>
										<th>Points Earned</th>
								</tr>
							</thead>
							<tbody>
								{#each bills as bill, i (bill.id)}
									<tr>
										<td class="num-cell row-num">{i + 1}</td>
										<td class="num-cell">{formatDate(bill.bill_date)}</td>
										<td class="num-cell">{bill.bill_time ? bill.bill_time.slice(0, 5) : '—'}</td>
										<td class="mono">{bill.bill_number ?? '—'}</td>
										<td><span class="mono">{bill.whatsapp_number}</span></td>
										<td>{bill.employee_id ?? '—'}</td>
										<td>{bill.erp_branch_id ?? '—'}</td>
										<td class="num-cell"><span class="currency">SAR</span> {Number(bill.bill_gross_total).toLocaleString('en-US', { minimumFractionDigits: 2 })}</td>
										<td class="num-cell"><span class="currency">SAR</span> {Number(bill.bill_net_total).toLocaleString('en-US', { minimumFractionDigits: 2 })}</td>
										<td class="num-cell"><span class="redeem-badge">{Number(bill.points_earned).toFixed(2)}</span></td>
									</tr>
								{/each}
							</tbody>
						</table>
						{#if billsLoadingMore}
							<div class="load-more-row">
								<div class="spinner-sm"></div>
								<span>Loading more…</span>
							</div>
						{:else if !billsHasMore && bills.length > 0}
							<div class="load-more-row dim">All {billsTotalCount} records loaded</div>
						{/if}
					</div>
				{/if}
			</div>
		{/if}

	</div>
</div>

<!-- ── Edit Tier Modal ──────────────────────────────────────────────────────── -->
{#if showEditModal && editingTier}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="modal-backdrop" on:click={() => { showEditModal = false; }}></div>
	<div class="edit-modal">
		<div class="edit-modal-header">
			<span class="tier-dot lg" style="background:{editForm.color}"></span>
			<h3>Edit Tier — {editingTier.name}</h3>
			<button class="modal-close" on:click={() => { showEditModal = false; }}>✕</button>
		</div>

		<div class="edit-modal-body">
			<div class="edit-row">
				<div class="edit-field">
					<label>Name (EN)</label>
					<input type="text" bind:value={editForm.name} placeholder="e.g. Bronze" />
				</div>
				<div class="edit-field">
					<label>Name (AR)</label>
					<input type="text" bind:value={editForm.name_ar} dir="rtl" placeholder="e.g. برونزي" />
				</div>
				<div class="edit-field edit-field-sm">
					<label>Color</label>
					<input type="color" bind:value={editForm.color} class="color-input" />
				</div>
			</div>

			<div class="edit-row">
				<div class="edit-field">
					<label>Lifetime Purchase From (SAR)</label>
					<input type="number" min="0" step="1" bind:value={editForm.total_purchase_from} />
				</div>
				<div class="edit-field">
					<label>Lifetime Purchase To (SAR) — blank = unlimited</label>
					<input type="number" min="0" step="1"
						value={editForm.total_purchase_to ?? ''}
						on:input={(e) => { const v = (e.target as HTMLInputElement).value; editForm.total_purchase_to = v === '' ? null : Number(v); }}
						placeholder="Leave empty for Unlimited"
					/>
				</div>
			</div>

			<div class="edit-row">
				<div class="edit-field">
					<label>Points % per Bill</label>
					<input type="number" min="0" step="0.01" bind:value={editForm.points_percentage} />
				</div>
				<div class="edit-field">
					<label>Min. Points to Redeem</label>
					<input type="number" min="0" step="1" bind:value={editForm.min_redeem_points} />
				</div>
				<div class="edit-field edit-field-sm">
					<label>Active</label>
					<label class="toggle">
						<input type="checkbox" bind:checked={editForm.is_active} />
						<span class="toggle-track"></span>
					</label>
				</div>
			</div>

			{#if editError}
				<div class="edit-error">⚠️ {editError}</div>
			{/if}
		</div>

		<div class="edit-modal-footer">
			<button class="btn-cancel" on:click={() => { showEditModal = false; }}>Cancel</button>
			<button class="btn-save" on:click={saveEdit} disabled={editSaving}>
				{#if editSaving}<span class="spinner-sm"></span> Saving…{:else}💾 Save Changes{/if}
			</button>
		</div>
	</div>
{/if}

<style>
	/* ── Layout ─────────────────────────────────────────────────────────────────── */
	.manage-tiers {
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

	/* ── Tab Bar ────────────────────────────────────────────────────────────────── */
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

	.tab-icon {
		font-size: 1rem;
	}

	/* ── Tab Content ────────────────────────────────────────────────────────────── */
	.tab-content {
		flex: 1;
		overflow-y: auto;
		padding: 22px 22px 28px;
	}

	/* ── Section Header ─────────────────────────────────────────────────────────── */
	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 18px;
		flex-wrap: wrap;
		gap: 10px;
	}

	.section-title {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.section-icon {
		font-size: 1.4rem;
	}

	.section-title h3 {
		margin: 0;
		font-size: 1.05rem;
		font-weight: 700;
		color: #0f172a;
	}

	.badge {
		background: rgba(99,102,241,0.12);
		color: #4f46e5;
		border-radius: 20px;
		font-size: 0.72rem;
		font-weight: 600;
		padding: 2px 10px;
	}

	/* ── Add Button ─────────────────────────────────────────────────────────────── */
	.add-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 18px;
		background: linear-gradient(135deg, #6366f1, #4f46e5);
		color: #fff;
		border: none;
		border-radius: 8px;
		font-size: 0.84rem;
		font-weight: 600;
		cursor: pointer;
		box-shadow: 0 2px 10px rgba(99,102,241,0.3);
		transition: all 0.18s ease;
	}

	.add-btn:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 14px rgba(99,102,241,0.4);
	}

	.add-btn:active {
		transform: translateY(0);
	}

	/* ── Table ──────────────────────────────────────────────────────────────────── */
	.table-wrap {
		background: rgba(255,255,255,0.7);
		border: 1.5px solid rgba(203,213,225,0.6);
		border-radius: 14px;
		overflow: hidden;
		box-shadow: 0 4px 20px rgba(0,0,0,0.05);
	}

	.tier-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.84rem;
	}

	.tier-table thead tr {
		background: rgba(241,245,249,0.9);
		border-bottom: 1.5px solid rgba(203,213,225,0.5);
	}

	.tier-table th {
		padding: 12px 16px;
		text-align: left;
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #64748b;
		white-space: nowrap;
	}

	.tier-table tbody tr {
		border-bottom: 1px solid rgba(226,232,240,0.7);
		transition: background 0.14s ease;
	}

	.tier-table tbody tr:last-child {
		border-bottom: none;
	}

	.tier-table tbody tr:hover {
		background: rgba(241,245,249,0.8);
	}

	.tier-table td {
		padding: 13px 16px;
		color: #1e293b;
		vertical-align: middle;
	}

	/* ── Tier Name Cell ─────────────────────────────────────────────────────────── */
	.tier-name-cell {
		display: flex;
		align-items: center;
		gap: 9px;
	}

	.tier-dot {
		width: 11px;
		height: 11px;
		border-radius: 50%;
		flex-shrink: 0;
		box-shadow: 0 0 0 3px rgba(0,0,0,0.06);
	}

	.tier-name {
		font-weight: 600;
		color: #0f172a;
	}

	/* ── Numeric Cells ──────────────────────────────────────────────────────────── */
	.num-cell {
		font-variant-numeric: tabular-nums;
		color: #334155;
	}

	.currency {
		font-size: 0.72rem;
		color: #94a3b8;
		margin-right: 2px;
	}

	.unlimited {
		color: #94a3b8;
		font-style: italic;
		font-size: 0.82rem;
	}

	/* ── Badges ─────────────────────────────────────────────────────────────────── */
	.pct-badge {
		display: inline-block;
		background: rgba(16,185,129,0.12);
		color: #059669;
		border-radius: 6px;
		padding: 2px 8px;
		font-weight: 600;
		font-size: 0.82rem;
	}

	.ecash-badge {
		display: inline-block;
		background: rgba(245,158,11,0.12);
		color: #d97706;
		border-radius: 6px;
		padding: 2px 8px;
		font-weight: 600;
		font-size: 0.82rem;
	}

	.redeem-badge {
		display: inline-block;
		background: rgba(99,102,241,0.12);
		color: #6366f1;
		border-radius: 6px;
		padding: 2px 8px;
		font-weight: 600;
		font-size: 0.82rem;
	}

	/* ── Action Buttons ─────────────────────────────────────────────────────────── */
	.actions-cell {
		white-space: nowrap;
	}

	.action-btn {
		border: none;
		background: transparent;
		cursor: pointer;
		padding: 5px 7px;
		border-radius: 6px;
		font-size: 1rem;
		line-height: 1;
		transition: background 0.14s ease;
		margin-right: 2px;
	}

	.action-btn.edit:hover {
		background: rgba(99,102,241,0.12);
	}

	.action-btn.delete:hover {
		background: rgba(239,68,68,0.12);
	}

	/* ── Placeholder Panels ─────────────────────────────────────────────────────── */
	.placeholder-panel {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 320px;
		gap: 12px;
		text-align: center;
		color: #64748b;
	}

	.placeholder-icon {
		font-size: 3.5rem;
		filter: grayscale(0.2);
	}

	.placeholder-panel h3 {
		margin: 0;
		font-size: 1.15rem;
		font-weight: 700;
		color: #334155;
	}

	.placeholder-panel p {
		margin: 0;
		font-size: 0.88rem;
		max-width: 340px;
		line-height: 1.6;
		color: #94a3b8;
	}

	.coming-soon-tag {
		display: inline-block;
		background: rgba(99,102,241,0.1);
		color: #6366f1;
		border: 1.5px solid rgba(99,102,241,0.2);
		border-radius: 20px;
		font-size: 0.75rem;
		font-weight: 600;
		padding: 4px 14px;
		letter-spacing: 0.05em;
		margin-top: 4px;
	}

	/* ── Tiers state ────────────────────────────────────────────────────────────── */
	.tiers-state {
		display: flex; flex-direction: column; align-items: center;
		gap: 10px; padding: 3rem 1rem; color: #64748b; font-size: 0.9rem;
	}
	.tiers-state.error { color: #ef4444; }
	.tier-name-ar { font-size: 0.75rem; color: #94a3b8; }
	.active-dot {
		display: inline-block; width: 10px; height: 10px; border-radius: 50%;
		background: #cbd5e1;
	}
	.active-dot.active { background: #22c55e; }

	/* ── Edit Modal ─────────────────────────────────────────────────────────────── */
	.modal-backdrop {
		position: fixed; inset: 0; background: rgba(15,23,42,0.45);
		z-index: 1000; backdrop-filter: blur(3px);
	}
	.edit-modal {
		position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);
		width: min(600px, 95vw);
		background: #fff;
		border-radius: 16px;
		box-shadow: 0 20px 60px rgba(0,0,0,0.2);
		z-index: 1001;
		overflow: hidden;
	}
	.edit-modal-header {
		display: flex; align-items: center; gap: 10px;
		padding: 18px 22px;
		background: linear-gradient(135deg, #f8fafc, #e2e8f0);
		border-bottom: 1px solid #e2e8f0;
	}
	.edit-modal-header h3 { margin: 0; font-size: 1rem; font-weight: 700; color: #0f172a; flex: 1; }
	.tier-dot.lg { width: 16px; height: 16px; border-radius: 50%; flex-shrink: 0; box-shadow: 0 0 0 3px rgba(0,0,0,0.08); }
	.modal-close {
		border: none; background: rgba(100,116,139,0.12); cursor: pointer;
		width: 28px; height: 28px; border-radius: 6px; font-size: 0.85rem;
		display: flex; align-items: center; justify-content: center;
		color: #64748b; transition: background 0.15s;
	}
	.modal-close:hover { background: rgba(239,68,68,0.12); color: #ef4444; }
	.edit-modal-body { padding: 20px 22px; display: flex; flex-direction: column; gap: 14px; }
	.edit-row { display: flex; gap: 12px; flex-wrap: wrap; }
	.edit-field { display: flex; flex-direction: column; gap: 5px; flex: 1; min-width: 130px; }
	.edit-field-sm { flex: 0 0 90px; }
	.edit-field label { font-size: 0.75rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: 0.04em; }
	.edit-field input[type="text"],
	.edit-field input[type="number"] {
		padding: 8px 10px; border: 1.5px solid #e2e8f0; border-radius: 8px;
		font-size: 0.9rem; color: #1e293b; outline: none;
		transition: border-color 0.18s, box-shadow 0.18s;
		width: 100%; box-sizing: border-box;
	}
	.edit-field input:focus { border-color: #6366f1; box-shadow: 0 0 0 3px rgba(99,102,241,0.12); }
	.color-input { width: 100%; height: 40px; border: 1.5px solid #e2e8f0; border-radius: 8px; cursor: pointer; padding: 2px; }
	.toggle { display: flex; align-items: center; margin-top: 4px; cursor: pointer; }
	.toggle input[type="checkbox"] { position: absolute; opacity: 0; width: 0; height: 0; }
	.toggle-track {
		width: 42px; height: 24px; background: #cbd5e1; border-radius: 12px;
		position: relative; transition: background 0.2s;
	}
	.toggle input:checked + .toggle-track { background: #22c55e; }
	.toggle-track::after {
		content: ''; position: absolute; top: 3px; left: 3px;
		width: 18px; height: 18px; background: #fff; border-radius: 50%;
		transition: transform 0.2s; box-shadow: 0 1px 4px rgba(0,0,0,0.15);
	}
	.toggle input:checked + .toggle-track::after { transform: translateX(18px); }
	.edit-error {
		background: rgba(239,68,68,0.08); border: 1px solid rgba(239,68,68,0.25);
		color: #dc2626; border-radius: 8px; padding: 10px 14px; font-size: 0.85rem;
	}
	.edit-modal-footer {
		display: flex; gap: 10px; justify-content: flex-end;
		padding: 16px 22px; border-top: 1px solid #e2e8f0; background: #f8fafc;
	}
	.btn-cancel {
		padding: 9px 20px; border: 1.5px solid #e2e8f0; background: #fff;
		border-radius: 8px; cursor: pointer; font-size: 0.88rem; color: #64748b;
		transition: all 0.15s;
	}
	.btn-cancel:hover { background: #f1f5f9; }
	.btn-save {
		padding: 9px 22px; background: linear-gradient(135deg, #6366f1, #4f46e5);
		color: #fff; border: none; border-radius: 8px; cursor: pointer;
		font-size: 0.88rem; font-weight: 600;
		display: flex; align-items: center; gap: 6px;
		box-shadow: 0 2px 10px rgba(99,102,241,0.3); transition: all 0.15s;
	}
	.btn-save:disabled { opacity: 0.6; cursor: not-allowed; }
	.btn-save:not(:disabled):hover { transform: translateY(-1px); box-shadow: 0 4px 14px rgba(99,102,241,0.4); }

	/* ── Scrollbar ──────────────────────────────────────────────────────────────── */
	.tab-content::-webkit-scrollbar {
		width: 5px;
	}
	.tab-content::-webkit-scrollbar-track {
		background: transparent;
	}
	.tab-content::-webkit-scrollbar-thumb {
		background: rgba(148,163,184,0.4);
		border-radius: 10px;
	}

	/* ── Customer Bills Panel ───────────────────────────────────────────────────── */
	.bills-panel {
		display: flex;
		flex-direction: column;
		flex: 1;
		overflow: hidden;
		gap: 0;
	}

	.bills-table-wrap {
		flex: 1;
		overflow-y: auto;
		overflow-x: auto;
	}

	.bills-toolbar {
		display: flex;
		align-items: center;
		gap: 10px;
		flex-wrap: wrap;
	}

	.search-wrap {
		position: relative;
		display: flex;
		align-items: center;
		flex: 1;
		min-width: 240px;
	}

	.search-icon {
		position: absolute;
		left: 10px;
		font-size: 0.9rem;
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 7px 32px 7px 32px;
		border: 1.5px solid rgba(148,163,184,0.35);
		border-radius: 8px;
		background: rgba(255,255,255,0.7);
		font-size: 0.85rem;
		color: #1e293b;
		outline: none;
		transition: border-color 0.15s;
	}

	.search-input:focus {
		border-color: #6366f1;
	}

	.clear-btn {
		position: absolute;
		right: 8px;
		border: none;
		background: none;
		cursor: pointer;
		color: #94a3b8;
		font-size: 0.85rem;
		padding: 2px 4px;
	}

	.clear-btn:hover { color: #ef4444; }

	.refresh-btn {
		padding: 7px 14px;
		border: 1.5px solid rgba(99,102,241,0.3);
		border-radius: 8px;
		background: rgba(99,102,241,0.07);
		color: #6366f1;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
		transition: background 0.14s;
	}
	.refresh-btn:hover { background: rgba(99,102,241,0.14); }

	.sync-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 7px 16px;
		border: none;
		border-radius: 8px;
		background: linear-gradient(135deg, #6366f1, #8b5cf6);
		color: #fff;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
		transition: opacity 0.14s;
		box-shadow: 0 2px 8px rgba(99,102,241,0.35);
	}
	.sync-btn:disabled { opacity: 0.65; cursor: not-allowed; }
	.sync-btn:not(:disabled):hover { opacity: 0.88; }

	.sync-message {
		margin: 0 18px 8px;
		padding: 8px 14px;
		border-radius: 8px;
		font-size: 0.83rem;
		font-weight: 600;
		background: rgba(34,197,94,0.1);
		color: #16a34a;
		border: 1px solid rgba(34,197,94,0.25);
	}
	.sync-message.error {
		background: rgba(239,68,68,0.08);
		color: #dc2626;
		border-color: rgba(239,68,68,0.2);
	}

	.bills-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 220px;
		gap: 12px;
		color: #64748b;
		font-size: 0.9rem;
	}

	.bills-state.error { color: #ef4444; }

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid rgba(99,102,241,0.2);
		border-top-color: #6366f1;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}

	@keyframes spin { to { transform: rotate(360deg); } }

	.bills-table th, .bills-table td {
		white-space: nowrap;
	}

	.notes-cell {
		max-width: 160px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.mono {
		font-family: 'Courier New', monospace;
		font-size: 0.82rem;
	}

	.dim { color: #94a3b8; }

	.row-num {
		color: #94a3b8;
		font-size: 0.78rem;
	}

	.load-more-row {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 14px;
		font-size: 0.82rem;
		color: #64748b;
		border-top: 1px solid rgba(203,213,225,0.4);
	}

	.spinner-sm {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(99,102,241,0.2);
		border-top-color: #6366f1;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
	}
</style>
