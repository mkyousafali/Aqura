<script lang="ts">
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';

	export let mobile = false;

	interface BranchSales {
		branch_id: number;
		branch_name: string;
		total_amount: number;
		total_bills: number;
		total_return: number;
		status: 'online' | 'unavailable';
		error?: string;
	}

	let loading = true;
	let todaySales: BranchSales[] = [];
	let yesterdaySales: BranchSales[] = [];
	let twoDaysAgoSales: BranchSales[] = [];
	let previousMonthSameDaySales: BranchSales[] = [];
	let twoDaysAgoPreviousMonthSales: BranchSales[] = [];
	let previousMonthSameDayDate = '';
	let twoDaysAgoPreviousMonthDate = '';
	let todayDate = '';
	let yesterdayDate = '';
	let twoDaysAgoDate = '';
	let lastUpdatedAt: Date | null = null;
	let selectedBranchId = 'all';
	$: availableBranches = todaySales.map((branch) => ({ id: String(branch.branch_id), name: branch.branch_name }));
	$: visibleTodaySales = filterByBranch(todaySales, selectedBranchId);
	$: visibleYesterdaySales = filterByBranch(yesterdaySales, selectedBranchId);
	$: visibleTwoDaysAgoSales = filterByBranch(twoDaysAgoSales, selectedBranchId);
	$: visiblePreviousMonthSales = filterByBranch(previousMonthSameDaySales, selectedBranchId);
	$: visibleTwoDaysAgoPreviousMonthSales = filterByBranch(twoDaysAgoPreviousMonthSales, selectedBranchId);
	$: todayTotal = sumOnline(visibleTodaySales, 'total_amount');
	$: todayBills = sumOnline(visibleTodaySales, 'total_bills');
	$: todayReturns = sumOnline(visibleTodaySales, 'total_return');
	$: yesterdayTotal = sumOnline(visibleYesterdaySales, 'total_amount');
	$: yesterdayBills = sumOnline(visibleYesterdaySales, 'total_bills');
	$: yesterdayReturns = sumOnline(visibleYesterdaySales, 'total_return');
	$: twoDaysAgoTotal = sumOnline(visibleTwoDaysAgoSales, 'total_amount');
	$: twoDaysAgoBills = sumOnline(visibleTwoDaysAgoSales, 'total_bills');
	$: twoDaysAgoReturns = sumOnline(visibleTwoDaysAgoSales, 'total_return');
	$: previousMonthSameDayTotal = sumOnline(visiblePreviousMonthSales, 'total_amount');
	$: previousMonthSameDayBills = sumOnline(visiblePreviousMonthSales, 'total_bills');
	$: previousMonthSameDayReturns = sumOnline(visiblePreviousMonthSales, 'total_return');
	$: twoDaysAgoPreviousMonthTotal = sumOnline(visibleTwoDaysAgoPreviousMonthSales, 'total_amount');
	$: twoDaysAgoPreviousMonthBills = sumOnline(visibleTwoDaysAgoPreviousMonthSales, 'total_bills');
	$: twoDaysAgoPreviousMonthReturns = sumOnline(visibleTwoDaysAgoPreviousMonthSales, 'total_return');
	$: comparisonMax = Math.max(yesterdayTotal, twoDaysAgoTotal, previousMonthSameDayTotal, twoDaysAgoPreviousMonthTotal, 1);
	$: todayChange = changePercentage(todayTotal, yesterdayTotal);
	$: yesterdayChange = changePercentage(yesterdayTotal, twoDaysAgoTotal);
	$: twoDaysAgoChange = changePercentage(twoDaysAgoTotal, twoDaysAgoPreviousMonthTotal);
	$: previousMonthChange = changePercentage(previousMonthSameDayTotal, twoDaysAgoTotal);
	$: selectedScopeName = selectedBranchId === 'all'
		? ui('All Branches', 'جميع الفروع')
		: availableBranches.find((branch) => branch.id === selectedBranchId)?.name || ui('Selected Branch', 'الفرع المحدد');

	$: isArabic = $currentLocale === 'ar';
	const ui = (english: string, arabic: string) => isArabic ? arabic : english;
	const money = (value: number) => new Intl.NumberFormat(
		isArabic ? 'ar-SA-u-nu-arab' : 'en-SA',
		{ maximumFractionDigits: 2 }
	).format(value || 0);

	function filterByBranch(rows: BranchSales[], branchId: string) {
		return branchId === 'all' ? rows : rows.filter((branch) => String(branch.branch_id) === branchId);
	}

	function sumOnline(rows: BranchSales[], field: 'total_amount' | 'total_bills' | 'total_return') {
		return rows.filter((branch) => branch.status === 'online').reduce((sum, branch) => sum + branch[field], 0);
	}

	function returnPercentage(netSales: number, returns: number) {
		const grossSales = netSales + returns;
		return grossSales > 0 ? (returns / grossSales) * 100 : 0;
	}

	function percent(value: number) {
		return new Intl.NumberFormat(isArabic ? 'ar-SA-u-nu-arab' : 'en-SA', {
			minimumFractionDigits: 1,
			maximumFractionDigits: 1
		}).format(value || 0);
	}

	function changePercentage(current: number, previous: number) {
		if (previous <= 0) return null;
		return ((current - previous) / previous) * 100;
	}

	function signedPercent(value: number | null) {
		if (value === null) return '—';
		return `${value >= 0 ? '+' : ''}${percent(value)}%`;
	}

	function barWidth(value: number) {
		return `${Math.max(value > 0 ? 4 : 0, (value / comparisonMax) * 100)}%`;
	}

	function saudiDate(offsetDays = 0) {
		const now = new Date();
		const saudi = new Date(now.getTime() + (3 * 60 + now.getTimezoneOffset()) * 60_000);
		saudi.setDate(saudi.getDate() + offsetDays);
		const year = saudi.getFullYear();
		const month = String(saudi.getMonth() + 1).padStart(2, '0');
		const day = String(saudi.getDate()).padStart(2, '0');
		return `${year}-${month}-${day}`;
	}

	function previousMonthDate(dateString: string) {
		const [year, month, day] = dateString.split('-').map(Number);
		const previousMonthIndex = month - 2;
		const targetYear = previousMonthIndex < 0 ? year - 1 : year;
		const targetMonthIndex = (previousMonthIndex + 12) % 12;
		const lastDayOfTargetMonth = new Date(targetYear, targetMonthIndex + 1, 0).getDate();
		const targetDay = Math.min(day, lastDayOfTargetMonth);
		return `${targetYear}-${String(targetMonthIndex + 1).padStart(2, '0')}-${String(targetDay).padStart(2, '0')}`;
	}

	function displayDate(dateString: string) {
		if (!dateString) return '';
		const [year, month, day] = dateString.split('-').map(Number);
		return new Intl.DateTimeFormat(isArabic ? 'ar-SA-u-nu-arab' : 'en-GB', {
			day: '2-digit',
			month: 'short',
			year: 'numeric'
		}).format(new Date(year, month - 1, day));
	}

	function numberValue(row: any, ...keys: string[]) {
		for (const key of keys) {
			if (row?.[key] !== undefined && row?.[key] !== null) return Number(row[key]) || 0;
		}
		return 0;
	}

	async function queryBranch(branch: any, today: string, yesterday: string, twoDaysAgo: string, previousMonthSameDay: string, twoDaysAgoPreviousMonth: string) {
		const erpBranchId = Number(branch.erp_branch_id);
		if (!Number.isInteger(erpBranchId) || erpBranchId <= 0) {
			throw new Error(`Missing or invalid ERP branch ID for Aqura branch ${branch.branch_id}`);
		}
		const sql = `
			SELECT
				CONVERT(varchar(10), CAST(TransactionDate AS date), 23) AS SaleDate,
				SUM(CASE WHEN VoucherType = 'SI' THEN GrandTotal ELSE 0 END) AS GrossSales,
				SUM(CASE WHEN VoucherType = 'SI' THEN 1 ELSE 0 END) AS GrossBills,
				SUM(CASE WHEN VoucherType = 'SR' THEN GrandTotal ELSE 0 END) AS ReturnAmount,
				SUM(CASE WHEN VoucherType = 'SR' THEN 1 ELSE 0 END) AS ReturnBills
			FROM InvTransactionMaster
			WHERE BranchID = ${erpBranchId}
			  AND CAST(TransactionDate AS date) IN ('${twoDaysAgoPreviousMonth}', '${previousMonthSameDay}', '${twoDaysAgo}', '${yesterday}', '${today}')
			  AND VoucherType IN ('SI', 'SR')
			GROUP BY CAST(TransactionDate AS date)
			ORDER BY CAST(TransactionDate AS date);
		`;

		const response = await authenticatedFetch('/api/erp-bridge-proxy', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ branchId: branch.branch_id, sql })
		});
		if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
		const payload = await response.json();
		return payload.recordset || payload.records || payload || [];
	}

	function salesRow(branch: any, records: any[], date: string): BranchSales {
		const row = records.find((item) => String(item.SaleDate ?? item.saleDate ?? item.saledate ?? '').slice(0, 10) === date) || {};
		const gross = numberValue(row, 'GrossSales', 'grossSales', 'grosssales');
		const returns = numberValue(row, 'ReturnAmount', 'returnAmount', 'returnamount');
		const grossBills = numberValue(row, 'GrossBills', 'grossBills', 'grossbills');
		const returnBills = numberValue(row, 'ReturnBills', 'returnBills', 'returnbills');
		return {
			branch_id: Number(branch.branch_id),
			branch_name: branch.branch_name || `Branch ${branch.branch_id}`,
			total_amount: gross - returns,
			total_bills: grossBills - returnBills,
			total_return: returns,
			status: 'online'
		};
	}

	function unavailableRow(branch: any, error: unknown): BranchSales {
		return {
			branch_id: Number(branch.branch_id),
			branch_name: branch.branch_name || `Branch ${branch.branch_id}`,
			total_amount: 0,
			total_bills: 0,
			total_return: 0,
			status: 'unavailable',
			error: error instanceof Error ? error.message : String(error)
		};
	}

	async function loadLiveSales() {
		const today = saudiDate();
		const yesterday = saudiDate(-1);
		const twoDaysAgo = saudiDate(-2);
		const previousMonthSameDay = previousMonthDate(yesterday);
		const twoDaysAgoPreviousMonth = previousMonthDate(twoDaysAgo);
		todayDate = today;
		yesterdayDate = yesterday;
		twoDaysAgoDate = twoDaysAgo;
		previousMonthSameDayDate = previousMonthSameDay;
		twoDaysAgoPreviousMonthDate = twoDaysAgoPreviousMonth;
		const { data: connections, error } = await supabase
			.from('erp_connections')
			.select('branch_id, branch_name, erp_branch_id')
			.eq('is_active', true)
			.order('branch_id');
		if (error) throw error;

		const results = await Promise.all((connections || []).map(async (branch: any) => {
			try {
				const records = await queryBranch(branch, today, yesterday, twoDaysAgo, previousMonthSameDay, twoDaysAgoPreviousMonth);
				return {
					today: salesRow(branch, records, today),
					yesterday: salesRow(branch, records, yesterday),
					twoDaysAgo: salesRow(branch, records, twoDaysAgo),
					previousMonthSameDay: salesRow(branch, records, previousMonthSameDay),
					twoDaysAgoPreviousMonth: salesRow(branch, records, twoDaysAgoPreviousMonth)
				};
			} catch (queryError) {
				return {
					today: unavailableRow(branch, queryError),
					yesterday: unavailableRow(branch, queryError),
					twoDaysAgo: unavailableRow(branch, queryError),
					previousMonthSameDay: unavailableRow(branch, queryError),
					twoDaysAgoPreviousMonth: unavailableRow(branch, queryError)
				};
			}
		}));
		todaySales = results.map((result) => result.today);
		yesterdaySales = results.map((result) => result.yesterday);
		twoDaysAgoSales = results.map((result) => result.twoDaysAgo);
		previousMonthSameDaySales = results.map((result) => result.previousMonthSameDay);
		twoDaysAgoPreviousMonthSales = results.map((result) => result.twoDaysAgoPreviousMonth);
		lastUpdatedAt = new Date();
	}

	async function refresh() {
		loading = true;
		try {
			await loadLiveSales();
		} catch (error) {
			console.error('Unable to load sales report:', error);
		} finally {
			loading = false;
		}
	}

	onMount(refresh);
</script>

<div class="live-report mobile" dir={isArabic ? 'rtl' : 'ltr'}>
	<div class="mobile-report-toolbar">
		<label for="sales-branch-filter">
			<span>{ui('Branch', 'الفرع')}</span>
			<select id="sales-branch-filter" bind:value={selectedBranchId} disabled={loading}>
				<option value="all">{ui('All Branches', 'جميع الفروع')}</option>
				{#each availableBranches as branch}
					<option value={branch.id}>{branch.name}</option>
				{/each}
			</select>
		</label>
		<button class="mobile-refresh-btn" type="button" on:click={refresh} disabled={loading} aria-label={ui('Refresh sales', 'تحديث المبيعات')} title={ui('Refresh', 'تحديث')}>
			<span aria-hidden="true">↻</span>
			{loading ? ui('Loading', 'تحميل') : ui('Refresh', 'تحديث')}
		</button>
	</div>

	{#if loading}
		<div class="loading">{ui('Loading live branch data…', 'جارٍ تحميل بيانات الفروع المباشرة…')}</div>
	{:else}
		<div class="sales-overview-card">
				<div class="mobile-card-title">
					<div><h3>{ui("Today's Overview", 'نظرة عامة على اليوم')}</h3><p>{ui('Today’s key figures for the selected branch scope', 'المؤشرات الرئيسية لليوم ضمن نطاق الفروع المحدد')}</p></div>
				</div>
				<div class="overview-grid">
					<div class="overview-stat net-stat"><span class="overview-icon">◉</span><small>{ui('Total Net Sales', 'إجمالي صافي المبيعات')}</small><strong>{money(todayTotal)}</strong></div>
					<div class="overview-stat bills-stat"><span class="overview-icon">▣</span><small>{ui('Total Bills', 'إجمالي الفواتير')}</small><strong>{todayBills}</strong></div>
					<div class="overview-stat basket-stat"><span class="overview-icon">🛒</span><small>{ui('Average Basket', 'متوسط السلة')}</small><strong>{money(todayBills > 0 ? todayTotal / todayBills : 0)}</strong></div>
					<div class="overview-stat returns-stat"><span class="overview-icon">%</span><small>{ui('Returns', 'المرتجعات')}</small><strong>{percent(returnPercentage(todayTotal, todayReturns))}%</strong></div>
				</div>
			</div>
			<section class="sales-comparison-chart" aria-label={ui('Sales comparison chart', 'رسم مقارنة المبيعات')}>
				<div class="chart-row today-row">
					<div class="period-head">
						<span class="period-icon today-icon">▣</span>
						<div class="period-name"><strong>{ui('Today', 'اليوم')}</strong><small>{displayDate(todayDate)}</small></div>
						<span class:positive={todayChange !== null && todayChange >= 0} class:negative={todayChange !== null && todayChange < 0} class="change-badge">{signedPercent(todayChange)}</span>
						<div class="period-net"><small>{ui('Net Sales', 'صافي المبيعات')}</small><strong>{money(todayTotal)}</strong></div>
					</div>
					<div class="chart-track"><div class="chart-bar today-bar" style:width={barWidth(todayTotal)}></div></div>
					<span class="bar-percent">{percent((todayTotal / comparisonMax) * 100)}%</span>
					<div class="chart-metrics">
						<span>{todayBills} {ui('bills', 'فاتورة')}</span>
						<span>{ui('Basket', 'متوسط السلة')}: {money(todayBills > 0 ? todayTotal / todayBills : 0)}</span>
						<span>{ui('Returns', 'المرتجعات')}: {percent(returnPercentage(todayTotal, todayReturns))}%</span>
					</div>
				</div>
				<div class="chart-row">
					<div class="period-head">
						<span class="period-icon yesterday-icon">▣</span>
						<div class="period-name"><strong>{ui('Yesterday', 'الأمس')}</strong><small>{displayDate(yesterdayDate)}</small></div>
						<span class:positive={yesterdayChange !== null && yesterdayChange >= 0} class:negative={yesterdayChange !== null && yesterdayChange < 0} class="change-badge">{signedPercent(yesterdayChange)}</span>
						<div class="period-net"><small>{ui('Net Sales', 'صافي المبيعات')}</small><strong>{money(yesterdayTotal)}</strong></div>
					</div>
					<div class="chart-track"><div class="chart-bar yesterday-bar" style:width={barWidth(yesterdayTotal)}></div></div>
					<span class="bar-percent">{percent((yesterdayTotal / comparisonMax) * 100)}%</span>
					<div class="chart-metrics">
						<span>{yesterdayBills} {ui('bills', 'فاتورة')}</span>
						<span>{ui('Basket', 'متوسط السلة')}: {money(yesterdayBills > 0 ? yesterdayTotal / yesterdayBills : 0)}</span>
						<span>{ui('Returns', 'المرتجعات')}: {percent(returnPercentage(yesterdayTotal, yesterdayReturns))}%</span>
					</div>
					<div class="embedded-previous-month">
						<div class="embedded-previous-head">
							<span class="period-icon previous-icon">▥</span>
							<div class="period-name">
								<strong>{ui('Same date last month', 'نفس التاريخ الشهر الماضي')}</strong>
								<small>{displayDate(previousMonthSameDayDate)}</small>
							</div>
							<div class="period-net">
								<small>{ui('Net Sales', 'صافي المبيعات')}</small>
								<strong>{money(previousMonthSameDayTotal)}</strong>
							</div>
						</div>
						<div class="chart-track"><div class="chart-bar previous-bar" style:width={barWidth(previousMonthSameDayTotal)}></div></div>
						<span class="bar-percent">{percent((previousMonthSameDayTotal / comparisonMax) * 100)}%</span>
						<div class="chart-metrics embedded-metrics">
							<span>{previousMonthSameDayBills} {ui('bills', 'فاتورة')}</span>
							<span>{ui('Basket', 'متوسط السلة')}: {money(previousMonthSameDayBills > 0 ? previousMonthSameDayTotal / previousMonthSameDayBills : 0)}</span>
							<span>{ui('Returns', 'المرتجعات')}: {percent(returnPercentage(previousMonthSameDayTotal, previousMonthSameDayReturns))}%</span>
						</div>
					</div>
				</div>
				<div class="chart-row">
					<div class="period-head">
						<span class="period-icon two-days-icon">▦</span>
						<div class="period-name"><strong>{ui('2 Days Ago', 'قبل يومين')}</strong><small>{displayDate(twoDaysAgoDate)}</small></div>
						<span class:positive={twoDaysAgoChange !== null && twoDaysAgoChange >= 0} class:negative={twoDaysAgoChange !== null && twoDaysAgoChange < 0} class="change-badge">{signedPercent(twoDaysAgoChange)}</span>
						<div class="period-net"><small>{ui('Net Sales', 'صافي المبيعات')}</small><strong>{money(twoDaysAgoTotal)}</strong></div>
					</div>
					<div class="chart-track"><div class="chart-bar two-days-bar" style:width={barWidth(twoDaysAgoTotal)}></div></div>
					<span class="bar-percent">{percent((twoDaysAgoTotal / comparisonMax) * 100)}%</span>
					<div class="chart-metrics">
						<span>{twoDaysAgoBills} {ui('bills', 'فاتورة')}</span>
						<span>{ui('Basket', 'متوسط السلة')}: {money(twoDaysAgoBills > 0 ? twoDaysAgoTotal / twoDaysAgoBills : 0)}</span>
						<span>{ui('Returns', 'المرتجعات')}: {percent(returnPercentage(twoDaysAgoTotal, twoDaysAgoReturns))}%</span>
					</div>
					<div class="embedded-previous-month">
						<div class="embedded-previous-head">
							<span class="period-icon previous-icon">▥</span>
							<div class="period-name">
								<strong>{ui('Same date last month', 'نفس التاريخ الشهر الماضي')}</strong>
								<small>{displayDate(twoDaysAgoPreviousMonthDate)}</small>
							</div>
							<div class="period-net">
								<small>{ui('Net Sales', 'صافي المبيعات')}</small>
								<strong>{money(twoDaysAgoPreviousMonthTotal)}</strong>
							</div>
						</div>
						<div class="chart-track"><div class="chart-bar previous-bar" style:width={barWidth(twoDaysAgoPreviousMonthTotal)}></div></div>
						<span class="bar-percent">{percent((twoDaysAgoPreviousMonthTotal / comparisonMax) * 100)}%</span>
						<div class="chart-metrics embedded-metrics">
							<span>{twoDaysAgoPreviousMonthBills} {ui('bills', 'فاتورة')}</span>
							<span>{ui('Basket', 'متوسط السلة')}: {money(twoDaysAgoPreviousMonthBills > 0 ? twoDaysAgoPreviousMonthTotal / twoDaysAgoPreviousMonthBills : 0)}</span>
							<span>{ui('Returns', 'المرتجعات')}: {percent(returnPercentage(twoDaysAgoPreviousMonthTotal, twoDaysAgoPreviousMonthReturns))}%</span>
						</div>
					</div>
				</div>
				<div class="chart-row previous-month-row">
					<div class="period-head">
						<span class="period-icon previous-icon">▥</span>
						<div class="period-name"><strong>{ui('Previous Month', 'الشهر السابق')}</strong><small>{displayDate(previousMonthSameDayDate)}</small></div>
						<span class:positive={previousMonthChange !== null && previousMonthChange >= 0} class:negative={previousMonthChange !== null && previousMonthChange < 0} class="change-badge">{signedPercent(previousMonthChange)}</span>
						<div class="period-net"><small>{ui('Net Sales', 'صافي المبيعات')}</small><strong>{money(previousMonthSameDayTotal)}</strong></div>
					</div>
					<div class="chart-track"><div class="chart-bar previous-bar" style:width={barWidth(previousMonthSameDayTotal)}></div></div>
					<span class="bar-percent">{percent((previousMonthSameDayTotal / comparisonMax) * 100)}%</span>
					<div class="chart-metrics">
						<span>{previousMonthSameDayBills} {ui('bills', 'فاتورة')}</span>
						<span>{ui('Basket', 'متوسط السلة')}: {money(previousMonthSameDayBills > 0 ? previousMonthSameDayTotal / previousMonthSameDayBills : 0)}</span>
						<span>{ui('Returns', 'المرتجعات')}: {percent(returnPercentage(previousMonthSameDayTotal, previousMonthSameDayReturns))}%</span>
					</div>
				</div>
			</section>
			<div class="sales-update-footer">
				<span>ⓘ {ui('Data shows net sales after discounts and before tax.', 'تعرض البيانات صافي المبيعات بعد الخصومات وقبل الضريبة.')}</span>
				<small>{ui('Last updated', 'آخر تحديث')} {lastUpdatedAt ? lastUpdatedAt.toLocaleTimeString(isArabic ? 'ar-SA' : 'en-SA', { hour: '2-digit', minute: '2-digit' }) : '—'}</small>
			</div>
		<section>
			<h3>{ui('Today — ERP Sales', 'اليوم — مبيعات ERP')}</h3>
			<div class="total-card">
				<span>{ui('Total sales', 'إجمالي المبيعات')} — {selectedScopeName}</span>
				<strong>{money(todayTotal)} <small>{ui('SAR', 'ر.س')}</small></strong>
				<em>{todayBills} {ui('bills', 'فاتورة')}</em>
			</div>
			<h4>{ui('Branch breakdown', 'تفصيل الفروع')}</h4>
			<div class="grid">
				{#each visibleTodaySales as branch}{@render BranchCard(branch)}{/each}
			</div>
		</section>
		<section>
			<h3>{ui('Yesterday — ERP Sales', 'الأمس — مبيعات ERP')}</h3>
			<div class="total-card">
				<span>{ui('Total sales', 'إجمالي المبيعات')} — {selectedScopeName}</span>
				<strong>{money(yesterdayTotal)} <small>{ui('SAR', 'ر.س')}</small></strong>
				<em>{yesterdayBills} {ui('bills', 'فاتورة')}</em>
			</div>
			<h4>{ui('Branch breakdown', 'تفصيل الفروع')}</h4>
			{#if mobile}
				<div class="previous-month-comparison">
					<div>
						<span>{ui('Same date, previous month', 'نفس التاريخ من الشهر السابق')}</span>
						<small>{displayDate(previousMonthSameDayDate)}</small>
					</div>
					<div class="comparison-value">
						<strong>{money(previousMonthSameDayTotal)} <small>{ui('SAR', 'ر.س')}</small></strong>
						<em>{previousMonthSameDayBills} {ui('bills', 'فاتورة')}</em>
					</div>
				</div>
			{/if}
			<div class="grid">
				{#each visibleYesterdaySales as branch}{@render BranchCard(branch)}{/each}
			</div>
		</section>
	{/if}
</div>

{#snippet BranchCard(branch: BranchSales)}
	<article class:offline={branch.status === 'unavailable'}>
		<div class="branch-head">
			<strong>{branch.branch_name}</strong>
			<span class:bad={branch.status === 'unavailable'}>{branch.status === 'online' ? ui('Live', 'مباشر') : ui('Unavailable', 'غير متاح')}</span>
		</div>
		<div class="amount">{money(branch.total_amount)} <small>{ui('SAR', 'ر.س')}</small></div>
		{#if branch.status === 'online'}
			<div class="details">
				<span>{branch.total_bills} {ui('bills', 'فاتورة')}</span>
				<span>{ui('Returns', 'المرتجعات')}: {money(branch.total_return)}</span>
				<span>{ui('Basket', 'المتوسط')}: {money(branch.total_bills > 0 ? branch.total_amount / branch.total_bills : 0)}</span>
			</div>
		{/if}
		{#if branch.error}<p class="error" title={branch.error}>{ui('Branch connection failed', 'فشل اتصال الفرع')}</p>{/if}
	</article>
{/snippet}

<style>
	.live-report { padding: 1.25rem; min-height: 100%; background: #f5f8fb; color: #16324a; }
	header { display: flex; justify-content: space-between; align-items: center; gap: 1rem; margin-bottom: 1.25rem; }
	h2 { margin: 0; font-size: 1.5rem; }
	header p { margin: .3rem 0 0; color: #64748b; }
	button { border: 0; border-radius: .65rem; padding: .7rem 1.2rem; background: #0787a8; color: white; font-weight: 700; cursor: pointer; }
	button:disabled { opacity: .6; cursor: wait; }
	section { background: white; border: 1px solid #dbe5ed; border-radius: 1rem; padding: 1rem; margin-bottom: 1rem; box-shadow: 0 4px 14px rgba(15, 48, 73, .06); }
	h3 { margin: 0 0 1rem; font-size: 1rem; }
	h4 { margin: 1rem 0 .65rem; color: #475569; font-size: .82rem; text-transform: uppercase; letter-spacing: .04em; }
	.total-card { display: grid; grid-template-columns: 1fr auto; align-items: center; gap: .25rem 1rem; padding: 1rem; border-radius: .85rem; background: linear-gradient(135deg, #073b5c, #0787a8); color: white; }
	.total-card span { font-size: .85rem; opacity: .85; }
	.total-card strong { grid-row: span 2; font-size: 1.8rem; }
	.total-card strong small { font-size: .75rem; opacity: .75; }
	.total-card em { font-size: .75rem; opacity: .8; font-style: normal; }
	.previous-month-comparison { display: flex; align-items: center; justify-content: space-between; gap: .75rem; margin: .65rem 0 .8rem; padding: .75rem; border: 1px solid #bae6fd; border-radius: .75rem; background: #f0f9ff; }
	.previous-month-comparison > div:first-child { display: flex; flex-direction: column; gap: .2rem; }
	.previous-month-comparison span { color: #475569; font-size: .72rem; font-weight: 700; }
	.previous-month-comparison small { color: #64748b; font-size: .68rem; }
	.comparison-value { display: flex; flex-direction: column; align-items: flex-end; gap: .15rem; text-align: end; }
	.comparison-value strong { color: #075985; font-size: 1rem; white-space: nowrap; }
	.comparison-value strong small { font-size: .62rem; }
	.comparison-value em { color: #64748b; font-size: .68rem; font-style: normal; }
	.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .8rem; }
	article { border: 1px solid #cfe8df; border-inline-start: 4px solid #0ca678; border-radius: .8rem; padding: .9rem; background: #f8fffc; }
	article.offline { border-color: #f2c7c7; border-inline-start-color: #dc2626; background: #fff8f8; }
	.branch-head { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
	.branch-head span { padding: .18rem .45rem; border-radius: 999px; background: #d7f7e9; color: #087f5b; font-size: .7rem; font-weight: 700; }
	.branch-head span.bad { background: #fee2e2; color: #b91c1c; }
	.amount { margin: .7rem 0; font-size: 1.45rem; font-weight: 800; color: #0f766e; }
	.amount small { font-size: .7rem; color: #64748b; }
	.details { display: flex; flex-wrap: wrap; gap: .65rem; color: #64748b; font-size: .78rem; }
	.error { margin: .5rem 0 0; color: #b91c1c; font-size: .75rem; }
	.loading { display: grid; place-items: center; min-height: 240px; color: #64748b; }
	.mobile { padding: .7rem; background: linear-gradient(180deg, #eef8fb 0, #f5f8fb 220px); }
	.mobile-report-toolbar { display: flex; align-items: flex-end; gap: .55rem; margin-bottom: .75rem; padding: .75rem; border: 1px solid #dbe5ed; border-radius: .9rem; background: rgba(255, 255, 255, .95); box-shadow: 0 3px 12px rgba(15, 48, 73, .05); }
	.mobile-report-toolbar label { display: flex; flex: 1; min-width: 0; flex-direction: column; gap: .35rem; }
	.mobile-report-toolbar label > span { color: #475569; font-size: .68rem; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; }
	.mobile-report-toolbar select { width: 100%; min-height: 42px; padding: .55rem 2rem .55rem .7rem; border: 1px solid #b9cbd8; border-radius: .65rem; background: white; color: #16324a; font: inherit; font-size: .78rem; font-weight: 700; }
	.mobile-report-toolbar .mobile-refresh-btn { display: inline-flex; align-items: center; justify-content: center; gap: .25rem; min-height: 42px; padding: .5rem .65rem; border-radius: .65rem; background: #0787a8; color: white; font-size: .68rem; white-space: nowrap; }
	.mobile-refresh-btn span { font-size: 1rem; line-height: 1; }
	.sales-overview-card { margin-bottom: .75rem; padding: .85rem; border: 1px solid #dbe5ed; border-radius: .9rem; background: white; box-shadow: 0 4px 14px rgba(15, 48, 73, .06); }
	.mobile-card-title h3 { margin: 0; color: #172554; font-size: 1rem; }
	.mobile-card-title p { margin: .15rem 0 .65rem; color: #7890a5; font-size: .65rem; }
	.overview-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: .4rem; }
	.overview-stat { display: flex; min-width: 0; flex-direction: column; align-items: center; gap: .2rem; padding: .55rem .25rem; border-radius: .7rem; text-align: center; }
	.overview-stat small { min-height: 1.7em; color: #64748b; font-size: .54rem; line-height: 1.15; }
	.overview-stat strong { max-width: 100%; overflow: hidden; color: #172554; font-size: .7rem; text-overflow: ellipsis; white-space: nowrap; }
	.overview-icon { display: grid; width: 32px; height: 32px; place-items: center; border-radius: 50%; font-size: .85rem; font-weight: 900; }
	.net-stat { background: #effcf8; } .net-stat .overview-icon { background: #c7f9e8; color: #059669; }
	.bills-stat { background: #eff6ff; } .bills-stat .overview-icon { background: #dbeafe; color: #2563eb; }
	.basket-stat { background: #fff8ed; } .basket-stat .overview-icon { background: #ffedc7; color: #d97706; }
	.returns-stat { background: #fff1f5; } .returns-stat .overview-icon { background: #ffd9e4; color: #e11d48; }
	.sales-comparison-chart { overflow: hidden; padding: .9rem; background: linear-gradient(145deg, #ffffff, #f8fcfe); }
	.chart-row { position: relative; margin-top: .55rem; padding: .65rem; border: 1px solid #e5edf4; border-radius: .75rem; background: white; box-shadow: 0 2px 8px rgba(15, 48, 73, .04); }
	.today-row { display: none; }
	.period-head { display: grid; grid-template-columns: auto minmax(0, 1fr) auto auto; align-items: center; gap: .45rem; margin-bottom: .48rem; }
	.period-icon { display: grid; width: 32px; height: 32px; place-items: center; border-radius: 50%; font-size: .75rem; font-weight: 900; }
	.today-icon { background: #d7f8ed; color: #0ca678; }
	.yesterday-icon { background: #dbeafe; color: #1687d9; }
	.two-days-icon { background: #fef3c7; color: #d97706; }
	.previous-icon { background: #ede9fe; color: #7c3aed; }
	.period-name { display: flex; min-width: 0; flex-direction: column; }
	.period-name strong { color: #172554; font-size: .76rem; }
	.period-name small { color: #94a3b8; font-size: .58rem; }
	.period-net { display: flex; flex-direction: column; align-items: flex-end; text-align: end; }
	.period-net small { color: #94a3b8; font-size: .54rem; }
	.period-net strong { color: #172554; font-size: .72rem; white-space: nowrap; }
	.change-badge { padding: .24rem .38rem; border-radius: 999px; font-size: .52rem; font-weight: 800; white-space: nowrap; }
	.change-badge.positive { background: #dcfce7; color: #059669; }
	.change-badge.negative { background: #ffe4e6; color: #e11d48; }
	.chart-label { display: flex; align-items: center; justify-content: space-between; gap: .5rem; margin-bottom: .3rem; font-size: .7rem; }
	.chart-label span { color: #475569; font-weight: 700; }
	.chart-label strong { color: #16324a; font-size: .75rem; }
	.chart-track { height: 10px; overflow: hidden; border-radius: 999px; background: #e8eef3; }
	.chart-bar { height: 100%; border-radius: inherit; transition: width .35s ease; }
	.chart-metrics { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: .25rem .5rem; margin-top: .4rem; padding-top: .4rem; border-top: 1px solid #eef2f7; color: #64748b; font-size: .58rem; font-weight: 700; }
	.chart-metrics span:last-child { color: #b45309; }
	.embedded-previous-month { margin-top: .65rem; padding: .65rem; border: 1px dashed #c4b5fd; border-radius: .7rem; background: linear-gradient(145deg, #fdfcff, #f7f5ff); }
	.embedded-previous-head { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; align-items: center; gap: .45rem; margin-bottom: .48rem; }
	.embedded-previous-month .period-icon { width: 32px; height: 32px; }
	.embedded-previous-month .period-name strong { color: #5b21b6; font-size: .76rem; }
	.embedded-previous-month .period-name small { font-size: .58rem; }
	.embedded-previous-month .period-net small { font-size: .54rem; }
	.embedded-previous-month .period-net strong { color: #5b21b6; font-size: .72rem; }
	.embedded-previous-month .chart-track { height: 10px; background: #e9e3ff; }
	.embedded-previous-month .bar-percent { margin-top: .18rem; }
	.embedded-metrics { margin-top: .4rem; padding-top: .4rem; border-top-color: #e9e3ff; }
	.previous-month-row { display: none; }
	.today-bar { background: linear-gradient(90deg, #0ca678, #20c997); }
	.yesterday-bar { background: linear-gradient(90deg, #0787a8, #38bdf8); }
	.two-days-bar { background: linear-gradient(90deg, #d97706, #fbbf24); }
	.previous-bar { background: linear-gradient(90deg, #7c3aed, #a78bfa); }
	.bar-percent { display: block; margin-top: .18rem; color: #94a3b8; font-size: .52rem; text-align: end; }
	.sales-update-footer { display: flex; align-items: center; justify-content: space-between; gap: .7rem; margin-top: .75rem; padding: .7rem; border: 1px solid #dbeafe; border-radius: .75rem; background: rgba(255,255,255,.86); color: #64748b; font-size: .55rem; }
	.sales-update-footer span { flex: 1; }
	.sales-update-footer small { text-align: end; white-space: nowrap; }
	.mobile section { border-radius: .9rem; padding: .85rem; }
	.mobile > section:not(.sales-comparison-chart) { display: none; }
	.mobile .total-card { box-shadow: 0 6px 18px rgba(7, 59, 92, .16); }
	.mobile .grid { grid-template-columns: 1fr; }
	@media (max-width: 640px) { header { align-items: flex-start; } .grid { grid-template-columns: 1fr; } }
</style>
