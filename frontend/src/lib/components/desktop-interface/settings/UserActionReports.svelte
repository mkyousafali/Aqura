<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';

	interface BranchOption {
		branch_id: number;
		branch_name: string;
		tunnel_url: string;
		erp_branch_id: number;
	}

	// Unified display entry — covers both item-level (VoidItems-backed) rows and
	// generic single-action rows (Save/Print/View/Edit/PriceChang/BTI/etc.)
	interface Entry {
		time: string;
		counter: string;
		actor: string;
		authorizedBy: string | null;
		kind: string;
		detail: string;
		amount: number | null;
		isItemLevel: boolean;
	}

	interface SummaryRow {
		Kind: string;
		Cnt: number;
	}

	const FRIENDLY_ACTION_NAMES: Record<string, string> = {
		PriceChang: 'Price Change',
		'BTI Pendin': 'BTI Pending',
		'BTI Accept': 'BTI Accepted',
		'Cheque Pri': 'Cheque Print',
		'PDT Trans': 'Product Transaction'
	};

	const ITEM_LEVEL_KINDS = new Set(['Remove a row from list', 'Void selected item', 'Cancel selected product list']);

	// Categorize an Authorize sub-action from its raw ActionPerformed text
	function deriveAuthorizeKind(actionPerformed: string | null | undefined, actionForm: string | null | undefined): string {
		const text = actionPerformed || '';
		if ((actionForm || '') === 'COUNTER SH') return 'Counter Open/Close';
		if (text.includes('Remove a row')) return 'Remove a row from list';
		if (text.includes('void selected items')) return 'Void selected item';
		if (text.includes('Cancel selected product list')) return 'Cancel selected product list';
		if (text.includes('retun window')) return 'Open return window';
		if (text.includes('close the counter shift')) return 'Try to close counter shift';
		if (text.includes('close window')) return 'Try to close window';
		return 'Other Authorize';
	}

	// Categorize any UserActions row (Authorize or otherwise) into a display Kind
	function deriveKind(actionName: string, actionPerformed: string | null | undefined, actionForm: string | null | undefined): string {
		if (actionName === 'Authorize') return deriveAuthorizeKind(actionPerformed, actionForm);
		return FRIENDLY_ACTION_NAMES[actionName] || actionName;
	}

	let branches: BranchOption[] = [];
	let selectedBranchId: number | null = null;
	let loadingBranches = true;

	const today = new Date().toISOString().split('T')[0];
	let dateFrom = today;
	let dateTo = today;

	let allEntries: Entry[] = [];
	let loading = false;
	let hasRun = false;
	let errorMessage = '';
	let expandedGroups = new Set<string>();
	let selectedKind: string | null = null;
	let selectedCashier: string | null = null;
	let cappedItemRows = false;
	let cappedGenericRows = false;

	function toggleKindFilter(kind: string) {
		selectedKind = selectedKind === kind ? null : kind;
	}

	// Cashier options are derived from the fetched data itself (post-fetch filter), not pre-loaded
	$: cashierOptions = Array.from(new Set(allEntries.map((r) => r.actor).filter(Boolean))).sort();

	// Kinds that never carry a product/amount (purely app-behavior or informational actions)
	const NO_ITEM_KINDS = new Set([
		'Counter Open/Close', 'Try to close window', 'Try to close counter shift', 'Open return window', 'Other Authorize'
	]);

	// Breakdown pills computed client-side from the cashier-filtered set (NOT kind-filtered — pills
	// need to always show every available kind as an option). This keeps counts consistent with
	// whatever is actually filterable, instead of a separate unfiltered SQL query going stale.
	$: cashierScopedEntries = selectedCashier ? allEntries.filter((r) => r.actor === selectedCashier) : allEntries;
	$: summaryRows = Array.from(
		cashierScopedEntries.reduce((map, r) => map.set(r.kind, (map.get(r.kind) || 0) + 1), new Map<string, number>()).entries()
	).map(([Kind, Cnt]) => ({ Kind, Cnt })).sort((a, b) => b.Cnt - a.Cnt);

	// If the currently selected kind has no entries left after a cashier filter change, clear it
	// automatically instead of silently showing an empty/confusing table.
	$: if (selectedKind && !summaryRows.some((r) => r.Kind === selectedKind)) {
		selectedKind = null;
	}

	$: filteredEntries = allEntries.filter(
		(r) => (!selectedKind || r.kind === selectedKind) && (!selectedCashier || r.actor === selectedCashier)
	);

	// Group entries into "events" (same counter + same second + same kind = one action instance)
	$: groupedRows = groupByEvent(filteredEntries);

	// Per-actor breakdown (respects the active Kind/Cashier filters), sorted by total amount desc, falls back to count
	$: cashierBreakdown = Array.from(
		filteredEntries.reduce((map, r) => {
			const key = r.actor || 'Unknown';
			const entry = map.get(key) || { name: key, items: 0, total: 0 };
			entry.items += 1;
			entry.total += r.amount || 0;
			map.set(key, entry);
			return map;
		}, new Map<string, { name: string; items: number; total: number }>()).values()
	).sort((a, b) => (b.total - a.total) || (b.items - a.items));

	function groupByEvent(rows: Entry[]) {
		const groups = new Map<string, Entry[]>();
		for (const row of rows) {
			// Truncate to whole seconds — items in the same batch are inserted milliseconds apart,
			// so an exact timestamp match would wrongly split them into separate rows.
			const secondBucket = row.time.slice(0, 19);
			const key = `${row.counter}|${secondBucket}|${row.kind}|${row.authorizedBy || ''}`;
			if (!groups.has(key)) groups.set(key, []);
			groups.get(key)!.push(row);
		}
		return Array.from(groups.entries()).map(([key, items]) => ({
			key,
			counter: items[0].counter,
			time: items[0].time,
			actor: items[0].actor,
			authorizedBy: items[0].authorizedBy,
			kind: items[0].kind,
			isItemLevel: items[0].isItemLevel,
			items,
			total: items.reduce((sum, i) => sum + (i.amount || 0), 0)
		})).sort((a, b) => new Date(b.time).getTime() - new Date(a.time).getTime());
	}

	function toggleGroup(key: string) {
		if (expandedGroups.has(key)) expandedGroups.delete(key);
		else expandedGroups.add(key);
		expandedGroups = expandedGroups; // trigger reactivity
	}

	$: totalItems = filteredEntries.length;
	$: totalAmount = filteredEntries.reduce((sum, r) => sum + (r.amount || 0), 0);
	$: cancelAmount = filteredEntries.filter(r => r.kind === 'Cancel selected product list').reduce((sum, r) => sum + (r.amount || 0), 0);
	$: voidAmount = filteredEntries.filter(r => r.kind === 'Void selected item' || r.kind === 'Remove a row from list').reduce((sum, r) => sum + (r.amount || 0), 0);
	$: topCashier = topBy(filteredEntries, 'actor');
	$: topAuthorizer = topBy(filteredEntries.filter(r => r.authorizedBy), 'authorizedBy');

	function topBy(rows: Entry[], field: 'actor' | 'authorizedBy') {
		const totals = new Map<string, number>();
		for (const r of rows) {
			const key = (r as any)[field] || 'Unknown';
			totals.set(key, (totals.get(key) || 0) + (r.amount || 0));
		}
		let best = { name: '-', amount: 0 };
		for (const [name, amount] of totals) {
			if (amount > best.amount) best = { name, amount };
		}
		return best;
	}

	const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
	const ROW_CAP = 50000;

	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data: erpConns, error: erpErr } = await supabase
				.from('erp_connections')
				.select('branch_id, branch_name, tunnel_url, erp_branch_id')
				.eq('is_active', true)
				.order('branch_id');

			if (erpErr) throw erpErr;

			branches = (erpConns || [])
				.filter((c: any) => c.tunnel_url)
				.map((c: any) => ({
					branch_id: c.branch_id,
					branch_name: c.branch_name || `Branch ${c.branch_id}`,
					tunnel_url: c.tunnel_url,
					erp_branch_id: c.erp_branch_id
				}));

			if (branches.length > 0 && !selectedBranchId) {
				selectedBranchId = branches[0].branch_id;
			}
		} catch (err: any) {
			console.error('Error loading branches:', err);
			errorMessage = err.message || 'Failed to load branches';
		} finally {
			loadingBranches = false;
		}
	}

	async function runQuery(sql: string, tunnelUrl: string): Promise<any[]> {
		const response = await fetch('/api/erp-products', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ action: 'query', tunnelUrl, sql })
		});
		const data = await response.json();
		if (!data.success) throw new Error(data.error || 'Query failed');
		return data.recordset || [];
	}

	async function loadReport() {
		if (!selectedBranchId) return;
		if (!DATE_RE.test(dateFrom) || !DATE_RE.test(dateTo)) {
			errorMessage = 'Invalid date format';
			return;
		}

		const branch = branches.find((b) => b.branch_id === selectedBranchId);
		if (!branch) return;

		loading = true;
		errorMessage = '';
		allEntries = [];
		expandedGroups = new Set();
		selectedKind = null;
		selectedCashier = null;
		cappedItemRows = false;
		cappedGenericRows = false;

		try {
			// This ERP database is shared across multiple physical branches (confirmed via schema:
			// UserActions/VoidItems/Counter all have a BranchID column, and branch 1's DB alone
			// contains BranchID values 0-4 mixed together) — every query MUST filter by this
			// branch's erp_branch_id, otherwise it silently returns every branch's data combined.
			const erpBranchId = branch.erp_branch_id;

			// Item-level Cancel/Void/Remove-a-row detail, with nearest Authorize event for "Authorized By" + raw text
			// Users/Counter/ProductBatches/Products all carry their own BranchID and their IDs are NOT
			// globally unique (e.g. ProductBatchID repeats ~4x, UserID up to 3x across branches) — every
			// LEFT JOIN below must also match on BranchID, otherwise one VoidItems row fans out into
			// multiple duplicate result rows (one per branch sharing that same ID).
			const itemSql = `
				SELECT TOP ${ROW_CAP} vi.CreatedDate, c.CounterName, u.UserName AS Cashier, p.ProductName, vi.Total, vi.Remarks,
					matched.AuthorizedBy, matched.ActionPerformed AS MatchedAction
				FROM VoidItems vi
				LEFT JOIN Users u ON u.UserID = vi.UserID AND u.BranchID = ${erpBranchId}
				LEFT JOIN Counter c ON c.CounterID = vi.CounterID AND c.BranchID = ${erpBranchId}
				LEFT JOIN ProductBatches pb ON pb.ProductBatchID = vi.ProductBatchID AND pb.BranchID = ${erpBranchId}
				LEFT JOIN Products p ON p.ProductID = pb.ProductID AND p.BranchID = ${erpBranchId}
				OUTER APPLY (
					SELECT TOP 1 u2.UserName AS AuthorizedBy, ua.ActionPerformed
					FROM UserActions ua LEFT JOIN Users u2 ON u2.UserID = ua.UserID AND u2.BranchID = ${erpBranchId}
					WHERE ua.CounterID = vi.CounterID AND ua.ActionName = 'Authorize'
					  AND ua.BranchID = ${erpBranchId}
					  AND ABS(DATEDIFF(second, ua.DateTimeOfAction, vi.CreatedDate)) <= 5
					ORDER BY ABS(DATEDIFF(second, ua.DateTimeOfAction, vi.CreatedDate)) ASC
				) matched
				WHERE vi.BranchID = ${erpBranchId}
				  AND vi.TransactionDate BETWEEN '${dateFrom}' AND '${dateTo}'
				ORDER BY vi.CreatedDate DESC
			`;

			// ALL other logged actions (Save, Print, View, Open, Edit, PriceChang, BTI, Close, Show, Load, Delete,
			// Add, Clicked, PDT Trans, Cheque Pri, plus non-item Authorize sub-types like close window/return window)
			const genericSql = `
				SELECT TOP ${ROW_CAP} ua.DateTimeOfAction, c.CounterName, u.UserName, ua.ActionName, ua.ActionForm,
					ua.ActionPerformed, ua.VoucherNumber
				FROM UserActions ua
				LEFT JOIN Users u ON u.UserID = ua.UserID AND u.BranchID = ${erpBranchId}
				LEFT JOIN Counter c ON c.CounterID = ua.CounterID AND c.BranchID = ${erpBranchId}
				WHERE ua.BranchID = ${erpBranchId}
				  AND CAST(ua.DateTimeOfAction AS DATE) BETWEEN '${dateFrom}' AND '${dateTo}'
				ORDER BY ua.DateTimeOfAction DESC
			`;

			const [items, generic] = await Promise.all([
				runQuery(itemSql, branch.tunnel_url),
				runQuery(genericSql, branch.tunnel_url)
			]);

			cappedItemRows = items.length >= ROW_CAP;
			cappedGenericRows = generic.length >= ROW_CAP;

			const itemEntries: Entry[] = items.map((r: any) => ({
				time: r.CreatedDate,
				counter: r.CounterName,
				actor: r.Cashier,
				authorizedBy: r.AuthorizedBy,
				kind: deriveAuthorizeKind(r.MatchedAction, null),
				detail: r.ProductName,
				amount: r.Total,
				isItemLevel: true
			}));

			// Skip generic rows whose kind duplicates what's already covered by VoidItems (avoids double counting)
			const genericEntries: Entry[] = generic
				.map((r: any) => ({
					time: r.DateTimeOfAction,
					counter: r.CounterName,
					kind: deriveKind(r.ActionName, r.ActionPerformed, r.ActionForm),
					isAuthorize: r.ActionName === 'Authorize',
					userName: r.UserName,
					detail: r.ActionPerformed || (r.VoucherNumber ? `Voucher: ${r.VoucherNumber}` : '-')
				}))
				.filter((r: any) => !ITEM_LEVEL_KINDS.has(r.kind))
				.map((r: any) => ({
					time: r.time,
					counter: r.counter,
					actor: r.isAuthorize ? '-' : r.userName,
					authorizedBy: r.isAuthorize ? r.userName : null,
					kind: r.kind,
					detail: r.detail,
					amount: null,
					isItemLevel: false
				}));

			allEntries = [...itemEntries, ...genericEntries];
		} catch (err: any) {
			console.error('Error loading user action report:', err);
			errorMessage = err.message || 'Failed to load report';
		} finally {
			loading = false;
			hasRun = true;
		}
	}

	// The bridge serializes SQL Server datetimes with a "Z" (UTC) suffix, but the underlying
	// value is actually the raw branch-local clock time (mislabeled) — NOT true UTC.
	// Parse the digits directly instead of using `new Date().toLocaleString()`, which would
	// incorrectly re-shift the time by the browser's own timezone offset.
	function formatTime(iso: string): string {
		const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/.exec(iso);
		if (!match) return iso;
		const [, year, month, day, hour, minute, second] = match;
		const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
		const h = parseInt(hour, 10);
		const ampm = h >= 12 ? 'PM' : 'AM';
		const h12 = h % 12 === 0 ? 12 : h % 12;
		return `${monthNames[parseInt(month, 10) - 1]} ${parseInt(day, 10)}, ${year} ${String(h12).padStart(2, '0')}:${minute}:${second} ${ampm}`;
	}

	function formatAmount(n: number): string {
		return (n || 0).toFixed(2);
	}

	function truncate(text: string, max = 80): string {
		if (!text) return '-';
		return text.length > max ? text.slice(0, max) + '…' : text;
	}
</script>

<div class="user-action-reports">
	<div class="bg-blob blob-1"></div>
	<div class="bg-blob blob-2"></div>

	<div class="header">
		<div class="header-left">
			<span class="header-icon">🕵️</span>
			<div>
				<h2 class="header-title">{t('nav.userActionReports') || 'User Action Reports'}</h2>
				<p class="header-subtitle">All user actions — authorizations, invoices, edits, price changes &amp; more — live from branch ERP</p>
			</div>
		</div>
	</div>

	<div class="filters-panel">
		<div class="filter-field">
			<label for="branch-select">Branch</label>
			<select id="branch-select" bind:value={selectedBranchId} disabled={loadingBranches}>
				{#each branches as b}
					<option value={b.branch_id}>{b.branch_name}</option>
				{/each}
			</select>
		</div>
		<div class="filter-field">
			<label for="date-from">From</label>
			<input id="date-from" type="date" bind:value={dateFrom} />
		</div>
		<div class="filter-field">
			<label for="date-to">To</label>
			<input id="date-to" type="date" bind:value={dateTo} />
		</div>
		<div class="filter-field">
			<label for="cashier-filter">Cashier</label>
			<select id="cashier-filter" bind:value={selectedCashier}>
				<option value={null}>All Cashiers</option>
				{#each cashierOptions as name}
					<option value={name}>{name}</option>
				{/each}
			</select>
		</div>
		<button class="run-btn" on:click={loadReport} disabled={loading || !selectedBranchId}>
			{loading ? '⏳ Loading...' : '🔍 Run Report'}
		</button>
	</div>

	{#if errorMessage}
		<div class="error-banner">⚠️ {errorMessage}</div>
	{/if}

	{#if cappedItemRows || cappedGenericRows}
		<div class="error-banner warn">⚠️ Results were capped at {ROW_CAP} rows for one or more data sources — narrow your date range for complete data.</div>
	{/if}

	{#if totalItems > 0}
		<div class="summary-cards">
			<div class="summary-card">
				<div class="summary-label">Total Items</div>
				<div class="summary-value">{totalItems}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Total Amount</div>
				<div class="summary-value">{formatAmount(totalAmount)}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Cancel / Void</div>
				<div class="summary-value">{formatAmount(cancelAmount)} / {formatAmount(voidAmount)}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Top User</div>
				<div class="summary-value small">{topCashier.name} <span class="dim">({formatAmount(topCashier.amount)})</span></div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Top Authorizer</div>
				<div class="summary-value small">{topAuthorizer.name} <span class="dim">({formatAmount(topAuthorizer.amount)})</span></div>
			</div>
		</div>
	{/if}

	{#if summaryRows.length > 0}
		<div class="section-block">
			<div class="section-title-row">
				<h3 class="section-title">All Actions Breakdown</h3>
				{#if selectedKind}
					<button class="clear-filter-btn" on:click={() => (selectedKind = null)}>✕ Clear filter</button>
				{/if}
			</div>
			<div class="type-pills">
				{#each summaryRows as row}
					<button
						class="type-pill"
						class:active={selectedKind === row.Kind}
						on:click={() => toggleKindFilter(row.Kind)}
						title={NO_ITEM_KINDS.has(row.Kind) ? 'App-behavior action — no product/amount detail' : 'Filter table by this type'}
					>
						<span class="pill-name">{row.Kind}</span>
						<span class="pill-count">{row.Cnt}</span>
					</button>
				{/each}
			</div>
		</div>
	{/if}

	{#if groupedRows.length > 0}
		<div class="content-split">
			<div class="table-column section-block">
				<h3 class="section-title">Action Detail</h3>
				<div class="table-wrapper">
					<table>
						<thead>
							<tr>
								<th></th>
								<th>Time</th>
								<th>Counter</th>
								<th>User</th>
								<th>Authorized By</th>
								<th>Type</th>
								<th>Detail</th>
								<th>Amount</th>
							</tr>
						</thead>
						<tbody>
							{#each groupedRows as g}
								<tr class="group-row" on:click={() => toggleGroup(g.key)}>
									<td class="expand-cell">{expandedGroups.has(g.key) ? '▼' : '▶'}</td>
									<td>{formatTime(g.time)}</td>
									<td>{g.counter || '-'}</td>
									<td>{g.actor || '-'}</td>
									<td>{g.authorizedBy || '-'}</td>
									<td><span class="type-badge" class:cancel={g.kind === 'Cancel selected product list'} class:void={g.kind === 'Void selected item' || g.kind === 'Remove a row from list'} class:generic={g.isItemLevel === false}>{g.kind}</span></td>
									<td>{g.isItemLevel ? `${g.items.length} item${g.items.length === 1 ? '' : 's'}` : truncate(g.items[0].detail)}</td>
									<td class="amount-cell">{g.isItemLevel ? formatAmount(g.total) : '-'}</td>
								</tr>
								{#if expandedGroups.has(g.key)}
									{#each g.items as item}
										<tr class="detail-row">
											<td></td>
											<td colspan="5" class="product-name">↳ {item.detail}</td>
											<td class="amount-cell">{item.amount !== null ? formatAmount(item.amount) : ''}</td>
										</tr>
									{/each}
								{/if}
							{/each}
						</tbody>
					</table>
				</div>
			</div>

			<div class="cashier-column section-block">
				<h3 class="section-title">User Breakdown</h3>
				<div class="cashier-card-list">
					{#each cashierBreakdown as c}
						<div class="cashier-mini-card" class:active={selectedCashier === c.name} on:click={() => (selectedCashier = selectedCashier === c.name ? null : c.name)}>
							<div class="cashier-mini-name">{c.name}</div>
							<div class="cashier-mini-stats">
								<span class="cashier-mini-amount">{formatAmount(c.total)}</span>
							</div>
						</div>
					{/each}
				</div>
			</div>
		</div>
	{:else if !loading && totalItems === 0 && !errorMessage}
		<div class="empty-state">
			{hasRun
				? 'No results match the current filters — try a different cashier, type, or date range.'
				: 'No data yet — select a branch and date range, then click Run Report.'}
		</div>
	{/if}
</div>

<style>
	.user-action-reports {
		position: relative;
		width: 100%;
		height: 100%;
		overflow-y: auto;
		padding: 1.25rem;
		background: linear-gradient(135deg, #fff5f5 0%, #fff0f0 50%, #fef2f2 100%);
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.bg-blob {
		position: fixed;
		border-radius: 50%;
		pointer-events: none;
		filter: blur(60px);
		opacity: 0.35;
		z-index: 0;
	}
	.blob-1 {
		width: 300px;
		height: 300px;
		background: rgba(239, 68, 68, 0.25);
		top: -80px;
		right: -60px;
	}
	.blob-2 {
		width: 260px;
		height: 260px;
		background: rgba(252, 165, 165, 0.3);
		bottom: -60px;
		left: -60px;
	}

	.header,
	.filters-panel,
	.summary-cards,
	.section-block,
	.error-banner,
	.empty-state {
		position: relative;
		z-index: 1;
	}

	.header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.25rem;
		background: rgba(255, 255, 255, 0.55);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border: 1px solid rgba(254, 202, 202, 0.7);
		border-radius: 16px;
		box-shadow: 0 8px 24px rgba(220, 38, 38, 0.08);
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.header-icon {
		font-size: 2rem;
	}

	.header-title {
		margin: 0;
		font-size: 1.2rem;
		font-weight: 700;
		color: #7f1d1d;
	}

	.header-subtitle {
		margin: 0.2rem 0 0;
		font-size: 0.8rem;
		color: #991b1b;
		opacity: 0.75;
	}

	.filters-panel {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: 0.85rem;
		padding: 1rem 1.25rem;
		background: rgba(255, 255, 255, 0.5);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(254, 202, 202, 0.6);
		border-radius: 16px;
		box-shadow: 0 6px 18px rgba(220, 38, 38, 0.06);
	}

	.filter-field {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
		min-width: 140px;
	}

	.filter-field label {
		font-size: 0.72rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.4px;
		color: #b91c1c;
	}

	.filter-field select,
	.filter-field input {
		padding: 0.5rem 0.7rem;
		border-radius: 10px;
		border: 1px solid rgba(252, 165, 165, 0.7);
		background: rgba(255, 255, 255, 0.8);
		font-size: 0.85rem;
		color: #7f1d1d;
	}

	.filter-field select:focus,
	.filter-field input:focus {
		outline: none;
		border-color: #ef4444;
	}

	.run-btn {
		padding: 0.6rem 1.4rem;
		border: none;
		border-radius: 10px;
		background: linear-gradient(135deg, #ef4444, #dc2626);
		color: #fff;
		font-weight: 700;
		font-size: 0.85rem;
		cursor: pointer;
		box-shadow: 0 6px 16px rgba(220, 38, 38, 0.3);
		transition: transform 0.15s, box-shadow 0.15s;
	}
	.run-btn:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 8px 20px rgba(220, 38, 38, 0.4);
	}
	.run-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.error-banner {
		padding: 0.75rem 1rem;
		background: rgba(220, 38, 38, 0.1);
		border: 1px solid rgba(220, 38, 38, 0.35);
		border-radius: 12px;
		color: #b91c1c;
		font-size: 0.85rem;
		font-weight: 600;
	}
	.error-banner.warn {
		background: rgba(245, 158, 11, 0.1);
		border-color: rgba(245, 158, 11, 0.4);
		color: #b45309;
	}

	.summary-cards {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
		gap: 0.75rem;
	}

	.summary-card {
		padding: 0.9rem 1rem;
		background: rgba(255, 255, 255, 0.55);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		border: 1px solid rgba(254, 202, 202, 0.6);
		border-radius: 14px;
		box-shadow: 0 6px 16px rgba(220, 38, 38, 0.06);
	}

	.summary-label {
		font-size: 0.7rem;
		text-transform: uppercase;
		letter-spacing: 0.4px;
		color: #b91c1c;
		font-weight: 600;
		margin-bottom: 0.3rem;
	}

	.summary-value {
		font-size: 1.15rem;
		font-weight: 700;
		color: #7f1d1d;
	}
	.summary-value.small {
		font-size: 0.9rem;
	}
	.summary-value .dim {
		font-weight: 500;
		font-size: 0.78rem;
		color: #b91c1c;
		opacity: 0.7;
	}

	.section-block {
		background: rgba(255, 255, 255, 0.5);
		backdrop-filter: blur(14px);
		-webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(254, 202, 202, 0.6);
		border-radius: 16px;
		padding: 1rem 1.1rem;
		box-shadow: 0 8px 20px rgba(220, 38, 38, 0.06);
	}

	.section-title {
		margin: 0 0 0.75rem;
		font-size: 0.95rem;
		font-weight: 700;
		color: #7f1d1d;
	}

	.section-title-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.75rem;
	}
	.section-title-row .section-title {
		margin-bottom: 0;
	}

	.clear-filter-btn {
		border: none;
		background: rgba(220, 38, 38, 0.1);
		color: #b91c1c;
		font-size: 0.72rem;
		font-weight: 700;
		padding: 0.3rem 0.7rem;
		border-radius: 999px;
		cursor: pointer;
		transition: background 0.15s;
	}
	.clear-filter-btn:hover {
		background: rgba(220, 38, 38, 0.2);
	}

	.type-pills {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.type-pill {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.4rem 0.9rem;
		background: rgba(254, 226, 226, 0.7);
		border: 1px solid rgba(252, 165, 165, 0.6);
		border-radius: 999px;
		font-size: 0.8rem;
		font-family: inherit;
		cursor: pointer;
		transition: background 0.15s, border-color 0.15s, transform 0.1s;
	}
	.type-pill:hover {
		background: rgba(254, 202, 202, 0.9);
		transform: translateY(-1px);
	}
	.type-pill.active {
		background: linear-gradient(135deg, #ef4444, #dc2626);
		border-color: #dc2626;
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.35);
	}
	.type-pill.active .pill-name {
		color: #fff;
	}
	.type-pill.active .pill-count {
		background: #fff;
		color: #b91c1c;
	}
	.pill-name {
		color: #991b1b;
		font-weight: 600;
	}
	.pill-count {
		background: #dc2626;
		color: #fff;
		border-radius: 999px;
		padding: 0.1rem 0.5rem;
		font-size: 0.75rem;
		font-weight: 700;
	}

	.content-split {
		display: flex;
		gap: 1rem;
		align-items: flex-start;
	}

	.table-column {
		flex: 0 0 70%;
		max-width: 70%;
		min-width: 0;
	}

	.cashier-column {
		flex: 0 0 30%;
		max-width: 30%;
		min-width: 0;
	}

	.cashier-card-list {
		display: flex;
		flex-direction: column;
		gap: 0.6rem;
		max-height: 560px;
		overflow-y: auto;
	}

	.cashier-mini-card {
		padding: 0.6rem 0.8rem;
		background: rgba(254, 226, 226, 0.5);
		border: 1px solid rgba(252, 165, 165, 0.6);
		border-radius: 12px;
		cursor: pointer;
		transition: background 0.15s, border-color 0.15s, transform 0.1s;
	}
	.cashier-mini-card:hover {
		background: rgba(254, 202, 202, 0.75);
		transform: translateY(-1px);
	}
	.cashier-mini-card.active {
		background: linear-gradient(135deg, #ef4444, #dc2626);
		border-color: #dc2626;
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.35);
	}
	.cashier-mini-card.active .cashier-mini-name,
	.cashier-mini-card.active .cashier-mini-amount {
		color: #fff;
	}

	.cashier-mini-name {
		font-weight: 700;
		font-size: 0.85rem;
		color: #7f1d1d;
		margin-bottom: 0.25rem;
	}

	.cashier-mini-stats {
		display: flex;
		align-items: center;
		justify-content: flex-end;
	}

	.cashier-mini-amount {
		font-size: 0.9rem;
		font-weight: 700;
		color: #991b1b;
	}

	.table-wrapper {
		overflow-x: auto;
		border-radius: 12px;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.82rem;
	}

	thead th {
		text-align: left;
		padding: 0.55rem 0.7rem;
		background: rgba(254, 226, 226, 0.6);
		color: #991b1b;
		font-weight: 700;
		text-transform: uppercase;
		font-size: 0.68rem;
		letter-spacing: 0.3px;
		position: sticky;
		top: 0;
	}

	tbody tr.group-row {
		cursor: pointer;
		transition: background 0.15s;
	}
	tbody tr.group-row:hover {
		background: rgba(254, 226, 226, 0.4);
	}
	tbody tr.detail-row {
		background: rgba(255, 255, 255, 0.3);
	}

	tbody td {
		padding: 0.5rem 0.7rem;
		border-bottom: 1px solid rgba(254, 202, 202, 0.4);
		color: #7f1d1d;
	}

	.expand-cell {
		width: 24px;
		color: #dc2626;
		font-size: 0.7rem;
	}

	.product-name {
		font-style: italic;
		color: #991b1b;
		opacity: 0.85;
	}

	.amount-cell {
		font-weight: 700;
		text-align: right;
	}

	.type-badge {
		padding: 0.15rem 0.55rem;
		border-radius: 999px;
		font-size: 0.72rem;
		font-weight: 700;
	}
	.type-badge.cancel {
		background: rgba(220, 38, 38, 0.15);
		color: #b91c1c;
	}
	.type-badge.void {
		background: rgba(251, 146, 60, 0.18);
		color: #c2410c;
	}
	.type-badge.generic {
		background: rgba(100, 116, 139, 0.15);
		color: #475569;
	}

	.empty-state {
		text-align: center;
		padding: 2rem;
		color: #b91c1c;
		opacity: 0.7;
		font-size: 0.9rem;
		background: rgba(255, 255, 255, 0.4);
		border-radius: 16px;
		border: 1px dashed rgba(252, 165, 165, 0.6);
	}
</style>
