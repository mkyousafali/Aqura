<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

	export let windowId: string;

	let loading = true;
	let employees: any[] = [];
	let branches: any[] = [];
	let searchQuery = '';
	let selectedBranch = '';
	let todayStr = '';
	let yesterdayStr = '';
	let now = Date.now();
	let tickInterval: ReturnType<typeof setInterval> | null = null;
	let pollInterval: ReturnType<typeof setInterval> | null = null;
	let realtimeChannel: any = null;
	let lastRefreshed = Date.now();

	// Map: employee id (string) → { attendanceToday, attendanceYesterday, breakTodaySecs, breakYesterdaySecs, activeBreak, pendingTasks }
	let employeeDataMap: Record<string, any> = {};

	$: isRtl = $locale === 'ar';

	$: filteredEmployees = employees
		.filter(e => {
			const q = searchQuery.toLowerCase();
			const matchName =
				!q ||
				(e.name_en || '').toLowerCase().includes(q) ||
				(e.name_ar || '').includes(searchQuery);
			const matchBranch = !selectedBranch || String(e.current_branch_id) === selectedBranch;
			return matchName && matchBranch;
		})
		.sort((a, b) => {
			const aOnBreak = !!(employeeDataMap[String(a.id)]?.activeBreak);
			const bOnBreak = !!(employeeDataMap[String(b.id)]?.activeBreak);
			if (aOnBreak && !bOnBreak) return -1;
			if (!aOnBreak && bOnBreak) return 1;
			return 0;
		});

	onMount(async () => {
		const d = new Date();
		const yest = new Date(d);
		yest.setDate(yest.getDate() - 1);
		todayStr = d.toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' });
		yesterdayStr = yest.toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' });
		await loadData();

		// Live second ticker for break timers
		tickInterval = setInterval(() => { now = Date.now(); }, 1000);

		// Realtime: watch break_register, attendance, and task tables
		setupRealtimeChannel();

		// Poll fallback every 30s for missed events
		pollInterval = setInterval(() => silentRefresh(), 30_000);
	});

	onDestroy(() => {
		if (tickInterval) clearInterval(tickInterval);
		if (pollInterval) clearInterval(pollInterval);
		if (realtimeChannel) supabase.removeChannel(realtimeChannel);
	});

	function setupRealtimeChannel() {
		if (realtimeChannel) supabase.removeChannel(realtimeChannel);
		realtimeChannel = supabase
			.channel('quick-dashboard-live-' + Date.now())
			.on('postgres_changes', { event: '*', schema: 'public', table: 'break_register' }, () => {
				silentRefresh();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'hr_analysed_attendance_data' }, () => {
				silentRefresh();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'task_assignments' }, () => {
				silentRefresh();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'quick_task_assignments' }, () => {
				silentRefresh();
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'receiving_tasks' }, () => {
				silentRefresh();
			})
			.subscribe();
	}

	/** Refresh data without showing the full loading spinner */
	async function silentRefresh() {
		// Debounce: skip if already refreshed within last 3s
		if (Date.now() - lastRefreshed < 3000) return;
		lastRefreshed = Date.now();
		await loadData(true);
	}

	async function loadData(silent = false) {
		if (!silent) loading = true;
		try {
			const [branchRes, empRes, attRes, breakSummaryRes, activeBreaksRes, taskRes, quickTaskRes, receivingTaskRes] = await Promise.all([
				supabase
					.from('branches')
					.select('id, name_en, name_ar, location_en, location_ar')
					.eq('is_active', true)
					.order('name_en'),
				supabase
					.from('hr_employee_master')
					.select('id, name_en, name_ar, current_branch_id, user_id')
					.in('employment_status', [
						'Job (With Finger)',
						'Job (Without Finger)',
						'Remote Job',
						'Active'
					])
					.order('name_en'),
				supabase
					.from('hr_analysed_attendance_data')
					.select(
						'employee_id, shift_date, status, check_in_time, check_out_time, late_minutes, shift_end_time, shift_start_time'
					)
					.in('shift_date', [todayStr, yesterdayStr]),
				supabase.rpc('get_break_summary_all_employees', {
					p_date_from: yesterdayStr,
					p_date_to: todayStr
				}),
				supabase.rpc('get_all_breaks', {
					p_date_from: todayStr,
					p_date_to: todayStr
				}),
				supabase
					.from('task_assignments')
					.select('assigned_to_user_id')
					.not('status', 'in', '(completed,cancelled)'),
				supabase
					.from('quick_task_assignments')
					.select('assigned_to_user_id')
					.not('status', 'in', '(completed,cancelled)'),
				supabase
					.from('receiving_tasks')
					.select('assigned_user_id')
					.eq('task_completed', false)
					.neq('task_status', 'completed')
			]);

			branches = branchRes.data || [];
			employees = empRes.data || [];

			// Attendance map: id → { today, yesterday }
			const attMap: Record<string, { today: any; yesterday: any }> = {};
			for (const row of attRes.data || []) {
				const id = String(row.employee_id);
				if (!attMap[id]) attMap[id] = { today: null, yesterday: null };
				if (row.shift_date === todayStr) attMap[id].today = row;
				else attMap[id].yesterday = row;
			}

			// Break totals map: id → { todaySecs, yesterdaySecs }
			const breakMap: Record<string, { todaySecs: number; yesterdaySecs: number }> = {};
			for (const emp of breakSummaryRes.data?.employees || []) {
				const id = String(emp.employee_id);
				const todayDay = (emp.days || []).find((d: any) => d.date === todayStr);
				const yestDay = (emp.days || []).find((d: any) => d.date === yesterdayStr);
				breakMap[id] = {
					todaySecs: todayDay?.total_seconds || 0,
					yesterdaySecs: yestDay?.total_seconds || 0
				};
			}

			// Active breaks map: employee_id → break record (open status)
			const activeMap: Record<string, any> = {};
			for (const b of activeBreaksRes.data?.breaks || []) {
				if (b.status === 'open' && b.employee_id) {
					activeMap[String(b.employee_id)] = b;
				}
			}

			// Pending tasks map: user_id → count
			const taskCountMap: Record<string, number> = {};
			for (const row of taskRes.data || []) {
				if (!row.assigned_to_user_id) continue;
				const uid = String(row.assigned_to_user_id);
				taskCountMap[uid] = (taskCountMap[uid] || 0) + 1;
			}
			for (const row of quickTaskRes.data || []) {
				if (!row.assigned_to_user_id) continue;
				const uid = String(row.assigned_to_user_id);
				taskCountMap[uid] = (taskCountMap[uid] || 0) + 1;
			}
			for (const row of receivingTaskRes.data || []) {
				if (!row.assigned_user_id) continue;
				const uid = String(row.assigned_user_id);
				taskCountMap[uid] = (taskCountMap[uid] || 0) + 1;
			}

			// Build final map
			const map: Record<string, any> = {};
			for (const emp of employees) {
				const id = String(emp.id);
				const att = attMap[id] || { today: null, yesterday: null };
				const brk = breakMap[id] || { todaySecs: 0, yesterdaySecs: 0 };
				map[id] = {
					attendanceToday: att.today,
					attendanceYesterday: att.yesterday,
					breakTodaySecs: brk.todaySecs,
					breakYesterdaySecs: brk.yesterdaySecs,
					activeBreak: activeMap[id] || null,
					pendingTasks: taskCountMap[emp.user_id] || 0
				};
			}
			employeeDataMap = map;
		} catch (e) {
			console.error('QuickDashboard load error:', e);
		} finally {
			loading = false;
		}
	}

	// ─── Helpers ─────────────────────────────────────────────────────────────────

	function formatBreak(secs: number): string {
		if (!secs || secs <= 0) return '—';
		const h = Math.floor(secs / 3600);
		const m = Math.floor((secs % 3600) / 60);
		if (h > 0) return `${h}h ${m.toString().padStart(2, '0')}m`;
		if (m > 0) return `${m}m`;
		return `${secs % 60}s`;
	}

	function formatLiveTimer(startTime: string, _now: number): string {
		const secs = Math.floor((_now - new Date(startTime).getTime()) / 1000);
		if (secs <= 0) return '00:00:00';
		const h = Math.floor(secs / 3600);
		const m = Math.floor((secs % 3600) / 60);
		const s = secs % 60;
		return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
	}

	function to12h(time: string | null): string {
		if (!time) return '';
		const [h, m] = time.split(':').map(Number);
		const ampm = h >= 12 ? 'PM' : 'AM';
		const h12 = h % 12 || 12;
		return `${h12}:${m.toString().padStart(2, '0')} ${ampm}`;
	}

	const STATUS_COLOR: Record<string, string> = {
		Worked: '#10B981',
		Absent: '#EF4444',
		'Official Day Off': '#6366F1',
		'Check-In Missing': '#F59E0B',
		'Check-Out Missing': '#F59E0B'
	};

	function statusColor(status: string): string {
		if (!status) return '#9CA3AF';
		if (status.includes('Leave')) return '#8B5CF6';
		return STATUS_COLOR[status] || '#9CA3AF';
	}

	const AR_STATUS: Record<string, string> = {
		Worked: 'حاضر',
		Absent: 'غائب',
		'Official Day Off': 'إجازة رسمية',
		'Check-In Missing': 'دخول مفقود',
		'Check-Out Missing': 'خروج مفقود',
		'Approved Leave (No Deduction)': 'إجازة بدون خصم',
		'Approved Leave (Deductible)': 'إجازة مع خصم',
		'Pending Approval': 'بانتظار الموافقة'
	};

	function displayStatus(status: string): string {
		if (!status) return '—';
		return isRtl ? AR_STATUS[status] || status : status;
	}

	/** Mirror mobile page logic: if shift end hasn't passed, Absent/Missing → 'Not yet' */
	function isTodayShiftEndPassed(att: any): boolean {
		if (!att?.shift_end_time) return false;
		// Detect overnight shift: end time is earlier than start time (e.g. 20:00→08:00)
		if (att.shift_start_time && att.shift_end_time < att.shift_start_time) return false;
		const nowSaudi = new Date().toLocaleTimeString('en-GB', {
			hour: '2-digit', minute: '2-digit', second: '2-digit',
			hour12: false, timeZone: 'Asia/Riyadh'
		});
		return nowSaudi >= att.shift_end_time.slice(0, 8);
	}

	function getTodayDisplayStatus(att: any): string {
		if (!att) return '—';
		const isNotFinal = att.status === 'Absent' || att.status?.includes('Missing');
		if (isNotFinal && !isTodayShiftEndPassed(att)) {
			return isRtl ? 'لم يحن الوقت بعد' : 'Not yet';
		}
		return displayStatus(att.status);
	}

	function getTodayStatusColor(att: any): string {
		if (!att) return '#9CA3AF';
		const isNotFinal = att.status === 'Absent' || att.status?.includes('Missing');
		if (isNotFinal && !isTodayShiftEndPassed(att)) return '#94a3b8'; // grey for not yet
		return statusColor(att.status);
	}

	function getBranchName(id: any): string {
		const b = branches.find((br) => String(br.id) === String(id));
		if (!b) return '';
		const name = isRtl ? b.name_ar || b.name_en : b.name_en || b.name_ar;
		const loc = isRtl ? b.location_ar || b.location_en : b.location_en || b.location_ar;
		return loc ? `${name} - ${loc}` : name;
	}

	function empName(emp: any): string {
		return isRtl ? emp.name_ar || emp.name_en : emp.name_en || emp.name_ar;
	}

	function initials(emp: any): string {
		const name = emp.name_en || emp.name_ar || '';
		return name
			.split(' ')
			.slice(0, 2)
			.map((w: string) => w[0] || '')
			.join('')
			.toUpperCase();
	}
</script>

<div class="qd-window" dir={isRtl ? 'rtl' : 'ltr'}>
	<!-- Toolbar -->
	<div class="qd-toolbar">
		<div class="qd-toolbar-left">
			<span class="qd-icon">📊</span>
			<span class="qd-title">{isRtl ? 'لوحة المتابعة السريعة' : 'Quick Dashboard'}</span>
			{#if !loading}
				<span class="qd-count">{filteredEmployees.length} {isRtl ? 'موظف' : 'employees'}</span>
			{/if}
			<span class="live-dot" title={isRtl ? 'مباشر' : 'Live'}>
				<span class="live-pulse"></span>
				{isRtl ? 'مباشر' : 'LIVE'}
			</span>
		</div>
		<div class="qd-toolbar-right">
			<select class="qd-select" bind:value={selectedBranch}>
				<option value="">{isRtl ? 'جميع الفروع' : 'All Branches'}</option>
				{#each branches as br}
					<option value={String(br.id)}>
						{isRtl ? br.name_ar || br.name_en : br.name_en || br.name_ar}
					</option>
				{/each}
			</select>
			<div class="qd-search-wrap">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
				</svg>
				<input
					class="qd-search"
					placeholder={isRtl ? 'بحث عن موظف...' : 'Search employee...'}
					bind:value={searchQuery}
				/>
			</div>
			<button class="qd-refresh" on:click={() => loadData()} title={isRtl ? 'تحديث' : 'Refresh'}>
				<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<polyline points="23 4 23 10 17 10" />
					<polyline points="1 20 1 14 7 14" />
					<path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
				</svg>
			</button>
		</div>
	</div>

	<!-- Date Strip -->
	<div class="qd-date-strip">
		<span class="qd-date-badge today-badge">
			📅 {isRtl ? 'اليوم' : 'Today'} — {todayStr}
		</span>
		<span class="qd-date-badge yest-badge">
			📅 {isRtl ? 'أمس' : 'Yesterday'} — {yesterdayStr}
		</span>
		<span class="qd-date-badge break-badge">
			☕ {isRtl ? 'الاستراحة' : 'Break'}
		</span>
		<span class="qd-date-badge task-badge">
			⏳ {isRtl ? 'المهام المعلقة' : 'Pending Tasks'}
		</span>
	</div>

	<!-- Content -->
	{#if loading}
		<div class="qd-loading">
			<div class="qd-spinner"></div>
			<p>{isRtl ? 'جاري التحميل...' : 'Loading...'}</p>
		</div>
	{:else if filteredEmployees.length === 0}
		<div class="qd-empty">
			<span>👤</span>
			<p>{isRtl ? 'لا يوجد موظفون' : 'No employees found'}</p>
		</div>
	{:else}
		<div class="qd-grid">
			{#each filteredEmployees as emp (emp.id)}
				{@const data = employeeDataMap[String(emp.id)] || {}}
				{@const att = data.attendanceToday}
				{@const attY = data.attendanceYesterday}
				{@const activeBreak = data.activeBreak}
				{@const pendingTasks = data.pendingTasks || 0}
				<div class="emp-card" class:on-break={activeBreak}>
					<!-- Card Header -->
					<div class="card-header">
						<div class="card-avatar">
							{initials(emp)}
						</div>
						<div class="card-info">
							<div class="card-name">{empName(emp)}</div>
							<div class="card-branch">{getBranchName(emp.current_branch_id)}</div>
						</div>
						<div class="card-badges">
							{#if pendingTasks > 0}
								<div class="task-count-pill" title={isRtl ? 'مهام معلقة' : 'Pending Tasks'}>
									⏳ {pendingTasks}
								</div>
							{/if}
							{#if activeBreak}
								<div class="active-break-dot" title={isRtl ? 'في استراحة' : 'On Break'}>☕</div>
							{/if}
						</div>
					</div>

					<!-- Attendance Rows -->
					<div class="att-rows">
						<!-- TODAY -->
						<div class="att-row">
							<div class="att-day-label today-label">{isRtl ? 'اليوم' : 'Today'}</div>
							{#if att}
								{@const sc = getTodayStatusColor(att)}
								<div class="att-status-badge" style="background: {sc}22; color: {sc}; border-color: {sc}44;">
									{getTodayDisplayStatus(att)}
								</div>
								{#if att.check_in_time}
									<div class="att-time">
										✅ {to12h(att.check_in_time)}{att.check_out_time ? ' → ' + to12h(att.check_out_time) : ''}
									</div>
								{/if}
								{#if att.late_minutes > 0}
									<div class="att-late">⏰ {att.late_minutes}{isRtl ? 'د' : 'm'}</div>
								{/if}
							{:else}
								<div class="att-nodata">—</div>
							{/if}
						</div>

						<!-- YESTERDAY -->
						<div class="att-row">
							<div class="att-day-label yest-label">{isRtl ? 'أمس' : 'Yest.'}</div>
							{#if attY}
								<div class="att-status-badge" style="background: {statusColor(attY.status)}22; color: {statusColor(attY.status)}; border-color: {statusColor(attY.status)}44;">
									{displayStatus(attY.status)}
								</div>
								{#if attY.check_in_time}
									<div class="att-time">
										✅ {to12h(attY.check_in_time)}{attY.check_out_time ? ' → ' + to12h(attY.check_out_time) : ''}
									</div>
								{/if}
								{#if attY.late_minutes > 0}
									<div class="att-late">⏰ {attY.late_minutes}{isRtl ? 'د' : 'm'}</div>
								{/if}
							{:else}
								<div class="att-nodata">—</div>
							{/if}
						</div>
					</div>

					<!-- Break Footer -->
					<div class="break-footer">
						<span class="break-icon">☕</span>
						<span class="break-part">
							<span class="break-label">{isRtl ? 'اليوم' : 'Today'}</span>
							<span class="break-val" class:has-break={data.breakTodaySecs > 0}>{formatBreak(data.breakTodaySecs)}</span>
						</span>
						<span class="break-divider">|</span>
						<span class="break-part">
							<span class="break-label">{isRtl ? 'أمس' : 'Yest.'}</span>
							<span class="break-val" class:has-break={data.breakYesterdaySecs > 0}>{formatBreak(data.breakYesterdaySecs)}</span>
						</span>
						{#if activeBreak}
							<span class="active-break-badge">
								☕ {formatLiveTimer(activeBreak.start_time, now)}
							</span>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	/* ─── Window Shell ─────────────────────────────────────────────────────────── */
	.qd-window {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: linear-gradient(135deg, #e0e7ff 0%, #f0f4ff 40%, #fdf4ff 100%);
		color: #1e293b;
		font-family: 'Inter', 'Segoe UI', sans-serif;
		overflow: hidden;
	}

	/* ─── Toolbar ──────────────────────────────────────────────────────────────── */
	.qd-toolbar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px;
		background: rgba(255, 255, 255, 0.55);
		backdrop-filter: blur(16px);
		-webkit-backdrop-filter: blur(16px);
		border-bottom: 1px solid rgba(148, 163, 184, 0.3);
		gap: 12px;
		flex-shrink: 0;
	}
	.qd-toolbar-left {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	.qd-toolbar-right {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	.qd-icon {
		font-size: 1.2rem;
	}
	.qd-title {
		font-size: 0.95rem;
		font-weight: 700;
		color: #1e293b;
	}
	.qd-count {
		font-size: 0.75rem;
		color: #64748b;
		background: rgba(100, 116, 139, 0.12);
		border: 1px solid rgba(100, 116, 139, 0.2);
		padding: 2px 8px;
		border-radius: 999px;
	}
	.live-dot {
		display: flex;
		align-items: center;
		gap: 5px;
		font-size: 0.65rem;
		font-weight: 800;
		letter-spacing: 0.8px;
		color: #059669;
		background: rgba(16, 185, 129, 0.1);
		border: 1px solid rgba(16, 185, 129, 0.3);
		padding: 2px 8px 2px 6px;
		border-radius: 999px;
	}
	.live-pulse {
		width: 7px;
		height: 7px;
		background: #10b981;
		border-radius: 50%;
		display: inline-block;
		animation: livepulse 1.4s ease-in-out infinite;
	}
	@keyframes livepulse {
		0%, 100% { opacity: 1; transform: scale(1); }
		50% { opacity: 0.4; transform: scale(0.7); }
	}
	.qd-select {
		background: rgba(255, 255, 255, 0.7);
		border: 1px solid rgba(148, 163, 184, 0.4);
		color: #1e293b;
		border-radius: 8px;
		padding: 5px 10px;
		font-size: 0.8rem;
		cursor: pointer;
		outline: none;
	}
	.qd-select:focus {
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
	}
	.qd-search-wrap {
		display: flex;
		align-items: center;
		gap: 6px;
		background: rgba(255, 255, 255, 0.7);
		border: 1px solid rgba(148, 163, 184, 0.4);
		border-radius: 8px;
		padding: 5px 10px;
	}
	.qd-search-wrap svg {
		color: #94a3b8;
		flex-shrink: 0;
	}
	.qd-search {
		background: transparent;
		border: none;
		outline: none;
		color: #1e293b;
		font-size: 0.8rem;
		width: 160px;
	}
	.qd-search::placeholder {
		color: #94a3b8;
	}
	.qd-refresh {
		background: rgba(255, 255, 255, 0.7);
		border: 1px solid rgba(148, 163, 184, 0.4);
		border-radius: 8px;
		padding: 6px 8px;
		color: #64748b;
		cursor: pointer;
		display: flex;
		align-items: center;
		transition: background 0.15s, box-shadow 0.15s;
	}
	.qd-refresh:hover {
		background: rgba(255, 255, 255, 0.95);
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		color: #1e293b;
	}

	/* ─── Date Strip ────────────────────────────────────────────────────────────── */
	.qd-date-strip {
		display: flex;
		gap: 8px;
		padding: 8px 16px;
		background: rgba(255, 255, 255, 0.4);
		backdrop-filter: blur(10px);
		-webkit-backdrop-filter: blur(10px);
		border-bottom: 1px solid rgba(148, 163, 184, 0.25);
		flex-shrink: 0;
		flex-wrap: wrap;
	}
	.qd-date-badge {
		font-size: 0.72rem;
		padding: 3px 10px;
		border-radius: 999px;
		font-weight: 600;
	}
	.today-badge {
		background: rgba(16, 185, 129, 0.12);
		color: #059669;
		border: 1px solid rgba(16, 185, 129, 0.3);
	}
	.yest-badge {
		background: rgba(99, 102, 241, 0.12);
		color: #6366f1;
		border: 1px solid rgba(99, 102, 241, 0.3);
	}
	.break-badge {
		background: rgba(245, 158, 11, 0.12);
		color: #d97706;
		border: 1px solid rgba(245, 158, 11, 0.3);
	}
	.task-badge {
		background: rgba(239, 68, 68, 0.1);
		color: #dc2626;
		border: 1px solid rgba(239, 68, 68, 0.25);
	}

	/* ─── States ────────────────────────────────────────────────────────────────── */
	.qd-loading,
	.qd-empty {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 12px;
		color: #64748b;
		font-size: 0.9rem;
	}
	.qd-loading span,
	.qd-empty span {
		font-size: 2rem;
	}
	.qd-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid rgba(148, 163, 184, 0.3);
		border-top-color: #6366f1;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* ─── Grid ──────────────────────────────────────────────────────────────────── */
	.qd-grid {
		flex: 1;
		overflow-y: auto;
		padding: 14px 16px;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 12px;
		align-content: start;
	}
	.qd-grid::-webkit-scrollbar { width: 6px; }
	.qd-grid::-webkit-scrollbar-track { background: transparent; }
	.qd-grid::-webkit-scrollbar-thumb { background: rgba(148, 163, 184, 0.4); border-radius: 3px; }

	/* ─── Employee Card ─────────────────────────────────────────────────────────── */
	.emp-card {
		background: rgba(255, 255, 255, 0.65);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		border: 1px solid rgba(148, 163, 184, 0.3);
		border-radius: 14px;
		overflow: visible;
		transition: border-color 0.2s, box-shadow 0.2s, transform 0.15s;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
	}
	.emp-card:hover {
		border-color: rgba(99, 102, 241, 0.4);
		box-shadow: 0 8px 24px rgba(99, 102, 241, 0.12);
		transform: translateY(-1px);
	}
	.emp-card.on-break {
		border-color: rgba(245, 158, 11, 0.5);
		box-shadow: 0 4px 16px rgba(245, 158, 11, 0.15);
	}

	/* Card Header */
	.card-header {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 12px 8px;
		border-bottom: 1px solid rgba(148, 163, 184, 0.2);
	}
	.card-avatar {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		background: linear-gradient(135deg, #6366f1, #8b5cf6);
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.7rem;
		font-weight: 700;
		color: #fff;
		flex-shrink: 0;
		letter-spacing: 0.5px;
		box-shadow: 0 2px 6px rgba(99, 102, 241, 0.35);
	}
	.card-info {
		flex: 1;
		min-width: 0;
	}
	.card-name {
		font-size: 0.82rem;
		font-weight: 700;
		color: #1e293b;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.card-branch {
		font-size: 0.7rem;
		color: #64748b;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.card-badges {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 4px;
		flex-shrink: 0;
	}
	.task-count-pill {
		font-size: 0.65rem;
		font-weight: 700;
		padding: 2px 7px;
		border-radius: 999px;
		background: rgba(239, 68, 68, 0.1);
		color: #dc2626;
		border: 1px solid rgba(239, 68, 68, 0.25);
		white-space: nowrap;
	}
	.active-break-dot {
		font-size: 1rem;
		flex-shrink: 0;
	}

	/* Attendance Rows */
	.att-rows {
		padding: 8px 12px 6px;
		display: flex;
		flex-direction: column;
		gap: 7px;
	}
	.att-row {
		display: flex;
		align-items: flex-start;
		gap: 6px;
		flex-wrap: wrap;
		min-height: 22px;
	}
	.att-day-label {
		font-size: 0.63rem;
		font-weight: 800;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		min-width: 36px;
		flex-shrink: 0;
		padding-top: 2px;
	}
	.today-label { color: #059669; }
	.yest-label { color: #6366f1; }

	.att-status-badge {
		font-size: 0.63rem;
		font-weight: 700;
		padding: 2px 8px;
		border-radius: 999px;
		border: 1px solid;
		white-space: nowrap;
	}
	.att-time {
		font-size: 0.64rem;
		color: #475569;
		white-space: nowrap;
	}
	.att-late {
		font-size: 0.62rem;
		color: #d97706;
		white-space: nowrap;
		font-weight: 600;
	}
	.att-nodata {
		font-size: 0.8rem;
		color: #94a3b8;
	}

	/* Break Footer */
	.break-footer {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 7px 12px 10px;
		border-top: 1px solid rgba(148, 163, 184, 0.2);
		flex-wrap: wrap;
		background: rgba(241, 245, 249, 0.5);
		border-radius: 0 0 14px 14px;
	}
	.break-icon {
		font-size: 0.8rem;
		flex-shrink: 0;
	}
	.break-part {
		display: flex;
		align-items: center;
		gap: 4px;
	}
	.break-label {
		font-size: 0.6rem;
		color: #94a3b8;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		font-weight: 600;
	}
	.break-val {
		font-size: 0.72rem;
		font-weight: 700;
		color: #94a3b8;
	}
	.break-val.has-break {
		color: #d97706;
	}
	.break-divider {
		color: #cbd5e1;
		font-size: 0.8rem;
	}
	.active-break-badge {
		margin-left: auto;
		font-size: 0.62rem;
		font-weight: 700;
		padding: 2px 8px;
		border-radius: 999px;
		background: rgba(245, 158, 11, 0.15);
		color: #d97706;
		border: 1px solid rgba(245, 158, 11, 0.35);
		white-space: nowrap;
		animation: pulse-badge 1.5s ease-in-out infinite;
	}
	@keyframes pulse-badge {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}
</style>
