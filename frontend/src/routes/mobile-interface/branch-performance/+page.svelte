<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { locale } from '$lib/i18n';

	let loading = true;
	let error = '';
	let daysBack = 30;
	let data: any = null;
	let filterMode: 'range' | 'today' | 'yesterday' | 'specific' = 'today';
	let specificDate = '';
	let showDatePicker = false;
	let showFilterPopup = false;
	let activeTab: 'overview' | 'branches' | 'employees' = 'branches';
	let empBranchFilter = 'all';
	let showBranchPopup = false;

	function selectBranch(val: string) {
		empBranchFilter = val;
		showBranchPopup = false;
	}

	function getBranchFilterLabel(): string {
		if (empBranchFilter === 'all') return isRTL ? 'كل الفروع' : 'All Branches';
		if (isRTL) {
			const found = branchStats.find((b: any) => b.branch_name_en === empBranchFilter);
			return found?.branch_name_ar || empBranchFilter;
		}
		return empBranchFilter;
	}

	$: isRTL = $locale === 'ar';
	$: filterLabel = (filterMode, daysBack, specificDate, isRTL, getFilterLabel());
	$: filterDateInfo = (filterMode, daysBack, specificDate, isRTL, getFilterDateInfo());

	onMount(async () => {
		await loadData();
	});

	function getToday(): string {
		return new Date().toISOString().split('T')[0];
	}

	function getYesterday(): string {
		const d = new Date();
		d.setDate(d.getDate() - 1);
		return d.toISOString().split('T')[0];
	}

	function selectToday() { filterMode = 'today'; showFilterPopup = false; showDatePicker = false; loadData(); }
	function selectYesterday() { filterMode = 'yesterday'; showFilterPopup = false; showDatePicker = false; loadData(); }
	function selectRange(days: number) { filterMode = 'range'; daysBack = days; showFilterPopup = false; showDatePicker = false; loadData(); }
	function selectSpecificDate() { if (!specificDate) return; filterMode = 'specific'; showFilterPopup = false; showDatePicker = false; loadData(); }

	function getFilterLabel(): string {
		if (filterMode === 'today') return isRTL ? 'اليوم' : 'Today';
		if (filterMode === 'yesterday') return isRTL ? 'أمس' : 'Yesterday';
		if (filterMode === 'specific') {
			const d = new Date(specificDate + 'T00:00:00');
			return d.toLocaleDateString(isRTL ? 'ar-SA' : 'en-US', { month: 'short', day: 'numeric' });
		}
		return isRTL ? `${daysBack} يوم` : `${daysBack}d`;
	}

	function getFilterDateInfo(): string {
		const loc = isRTL ? 'ar-SA' : 'en-US';
		const fmt: Intl.DateTimeFormatOptions = { weekday: 'short', month: 'short', day: 'numeric' };
		if (filterMode === 'today') return new Date().toLocaleDateString(loc, fmt);
		if (filterMode === 'yesterday') {
			const d = new Date(); d.setDate(d.getDate() - 1);
			return d.toLocaleDateString(loc, fmt);
		}
		if (filterMode === 'specific') {
			return new Date(specificDate + 'T00:00:00').toLocaleDateString(loc, fmt);
		}
		const from = new Date(); from.setDate(from.getDate() - daysBack);
		return `${from.toLocaleDateString(loc, { month: 'short', day: 'numeric' })} — ${new Date().toLocaleDateString(loc, { month: 'short', day: 'numeric' })}`;
	}

	async function loadData() {
		loading = true;
		error = '';
		try {
			const params: any = {};
			if (filterMode === 'today') params.p_specific_date = getToday();
			else if (filterMode === 'yesterday') params.p_specific_date = getYesterday();
			else if (filterMode === 'specific' && specificDate) params.p_specific_date = specificDate;
			else params.p_days_back = daysBack;
			const { data: result, error: err } = await supabase.rpc('get_branch_performance_dashboard', params);
			if (err) throw err;
			data = result;
		} catch (e: any) {
			console.error('Error loading branch performance:', e);
			error = e.message || 'Failed to load data';
		} finally {
			loading = false;
		}
	}

	const periods = [
		{ value: 7, label: '7d', labelAr: '7' },
		{ value: 14, label: '14d', labelAr: '14' },
		{ value: 30, label: '30d', labelAr: '30' },
		{ value: 60, label: '60d', labelAr: '60' },
		{ value: 90, label: '90d', labelAr: '90' }
	];

	function getBranchName(b: any) {
		if (isRTL) return b.branch_name_ar ? `${b.branch_name_ar}` : b.branch_name_en || '';
		return b.branch_name_en || '';
	}

	function getBranchLocation(b: any) {
		if (isRTL) return b.branch_location_ar || b.branch_location_en || '';
		return b.branch_location_en || b.branch_location_ar || '';
	}

	function getCompletionColor(rate: number) {
		if (rate >= 80) return '#22c55e';
		if (rate >= 60) return '#eab308';
		if (rate >= 40) return '#f97316';
		return '#ef4444';
	}

	function getEmpName(emp: any) {
		return isRTL ? (emp.name_ar || emp.name_en) : (emp.name_en || emp.name_ar);
	}

	function getEmpBranch(emp: any) {
		return isRTL ? (emp.branch_name_ar || emp.branch_name_en) : (emp.branch_name_en || emp.branch_name_ar);
	}

	function formatDay(dateStr: string) {
		const d = new Date(dateStr);
		return d.toLocaleDateString(isRTL ? 'ar-SA' : 'en-US', { month: 'short', day: 'numeric' });
	}

	function getDailyMax(daily: any[]) {
		if (!daily || daily.length === 0) return 10;
		return Math.max(...daily.map(d => Math.max(d.completed || 0, d.created || 0)), 10);
	}

	function getPieSlices(typeStats: any) {
		if (!typeStats) return [];
		const total = (typeStats.regular || 0) + (typeStats.quick || 0) + (typeStats.receiving || 0);
		if (total === 0) return [];
		const slices: any[] = [];
		let currentAngle = 0;
		const types = [
			{ key: 'regular', color: '#3b82f6', label: isRTL ? 'عادية' : 'Regular', count: typeStats.regular || 0 },
			{ key: 'quick', color: '#f59e0b', label: isRTL ? 'سريعة' : 'Quick', count: typeStats.quick || 0 },
			{ key: 'receiving', color: '#8b5cf6', label: isRTL ? 'استلام' : 'Receiving', count: typeStats.receiving || 0 }
		];
		for (const type of types) {
			if (type.count === 0) continue;
			const pct = type.count / total;
			const angle = pct * 360;
			const startAngle = currentAngle;
			const endAngle = currentAngle + angle;
			const x1 = 50 + 40 * Math.cos((startAngle - 90) * Math.PI / 180);
			const y1 = 50 + 40 * Math.sin((startAngle - 90) * Math.PI / 180);
			const x2 = 50 + 40 * Math.cos((endAngle - 90) * Math.PI / 180);
			const y2 = 50 + 40 * Math.sin((endAngle - 90) * Math.PI / 180);
			const largeArc = angle > 180 ? 1 : 0;
			slices.push({ ...type, pct: Math.round(pct * 100), path: `M 50 50 L ${x1} ${y1} A 40 40 0 ${largeArc} 1 ${x2} ${y2} Z` });
			currentAngle = endAngle;
		}
		return slices;
	}

	$: pieSlices = data ? getPieSlices(data.task_type_stats) : [];
	$: branchStats = data?.branch_stats || [];
	$: dailyStats = data?.daily_stats || [];
	$: topEmployees = data?.top_employees || [];
	$: filteredEmployees = empBranchFilter === 'all'
		? topEmployees
		: topEmployees.filter((e: any) => e.branch_name_en === empBranchFilter);
	$: availableBranches = [...new Set(topEmployees.map((e: any) => e.branch_name_en).filter(Boolean))] as string[];
	$: totals = data?.totals || {};
	$: completionRate = totals.total_tasks > 0 ? Math.round((totals.completed_tasks / totals.total_tasks) * 100) : 0;
	$: visibleDaily = dailyStats.length > 7 ? dailyStats.slice(-7) : dailyStats;
</script>

<div class="page" dir={isRTL ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="header">
		<div class="header-top">
			<div class="header-title">
				<span>📊</span>
				<h1>{isRTL ? 'أداء الفروع' : 'Branch Performance'}</h1>
			</div>
			<button class="refresh-btn" on:click={loadData} disabled={loading} aria-label="Refresh">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class:spinning={loading}>
					<polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
				</svg>
			</button>
		</div>
		<!-- Filter trigger button -->
		<button class="period-picker-btn" on:click={() => showFilterPopup = true}>
			<div class="period-picker-main">
				<span class="period-picker-icon">📆</span>
				<div class="period-picker-info">
					<span class="period-picker-label">{filterLabel}</span>
					<span class="period-picker-date">{filterDateInfo}</span>
				</div>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="6 9 12 15 18 9"/></svg>
			</div>
			<span class="period-picker-hint">{isRTL ? 'اضغط لتغيير الفترة ⟵' : '⟶ Tap to change period'}</span>
		</button>

		<!-- Filter Popup -->
		{#if showFilterPopup}
			<div class="popup-overlay" on:click|self={() => { showFilterPopup = false; showDatePicker = false; }} on:keydown={(e) => e.key === 'Escape' && (showFilterPopup = false)} role="dialog" aria-modal="true">
				<div class="popup-sheet">
					<div class="popup-handle"></div>
					<h3 class="popup-title">{isRTL ? 'اختر الفترة' : 'Select Period'}</h3>
					<div class="popup-list">
						<button class="popup-item {filterMode === 'today' ? 'popup-item-active' : ''}" on:click={selectToday}>
							<span class="popup-item-icon">🟢</span>
							<span class="popup-item-label">{isRTL ? 'اليوم' : 'Today'}</span>
							{#if filterMode === 'today'}<span class="popup-check">✓</span>{/if}
						</button>
						<button class="popup-item {filterMode === 'yesterday' ? 'popup-item-active' : ''}" on:click={selectYesterday}>
							<span class="popup-item-icon">🟡</span>
							<span class="popup-item-label">{isRTL ? 'أمس' : 'Yesterday'}</span>
							{#if filterMode === 'yesterday'}<span class="popup-check">✓</span>{/if}
						</button>
						<div class="popup-separator"></div>
						{#each periods as period}
							<button class="popup-item {filterMode === 'range' && daysBack === period.value ? 'popup-item-active' : ''}" on:click={() => selectRange(period.value)}>
								<span class="popup-item-icon">📅</span>
								<span class="popup-item-label">{isRTL ? `آخر ${period.labelAr} يوم` : `Last ${period.label}`}</span>
								{#if filterMode === 'range' && daysBack === period.value}<span class="popup-check">✓</span>{/if}
							</button>
						{/each}
						<div class="popup-separator"></div>
						<div class="popup-date-section">
							<p class="popup-date-label">{isRTL ? 'تاريخ محدد' : 'Specific Date'}</p>
							<input type="date" bind:value={specificDate} max={getToday()} class="date-input-popup" />
							<button class="date-apply-popup" disabled={!specificDate} on:click={selectSpecificDate}>{isRTL ? 'عرض' : 'Apply'}</button>
						</div>
					</div>
				</div>
			</div>
		{/if}
		<!-- Tabs -->
		<div class="tabs-row">
			<button class="tab-btn {activeTab === 'overview' ? 'tab-active' : ''}" on:click={() => activeTab = 'overview'}>{isRTL ? 'نظرة عامة' : 'Overview'}</button>
			<button class="tab-btn {activeTab === 'branches' ? 'tab-active' : ''}" on:click={() => activeTab = 'branches'}>{isRTL ? 'الفروع' : 'Branches'}</button>
			<button class="tab-btn {activeTab === 'employees' ? 'tab-active' : ''}" on:click={() => activeTab = 'employees'}>{isRTL ? 'الموظفين' : 'Employees'}</button>
		</div>
	</div>

	<!-- Content -->
	<div class="content">
		{#if loading}
			<div class="loading-box">
				<div class="spinner"></div>
				<p>{isRTL ? 'جاري التحميل...' : 'Loading...'}</p>
			</div>
		{:else if error}
			<div class="error-box">
				<p>{error}</p>
				<button on:click={loadData}>{isRTL ? 'إعادة المحاولة' : 'Retry'}</button>
			</div>
		{:else if data}
			{#if activeTab === 'overview'}
				<!-- KPI Cards -->
				<div class="kpi-grid">
					<div class="kpi-card blue">
						<p class="kpi-label">{isRTL ? 'إجمالي' : 'Total'}</p>
						<p class="kpi-value">{totals.total_tasks?.toLocaleString() || 0}</p>
						<p class="kpi-sub">{filterLabel}</p>
					</div>
					<div class="kpi-card green">
						<p class="kpi-label">{isRTL ? 'مكتمل' : 'Done'}</p>
						<p class="kpi-value">{totals.completed_tasks?.toLocaleString() || 0}</p>
						<p class="kpi-sub">{completionRate}%</p>
					</div>
					<div class="kpi-card amber">
						<p class="kpi-label">{isRTL ? 'معلق' : 'Pending'}</p>
						<p class="kpi-value">{totals.pending_tasks?.toLocaleString() || 0}</p>
					</div>
					<div class="kpi-card red">
						<p class="kpi-label">{isRTL ? 'متأخر' : 'Overdue'}</p>
						<p class="kpi-value">{totals.overdue_tasks?.toLocaleString() || 0}</p>
					</div>
				</div>

				<!-- Completion Gauge -->
				<div class="card">
					<div class="gauge-row">
						<div class="gauge-wrap">
							<svg viewBox="0 0 100 100" class="gauge-svg">
								<circle cx="50" cy="50" r="42" fill="none" stroke="#e2e8f0" stroke-width="8"/>
								<circle cx="50" cy="50" r="42" fill="none"
									stroke={getCompletionColor(completionRate)}
									stroke-width="8"
									stroke-dasharray="{completionRate * 2.64} 264"
									stroke-linecap="round"
									transform="rotate(-90 50 50)"
								/>
							</svg>
							<div class="gauge-text">
								<span class="gauge-pct" style="color: {getCompletionColor(completionRate)}">{completionRate}%</span>
							</div>
						</div>
						<div class="gauge-stats">
							<div class="gauge-stat"><span class="gs-val green-text">{totals.completed_tasks || 0}</span><span class="gs-lbl">{isRTL ? 'مكتمل' : 'Done'}</span></div>
							<div class="gauge-stat"><span class="gs-val amber-text">{totals.pending_tasks || 0}</span><span class="gs-lbl">{isRTL ? 'معلق' : 'Pending'}</span></div>
							<div class="gauge-stat"><span class="gs-val red-text">{totals.overdue_tasks || 0}</span><span class="gs-lbl">{isRTL ? 'متأخر' : 'Late'}</span></div>
							<div class="gauge-stat"><span class="gs-val violet-text">{totals.avg_completion_hours || 0}h</span><span class="gs-lbl">{isRTL ? 'متوسط' : 'Avg'}</span></div>
						</div>
					</div>
				</div>

				<!-- Task Type Pie -->
				<div class="card">
					<h3 class="card-title">{isRTL ? 'أنواع المهام' : 'Task Types'}</h3>
					<div class="pie-row">
						<svg viewBox="0 0 100 100" class="pie-svg">
							{#if pieSlices.length === 0}
								<circle cx="50" cy="50" r="40" fill="#e2e8f0"/>
							{:else}
								{#each pieSlices as slice}
									<path d={slice.path} fill={slice.color} opacity="0.85"/>
								{/each}
							{/if}
						</svg>
						<div class="pie-legend">
							{#each pieSlices as slice}
								<div class="legend-item">
									<span class="legend-dot" style="background: {slice.color}"></span>
									<span class="legend-label">{slice.label}</span>
									<span class="legend-count">{slice.count}</span>
									<span class="legend-pct">({slice.pct}%)</span>
								</div>
							{/each}
							{#if pieSlices.length === 0}
								<p class="no-data-text">{isRTL ? 'لا بيانات' : 'No data'}</p>
							{/if}
						</div>
					</div>
				</div>

				<!-- Daily Trend -->
				<div class="card">
					<h3 class="card-title">{isRTL ? 'الاتجاه اليومي' : 'Daily Trend'}</h3>
					{#if visibleDaily.length > 0}
						<div class="daily-chart-wrap">
							<svg viewBox="0 0 {visibleDaily.length * 46 + 20} 130" class="daily-svg">
								{#each visibleDaily as day, i}
									{@const barX = 10 + i * 46}
									{@const maxVal = getDailyMax(visibleDaily)}
									{@const createdH = maxVal > 0 ? (day.created / maxVal) * 85 : 0}
									{@const completedH = maxVal > 0 ? (day.completed / maxVal) * 85 : 0}
									<rect x={barX} y={95 - createdH} width="15" height={createdH} rx="2" fill="#93c5fd" opacity="0.7"/>
									<rect x={barX + 17} y={95 - completedH} width="15" height={completedH} rx="2" fill="#22c55e" opacity="0.8"/>
									<text x={barX + 16} y="108" text-anchor="middle" class="chart-day-label">{formatDay(day.day)}</text>
									<text x={barX + 7} y={90 - createdH} text-anchor="middle" class="chart-val-label">{day.created}</text>
									<text x={barX + 24} y={90 - completedH} text-anchor="middle" class="chart-val-label">{day.completed}</text>
								{/each}
								<rect x="5" y="118" width="8" height="5" rx="1" fill="#93c5fd" opacity="0.7"/>
								<text x="16" y="123" class="chart-legend-text">{isRTL ? 'إنشاء' : 'Created'}</text>
								<rect x="55" y="118" width="8" height="5" rx="1" fill="#22c55e" opacity="0.8"/>
								<text x="66" y="123" class="chart-legend-text">{isRTL ? 'إنجاز' : 'Done'}</text>
							</svg>
						</div>
					{:else}
						<p class="no-data-text">{isRTL ? 'لا بيانات يومية' : 'No daily data'}</p>
					{/if}
				</div>

			{:else if activeTab === 'branches'}
				<!-- Branch Cards -->
				{#each branchStats as branch}
					<div class="branch-card">
						<div class="branch-card-header">
							<div class="branch-info">
								<p class="branch-name">{getBranchName(branch)}</p>
								<p class="branch-location">{getBranchLocation(branch)}</p>
							</div>
							<div class="branch-rate" style="color: {getCompletionColor(branch.completion_rate)}">
								{branch.completion_rate}%
							</div>
						</div>
						<div class="branch-progress">
							<div class="progress-bar">
								<div class="progress-fill" style="width: {branch.completion_rate}%; background: {getCompletionColor(branch.completion_rate)}"></div>
							</div>
						</div>
						<div class="branch-metrics">
							<div class="metric"><span class="metric-val">{branch.total_tasks}</span><span class="metric-lbl">{isRTL ? 'إجمالي' : 'Total'}</span></div>
							<div class="metric"><span class="metric-val green-text">{branch.completed}</span><span class="metric-lbl">{isRTL ? 'مكتمل' : 'Done'}</span></div>
							<div class="metric"><span class="metric-val amber-text">{branch.pending}</span><span class="metric-lbl">{isRTL ? 'معلق' : 'Pend.'}</span></div>
							<div class="metric"><span class="metric-val red-text">{branch.overdue}</span><span class="metric-lbl">{isRTL ? 'متأخر' : 'Late'}</span></div>
						</div>
						<div class="branch-types">
							<span class="type-badge blue">{isRTL ? 'عادي' : 'Reg'} {branch.regular_count}</span>
							<span class="type-badge amber">{isRTL ? 'سريع' : 'Quick'} {branch.quick_count}</span>
							<span class="type-badge violet">{isRTL ? 'استلام' : 'Recv'} {branch.receiving_count}</span>
						</div>
					</div>
				{/each}
				{#if branchStats.length === 0}
					<div class="empty-state">{isRTL ? 'لا توجد بيانات' : 'No branch data'}</div>
				{/if}

			{:else if activeTab === 'employees'}
				<!-- Branch Filter Trigger -->
				<button class="branch-picker-btn" on:click={() => showBranchPopup = true}>
					<span class="branch-picker-icon">🏢</span>
					<span class="branch-picker-label">{getBranchFilterLabel()}</span>
					<span class="branch-picker-count">{filteredEmployees.length} {isRTL ? 'موظف' : 'emp'}</span>
					<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="6 9 12 15 18 9"/></svg>
				</button>

				<!-- Branch Popup -->
				{#if showBranchPopup}
					<div class="popup-overlay" on:click|self={() => showBranchPopup = false} on:keydown={(e) => e.key === 'Escape' && (showBranchPopup = false)} role="dialog" aria-modal="true">
						<div class="popup-sheet">
							<div class="popup-handle"></div>
							<h3 class="popup-title">{isRTL ? 'اختر الفرع' : 'Select Branch'}</h3>
							<div class="popup-list">
								<button class="popup-item {empBranchFilter === 'all' ? 'popup-item-active' : ''}" on:click={() => selectBranch('all')}>
									<span class="popup-item-icon">🌐</span>
									<span class="popup-item-label">{isRTL ? 'كل الفروع' : 'All Branches'}</span>
									{#if empBranchFilter === 'all'}<span class="popup-check">✓</span>{/if}
								</button>
								{#each availableBranches as br}
									<button class="popup-item {empBranchFilter === br ? 'popup-item-active' : ''}" on:click={() => selectBranch(br)}>
										<span class="popup-item-icon">🏢</span>
										<span class="popup-item-label">{isRTL ? (branchStats.find((b: any) => b.branch_name_en === br)?.branch_name_ar || br) : br}</span>
										{#if empBranchFilter === br}<span class="popup-check">✓</span>{/if}
									</button>
								{/each}
							</div>
						</div>
					</div>
				{/if}

				<!-- Top Employees -->
				{#each filteredEmployees as emp, idx}
					<div class="emp-row">
						<div class="emp-rank {idx === 0 ? 'gold' : idx === 1 ? 'silver' : idx === 2 ? 'bronze' : ''}">
							{idx + 1}
						</div>
						<div class="emp-info">
							<p class="emp-name">{getEmpName(emp)}</p>
							<p class="emp-branch">{getEmpBranch(emp)}</p>
						</div>
						<div class="emp-stats">
							<p class="emp-completed">{emp.completed}<span class="emp-total">/{emp.total}</span></p>
							<div class="emp-bar">
								<div class="emp-bar-fill" style="width: {emp.rate}%; background: {getCompletionColor(emp.rate)}"></div>
							</div>
							<p class="emp-rate" style="color: {getCompletionColor(emp.rate)}">{emp.rate}%</p>
						</div>
					</div>
				{/each}
				{#if filteredEmployees.length === 0}
					<div class="empty-state">{isRTL ? 'لا بيانات' : 'No data'}</div>
				{/if}
			{/if}
		{/if}
	</div>
</div>

<style>
	.page {
		min-height: 100%;
		background: #f8fafc;
		display: flex;
		flex-direction: column;
		font-family: system-ui, -apple-system, sans-serif;
	}

	/* Header */
	.header {
		background: white;
		border-bottom: 1px solid #e2e8f0;
		position: sticky;
		top: 0;
		z-index: 20;
	}
	.header-top {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.5rem 0.75rem;
	}
	.header-title {
		display: flex;
		align-items: center;
		gap: 0.4rem;
	}
	.header-title span { font-size: 1.2rem; }
	.header-title h1 {
		margin: 0;
		font-size: 0.85rem;
		font-weight: 800;
		color: #1e293b;
		text-transform: uppercase;
		letter-spacing: 0.03em;
	}
	.refresh-btn {
		width: 32px; height: 32px;
		background: #4f46e5;
		border: none; border-radius: 8px;
		color: white; cursor: pointer;
		display: flex; align-items: center; justify-content: center;
	}
	.refresh-btn:disabled { opacity: 0.5; }
	.spinning { animation: spin 1s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	/* Period picker button */
	.period-picker-btn {
		display: flex;
		flex-direction: column;
		margin: 0 0.5rem 0.4rem;
		padding: 0;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 10px;
		cursor: pointer;
		box-shadow: 0 1px 3px rgba(0,0,0,0.04);
		transition: all 0.2s;
		overflow: hidden;
	}
	.period-picker-btn:active { background: #f8fafc; transform: scale(0.98); }
	.period-picker-main {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem 0.75rem;
	}
	.period-picker-icon { font-size: 1rem; }
	.period-picker-info {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: flex-start;
	}
	.period-picker-label {
		font-size: 0.78rem;
		font-weight: 800;
		color: #1e293b;
	}
	.period-picker-date {
		font-size: 0.62rem;
		font-weight: 600;
		color: #94a3b8;
		margin-top: 0.05rem;
	}
	.period-picker-main svg { color: #94a3b8; flex-shrink: 0; }
	.period-picker-hint {
		display: block;
		width: 100%;
		padding: 0.2rem 0.75rem;
		background: linear-gradient(135deg, #f0f4ff, #eef2ff);
		border-top: 1px solid #e8ecf4;
		font-size: 0.58rem;
		font-weight: 600;
		color: #818cf8;
		letter-spacing: 0.03em;
		text-align: center;
	}
	.popup-separator {
		height: 1px;
		background: #f1f5f9;
		margin: 0.2rem 0;
	}
	.popup-date-section {
		padding: 0.75rem 1rem;
	}
	.popup-date-label {
		font-size: 0.68rem;
		font-weight: 700;
		color: #94a3b8;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		margin: 0 0 0.4rem;
	}

	.date-input-popup {
		width: 100%;
		padding: 0.65rem 0.75rem;
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		font-size: 0.9rem;
		font-weight: 600;
		color: #334155;
		background: #f8fafc;
		outline: none;
		transition: border-color 0.2s;
	}
	.date-input-popup:focus { border-color: #7c3aed; }
	.date-apply-popup {
		width: 100%;
		margin-top: 0.75rem;
		padding: 0.65rem;
		background: #7c3aed;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 0.82rem;
		font-weight: 800;
		cursor: pointer;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		transition: background 0.2s;
	}
	.date-apply-popup:active { background: #6d28d9; }
	.date-apply-popup:disabled { opacity: 0.5; }

	/* Tabs */
	.tabs-row {
		display: flex;
		gap: 0;
		background: #f1f5f9;
		margin: 0 0.5rem 0;
		border-radius: 10px;
		padding: 3px;
		margin-bottom: 0;
	}
	.tab-btn {
		flex: 1;
		padding: 0.4rem;
		font-size: 0.72rem;
		font-weight: 700;
		border: none;
		border-radius: 8px;
		background: transparent;
		color: #64748b;
		cursor: pointer;
		transition: all 0.2s;
		text-transform: uppercase;
	}
	.tab-active {
		background: #4f46e5;
		color: white;
		box-shadow: 0 2px 8px rgba(79,70,229,0.3);
	}

	/* Content */
	.content {
		flex: 1;
		padding: 0.5rem;
		overflow-y: auto;
		padding-bottom: 5rem;
	}

	/* Loading / Error */
	.loading-box {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 1rem;
		color: #64748b;
		font-size: 0.8rem;
	}
	.spinner {
		width: 28px; height: 28px;
		border: 3px solid #e2e8f0;
		border-top-color: #4f46e5;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 0.5rem;
	}
	.error-box {
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 10px;
		padding: 1rem;
		text-align: center;
		color: #dc2626;
		font-size: 0.78rem;
	}
	.error-box button {
		margin-top: 0.5rem;
		padding: 0.4rem 1rem;
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 700;
		font-size: 0.72rem;
	}

	/* KPI Grid */
	.kpi-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.4rem;
		margin-bottom: 0.5rem;
	}
	.kpi-card {
		background: white;
		border-radius: 12px;
		padding: 0.65rem 0.75rem;
		border: 1px solid #f1f5f9;
		box-shadow: 0 1px 3px rgba(0,0,0,0.04);
	}
	.kpi-label {
		font-size: 0.62rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		margin: 0 0 0.15rem;
	}
	.kpi-value {
		font-size: 1.4rem;
		font-weight: 900;
		margin: 0;
		line-height: 1.1;
	}
	.kpi-sub {
		font-size: 0.58rem;
		margin: 0.1rem 0 0;
		opacity: 0.7;
	}
	.kpi-card.blue .kpi-label { color: #3b82f6; }
	.kpi-card.blue .kpi-value { color: #1e293b; }
	.kpi-card.blue .kpi-sub { color: #94a3b8; }
	.kpi-card.green .kpi-label { color: #059669; }
	.kpi-card.green .kpi-value { color: #047857; }
	.kpi-card.green .kpi-sub { color: #059669; }
	.kpi-card.amber .kpi-label { color: #d97706; }
	.kpi-card.amber .kpi-value { color: #b45309; }
	.kpi-card.red .kpi-label { color: #dc2626; }
	.kpi-card.red .kpi-value { color: #b91c1c; }

	/* Card */
	.card {
		background: white;
		border-radius: 12px;
		padding: 0.65rem 0.75rem;
		border: 1px solid #f1f5f9;
		box-shadow: 0 1px 3px rgba(0,0,0,0.04);
		margin-bottom: 0.5rem;
	}
	.card-title {
		font-size: 0.72rem;
		font-weight: 800;
		color: #1e293b;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		margin: 0 0 0.5rem;
	}

	/* Gauge */
	.gauge-row {
		display: flex;
		align-items: center;
		gap: 1rem;
	}
	.gauge-wrap {
		position: relative;
		width: 80px; height: 80px;
		flex-shrink: 0;
	}
	.gauge-svg { width: 100%; height: 100%; }
	.gauge-text {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.gauge-pct {
		font-size: 1.1rem;
		font-weight: 900;
	}
	.gauge-stats {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.4rem;
		flex: 1;
	}
	.gauge-stat {
		display: flex;
		flex-direction: column;
	}
	.gs-val { font-size: 0.95rem; font-weight: 900; }
	.gs-lbl { font-size: 0.58rem; color: #94a3b8; font-weight: 600; text-transform: uppercase; }
	.green-text { color: #059669; }
	.amber-text { color: #d97706; }
	.red-text { color: #dc2626; }
	.violet-text { color: #7c3aed; }

	/* Pie */
	.pie-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}
	.pie-svg { width: 70px; height: 70px; flex-shrink: 0; }
	.pie-legend { flex: 1; }
	.legend-item {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		margin-bottom: 0.2rem;
	}
	.legend-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
	.legend-label { font-size: 0.68rem; font-weight: 600; color: #475569; }
	.legend-count { font-size: 0.68rem; font-weight: 800; color: #1e293b; }
	.legend-pct { font-size: 0.6rem; color: #94a3b8; }
	.no-data-text { font-size: 0.7rem; color: #94a3b8; text-align: center; padding: 1rem 0; }

	/* Daily chart */
	.daily-chart-wrap { overflow-x: auto; -webkit-overflow-scrolling: touch; }
	.daily-svg { width: 100%; min-width: 280px; }
	.chart-day-label { font-size: 6.5px; fill: #64748b; font-weight: 600; }
	.chart-val-label { font-size: 5.5px; fill: #94a3b8; font-weight: 700; }
	.chart-legend-text { font-size: 6px; fill: #64748b; }

	/* Branch cards */
	.branch-card {
		background: white;
		border-radius: 12px;
		padding: 0.65rem 0.75rem;
		border: 1px solid #f1f5f9;
		box-shadow: 0 1px 3px rgba(0,0,0,0.04);
		margin-bottom: 0.4rem;
	}
	.branch-card-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.35rem;
	}
	.branch-info { flex: 1; min-width: 0; }
	.branch-name {
		font-size: 0.78rem;
		font-weight: 800;
		color: #1e293b;
		margin: 0;
		line-height: 1.2;
	}
	.branch-location {
		font-size: 0.62rem;
		color: #94a3b8;
		margin: 0.1rem 0 0;
	}
	.branch-rate {
		font-size: 1.2rem;
		font-weight: 900;
		flex-shrink: 0;
	}
	.branch-progress { margin-bottom: 0.4rem; }
	.progress-bar {
		height: 5px;
		background: #f1f5f9;
		border-radius: 4px;
		overflow: hidden;
	}
	.progress-fill {
		height: 100%;
		border-radius: 4px;
		transition: width 0.5s;
	}
	.branch-metrics {
		display: flex;
		gap: 0.6rem;
		margin-bottom: 0.35rem;
	}
	.metric { display: flex; flex-direction: column; }
	.metric-val { font-size: 0.82rem; font-weight: 800; color: #1e293b; }
	.metric-lbl { font-size: 0.55rem; color: #94a3b8; font-weight: 600; text-transform: uppercase; }
	.branch-types {
		display: flex;
		gap: 0.3rem;
	}
	.type-badge {
		font-size: 0.58rem;
		font-weight: 700;
		padding: 0.15rem 0.4rem;
		border-radius: 4px;
	}
	.type-badge.blue   { background: #eff6ff; color: #3b82f6; }
	.type-badge.amber  { background: #fffbeb; color: #d97706; }
	.type-badge.violet { background: #f5f3ff; color: #7c3aed; }

	/* Employee rows */
	.emp-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		background: white;
		border-radius: 10px;
		padding: 0.55rem 0.65rem;
		border: 1px solid #f1f5f9;
		margin-bottom: 0.35rem;
	}
	.emp-rank {
		width: 26px; height: 26px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.68rem;
		font-weight: 900;
		background: #f1f5f9;
		color: #64748b;
		flex-shrink: 0;
	}
	.emp-rank.gold   { background: #fef3c7; color: #b45309; }
	.emp-rank.silver { background: #e2e8f0; color: #475569; }
	.emp-rank.bronze { background: #ffedd5; color: #c2410c; }
	.emp-info { flex: 1; min-width: 0; }
	.emp-name {
		font-size: 0.72rem;
		font-weight: 700;
		color: #1e293b;
		margin: 0;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.emp-branch {
		font-size: 0.58rem;
		color: #94a3b8;
		margin: 0;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.emp-stats {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		flex-shrink: 0;
		min-width: 60px;
	}
	.emp-completed {
		font-size: 0.82rem;
		font-weight: 900;
		color: #059669;
		margin: 0;
	}
	.emp-total {
		font-size: 0.62rem;
		font-weight: 600;
		color: #94a3b8;
	}
	.emp-bar {
		width: 50px;
		height: 4px;
		background: #f1f5f9;
		border-radius: 3px;
		overflow: hidden;
		margin: 0.15rem 0;
	}
	.emp-bar-fill { height: 100%; border-radius: 3px; }
	.emp-rate {
		font-size: 0.6rem;
		font-weight: 800;
		margin: 0;
	}

	/* Branch picker button */
	.branch-picker-btn {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		width: 100%;
		padding: 0.55rem 0.75rem;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 10px;
		margin-bottom: 0.5rem;
		cursor: pointer;
		transition: all 0.2s;
		box-shadow: 0 1px 3px rgba(0,0,0,0.04);
	}
	.branch-picker-btn:active { background: #f8fafc; transform: scale(0.98); }
	.branch-picker-icon { font-size: 1rem; }
	.branch-picker-label {
		flex: 1;
		text-align: start;
		font-size: 0.75rem;
		font-weight: 700;
		color: #1e293b;
	}
	.branch-picker-count {
		font-size: 0.62rem;
		font-weight: 700;
		color: #94a3b8;
		background: #f1f5f9;
		padding: 0.15rem 0.4rem;
		border-radius: 6px;
	}
	.branch-picker-btn svg { color: #94a3b8; flex-shrink: 0; }

	/* Popup overlay & sheet */
	.popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0,0,0,0.4);
		z-index: 1100;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		animation: fadeIn 0.2s;
	}
	@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
	.popup-sheet {
		background: white;
		border-radius: 20px 20px 0 0;
		width: 100%;
		max-width: 500px;
		max-height: 70vh;
		overflow: hidden;
		animation: slideUp 0.25s ease-out;
		box-shadow: 0 -8px 40px rgba(0,0,0,0.12);
		padding-bottom: calc(4rem + env(safe-area-inset-bottom));
	}
	@keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
	.popup-handle {
		width: 36px;
		height: 4px;
		background: #cbd5e1;
		border-radius: 4px;
		margin: 10px auto 0;
	}
	.popup-title {
		font-size: 0.85rem;
		font-weight: 800;
		color: #1e293b;
		text-align: center;
		padding: 0.75rem;
		margin: 0;
		border-bottom: 1px solid #f1f5f9;
		text-transform: uppercase;
		letter-spacing: 0.03em;
	}
	.popup-list {
		overflow-y: auto;
		max-height: calc(70vh - 80px);
		padding: 0.4rem 0;
	}
	.popup-item {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		width: 100%;
		padding: 0.7rem 1rem;
		background: transparent;
		border: none;
		cursor: pointer;
		transition: background 0.15s;
		font-size: 0.78rem;
	}
	.popup-item:active { background: #f1f5f9; }
	.popup-item-active { background: #eef2ff; }
	.popup-item-icon { font-size: 1.1rem; }
	.popup-item-label {
		flex: 1;
		text-align: start;
		font-weight: 600;
		color: #334155;
	}
	.popup-item-active .popup-item-label { color: #4f46e5; font-weight: 700; }
	.popup-check {
		color: #4f46e5;
		font-weight: 900;
		font-size: 1rem;
	}

	.empty-state {
		text-align: center;
		padding: 2rem 1rem;
		color: #94a3b8;
		font-size: 0.78rem;
	}
</style>
