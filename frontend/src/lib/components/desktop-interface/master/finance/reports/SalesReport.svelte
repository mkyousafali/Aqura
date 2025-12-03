<script lang="ts">
	import { onMount } from 'svelte';
	import { get } from 'svelte/store';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { goAPI } from '$lib/utils/goAPI';
	import { _ as t, currentLocale } from '$lib/i18n';

	interface DailySales {
		date: string;
		total_amount: number;
		total_bills: number;
		total_return: number;
		minAmount?: number;
	}

	interface MonthlyAverage {
		month: string;
		average: number;
		totalDays: number;
	}

	interface BranchSales {
		branch_id: number;
		branch_name: string;
		total_amount: number;
		total_bills: number;
		total_return: number;
		currentMonthAvg?: number;
		previousMonthAvg?: number;
		totalDays?: number;
	}

	let salesData: DailySales[] = [];
	let branchSalesData: BranchSales[] = [];
	let yesterdayBranchSalesData: BranchSales[] = [];
	let currentMonthAvg: MonthlyAverage | null = null;
	let previousMonthAvg: MonthlyAverage | null = null;
	let loading = true;
	let loadingBranch = true;
	let loadingYesterdayBranch = true;
	let maxAmount = 0;
	let minAmount = 0;
	let maxBranchAmount = 0;
	let maxYesterdayBranchAmount = 0;

	onMount(async () => {
		// Test Go backend availability
		const { data: healthData } = await goAPI.healthCheck();
		if (healthData) {
			console.log('🚀 Go backend is available:', healthData);
			
			// Test fetching sales data from Go backend
			const testStart = performance.now();
			const { data: goSalesData, error } = await goAPI.sales.getDailySales();
			const testEnd = performance.now();
			
			if (goSalesData) {
				console.log(`✅ Go backend sales data fetched in ${(testEnd - testStart).toFixed(2)}ms`);
				console.log('📊 Go backend returned:', goSalesData.count, 'sales records');
			} else if (error) {
				console.log('⚠️ Go backend error:', error);
			}
		}
		
		await loadSalesData();
		await loadBranchSalesData();
		await loadYesterdayBranchSalesData();
	});

	async function loadSalesData() {
		loading = true;
		const startTime = performance.now();
		console.log('📊 Loading sales data...');
		
		try {
			// Use Saudi Arabia timezone (UTC+3)
			const saudiOffset = 3 * 60; // 3 hours in minutes
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
			// Format date as YYYY-MM-DD string directly to avoid timezone conversion issues
			const formatDate = (date: Date) => {
				const year = date.getFullYear();
				const month = String(date.getMonth() + 1).padStart(2, '0');
				const day = String(date.getDate()).padStart(2, '0');
				return `${year}-${month}-${day}`;
			};
			
			const today = formatDate(saudiTime);
			const yesterday = new Date(saudiTime);
			yesterday.setDate(yesterday.getDate() - 1);
			const dayBeforeYesterday = new Date(saudiTime);
			dayBeforeYesterday.setDate(dayBeforeYesterday.getDate() - 2);

			const dates = [
				formatDate(dayBeforeYesterday),
				formatDate(yesterday),
				today
			];

			// Calculate current and previous month date ranges
			const currentMonthStart = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 1));
			const currentMonthEnd = today;
			
			const previousMonthDate = new Date(saudiTime.getFullYear(), saudiTime.getMonth() - 1, 1);
			const previousMonthStart = formatDate(previousMonthDate);
			const previousMonthEnd = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 0));

			// Fetch daily sales data from Go backend (last 3 days)
			const { data, error } = await goAPI.sales.getDailySales({
				startDate: formatDate(dayBeforeYesterday),
				endDate: today
			});

			if (error) throw error;
			
			// Debug: Log actual dates in the response
			console.log('📊 API returned records:', data?.count);
			console.log('📊 Sample dates from API:', data?.records?.slice(0, 5).map(r => r.sale_date));

			// Fetch current month data
			const { data: currentMonthData, error: currentMonthError } = await goAPI.sales.getDailySales({
				startDate: currentMonthStart,
				endDate: currentMonthEnd
			});

			// Fetch previous month data
			const { data: previousMonthData, error: previousMonthError } = await goAPI.sales.getDailySales({
				startDate: previousMonthStart,
				endDate: previousMonthEnd
			});

			// Group by date and sum amounts for daily chart
			const groupedData = dates.map(date => {
				// Extract just the date part from ISO timestamp (2025-12-03T00:00:00Z -> 2025-12-03)
				const dayData = data?.records?.filter(d => d.sale_date?.substring(0, 10) === date) || [];
				console.log(`📊 Processing date ${date}:`, {
					recordCount: dayData.length,
					sampleRecord: dayData[0],
					netAmounts: dayData.map(d => d.net_amount)
				});
				const total_amount = dayData.reduce((sum, d) => sum + (d.net_amount || 0), 0);
				const total_bills = dayData.reduce((sum, d) => sum + (d.net_bills || 0), 0);
				const total_return = dayData.reduce((sum, d) => sum + (d.return_amount || 0), 0);
				return { date, total_amount, total_bills, total_return };
			});
			
			console.log('📊 Sales data grouped:', groupedData);
			salesData = groupedData;
			minAmount = Math.min(...groupedData.map(d => d.total_amount));
			maxAmount = Math.max(...groupedData.map(d => d.total_amount), 1);

			// Calculate current month average
			if (currentMonthData?.records && !currentMonthError) {
				const uniqueDates = [...new Set(currentMonthData.records.map(d => d.sale_date))];
				const totalAmount = currentMonthData.records.reduce((sum, d) => sum + (d.net_amount || 0), 0);
				currentMonthAvg = {
					month: saudiTime.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
					average: uniqueDates.length > 0 ? totalAmount / uniqueDates.length : 0,
					totalDays: uniqueDates.length
				};
			}

			// Calculate previous month average
			if (previousMonthData?.records && !previousMonthError) {
				const uniqueDates = [...new Set(previousMonthData.records.map(d => d.sale_date))];
				const totalAmount = previousMonthData.records.reduce((sum, d) => sum + (d.net_amount || 0), 0);
				previousMonthAvg = {
					month: previousMonthDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
					average: uniqueDates.length > 0 ? totalAmount / uniqueDates.length : 0,
					totalDays: uniqueDates.length
				};
			}
		} catch (err) {
			console.error('❌ Error loading sales data:', err);
		} finally {
			const endTime = performance.now();
			const duration = (endTime - startTime).toFixed(2);
			console.log(`✅ Sales data loaded in ${duration}ms (Source: Go Backend)`);
			loading = false;
		}
	}

	async function loadBranchSalesData() {
		loadingBranch = true;
		const startTime = performance.now();
		console.log('📊 Loading branch sales data...');
		
		try {
			// Use Saudi Arabia timezone (UTC+3)
			const saudiOffset = 3 * 60;
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
			// Format date as YYYY-MM-DD string directly to avoid timezone conversion issues
			const formatDate = (date: Date) => {
				const year = date.getFullYear();
				const month = String(date.getMonth() + 1).padStart(2, '0');
				const day = String(date.getDate()).padStart(2, '0');
				return `${year}-${month}-${day}`;
			};
			
			const todayStr = formatDate(saudiTime);

			// Calculate current and previous month date ranges
			const currentMonthStart = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 1));
			const currentMonthEnd = todayStr;
			
			const previousMonthDate = new Date(saudiTime.getFullYear(), saudiTime.getMonth() - 1, 1);
			const previousMonthStart = formatDate(previousMonthDate);
			const previousMonthEnd = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 0));

			// Fetch today's sales by branch from Go backend
			const { data, error } = await goAPI.sales.getDailySales({
				startDate: todayStr,
				endDate: todayStr
			});

			if (error) throw error;

			console.log('📊 Today branch sales API response:', data);
			console.log('📊 Today string for comparison:', todayStr);
			console.log('📊 Sample sale_date from records:', data?.records?.[0]?.sale_date);

			// Get branch names
			const branchIds = [...new Set(data?.records?.map(d => d.branch_id) || [])];
			
			let branchMap = new Map();
			if (branchIds.length > 0) {
				try {
					const { data: branchData, error: branchError } = await supabaseAdmin
						.from('branches')
						.select('id, location_en, location_ar')
						.in('id', branchIds);

					if (branchError) {
						console.error('Error fetching branch locations:', branchError);
					} else {
						const locale = get(currentLocale);
						branchMap = new Map(branchData?.map(b => [b.id, locale === 'ar' ? (b.location_ar || b.location_en) : (b.location_en || b.location_ar)]) || []);
					}
				} catch (branchErr) {
					console.error('Exception fetching branches:', branchErr);
				}
			}

			// Group by branch
			const groupedByBranch = branchIds.map(branchId => {
				const branchItems = data?.records?.filter(d => d.branch_id === branchId) || [];
				const total_amount = branchItems.reduce((sum, d) => sum + (d.net_amount || 0), 0);
				const total_bills = branchItems.reduce((sum, d) => sum + (d.net_bills || 0), 0);
				const total_return = branchItems.reduce((sum, d) => sum + (d.return_amount || 0), 0);
				const result = {
					branch_id: branchId,
					branch_name: branchMap.get(branchId) || `Branch ${branchId}`,
					total_amount,
					total_bills,
					total_return
				};
				console.log(`📊 Today Branch ${branchId}:`, {
					items: branchItems.length,
					total_amount,
					total_bills,
					basket: total_bills > 0 ? total_amount / total_bills : 0,
					sampleBills: branchItems.slice(0, 2).map(d => ({ net_bills: d.net_bills, net_amount: d.net_amount }))
				});
				return result;
			});

			// Fetch current month data by branch
			const { data: currentMonthData } = await goAPI.sales.getDailySales({
				startDate: currentMonthStart,
				endDate: currentMonthEnd
			});

			// Fetch previous month data by branch
			const { data: previousMonthData } = await goAPI.sales.getDailySales({
				startDate: previousMonthStart,
				endDate: previousMonthEnd
			});

			// Calculate averages for each branch
			groupedByBranch.forEach(branch => {
				// Current month average for this branch
				if (currentMonthData?.records) {
					const branchCurrentData = currentMonthData.records.filter(d => d.branch_id === branch.branch_id);
					const uniqueDates = [...new Set(branchCurrentData.map(d => d.sale_date))];
					const totalAmount = branchCurrentData.reduce((sum, d) => sum + (d.net_amount || 0), 0);
					branch.currentMonthAvg = uniqueDates.length > 0 ? totalAmount / uniqueDates.length : 0;
					branch.totalDays = uniqueDates.length;
				}
				
				// Previous month average for this branch
				if (previousMonthData?.records) {
					const branchPreviousData = previousMonthData.records.filter(d => d.branch_id === branch.branch_id);
					const uniqueDates = [...new Set(branchPreviousData.map(d => d.sale_date))];
					const totalAmount = branchPreviousData.reduce((sum, d) => sum + (d.net_amount || 0), 0);
					branch.previousMonthAvg = uniqueDates.length > 0 ? totalAmount / uniqueDates.length : 0;
				}
			});

			branchSalesData = groupedByBranch;
			maxBranchAmount = Math.max(...groupedByBranch.map(d => d.total_amount), 1);
		} catch (err) {
			console.error('❌ Error loading branch sales data:', err);
		} finally {
			const endTime = performance.now();
			const duration = (endTime - startTime).toFixed(2);
			console.log(`✅ Branch sales data loaded in ${duration}ms (Source: Go Backend)`);
			loadingBranch = false;
		}
	}

	async function loadYesterdayBranchSalesData() {
		loadingYesterdayBranch = true;
		const startTime = performance.now();
		console.log('📊 Loading yesterday branch sales data...');
		
		try {
			// Use Saudi Arabia timezone (UTC+3)
			const saudiOffset = 3 * 60;
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
			// Format date as YYYY-MM-DD string directly to avoid timezone conversion issues
			const formatDate = (date: Date) => {
				const year = date.getFullYear();
				const month = String(date.getMonth() + 1).padStart(2, '0');
				const day = String(date.getDate()).padStart(2, '0');
				return `${year}-${month}-${day}`;
			};
			
			const yesterday = new Date(saudiTime);
			yesterday.setDate(yesterday.getDate() - 1);
			const yesterdayStr = formatDate(yesterday);

		// Fetch yesterday's sales by branch from Go backend
		const { data, error } = await goAPI.sales.getDailySales({
			startDate: yesterdayStr,
			endDate: yesterdayStr
		});

		if (error) throw error;

		console.log('📊 Yesterday branch sales API response:', data);

		// Get branch names
		const branchIds = [...new Set(data?.records?.map(d => d.branch_id) || [])];
		
		let branchMap = new Map();
		if (branchIds.length > 0) {
			try {
				const { data: branchData, error: branchError } = await supabaseAdmin
					.from('branches')
					.select('id, location_en, location_ar')
					.in('id', branchIds);

				if (branchError) {
					console.error('Error fetching branch locations:', branchError);
				} else {
					const locale = get(currentLocale);
					branchMap = new Map(branchData?.map(b => [b.id, locale === 'ar' ? (b.location_ar || b.location_en) : (b.location_en || b.location_ar)]) || []);
				}
			} catch (branchErr) {
				console.error('Exception fetching branches:', branchErr);
			}
		}

		// Group by branch
		const groupedByBranch = branchIds.map(branchId => {
			const branchItems = data?.records?.filter(d => d.branch_id === branchId) || [];
			const total_amount = branchItems.reduce((sum, d) => sum + (d.net_amount || 0), 0);
			const total_bills = branchItems.reduce((sum, d) => sum + (d.net_bills || 0), 0);
			const total_return = branchItems.reduce((sum, d) => sum + (d.return_amount || 0), 0);
			return {
				branch_id: branchId,
				branch_name: branchMap.get(branchId) || `Branch ${branchId}`,
				total_amount,
				total_bills,
				total_return
			};
		});		yesterdayBranchSalesData = groupedByBranch;
		maxYesterdayBranchAmount = Math.max(...groupedByBranch.map(d => d.total_amount), 1);
	} catch (err) {
		console.error('❌ Error loading yesterday branch sales data:', err);
	} finally {
		const endTime = performance.now();
		const duration = (endTime - startTime).toFixed(2);
		console.log(`✅ Yesterday branch sales data loaded in ${duration}ms (Source: Go Backend)`);
		loadingYesterdayBranch = false;
	}
}	function getBarColor(amount: number): string {
		const amounts = salesData.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981'; // Green for top
		if (amount === lowest) return '#ef4444'; // Red for lowest
		return '#f97316'; // Orange for middle
	}

	function getBarHeight(amount: number): number {
		if (!maxAmount) return 0;
		const percent = (amount / maxAmount) * 100;
		// Ensure the tallest bar reaches the top; others scale proportionally
		return Math.min(Math.max(Math.round(percent), 0), 100);
	}

	function getBranchBarColor(amount: number): string {
		const amounts = branchSalesData.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981'; // Green for top
		if (amount === lowest) return '#ef4444'; // Red for lowest
		return '#f97316'; // Orange for middle
	}

	function getBranchBarHeight(amount: number): number {
		if (!maxBranchAmount) return 0;
		const percent = (amount / maxBranchAmount) * 100;
		return Math.min(Math.max(Math.round(percent), 0), 100);
	}

	function getYesterdayBranchBarColor(amount: number): string {
		const amounts = yesterdayBranchSalesData.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981'; // Green for top
		if (amount === lowest) return '#ef4444'; // Red for lowest
		return '#f97316'; // Orange for middle
	}

	function getYesterdayBranchBarHeight(amount: number): number {
		if (!maxYesterdayBranchAmount) return 0;
		const percent = (amount / maxYesterdayBranchAmount) * 100;
		return Math.min(Math.max(Math.round(percent), 0), 100);
	}

	function formatDate(dateStr: string) {
		const date = new Date(dateStr + 'T00:00:00');
		
		// Use Saudi Arabia timezone for comparison
		const saudiOffset = 3 * 60;
		const now = new Date();
		const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
		
		const formatDateStr = (d: Date) => {
			const year = d.getFullYear();
			const month = String(d.getMonth() + 1).padStart(2, '0');
			const day = String(d.getDate()).padStart(2, '0');
			return `${year}-${month}-${day}`;
		};
		
		const today = formatDateStr(saudiTime);
		const yesterday = new Date(saudiTime);
		yesterday.setDate(yesterday.getDate() - 1);
		const dayBeforeYesterday = new Date(saudiTime);
		dayBeforeYesterday.setDate(dayBeforeYesterday.getDate() - 2);

		if (dateStr === today) return $t('reports.today');
		if (dateStr === formatDateStr(yesterday)) return $t('reports.yesterday');
		if (dateStr === formatDateStr(dayBeforeYesterday)) return $t('reports.twoDaysAgo');
		return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}

	function formatCurrency(amount: number) {
		return new Intl.NumberFormat('en-SA', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(amount);
	}
</script>

<div class="sales-report-container">
	<div class="sales-card">
		<div class="header">
			<h3>{$t('reports.dailySalesOverview')}</h3>
			<button class="refresh-btn" on:click={loadSalesData} disabled={loading} title={$t('common.refresh')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
				</svg>
			</button>
		</div>
		{#if loading}
			<div class="loading">{$t('common.loading')}</div>
		{:else}
			<!-- Monthly Averages -->
			<div class="monthly-averages">
				{#if previousMonthAvg}
					<div class="month-avg previous">
						<div class="month-label">{$t('reports.previousMonth')}</div>
						<div class="month-value">
							<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
							{formatCurrency(previousMonthAvg.average)}
						</div>
						<div class="month-days">{$t('reports.averagePerDay')} ({previousMonthAvg.totalDays} {$t('reports.days')})</div>
					</div>
				{/if}
				{#if currentMonthAvg}
					<div class="month-avg current">
						<div class="month-label">{$t('reports.currentMonth')}</div>
						<div class="month-value">
							<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
							{formatCurrency(currentMonthAvg.average)}
						</div>
						<div class="month-days">{$t('reports.averagePerDay')} ({currentMonthAvg.totalDays} {$t('reports.days')})</div>
					</div>
				{/if}
			</div>

			<div class="chart-container">
				{#each salesData as day}
					<div class="sale-item">
						<div class="bar-container">
							<div class="bar" style="height: {getBarHeight(day.total_amount)}%; background-color: {getBarColor(day.total_amount)};"></div>
						</div>
					<div class="sale-info">
						<div class="date-label">{formatDate(day.date)}</div>
						<div class="amount-label">
							<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
							{formatCurrency(day.total_amount)}
						</div>
					<div class="bills-label">{day.total_bills} {$t('reports.bills')}</div>
					<div class="basket-label">
						{$t('reports.basket')}: <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
						{formatCurrency(day.total_bills > 0 ? day.total_amount / day.total_bills : 0)}
					</div>
					<div class="return-label">
						{$t('reports.return')}: {((day.total_return / (day.total_amount + day.total_return)) * 100 || 0).toFixed(1)}%
					</div>
				</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Branch Sales Card -->
	<div class="sales-card">
		<div class="header">
			<h3>{$t('reports.todayBranchSales')}</h3>
			<button class="refresh-btn" on:click={loadBranchSalesData} disabled={loadingBranch} title={$t('common.refresh')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
				</svg>
			</button>
		</div>
		{#if loadingBranch}
			<div class="loading">{$t('common.loading')}</div>
		{:else}
			<div class="chart-container">
				{#each branchSalesData as branch}
					<div class="sale-item">
						<!-- Monthly Averages per Branch -->
						<div class="branch-monthly-badges">
							{#if branch.previousMonthAvg !== undefined}
								<div class="mini-badge previous-badge">
									<div class="badge-label">{$t('reports.previous')}</div>
									<div class="badge-value">
										<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-micro" />
										{formatCurrency(branch.previousMonthAvg)}
									</div>
								</div>
							{/if}
							{#if branch.currentMonthAvg !== undefined}
								<div class="mini-badge current-badge">
									<div class="badge-label">{$t('reports.current')}</div>
									<div class="badge-value">
										<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-micro" />
										{formatCurrency(branch.currentMonthAvg)}
									</div>
								</div>
							{/if}
						</div>

						<div class="bar-container">
							<div class="bar" style="height: {getBranchBarHeight(branch.total_amount)}%; background-color: {getBranchBarColor(branch.total_amount)};"></div>
						</div>
						<div class="sale-info">
							<div class="date-label">{branch.branch_name}</div>
							<div class="amount-label">
								<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
							<div class="bills-label">{branch.total_bills} {$t('reports.bills')}</div>
							<div class="basket-label">
								{$t('reports.basket')}: <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
								{formatCurrency(branch.total_bills > 0 ? branch.total_amount / branch.total_bills : 0)}
							</div>
							<div class="return-label">
								{$t('reports.return')}: {((branch.total_return / (branch.total_amount + branch.total_return)) * 100 || 0).toFixed(1)}%
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Yesterday's Branch Sales Card -->
	<div class="sales-card">
		<div class="header">
			<h3>{$t('reports.yesterdayBranchSales')}</h3>
			<button class="refresh-btn" on:click={loadYesterdayBranchSalesData} disabled={loadingYesterdayBranch} title={$t('common.refresh')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
				</svg>
			</button>
		</div>
		{#if loadingYesterdayBranch}
			<div class="loading">{$t('common.loading')}</div>
		{:else}
			<div class="chart-container">
				{#each yesterdayBranchSalesData as branch}
					<div class="sale-item">
						<div class="bar-container">
							<div class="bar" style="height: {getYesterdayBranchBarHeight(branch.total_amount)}%; background-color: {getYesterdayBranchBarColor(branch.total_amount)};"></div>
						</div>
						<div class="sale-info">
							<div class="date-label">{branch.branch_name}</div>
							<div class="amount-label">
								<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
							<div class="bills-label">{branch.total_bills} {$t('reports.bills')}</div>
							<div class="basket-label">
								{$t('reports.basket')}: <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
								{formatCurrency(branch.total_bills > 0 ? branch.total_amount / branch.total_bills : 0)}
							</div>
							<div class="return-label">
								{$t('reports.return')}: {((branch.total_return / (branch.total_amount + branch.total_return)) * 100 || 0).toFixed(1)}%
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.sales-report-container {
		padding: 1rem;
		width: 100%;
		height: 100%;
		background-color: var(--background);
		overflow-y: auto;
		display: flex;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.sales-card {
		background: white;
		border-radius: 16px;
		padding: 1rem;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		max-width: 450px;
		border: 2px solid #10b981;
		height: fit-content;
	}

	.branch-monthly-badges {
		display: flex;
		gap: 0.4rem;
		margin-bottom: 0.5rem;
		flex-wrap: wrap;
		justify-content: center;
	}

	.mini-badge {
		padding: 0.5rem 0.75rem;
		border-radius: 8px;
		font-size: 0.65rem;
		color: white;
		min-width: 70px;
	}

	.mini-badge.previous-badge {
		background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
	}

	.mini-badge.current-badge {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.badge-label {
		font-size: 0.7rem;
		opacity: 0.9;
		text-transform: uppercase;
		font-weight: 600;
		margin-bottom: 0.25rem;
	}

	.badge-value {
		font-size: 0.8rem;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
	}

	.currency-icon-micro {
		width: 12px;
		height: 12px;
		filter: brightness(0) invert(1);
	}

	h3 {
		margin: 0;
		color: #333;
		font-size: 1rem;
		font-weight: 600;
	}

	.header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1rem;
	}

	.refresh-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 0.5rem;
		border-radius: 6px;
		display: flex;
		align-items: center;
		justify-content: center;
		color: #666;
		transition: all 0.2s ease;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #f3f4f6;
		color: #333;
	}

	.refresh-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.refresh-btn svg {
		animation: spin 1s linear infinite;
		animation-play-state: paused;
	}

	.refresh-btn:disabled svg {
		animation-play-state: running;
	}

	@keyframes spin {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
	}

	.loading {
		text-align: center;
		padding: 2rem;
		color: #666;
	}

	.monthly-averages {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.month-avg {
		flex: 1;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		padding: 0.75rem;
		border-radius: 10px;
		color: white;
	}

	.month-avg.current {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.month-avg.previous {
		background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
	}

	.month-label {
		font-size: 0.6rem;
		opacity: 0.9;
		margin-bottom: 0.35rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.month-value {
		font-size: 0.95rem;
		font-weight: 700;
		display: flex;
		align-items: center;
		gap: 0.25rem;
		margin-bottom: 0.2rem;
	}

	.month-value .currency-icon {
		width: 12px;
		height: 12px;
		filter: brightness(0) invert(1);
	}

	.month-days {
		font-size: 0.55rem;
		opacity: 0.85;
	}

	.chart-container {
		display: flex;
		justify-content: space-around;
		align-items: flex-end;
		gap: 1rem;
		padding: 2rem 1rem 1rem;
		height: 400px;
		background: #f9fafb;
		border-radius: 12px;
	}

	.sale-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
		flex: 1;
		min-height: 100%;
		max-width: 120px;
		overflow: visible;
	}

	.bar-container {
		flex: 1;
		height: 100%;
		width: 50px;
		display: flex;
		align-items: flex-end;
	}

	.bar {
		width: 100%;
		border-radius: 8px 8px 0 0;
		transition: all 0.3s ease;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
	}

	.bar:hover {
		transform: translateY(-5px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
	}

	.sale-info {
		text-align: center;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		width: 100%;
		overflow-wrap: break-word;
	}

	.date-label {
		font-weight: 600;
		color: #333;
		font-size: 0.75rem;
	}

	.amount-label {
		font-weight: 700;
		color: #111;
		font-size: 0.8rem;
		word-break: break-word;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
	}

	.currency-icon {
		width: 14px;
		height: 14px;
		object-fit: contain;
	}

	.bills-label {
		font-size: 0.65rem;
		color: #666;
	}

	.basket-label {
		font-size: 0.65rem;
		color: #10b981;
		font-weight: 600;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.2rem;
	}

	.return-label {
		font-size: 0.65rem;
		color: #ef4444;
		font-weight: 600;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.2rem;
	}

	.currency-icon-small {
		width: 10px;
		height: 10px;
		object-fit: contain;
	}
</style>
