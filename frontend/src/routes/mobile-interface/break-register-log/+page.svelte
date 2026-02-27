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

	// User's branch — mobile only shows own branch (unless admin)
	$: userBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
	$: isAdminOrMaster = $currentUser?.isMasterAdmin || $currentUser?.isAdmin || false;

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
		await Promise.all([loadBreaks(), loadBranches()]);
	});

	onDestroy(() => {
		if (tickInterval) clearInterval(tickInterval);
	});

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
		// Admins see all branches; regular users see only their branch
		if (!isAdminOrMaster && userBranchId) {
			params.p_branch_id = userBranchId;
		} else if (isAdminOrMaster && filterBranch) {
			params.p_branch_id = parseInt(filterBranch);
		}
		if (filterStatus) params.p_status = filterStatus;

		const { data, error } = await supabase.rpc('get_all_breaks', params);
		if (!error && data?.breaks) {
			breaks = data.breaks;
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

	function getBranchLocation(branchId: number): string {
		const br = branches.find(x => Number(x.id) === Number(branchId));
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
</script>

<div class="break-log-page" dir={isRtl ? 'rtl' : 'ltr'}>
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
			{#if isAdminOrMaster}
				<select bind:value={filterBranch} on:change={() => loadBreaks()} class="filter-select">
					<option value="">{t('All Branches', 'كل الفروع')}</option>
					{#each branches as branch}
						<option value={String(branch.id)}>{isRtl ? (branch.name_ar || branch.name_en) : (branch.name_en || branch.name_ar)}</option>
					{/each}
				</select>
			{/if}
		</div>
	</div>

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
		<!-- Grouped by date -->
		{#each groupedBreaks as group}
			<div class="date-group">
				<div class="date-header">
					<span>{group.label}</span>
					<span class="date-count">{group.breaks.length}</span>
				</div>
				{#each group.breaks as b}
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
								<span class="detail-icon">🏢</span>
								<span class="detail-text branch-block">
									<span class="branch-name">{getBranchName(b)}</span>
									{#if getBranchLocation(b.branch_id)}
										<span class="branch-location">{getBranchLocation(b.branch_id)}</span>
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
			</div>
		{/each}
	{/if}
</div>

<style>
	.break-log-page {
		padding: 16px;
		display: flex;
		flex-direction: column;
		gap: 12px;
		min-height: 100%;
		background: #f8fafc;
	}

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
