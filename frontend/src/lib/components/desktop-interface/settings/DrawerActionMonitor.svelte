<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';

	interface BranchOption {
		id: number;
		name_en: string;
	}

	interface FlaggedEvent {
		id: number;
		branch_id: number;
		branch_name: string;
		counter_name: string;
		event_type: string;
		event_time: string;
		byte_size: number | null;
		user_name: string | null;
		document_name: string | null;
		printer_name: string | null;
		erp_counter_id: number | null;
		is_small_print: boolean;
		matched_action_name: string | null;
		matched_voucher_number: string | null;
		matched_user_name: string | null;
		seconds_to_match: number | null;
		is_flagged: boolean;
	}

	// User Actions tab — same shape/derivation as the live User Action Reports window,
	// but sourced from Supabase's synced erp_user_actions / erp_void_items tables.
	interface UAEntry {
		time: string;
		counter: string;
		actor: string;
		authorizedBy: string | null;
		kind: string;
		detail: string;
		amount: number | null;
		isItemLevel: boolean;
	}

	const FRIENDLY_ACTION_NAMES: Record<string, string> = {
		PriceChang: 'Price Change',
		'BTI Pendin': 'BTI Pending',
		'BTI Accept': 'BTI Accepted',
		'Cheque Pri': 'Cheque Print',
		'PDT Trans': 'Product Transaction'
	};

	const ITEM_LEVEL_KINDS = new Set(['Remove a row from list', 'Void selected item', 'Cancel selected product list']);

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

	function deriveKind(actionName: string, actionPerformed: string | null | undefined, actionForm: string | null | undefined): string {
		if (actionName === 'Authorize') return deriveAuthorizeKind(actionPerformed, actionForm);
		return FRIENDLY_ACTION_NAMES[actionName] || actionName;
	}

	let activeTab: 'useractions' | 'flagger' | 'livecheck' | 'syncstatus' | 'erpcounters' = 'useractions';

	let branches: BranchOption[] = [];
	let selectedBranchId: number | null = null; // null = all branches
	let loadingBranches = true;

	// Default to the latest 2 days — user can widen/narrow as needed.
	const today = new Date().toISOString().split('T')[0];
	const twoDaysAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
	let dateFrom = twoDaysAgo;
	let dateTo = today;
	let reportTimeFrom = ''; // optional HH:MM, narrows the date range down to a specific window each day
	let reportTimeTo = ''; // optional HH:MM

	let events: FlaggedEvent[] = [];
	let loading = false;
	let hasRun = false;
	let errorMessage = '';
	// Total ERP Print actions recorded for this branch/date/time window — independent of whether
	// each one matched a local event, so it can be compared directly against Print Count (local)
	// to catch a sync/matching problem rather than a genuine drop in prints.
	let erpPrintActionCount: number | null = null;
	// Of those ERP Print actions, how many have NO corresponding local spooler event — the reverse
	// direction of "Flagged (No Match)" below, which only flags local events missing an ERP match.
	let erpUnmatchedCount: number | null = null;

	let selectedStatus: 'flagged' | 'matched' | null = null;
	let selectedCounter: string | null = null;

	// Time window applies before the status/counter pill filters, so flagged/matched counts,
	// the counter breakdown, and the table all recompute against the narrowed window too.
	$: timeFilteredEvents = events.filter(
		(e) =>
			(!reportTimeFrom || timeOfDay(e.event_time) >= reportTimeFrom) &&
			(!reportTimeTo || timeOfDay(e.event_time) <= reportTimeTo)
	);

	$: statusPills = [
		{ status: 'flagged' as const, label: '🚨 Flagged (No Match)', count: timeFilteredEvents.filter((e) => e.is_flagged).length },
		{ status: 'matched' as const, label: '✅ Matched', count: timeFilteredEvents.filter((e) => !e.is_flagged).length }
	];

	$: filteredEvents = timeFilteredEvents.filter(
		(e) =>
			(!selectedStatus || (selectedStatus === 'flagged' ? e.is_flagged : !e.is_flagged)) &&
			(!selectedCounter || (e.printer_name || e.counter_name || 'Unknown') === selectedCounter)
	);

	$: counterBreakdown = Array.from(
		filteredEvents
			.reduce((map, e) => {
				const key = e.printer_name || e.counter_name || 'Unknown';
				const entry = map.get(key) || { name: key, total: 0, flagged: 0 };
				entry.total += 1;
				if (e.is_flagged) entry.flagged += 1;
				map.set(key, entry);
				return map;
			}, new Map<string, { name: string; total: number; flagged: number }>())
			.values()
	).sort((a, b) => b.flagged - a.flagged || b.total - a.total);

	$: totalEvents = filteredEvents.length; // local spooler-captured print/drawer events
	$: flaggedCount = filteredEvents.filter((e) => e.is_flagged).length;
	$: flagRate = totalEvents > 0 ? ((flaggedCount / totalEvents) * 100).toFixed(1) : '0.0';

	// --- Standalone "Drawer Flagger" quick-check widget — its own date + run button,
	// independent of the main report above (always runs flagged-only, for one day). ---
	let flaggerDate = today;
	let flaggerTimeFrom = ''; // optional HH:MM, narrows the day down to a specific window
	let flaggerTimeTo = ''; // optional HH:MM
	let flaggerLoading = false;
	let flaggerHasRun = false;
	let flaggerError = '';
	let flaggerResults: FlaggedEvent[] = [];
	// erp_counter_id only identifies the till, not its human-readable name — and the name
	// alone isn't reliably unique either (two counters have been seen sharing the name
	// "Primary" on the same branch). Rather than resolving this live over the branch's
	// tunnel on every flagger run (slow, and blank whenever that branch's tunnel happens to
	// be down), it's looked up from `erp_counters` — a Supabase table pre-populated by the
	// "Sync ERP Counters" button on the ERP Counters tab (see syncErpCounters()), which also
	// carries each counter's last-seen SystemName (Windows hostname) as the actual per-PC
	// identifier — so both still show even with the tunnel offline. Keyed "branchId:counterId".
	interface CounterInfo {
		name: string;
		systemName: string | null;
	}
	let flaggerCounterNames = new Map<string, CounterInfo>();
	// Same lookup, kept separate for the main report table below (independent branch/date scope).
	let reportCounterNames = new Map<string, CounterInfo>();

	// Takes the map explicitly (rather than closing over the module-level variable) so Svelte's
	// template dependency tracking — which only sees identifiers referenced directly in the
	// markup expression, not ones read inside the function body — re-runs this once the
	// async lookup below resolves and reassigns the map.
	function posCounterLabel(e: FlaggedEvent, counterNames: Map<string, CounterInfo>): string {
		if (e.erp_counter_id == null) return '-';
		const info = counterNames.get(`${e.branch_id}:${e.erp_counter_id}`);
		if (!info) return `Counter ${e.erp_counter_id} (not synced)`;
		return info.systemName ? `${info.name} (${info.systemName})` : info.name;
	}

	async function loadCounterNamesFor(rows: FlaggedEvent[]): Promise<Map<string, CounterInfo>> {
		const branchIds = Array.from(new Set(rows.map((e) => e.branch_id).filter((id) => id != null)));
		if (branchIds.length === 0) return new Map();
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('erp_counters')
				.select('branch_id, counter_id, counter_name, system_name')
				.in('branch_id', branchIds);
			if (error) throw error;
			const counterNameMap = new Map<string, CounterInfo>();
			for (const r of data || []) {
				counterNameMap.set(`${r.branch_id}:${r.counter_id}`, { name: r.counter_name, systemName: r.system_name });
			}
			return counterNameMap;
		} catch (err) {
			console.error('Error loading synced POS counter names:', err);
			return new Map();
		}
	}

	async function runFlagger() {
		flaggerLoading = true;
		flaggerError = '';
		flaggerResults = [];
		flaggerCounterNames = new Map();
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase.rpc('get_flagged_drawer_events', {
				p_branch_id: selectedBranchId,
				p_date_from: flaggerDate,
				p_date_to: flaggerDate,
				p_flagged_only: true
			});
			if (error) throw error;
			let results: FlaggedEvent[] = data || [];
			// Optional HH:MM narrowing within the picked day — the RPC itself is date-only, so this
			// trims to a specific window client-side (same digit-extraction as formatTime, to compare
			// against the event's recorded wall-clock time rather than a browser-shifted one).
			if (flaggerTimeFrom) results = results.filter((e) => timeOfDay(e.event_time) >= flaggerTimeFrom);
			if (flaggerTimeTo) results = results.filter((e) => timeOfDay(e.event_time) <= flaggerTimeTo);
			flaggerResults = results;
			// Reads from the erp_counters cache table — no tunnel call here, so this still
			// works when a branch's tunnel is offline (see loadCounterNamesFor above).
			flaggerCounterNames = await loadCounterNamesFor(flaggerResults);
		} catch (err: any) {
			console.error('Error running flagger:', err);
			flaggerError = err.message || 'Failed to run flagger';
		} finally {
			flaggerLoading = false;
			flaggerHasRun = true;
		}
	}

	// --- Live ERP Check tab — re-verifies flagged events against a LIVE query of the branch's
	// own SQL Server (via tunnel), instead of the Supabase-synced copy which lags behind by
	// whatever the Auto Sync interval is. Only checks for a matching 'Print' UserActions row
	// near each flagged event's time (the same signal the Supabase-side RPC uses).
	interface ErpConnection {
		branch_id: number;
		tunnel_url: string;
		erp_branch_id: number;
	}

	interface LiveCheckResult {
		event: FlaggedEvent;
		liveMatchFound: boolean;
		liveMatchCount: number;
		liveVoucherNumber: string | null;
		liveUserName: string | null;
		liveSecondsDiff: number | null;
	}

	const LIVE_MATCH_QUERY_PAD_SECONDS = 120;

	let erpConnections: ErpConnection[] = [];
	let lcSelectedBranchId: number | null = null;
	let lcDate = today;
	let lcTimeFrom = ''; // optional HH:MM, narrows the day down to a specific window
	let lcTimeTo = ''; // optional HH:MM
	let lcLoading = false;
	let lcHasRun = false;
	let lcError = '';
	let lcResults: LiveCheckResult[] = [];

	async function loadErpConnections() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('erp_connections')
				.select('branch_id, tunnel_url, erp_branch_id')
				.eq('is_active', true);
			if (error) throw error;
			erpConnections = (data || []).filter((c: any) => c.tunnel_url);
			if (erpConnections.length > 0 && !lcSelectedBranchId) {
				lcSelectedBranchId = erpConnections[0].branch_id;
			}
		} catch (err: any) {
			console.error('Error loading ERP connections:', err);
		}
	}

	async function runLiveErpQuery(sql: string, tunnelUrl: string): Promise<any[]> {
		const response = await fetch('/api/erp-products', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ action: 'query', tunnelUrl, sql })
		});
		const data = await response.json();
		if (!data.success) throw new Error(data.error || 'Live ERP query failed');
		return data.recordset || [];
	}

	async function runLiveCheck() {
		lcError = '';
		lcResults = [];
		if (!lcSelectedBranchId) {
			lcError = "Pick a specific branch — live ERP check needs a single branch's SQL Server connection.";
			lcHasRun = true;
			return;
		}
		const conn = erpConnections.find((c) => c.branch_id === lcSelectedBranchId);
		if (!conn) {
			lcError = 'No ERP connection/tunnel configured for this branch.';
			lcHasRun = true;
			return;
		}

		lcLoading = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data: flagged, error } = await supabase.rpc('get_flagged_drawer_events', {
				p_branch_id: lcSelectedBranchId,
				p_date_from: lcDate,
				p_date_to: lcDate,
				p_flagged_only: true
			});
			if (error) throw error;
			let flaggedEvents: FlaggedEvent[] = flagged || [];

			// Optional HH:MM narrowing within the picked day — the RPC itself is date-only, so this
			// trims to a specific window client-side (same digit-extraction approach as formatTime,
			// to compare against the event's recorded wall-clock time rather than a browser-shifted one).
			if (lcTimeFrom) flaggedEvents = flaggedEvents.filter((e) => timeOfDay(e.event_time) >= lcTimeFrom);
			if (lcTimeTo) flaggedEvents = flaggedEvents.filter((e) => timeOfDay(e.event_time) <= lcTimeTo);

			if (flaggedEvents.length === 0) {
				lcResults = [];
				return;
			}

			// One padded-window query covers every flagged event's time in a single round trip;
			// matching against each event happens client-side afterward.
			const times = flaggedEvents.map((e) => new Date(e.event_time).getTime());
			const padMs = LIVE_MATCH_QUERY_PAD_SECONDS * 1000;
			const minTime = new Date(Math.min(...times) - padMs).toISOString().slice(0, 19).replace('T', ' ');
			const maxTime = new Date(Math.max(...times) + padMs).toISOString().slice(0, 19).replace('T', ' ');
			const erpBranchId = conn.erp_branch_id;

			// Pull CounterID alongside so matching can be scoped to the SAME counter when a
			// flagged event has one recorded (falls back to branch-wide time-only matching
			// for events captured before the till's counter was configured).
			const sql = `
				SELECT ua.DateTimeOfAction, ua.VoucherNumber, ua.CounterID, u.UserName
				FROM UserActions ua
				LEFT JOIN Users u ON u.UserID = ua.UserID AND u.BranchID = ${erpBranchId}
				WHERE ua.BranchID = ${erpBranchId} AND ua.ActionName = 'Print'
				  AND ua.DateTimeOfAction BETWEEN '${minTime}' AND '${maxTime}'
				ORDER BY ua.DateTimeOfAction ASC
			`;
			const livePrints = await runLiveErpQuery(sql, conn.tunnel_url);

			lcResults = flaggedEvents.map((e) => {
				const eventMs = new Date(e.event_time).getTime();
				// Match is purely on COUNT of Print actions for the same counter, within the query's
				// padded window — no per-event time tolerance is applied. Counter-scoped when the
				// flagged event has an erp_counter_id recorded, else falls back branch-wide.
				const matches = livePrints.filter(
					(p: any) => e.erp_counter_id == null || p.CounterID === e.erp_counter_id
				);
				// Closest-in-time match is still picked out of that count, for display only
				// (voucher/user/time-diff columns) — it does not affect the match/no-match verdict.
				let closest: any = null;
				let closestDiffSec: number | null = null;
				for (const p of matches) {
					const diffSec = Math.abs(new Date(p.DateTimeOfAction).getTime() - eventMs) / 1000;
					if (closest === null || diffSec < closestDiffSec!) {
						closest = p;
						closestDiffSec = diffSec;
					}
				}
				return {
					event: e,
					liveMatchFound: matches.length > 0,
					liveMatchCount: matches.length,
					liveVoucherNumber: closest?.VoucherNumber ? String(closest.VoucherNumber) : null,
					liveUserName: closest?.UserName || null,
					liveSecondsDiff: closest ? closestDiffSec : null
				};
			});
		} catch (err: any) {
			console.error('Error running live ERP check:', err);
			lcError = err.message || 'Failed to run live ERP check';
		} finally {
			lcLoading = false;
			lcHasRun = true;
		}
	}

	onMount(async () => {
		await loadBranches();
		await loadErpConnections();
		await loadErpCountersTable();
	});

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en')
				.eq('is_active', true)
				.order('name_en');
			if (error) throw error;
			branches = data || [];
		} catch (err: any) {
			console.error('Error loading branches:', err);
			errorMessage = err.message || 'Failed to load branches';
		} finally {
			loadingBranches = false;
		}
	}

	// --- User Actions tab (Supabase-sourced, mirrors the live User Action Reports window) ---
	let uaSelectedBranchId: number | null = null; // null = all branches
	let uaDateFrom = twoDaysAgo;
	let uaDateTo = today;
	let uaEntries: UAEntry[] = [];
	let uaLoading = false;
	let uaHasRun = false;
	let uaError = '';
	let uaExpandedGroups = new Set<string>();
	let uaSelectedKind: string | null = null;
	let uaSelectedCashier: string | null = null;

	$: uaCashierOptions = Array.from(new Set(uaEntries.map((r) => r.actor).filter(Boolean))).sort();

	$: uaCashierScopedEntries = uaSelectedCashier ? uaEntries.filter((r) => r.actor === uaSelectedCashier) : uaEntries;
	$: uaSummaryRows = Array.from(
		uaCashierScopedEntries.reduce((map, r) => map.set(r.kind, (map.get(r.kind) || 0) + 1), new Map<string, number>()).entries()
	).map(([Kind, Cnt]) => ({ Kind, Cnt })).sort((a, b) => b.Cnt - a.Cnt);

	$: if (uaSelectedKind && !uaSummaryRows.some((r) => r.Kind === uaSelectedKind)) {
		uaSelectedKind = null;
	}

	$: uaFilteredEntries = uaEntries.filter(
		(r) => (!uaSelectedKind || r.kind === uaSelectedKind) && (!uaSelectedCashier || r.actor === uaSelectedCashier)
	);

	$: uaGroupedRows = groupByEvent(uaFilteredEntries);

	$: uaCashierBreakdown = Array.from(
		uaFilteredEntries.reduce((map, r) => {
			const key = r.actor || 'Unknown';
			const entry = map.get(key) || { name: key, items: 0, total: 0 };
			entry.items += 1;
			entry.total += r.amount || 0;
			map.set(key, entry);
			return map;
		}, new Map<string, { name: string; items: number; total: number }>()).values()
	).sort((a, b) => (b.total - a.total) || (b.items - a.items));

	function groupByEvent(rows: UAEntry[]) {
		const groups = new Map<string, UAEntry[]>();
		for (const row of rows) {
			const secondBucket = (row.time || '').slice(0, 19);
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

	function toggleUAGroup(key: string) {
		if (uaExpandedGroups.has(key)) uaExpandedGroups.delete(key);
		else uaExpandedGroups.add(key);
		uaExpandedGroups = uaExpandedGroups;
	}

	$: uaTotalItems = uaFilteredEntries.length;
	$: uaTotalAmount = uaFilteredEntries.reduce((sum, r) => sum + (r.amount || 0), 0);
	$: uaCancelAmount = uaFilteredEntries.filter((r) => r.kind === 'Cancel selected product list').reduce((sum, r) => sum + (r.amount || 0), 0);
	$: uaVoidAmount = uaFilteredEntries.filter((r) => r.kind === 'Void selected item' || r.kind === 'Remove a row from list').reduce((sum, r) => sum + (r.amount || 0), 0);
	$: uaTopCashier = topBy(uaFilteredEntries, 'actor');
	$: uaTopAuthorizer = topBy(uaFilteredEntries.filter((r) => r.authorizedBy), 'authorizedBy');

	function topBy(rows: UAEntry[], field: 'actor' | 'authorizedBy') {
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

	async function loadUserActionsReport() {
		uaLoading = true;
		uaError = '';
		uaEntries = [];
		uaExpandedGroups = new Set();
		uaSelectedKind = null;
		uaSelectedCashier = null;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const dateToExclusive = new Date(new Date(uaDateTo).getTime() + 24 * 60 * 60 * 1000).toISOString().split('T')[0];

			let actionsQuery = supabase
				.from('erp_user_actions')
				.select('counter_id, user_name, action_name, action_form, action_performed, voucher_number, date_time_of_action')
				.gte('date_time_of_action', uaDateFrom)
				.lt('date_time_of_action', dateToExclusive)
				.order('date_time_of_action', { ascending: false })
				.limit(5000);
			if (uaSelectedBranchId) actionsQuery = actionsQuery.eq('branch_id', uaSelectedBranchId);

			let voidsQuery = supabase
				.from('erp_void_items')
				.select('counter_id, user_name, product_name, total, created_date, transaction_date')
				.gte('transaction_date', uaDateFrom)
				.lte('transaction_date', uaDateTo)
				.order('created_date', { ascending: false })
				.limit(5000);
			if (uaSelectedBranchId) voidsQuery = voidsQuery.eq('branch_id', uaSelectedBranchId);

			const [{ data: actions, error: actionsErr }, { data: voids, error: voidsErr }] = await Promise.all([actionsQuery, voidsQuery]);
			if (actionsErr) throw actionsErr;
			if (voidsErr) throw voidsErr;

			// Correlate each void item with the nearest same-counter Authorize action within ±5s
			// (client-side equivalent of the live report's SQL OUTER APPLY nearest-timestamp join).
			const authorizeActions = (actions || []).filter((a: any) => a.action_name === 'Authorize');
			const itemEntries: UAEntry[] = (voids || []).map((v: any) => {
				const voidTime = new Date(v.created_date).getTime();
				let best: any = null;
				let bestDiff = 5000;
				for (const a of authorizeActions) {
					if (a.counter_id !== v.counter_id) continue;
					const diff = Math.abs(new Date(a.date_time_of_action).getTime() - voidTime);
					if (diff <= bestDiff) {
						best = a;
						bestDiff = diff;
					}
				}
				return {
					time: v.created_date,
					counter: String(v.counter_id ?? '-'),
					actor: v.user_name,
					authorizedBy: best ? best.user_name : null,
					kind: deriveAuthorizeKind(best ? best.action_performed : null, null),
					detail: v.product_name,
					amount: v.total,
					isItemLevel: true
				};
			});

			const genericEntries: UAEntry[] = (actions || [])
				.map((a: any) => ({
					time: a.date_time_of_action,
					counter: String(a.counter_id ?? '-'),
					kind: deriveKind(a.action_name, a.action_performed, a.action_form),
					isAuthorize: a.action_name === 'Authorize',
					userName: a.user_name,
					detail: a.action_performed || (a.voucher_number ? `Voucher: ${a.voucher_number}` : '-')
				}))
				.filter((a: any) => !ITEM_LEVEL_KINDS.has(a.kind))
				.map((a: any) => ({
					time: a.time,
					counter: a.counter,
					actor: a.isAuthorize ? '-' : a.userName,
					authorizedBy: a.isAuthorize ? a.userName : null,
					kind: a.kind,
					detail: a.detail,
					amount: null,
					isItemLevel: false
				}));

			uaEntries = [...itemEntries, ...genericEntries];
		} catch (err: any) {
			console.error('Error loading Supabase user actions report:', err);
			uaError = err.message || 'Failed to load report';
		} finally {
			uaLoading = false;
			uaHasRun = true;
		}
	}

	function formatAmount(n: number): string {
		return (n || 0).toFixed(2);
	}

	function truncate(text: string, max = 80): string {
		if (!text) return '-';
		return text.length > max ? text.slice(0, max) + '…' : text;
	}

	async function loadReport() {
		loading = true;
		errorMessage = '';
		events = [];
		reportCounterNames = new Map();
		selectedStatus = null;
		selectedCounter = null;
		erpPrintActionCount = null;
		erpUnmatchedCount = null;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase.rpc('get_flagged_drawer_events', {
				p_branch_id: selectedBranchId,
				p_date_from: dateFrom,
				p_date_to: dateTo,
				p_flagged_only: false
			});
			if (error) throw error;
			events = data || [];
			// Reads from the erp_counters cache table — no tunnel call here (see loadCounterNamesFor).
			reportCounterNames = await loadCounterNamesFor(events);

			// Total ERP Print actions for the same branch/date range, from the synced erp_user_actions
			// table — this is every Print the ERP logged, not just the ones a local event matched to.
			const dateToExclusive = new Date(new Date(dateTo).getTime() + 24 * 60 * 60 * 1000).toISOString().split('T')[0];
			let printQuery = supabase
				.from('erp_user_actions')
				.select('date_time_of_action, voucher_number')
				.eq('action_name', 'Print')
				.gte('date_time_of_action', dateFrom)
				.lt('date_time_of_action', dateToExclusive)
				.limit(20000);
			if (selectedBranchId) printQuery = printQuery.eq('branch_id', selectedBranchId);
			const { data: printRows, error: printErr } = await printQuery;
			if (printErr) throw printErr;
			// Same optional HH:MM narrowing as the local events, so the two counts stay comparable.
			const filteredPrintRows = (printRows || []).filter(
				(r: any) =>
					(!reportTimeFrom || timeOfDay(r.date_time_of_action) >= reportTimeFrom) &&
					(!reportTimeTo || timeOfDay(r.date_time_of_action) <= reportTimeTo)
			);
			erpPrintActionCount = filteredPrintRows.length;

			// Reverse match: a local event's matched_voucher_number (set only when the RPC found an
			// ERP match for it) tells us which vouchers ARE accounted for locally. Any ERP print row
			// whose voucher isn't in that set has no local spooler capture — flag it the other way.
			const timeFilteredLocalEvents = events.filter(
				(e) =>
					(!reportTimeFrom || timeOfDay(e.event_time) >= reportTimeFrom) &&
					(!reportTimeTo || timeOfDay(e.event_time) <= reportTimeTo)
			);
			const matchedVouchers = new Set(
				timeFilteredLocalEvents
					.filter((e) => !e.is_flagged && e.matched_voucher_number)
					.map((e) => String(e.matched_voucher_number))
			);
			erpUnmatchedCount = filteredPrintRows.filter((r: any) => !matchedVouchers.has(String(r.voucher_number))).length;
		} catch (err: any) {
			console.error('Error loading flagged drawer events:', err);
			errorMessage = err.message || 'Failed to load report';
		} finally {
			loading = false;
			hasRun = true;
		}
	}

	// Same parsing approach as the live User Action Reports window — parse the ISO digits
	// directly instead of `new Date().toLocaleString()`, which can re-shift by the browser's
	// timezone. Includes the year, since dates can span more than the current year.
	function formatTime(iso: string): string {
		const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/.exec(iso || '');
		if (!match) return iso;
		const [, year, month, day, hour, minute, second] = match;
		const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
		const h = parseInt(hour, 10);
		const ampm = h >= 12 ? 'PM' : 'AM';
		const h12 = h % 12 === 0 ? 12 : h % 12;
		return `${monthNames[parseInt(month, 10) - 1]} ${parseInt(day, 10)}, ${year} ${String(h12).padStart(2, '0')}:${minute}:${second} ${ampm}`;
	}

	// HH:MM extracted the same digit-parsing way as formatTime, for comparing against
	// the lcTimeFrom/lcTimeTo inputs without a browser-timezone re-shift.
	function timeOfDay(iso: string): string {
		const match = /T(\d{2}):(\d{2})/.exec(iso || '');
		return match ? `${match[1]}:${match[2]}` : '';
	}

	function formatSeconds(n: number | null): string {
		if (n === null || n === undefined) return '-';
		return `${Math.abs(n).toFixed(1)}s`;
	}

	function formatBytes(n: number | null): string {
		if (n === null || n === undefined) return '-';
		if (n < 1024) return `${n} B`;
		if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
		return `${(n / (1024 * 1024)).toFixed(1)} MB`;
	}

	// --- App Sync Status tab ---
	interface SyncAppStatus {
		device_id: string;
		branch_id: number | null;
		branch_name: string | null;
		mode: string | null;
		app_version: string | null;
		hostname: string | null;
		ip_address: string | null;
		sync_status: string | null;
		last_sync_at: string | null;
		last_error: string | null;
		counter_name: string | null;
		counter_id: number | null;
		heartbeat_at: string;
		created_at: string;
		is_online: boolean;
		is_flagged: boolean;
		minutes_since_heartbeat: number;
	}

	let syncStatuses: SyncAppStatus[] = [];
	let syncStatusLoading = false;
	let syncStatusError = '';

	async function loadSyncStatuses() {
		syncStatusLoading = true;
		syncStatusError = '';
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase.rpc('get_sync_app_statuses');
			if (error) throw error;
			syncStatuses = data || [];
		} catch (err: any) {
			syncStatusError = err.message || 'Failed to load sync statuses';
		} finally {
			syncStatusLoading = false;
		}
	}

	function formatMinutes(mins: number): string {
		if (mins < 1) return 'just now';
		if (mins < 60) return `${Math.round(mins)}m ago`;
		const h = Math.floor(mins / 60);
		const m = Math.round(mins % 60);
		return `${h}h ${m}m ago`;
	}

	// --- ERP Counters sync (ERP Counters tab) ---
	// "🔄 Sync ERP Counters" action: pulls CounterID/CounterName from every connected branch's
	// live SQL Server (via tunnel) and upserts them into `erp_counters`. Counter *names* aren't
	// reliably unique on their own (e.g. two counters both named "Primary" have been seen on the
	// same branch) — so this also pulls each counter's most-recently-seen SystemName (the Windows
	// hostname, logged on every UserActions row) as the actual per-PC identifier.
	// The Flagger tab then reads both from this cached table instead of the tunnel, so it keeps
	// showing them even when a branch's tunnel is offline.
	interface ErpCounterRow {
		branch_id: number;
		counter_id: number;
		counter_name: string;
		system_name: string | null;
		synced_at: string;
	}

	let erpCounters: ErpCounterRow[] = [];
	let counterSyncLoading = false;
	let counterSyncError = '';
	let counterSyncSummary = '';

	function branchNameFor(branchId: number): string {
		return branches.find((b) => b.id === branchId)?.name_en || `Branch ${branchId}`;
	}

	async function loadErpCountersTable() {
		const { supabase } = await import('$lib/utils/supabase');
		const { data, error } = await supabase
			.from('erp_counters')
			.select('branch_id, counter_id, counter_name, system_name, synced_at')
			.order('branch_id')
			.order('counter_id');
		if (error) {
			console.error('Error loading erp_counters:', error);
			return;
		}
		erpCounters = data || [];
	}

	async function syncErpCounters() {
		counterSyncLoading = true;
		counterSyncError = '';
		counterSyncSummary = '';
		try {
			const { supabase } = await import('$lib/utils/supabase');
			if (erpConnections.length === 0) await loadErpConnections();
			if (erpConnections.length === 0) {
				counterSyncError = 'No active ERP tunnel connections configured for any branch.';
				return;
			}

			let totalSynced = 0;
			const failedBranches: string[] = [];
			for (const conn of erpConnections) {
				try {
					const counterSql = `SELECT CounterID, CounterName FROM Counter WHERE BranchID = ${conn.erp_branch_id}`;
					// Most-recent non-blank SystemName per counter, from the last 60 days of activity —
					// bounded so this stays a fast indexed-range scan rather than a full table scan.
					const systemNameSql = `
						SELECT CounterID, SystemName FROM (
							SELECT CounterID, SystemName,
								ROW_NUMBER() OVER (PARTITION BY CounterID ORDER BY DateTimeOfAction DESC) AS rn
							FROM UserActions
							WHERE BranchID = ${conn.erp_branch_id}
							  AND SystemName IS NOT NULL AND SystemName <> ''
							  AND DateTimeOfAction >= DATEADD(day, -60, GETDATE())
						) recent WHERE rn = 1
					`;
					const [rows, systemNameRows] = await Promise.all([
						runLiveErpQuery(counterSql, conn.tunnel_url),
						runLiveErpQuery(systemNameSql, conn.tunnel_url)
					]);
					if (rows.length === 0) continue;
					const systemNameByCounter = new Map<number, string>();
					for (const r of systemNameRows) systemNameByCounter.set(r.CounterID, r.SystemName);

					const syncedAt = new Date().toISOString();
					const upsertRows = rows.map((r: any) => ({
						branch_id: conn.branch_id,
						erp_branch_id: conn.erp_branch_id,
						counter_id: r.CounterID,
						counter_name: r.CounterName,
						system_name: systemNameByCounter.get(r.CounterID) || null,
						synced_at: syncedAt
					}));
					const { error } = await supabase.from('erp_counters').upsert(upsertRows, { onConflict: 'branch_id,counter_id' });
					if (error) throw error;
					totalSynced += upsertRows.length;
				} catch (err: any) {
					console.error(`Error syncing counters for branch ${conn.branch_id}:`, err);
					failedBranches.push(branchNameFor(conn.branch_id));
				}
			}

			const okBranches = erpConnections.length - failedBranches.length;
			counterSyncSummary = `✅ Synced ${totalSynced} counter${totalSynced === 1 ? '' : 's'} across ${okBranches} branch${okBranches === 1 ? '' : 'es'}.`;
			if (failedBranches.length > 0) {
				counterSyncError = `⚠️ Tunnel unreachable for: ${failedBranches.join(', ')} — their counter names weren't refreshed.`;
			}
			await loadErpCountersTable();
		} finally {
			counterSyncLoading = false;
		}
	}
</script>

<div class="drawer-monitor">
	<div class="bg-blob blob-1"></div>
	<div class="bg-blob blob-2"></div>

	<div class="header">
		<div class="header-left">
			<span class="header-icon">🚨</span>
			<div>
				<h2 class="header-title">{t('nav.drawerActionMonitor') || 'Drawer Action Monitor'}</h2>
				<p class="header-subtitle">User actions &amp; cash-drawer events — live from Supabase, synced from Aqura Action Sync</p>
			</div>
		</div>
	</div>

	<div class="tab-bar">
		<button class="tab-btn" class:active={activeTab === 'useractions'} on:click={() => (activeTab = 'useractions')}>👤 User Actions</button>
		<button class="tab-btn" class:active={activeTab === 'flagger'} on:click={() => (activeTab = 'flagger')}>🚩 Flagger</button>
		<button class="tab-btn" class:active={activeTab === 'livecheck'} on:click={() => (activeTab = 'livecheck')}>🔴 Live ERP Check</button>
		<button class="tab-btn" class:active={activeTab === 'syncstatus'} on:click={() => { activeTab = 'syncstatus'; loadSyncStatuses(); }}>📡 App Sync Status</button>
		<button class="tab-btn" class:active={activeTab === 'erpcounters'} on:click={() => { activeTab = 'erpcounters'; loadErpCountersTable(); }}>🔢 ERP Counters</button>
	</div>

	{#if activeTab === 'useractions'}
	<div class="filters-panel">
		<div class="filter-field">
			<label for="ua-branch-select">Branch</label>
			<select id="ua-branch-select" bind:value={uaSelectedBranchId} disabled={loadingBranches}>
				<option value={null}>All Branches</option>
				{#each branches as b}
					<option value={b.id}>{b.name_en}</option>
				{/each}
			</select>
		</div>
		<div class="filter-field">
			<label for="ua-date-from">From</label>
			<input id="ua-date-from" type="date" bind:value={uaDateFrom} />
		</div>
		<div class="filter-field">
			<label for="ua-date-to">To</label>
			<input id="ua-date-to" type="date" bind:value={uaDateTo} />
		</div>
		<div class="filter-field">
			<label for="ua-cashier-filter">Cashier</label>
			<select id="ua-cashier-filter" bind:value={uaSelectedCashier}>
				<option value={null}>All Cashiers</option>
				{#each uaCashierOptions as name}
					<option value={name}>{name}</option>
				{/each}
			</select>
		</div>
		<button class="run-btn" on:click={loadUserActionsReport} disabled={uaLoading}>
			{uaLoading ? '⏳ Loading...' : '🔍 Run Report'}
		</button>
	</div>

	{#if uaError}
		<div class="error-banner">⚠️ {uaError}</div>
	{/if}

	{#if uaTotalItems > 0}
		<div class="summary-cards">
			<div class="summary-card">
				<div class="summary-label">Total Items</div>
				<div class="summary-value">{uaTotalItems}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Total Amount</div>
				<div class="summary-value">{formatAmount(uaTotalAmount)}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Cancel / Void</div>
				<div class="summary-value">{formatAmount(uaCancelAmount)} / {formatAmount(uaVoidAmount)}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Top User</div>
				<div class="summary-value small">{uaTopCashier.name} <span class="dim">({formatAmount(uaTopCashier.amount)})</span></div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Top Authorizer</div>
				<div class="summary-value small">{uaTopAuthorizer.name} <span class="dim">({formatAmount(uaTopAuthorizer.amount)})</span></div>
			</div>
		</div>
	{/if}

	{#if uaSummaryRows.length > 0}
		<div class="section-block">
			<div class="section-title-row">
				<h3 class="section-title">All Actions Breakdown</h3>
				{#if uaSelectedKind}
					<button class="clear-filter-btn" on:click={() => (uaSelectedKind = null)}>✕ Clear filter</button>
				{/if}
			</div>
			<div class="type-pills">
				{#each uaSummaryRows as row}
					<button class="type-pill" class:active={uaSelectedKind === row.Kind} on:click={() => (uaSelectedKind = uaSelectedKind === row.Kind ? null : row.Kind)}>
						<span class="pill-name">{row.Kind}</span>
						<span class="pill-count">{row.Cnt}</span>
					</button>
				{/each}
			</div>
		</div>
	{/if}

	{#if uaGroupedRows.length > 0}
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
							{#each uaGroupedRows as g}
								<tr class="group-row" on:click={() => toggleUAGroup(g.key)}>
									<td class="expand-cell">{uaExpandedGroups.has(g.key) ? '▼' : '▶'}</td>
									<td>{formatTime(g.time)}</td>
									<td>{g.counter || '-'}</td>
									<td>{g.actor || '-'}</td>
									<td>{g.authorizedBy || '-'}</td>
									<td><span class="type-badge" class:cancel={g.kind === 'Cancel selected product list'} class:void={g.kind === 'Void selected item' || g.kind === 'Remove a row from list'} class:generic={g.isItemLevel === false}>{g.kind}</span></td>
									<td>{g.isItemLevel ? `${g.items.length} item${g.items.length === 1 ? '' : 's'}` : truncate(g.items[0].detail)}</td>
									<td class="amount-cell">{g.isItemLevel ? formatAmount(g.total) : '-'}</td>
								</tr>
								{#if uaExpandedGroups.has(g.key)}
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
					{#each uaCashierBreakdown as c}
						<div class="cashier-mini-card" class:active={uaSelectedCashier === c.name} on:click={() => (uaSelectedCashier = uaSelectedCashier === c.name ? null : c.name)}>
							<div class="cashier-mini-name">{c.name}</div>
							<div class="cashier-mini-stats">
								<span class="cashier-mini-items">{c.items} item{c.items === 1 ? '' : 's'}</span>
								<span class="cashier-mini-amount">{formatAmount(c.total)}</span>
							</div>
						</div>
					{/each}
				</div>
			</div>
		</div>
	{:else if !uaLoading && uaHasRun && !uaError}
		<div class="empty-state">No results match the current filters — try a different cashier, type, or date range.</div>
	{:else if !uaLoading && !uaHasRun && !uaError}
		<div class="empty-state">No data yet — select a branch and date range, then click Run Report.</div>
	{/if}
	{/if}

	{#if activeTab === 'flagger'}
	<div class="filters-panel">
		<div class="filter-field">
			<label for="branch-select">Branch</label>
			<select id="branch-select" bind:value={selectedBranchId} disabled={loadingBranches}>
				<option value={null}>All Branches</option>
				{#each branches as b}
					<option value={b.id}>{b.name_en}</option>
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
			<label for="report-time-from">From time (optional)</label>
			<input id="report-time-from" type="time" bind:value={reportTimeFrom} />
		</div>
		<div class="filter-field">
			<label for="report-time-to">To time (optional)</label>
			<input id="report-time-to" type="time" bind:value={reportTimeTo} />
		</div>
		<button class="run-btn" on:click={loadReport} disabled={loading}>
			{loading ? '⏳ Loading...' : '🔍 Run Report'}
		</button>
	</div>

	{#if errorMessage}
		<div class="error-banner">⚠️ {errorMessage}</div>
	{/if}

	{#if totalEvents > 0}
		<div class="summary-cards">
			<div class="summary-card">
				<div class="summary-label">🖨️ Print Count (Local)</div>
				<div class="summary-value">{totalEvents}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">🧾 ERP Print Count</div>
				<div class="summary-value">{erpPrintActionCount ?? '-'}</div>
			</div>
			<div class="summary-card flagged">
				<div class="summary-label">🚨 Flagged (No Match)</div>
				<div class="summary-value">{flaggedCount}</div>
			</div>
			<div class="summary-card warn">
				<div class="summary-label">⚠️ ERP Unmatched (No Local Capture)</div>
				<div class="summary-value">{erpUnmatchedCount ?? '-'}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Flag Rate</div>
				<div class="summary-value">{flagRate}%</div>
			</div>
		</div>
	{/if}

	{#if events.length > 0}
		<div class="section-block">
			<div class="section-title-row">
				<h3 class="section-title">Status Breakdown</h3>
				{#if selectedStatus}
					<button class="clear-filter-btn" on:click={() => (selectedStatus = null)}>✕ Clear filter</button>
				{/if}
			</div>
			<div class="type-pills">
				{#each statusPills as p}
					<button class="type-pill" class:active={selectedStatus === p.status} on:click={() => (selectedStatus = selectedStatus === p.status ? null : p.status)}>
						<span class="pill-name">{p.label}</span>
						<span class="pill-count">{p.count}</span>
					</button>
				{/each}
			</div>
		</div>
	{/if}

	{#if filteredEvents.length > 0}
		<div class="content-split">
			<div class="table-column section-block">
				<h3 class="section-title">Event Detail</h3>
				<div class="table-wrapper">
					<table>
						<thead>
							<tr>
								<th>Status</th>
								<th>Time</th>
								<th>Branch</th>
								<th>POS Counter</th>
								<th>Printer</th>
								<th>Size</th>
								<th>User</th>
								<th>Matched Action</th>
								<th>Time Diff</th>
							</tr>
						</thead>
						<tbody>
							{#each filteredEvents as e}
								<tr class:flagged-row={e.is_flagged}>
									<td>
										{#if e.is_flagged}
											<span class="status-badge flagged">🚨 Unexplained</span>
										{:else}
											<span class="status-badge ok">✅ Matched</span>
										{/if}
									</td>
									<td>{formatTime(e.event_time)}</td>
									<td>{e.branch_name || '-'}</td>
									<td>{posCounterLabel(e, reportCounterNames)}</td>
									<td>{e.printer_name || e.counter_name || '-'}</td>
									<td>
										{formatBytes(e.byte_size)}
										{#if e.is_small_print}<span class="small-print-badge" title="Tiny print — likely a blank F3 drawer-kick slip, not a real receipt">kick?</span>{/if}
									</td>
									<td>{e.user_name || '-'}</td>
									<td>{e.matched_action_name ? `${e.matched_action_name}${e.matched_voucher_number ? ' #' + e.matched_voucher_number : ''}` : '-'}</td>
									<td>{formatSeconds(e.seconds_to_match)}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>

			<div class="cashier-column section-block">
				<h3 class="section-title">Printer Breakdown</h3>
				<div class="cashier-card-list">
					{#each counterBreakdown as c}
						<div class="cashier-mini-card" class:active={selectedCounter === c.name} on:click={() => (selectedCounter = selectedCounter === c.name ? null : c.name)}>
							<div class="cashier-mini-name">{c.name}</div>
							<div class="cashier-mini-stats">
								<span class="cashier-mini-items">{c.total} event{c.total === 1 ? '' : 's'}</span>
								<span class="cashier-mini-amount" class:flagged-text={c.flagged > 0}>{c.flagged} flagged</span>
							</div>
						</div>
					{/each}
				</div>
			</div>
		</div>
	{:else if !loading && hasRun && !errorMessage}
		<div class="empty-state">No drawer/print events match the current filters — try a different counter, status, date range, or time window.</div>
	{:else if !loading && !hasRun && !errorMessage}
		<div class="empty-state">No data yet — select a branch and date range, then click Run Report. Data populates once Aqura Action Sync (Print mode) is running on POS tills.</div>
	{/if}

	<div class="section-block flagger-block">
		<h3 class="section-title">🚩 Drawer Flagger — Quick Check</h3>
		<p class="flagger-desc">Pick a single day and run the flagger to see only unexplained drawer/print events for that day, independent of the report above.</p>
		<div class="flagger-controls">
			<div class="filter-field">
				<label for="flagger-date">Flag Date</label>
				<input id="flagger-date" type="date" bind:value={flaggerDate} />
			</div>
			<div class="filter-field">
				<label for="flagger-time-from">From time (optional)</label>
				<input id="flagger-time-from" type="time" bind:value={flaggerTimeFrom} />
			</div>
			<div class="filter-field">
				<label for="flagger-time-to">To time (optional)</label>
				<input id="flagger-time-to" type="time" bind:value={flaggerTimeTo} />
			</div>
			<button class="run-btn flagger-btn" on:click={runFlagger} disabled={flaggerLoading}>
				{flaggerLoading ? '⏳ Running...' : '🚩 Run Flagger'}
			</button>
		</div>

		{#if flaggerError}
			<div class="error-banner">⚠️ {flaggerError}</div>
		{:else if flaggerHasRun}
			{#if flaggerResults.length > 0}
				<div class="flagger-summary">🚨 {flaggerResults.length} flagged event{flaggerResults.length === 1 ? '' : 's'} found on {flaggerDate}{#if flaggerTimeFrom || flaggerTimeTo} ({flaggerTimeFrom || '00:00'}–{flaggerTimeTo || '23:59'}){/if}</div>
				<div class="table-wrapper">
					<table>
						<thead>
							<tr>
								<th>Time</th>
								<th>Branch</th>
								<th>POS Counter</th>
								<th>Printer</th>
								<th>Size</th>
								<th>User</th>
							</tr>
						</thead>
						<tbody>
							{#each flaggerResults as e}
								<tr class="flagged-row">
									<td>{formatTime(e.event_time)}</td>
									<td>{e.branch_name || '-'}</td>
									<td>{posCounterLabel(e, flaggerCounterNames)}</td>
									<td>{e.printer_name || e.counter_name || '-'}</td>
									<td>{formatBytes(e.byte_size)}{#if e.is_small_print}<span class="small-print-badge">kick?</span>{/if}</td>
									<td>{e.user_name || '-'}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div class="flagger-summary ok">✅ No unexplained events found on {flaggerDate}{#if flaggerTimeFrom || flaggerTimeTo} ({flaggerTimeFrom || '00:00'}–{flaggerTimeTo || '23:59'}){/if}.</div>
			{/if}
		{/if}
	</div>
	{/if}

	{#if activeTab === 'livecheck'}
	<div class="filters-panel">
		<div class="filter-field">
			<label for="lc-branch-select">Branch</label>
			<select id="lc-branch-select" bind:value={lcSelectedBranchId}>
				{#each branches.filter((b) => erpConnections.some((c) => c.branch_id === b.id)) as b}
					<option value={b.id}>{b.name_en}</option>
				{/each}
			</select>
		</div>
		<div class="filter-field">
			<label for="lc-date">Date</label>
			<input id="lc-date" type="date" bind:value={lcDate} />
		</div>
		<div class="filter-field">
			<label for="lc-time-from">From time (optional)</label>
			<input id="lc-time-from" type="time" bind:value={lcTimeFrom} />
		</div>
		<div class="filter-field">
			<label for="lc-time-to">To time (optional)</label>
			<input id="lc-time-to" type="time" bind:value={lcTimeTo} />
		</div>
		<button class="run-btn" on:click={runLiveCheck} disabled={lcLoading || !lcSelectedBranchId}>
			{lcLoading ? '⏳ Checking ERP live...' : '🔴 Run Live Check'}
		</button>
	</div>
	<p class="flagger-desc">Re-checks each flagged (unmatched) event directly against this branch's live SQL Server via tunnel — bypasses the Supabase sync delay, useful right after a drawer-kick to confirm nothing was actually printed/invoiced around that time.</p>

	{#if lcError}
		<div class="error-banner">⚠️ {lcError}</div>
	{:else if lcHasRun}
		{#if lcResults.length > 0}
			<div class="table-wrapper">
				<table>
					<thead>
						<tr>
							<th>Time</th>
							<th>Printer</th>
							<th>Size</th>
							<th>User (local)</th>
							<th>Live ERP Match</th>
							<th>Match Count</th>
							<th>Closest Voucher</th>
							<th>Closest ERP User</th>
							<th>Closest Time Diff</th>
						</tr>
					</thead>
					<tbody>
						{#each lcResults as r}
							<tr class:flagged-row={!r.liveMatchFound}>
								<td>{formatTime(r.event.event_time)}</td>
								<td>{r.event.printer_name || r.event.counter_name || '-'}</td>
								<td>
									{formatBytes(r.event.byte_size)}
									{#if r.event.is_small_print}<span class="small-print-badge">kick?</span>{/if}
								</td>
								<td>{r.event.user_name || '-'}</td>
								<td>
									{#if r.liveMatchFound}
										<span class="status-badge ok">✅ Found live</span>
									{:else}
										<span class="status-badge flagged">🚨 Still no match</span>
									{/if}
								</td>
								<td>{r.liveMatchCount}</td>
								<td>{r.liveVoucherNumber || '-'}</td>
								<td>{r.liveUserName || '-'}</td>
								<td>{formatSeconds(r.liveSecondsDiff)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{:else}
			<div class="empty-state">✅ No flagged events for this branch/day{#if lcTimeFrom || lcTimeTo}/time window{/if} — nothing to live-check.</div>
		{/if}
	{:else}
		<div class="empty-state">Pick a branch and date, then click Run Live Check.</div>
	{/if}
	{/if}

	{#if activeTab === 'syncstatus'}
	<div class="filters-panel">
		<button class="run-btn" on:click={loadSyncStatuses} disabled={syncStatusLoading}>
			{syncStatusLoading ? '⏳ Loading...' : '🔄 Refresh'}
		</button>
	</div>

	{#if syncStatusError}
		<div class="error-banner">⚠️ {syncStatusError}</div>
	{/if}

	{#if syncStatuses.length > 0}
		<div class="summary-cards">
			<div class="summary-card">
				<div class="summary-label">Total Devices</div>
				<div class="summary-value">{syncStatuses.length}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">🟢 Online</div>
				<div class="summary-value">{syncStatuses.filter(s => s.is_online).length}</div>
			</div>
			<div class="summary-card flagged">
				<div class="summary-label">🚨 Flagged (&gt;1h)</div>
				<div class="summary-value">{syncStatuses.filter(s => s.is_flagged).length}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">⚪ Offline</div>
				<div class="summary-value">{syncStatuses.filter(s => !s.is_online && !s.is_flagged).length}</div>
			</div>
		</div>

		<div class="section-block">
			<h3 class="section-title">Installed Sync Apps</h3>
			<div class="table-wrapper">
				<table>
					<thead>
						<tr>
							<th>Status</th>
							<th>Branch</th>
							<th>Mode</th>
							<th>Hostname / IP</th>
							<th>Counter</th>
							<th>Last Heartbeat</th>
							<th>Last Sync</th>
							<th>Last Error</th>
							<th>Version</th>
						</tr>
					</thead>
					<tbody>
						{#each syncStatuses as s}
							<tr class:flagged-row={s.is_flagged}>
								<td>
									{#if s.is_online}
										<span class="status-badge ok">🟢 Online</span>
									{:else if s.is_flagged}
										<span class="status-badge flagged">🚨 Flagged</span>
									{:else}
										<span class="status-badge" style="background:rgba(148,163,184,0.15);color:#94a3b8;border-color:#475569;">⚪ Offline</span>
									{/if}
								</td>
								<td>{s.branch_name || '-'}</td>
								<td><span style="text-transform:uppercase;font-size:0.75rem;font-weight:600;">{s.mode || '-'}</span></td>
								<td>{s.hostname || '-'}{s.ip_address ? ` (${s.ip_address})` : ''}</td>
								<td>{s.counter_name || '-'}</td>
								<td>{formatMinutes(s.minutes_since_heartbeat)}</td>
								<td>{s.last_sync_at ? formatTime(s.last_sync_at) : 'Never'}</td>
								<td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title={s.last_error || ''}>{s.last_error || '✅'}</td>
								<td>{s.app_version || '-'}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{:else if !syncStatusLoading}
		<div class="empty-state">No Sync App devices found. Install the Sync App on branch machines to see their status here.</div>
	{/if}
	{/if}

	{#if activeTab === 'erpcounters'}
	<div class="filters-panel">
		<button class="run-btn" on:click={syncErpCounters} disabled={counterSyncLoading}>
			{counterSyncLoading ? '⏳ Syncing...' : '🔄 Sync ERP Counters'}
		</button>
	</div>
	<p class="flagger-desc">
		Pulls each branch's POS counter names — plus each counter's last-seen system (PC hostname), since names alone
		can repeat across counters — live over its tunnel, and caches them in Supabase. The Flagger tab then shows both
		instead of just the numeric counter ID, even if that branch's tunnel is offline when the flagger runs.
	</p>

	{#if counterSyncSummary}
		<div class="flagger-summary ok">{counterSyncSummary}</div>
	{/if}
	{#if counterSyncError}
		<div class="error-banner">{counterSyncError}</div>
	{/if}

	{#if erpCounters.length > 0}
		<div class="section-block">
			<h3 class="section-title">Synced POS Counters</h3>
			<div class="table-wrapper">
				<table>
					<thead>
						<tr>
							<th>Branch</th>
							<th>Counter ID</th>
							<th>Counter Name</th>
							<th>System (PC)</th>
							<th>Last Synced</th>
						</tr>
					</thead>
					<tbody>
						{#each erpCounters as c}
							<tr>
								<td>{branchNameFor(c.branch_id)}</td>
								<td>{c.counter_id}</td>
								<td>{c.counter_name || '-'}</td>
								<td>{c.system_name || '-'}</td>
								<td>{formatTime(c.synced_at)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{:else if !counterSyncLoading}
		<div class="empty-state">No counters synced yet — click "Sync ERP Counters" to pull them from each branch.</div>
	{/if}
	{/if}
</div>

<style>
	.drawer-monitor {
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
	.blob-1 { width: 300px; height: 300px; background: rgba(239, 68, 68, 0.25); top: -80px; right: -60px; }
	.blob-2 { width: 260px; height: 260px; background: rgba(252, 165, 165, 0.3); bottom: -60px; left: -60px; }

	.header, .filters-panel, .summary-cards, .section-block, .error-banner, .empty-state {
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
	.header-left { display: flex; align-items: center; gap: 0.75rem; }
	.header-icon { font-size: 2rem; }
	.header-title { margin: 0; font-size: 1.2rem; font-weight: 700; color: #7f1d1d; }
	.header-subtitle { margin: 0.2rem 0 0; font-size: 0.8rem; color: #991b1b; opacity: 0.75; }

	.tab-bar { position: relative; z-index: 1; display: flex; gap: 0.6rem; }
	.tab-btn {
		padding: 0.6rem 1.3rem; border: 1px solid rgba(254, 202, 202, 0.7); border-radius: 12px;
		background: rgba(255, 255, 255, 0.5); color: #991b1b; font-weight: 700; font-size: 0.85rem;
		cursor: pointer; transition: background 0.15s, transform 0.1s;
	}
	.tab-btn:hover { background: rgba(254, 226, 226, 0.7); transform: translateY(-1px); }
	.tab-btn.active { background: linear-gradient(135deg, #ef4444, #dc2626); color: #fff; border-color: #dc2626; box-shadow: 0 6px 16px rgba(220, 38, 38, 0.3); }

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
	.filter-field { display: flex; flex-direction: column; gap: 0.3rem; min-width: 140px; }
	.filter-field label { font-size: 0.72rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.4px; color: #b91c1c; }
	.filter-field select, .filter-field input[type="date"] {
		padding: 0.5rem 0.7rem; border-radius: 10px; border: 1px solid rgba(252, 165, 165, 0.7);
		background: rgba(255, 255, 255, 0.8); font-size: 0.85rem; color: #7f1d1d;
	}
	.checkbox-field { flex-direction: row; align-items: center; gap: 0.5rem; min-width: auto; }
	.checkbox-label { display: flex; align-items: center; gap: 0.4rem; font-size: 0.82rem; color: #7f1d1d; cursor: pointer; }

	.run-btn {
		padding: 0.6rem 1.4rem; border: none; border-radius: 10px;
		background: linear-gradient(135deg, #ef4444, #dc2626); color: #fff; font-weight: 700; font-size: 0.85rem;
		cursor: pointer; box-shadow: 0 6px 16px rgba(220, 38, 38, 0.3); transition: transform 0.15s, box-shadow 0.15s;
	}
	.run-btn:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 8px 20px rgba(220, 38, 38, 0.4); }
	.run-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	.error-banner {
		padding: 0.75rem 1rem; background: rgba(220, 38, 38, 0.1); border: 1px solid rgba(220, 38, 38, 0.35);
		border-radius: 12px; color: #b91c1c; font-size: 0.85rem; font-weight: 600;
	}

	.summary-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 0.75rem; }
	.summary-card {
		padding: 0.9rem 1rem; background: rgba(255, 255, 255, 0.55); backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px); border: 1px solid rgba(254, 202, 202, 0.6); border-radius: 14px;
		box-shadow: 0 6px 16px rgba(220, 38, 38, 0.06);
	}
	.summary-card.flagged { border-color: rgba(220, 38, 38, 0.6); background: rgba(254, 226, 226, 0.7); }
	.summary-card.warn { border-color: rgba(234, 179, 8, 0.6); background: rgba(254, 243, 199, 0.7); }
	.summary-label { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.4px; color: #b91c1c; font-weight: 600; margin-bottom: 0.3rem; }
	.summary-value { font-size: 1.15rem; font-weight: 700; color: #7f1d1d; }
	.summary-value.small { font-size: 0.9rem; }
	.summary-value .dim { font-weight: 500; font-size: 0.78rem; color: #b91c1c; opacity: 0.7; }

	.section-block {
		background: rgba(255, 255, 255, 0.5); backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(254, 202, 202, 0.6); border-radius: 16px; padding: 1rem 1.1rem;
		box-shadow: 0 8px 20px rgba(220, 38, 38, 0.06);
	}
	.section-title { margin: 0 0 0.75rem; font-size: 0.95rem; font-weight: 700; color: #7f1d1d; }

	.section-title-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.75rem; }
	.section-title-row .section-title { margin-bottom: 0; }

	.clear-filter-btn {
		border: none; background: rgba(220, 38, 38, 0.1); color: #b91c1c; font-size: 0.72rem; font-weight: 700;
		padding: 0.3rem 0.7rem; border-radius: 999px; cursor: pointer; transition: background 0.15s;
	}
	.clear-filter-btn:hover { background: rgba(220, 38, 38, 0.2); }

	.type-pills { display: flex; flex-wrap: wrap; gap: 0.5rem; }
	.type-pill {
		display: flex; align-items: center; gap: 0.5rem; padding: 0.4rem 0.9rem;
		background: rgba(254, 226, 226, 0.7); border: 1px solid rgba(252, 165, 165, 0.6); border-radius: 999px;
		font-size: 0.8rem; font-family: inherit; cursor: pointer; transition: background 0.15s, border-color 0.15s, transform 0.1s;
	}
	.type-pill:hover { background: rgba(254, 202, 202, 0.9); transform: translateY(-1px); }
	.type-pill.active { background: linear-gradient(135deg, #ef4444, #dc2626); border-color: #dc2626; box-shadow: 0 4px 12px rgba(220, 38, 38, 0.35); }
	.type-pill.active .pill-name { color: #fff; }
	.type-pill.active .pill-count { background: #fff; color: #b91c1c; }
	.pill-name { color: #991b1b; font-weight: 600; }
	.pill-count { background: #dc2626; color: #fff; border-radius: 999px; padding: 0.1rem 0.5rem; font-size: 0.75rem; font-weight: 700; }

	.content-split { display: flex; gap: 1rem; align-items: flex-start; }
	.table-column { flex: 0 0 70%; max-width: 70%; min-width: 0; }
	.cashier-column { flex: 0 0 30%; max-width: 30%; min-width: 0; }

	.cashier-card-list { display: flex; flex-direction: column; gap: 0.6rem; max-height: 560px; overflow-y: auto; }
	.cashier-mini-card {
		padding: 0.6rem 0.8rem; background: rgba(254, 226, 226, 0.5); border: 1px solid rgba(252, 165, 165, 0.6);
		border-radius: 12px; cursor: pointer; transition: background 0.15s, border-color 0.15s, transform 0.1s;
	}
	.cashier-mini-card:hover { background: rgba(254, 202, 202, 0.75); transform: translateY(-1px); }
	.cashier-mini-card.active { background: linear-gradient(135deg, #ef4444, #dc2626); border-color: #dc2626; box-shadow: 0 4px 12px rgba(220, 38, 38, 0.35); }
	.cashier-mini-card.active .cashier-mini-name, .cashier-mini-card.active .cashier-mini-items, .cashier-mini-card.active .cashier-mini-amount { color: #fff; }
	.cashier-mini-name { font-weight: 700; font-size: 0.85rem; color: #7f1d1d; margin-bottom: 0.25rem; }
	.cashier-mini-stats { display: flex; align-items: center; justify-content: space-between; }
	.cashier-mini-items { font-size: 0.72rem; color: #b91c1c; opacity: 0.8; }
	.cashier-mini-amount { font-size: 0.9rem; font-weight: 700; color: #991b1b; }
	.cashier-mini-amount.flagged-text { color: #dc2626; }

	.table-wrapper { overflow-x: auto; border-radius: 12px; }
	table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
	thead th {
		text-align: left; padding: 0.55rem 0.7rem; background: rgba(254, 226, 226, 0.6); color: #991b1b;
		font-weight: 700; text-transform: uppercase; font-size: 0.68rem; letter-spacing: 0.3px; position: sticky; top: 0;
	}
	tbody td { padding: 0.5rem 0.7rem; border-bottom: 1px solid rgba(254, 202, 202, 0.4); color: #7f1d1d; }
	tbody tr.flagged-row { background: rgba(220, 38, 38, 0.08); }
	tbody tr.flagged-row td { font-weight: 600; }

	tbody tr.group-row { cursor: pointer; transition: background 0.15s; }
	tbody tr.group-row:hover { background: rgba(254, 226, 226, 0.4); }
	tbody tr.detail-row { background: rgba(255, 255, 255, 0.3); }

	.expand-cell { width: 24px; color: #dc2626; font-size: 0.7rem; }
	.product-name { font-style: italic; color: #991b1b; opacity: 0.85; }
	.amount-cell { font-weight: 700; text-align: right; }

	.type-badge { padding: 0.15rem 0.55rem; border-radius: 999px; font-size: 0.72rem; font-weight: 700; }
	.type-badge.cancel { background: rgba(220, 38, 38, 0.15); color: #b91c1c; }
	.type-badge.void { background: rgba(251, 146, 60, 0.18); color: #c2410c; }
	.type-badge.generic { background: rgba(100, 116, 139, 0.15); color: #475569; }

	.status-badge { padding: 0.2rem 0.6rem; border-radius: 999px; font-size: 0.72rem; font-weight: 700; white-space: nowrap; }
	.status-badge.flagged { background: rgba(220, 38, 38, 0.18); color: #b91c1c; }
	.status-badge.ok { background: rgba(34, 197, 94, 0.15); color: #15803d; }

	.small-print-badge {
		margin-left: 6px; padding: 0.1rem 0.4rem; border-radius: 6px; font-size: 0.62rem; font-weight: 700;
		background: rgba(220, 38, 38, 0.15); color: #b91c1c; vertical-align: middle;
	}

	.empty-state {
		text-align: center; padding: 2rem; color: #b91c1c; opacity: 0.7; font-size: 0.9rem;
		background: rgba(255, 255, 255, 0.4); border-radius: 16px; border: 1px dashed rgba(252, 165, 165, 0.6);
	}

	.flagger-block { border: 1px dashed rgba(220, 38, 38, 0.5); background: rgba(254, 242, 242, 0.6); }
	.flagger-desc { margin: 0 0 0.75rem; font-size: 0.8rem; color: #991b1b; opacity: 0.8; }
	.flagger-controls { display: flex; align-items: flex-end; gap: 0.85rem; margin-bottom: 0.85rem; }
	.flagger-btn { padding: 0.6rem 1.2rem; }
	.flagger-summary { margin-bottom: 0.75rem; font-weight: 700; color: #b91c1c; font-size: 0.85rem; }
	.flagger-summary.ok { color: #15803d; }
</style>
