<script lang="ts">
	import { onMount, onDestroy } from 'svelte';

	// ─── Types ───────────────────────────────────────────────────────────────────
	interface Customer {
		id: string;
		name: string;
		whatsapp_number: string;
		registration_status: string;
		created_at: string;
		updated_at: string;
		final_loyalty_point_balance: number;
	}

	// ─── State ───────────────────────────────────────────────────────────────────
	let activeTab: 'customers' | 'activities' = 'customers';

	// Customers tab
	let customers: Customer[] = [];
	let loading = false;
	let loadingMore = false;
	let error = '';
	let searchTerm = '';
	let statusFilter = 'all';
	let offset = 0;
	const pageSize = 50;
	let totalCount = 0;
	let hasMore = true;
	let pointsMap: Map<string, number> = new Map();

	// Summary counts
	let totalCustomers = 0;
	let approvedCustomers = 0;
	let pendingCustomers = 0;
	let rejectedCustomers = 0;

	let tableWrap: HTMLElement;

	const STATUS_OPTIONS = [
		{ value: 'all',            label: 'All' },
		{ value: 'approved',       label: 'Approved' },
		{ value: 'pending',        label: 'Pending' },
		{ value: 'pre_registered', label: 'Pre-registered' },
		{ value: 'rejected',       label: 'Rejected' },
		{ value: 'suspended',      label: 'Suspended' },
	];


	// ─── Points Loading ──────────────────────────────────────────────────────────
	async function loadPoints() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data } = await supabase.rpc('get_all_customer_total_points');
			const map = new Map<string, number>();
			(data ?? []).forEach((row: { customer_id: string; total_points: number }) => {
				map.set(row.customer_id, Number(row.total_points));
			});
			pointsMap = map;
		} catch { /* non-critical */ }
	}

	// ─── Lifecycle ───────────────────────────────────────────────────────────────
	onMount(async () => {
		await resetAndLoad();
		await loadSummary();
		await loadPoints();
	});

	onDestroy(() => {
		if (tableWrap) tableWrap.removeEventListener('scroll', onScroll);
	});

	function bindScroll(node: HTMLElement) {
		tableWrap = node;
		node.addEventListener('scroll', onScroll, { passive: true });
		return {
			destroy() { node.removeEventListener('scroll', onScroll); }
		};
	}

	function onScroll() {
		if (!tableWrap || loadingMore || !hasMore) return;
		const { scrollTop, scrollHeight, clientHeight } = tableWrap;
		if (scrollTop + clientHeight >= scrollHeight - 80) {
			loadMore();
		}
	}

	// ─── Data Loading ─────────────────────────────────────────────────────────────
	async function resetAndLoad() {
		customers = [];
		offset = 0;
		hasMore = true;
		error = '';
		await fetchPage();
	}

	async function fetchPage() {
		const isFirst = offset === 0;
		if (isFirst) loading = true; else loadingMore = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error: rpcError } = await supabase.rpc('get_customers_list_paginated', {
				p_search: searchTerm.trim(),
				p_status: statusFilter,
				p_limit: pageSize,
				p_offset: offset
			});

			if (rpcError) throw rpcError;

			const rows: Customer[] = data?.data ?? data ?? [];
			totalCount = data?.total_count ?? (offset + rows.length);
			customers = isFirst ? rows : [...customers, ...rows];
			offset += rows.length;
			hasMore = rows.length === pageSize;
		} catch (e: any) {
			error = e?.message || 'Failed to load customers';
		} finally {
			loading = false;
			loadingMore = false;
		}
	}

	async function loadMore() {
		if (loadingMore || !hasMore) return;
		await fetchPage();
	}

	async function loadSummary() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error: qError } = await supabase
				.from('customers')
				.select('registration_status', { count: 'exact', head: false });
			if (qError) throw qError;
			const rows: { registration_status: string }[] = data ?? [];
			totalCustomers   = rows.length;
			approvedCustomers = rows.filter(r => r.registration_status === 'approved').length;
			pendingCustomers  = rows.filter(r => r.registration_status === 'pending').length;
			rejectedCustomers = rows.filter(r => r.registration_status === 'rejected').length;
		} catch { /* non-critical */ }
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────────
	function onFilterChange() { resetAndLoad(); }

	function statusBadgeClass(status: string): string {
		const map: Record<string, string> = {
			approved:       'badge-approved',
			pending:        'badge-pending',
			pre_registered: 'badge-pre',
			rejected:       'badge-rejected',
			suspended:      'badge-suspended',
		};
		return map[status] ?? 'badge-default';
	}

	function statusLabel(status: string): string {
		return STATUS_OPTIONS.find(s => s.value === status)?.label ?? status;
	}

	let searchDebounce: ReturnType<typeof setTimeout>;
	function handleSearch() {
		clearTimeout(searchDebounce);
		searchDebounce = setTimeout(resetAndLoad, 350);
	}

	// ─── Sync Points ─────────────────────────────────────────────────────────────
	let syncingPoints = false;
	let showSyncSummary = false;
	interface SyncResult {
		success: boolean;
		status: 'success' | 'partial_success' | 'failed';
		total_scanned: number;
		total_matched: number;
		total_updated: number;
		total_skipped: number;
		total_points_synced: number;
		error_count: number;
		errors: { customer_id: string; mobile: string; error: string }[];
	}
	let syncResult: SyncResult | null = null;
	let syncError = '';

	async function syncPoints() {
		if (syncingPoints) return;
		syncingPoints = true;
		syncError = '';
		syncResult = null;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error: rpcError } = await supabase.rpc('sync_privilege_cards_opening_balance');
			if (rpcError) throw rpcError;
			syncResult = data as SyncResult;
			showSyncSummary = true;
			// Refresh customer data after sync
			await resetAndLoad();
			await loadPoints();
		} catch (e: any) {
			syncError = e?.message || 'Sync failed';
			showSyncSummary = true;
		} finally {
			syncingPoints = false;
		}
	}
</script>

<!-- ─── Root ─────────────────────────────────────────────────────────────────── -->
<div class="cam-root">

	<!-- Tabs bar -->
	<div class="cam-tabs">
		<button
			class="cam-tab"
			class:cam-tab--active={activeTab === 'customers'}
			on:click={() => activeTab = 'customers'}
		>
			👥 Customers
		</button>
		<button
			class="cam-tab"
			class:cam-tab--active={activeTab === 'activities'}
			on:click={() => activeTab = 'activities'}
		>
			📋 Activities
		</button>
	</div>

	<!-- ── Customers Tab ──────────────────────────────────────────────────────── -->
	{#if activeTab === 'customers'}
		<div class="cam-panel">

			<!-- Summary cards -->
			<div class="cam-cards">
				<div class="cam-card cam-card--total">
					<div class="cam-card__value">{totalCustomers}</div>
					<div class="cam-card__label">Total Customers</div>
				</div>
				<div class="cam-card cam-card--approved">
					<div class="cam-card__value">{approvedCustomers}</div>
					<div class="cam-card__label">Approved</div>
				</div>
				<div class="cam-card cam-card--pending">
					<div class="cam-card__value">{pendingCustomers}</div>
					<div class="cam-card__label">Pending</div>
				</div>
				<div class="cam-card cam-card--rejected">
					<div class="cam-card__value">{rejectedCustomers}</div>
					<div class="cam-card__label">Rejected</div>
				</div>
			</div>

			<!-- Search + Filter toolbar -->
			<div class="cam-toolbar">
				<div class="cam-search-wrap">
					<span class="cam-search-icon">🔍</span>
					<input
						class="cam-search"
						type="text"
						placeholder="Search by name or number…"
						bind:value={searchTerm}
						on:input={handleSearch}
					/>
					{#if searchTerm}
						<button class="cam-search-clear" on:click={() => { searchTerm = ''; onSearchInput(); }}>✕</button>
					{/if}
				</div>

				<select class="cam-select" bind:value={statusFilter} on:change={onFilterChange}>
					{#each STATUS_OPTIONS as opt}
						<option value={opt.value}>{opt.label}</option>
					{/each}
				</select>

				<button class="cam-btn-refresh" on:click={() => { resetAndLoad(); loadSummary(); loadPoints(); }} title="Refresh">
					🔄
				</button>

				<button
					class="cam-btn-sync"
					class:cam-btn-sync--loading={syncingPoints}
					on:click={syncPoints}
					disabled={syncingPoints}
					title="Sync opening points from privilege cards"
				>
					{#if syncingPoints}
						<span class="cam-sync-spinner"></span>
						Syncing…
					{:else}
						⚡ Sync Points
					{/if}
				</button>
			</div>

			<!-- Table area -->
			<div class="cam-table-wrap" use:bindScroll>
				{#if loading}
					<div class="cam-state cam-state--loading">
						<div class="cam-spinner"></div>
						<span>Loading customers…</span>
					</div>
				{:else if error}
					<div class="cam-state cam-state--error">
						<span>⚠️ {error}</span>
						<button class="cam-btn-retry" on:click={() => resetAndLoad()}>Retry</button>
					</div>
				{:else if customers.length === 0}
					<div class="cam-state cam-state--empty">
						<span>👤</span>
						<p>No customers found</p>
						{#if searchTerm || statusFilter !== 'all'}
							<button class="cam-btn-retry" on:click={() => { searchTerm = ''; statusFilter = 'all'; resetAndLoad(); }}>
								Clear filters
							</button>
						{/if}
					</div>
				{:else}
					<table class="cam-table">
						<thead>
							<tr>
								<th>#</th>
								<th>Name</th>
								<th>Contact Number</th>
								<th>Status</th>
								<th>Approved Date</th>
							<th>Total Points</th>
							</tr>
						</thead>
						<tbody>
							{#each customers as customer, i}
								<tr>
									<td class="cam-td-num">{i + 1}</td>
									<td class="cam-td-name">{customer.name || '—'}</td>
									<td class="cam-td-phone">{customer.whatsapp_number || '—'}</td>
									<td>
										<span class="cam-badge {statusBadgeClass(customer.registration_status)}">
											{statusLabel(customer.registration_status)}
										</span>
									</td>
									<td class="cam-td-date">
										{#if customer.registration_status === 'approved' && customer.updated_at}
											{new Date(customer.updated_at).toLocaleDateString('en-SA', { year: 'numeric', month: 'short', day: 'numeric' })}
										{:else}
											—
										{/if}
									</td>
													<td class="cam-td-points">{Number(customer.final_loyalty_point_balance ?? 0).toFixed(2)}</td>
								</tr>
							{/each}
						</tbody>
					</table>

					<!-- Infinite scroll footer -->
					<div class="cam-scroll-footer">
						{#if loadingMore}
							<div class="cam-spinner cam-spinner--sm"></div>
							<span>Loading more…</span>
						{:else if !hasMore}
							<span class="cam-all-loaded">✓ All {customers.length} customers loaded</span>
						{/if}
					</div>
				{/if}
			</div>

		</div>
	{/if}

	<!-- ── Activities Tab ────────────────────────────────────────────────────── -->
	{#if activeTab === 'activities'}
		<div class="cam-panel cam-panel--activities">
			<div class="cam-activities-placeholder">
				<div class="cam-activities-icon">📋</div>
				<h3>Activities</h3>
				<p>Activities module will be implemented later.</p>
			</div>
		</div>
	{/if}

	<!-- ── Sync Points Summary Modal ─────────────────────────────────────────── -->
	{#if showSyncSummary}
		<div class="cam-modal-overlay" on:click|self={() => showSyncSummary = false}>
			<div class="cam-modal">
				{#if syncError}
					<!-- Error state -->
					<div class="cam-modal__header cam-modal__header--error">
						<span class="cam-modal__icon">❌</span>
						<h2>Sync Failed</h2>
					</div>
					<div class="cam-modal__body">
						<div class="cam-modal__error-msg">{syncError}</div>
					</div>
				{:else if syncResult}
					<!-- Result state -->
					<div class="cam-modal__header" class:cam-modal__header--success={syncResult.status === 'success'} class:cam-modal__header--partial={syncResult.status === 'partial_success'} class:cam-modal__header--error={syncResult.status === 'failed'}>
						<span class="cam-modal__icon">
							{#if syncResult.status === 'success'}✅{:else if syncResult.status === 'partial_success'}⚠️{:else}❌{/if}
						</span>
						<h2>
							{#if syncResult.status === 'success'}Sync Complete{:else if syncResult.status === 'partial_success'}Partial Success{:else}Sync Failed{/if}
						</h2>
					</div>
					<div class="cam-modal__body">
						<div class="cam-modal__stats">
							<div class="cam-stat">
								<span class="cam-stat__value">{syncResult.total_scanned}</span>
								<span class="cam-stat__label">Cards Scanned</span>
							</div>
							<div class="cam-stat">
								<span class="cam-stat__value cam-stat__value--matched">{syncResult.total_matched}</span>
								<span class="cam-stat__label">Customers Matched</span>
							</div>
							<div class="cam-stat">
								<span class="cam-stat__value cam-stat__value--updated">{syncResult.total_updated}</span>
								<span class="cam-stat__label">Customers Updated</span>
							</div>
							<div class="cam-stat">
								<span class="cam-stat__value cam-stat__value--skipped">{syncResult.total_skipped}</span>
								<span class="cam-stat__label">Skipped (No Match)</span>
							</div>
							<div class="cam-stat cam-stat--full">
								<span class="cam-stat__value cam-stat__value--points">{syncResult.total_points_synced.toFixed(2)}</span>
								<span class="cam-stat__label">Total Opening Points Synced</span>
							</div>
							{#if syncResult.error_count > 0}
								<div class="cam-stat cam-stat--full">
									<span class="cam-stat__value cam-stat__value--error">{syncResult.error_count}</span>
									<span class="cam-stat__label">Errors</span>
								</div>
							{/if}
						</div>

						{#if syncResult.errors && syncResult.errors.length > 0}
							<div class="cam-modal__errors">
								<h4>Error Details</h4>
								{#each syncResult.errors as err}
									<div class="cam-modal__error-row">
										<span class="cam-err-mobile">{err.mobile}</span>
										<span class="cam-err-msg">{err.error}</span>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				{/if}

				<div class="cam-modal__footer">
					<button class="cam-btn-close-modal" on:click={() => showSyncSummary = false}>
						Close
					</button>
				</div>
			</div>
		</div>
	{/if}

</div>

<style>
	/* ── Root ──────────────────────────────────────────────────────────────────── */
	.cam-root {
		display: flex;
		flex-direction: column;
		height: 100%;
		position: relative;
		background: linear-gradient(135deg, #f0f4ff 0%, #fafbff 100%);
		font-family: 'Plus Jakarta Sans', 'Tajawal', sans-serif;
		color: #1e293b;
	}

	/* ── Tabs ──────────────────────────────────────────────────────────────────── */
	.cam-tabs {
		display: flex;
		gap: 4px;
		padding: 14px 20px 0;
		border-bottom: 1px solid rgba(99, 102, 241, 0.12);
		background: rgba(255, 255, 255, 0.7);
		backdrop-filter: blur(10px);
	}

	.cam-tab {
		padding: 10px 22px;
		border: none;
		border-radius: 10px 10px 0 0;
		background: transparent;
		color: #64748b;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.cam-tab:hover {
		background: rgba(99, 102, 241, 0.07);
		color: #4f46e5;
	}

	.cam-tab--active {
		background: white;
		color: #4f46e5;
		box-shadow: 0 -2px 0 0 #4f46e5 inset, 0 2px 8px rgba(99, 102, 241, 0.1);
	}

	/* ── Panel ─────────────────────────────────────────────────────────────────── */
	.cam-panel {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		padding: 20px;
		gap: 16px;
	}

	/* ── Summary Cards ─────────────────────────────────────────────────────────── */
	.cam-cards {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 12px;
	}

	.cam-card {
		background: white;
		border-radius: 14px;
		padding: 16px 18px;
		text-align: center;
		box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.8);
		transition: transform 0.2s ease, box-shadow 0.2s ease;
	}

	.cam-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 20px rgba(0, 0, 0, 0.1);
	}

	.cam-card__value {
		font-size: 2rem;
		font-weight: 800;
		line-height: 1;
		margin-bottom: 4px;
	}

	.cam-card__label {
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: #64748b;
	}

	.cam-card--total   .cam-card__value { color: #4f46e5; }
	.cam-card--approved .cam-card__value { color: #16a34a; }
	.cam-card--pending  .cam-card__value { color: #d97706; }
	.cam-card--rejected .cam-card__value { color: #dc2626; }

	/* ── Toolbar ───────────────────────────────────────────────────────────────── */
	.cam-toolbar {
		display: flex;
		gap: 10px;
		align-items: center;
	}

	.cam-search-wrap {
		flex: 1;
		position: relative;
		display: flex;
		align-items: center;
	}

	.cam-search-icon {
		position: absolute;
		left: 12px;
		font-size: 0.9rem;
		pointer-events: none;
	}

	.cam-search {
		width: 100%;
		padding: 9px 36px 9px 36px;
		border: 1.5px solid #e2e8f0;
		border-radius: 10px;
		background: white;
		font-size: 0.88rem;
		color: #1e293b;
		transition: border-color 0.2s ease, box-shadow 0.2s ease;
		outline: none;
	}

	.cam-search:focus {
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.12);
	}

	.cam-search-clear {
		position: absolute;
		right: 10px;
		background: none;
		border: none;
		cursor: pointer;
		color: #94a3b8;
		font-size: 0.8rem;
		padding: 2px 4px;
	}

	.cam-search-clear:hover { color: #ef4444; }

	.cam-select {
		padding: 9px 14px;
		border: 1.5px solid #e2e8f0;
		border-radius: 10px;
		background: white;
		font-size: 0.88rem;
		color: #1e293b;
		cursor: pointer;
		outline: none;
		transition: border-color 0.2s ease;
	}

	.cam-select:focus { border-color: #6366f1; }

	.cam-btn-refresh {
		padding: 9px 13px;
		border: 1.5px solid #e2e8f0;
		border-radius: 10px;
		background: white;
		cursor: pointer;
		font-size: 1rem;
		transition: all 0.2s ease;
	}

	.cam-btn-refresh:hover {
		border-color: #6366f1;
		background: #f5f3ff;
	}

	/* ── Sync Points Button ─────────────────────────────────────────────────────── */
	.cam-btn-sync {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 9px 16px;
		border: 1.5px solid #10b981;
		border-radius: 10px;
		background: #ecfdf5;
		color: #065f46;
		font-size: 0.88rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s ease;
		white-space: nowrap;
	}

	.cam-btn-sync:hover:not(:disabled) {
		background: #10b981;
		color: white;
		border-color: #10b981;
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.cam-btn-sync:disabled,
	.cam-btn-sync--loading {
		opacity: 0.75;
		cursor: not-allowed;
	}

	.cam-sync-spinner {
		display: inline-block;
		width: 14px;
		height: 14px;
		border: 2px solid rgba(6, 95, 70, 0.3);
		border-top-color: #065f46;
		border-radius: 50%;
		animation: cam-spin 0.7s linear infinite;
	}

	/* ── Sync Modal ─────────────────────────────────────────────────────────────── */
	.cam-modal-overlay {
		position: absolute;
		inset: 0;
		background: rgba(15, 23, 42, 0.55);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999;
	}

	.cam-modal {
		background: white;
		border-radius: 20px;
		width: 520px;
		max-width: 92%;
		box-shadow: 0 24px 60px rgba(0, 0, 0, 0.2);
		overflow: hidden;
		animation: cam-modal-in 0.25s ease;
	}

	@keyframes cam-modal-in {
		from { transform: scale(0.92); opacity: 0; }
		to   { transform: scale(1);    opacity: 1; }
	}

	.cam-modal__header {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 20px 24px;
		color: white;
	}

	.cam-modal__header--success  { background: linear-gradient(135deg, #10b981, #059669); }
	.cam-modal__header--partial  { background: linear-gradient(135deg, #f59e0b, #d97706); }
	.cam-modal__header--error    { background: linear-gradient(135deg, #ef4444, #dc2626); }

	.cam-modal__icon { font-size: 1.6rem; }

	.cam-modal__header h2 {
		margin: 0;
		font-size: 1.2rem;
		font-weight: 800;
	}

	.cam-modal__body {
		padding: 24px;
	}

	.cam-modal__stats {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 12px;
		margin-bottom: 16px;
	}

	.cam-stat {
		background: #f8fafc;
		border-radius: 12px;
		padding: 14px;
		text-align: center;
		border: 1px solid #e2e8f0;
	}

	.cam-stat--full { grid-column: 1 / -1; }

	.cam-stat__value {
		display: block;
		font-size: 1.8rem;
		font-weight: 800;
		color: #4f46e5;
		line-height: 1;
		margin-bottom: 4px;
	}

	.cam-stat__value--matched  { color: #4f46e5; }
	.cam-stat__value--updated  { color: #10b981; }
	.cam-stat__value--skipped  { color: #f59e0b; }
	.cam-stat__value--points   { color: #0ea5e9; }
	.cam-stat__value--error    { color: #ef4444; }

	.cam-stat__label {
		font-size: 0.72rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #64748b;
	}

	.cam-modal__errors {
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 10px;
		padding: 12px;
		max-height: 140px;
		overflow-y: auto;
	}

	.cam-modal__errors h4 {
		margin: 0 0 8px;
		font-size: 0.82rem;
		color: #dc2626;
	}

	.cam-modal__error-row {
		display: flex;
		gap: 10px;
		font-size: 0.8rem;
		padding: 4px 0;
		border-bottom: 1px solid rgba(220, 38, 38, 0.1);
	}

	.cam-modal__error-row:last-child { border-bottom: none; }

	.cam-err-mobile { font-weight: 700; color: #dc2626; min-width: 120px; }
	.cam-err-msg    { color: #7f1d1d; }

	.cam-modal__error-msg {
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 10px;
		padding: 14px;
		color: #dc2626;
		font-size: 0.9rem;
	}

	.cam-modal__footer {
		padding: 16px 24px;
		border-top: 1px solid #f1f5f9;
		display: flex;
		justify-content: flex-end;
	}

	.cam-btn-close-modal {
		padding: 10px 28px;
		background: #4f46e5;
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 0.9rem;
		font-weight: 700;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.cam-btn-close-modal:hover { background: #4338ca; }

	/* ── Table ─────────────────────────────────────────────────────────────────── */
	.cam-table-wrap {
		flex: 1;
		overflow-y: auto;
		border-radius: 14px;
		box-shadow: 0 2px 16px rgba(0, 0, 0, 0.06);
		background: white;
	}

	.cam-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	.cam-table thead th {
		padding: 13px 16px;
		text-align: left;
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #64748b;
		background: #f8fafc;
		border-bottom: 1px solid #f1f5f9;
		position: sticky;
		top: 0;
		z-index: 1;
	}

	.cam-table tbody tr {
		border-bottom: 1px solid #f1f5f9;
		transition: background 0.15s ease;
	}

	.cam-table tbody tr:last-child { border-bottom: none; }
	.cam-table tbody tr:hover { background: #fafbff; }

	.cam-table tbody td {
		padding: 13px 16px;
		color: #334155;
	}

	.cam-td-num  { color: #94a3b8; font-size: 0.8rem; width: 48px; }
	.cam-td-name { font-weight: 600; color: #1e293b; }
	.cam-td-phone { font-family: monospace; font-size: 0.85rem; }
	.cam-td-date { font-size: 0.82rem; color: #64748b; white-space: nowrap; }

	/* ── Status Badges ─────────────────────────────────────────────────────────── */
	.cam-badge {
		display: inline-flex;
		align-items: center;
		padding: 3px 10px;
		border-radius: 999px;
		font-size: 0.75rem;
		font-weight: 700;
	}

	.badge-approved   { background: #dcfce7; color: #15803d; }
	.badge-pending    { background: #fef9c3; color: #a16207; }
	.badge-pre        { background: #dbeafe; color: #1d4ed8; }
	.badge-rejected   { background: #fee2e2; color: #b91c1c; }
	.badge-suspended  { background: #fce7f3; color: #9d174d; }
	.badge-default    { background: #f1f5f9; color: #475569; }

	/* ── States (loading / error / empty) ─────────────────────────────────────── */
	.cam-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 12px;
		padding: 64px 24px;
		color: #94a3b8;
		font-size: 0.9rem;
	}

	.cam-spinner {
		width: 36px;
		height: 36px;
		border: 3px solid #e2e8f0;
		border-top-color: #6366f1;
		border-radius: 50%;
		animation: cam-spin 0.8s linear infinite;
	}

	@keyframes cam-spin { to { transform: rotate(360deg); } }

	.cam-state--error { color: #ef4444; }
	.cam-state--empty span { font-size: 2.5rem; }
	.cam-state--empty p { margin: 0; font-size: 0.9rem; color: #94a3b8; }

	.cam-btn-retry {
		padding: 7px 18px;
		border: 1.5px solid #e2e8f0;
		border-radius: 8px;
		background: white;
		cursor: pointer;
		font-size: 0.85rem;
		color: #475569;
		transition: all 0.2s ease;
	}

	.cam-btn-retry:hover { border-color: #6366f1; color: #4f46e5; }

	/* ── Pagination ────────────────────────────────────────────────────────────── */
	.cam-scroll-footer {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 10px;
		padding: 16px;
		border-top: 1px solid #f1f5f9;
		font-size: 0.82rem;
		color: #94a3b8;
	}

	.cam-spinner--sm {
		width: 18px;
		height: 18px;
		border-width: 2px;
	}

	.cam-all-loaded { color: #16a34a; font-weight: 600; }

	/* ── Activities placeholder ────────────────────────────────────────────────── */
	.cam-panel--activities {
		align-items: center;
		justify-content: center;
	}

	.cam-activities-placeholder {
		text-align: center;
		padding: 48px 32px;
		background: white;
		border-radius: 20px;
		box-shadow: 0 4px 24px rgba(0, 0, 0, 0.06);
		max-width: 420px;
	}

	.cam-activities-icon {
		font-size: 3.5rem;
		margin-bottom: 16px;
	}

	.cam-activities-placeholder h3 {
		margin: 0 0 10px;
		font-size: 1.25rem;
		font-weight: 700;
		color: #1e293b;
	}

	.cam-activities-placeholder p {
		margin: 0;
		color: #64748b;
		font-size: 0.95rem;
		line-height: 1.6;
	}
</style>
