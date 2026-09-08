<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';
	// User Actions tab embeds the standalone live-query report directly — single implementation,
	// shared between its own window and this tab, per the "live data only, one place" decision.
	import UserActionReports from './UserActionReports.svelte';

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

	let activeTab: 'useractions' | 'livecheck' | 'syncstatus' | 'erpcounters' = 'useractions';

	let branches: BranchOption[] = [];
	let loadingBranches = true;
	// Set by loadBranches() on failure — no longer displayed anywhere since the Flagger tab (its
	// only consumer) was removed, but left in place since loadBranches() itself is shared with the
	// Live ERP Check tab's branch dropdown.
	let errorMessage = '';

	const today = new Date().toISOString().split('T')[0];

	// erp_counter_id only identifies the till, not its human-readable name — and the name
	// alone isn't reliably unique either (two counters have been seen sharing the name
	// "Primary" on the same branch). Rather than resolving this live over the branch's
	// tunnel on every report run (slow, and blank whenever that branch's tunnel happens to
	// be down), it's looked up from `erp_counters` — a Supabase table pre-populated by the
	// "Sync ERP Counters" button on the ERP Counters tab (see syncErpCounters()), which also
	// carries each counter's last-seen SystemName (Windows hostname) as the actual per-PC
	// identifier — so both still show even with the tunnel offline. Keyed "branchId:counterId".
	interface CounterInfo {
		name: string;
		systemName: string | null;
	}
	let lcCounterNames = new Map<string, CounterInfo>();

	// Takes the map explicitly (rather than closing over the module-level variable) so Svelte's
	// template dependency tracking — which only sees identifiers referenced directly in the
	// markup expression, not ones read inside the function body — re-runs this once the
	// async lookup below resolves and reassigns the map.
	function posCounterLabel(e: FlaggedEvent, counterNames: Map<string, CounterInfo>): string {
		if (e.erp_counter_id == null) return '-';
		const info = counterNames.get(`${e.branch_id}:${e.erp_counter_id}`);
		if (!info) return $t('drawerMonitor.counterNotSynced', { id: e.erp_counter_id });
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
		// Who had that POS counter's till open at the moment of the event, from CounterShift —
		// unlike liveUserName (only set when a Print action actually matched), this is available
		// even for flagged/unmatched events, which is exactly when knowing the operator matters most.
		tillUserName: string | null;
	}

	interface CounterShiftRow {
		counterId: string;
		userName: string | null;
		openMs: number;
		closeMs: number; // Infinity when the shift is still open
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
	let lcSelectedPosCounter: string | null = null; // the POS Counter dropdown filter
	// Drives the breakdown cards — keyed by tillUserName (who actually had the till open), not
	// liveUserName, so events with no Print match still bucket under their real operator instead
	// of falling out of the breakdown entirely.
	let lcSelectedUser: string | null = null;
	let lcSelectedKickOnly = false; // when on, only show suspected blank-print drawer kicks

	// Distinct POS Counter labels present in the current results, for the dropdown filter.
	$: lcPosCounterOptions = Array.from(new Set(lcResults.map((r) => posCounterLabel(r.event, lcCounterNames)))).sort();

	$: lcFilteredResults = lcResults.filter(
		(r) =>
			(!lcSelectedPosCounter || posCounterLabel(r.event, lcCounterNames) === lcSelectedPosCounter) &&
			(!lcSelectedUser || (r.tillUserName || 'Unknown') === lcSelectedUser) &&
			(!lcSelectedKickOnly || (r.event.is_small_print && isKickSized(r.event.byte_size)))
	);

	// Grouped by till user (from CounterShift) rather than counter — "flagged" here means still no
	// live match, same red-flag meaning as the Run Report's cashierBreakdown even though the
	// underlying field name differs.
	$: lcUserBreakdown = Array.from(
		lcFilteredResults
			.reduce((map, r) => {
				const key = r.tillUserName || $t('drawerMonitor.unknownUser');
				const entry = map.get(key) || { name: key, total: 0, flagged: 0 };
				entry.total += 1;
				if (!r.liveMatchFound) entry.flagged += 1;
				map.set(key, entry);
				return map;
			}, new Map<string, { name: string; total: number; flagged: number }>())
			.values()
	).sort((a, b) => b.flagged - a.flagged || b.total - a.total);

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

	async function runLiveErpQuery(sql: string, branchId: number): Promise<any[]> {
		const response = await fetch('/api/erp-products', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ action: 'query', branchId, sql })
		});
		const data = await response.json();
		if (!data.success) throw new Error(data.error || $t('drawerMonitor.liveErpQueryFailed'));
		return data.recordset || [];
	}

	async function runLiveCheck() {
		lcError = '';
		lcResults = [];
		lcSelectedPosCounter = null;
		lcSelectedUser = null;
		if (!lcSelectedBranchId) {
			lcError = $t('drawerMonitor.pickBranchLiveCheck');
			lcHasRun = true;
			return;
		}
		const conn = erpConnections.find((c) => c.branch_id === lcSelectedBranchId);
		if (!conn) {
			lcError = $t('drawerMonitor.noErpConnectionForBranch');
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
				p_flagged_only: false
			});
			if (error) throw error;
			let flaggedEvents: FlaggedEvent[] = flagged || [];
			// Reads from the erp_counters cache table — no tunnel call here (see loadCounterNamesFor).
			lcCounterNames = await loadCounterNamesFor(flaggedEvents);

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
			const times = flaggedEvents.map((e) => naiveMs(e.event_time));
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
			// Every till-open/close session for the day (plus the day before, to cover a shift that
			// opened yesterday and is still running past midnight) — matched client-side against each
			// event's CounterID + timestamp so we know who was actually on that till, independent of
			// whether a Print action ever matched.
			const csSql = `
				SELECT cs.CounterID, cs.TransactionDate, cs.OpenTime, cs.ClosingTime, cs.OpenCloseStatus, u.UserName
				FROM CounterShift cs
				LEFT JOIN Users u ON u.UserID = cs.OpenUserID AND u.BranchID = ${erpBranchId}
				WHERE cs.BranchID = ${erpBranchId}
				  AND cs.TransactionDate BETWEEN DATEADD(day, -1, '${lcDate}') AND '${lcDate}'
			`;
			const [livePrints, rawShifts] = await Promise.all([
				runLiveErpQuery(sql, conn.branch_id),
				runLiveErpQuery(csSql, conn.branch_id)
			]);
			const shifts = buildCounterShiftRows(rawShifts);

			lcResults = flaggedEvents.map((e) => {
				const eventMs = naiveMs(e.event_time);
				// +10s tolerance ONLY (not symmetric), same as the main Flagger's DB-side matching —
				// the spooler-captured print event is what triggers the ERP's own Print log entry (the
				// DB write happens after the physical print job runs), so the ERP action can only
				// follow that event, never precede it. Counter-scoped when the flagged event has an
				// erp_counter_id recorded (falls back to branch-wide time-only matching for events
				// captured before the till's counter was configured).
				const toleranceMs = 10000;
				let best: any = null;
				let bestDiffSec: number | null = null;
				for (const p of livePrints) {
					// CounterID comes back from the live SQL Server bridge as a string (e.g. "15"),
					// while erp_counter_id from Supabase is a number — compare as strings so the
					// type mismatch doesn't silently exclude every row.
					if (e.erp_counter_id != null && String(p.CounterID) !== String(e.erp_counter_id)) continue;
					const diffMs = naiveMs(p.DateTimeOfAction) - eventMs; // only >=0: ERP print must be at or after the event
					if (diffMs < 0 || diffMs > toleranceMs) continue;
					const diffSec = diffMs / 1000;
					if (best === null || diffSec < bestDiffSec!) {
						best = p;
						bestDiffSec = diffSec;
					}
				}
				return {
					event: e,
					liveMatchFound: !!best,
					liveMatchCount: livePrints.filter(
						(p: any) => e.erp_counter_id == null || String(p.CounterID) === String(e.erp_counter_id)
					).length,
					liveVoucherNumber: best?.VoucherNumber ? String(best.VoucherNumber) : null,
					liveUserName: best?.UserName || null,
					liveSecondsDiff: best ? bestDiffSec : null,
					tillUserName: e.erp_counter_id != null ? findTillUser(shifts, String(e.erp_counter_id), eventMs) : null
				};
			});
		} catch (err: any) {
			console.error('Error running live ERP check:', err);
			lcError = err.message || $t('drawerMonitor.failedToRunLiveCheck');
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
			errorMessage = err.message || $t('drawerMonitor.failedToLoadBranches');
		} finally {
			loadingBranches = false;
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

	// Live ERP Check matches two naive branch-local wall-clock timestamps: the RPC's event_time
	// (no timezone marker) and the live SQL Server bridge's DateTimeOfAction (bogusly tagged with
	// a trailing 'Z', even though the digits are still naive branch-local, not real UTC). Passing
	// either through `new Date(str)` directly reinterprets it per that marker — no-marker as the
	// runtime's local timezone, 'Z' as UTC — silently shifting one or both by the host's UTC offset
	// and pushing every diff outside tolerance regardless of how generous it is. Extract the digits
	// and anchor them to UTC ourselves so only the actual wall-clock values are ever compared.
	function naiveMs(iso: string): number {
		const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?/.exec(iso || '');
		if (!m) return NaN;
		const [, y, mo, d, h, mi, s, ms] = m;
		return Date.UTC(+y, +mo - 1, +d, +h, +mi, +s, ms ? +ms.padEnd(3, '0').slice(0, 3) : 0);
	}

	// CounterShift's OpenTime/ClosingTime come back as full datetimes but with a dummy 1900-01-01
	// date — only the time-of-day portion is meaningful; the real date lives in TransactionDate
	// (also date-only). Stitch them together, rolling ClosingTime to the next calendar day when its
	// time-of-day is earlier than OpenTime's (an overnight shift), same handling as the live SQL
	// join used for the User Actions report.
	function shiftBoundMs(transactionDate: string, timeIso: string, rollIfBefore: number | null): number {
		const dateStr = (transactionDate || '').slice(0, 10);
		const timeStr = (timeIso || '').slice(11, 19) || '00:00:00';
		let ms = naiveMs(`${dateStr}T${timeStr}`);
		if (rollIfBefore !== null && ms < rollIfBefore) ms += 24 * 60 * 60 * 1000;
		return ms;
	}

	function buildCounterShiftRows(raw: any[]): CounterShiftRow[] {
		return raw.map((r: any) => {
			const openMs = shiftBoundMs(r.TransactionDate, r.OpenTime, null);
			const closeMs = r.OpenCloseStatus === 'O' ? Infinity : shiftBoundMs(r.TransactionDate, r.ClosingTime, openMs);
			return { counterId: String(r.CounterID), userName: r.UserName || null, openMs, closeMs };
		});
	}

	// Finds whichever shift covers this counter+timestamp; when more than one somehow overlaps,
	// prefers the one that opened most recently.
	function findTillUser(shifts: CounterShiftRow[], counterId: string, eventMs: number): string | null {
		let best: CounterShiftRow | null = null;
		for (const s of shifts) {
			if (s.counterId !== counterId) continue;
			if (eventMs < s.openMs || eventMs > s.closeMs) continue;
			if (!best || s.openMs > best.openMs) best = s;
		}
		return best?.userName || null;
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

	// The "kick?" badge should only call out prints tiny enough to actually display in bytes
	// (e.g. "79 B", "244 B") — is_small_print itself is flagged up to a much wider 50KB threshold
	// server-side (see get_flagged_drawer_events' p_small_print_bytes), which would otherwise badge
	// genuine multi-KB receipts too.
	function isKickSized(n: number | null): boolean {
		return n !== null && n !== undefined && n < 1024;
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
	let syncStatusSelectedBranchId: number | null = null; // null = all branches

	// Distinct branches present in the loaded devices, for the filter dropdown — built from the
	// devices themselves (branch_id/branch_name) rather than the global `branches` list, so it only
	// ever offers branches that actually have a Sync App device reporting in.
	$: syncStatusBranchOptions = Array.from(
		syncStatuses
			.filter((s) => s.branch_id != null)
			.reduce((map, s) => map.set(s.branch_id as number, s.branch_name || $t('drawerMonitor.branchFallback', { id: s.branch_id })), new Map<number, string>())
			.entries()
	).sort((a, b) => a[1].localeCompare(b[1]));

	$: filteredSyncStatuses = syncStatuses.filter(
		(s) => !syncStatusSelectedBranchId || s.branch_id === syncStatusSelectedBranchId
	);

	async function loadSyncStatuses() {
		syncStatusLoading = true;
		syncStatusError = '';
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase.rpc('get_sync_app_statuses');
			if (error) throw error;
			syncStatuses = data || [];
		} catch (err: any) {
			syncStatusError = err.message || $t('drawerMonitor.failedToLoadSyncStatuses');
		} finally {
			syncStatusLoading = false;
		}
	}

	function formatMinutes(mins: number): string {
		if (mins < 1) return $t('drawerMonitor.justNow');
		if (mins < 60) return $t('drawerMonitor.minutesAgo', { m: Math.round(mins) });
		const h = Math.floor(mins / 60);
		const m = Math.round(mins % 60);
		return $t('drawerMonitor.hoursMinutesAgo', { h, m });
	}

	// --- ERP Counters sync (ERP Counters tab) ---
	// "🔄 Sync ERP Counters" action: pulls CounterID/CounterName from every connected branch's
	// live SQL Server (via tunnel) and upserts them into `erp_counters`. Counter *names* aren't
	// reliably unique on their own (e.g. two counters both named "Primary" have been seen on the
	// same branch) — so this also pulls each counter's most-recently-seen SystemName (the Windows
	// hostname, logged on every UserActions row) as the actual per-PC identifier.
	// The Live ERP Check tab then reads both from this cached table instead of the tunnel, so it
	// keeps showing them even when a branch's tunnel is offline.
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
		return branches.find((b) => b.id === branchId)?.name_en || $t('drawerMonitor.branchFallback', { id: branchId });
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
				counterSyncError = $t('drawerMonitor.noActiveTunnelConnections');
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
						runLiveErpQuery(counterSql, conn.branch_id),
						runLiveErpQuery(systemNameSql, conn.branch_id)
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
			counterSyncSummary = $t('drawerMonitor.syncedSummary', { total: totalSynced, branches: okBranches });
			if (failedBranches.length > 0) {
				counterSyncError = $t('drawerMonitor.tunnelUnreachableFor', { branches: failedBranches.join(', ') });
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

	<div class="tab-bar">
		<button class="tab-btn" class:active={activeTab === 'useractions'} on:click={() => (activeTab = 'useractions')}>{$t('drawerMonitor.tabUserActions')}</button>
		<button class="tab-btn" class:active={activeTab === 'livecheck'} on:click={() => (activeTab = 'livecheck')}>{$t('drawerMonitor.tabLiveCheck')}</button>
		<button class="tab-btn" class:active={activeTab === 'syncstatus'} on:click={() => { activeTab = 'syncstatus'; loadSyncStatuses(); }}>{$t('drawerMonitor.tabSyncStatus')}</button>
		<button class="tab-btn" class:active={activeTab === 'erpcounters'} on:click={() => { activeTab = 'erpcounters'; loadErpCountersTable(); }}>{$t('drawerMonitor.tabErpCounters')}</button>
	</div>

	<div class="tab-content">
	{#if activeTab === 'useractions'}
	<div class="embedded-user-actions">
		<UserActionReports hideHeader />
	</div>
	{/if}

	{#if activeTab === 'livecheck'}
	<div class="sticky-top">
	<div class="filters-panel">
		<div class="filter-field">
			<label for="lc-branch-select">{$t('common.branch')}</label>
			<select id="lc-branch-select" bind:value={lcSelectedBranchId}>
				{#each branches.filter((b) => erpConnections.some((c) => c.branch_id === b.id)) as b}
					<option value={b.id}>{b.name_en}</option>
				{/each}
			</select>
		</div>
		<div class="filter-field">
			<label for="lc-date">{$t('drawerMonitor.dateLabel')}</label>
			<input id="lc-date" type="date" bind:value={lcDate} />
		</div>
		<div class="filter-field">
			<label for="lc-time-from">{$t('drawerMonitor.fromTimeOptional')}</label>
			<input id="lc-time-from" type="time" bind:value={lcTimeFrom} />
		</div>
		<div class="filter-field">
			<label for="lc-time-to">{$t('drawerMonitor.toTimeOptional')}</label>
			<input id="lc-time-to" type="time" bind:value={lcTimeTo} />
		</div>
		<div class="filter-field">
			<label for="lc-pos-counter-filter">{$t('drawerMonitor.posCounter')}</label>
			<select id="lc-pos-counter-filter" bind:value={lcSelectedPosCounter}>
				<option value={null}>{$t('drawerMonitor.allCounters')}</option>
				{#each lcPosCounterOptions as c}
					<option value={c}>{c}</option>
				{/each}
			</select>
		</div>
		<div class="filter-field">
			<label for="lc-kick-only-filter">{$t('drawerMonitor.kickFilter')}</label>
			<button id="lc-kick-only-filter" type="button" class="kick-toggle-btn" class:active={lcSelectedKickOnly} on:click={() => (lcSelectedKickOnly = !lcSelectedKickOnly)}>
				{lcSelectedKickOnly ? $t('drawerMonitor.kickOnly') : $t('drawerMonitor.allSizes')}
			</button>
		</div>
		<button class="run-btn" on:click={runLiveCheck} disabled={lcLoading || !lcSelectedBranchId}>
			{lcLoading ? $t('drawerMonitor.checkingErpLive') : $t('drawerMonitor.runLiveCheck')}
		</button>
	</div>
	<p class="flagger-desc">{$t('drawerMonitor.liveCheckDesc')}</p>
	</div>

	<div class="scroll-area">
	{#if lcError}
		<div class="error-banner">⚠️ {lcError}</div>
	{:else if lcHasRun}
		{#if lcResults.length > 0}
			<div class="content-split">
				<div class="table-column section-block">
					<h3 class="section-title">{$t('drawerMonitor.eventDetail')}</h3>
					<div class="table-wrapper">
						<table>
							<thead>
								<tr>
									<th>{$t('drawerMonitor.colTime')}</th>
									<th>{$t('drawerMonitor.colPosCounter')}</th>
									<th>{$t('drawerMonitor.colPrinter')}</th>
									<th>{$t('drawerMonitor.colSize')}</th>
									<th>{$t('drawerMonitor.colUserLocal')}</th>
									<th>{$t('drawerMonitor.colSupabaseStatus')}</th>
									<th>{$t('drawerMonitor.colLiveErpMatch')}</th>
									<th>{$t('drawerMonitor.colMatchCount')}</th>
									<th>{$t('drawerMonitor.colClosestVoucher')}</th>
									<th>{$t('drawerMonitor.colClosestErpUser')}</th>
									<th title={$t('drawerMonitor.tillUserTooltip')}>{$t('drawerMonitor.colTillUser')}</th>
									<th>{$t('drawerMonitor.colClosestTimeDiff')}</th>
								</tr>
							</thead>
							<tbody>
								{#each lcFilteredResults as r}
									<tr class:flagged-row={!r.liveMatchFound}>
										<td>{formatTime(r.event.event_time)}</td>
										<td>{posCounterLabel(r.event, lcCounterNames)}</td>
										<td>{r.event.printer_name || r.event.counter_name || '-'}</td>
										<td>
											{formatBytes(r.event.byte_size)}
											{#if r.event.is_small_print && isKickSized(r.event.byte_size)}<span class="small-print-badge">{$t('drawerMonitor.kickBadge')}</span>{/if}
										</td>
										<td>{r.event.user_name || '-'}</td>
										<td>
											{#if r.event.is_flagged}
												<span class="status-badge flagged">{$t('drawerMonitor.flaggedBadge')}</span>
											{:else}
												<span class="status-badge ok">{$t('drawerMonitor.matchedBadge')}</span>
											{/if}
										</td>
										<td>
											{#if r.liveMatchFound}
												<span class="status-badge ok">{$t('drawerMonitor.foundLiveBadge')}</span>
											{:else}
												<span class="status-badge flagged">{$t('drawerMonitor.stillNoMatchBadge')}</span>
											{/if}
										</td>
										<td>{r.liveMatchCount}</td>
										<td>{r.liveVoucherNumber || '-'}</td>
										<td>{r.liveUserName || '-'}</td>
										<td>{r.tillUserName || '-'}</td>
										<td>{formatSeconds(r.liveSecondsDiff)}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>

				<div class="cashier-column section-block">
					<h3 class="section-title">{$t('drawerMonitor.userBreakdown')}</h3>
					<div class="cashier-card-list">
						{#each lcUserBreakdown as c}
							<div class="cashier-mini-card" class:active={lcSelectedUser === c.name} on:click={() => (lcSelectedUser = lcSelectedUser === c.name ? null : c.name)}>
								<div class="cashier-mini-name">{c.name}</div>
								<div class="cashier-mini-stats">
									<span class="cashier-mini-items">{c.total} {c.total === 1 ? $t('drawerMonitor.eventWord') : $t('drawerMonitor.eventsWord')}</span>
									<span class="cashier-mini-amount" class:flagged-text={c.flagged > 0}>{c.flagged} {$t('drawerMonitor.noMatchWord')}</span>
								</div>
							</div>
						{/each}
					</div>
				</div>
			</div>
		{:else}
			<div class="empty-state">{lcTimeFrom || lcTimeTo ? $t('drawerMonitor.noEventsForDayTime') : $t('drawerMonitor.noEventsForDay')}</div>
		{/if}
	{:else}
		<div class="empty-state">{$t('drawerMonitor.pickBranchDateRun')}</div>
	{/if}
	</div>
	{/if}

	{#if activeTab === 'syncstatus'}
	<div class="sticky-top">
	<div class="filters-panel">
		<div class="filter-field">
			<label for="sync-status-branch-select">{$t('common.branch')}</label>
			<select id="sync-status-branch-select" bind:value={syncStatusSelectedBranchId}>
				<option value={null}>{$t('drawerMonitor.allBranches')}</option>
				{#each syncStatusBranchOptions as [id, name]}
					<option value={id}>{name}</option>
				{/each}
			</select>
		</div>
		<button class="run-btn" on:click={loadSyncStatuses} disabled={syncStatusLoading}>
			{syncStatusLoading ? $t('drawerMonitor.refreshingBtn') : $t('drawerMonitor.refreshBtn')}
		</button>
	</div>

	{#if syncStatusError}
		<div class="error-banner">⚠️ {syncStatusError}</div>
	{/if}

	{#if filteredSyncStatuses.length > 0}
		<div class="summary-cards">
			<div class="summary-card">
				<div class="summary-label">{$t('drawerMonitor.totalDevices')}</div>
				<div class="summary-value">{filteredSyncStatuses.length}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">{$t('drawerMonitor.onlineBadge')}</div>
				<div class="summary-value">{filteredSyncStatuses.filter(s => s.is_online).length}</div>
			</div>
			<div class="summary-card flagged">
				<div class="summary-label">{$t('drawerMonitor.flaggedGt1h')}</div>
				<div class="summary-value">{filteredSyncStatuses.filter(s => s.is_flagged).length}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">{$t('drawerMonitor.offlineBadge')}</div>
				<div class="summary-value">{filteredSyncStatuses.filter(s => !s.is_online && !s.is_flagged).length}</div>
			</div>
		</div>
	{/if}
	</div>

	<div class="scroll-area">
	{#if filteredSyncStatuses.length > 0}
		<div class="section-block table-section">
			<h3 class="section-title">{$t('drawerMonitor.installedSyncApps')}</h3>
			<div class="table-wrapper">
				<table>
					<thead>
						<tr>
							<th>{$t('common.status')}</th>
							<th>{$t('common.branch')}</th>
							<th>{$t('drawerMonitor.colMode')}</th>
							<th>{$t('drawerMonitor.colHostnameIp')}</th>
							<th>{$t('drawerMonitor.colCounter')}</th>
							<th>{$t('drawerMonitor.colLastHeartbeat')}</th>
							<th>{$t('drawerMonitor.colLastSync')}</th>
							<th>{$t('drawerMonitor.colLastError')}</th>
							<th>{$t('drawerMonitor.colVersion')}</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredSyncStatuses as s}
							<tr class:flagged-row={s.is_flagged}>
								<td>
									{#if s.is_online}
										<span class="status-badge ok">{$t('drawerMonitor.onlineBadge')}</span>
									{:else if s.is_flagged}
										<span class="status-badge flagged">{$t('drawerMonitor.flaggedBadge')}</span>
									{:else}
										<span class="status-badge" style="background:rgba(148,163,184,0.15);color:#94a3b8;border-color:#475569;">{$t('drawerMonitor.offlineBadge')}</span>
									{/if}
								</td>
								<td>{s.branch_name || '-'}</td>
								<td><span style="text-transform:uppercase;font-size:0.75rem;font-weight:600;">{s.mode || '-'}</span></td>
								<td>{s.hostname || '-'}{s.ip_address ? ` (${s.ip_address})` : ''}</td>
								<td>{s.counter_name || '-'}</td>
								<td>{formatMinutes(s.minutes_since_heartbeat)}</td>
								<td>{s.last_sync_at ? formatTime(s.last_sync_at) : $t('drawerMonitor.never')}</td>
								<td style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title={s.last_error || ''}>{s.last_error || '✅'}</td>
								<td>{s.app_version || '-'}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{:else if !syncStatusLoading}
		<div class="empty-state">
			{syncStatuses.length > 0
				? $t('drawerMonitor.noDevicesForBranch')
				: $t('drawerMonitor.noSyncAppDevices')}
		</div>
	{/if}
	</div>
	{/if}

	{#if activeTab === 'erpcounters'}
	<div class="sticky-top">
	<div class="filters-panel">
		<button class="run-btn" on:click={syncErpCounters} disabled={counterSyncLoading}>
			{counterSyncLoading ? $t('drawerMonitor.syncingBtn') : $t('drawerMonitor.syncErpCountersBtn')}
		</button>
	</div>
	<p class="flagger-desc">{$t('drawerMonitor.erpCountersDesc')}</p>

	{#if counterSyncSummary}
		<div class="flagger-summary ok">{counterSyncSummary}</div>
	{/if}
	{#if counterSyncError}
		<div class="error-banner">{counterSyncError}</div>
	{/if}
	</div>

	<div class="scroll-area">
	{#if erpCounters.length > 0}
		<div class="section-block table-section">
			<h3 class="section-title">{$t('drawerMonitor.syncedPosCounters')}</h3>
			<div class="table-wrapper">
				<table>
					<thead>
						<tr>
							<th>{$t('common.branch')}</th>
							<th>{$t('drawerMonitor.colCounterId')}</th>
							<th>{$t('drawerMonitor.colCounterName')}</th>
							<th>{$t('drawerMonitor.colSystemPc')}</th>
							<th>{$t('drawerMonitor.colLastSynced')}</th>
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
		<div class="empty-state">{$t('drawerMonitor.noCountersSynced')}</div>
	{/if}
	</div>
	{/if}
	</div>
</div>

<style>
	.drawer-monitor {
		position: relative;
		width: 100%;
		height: 100%;
		overflow: hidden;
		padding: 1.25rem;
		background: linear-gradient(135deg, #fff5f5 0%, #fff0f0 50%, #fef2f2 100%);
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	/* Tab bar stays fixed in place. .tab-content itself no longer scrolls — it's bounded to the
	   remaining viewport height, and each tab splits into a fixed .sticky-top (filters/summary/
	   status-pills) plus a .scroll-area that alone owns the scrollbar for that tab's table data. */
	.tab-bar { flex-shrink: 0; }
	.tab-content {
		flex: 1 1 auto;
		min-height: 0;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.sticky-top {
		flex-shrink: 0;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	/* Gives the embedded UserActionReports component (which sizes itself to height:100% and
	   scrolls internally) a definite height to resolve that percentage against. */
	.embedded-user-actions {
		flex: 1 1 auto;
		min-height: 0;
		overflow: hidden;
	}

	/* Owns the scrollbar for everything below .sticky-top in a tab — table headers inside stay
	   sticky to the top of THIS box (not fighting with .sticky-top for the same scroll offset). */
	.scroll-area {
		flex: 1 1 auto;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	/* For a lone table section (no side breakdown panel) inside .scroll-area — lets its .table-wrapper
	   claim the section's full height so the table itself scrolls with a sticky header, rather than
	   growing to fit all rows and pushing the scroll down to .scroll-area's outer edge. */
	.table-section { display: flex; flex-direction: column; min-height: 0; flex: 1 1 auto; }

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

	.filters-panel, .summary-cards, .section-block, .error-banner, .empty-state {
		position: relative;
		z-index: 1;
	}

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
	.filter-field select, .filter-field input[type="date"], .filter-field input[type="time"] {
		padding: 0.5rem 0.7rem; border-radius: 10px; border: 1px solid rgba(252, 165, 165, 0.7);
		background: rgba(255, 255, 255, 0.8); font-size: 0.85rem; color: #7f1d1d;
	}
	.checkbox-field { flex-direction: row; align-items: center; gap: 0.5rem; min-width: auto; }
	.checkbox-label { display: flex; align-items: center; gap: 0.4rem; font-size: 0.82rem; color: #7f1d1d; cursor: pointer; }
	.kick-toggle-btn {
		padding: 0.5rem 0.7rem; border-radius: 10px; border: 1px solid rgba(252, 165, 165, 0.7);
		background: rgba(255, 255, 255, 0.8); font-size: 0.85rem; color: #7f1d1d; font-weight: 600;
		cursor: pointer; white-space: nowrap; transition: all 0.15s ease;
	}
	.kick-toggle-btn:hover { background: rgba(254, 226, 226, 0.9); border-color: #f87171; }
	.kick-toggle-btn.active {
		background: linear-gradient(135deg, #ef4444, #dc2626); border-color: #dc2626; color: #fff;
		box-shadow: 0 4px 12px rgba(220, 38, 38, 0.35);
	}

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
	.summary-label { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.4px; color: #b91c1c; font-weight: 600; margin-bottom: 0.3rem; }
	.summary-value { font-size: 1.15rem; font-weight: 700; color: #7f1d1d; }

	.section-block {
		background: rgba(255, 255, 255, 0.5); backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
		border: 1px solid rgba(254, 202, 202, 0.6); border-radius: 16px; padding: 1rem 1.1rem;
		box-shadow: 0 8px 20px rgba(220, 38, 38, 0.06);
	}
	.section-title { margin: 0 0 0.75rem; font-size: 0.95rem; font-weight: 700; color: #7f1d1d; }

	/* flex:1/min-height:0 so this fills whatever height .scroll-area has available, rather than
	   growing to fit every row — that's what lets both columns below scroll independently. */
	.content-split { display: flex; gap: 1rem; align-items: stretch; flex: 1 1 auto; min-height: 0; }
	.table-column { flex: 0 0 70%; max-width: 70%; min-width: 0; display: flex; flex-direction: column; min-height: 0; }
	.cashier-column { flex: 0 0 30%; max-width: 30%; min-width: 0; display: flex; flex-direction: column; min-height: 0; }

	.cashier-card-list { display: flex; flex-direction: column; gap: 0.6rem; flex: 1 1 auto; min-height: 0; overflow-y: auto; }
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

	.table-wrapper { overflow: auto; border-radius: 12px; flex: 1 1 auto; min-height: 0; }
	table { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
	thead th {
		text-align: left; padding: 0.55rem 0.7rem; background: #fde2e2; color: #991b1b;
		font-weight: 700; text-transform: uppercase; font-size: 0.68rem; letter-spacing: 0.3px; position: sticky; top: 0; z-index: 1;
	}
	tbody td { padding: 0.5rem 0.7rem; border-bottom: 1px solid rgba(254, 202, 202, 0.4); color: #7f1d1d; }
	tbody tr.flagged-row { background: rgba(220, 38, 38, 0.08); }
	tbody tr.flagged-row td { font-weight: 600; }

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

	.flagger-desc { margin: 0 0 0.75rem; font-size: 0.8rem; color: #991b1b; opacity: 0.8; }
	.flagger-summary { margin-bottom: 0.75rem; font-weight: 700; color: #b91c1c; font-size: 0.85rem; }
	.flagger-summary.ok { color: #15803d; }
</style>
