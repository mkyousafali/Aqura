<script lang="ts">
	import { onMount } from 'svelte';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, currentLocale } from '$lib/i18n';

	interface DailySales {
		date: string;
		total_amount: number;
		total_bills: number;
		total_return: number;
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
	let todayCollectionData: BranchSales[] = [];
	let yesterdayCollectionData: BranchSales[] = [];
	let currentMonthAvg: MonthlyAverage | null = null;
	let previousMonthAvg: MonthlyAverage | null = null;
	let loading = true;
	let loadingBranch = true;
	let loadingYesterdayBranch = true;
	let loadingTodayCollection = true;
	let loadingYesterdayCollection = true;
	let maxAmount = 0;
	let maxBranchAmount = 0;
	let maxYesterdayBranchAmount = 0;
	let maxTodayCollectionAmount = 0;
	let maxYesterdayCollectionAmount = 0;

	onMount(async () => {
		// Load all data in parallel for maximum speed
		await Promise.all([
			loadSalesData(),
			loadBranchSalesData(),
			loadYesterdayBranchSalesData(),
			loadTodayCollectionData(),
			loadYesterdayCollectionData()
		]);
	});

	async function loadSalesData() {
		loading = true;
		const startTime = performance.now();
		console.log('📊 [Mobile] Loading sales data...');
		
		try {
			const saudiOffset = 3 * 60;
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
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

			const currentMonthStart = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 1));
			const currentMonthEnd = today;
			
			const previousMonthDate = new Date(saudiTime.getFullYear(), saudiTime.getMonth() - 1, 1);
			const previousMonthStart = formatDate(previousMonthDate);
			const previousMonthEnd = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 0));

			// Fetch all data in parallel
			const [
				{ data: salesRecords, error },
				{ data: currentMonthRecords, error: currentMonthError },
				{ data: previousMonthRecords, error: previousMonthError }
			] = await Promise.all([
				supabase
					.from('erp_daily_sales')
					.select('sale_date, net_amount, net_bills, return_amount')
					.gte('sale_date', formatDate(dayBeforeYesterday))
					.lte('sale_date', today),
				supabase
					.from('erp_daily_sales')
					.select('sale_date, net_amount')
					.gte('sale_date', currentMonthStart)
					.lte('sale_date', currentMonthEnd),
				supabase
					.from('erp_daily_sales')
					.select('sale_date, net_amount')
					.gte('sale_date', previousMonthStart)
					.lte('sale_date', previousMonthEnd)
			]);

			const data = { count: salesRecords?.length || 0, records: salesRecords || [] };

			if (error) throw error;

			console.log('📊 [Mobile] API returned records:', data?.count);

			// Group by date
			const groupedData = dates.map(date => {
				const dayData = data?.records?.filter(d => d.sale_date?.substring(0, 10) === date) || [];
				const total_amount = dayData.reduce((sum, d) => sum + (d.net_amount || 0), 0);
				const total_bills = dayData.reduce((sum, d) => sum + (d.net_bills || 0), 0);
				const total_return = dayData.reduce((sum, d) => sum + (d.return_amount || 0), 0);
				return { date, total_amount, total_bills, total_return };
			});
			
			salesData = groupedData;
			maxAmount = Math.max(...groupedData.map(d => d.total_amount), 1);

			// Calculate current month average
			if (currentMonthRecords) {
				const uniqueDates = [...new Set(currentMonthRecords.map(d => d.sale_date))];
				const totalAmount = currentMonthRecords.reduce((sum, d) => sum + (d.net_amount || 0), 0);
				currentMonthAvg = {
					month: saudiTime.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
					average: uniqueDates.length > 0 ? totalAmount / uniqueDates.length : 0,
					totalDays: uniqueDates.length
				};
			}

			// Calculate previous month average
			if (previousMonthRecords) {
				const uniqueDates = [...new Set(previousMonthRecords.map(d => d.sale_date))];
				const totalAmount = previousMonthRecords.reduce((sum, d) => sum + (d.net_amount || 0), 0);
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
			console.log(`✅ [Mobile] Sales data loaded in ${duration}ms`);
			loading = false;
		}
	}

	async function loadBranchSalesData() {
		loadingBranch = true;
		const startTime = performance.now();
		console.log('📊 [Mobile] Loading branch sales data...');
		
		try {
			const saudiOffset = 3 * 60;
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
			const formatDate = (date: Date) => {
				const year = date.getFullYear();
				const month = String(date.getMonth() + 1).padStart(2, '0');
				const day = String(date.getDate()).padStart(2, '0');
				return `${year}-${month}-${day}`;
			};
			
			const todayStr = formatDate(saudiTime);
			const currentMonthStart = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 1));
			const currentMonthEnd = todayStr;
			
			const previousMonthDate = new Date(saudiTime.getFullYear(), saudiTime.getMonth() - 1, 1);
			const previousMonthStart = formatDate(previousMonthDate);
			const previousMonthEnd = formatDate(new Date(saudiTime.getFullYear(), saudiTime.getMonth(), 0));

			// Fetch all data in parallel
			const [
				{ data: salesRecords, error },
				{ data: currentMonthRecords },
				{ data: previousMonthRecords }
			] = await Promise.all([
				supabase
					.from('erp_daily_sales')
					.select('branch_id, net_amount, net_bills, return_amount')
					.eq('sale_date', todayStr),
				supabase
					.from('erp_daily_sales')
					.select('branch_id, sale_date, net_amount')
					.gte('sale_date', currentMonthStart)
					.lte('sale_date', currentMonthEnd),
				supabase
					.from('erp_daily_sales')
					.select('branch_id, sale_date, net_amount')
					.gte('sale_date', previousMonthStart)
					.lte('sale_date', previousMonthEnd)
			]);

			const data = { records: salesRecords || [] };
			if (error) throw error;

			const branchIds = [...new Set(data?.records?.map(d => d.branch_id) || [])];
			
			let branchMap = new Map();
			if (branchIds.length > 0) {
				try {
					const { data: branchData } = await supabase
						.from('branches')
						.select('id, location_en, location_ar')
						.in('id', branchIds);

					if (branchData) {
						const locale = get(currentLocale);
						branchMap = new Map(branchData.map(b => [b.id, locale === 'ar' ? (b.location_ar || b.location_en) : (b.location_en || b.location_ar)]) || []);
					}
				} catch (branchErr) {
					console.error('Exception fetching branches:', branchErr);
				}
			}

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
			});

			// Calculate averages
			groupedByBranch.forEach(branch => {
				if (currentMonthRecords) {
					const branchCurrentData = currentMonthRecords.filter(d => d.branch_id === branch.branch_id);
					const uniqueDates = [...new Set(branchCurrentData.map(d => d.sale_date))];
					const totalAmount = branchCurrentData.reduce((sum, d) => sum + (d.net_amount || 0), 0);
					branch.currentMonthAvg = uniqueDates.length > 0 ? totalAmount / uniqueDates.length : 0;
					branch.totalDays = uniqueDates.length;
				}
				
				if (previousMonthRecords) {
					const branchPreviousData = previousMonthRecords.filter(d => d.branch_id === branch.branch_id);
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
			console.log(`✅ [Mobile] Branch sales data loaded in ${duration}ms`);
			loadingBranch = false;
		}
	}

	async function loadYesterdayBranchSalesData() {
		loadingYesterdayBranch = true;
		const startTime = performance.now();
		console.log('📊 [Mobile] Loading yesterday branch sales data...');
		
		try {
			const saudiOffset = 3 * 60;
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
			const formatDate = (date: Date) => {
				const year = date.getFullYear();
				const month = String(date.getMonth() + 1).padStart(2, '0');
				const day = String(date.getDate()).padStart(2, '0');
				return `${year}-${month}-${day}`;
			};
			
			const yesterday = new Date(saudiTime);
			yesterday.setDate(yesterday.getDate() - 1);
			const yesterdayStr = formatDate(yesterday);

			const { data: salesRecords, error } = await supabase
				.from('erp_daily_sales')
				.select('branch_id, net_amount, net_bills, return_amount')
				.eq('sale_date', yesterdayStr);
			
			const data = { records: salesRecords || [] };
			if (error) throw error;

			const branchIds = [...new Set(data?.records?.map(d => d.branch_id) || [])];
			
			let branchMap = new Map();
			if (branchIds.length > 0) {
				try {
					const { data: branchData } = await supabase
						.from('branches')
						.select('id, location_en, location_ar')
						.in('id', branchIds);

					if (branchData) {
						const locale = get(currentLocale);
						branchMap = new Map(branchData.map(b => [b.id, locale === 'ar' ? (b.location_ar || b.location_en) : (b.location_en || b.location_ar)]) || []);
					}
				} catch (branchErr) {
					console.error('Exception fetching branches:', branchErr);
				}
			}

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
			});

			yesterdayBranchSalesData = groupedByBranch;
			maxYesterdayBranchAmount = Math.max(...groupedByBranch.map(d => d.total_amount), 1);
		} catch (err) {
			console.error('❌ Error loading yesterday branch sales data:', err);
		} finally {
			const endTime = performance.now();
			const duration = (endTime - startTime).toFixed(2);
			console.log(`✅ [Mobile] Yesterday branch sales data loaded in ${duration}ms`);
			loadingYesterdayBranch = false;
		}
	}

	async function loadTodayCollectionData() {
		loadingTodayCollection = true;
		const startTime = performance.now();
		console.log('📊 [Mobile] Loading today collection data...');
		
		try {
			const saudiOffset = 3 * 60;
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
			const formatDate = (date: Date) => {
				const year = date.getFullYear();
				const month = String(date.getMonth() + 1).padStart(2, '0');
				const day = String(date.getDate()).padStart(2, '0');
				return `${year}-${month}-${day}`;
			};
			
			const today = formatDate(saudiTime);
			
			const { data: records, error } = await supabase
				.from('box_operations')
				.select(`
					*,
					branches!inner(id, location_en, location_ar)
				`)
				.eq('status', 'completed')
				.gte('start_time', `${today}T00:00:00`)
				.lte('start_time', `${today}T23:59:59`);
			
			if (error) throw error;
			
			const locale = get(currentLocale);
			const branchIds = [...new Set(records?.map(r => r.branch_id) || [])];
			const groupedByBranch = branchIds.map(branchId => {
				const branchRecords = records?.filter(r => r.branch_id === branchId) || [];
				const branchInfo = branchRecords[0]?.branches;
				const branchName = branchInfo ? (locale === 'ar' ? (branchInfo.location_ar || branchInfo.location_en) : (branchInfo.location_en || branchInfo.location_ar)) : `Branch ${branchId}`;
				
				let total_amount = 0;
				branchRecords.forEach(record => {
					try {
						const closingDetails = typeof record.closing_details === 'string' 
							? JSON.parse(record.closing_details) 
							: record.closing_details;
						
						if (closingDetails?.total_sales) {
							total_amount += parseFloat(closingDetails.total_sales) || 0;
						}
					} catch (e) {
						console.error('Error parsing closing_details:', e);
					}
				});
				
				return {
					branch_id: branchId,
					branch_name: branchName,
					total_amount,
					total_bills: 0,
					total_return: 0
				};
			});
			
			todayCollectionData = groupedByBranch;
			maxTodayCollectionAmount = Math.max(...groupedByBranch.map(d => d.total_amount), 1);
		} catch (err) {
			console.error('❌ Error loading today collection data:', err);
		} finally {
			const endTime = performance.now();
			const duration = (endTime - startTime).toFixed(2);
			console.log(`✅ [Mobile] Today collection data loaded in ${duration}ms`);
			loadingTodayCollection = false;
		}
	}

	async function loadYesterdayCollectionData() {
		loadingYesterdayCollection = true;
		const startTime = performance.now();
		console.log('📊 [Mobile] Loading yesterday collection data...');
		
		try {
			const saudiOffset = 3 * 60;
			const now = new Date();
			const saudiTime = new Date(now.getTime() + (saudiOffset + now.getTimezoneOffset()) * 60000);
			
			const formatDate = (date: Date) => {
				const year = date.getFullYear();
				const month = String(date.getMonth() + 1).padStart(2, '0');
				const day = String(date.getDate()).padStart(2, '0');
				return `${year}-${month}-${day}`;
			};
			
			const yesterday = new Date(saudiTime);
			yesterday.setDate(yesterday.getDate() - 1);
			const yesterdayStr = formatDate(yesterday);
			
			const { data: records, error } = await supabase
				.from('box_operations')
				.select(`
					*,
					branches!inner(id, location_en, location_ar)
				`)
				.eq('status', 'completed')
				.gte('start_time', `${yesterdayStr}T00:00:00`)
				.lte('start_time', `${yesterdayStr}T23:59:59`);
			
			if (error) throw error;
			
			const locale = get(currentLocale);
			const branchIds = [...new Set(records?.map(r => r.branch_id) || [])];
			const groupedByBranch = branchIds.map(branchId => {
				const branchRecords = records?.filter(r => r.branch_id === branchId) || [];
				const branchInfo = branchRecords[0]?.branches;
				const branchName = branchInfo ? (locale === 'ar' ? (branchInfo.location_ar || branchInfo.location_en) : (branchInfo.location_en || branchInfo.location_ar)) : `Branch ${branchId}`;
				
				let total_amount = 0;
				branchRecords.forEach(record => {
					try {
						const closingDetails = typeof record.closing_details === 'string' 
							? JSON.parse(record.closing_details) 
							: record.closing_details;
						
						if (closingDetails?.total_sales) {
							total_amount += parseFloat(closingDetails.total_sales) || 0;
						}
					} catch (e) {
						console.error('Error parsing closing_details:', e);
					}
				});
				
				return {
					branch_id: branchId,
					branch_name: branchName,
					total_amount,
					total_bills: 0,
					total_return: 0
				};
			});
			
			yesterdayCollectionData = groupedByBranch;
			maxYesterdayCollectionAmount = Math.max(...groupedByBranch.map(d => d.total_amount), 1);
		} catch (err) {
			console.error('❌ Error loading yesterday collection data:', err);
		} finally {
			const endTime = performance.now();
			const duration = (endTime - startTime).toFixed(2);
			console.log(`✅ [Mobile] Yesterday collection data loaded in ${duration}ms`);
			loadingYesterdayCollection = false;
		}
	}

	function getBarColor(amount: number): string {
		const amounts = salesData.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981';
		if (amount === lowest) return '#ef4444';
		return '#f97316';
	}

	function getBarHeight(amount: number): number {
		if (!maxAmount || maxAmount === 0) return 20;
		const percent = (amount / maxAmount) * 100;
		return Math.max(Math.round(percent), 20);
	}

	function getBranchBarColor(amount: number): string {
		const amounts = branchSalesData.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981';
		if (amount === lowest) return '#ef4444';
		return '#f97316';
	}

	function getBranchBarHeight(amount: number): number {
		if (!maxBranchAmount || maxBranchAmount === 0) return 20;
		const percent = (amount / maxBranchAmount) * 100;
		return Math.max(Math.round(percent), 20);
	}

	function getYesterdayBranchBarColor(amount: number): string {
		const amounts = yesterdayBranchSalesData.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981';
		if (amount === lowest) return '#ef4444';
		return '#f97316';
	}

	function getYesterdayBranchBarHeight(amount: number): number {
		if (!maxYesterdayBranchAmount || maxYesterdayBranchAmount === 0) return 20;
		const percent = (amount / maxYesterdayBranchAmount) * 100;
		return Math.max(Math.round(percent), 20);
	}

	function getCollectionBarColor(amount: number, dataArray: BranchSales[]): string {
		const amounts = dataArray.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981';
		if (amount === lowest) return '#ef4444';
		return '#f97316';
	}

	function getCollectionBarHeight(amount: number, maxAmount: number): number {
		if (!maxAmount || maxAmount === 0) return 20;
		const percent = (amount / maxAmount) * 100;
		return Math.max(Math.round(percent), 20);
	}

	function formatDate(dateStr: string) {
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

		if (dateStr === today) return $t('reports.today');
		if (dateStr === formatDateStr(yesterday)) return $t('reports.yesterday');
		return new Date(dateStr + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}

	function formatCurrency(amount: number) {
		return new Intl.NumberFormat('en-SA', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(amount);
	}
</script>

<div class="mobile-sales-report-container">
	<!-- Daily Sales Card -->
	<div class="sales-card">
		<div class="card-header">
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
			<div class="monthly-averages">
				{#if previousMonthAvg}
					<div class="month-avg previous">
						<div class="month-label">{$t('reports.previousMonth')}</div>
						<div class="month-value">
							<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
							{formatCurrency(previousMonthAvg.average)}
						</div>
						<div class="month-days">{previousMonthAvg.totalDays} {$t('reports.days')}</div>
					</div>
				{/if}
				{#if currentMonthAvg}
					<div class="month-avg current">
						<div class="month-label">{$t('reports.currentMonth')}</div>
						<div class="month-value">
							<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
							{formatCurrency(currentMonthAvg.average)}
						</div>
						<div class="month-days">{currentMonthAvg.totalDays} {$t('reports.days')}</div>
					</div>
				{/if}
			</div>

			<div class="chart-container">
				{#each salesData as day}
					<div class="sale-item">
						<div class="bar-container">
							<div class="bar" style="height: {getBarHeight(day.total_amount)}px; background-color: {getBarColor(day.total_amount)};"></div>
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
		<div class="card-header">
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
							<div class="bar" style="height: {getBranchBarHeight(branch.total_amount)}px; background-color: {getBranchBarColor(branch.total_amount)};"></div>
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

	<!-- Yesterday Branch Sales Card -->
	<div class="sales-card">
		<div class="card-header">
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
							<div class="bar" style="height: {getYesterdayBranchBarHeight(branch.total_amount)}px; background-color: {getYesterdayBranchBarColor(branch.total_amount)};"></div>
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

	<!-- Today Collection Sales Card -->
	<div class="sales-card">
		<div class="card-header">
			<h3>{$t('reports.todayCollectionSales')}</h3>
			<button class="refresh-btn" on:click={loadTodayCollectionData} disabled={loadingTodayCollection} title={$t('common.refresh')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
				</svg>
			</button>
		</div>
		{#if loadingTodayCollection}
			<div class="loading">{$t('common.loading')}</div>
		{:else}
			<div class="chart-container">
				{#each todayCollectionData as branch}
					<div class="sale-item">
						<div class="bar-container">
							<div class="bar" style="height: {getCollectionBarHeight(branch.total_amount, maxTodayCollectionAmount)}px; background-color: {getCollectionBarColor(branch.total_amount, todayCollectionData)};"></div>
						</div>
						<div class="sale-info">
							<div class="date-label">{branch.branch_name}</div>
							<div class="amount-label">
								<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Yesterday Collection Sales Card -->
	<div class="sales-card">
		<div class="card-header">
			<h3>{$t('reports.yesterdayCollectionSales')}</h3>
			<button class="refresh-btn" on:click={loadYesterdayCollectionData} disabled={loadingYesterdayCollection} title={$t('common.refresh')}>
				<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"/>
				</svg>
			</button>
		</div>
		{#if loadingYesterdayCollection}
			<div class="loading">{$t('common.loading')}</div>
		{:else}
			<div class="chart-container">
				{#each yesterdayCollectionData as branch}
					<div class="sale-item">
						<div class="bar-container">
							<div class="bar" style="height: {getCollectionBarHeight(branch.total_amount, maxYesterdayCollectionAmount)}px; background-color: {getCollectionBarColor(branch.total_amount, yesterdayCollectionData)};"></div>
						</div>
						<div class="sale-info">
							<div class="date-label">{branch.branch_name}</div>
							<div class="amount-label">
								<img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.mobile-sales-report-container {
		padding: 0.75rem;
		width: 100%;
		background-color: #f8f9fa;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.sales-card {
		background: white;
		border-radius: 16px;
		padding: 1rem;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		border: 2px solid #10b981;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.card-header h3 {
		font-size: 1rem;
		font-weight: 700;
		color: #1f2937;
		margin: 0;
	}

	.refresh-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 0.5rem;
		display: flex;
		align-items: center;
		justify-content: center;
		color: #10b981;
		transition: transform 0.3s ease;
	}

	.refresh-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.refresh-btn:active:not(:disabled) {
		transform: rotate(180deg);
	}

	.loading {
		text-align: center;
		padding: 2rem;
		color: #6b7280;
		font-size: 0.9rem;
	}

	.monthly-averages {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
		flex-wrap: wrap;
		justify-content: center;
	}

	.month-avg {
		padding: 0.75rem;
		border-radius: 12px;
		color: white;
		text-align: center;
		flex: 1;
		min-width: 100px;
	}

	.month-avg.previous {
		background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
	}

	.month-avg.current {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.month-label {
		font-size: 0.65rem;
		opacity: 0.9;
		margin-bottom: 0.35rem;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.month-value {
		font-size: 0.9rem;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
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
		gap: 0.75rem;
		padding: 1.5rem 0.5rem 1rem;
		min-height: 280px;
		background: #f9fafb;
		border-radius: 12px;
		overflow-x: auto;
	}

	.sale-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
		flex: 1;
		min-width: 60px;
		overflow: visible;
	}

	.branch-monthly-badges {
		display: flex;
		gap: 0.3rem;
		margin-bottom: 0.5rem;
		flex-wrap: wrap;
		justify-content: center;
	}

	.mini-badge {
		padding: 0.4rem 0.6rem;
		border-radius: 6px;
		font-size: 0.55rem;
		color: white;
		min-width: 60px;
	}

	.mini-badge.previous-badge {
		background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
	}

	.mini-badge.current-badge {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.badge-label {
		font-size: 0.6rem;
		opacity: 0.9;
		margin-bottom: 0.2rem;
		font-weight: 500;
		text-transform: uppercase;
	}

	.badge-value {
		font-size: 0.65rem;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.15rem;
	}

	.currency-icon-micro {
		width: 8px;
		height: 8px;
		filter: brightness(0) invert(1);
	}

	.bar-container {
		flex: 1;
		height: 100%;
		width: 40px;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		min-height: 180px;
	}

	.bar {
		width: 80%;
		min-height: 20px;
		max-height: 100%;
		border-radius: 8px 8px 0 0;
		transition: all 0.3s ease;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
	}

	.bar:hover {
		transform: translateY(-3px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
	}

	.sale-info {
		text-align: center;
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
		width: 100%;
		overflow-wrap: break-word;
	}

	.date-label {
		font-weight: 600;
		color: #333;
		font-size: 0.7rem;
	}

	.amount-label {
		font-weight: 700;
		color: #111;
		font-size: 0.75rem;
		word-break: break-word;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.2rem;
	}

	.currency-icon {
		width: 12px;
		height: 12px;
		object-fit: contain;
	}

	.bills-label {
		font-size: 0.6rem;
		color: #666;
	}

	.basket-label {
		font-size: 0.6rem;
		color: #10b981;
		font-weight: 600;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.15rem;
	}

	.return-label {
		font-size: 0.6rem;
		color: #ef4444;
		font-weight: 600;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.15rem;
	}

	.currency-icon-small {
		width: 9px;
		height: 9px;
		object-fit: contain;
	}
</style>
