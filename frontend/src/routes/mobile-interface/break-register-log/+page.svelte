<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { localeData } from '$lib/i18n';
	import { goto } from '$app/navigation';

	let breaks: any[] = [];
	let loading = true;
	let now = Date.now();
	let tickInterval: ReturnType<typeof setInterval> | null = null;
	let branches: any[] = [];
	let filterBranch = '';
	let filterStatus = '';
	let searchQuery = '';

	// Tabs
	let activeTab: 'logs' | 'summary' = 'logs';

	// Summary state
	let summarySpecificDate = '';
	let summaryDateFrom = '';
	let summaryDateTo = '';
	let summaryData: any[] = [];
	let loadingSummary = false;
	let summaryLoaded = false;

	// User's branch — mobile only shows own branch (unless admin)
	$: userBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
	$: isAdminOrMaster = $currentUser?.isMasterAdmin || $currentUser?.isAdmin || false;

	// Break register permissions
	let canSeeBranchBreaks = false;
	let canSeeAllBreaks = false;

	$: isRtl = $localeData.code === 'ar';

	function t(en: string, ar: string): string {
		return isRtl ? ar : en;
	}

	// Compute last 3 days range (today, yesterday, day before)
	function getDateRange() {
		const today = new Date();
		const threeDaysAgo = new Date(today);
		threeDaysAgo.setDate(today.getDate() - 2);
		return {
			from: threeDaysAgo.toISOString().split('T')[0],
			to: today.toISOString().split('T')[0]
		};
	}

	$: filteredBreaks = breaks.filter(b => {
		if (filterStatus && b.status !== filterStatus) return false;
		if (filterBranch && String(b.branch_id) !== filterBranch) return false;
		if (searchQuery.trim()) {
			const s = searchQuery.toLowerCase();
			const match = (b.employee_id || '').toLowerCase().includes(s)
				|| (b.employee_name_en || '').toLowerCase().includes(s)
				|| (b.employee_name_ar || '').includes(s)
				|| (b.reason_en || '').toLowerCase().includes(s)
				|| (b.reason_ar || '').includes(s);
			if (!match) return false;
		}
		return true;
	});

	$: openBreaks = filteredBreaks.filter(b => b.status === 'open');

	// Live tick for open breaks
	$: if (openBreaks.length > 0 && !tickInterval) {
		tickInterval = setInterval(() => { now = Date.now(); }, 1000);
	} else if (openBreaks.length === 0 && tickInterval) {
		clearInterval(tickInterval);
		tickInterval = null;
	}

	onMount(async () => {
		if (!$currentUser?.id) {
			goto('/mobile-interface');
			return;
		}
		await Promise.all([loadPermissions(), loadBreaks(), loadBranches()]);
	});

	onDestroy(() => {
		if (tickInterval) clearInterval(tickInterval);
	});

	async function loadPermissions() {
		if (isAdminOrMaster) {
			// Admins always see everything
			canSeeBranchBreaks = true;
			canSeeAllBreaks = true;
			return;
		}
		const { data } = await supabase
			.from('break_register_permissions')
			.select('can_see_branch_breaks, can_see_all_breaks')
			.eq('user_id', $currentUser!.id)
			.maybeSingle();
		canSeeBranchBreaks = data?.can_see_branch_breaks ?? false;
		canSeeAllBreaks = data?.can_see_all_breaks ?? false;
	}

	async function loadBranches() {
		const { data } = await supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').eq('is_active', true).order('id');
		if (data) branches = data;
	}

	async function loadBreaks() {
		loading = true;
		const range = getDateRange();
		const params: any = {
			p_date_from: range.from,
			p_date_to: range.to
		};

		// Determine scope based on permissions
		if (canSeeAllBreaks || isAdminOrMaster) {
			// See all branches; optionally filter by selected branch
			if (filterBranch) params.p_branch_id = parseInt(filterBranch);
		} else if (canSeeBranchBreaks) {
			// See own branch only
			if (userBranchId) params.p_branch_id = userBranchId;
		} else {
			// Only own breaks — filter client-side after loading own branch
			if (userBranchId) params.p_branch_id = userBranchId;
		}

		if (filterStatus) params.p_status = filterStatus;

		const { data, error } = await supabase.rpc('get_all_breaks', params);
		if (!error && data?.breaks) {
			let result = data.breaks;
			// If user can only see own breaks, filter to current user
			if (!canSeeBranchBreaks && !canSeeAllBreaks && !isAdminOrMaster) {
				result = result.filter((b: any) => b.user_id === $currentUser?.id);
			}
			breaks = result;
		}
		loading = false;
	}

	function formatDuration(seconds: number | null): string {
		if (!seconds) return '—';
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		const s = seconds % 60;
		if (h > 0) return `${h}h ${m}m`;
		if (m > 0) return `${m}m ${s}s`;
		return `${s}s`;
	}

	function getLiveDuration(startTime: string, _now: number): string {
		const secs = Math.floor((_now - new Date(startTime).getTime()) / 1000);
		return formatDuration(secs > 0 ? secs : 0);
	}

	function formatTime(dt: string | null): string {
		if (!dt) return '—';
		const d = new Date(dt);
		return d.toLocaleTimeString(isRtl ? 'ar-EG' : 'en-US', {
			hour: '2-digit',
			minute: '2-digit',
			timeZone: 'Asia/Riyadh'
		});
	}

	function formatDate(dt: string | null): string {
		if (!dt) return '—';
		const d = new Date(dt);
		return d.toLocaleDateString(isRtl ? 'ar-EG' : 'en-US', {
			weekday: 'short',
			month: 'short',
			day: 'numeric',
			timeZone: 'Asia/Riyadh'
		});
	}

	function getBranchName(b: any): string {
		if (isRtl) return b.branch_name_ar || b.branch_name_en || '—';
		return b.branch_name_en || b.branch_name_ar || '—';
	}

	function getBranchLocation(b: any): string {
		// Try lookup by branch_id first
		let br = branches.find(x => Number(x.id) === Number(b.branch_id));
		// Fallback: try matching by branch name
		if (!br && b.branch_name_en) {
			br = branches.find(x => x.name_en === b.branch_name_en);
		}
		if (!br) return '';
		return isRtl ? (br.location_ar || br.location_en || '') : (br.location_en || br.location_ar || '');
	}

	// Group breaks by date
	$: groupedBreaks = (() => {
		const groups = new Map<string, any[]>();
		for (const b of filteredBreaks) {
			const dateKey = b.start_time ? new Date(b.start_time).toLocaleDateString(isRtl ? 'ar-EG' : 'en-US', {
				year: 'numeric', month: 'short', day: 'numeric', weekday: 'long', timeZone: 'Asia/Riyadh'
			}) : t('Unknown', 'غير معروف');
			const rawDate = b.start_time ? new Date(b.start_time).toISOString().split('T')[0] : '0000-00-00';
			const key = rawDate + '||' + dateKey;
			if (!groups.has(key)) groups.set(key, []);
			groups.get(key)!.push(b);
		}
		// Sort by date descending
		return Array.from(groups.entries())
			.sort((a, b) => b[0].localeCompare(a[0]))
			.map(([key, items]) => ({
				label: key.split('||')[1],
				breaks: items
			}));
	})();

	async function loadSummary() {
		loadingSummary = true;
		summaryLoaded = false;
		try {
			const params: any = {};
			if (summarySpecificDate) {
				params.p_date_from = summarySpecificDate;
				params.p_date_to = summarySpecificDate;
			} else {
				if (summaryDateFrom) params.p_date_from = summaryDateFrom;
				if (summaryDateTo) params.p_date_to = summaryDateTo;
			}
			const { data, error } = await supabase.rpc('get_break_summary_all_employees', params);
			if (!error && data?.employees) {
				// Compute total_breaks from days array
				summaryData = (data.employees as any[]).map(emp => ({
					...emp,
					total_breaks: (emp.days || []).reduce((s: number, d: any) => s + (d.break_count || 0), 0)
				})).filter(emp => emp.total_breaks > 0 || (emp.grand_total_seconds || 0) > 0);
			} else {
				summaryData = [];
			}
		} catch (err) {
			console.error('Error loading summary:', err);
			summaryData = [];
		} finally {
			loadingSummary = false;
			summaryLoaded = true;
		}
	}

	function formatSummaryDuration(seconds: number): string {
		if (!seconds || seconds === 0) return '—';
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		if (h > 0) return `${h}h ${m}m`;
		return `${m}m`;
	}

	function switchTab(tab: 'logs' | 'summary') {
		activeTab = tab;
		if (tab === 'summary' && !summaryLoaded && !loadingSummary) {
			// Auto-load today
			const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Riyadh' });
			summarySpecificDate = today;
			summaryDateFrom = '';
			summaryDateTo = '';
			loadSummary();
		}
	}
</script>

<div class="break-log-page" dir={isRtl ? 'rtl' : 'ltr'}>

	<!-- Sticky Top: Tab Switcher always visible -->
	<div class="sticky-top">
		<!-- Tab Switcher -->
		<div class="tab-row">
			<button class="tab-btn {activeTab === 'logs' ? 'tab-active' : ''}" on:click={() => switchTab('logs')}>
				☕ {t('Logs', 'السجلات')}
			</button>
			{#if canSeeAllBreaks || isAdminOrMaster}
				<button class="tab-btn {activeTab === 'summary' ? 'tab-active' : ''}" on:click={() => switchTab('summary')}>
					📊 {t('Summary', 'الملخص')}
				</button>
			{/if}
		</div>

		{#if activeTab === 'logs'}
		<!-- 3-Day Notice -->
		<div class="three-day-notice">
			<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
			<span>{t('Showing last 3 days only', 'عرض آخر 3 أيام فقط')}</span>
		</div>

		<!-- Stats Row -->
		<div class="stats-row">
			<div class="stat-card stat-open">
				<span class="stat-number">{openBreaks.length}</span>
				<span class="stat-label">{t('Open', 'مفتوحة')}</span>
			</div>
			<div class="stat-card stat-total">
				<span class="stat-number">{filteredBreaks.length}</span>
				<span class="stat-label">{t('Total', 'الإجمالي')}</span>
			</div>
		</div>

		<!-- Filters -->
		<div class="filters">
			<input
				type="text"
				bind:value={searchQuery}
				placeholder={t('Search employee...', 'بحث عن موظف...')}
				class="filter-input"
			/>
			<div class="filter-row">
				<select bind:value={filterStatus} on:change={() => loadBreaks()} class="filter-select">
					<option value="">{t('All Status', 'كل الحالات')}</option>
					<option value="open">{t('Open', 'مفتوحة')}</option>
					<option value="closed">{t('Closed', 'مغلقة')}</option>
				</select>
				{#if isAdminOrMaster || canSeeAllBreaks}
					<select bind:value={filterBranch} on:change={() => loadBreaks()} class="filter-select">
						<option value="">{t('All Branches', 'كل الفروع')}</option>
						{#each branches as branch}
							<option value={String(branch.id)}>{isRtl ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar)}</option>
						{/each}
					</select>
				{/if}
			</div>
		</div>
		{/if}

		{#if activeTab === 'summary' && (canSeeAllBreaks || isAdminOrMaster)}
		<div class="summary-filters">
			<div class="summary-filter-row">
				<label class="summary-label">{t('Specific Date', 'تاريخ محدد')}</label>
				<input type="date" bind:value={summarySpecificDate} class="summary-input"
					on:change={() => { summaryDateFrom = ''; summaryDateTo = ''; }} />
			</div>
			<div class="summary-filter-row">
				<label class="summary-label">{t('Date Range', 'نطاق التاريخ')}</label>
				<div class="summary-range">
					<input type="date" bind:value={summaryDateFrom} class="summary-input"
						on:change={() => summarySpecificDate = ''} placeholder={t('From', 'من')} />
					<input type="date" bind:value={summaryDateTo} class="summary-input"
						on:change={() => summarySpecificDate = ''} placeholder={t('To', 'إلى')} />
				</div>
			</div>
			<button class="load-summary-btn" on:click={loadSummary} disabled={loadingSummary}>
				{loadingSummary ? t('Loading...', 'جاري التحميل...') : t('Load Summary', 'تحميل الملخص')}
			</button>
		</div>
		{/if}
	</div>

	<!-- Scrollable Content -->
	<div class="scroll-content">
		{#if activeTab === 'logs'}
		{#if loading}
			<div class="loading-container">
				<div class="spinner"></div>
				<p>{t('Loading...', 'جاري التحميل...')}</p>
			</div>
		{:else if filteredBreaks.length === 0}
			<div class="empty-state">
				<span class="empty-icon">☕</span>
				<p>{t('No breaks found', 'لا توجد استراحات')}</p>
				<span class="empty-sub">{t('Last 3 days', 'آخر 3 أيام')}</span>
			</div>
		{:else}
			<!-- Flat list -->
			{#each filteredBreaks as b}
					<div class="break-card {b.status === 'open' ? 'break-open' : ''}">
							<div class="break-top">
								<div class="employee-info">
									<span class="employee-name">{isRtl ? (b.employee_name_ar || b.employee_name_en) : (b.employee_name_en || b.employee_name_ar)}</span>
									<span class="employee-id">{b.employee_id}</span>
								</div>
								<div class="break-status">
									{#if b.status === 'open'}
										<span class="status-badge status-open">{t('Open', 'مفتوحة')}</span>
									{:else}
										<span class="status-badge status-closed">{t('Closed', 'مغلقة')}</span>
									{/if}
								</div>
							</div>
							<div class="break-details">
								<div class="detail-item">
									<span class="detail-icon">📅</span>
									<span class="detail-text">{b.start_time ? new Date(b.start_time).toLocaleDateString(isRtl ? 'ar-EG' : 'en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—'}</span>
								</div>
								<div class="detail-item">
									<span class="detail-icon">🏢</span>
									<span class="detail-text branch-block">
										<span class="branch-name">{getBranchName(b)}</span>
										{#if getBranchLocation(b)}
											<span class="branch-location">{getBranchLocation(b)}</span>
										{/if}
									</span>
								</div>
								<div class="detail-item">
									<span class="detail-icon">📌</span>
									<span class="detail-text">{isRtl ? (b.reason_ar || b.reason_en || '—') : (b.reason_en || b.reason_ar || '—')}</span>
								</div>
								{#if b.reason_note}
									<div class="detail-item">
										<span class="detail-icon">📝</span>
										<span class="detail-text note">{b.reason_note}</span>
									</div>
								{/if}
							</div>
							<div class="break-times">
								<div class="time-item">
									<span class="time-label">{t('Start', 'بداية')}</span>
									<span class="time-value">{formatTime(b.start_time)}</span>
								</div>
								<div class="time-item">
									<span class="time-label">{t('End', 'نهاية')}</span>
									<span class="time-value">{b.end_time ? formatTime(b.end_time) : '—'}</span>
								</div>
								<div class="time-item duration {b.status === 'open' ? 'live' : ''}">
									<span class="time-label">{t('Duration', 'المدة')}</span>
									<span class="time-value">{b.status === 'open' ? getLiveDuration(b.start_time, now) : formatDuration(b.duration_seconds)}</span>
								</div>
							</div>
					</div>
			{/each}
		{/if}
		{/if}

		<!-- SUMMARY TAB -->
		{#if activeTab === 'summary' && (canSeeAllBreaks || isAdminOrMaster)}
			{#if loadingSummary}
				<div class="loading-container">
					<div class="spinner"></div>
					<p>{t('Loading summary...', 'جاري تحميل الملخص...')}</p>
				</div>
			{:else if summaryLoaded && summaryData.length === 0}
				<div class="empty-state">
					<span class="empty-icon">📊</span>
					<p>{t('No data found', 'لا توجد بيانات')}</p>
				</div>
			{:else if summaryLoaded}
				<div class="summary-list">
					{#each summaryData as emp}
						<div class="summary-card">
							<div class="summary-emp-name">{isRtl ? (emp.employee_name_ar || emp.employee_name_en) : (emp.employee_name_en || emp.employee_name_ar)}</div>
							<div class="summary-emp-id">{emp.employee_id}</div>
							<div class="summary-stats">
								<div class="summary-stat">
									<span class="summary-stat-label">{t('Total Breaks', 'إجمالي الاستراحات')}</span>
									<span class="summary-stat-val">{emp.total_breaks ?? 0}</span>
								</div>
								<div class="summary-stat">
									<span class="summary-stat-label">{t('Total Duration', 'إجمالي المدة')}</span>
									<span class="summary-stat-val">{formatSummaryDuration(emp.grand_total_seconds ?? 0)}</span>
								</div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		{/if}
	</div>

</div>

<style>
	.break-log-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: hidden;
		background: #f8fafc;
	}
	.sticky-top {
		flex-shrink: 0;
		background: #f8fafc;
		padding: 12px 16px 0;
		z-index: 10;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.scroll-content {
		flex: 1;
		overflow-y: auto;
		padding: 12px 16px 24px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	/* Tabs */
	.tab-row {
		display: flex;
		gap: 8px;
		background: #f1f5f9;
		border-radius: 12px;
		padding: 4px;
	}
	.tab-btn {
		flex: 1;
		padding: 8px 0;
		border: none;
		border-radius: 9px;
		background: transparent;
		font-size: 13px;
		font-weight: 700;
		color: #64748b;
		cursor: pointer;
		transition: all 0.2s;
	}
	.tab-btn.tab-active {
		background: #fff;
		color: #1e293b;
		box-shadow: 0 1px 4px rgba(0,0,0,0.1);
	}

	/* Summary */
	.summary-filters {
		display: flex;
		flex-direction: column;
		gap: 10px;
		background: #fff;
		border-radius: 14px;
		padding: 14px;
		box-shadow: 0 1px 4px rgba(0,0,0,0.07);
	}
	.summary-filter-row {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.summary-label {
		font-size: 11px;
		font-weight: 700;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	.summary-input {
		padding: 8px 10px;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		font-size: 13px;
		color: #1e293b;
		background: #f8fafc;
		width: 100%;
		box-sizing: border-box;
	}
	.summary-range {
		display: flex;
		gap: 8px;
	}
	.summary-range .summary-input {
		flex: 1;
	}
	.load-summary-btn {
		padding: 10px;
		background: #6366f1;
		color: #fff;
		border: none;
		border-radius: 10px;
		font-size: 14px;
		font-weight: 700;
		cursor: pointer;
		transition: background 0.2s;
	}
	.load-summary-btn:disabled { opacity: 0.6; cursor: not-allowed; }
	.load-summary-btn:not(:disabled):hover { background: #4f46e5; }
	.summary-list {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.summary-card {
		background: #fff;
		border-radius: 14px;
		padding: 14px;
		box-shadow: 0 1px 4px rgba(0,0,0,0.07);
	}
	.summary-emp-name {
		font-size: 15px;
		font-weight: 700;
		color: #1e293b;
	}
	.summary-emp-id {
		font-size: 11px;
		color: #94a3b8;
		margin-bottom: 10px;
	}
	.summary-stats {
		display: flex;
		gap: 10px;
	}
	.summary-stat {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		background: #f8fafc;
		border-radius: 8px;
		padding: 8px 4px;
	}
	.summary-stat-label {
		font-size: 9px;
		font-weight: 700;
		color: #94a3b8;
		text-transform: uppercase;
		text-align: center;
	}
	.summary-stat-val {
		font-size: 16px;
		font-weight: 800;
		color: #1e293b;
		margin-top: 2px;
	}
	.summary-stat-val.open-val { color: #ef4444; }

	/* 3-Day Notice */
	.three-day-notice {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 14px;
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 12px;
		color: #1d4ed8;
		font-size: 13px;
		font-weight: 500;
		margin-bottom: 10px;
	}
	.three-day-notice svg {
		flex-shrink: 0;
	}

	/* Stats */
	.stats-row {
		display: flex;
		gap: 10px;
	}
	.stat-card {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 12px 8px;
		border-radius: 16px;
		background: white;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
	}
	.stat-number {
		font-size: 28px;
		font-weight: 900;
		line-height: 1;
	}
	.stat-label {
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #64748b;
		margin-top: 4px;
	}
	.stat-open .stat-number { color: #059669; }
	.stat-total .stat-number { color: #2563eb; }

	/* Filters */
	.filters {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.filter-input {
		width: 100%;
		padding: 10px 14px;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		font-size: 14px;
		background: white;
		color: #1e293b;
		outline: none;
		transition: border-color 0.2s;
	}
	.filter-input:focus {
		border-color: #10b981;
	}
	.filter-input::placeholder {
		color: #94a3b8;
	}
	.filter-row {
		display: flex;
		gap: 8px;
	}
	.filter-select {
		flex: 1;
		padding: 10px 14px;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		font-size: 13px;
		background: white;
		color: #1e293b;
		outline: none;
		appearance: auto;
		transition: border-color 0.2s;
	}
	.filter-select:focus {
		border-color: #10b981;
	}

	/* Loading */
	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px 0;
		gap: 12px;
		color: #64748b;
		font-weight: 600;
	}
	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #d1fae5;
		border-top: 4px solid #059669;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Empty state */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px 16px;
		gap: 8px;
	}
	.empty-icon {
		font-size: 48px;
	}
	.empty-state p {
		font-size: 16px;
		font-weight: 700;
		color: #475569;
	}
	.empty-sub {
		font-size: 13px;
		color: #94a3b8;
	}

	/* Date groups */
	.date-group {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.date-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 4px;
		font-size: 13px;
		font-weight: 800;
		color: #334155;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		border-bottom: 2px solid #e2e8f0;
	}
	.date-count {
		background: #e2e8f0;
		color: #475569;
		font-size: 11px;
		font-weight: 800;
		padding: 2px 8px;
		border-radius: 999px;
	}

	/* Break cards */
	.break-card {
		background: white;
		border-radius: 16px;
		padding: 14px;
		box-shadow: 0 2px 8px rgba(0,0,0,0.05);
		border: 1px solid #f1f5f9;
		display: flex;
		flex-direction: column;
		gap: 10px;
		transition: transform 0.15s;
	}
	.break-card.break-open {
		border-left: 4px solid #10b981;
		background: linear-gradient(135deg, #f0fdf4, #ffffff);
	}
	[dir="rtl"] .break-card.break-open {
		border-left: none;
		border-right: 4px solid #10b981;
	}

	.break-top {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 8px;
	}
	.employee-info {
		display: flex;
		flex-direction: column;
	}
	.employee-name {
		font-size: 15px;
		font-weight: 800;
		color: #1e293b;
	}
	.employee-id {
		font-size: 11px;
		font-family: monospace;
		color: #94a3b8;
	}

	.status-badge {
		font-size: 10px;
		font-weight: 800;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		padding: 4px 10px;
		border-radius: 999px;
	}
	.status-open {
		background: #d1fae5;
		color: #065f46;
	}
	.status-closed {
		background: #e2e8f0;
		color: #475569;
	}

	.break-details {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}
	.detail-item {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 13px;
		color: #475569;
	}
	.detail-icon {
		font-size: 12px;
		flex-shrink: 0;
	}
	.detail-text.note {
		font-style: italic;
		color: #64748b;
	}
	.branch-block {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}
	.branch-name {
		font-weight: 600;
		color: #334155;
	}
	.branch-location {
		font-size: 11px;
		color: #94a3b8;
		font-weight: 400;
	}

	.break-times {
		display: flex;
		gap: 6px;
		padding-top: 8px;
		border-top: 1px solid #f1f5f9;
	}
	.time-item {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
	}
	.time-label {
		font-size: 10px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #94a3b8;
	}
	.time-value {
		font-size: 14px;
		font-weight: 700;
		font-family: monospace;
		color: #1e293b;
	}
	.time-item.duration.live .time-value {
		color: #dc2626;
		animation: pulse-text 1s ease-in-out infinite;
	}

	@keyframes pulse-text {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.6; }
	}
</style>
