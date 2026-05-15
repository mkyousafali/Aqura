<script lang="ts">
	import { onMount } from 'svelte';
	import { get } from 'svelte/store';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { iconUrlMap } from '$lib/stores/iconStore';
	import * as XLSX from 'xlsx';

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
	let minAmount = 0;
	let maxBranchAmount = 0;
	let maxYesterdayBranchAmount = 0;
	let maxTodayCollectionAmount = 0;
	let maxYesterdayCollectionAmount = 0;

	// Real-time subscription
	let subscription: any = null;

	// ── REPORT MODE ──────────────────────────────────────────────────────────────
	let reportMode: 'quick' | 'detailed' | 'monthly' = 'quick';

	// Detailed report filters
	const _nowRef = new Date();
	let detailYear: number = _nowRef.getFullYear();
	let detailMonthFrom: number = _nowRef.getMonth();
	let detailMonthTo: number   = _nowRef.getMonth();

	const YEARS = Array.from({ length: 5 }, (_, i) => _nowRef.getFullYear() - i);
	const MONTH_NAMES = [
		'January', 'February', 'March', 'April', 'May', 'June',
		'July', 'August', 'September', 'October', 'November', 'December'
	];

	interface DetailRow {
		date: string;
		branch_id: number;
		branch_name: string;
		net_amount: number;
		net_bills: number;
		avg_basket: number;
		return_amount: number;
		return_pct: number;
		prev_amount: number | null;
		diff: number | null;
		trend: 'up' | 'down' | 'neutral';
	}

	let detailRows: DetailRow[] = [];
	let loadingDetail = false;

	// Pivot structure: rows = dates, columns = branches × {Sales, Bills, Avg Basket}
	let detailDates: string[] = [];
	let detailBranches: { id: number; name: string }[] = [];
	let detailPivotMap = new Map<string, { net_amount: number; net_bills: number; avg_basket: number }>();

	$: detailTotalSales  = detailRows.reduce((s, r) => s + r.net_amount, 0);
	$: detailTotalBills  = detailRows.reduce((s, r) => s + r.net_bills, 0);
	$: detailTotalReturn = detailRows.reduce((s, r) => s + r.return_amount, 0);
	$: detailAvgBasket   = detailTotalBills > 0 ? detailTotalSales / detailTotalBills : 0;
	$: detailAvgPerDay   = detailDates.length > 0 ? detailTotalSales / detailDates.length : 0;

	// ── MONTHLY SUMMARY ────────────────────────────────────────────────────
	let monthlyYearFrom:  number = _nowRef.getFullYear();
	let monthlyMonthFrom: number = 0;                       // January
	let monthlyYearTo:   number = _nowRef.getFullYear();
	let monthlyMonthTo:  number = _nowRef.getMonth();       // current month

	let monthlyMonths:   string[] = [];                     // 'YYYY-MM' labels
	let monthlyBranches: { id: number; name: string }[] = [];
	let monthlyPivotMap  = new Map<string, { net_amount: number; net_bills: number; avg_basket: number }>();
	let loadingMonthly   = false;

	$: monthlyTotalSales  = [...monthlyPivotMap.values()].reduce((s, v) => s + v.net_amount, 0);
	$: monthlyTotalBills  = [...monthlyPivotMap.values()].reduce((s, v) => s + v.net_bills,  0);
	$: monthlyAvgBasket   = monthlyTotalBills > 0 ? monthlyTotalSales / monthlyTotalBills : 0;
	$: monthlyAvgPerMonth = monthlyMonths.length > 0 ? monthlyTotalSales / monthlyMonths.length : 0;
	// ─────────────────────────────────────────────────────────────────────────────

	onMount(async () => {
		// TODO: Replace Go backend availability check with Supabase health check
		// const { data: healthData } = await goAPI.healthCheck();
		// if (healthData) {
		// 	console.log('🚀 Go backend is available:', healthData);
		// }
		
		await loadSalesData();
		await loadBranchSalesData();
		await loadYesterdayBranchSalesData();
		await loadTodayCollectionData();
		await loadYesterdayCollectionData();
		
		// Subscribe to real-time changes in erp_daily_sales table
		subscribeToSalesUpdates();

		// Cleanup on component unmount
		return () => {
			if (subscription) {
				subscription.unsubscribe();
				console.log('🛑 Unsubscribed from realtime updates');
			}
		};
	});

	function subscribeToSalesUpdates() {
		console.log('🔴 Attempting to subscribe to real-time sales updates...');
		console.log('📡 Using anon key for realtime WebSocket connection');
		
		try {
			// Check if supabase realtime is available
			if (!supabase.realtime) {
				console.error('❌ Supabase realtime client not available');
				return;
			}

			const channel = supabase
				.channel('public:erp_daily_sales')
				.on(
					'postgres_changes',
					{
						event: '*',
						schema: 'public',
						table: 'erp_daily_sales'
					},
					(payload: any) => {
						console.log('🔔 Real-time update received:', {
							event: payload.eventType,
							table: payload.table,
							record: payload.new || payload.old
						});
						
						// Update component state directly instead of reloading entire page
						handleRealtimeUpdate(payload);
					}
				)
				.subscribe((status: string, err?: any) => {
					if (status === 'SUBSCRIBED') {
						console.log('✅ Successfully subscribed to real-time updates');
					} else if (status === 'CHANNEL_ERROR') {
						console.error('❌ Channel error:', err);
						console.log('🔍 Debugging info:');
						console.log('  - Check if Realtime is enabled in Supabase Settings');
						console.log('  - Verify JWT token in anon key is valid');
						console.log('  - Check network connectivity to wss://supabase.urbanaqura.com');
					} else if (status === 'TIMED_OUT') {
						console.warn('⏱️ Subscription timed out, retrying in 5 seconds...');
						setTimeout(() => subscribeToSalesUpdates(), 5000);
					} else {
						console.log('📡 Subscription status changed:', status);
					}
				});

			subscription = channel;
		} catch (error) {
			console.error('❌ Error setting up subscription:', error);
		}
	}

	function handleRealtimeUpdate(payload: any) {
		console.log('⚡ Processing real-time update efficiently (no page reload)...');
		const record = payload.new || payload.old;
		
		if (!record) return;

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
		const yesterdayStr = formatDate(yesterday);
		
		const recordDate = record.sale_date?.substring(0, 10);
		
		console.log(`📅 Update for date: ${recordDate}, comparing with today: ${today}, yesterday: ${yesterdayStr}`);
		
		// Update branch sales if it's today
		if (recordDate === today) {
			console.log('💾 Updating today branch sales directly (no reload)...');
			updateBranchSalesDirectly(record, 'today');
		}
		
		// Update yesterday branch sales if it's yesterday
		if (recordDate === yesterdayStr) {
			console.log('💾 Updating yesterday branch sales directly (no reload)...');
			updateBranchSalesDirectly(record, 'yesterday');
		}
		
		// Update daily sales overview if it's in the last 3 days
		const dayBeforeYesterday = new Date(saudiTime);
		dayBeforeYesterday.setDate(dayBeforeYesterday.getDate() - 2);
		const dayBeforeYesterdayStr = formatDate(dayBeforeYesterday);
		
		if (recordDate === today || recordDate === yesterdayStr || recordDate === dayBeforeYesterdayStr) {
			console.log('💾 Updating daily sales directly (no reload)...');
			updateDailySalesDirectly(record, recordDate);
		}
	}

	function updateBranchSalesDirectly(record: any, period: 'today' | 'yesterday') {
		const branchData = period === 'today' ? branchSalesData : yesterdayBranchSalesData;
		const setter = period === 'today' ? ((v: any) => branchSalesData = v) : ((v: any) => yesterdayBranchSalesData = v);
		const maxSetter = period === 'today' ? ((v: number) => maxBranchAmount = v) : ((v: number) => maxYesterdayBranchAmount = v);
		
		// Find if branch exists in current data
		const existingIndex = branchData.findIndex(b => b.branch_id === record.branch_id);
		
		if (existingIndex >= 0) {
			// Update existing branch data
			const updatedBranch = branchData[existingIndex];
			updatedBranch.total_amount = (record.net_amount || 0);
			updatedBranch.total_bills = (record.net_bills || 0);
			updatedBranch.total_return = (record.return_amount || 0);
			
			// Recalculate max
			const newMax = Math.max(...branchData.map(d => d.total_amount), 1);
			maxSetter(newMax);
			
			// Trigger reactivity by reassigning
			setter([...branchData]);
			console.log(`✅ Updated ${period} branch ${record.branch_id} directly`);
		} else {
			// New branch - add it
			const newBranch = {
				branch_id: record.branch_id,
				branch_name: `Branch ${record.branch_id}`,
				total_amount: record.net_amount || 0,
				total_bills: record.net_bills || 0,
				total_return: record.return_amount || 0
			};
			branchData.push(newBranch);
			maxSetter(Math.max(...branchData.map(d => d.total_amount), 1));
			setter([...branchData]);
			console.log(`✅ Added new ${period} branch ${record.branch_id} directly`);
		}
	}

	function updateDailySalesDirectly(record: any, recordDate: string) {
		// Find if date exists in sales data
		const existingIndex = salesData.findIndex(d => d.date === recordDate);
		
		if (existingIndex >= 0) {
			// Update existing date - just increment the values
			const day = salesData[existingIndex];
			day.total_amount += (record.net_amount || 0);
			day.total_bills += (record.net_bills || 0);
			day.total_return += (record.return_amount || 0);
			
			// Recalculate min/max
			minAmount = Math.min(...salesData.map(d => d.total_amount));
			maxAmount = Math.max(...salesData.map(d => d.total_amount), 1);
			
			// Trigger reactivity
			salesData = [...salesData];
			console.log(`✅ Updated daily sales for ${recordDate} directly`);
		}
	}

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

			// Fetch daily sales data from Supabase (last 3 days)
			const { data: salesRecords, error } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.gte('sale_date', formatDate(dayBeforeYesterday))
				.lte('sale_date', today)
				.order('sale_date', { ascending: false });
			
			const data = { count: salesRecords?.length || 0, records: salesRecords || [] };

			if (error) throw error;
			
			// Debug: Log actual dates in the response
			console.log('📊 API returned records:', data?.count);
			console.log('📊 Sample dates from API:', data?.records?.slice(0, 5).map(r => r.sale_date));

			// Fetch current month data
			const { data: currentMonthRecords, error: currentMonthError } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.gte('sale_date', currentMonthStart)
				.lte('sale_date', currentMonthEnd);
			
			const currentMonthData = { records: currentMonthRecords || [] };

			// Fetch previous month data
			const { data: previousMonthRecords, error: previousMonthError } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.gte('sale_date', previousMonthStart)
				.lte('sale_date', previousMonthEnd);
			
			const previousMonthData = { records: previousMonthRecords || [] };

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
			console.log(`✅ Sales data loaded in ${duration}ms (Source: Supabase)`);
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

			// Fetch today's sales by branch from Supabase
			const { data: salesRecords, error } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.eq('sale_date', todayStr)
				.order('branch_id', { ascending: true });
			
			const data = { records: salesRecords || [] };

			if (error) throw error;

			console.log('📊 Today branch sales API response:', data);
			console.log('📊 Today string for comparison:', todayStr);
			console.log('📊 Sample sale_date from records:', data?.records?.[0]?.sale_date);

			// Get branch names
			const branchIds = [...new Set(data?.records?.map(d => d.branch_id) || [])];
			
			let branchMap = new Map();
			if (branchIds.length > 0) {
				try {
					const { data: branchData, error: branchError } = await supabase
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
			const { data: currentMonthRecords } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.gte('sale_date', currentMonthStart)
				.lte('sale_date', currentMonthEnd);
			
			const currentMonthData = { records: currentMonthRecords || [] };

			// Fetch previous month data by branch
			const { data: previousMonthRecords } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.gte('sale_date', previousMonthStart)
				.lte('sale_date', previousMonthEnd);
			
			const previousMonthData = { records: previousMonthRecords || [] };

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
			console.log(`✅ Branch sales data loaded in ${duration}ms (Source: Supabase)`);
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

		// Fetch yesterday's sales by branch from Supabase
		const { data: salesRecords, error } = await supabase
			.from('erp_daily_sales')
			.select('*')
			.eq('sale_date', yesterdayStr)
			.order('branch_id', { ascending: true });
		
		const data = { records: salesRecords || [] };

		if (error) throw error;

		console.log('📊 Yesterday branch sales API response:', data);

		// Get branch names
		const branchIds = [...new Set(data?.records?.map(d => d.branch_id) || [])];
		
		let branchMap = new Map();
		if (branchIds.length > 0) {
			try {
				const { data: branchData, error: branchError } = await supabase
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
		console.log(`✅ Yesterday branch sales data loaded in ${duration}ms (Source: Supabase)`);
		loadingYesterdayBranch = false;
	}
}

	async function loadTodayCollectionData() {
		loadingTodayCollection = true;
		const startTime = performance.now();
		console.log('📊 Loading today collection data...');
		
		try {
			// Get today's date in YYYY-MM-DD format
			const today = new Date().toISOString().split('T')[0];
			
			// Fetch today's completed box operations
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
			
			console.log('📊 Today collection records:', records);
			
			// Get branch names map
			const locale = get(currentLocale);
			
			// Group by branch
			const branchIds = [...new Set(records?.map(r => r.branch_id) || [])];
			const groupedByBranch = branchIds.map(branchId => {
				const branchRecords = records?.filter(r => r.branch_id === branchId) || [];
				const branchInfo = branchRecords[0]?.branches;
				const branchName = branchInfo ? (locale === 'ar' ? (branchInfo.location_ar || branchInfo.location_en) : (branchInfo.location_en || branchInfo.location_ar)) : `Branch ${branchId}`;
				
				// Sum total_sales from closing_details JSON
				let total_amount = 0;
				let total_bills = 0;
				
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
					total_bills,
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
			console.log(`✅ Today collection data loaded in ${duration}ms`);
			loadingTodayCollection = false;
		}
	}

	async function loadYesterdayCollectionData() {
		loadingYesterdayCollection = true;
		const startTime = performance.now();
		console.log('📊 Loading yesterday collection data...');
		
		try {
			// Get yesterday's date in YYYY-MM-DD format
			const yesterday = new Date();
			yesterday.setDate(yesterday.getDate() - 1);
			const yesterdayStr = yesterday.toISOString().split('T')[0];
			
			// Fetch yesterday's completed box operations
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
			
			console.log('📊 Yesterday collection records:', records);
			
			// Get branch names map
			const locale = get(currentLocale);
			
			// Group by branch
			const branchIds = [...new Set(records?.map(r => r.branch_id) || [])];
			const groupedByBranch = branchIds.map(branchId => {
				const branchRecords = records?.filter(r => r.branch_id === branchId) || [];
				const branchInfo = branchRecords[0]?.branches;
				const branchName = branchInfo ? (locale === 'ar' ? (branchInfo.location_ar || branchInfo.location_en) : (branchInfo.location_en || branchInfo.location_ar)) : `Branch ${branchId}`;
				
				// Sum total_sales from closing_details JSON
				let total_amount = 0;
				let total_bills = 0;
				
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
					total_bills,
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
			console.log(`✅ Yesterday collection data loaded in ${duration}ms`);
			loadingYesterdayCollection = false;
		}
	}

	function getCollectionBarColor(amount: number, dataArray: BranchSales[]): string {
		const amounts = dataArray.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981'; // Green for top
		if (amount === lowest) return '#ef4444'; // Red for lowest
		return '#f97316'; // Orange for middle
	}

	function getCollectionBarHeight(amount: number, maxAmount: number): number {
		if (!maxAmount || maxAmount === 0) return 20;
		const percent = (amount / maxAmount) * 100;
		return Math.max(Math.round(percent), 20); // Minimum 20px height
	}

	function getBarColor(amount: number): string {
		const amounts = salesData.map(d => d.total_amount).sort((a, b) => b - a);
		const highest = amounts[0];
		const lowest = amounts[amounts.length - 1];
		
		if (amount === highest) return '#10b981'; // Green for top
		if (amount === lowest) return '#ef4444'; // Red for lowest
		return '#f97316'; // Orange for middle
	}

	function getBarHeight(amount: number): number {
		if (!maxAmount || maxAmount === 0) return 20;
		const percent = (amount / maxAmount) * 100;
		return Math.max(Math.round(percent), 20); // Minimum 20px height
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
		if (!maxBranchAmount || maxBranchAmount === 0) return 20;
		const percent = (amount / maxBranchAmount) * 100;
		return Math.max(Math.round(percent), 20); // Minimum 20px height
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
		if (!maxYesterdayBranchAmount || maxYesterdayBranchAmount === 0) return 20;
		const percent = (amount / maxYesterdayBranchAmount) * 100;
		return Math.max(Math.round(percent), 20); // Minimum 20px height
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

	// ── DETAILED REPORT ───────────────────────────────────────────────────────────

	async function loadDetailedReport() {
		if (detailMonthTo < detailMonthFrom) detailMonthTo = detailMonthFrom;
		loadingDetail = true;
		try {
			const fromDate = `${detailYear}-${String(detailMonthFrom + 1).padStart(2, '0')}-01`;
			const lastDay  = new Date(detailYear, detailMonthTo + 1, 0).getDate();
			const toDate   = `${detailYear}-${String(detailMonthTo + 1).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

			const { data: records, error } = await supabase
				.from('erp_daily_sales')
				.select('sale_date, branch_id, net_amount, net_bills, return_amount')
				.gte('sale_date', fromDate)
				.lte('sale_date', toDate)
				.order('sale_date', { ascending: true })
				.order('branch_id', { ascending: true });

			if (error) throw error;

			// Fetch branch names
			const branchIds = [...new Set(records?.map(r => r.branch_id) || [])];
			let bMap = new Map<number, string>();
			if (branchIds.length > 0) {
				const { data: branches } = await supabase
					.from('branches')
					.select('id, location_en, location_ar')
					.in('id', branchIds);
				const locale = get(currentLocale);
				bMap = new Map(
					branches?.map(b => [
						b.id,
						locale === 'ar' ? (b.location_ar || b.location_en) : (b.location_en || b.location_ar)
					]) || []
				);
			}

			// Aggregate raw records by date + branch
			const grouped = new Map<string, { date: string; branch_id: number; net_amount: number; net_bills: number; return_amount: number }>();
			for (const r of (records || [])) {
				const d   = (r.sale_date as string)?.substring(0, 10);
				const key = `${d}|${r.branch_id}`;
				const ex  = grouped.get(key);
				if (ex) {
					ex.net_amount    += r.net_amount    || 0;
					ex.net_bills     += r.net_bills     || 0;
					ex.return_amount += r.return_amount || 0;
				} else {
					grouped.set(key, {
						date: d,
						branch_id: r.branch_id,
						net_amount:    r.net_amount    || 0,
						net_bills:     r.net_bills     || 0,
						return_amount: r.return_amount || 0,
					});
				}
			}

			// Sort by date then branch
			const entries = [...grouped.values()].sort(
				(a, b) => a.date.localeCompare(b.date) || a.branch_id - b.branch_id
			);

			detailRows = entries.map(entry => {
				// Compare to previous calendar day for the same branch
				const prevDate = new Date(entry.date + 'T00:00:00');
				prevDate.setDate(prevDate.getDate() - 1);
				const prevKey = `${prevDate.toISOString().split('T')[0]}|${entry.branch_id}`;
				const prev    = grouped.get(prevKey);
				const diff    = prev != null ? entry.net_amount - prev.net_amount : null;
				const gross   = entry.net_amount + entry.return_amount;
				return {
					date:          entry.date,
					branch_id:     entry.branch_id,
					branch_name:   bMap.get(entry.branch_id) || `Branch ${entry.branch_id}`,
					net_amount:    entry.net_amount,
					net_bills:     entry.net_bills,
					avg_basket:    entry.net_bills > 0 ? entry.net_amount / entry.net_bills : 0,
					return_amount: entry.return_amount,
					return_pct:    gross > 0 ? (entry.return_amount / gross) * 100 : 0,
					prev_amount:   prev?.net_amount ?? null,
					diff,
					trend: diff == null ? 'neutral' : diff > 0 ? 'up' : diff < 0 ? 'down' : 'neutral',
				};
			});

			// Build pivot structure for cross-tab table
			detailDates = [...new Set(entries.map(e => e.date))].sort();
			detailBranches = [...new Set(entries.map(e => e.branch_id))]
				.sort((a, b) => (a as number) - (b as number))
				.map(id => ({ id: id as number, name: bMap.get(id as number) || `Branch ${id}` }));
			detailPivotMap = new Map(
				entries.map(entry => [
					`${entry.date}|${entry.branch_id}`,
					{
						net_amount: entry.net_amount,
						net_bills:  entry.net_bills,
						avg_basket: entry.net_bills > 0 ? entry.net_amount / entry.net_bills : 0,
					}
				])
			);
		} catch (err) {
			console.error('❌ Error loading detailed report:', err);
		} finally {
			loadingDetail = false;
		}
	}

	function exportDetailExcel(lang: 'en' | 'ar') {
		const isAr = lang === 'ar';

		// Pivot-format export: row1 = branch headers, row2 = sub-headers, data rows = one per date
		const header1: string[] = [isAr ? 'التاريخ' : 'Date'];
		detailBranches.forEach(b => { header1.push(b.name, '', ''); });
		header1.push(isAr ? 'الإجمالي' : 'Total', '');

		const header2: string[] = [''];
		detailBranches.forEach(() => {
			header2.push(
				isAr ? 'المبيعات (ر.س)' : 'Sales (SAR)',
				isAr ? 'الفواتير' : 'Bills',
				isAr ? 'متوسط السلة' : 'Avg Basket',
				isAr ? 'الاتجاه' : 'Trend',
			);
		});
		header2.push(isAr ? 'المبيعات' : 'Sales', isAr ? 'الفواتير' : 'Bills', isAr ? 'الاتجاه' : 'Trend');

		const dataRows = detailDates.map((date, idx) => {
			const prevDate = detailDates[idx - 1] ?? null;
			const row: (string | number)[] = [date];
			let rowSales = 0, rowBills = 0;
			let prevRowSales = 0;
			detailBranches.forEach(b => {
				const cell     = detailPivotMap.get(`${date}|${b.id}`);
				const prevCell = prevDate ? detailPivotMap.get(`${prevDate}|${b.id}`) : null;
				const bTrend   = prevCell == null ? '—' : (cell?.net_amount ?? 0) > prevCell.net_amount ? '↑' : (cell?.net_amount ?? 0) < prevCell.net_amount ? '↓' : '—';
				row.push(
					cell?.net_amount ?? 0,
					cell?.net_bills  ?? 0,
					parseFloat((cell?.avg_basket ?? 0).toFixed(2)),
					bTrend,
				);
				rowSales += cell?.net_amount ?? 0;
				rowBills += cell?.net_bills  ?? 0;
				prevRowSales += prevCell?.net_amount ?? 0;
			});
			const rowTrend = prevDate == null ? '—' : rowSales > prevRowSales ? '↑' : rowSales < prevRowSales ? '↓' : '—';
			row.push(rowSales, rowBills, rowTrend);
			return row;
		});

		// Totals row
		const totalsRow: (string | number)[] = [isAr ? 'الإجمالي' : 'Total'];
		detailBranches.forEach(b => {
			const colSales = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${b.id}`)?.net_amount ?? 0), 0);
			const colBills = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${b.id}`)?.net_bills  ?? 0), 0);
			totalsRow.push(colSales, colBills, parseFloat((colBills > 0 ? colSales / colBills : 0).toFixed(2)), '');
		});
		totalsRow.push(detailTotalSales, detailTotalBills, '');

		// Avg per day row
		const avgDayRow: (string | number)[] = [isAr ? 'متوسط اليوم' : 'Avg / Day'];
		detailBranches.forEach(b => {
			const colSales = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${b.id}`)?.net_amount ?? 0), 0);
			const colBills = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${b.id}`)?.net_bills  ?? 0), 0);
			const avgS = detailDates.length > 0 ? colSales / detailDates.length : 0;
			const avgB = detailDates.length > 0 ? colBills / detailDates.length : 0;
			avgDayRow.push(
				parseFloat(avgS.toFixed(2)),
				parseFloat(avgB.toFixed(1)),
				parseFloat((avgB > 0 ? avgS / avgB : 0).toFixed(2)),
				'',
			);
		});
		avgDayRow.push(
			parseFloat(detailAvgPerDay.toFixed(2)),
			detailDates.length > 0 ? parseFloat((detailTotalBills / detailDates.length).toFixed(1)) : 0,
			'',
		);

		const ws = XLSX.utils.aoa_to_sheet([header1, header2, ...dataRows, totalsRow, avgDayRow]);

		// Merge branch header cells (4 cols each now: Sales, Bills, Avg, Trend)
		ws['!merges'] = [];
		let mc = 1;
		detailBranches.forEach(() => {
			ws['!merges']!.push({ s: { r: 0, c: mc }, e: { r: 0, c: mc + 3 } });
			mc += 4;
		});
		// Merge Total header (Sales, Bills, Trend)
		ws['!merges']!.push({ s: { r: 0, c: mc }, e: { r: 0, c: mc + 2 } });

		ws['!cols'] = Array(header1.length).fill({ wch: 18 });

		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, isAr ? 'تقرير المبيعات' : 'Sales Report');

		const filename = `Sales_${MONTH_NAMES[detailMonthFrom]}_to_${MONTH_NAMES[detailMonthTo]}_${detailYear}_${isAr ? 'AR' : 'EN'}.xlsx`;
		XLSX.writeFile(wb, filename);
	}
	// ─────────────────────────────────────────────────────────────────────────────

	// ── MONTHLY SUMMARY FUNCTIONS ───────────────────────────────────────────────
	async function loadMonthlySummary() {
		// Normalize: ensure from <= to
		const fromVal = monthlyYearFrom * 12 + monthlyMonthFrom;
		const toVal   = monthlyYearTo   * 12 + monthlyMonthTo;
		if (toVal < fromVal) { monthlyYearTo = monthlyYearFrom; monthlyMonthTo = monthlyMonthFrom; }

		loadingMonthly = true;
		try {
			const fromDate = `${monthlyYearFrom}-${String(monthlyMonthFrom + 1).padStart(2,'0')}-01`;
			const lastDay  = new Date(monthlyYearTo, monthlyMonthTo + 1, 0).getDate();
			const toDate   = `${monthlyYearTo}-${String(monthlyMonthTo + 1).padStart(2,'0')}-${String(lastDay).padStart(2,'0')}`;

			const { data: records, error } = await supabase
				.from('erp_daily_sales')
				.select('sale_date, branch_id, net_amount, net_bills')
				.gte('sale_date', fromDate)
				.lte('sale_date', toDate)
				.order('sale_date', { ascending: true })
				.order('branch_id', { ascending: true });

			if (error) throw error;

			// Fetch branch names
			const branchIds = [...new Set(records?.map(r => r.branch_id) || [])];
			let bMap = new Map<number, string>();
			if (branchIds.length > 0) {
				const { data: branches } = await supabase
					.from('branches').select('id, location_en, location_ar').in('id', branchIds);
				const locale = get(currentLocale);
				bMap = new Map(branches?.map(b => [
					b.id,
					locale === 'ar' ? (b.location_ar || b.location_en) : (b.location_en || b.location_ar)
				]) || []);
			}

			// Aggregate by YYYY-MM + branch_id
			const grouped = new Map<string, { net_amount: number; net_bills: number }>();
			for (const r of (records || [])) {
				const ym  = (r.sale_date as string)?.substring(0, 7); // 'YYYY-MM'
				const key = `${ym}|${r.branch_id}`;
				const ex  = grouped.get(key);
				if (ex) {
					ex.net_amount += r.net_amount || 0;
					ex.net_bills  += r.net_bills  || 0;
				} else {
					grouped.set(key, { net_amount: r.net_amount || 0, net_bills: r.net_bills || 0 });
				}
			}

			// Build ordered month list
			const monthSet = new Set<string>();
			for (const key of grouped.keys()) monthSet.add(key.split('|')[0]);
			monthlyMonths   = [...monthSet].sort();
			monthlyBranches = branchIds.sort((a: any, b: any) => a - b)
				.map((id: any) => ({ id: id as number, name: bMap.get(id as number) || `Branch ${id}` }));

			monthlyPivotMap = new Map(
				[...grouped.entries()].map(([key, val]) => [
					key,
					{ net_amount: val.net_amount, net_bills: val.net_bills, avg_basket: val.net_bills > 0 ? val.net_amount / val.net_bills : 0 }
				])
			);
		} catch (err) {
			console.error('❌ Error loading monthly summary:', err);
		} finally {
			loadingMonthly = false;
		}
	}

	function exportMonthlyExcel(lang: 'en' | 'ar') {
		const isAr = lang === 'ar';

		const header1: string[] = [isAr ? 'الشهر' : 'Month'];
		monthlyBranches.forEach(b => { header1.push(b.name, '', '', ''); });
		header1.push(isAr ? 'الإجمالي' : 'Total', '', '');

		const header2: string[] = [''];
		monthlyBranches.forEach(() => {
			header2.push(
				isAr ? 'المبيعات (ر.س)' : 'Sales (SAR)',
				isAr ? 'الفواتير' : 'Bills',
				isAr ? 'متوسط السلة' : 'Avg Basket',
				isAr ? 'الاتجاه' : 'Trend',
			);
		});
		header2.push(
			isAr ? 'المبيعات' : 'Sales',
			isAr ? 'الفواتير' : 'Bills',
			isAr ? 'الاتجاه' : 'Trend',
		);

		const dataRows = monthlyMonths.map((ym, idx) => {
			const prevYm = monthlyMonths[idx - 1] ?? null;
			const row: (string | number)[] = [ym];
			let rowSales = 0, rowBills = 0, prevRowSales = 0;
			monthlyBranches.forEach(b => {
				const cell     = monthlyPivotMap.get(`${ym}|${b.id}`);
				const prevCell = prevYm ? monthlyPivotMap.get(`${prevYm}|${b.id}`) : null;
				const bTrend   = prevCell == null ? '—' : (cell?.net_amount ?? 0) > prevCell.net_amount ? '↑' : (cell?.net_amount ?? 0) < prevCell.net_amount ? '↓' : '—';
				row.push(cell?.net_amount ?? 0, cell?.net_bills ?? 0, parseFloat((cell?.avg_basket ?? 0).toFixed(2)), bTrend);
				rowSales += cell?.net_amount ?? 0;
				rowBills += cell?.net_bills  ?? 0;
				prevRowSales += prevCell?.net_amount ?? 0;
			});
			const rowTrend = prevYm == null ? '—' : rowSales > prevRowSales ? '↑' : rowSales < prevRowSales ? '↓' : '—';
			row.push(rowSales, rowBills, rowTrend);
			return row;
		});

		const totalsRow: (string | number)[] = [isAr ? 'الإجمالي' : 'Total'];
		monthlyBranches.forEach(b => {
			const cs = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${b.id}`)?.net_amount ?? 0), 0);
			const cb = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${b.id}`)?.net_bills  ?? 0), 0);
			totalsRow.push(cs, cb, parseFloat((cb > 0 ? cs / cb : 0).toFixed(2)), '');
		});
		totalsRow.push(monthlyTotalSales, monthlyTotalBills, '');

		const avgRow: (string | number)[] = [isAr ? 'متوسط الشهر' : 'Avg / Month'];
		monthlyBranches.forEach(b => {
			const cs = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${b.id}`)?.net_amount ?? 0), 0);
			const cb = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${b.id}`)?.net_bills  ?? 0), 0);
			const n  = monthlyMonths.length || 1;
			const avgS = cs / n, avgB = cb / n;
			avgRow.push(parseFloat(avgS.toFixed(2)), parseFloat(avgB.toFixed(1)), parseFloat((avgB > 0 ? avgS / avgB : 0).toFixed(2)), '');
		});
		avgRow.push(parseFloat(monthlyAvgPerMonth.toFixed(2)), parseFloat((monthlyTotalBills / (monthlyMonths.length || 1)).toFixed(1)), '');

		const ws = XLSX.utils.aoa_to_sheet([header1, header2, ...dataRows, totalsRow, avgRow]);
		ws['!merges'] = [];
		let mc = 1;
		monthlyBranches.forEach(() => {
			ws['!merges']!.push({ s: { r: 0, c: mc }, e: { r: 0, c: mc + 3 } });
			mc += 4;
		});
		ws['!merges']!.push({ s: { r: 0, c: mc }, e: { r: 0, c: mc + 2 } });
		ws['!cols'] = Array(header1.length).fill({ wch: 18 });

		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, isAr ? 'تلخيص شهري' : 'Monthly Summary');
		XLSX.writeFile(wb, `Monthly_${MONTH_NAMES[monthlyMonthFrom]}_${monthlyYearFrom}_to_${MONTH_NAMES[monthlyMonthTo]}_${monthlyYearTo}_${isAr ? 'AR' : 'EN'}.xlsx`);
	}
	// ─────────────────────────────────────────────────────────────────────────────
</script>

<div class="report-wrapper">
	<div class="mode-toggle">
		<button
			class="mode-btn"
			class:active={reportMode === 'quick'}
			on:click={() => (reportMode = 'quick')}
		>Quick Report</button>
		<button
			class="mode-btn"
			class:active={reportMode === 'detailed'}
			on:click={() => { reportMode = 'detailed'; if (detailRows.length === 0) loadDetailedReport(); }}
		>Detailed Report</button>
		<button
			class="mode-btn"
			class:active={reportMode === 'monthly'}
			on:click={() => { reportMode = 'monthly'; if (monthlyMonths.length === 0) loadMonthlySummary(); }}
		>Month Summary</button>
	</div>

{#if reportMode === 'quick'}
<div class="sales-report-container">
	<div class="sales-card">
		<div class="header">
			<h3>{$t('reports.dailySalesOverview')}</h3>
			<button class="refresh-btn" on:click={loadSalesData} disabled={true} title="Real-time updates active">
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
							<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
							{formatCurrency(previousMonthAvg.average)}
						</div>
						<div class="month-days">{$t('reports.averagePerDay')} ({previousMonthAvg.totalDays} {$t('reports.days')})</div>
					</div>
				{/if}
				{#if currentMonthAvg}
					<div class="month-avg current">
						<div class="month-label">{$t('reports.currentMonth')}</div>
						<div class="month-value">
							<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
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
							<div class="bar" style="height: {getBarHeight(day.total_amount)}px; background-color: {getBarColor(day.total_amount)};"></div>
						</div>
					<div class="sale-info">
						<div class="date-label">{formatDate(day.date)}</div>
						<div class="amount-label">
							<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
							{formatCurrency(day.total_amount)}
						</div>
					<div class="bills-label">{day.total_bills} {$t('reports.bills')}</div>
					<div class="basket-label">
						{$t('reports.basket')}: <img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon-small" />
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
			<button class="refresh-btn" on:click={loadBranchSalesData} disabled={true} title="Real-time updates active">
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
										<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon-micro" />
										{formatCurrency(branch.previousMonthAvg)}
									</div>
								</div>
							{/if}
							{#if branch.currentMonthAvg !== undefined}
								<div class="mini-badge current-badge">
									<div class="badge-label">{$t('reports.current')}</div>
									<div class="badge-value">
										<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon-micro" />
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
								<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
							<div class="bills-label">{branch.total_bills} {$t('reports.bills')}</div>
							<div class="basket-label">
								{$t('reports.basket')}: <img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon-small" />
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
			<button class="refresh-btn" on:click={loadYesterdayBranchSalesData} disabled={true} title="Real-time updates active">
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
								<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
							<div class="bills-label">{branch.total_bills} {$t('reports.bills')}</div>
							<div class="basket-label">
								{$t('reports.basket')}: <img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon-small" />
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

	<!-- Today's Sales Collection Card -->
	<div class="sales-card">
		<div class="header">
			<h3>{$t('reports.todayCollectionSales') || 'Today Sales (Collection)'}</h3>
			<button class="refresh-btn" on:click={loadTodayCollectionData} title="Refresh">
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
								<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Yesterday's Sales Collection Card -->
	<div class="sales-card">
		<div class="header">
			<h3>{$t('reports.yesterdayCollectionSales') || 'Yesterday Sales (Collection)'}</h3>
			<button class="refresh-btn" on:click={loadYesterdayCollectionData} title="Refresh">
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
								<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
								{formatCurrency(branch.total_amount)}
							</div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>
{/if}

{#if reportMode === 'detailed'}
<!-- ══ DETAILED REPORT ══════════════════════════════════════════════════════ -->
<div class="detail-section">
	<!-- Filters -->
	<div class="filter-bar">
		<div class="filter-group">
			<label class="filter-label" for="detail-year">Year</label>
			<select id="detail-year" class="filter-select" bind:value={detailYear}>
				{#each YEARS as y}
					<option value={y}>{y}</option>
				{/each}
			</select>
		</div>
		<div class="filter-group">
			<label class="filter-label" for="detail-month-from">From Month</label>
			<select id="detail-month-from" class="filter-select" bind:value={detailMonthFrom}>
				{#each MONTH_NAMES as m, i}
					<option value={i}>{m}</option>
				{/each}
			</select>
		</div>
		<div class="filter-group">
			<label class="filter-label" for="detail-month-to">To Month</label>
			<select id="detail-month-to" class="filter-select" bind:value={detailMonthTo}>
				{#each MONTH_NAMES as m, i}
					<option value={i} disabled={i < detailMonthFrom}>{m}</option>
				{/each}
			</select>
		</div>
		<button class="run-btn" on:click={loadDetailedReport} disabled={loadingDetail}>
			{loadingDetail ? 'Loading…' : 'Load Report'}
		</button>
		<div class="export-bar">
			<button class="export-btn export-en" on:click={() => exportDetailExcel('en')} disabled={detailRows.length === 0}>
				↓ Export Excel (EN)
			</button>
			<button class="export-btn export-ar" on:click={() => exportDetailExcel('ar')} disabled={detailRows.length === 0}>
				↓ تصدير Excel
			</button>
		</div>
	</div>

	<!-- Summary badges -->
	{#if detailRows.length > 0}
		<div class="detail-summary">
			<div class="summary-badge green">
				<span class="s-label">Total Sales</span>
				<span class="s-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
					{formatCurrency(detailTotalSales)}
				</span>
			</div>
			<div class="summary-badge blue">
				<span class="s-label">Total Bills</span>
				<span class="s-value">{detailTotalBills.toLocaleString()}</span>
			</div>
			<div class="summary-badge purple">
				<span class="s-label">Avg Basket</span>
				<span class="s-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
					{formatCurrency(detailAvgBasket)}
				</span>
			</div>
			<div class="summary-badge red">
				<span class="s-label">Total Returns</span>
				<span class="s-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
					{formatCurrency(detailTotalReturn)}
				</span>
			</div>
			<div class="summary-badge orange">
				<span class="s-label">Avg / Day ({detailDates.length} days)</span>
				<span class="s-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
					{formatCurrency(detailAvgPerDay)}
				</span>
			</div>
		</div>
	{/if}

	{#if loadingDetail}
		<div class="loading">Loading detailed report…</div>
	{:else if detailRows.length === 0}
		<div class="detail-empty">
			<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" fill="none" stroke="#d1d5db" stroke-width="1.5" viewBox="0 0 24 24">
				<rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/>
			</svg>
			<p>Select a period above and click <strong>Load Report</strong>.</p>
		</div>
	{:else}
		<div class="table-wrapper">
			<table class="detail-table">
				<thead>
					<!-- Row 1: Date + branch name headers (each spans 4 sub-cols) + Total -->
					<tr>
						<th rowspan="2" class="date-h">Date</th>
						{#each detailBranches as branch}
							<th colspan="4" class="branch-group-h">{branch.name}</th>
						{/each}
						<th colspan="3" class="total-group-h">Total</th>
					</tr>
					<!-- Row 2: Sub-column headers per branch -->
					<tr>
						{#each detailBranches as _}
							<th class="num-h sub-h">Sales (SAR)</th>
							<th class="num-h sub-h">Bills</th>
							<th class="num-h sub-h">Avg Basket</th>
							<th class="center-h sub-h">Trend</th>
						{/each}
						<th class="num-h sub-h">Sales (SAR)</th>
						<th class="num-h sub-h">Bills</th>
						<th class="center-h sub-h">Trend</th>
					</tr>
				</thead>
				<tbody>
					{#each detailDates as date, idx}
						{@const prevDate = detailDates[idx - 1] ?? null}
						{@const rowSales = detailBranches.reduce((s, b) => s + (detailPivotMap.get(`${date}|${b.id}`)?.net_amount ?? 0), 0)}
						{@const rowBills = detailBranches.reduce((s, b) => s + (detailPivotMap.get(`${date}|${b.id}`)?.net_bills  ?? 0), 0)}
						{@const prevRowSales = prevDate ? detailBranches.reduce((s, b) => s + (detailPivotMap.get(`${prevDate}|${b.id}`)?.net_amount ?? 0), 0) : null}
						{@const rowTrend = prevRowSales == null ? 'neutral' : rowSales > prevRowSales ? 'up' : rowSales < prevRowSales ? 'down' : 'neutral'}
						<tr class:alt-row={idx % 2 === 1}>
							<td class="date-cell">{date}</td>
							{#each detailBranches as branch}
								{@const cell     = detailPivotMap.get(`${date}|${branch.id}`)}
								{@const prevCell = prevDate ? detailPivotMap.get(`${prevDate}|${branch.id}`) : null}
								{@const bDiff    = (cell?.net_amount ?? null) != null && (prevCell?.net_amount ?? null) != null ? (cell?.net_amount ?? 0) - (prevCell?.net_amount ?? 0) : null}
								{@const bTrend   = bDiff == null ? 'neutral' : bDiff > 0 ? 'up' : bDiff < 0 ? 'down' : 'neutral'}
								<td class="num-cell">{cell ? formatCurrency(cell.net_amount) : '—'}</td>
								<td class="num-cell">{cell ? cell.net_bills.toLocaleString() : '—'}</td>
								<td class="num-cell avg-cell">{cell ? formatCurrency(cell.avg_basket) : '—'}</td>
								<td class="trend-cell">
									{#if bTrend === 'up'}<span class="t-up">↑</span>{:else if bTrend === 'down'}<span class="t-down">↓</span>{:else}<span class="t-neu">—</span>{/if}
								</td>
							{/each}
							<td class="num-cell total-cell">{formatCurrency(rowSales)}</td>
							<td class="num-cell total-cell">{rowBills.toLocaleString()}</td>
							<td class="trend-cell total-cell">
								{#if rowTrend === 'up'}<span class="t-up">↑</span>{:else if rowTrend === 'down'}<span class="t-down">↓</span>{:else}<span class="t-neu">—</span>{/if}
							</td>
						</tr>
					{/each}
				</tbody>
				<tfoot>
					<tr class="totals-row sticky-tfoot-top">
						<td class="date-cell"><strong>Total</strong></td>
						{#each detailBranches as branch}
							{@const colSales = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${branch.id}`)?.net_amount ?? 0), 0)}
							{@const colBills = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${branch.id}`)?.net_bills  ?? 0), 0)}
							<td class="num-cell"><strong>{formatCurrency(colSales)}</strong></td>
							<td class="num-cell"><strong>{colBills.toLocaleString()}</strong></td>
							<td class="num-cell avg-cell"><strong>{formatCurrency(colBills > 0 ? colSales / colBills : 0)}</strong></td>
							<td class="trend-cell"></td>
						{/each}
						<td class="num-cell total-cell"><strong>{formatCurrency(detailTotalSales)}</strong></td>
						<td class="num-cell total-cell"><strong>{detailTotalBills.toLocaleString()}</strong></td>
						<td class="trend-cell total-cell"></td>
					</tr>
					<tr class="totals-row sticky-tfoot-bottom">
						<td class="date-cell"><strong>Avg/Day ({detailDates.length}d)</strong></td>
						{#each detailBranches as branch}
							{@const colSales = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${branch.id}`)?.net_amount ?? 0), 0)}
							{@const colBills = detailDates.reduce((s, d) => s + (detailPivotMap.get(`${d}|${branch.id}`)?.net_bills  ?? 0), 0)}
							{@const n = detailDates.length || 1}
							<td class="num-cell">{formatCurrency(colSales / n)}</td>
							<td class="num-cell">{Math.round(colBills / n).toLocaleString()}</td>
							<td class="num-cell avg-cell">{formatCurrency(colBills > 0 ? colSales / colBills : 0)}</td>
							<td class="trend-cell"></td>
						{/each}
						<td class="num-cell total-cell">{formatCurrency(detailAvgPerDay)}</td>
						<td class="num-cell total-cell">{Math.round(detailTotalBills / (detailDates.length || 1)).toLocaleString()}</td>
						<td class="trend-cell total-cell"></td>
					</tr>
				</tfoot>
			</table>
		</div>
	{/if}
</div>
{/if}

{#if reportMode === 'monthly'}
<!-- ══ MONTHLY SUMMARY ══════════════════════════════════════════════════════ -->
<div class="detail-section">
	<!-- Filters -->
	<div class="filter-bar">
		<div class="filter-group">
			<label class="filter-label" for="msum-year-from">From Year</label>
			<select id="msum-year-from" class="filter-select" bind:value={monthlyYearFrom}>
				{#each YEARS as y}<option value={y}>{y}</option>{/each}
			</select>
		</div>
		<div class="filter-group">
			<label class="filter-label" for="msum-month-from">From Month</label>
			<select id="msum-month-from" class="filter-select" bind:value={monthlyMonthFrom}>
				{#each MONTH_NAMES as m, i}<option value={i}>{m}</option>{/each}
			</select>
		</div>
		<div class="filter-group">
			<label class="filter-label" for="msum-year-to">To Year</label>
			<select id="msum-year-to" class="filter-select" bind:value={monthlyYearTo}>
				{#each YEARS as y}<option value={y}>{y}</option>{/each}
			</select>
		</div>
		<div class="filter-group">
			<label class="filter-label" for="msum-month-to">To Month</label>
			<select id="msum-month-to" class="filter-select" bind:value={monthlyMonthTo}>
				{#each MONTH_NAMES as m, i}<option value={i}>{m}</option>{/each}
			</select>
		</div>
		<button class="run-btn" on:click={loadMonthlySummary} disabled={loadingMonthly}>
			{loadingMonthly ? 'Loading…' : 'Load Report'}
		</button>
		<div class="export-bar">
			<button class="export-btn export-en" on:click={() => exportMonthlyExcel('en')} disabled={monthlyMonths.length === 0}>
				↓ Export Excel (EN)
			</button>
			<button class="export-btn export-ar" on:click={() => exportMonthlyExcel('ar')} disabled={monthlyMonths.length === 0}>
				↓ تصدير Excel
			</button>
		</div>
	</div>

	<!-- Summary badges -->
	{#if monthlyMonths.length > 0}
		<div class="detail-summary">
			<div class="summary-badge green">
				<span class="s-label">Total Sales</span>
				<span class="s-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
					{formatCurrency(monthlyTotalSales)}
				</span>
			</div>
			<div class="summary-badge blue">
				<span class="s-label">Total Bills</span>
				<span class="s-value">{monthlyTotalBills.toLocaleString()}</span>
			</div>
			<div class="summary-badge purple">
				<span class="s-label">Avg Basket</span>
				<span class="s-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
					{formatCurrency(monthlyAvgBasket)}
				</span>
			</div>
			<div class="summary-badge orange">
				<span class="s-label">Avg / Month ({monthlyMonths.length} months)</span>
				<span class="s-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="currency-icon" />
					{formatCurrency(monthlyAvgPerMonth)}
				</span>
			</div>
		</div>
	{/if}

	{#if loadingMonthly}
		<div class="loading">Loading monthly summary…</div>
	{:else if monthlyMonths.length === 0}
		<div class="detail-empty">
			<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" fill="none" stroke="#d1d5db" stroke-width="1.5" viewBox="0 0 24 24">
				<rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/>
			</svg>
			<p>Select a period above and click <strong>Load Report</strong>.</p>
		</div>
	{:else}
		<div class="table-wrapper">
			<table class="detail-table">
				<thead>
					<tr>
						<th rowspan="2" class="date-h">Month</th>
						{#each monthlyBranches as branch}
							<th colspan="4" class="branch-group-h">{branch.name}</th>
						{/each}
						<th colspan="3" class="total-group-h">Total</th>
					</tr>
					<tr>
						{#each monthlyBranches as _}
							<th class="num-h sub-h">Sales (SAR)</th>
							<th class="num-h sub-h">Bills</th>
							<th class="num-h sub-h">Avg Basket</th>
							<th class="center-h sub-h">Trend</th>
						{/each}
						<th class="num-h sub-h">Sales (SAR)</th>
						<th class="num-h sub-h">Bills</th>
						<th class="center-h sub-h">Trend</th>
					</tr>
				</thead>
				<tbody>
					{#each monthlyMonths as ym, idx}
						{@const prevYm      = monthlyMonths[idx - 1] ?? null}
						{@const rowSales    = monthlyBranches.reduce((s, b) => s + (monthlyPivotMap.get(`${ym}|${b.id}`)?.net_amount ?? 0), 0)}
						{@const rowBills    = monthlyBranches.reduce((s, b) => s + (monthlyPivotMap.get(`${ym}|${b.id}`)?.net_bills  ?? 0), 0)}
						{@const prevRowSales = prevYm ? monthlyBranches.reduce((s, b) => s + (monthlyPivotMap.get(`${prevYm}|${b.id}`)?.net_amount ?? 0), 0) : null}
						{@const rowTrend    = prevRowSales == null ? 'neutral' : rowSales > prevRowSales ? 'up' : rowSales < prevRowSales ? 'down' : 'neutral'}
						<tr class:alt-row={idx % 2 === 1}>
							<td class="date-cell">{ym}</td>
							{#each monthlyBranches as branch}
								{@const cell     = monthlyPivotMap.get(`${ym}|${branch.id}`)}
								{@const prevCell = prevYm ? monthlyPivotMap.get(`${prevYm}|${branch.id}`) : null}
								{@const bDiff    = cell && prevCell ? cell.net_amount - prevCell.net_amount : null}
								{@const bTrend   = bDiff == null ? 'neutral' : bDiff > 0 ? 'up' : bDiff < 0 ? 'down' : 'neutral'}
								<td class="num-cell">{cell ? formatCurrency(cell.net_amount) : '—'}</td>
								<td class="num-cell">{cell ? cell.net_bills.toLocaleString() : '—'}</td>
								<td class="num-cell avg-cell">{cell ? formatCurrency(cell.avg_basket) : '—'}</td>
								<td class="trend-cell">
									{#if bTrend === 'up'}<span class="t-up">↑</span>{:else if bTrend === 'down'}<span class="t-down">↓</span>{:else}<span class="t-neu">—</span>{/if}
								</td>
							{/each}
							<td class="num-cell total-cell">{formatCurrency(rowSales)}</td>
							<td class="num-cell total-cell">{rowBills.toLocaleString()}</td>
							<td class="trend-cell total-cell">
								{#if rowTrend === 'up'}<span class="t-up">↑</span>{:else if rowTrend === 'down'}<span class="t-down">↓</span>{:else}<span class="t-neu">—</span>{/if}
							</td>
						</tr>
					{/each}
				</tbody>
				<tfoot>
					<tr class="totals-row sticky-tfoot-top">
						<td class="date-cell"><strong>Total</strong></td>
						{#each monthlyBranches as branch}
							{@const cs = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${branch.id}`)?.net_amount ?? 0), 0)}
							{@const cb = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${branch.id}`)?.net_bills  ?? 0), 0)}
							<td class="num-cell"><strong>{formatCurrency(cs)}</strong></td>
							<td class="num-cell"><strong>{cb.toLocaleString()}</strong></td>
							<td class="num-cell avg-cell"><strong>{formatCurrency(cb > 0 ? cs / cb : 0)}</strong></td>
							<td class="trend-cell"></td>
						{/each}
						<td class="num-cell total-cell"><strong>{formatCurrency(monthlyTotalSales)}</strong></td>
						<td class="num-cell total-cell"><strong>{monthlyTotalBills.toLocaleString()}</strong></td>
						<td class="trend-cell total-cell"></td>
					</tr>
					<tr class="totals-row sticky-tfoot-bottom">
						<td class="date-cell"><strong>Avg/Month</strong></td>
						{#each monthlyBranches as branch}
							{@const cs = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${branch.id}`)?.net_amount ?? 0), 0)}
							{@const cb = monthlyMonths.reduce((s, m) => s + (monthlyPivotMap.get(`${m}|${branch.id}`)?.net_bills  ?? 0), 0)}
							{@const n  = monthlyMonths.length || 1}
							<td class="num-cell">{formatCurrency(cs / n)}</td>
							<td class="num-cell">{Math.round(cb / n).toLocaleString()}</td>
							<td class="num-cell avg-cell">{formatCurrency(cb > 0 ? cs / cb : 0)}</td>
							<td class="trend-cell"></td>
						{/each}
						<td class="num-cell total-cell">{formatCurrency(monthlyAvgPerMonth)}</td>
						<td class="num-cell total-cell">{Math.round(monthlyTotalBills / (monthlyMonths.length || 1)).toLocaleString()}</td>
						<td class="trend-cell total-cell"></td>
					</tr>
				</tfoot>
			</table>
		</div>
	{/if}
</div>
{/if}
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
		min-height: 300px;
		background: #f9fafb;
		border-radius: 12px;
	}

	.sale-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.75rem;
		flex: 1;
		height: 100%;
		max-width: 120px;
		overflow: visible;
	}

	.bar-container {
		flex: 1;
		height: 100%;
		width: 50px;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		min-height: 200px;
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

	/* ── REPORT MODE TOGGLE ──────────────────────────────────────────────────── */
	.report-wrapper {
		display: flex;
		flex-direction: column;
		width: 100%;
		height: 100%;
		background-color: var(--background);
		overflow: hidden;
	}

	.mode-toggle {
		display: flex;
		gap: 0.5rem;
		padding: 0.75rem 1rem 0;
		background-color: var(--background);
		flex-shrink: 0;
	}

	.mode-btn {
		padding: 0.5rem 1.25rem;
		border: 2px solid #10b981;
		border-radius: 8px;
		background: white;
		color: #10b981;
		font-weight: 600;
		font-size: 0.85rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.mode-btn:hover { background: #f0fdf4; }

	.mode-btn.active {
		background: #10b981;
		color: white;
	}

	/* Quick report scroll within wrapper */
	.report-wrapper .sales-report-container {
		flex: 1;
		overflow-y: auto;
	}

	/* ── DETAILED REPORT ─────────────────────────────────────────────────────── */
	.detail-section {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		padding: 1rem;
		overflow-y: auto;
	}

	.filter-bar {
		display: flex;
		align-items: flex-end;
		gap: 0.75rem;
		flex-wrap: wrap;
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 2px 8px rgba(0,0,0,0.08);
		border: 2px solid #10b981;
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.filter-label {
		font-size: 0.7rem;
		font-weight: 600;
		color: #555;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.filter-select {
		padding: 0.4rem 0.6rem;
		border: 1.5px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.85rem;
		color: #333;
		background: white;
		cursor: pointer;
	}

	.filter-select:focus {
		outline: none;
		border-color: #10b981;
	}

	.run-btn {
		padding: 0.45rem 1.25rem;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.85rem;
		cursor: pointer;
		transition: background 0.2s;
		align-self: flex-end;
	}

	.run-btn:hover:not(:disabled) { background: #059669; }
	.run-btn:disabled { opacity: 0.6; cursor: not-allowed; }

	.export-bar {
		display: flex;
		gap: 0.5rem;
		align-self: flex-end;
		margin-left: auto;
	}

	.export-btn {
		padding: 0.45rem 0.9rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.8rem;
		cursor: pointer;
		transition: opacity 0.2s;
	}

	.export-btn:disabled { opacity: 0.4; cursor: not-allowed; }

	.export-en { background: #2563eb; color: white; }
	.export-en:hover:not(:disabled) { background: #1d4ed8; }

	.export-ar { background: #7c3aed; color: white; }
	.export-ar:hover:not(:disabled) { background: #6d28d9; }

	.detail-summary {
		display: flex;
		gap: 0.75rem;
		flex-wrap: wrap;
	}

	.summary-badge {
		flex: 1;
		min-width: 140px;
		background: white;
		border-radius: 12px;
		padding: 0.75rem 1rem;
		box-shadow: 0 2px 8px rgba(0,0,0,0.08);
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.summary-badge.green  { border-left: 4px solid #10b981; }
	.summary-badge.blue   { border-left: 4px solid #3b82f6; }
	.summary-badge.purple { border-left: 4px solid #8b5cf6; }
	.summary-badge.red    { border-left: 4px solid #ef4444; }
	.summary-badge.orange { border-left: 4px solid #f97316; }

	.s-label {
		font-size: 0.65rem;
		font-weight: 600;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.s-value {
		font-size: 1rem;
		font-weight: 700;
		color: #111;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.detail-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 4rem 2rem;
		color: #9ca3af;
		text-align: center;
	}

	.table-wrapper {
		overflow-x: auto;
		overflow-y: auto;
		max-height: 60vh;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0,0,0,0.08);
		border: 1px solid #e5e7eb;
	}

	.detail-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.82rem;
	}

	.detail-table thead th {
		position: sticky;
		top: 0;
		z-index: 2;
		background: #f9fafb;
		padding: 0.65rem 0.75rem;
		text-align: left;
		font-weight: 700;
		color: #374151;
		border-bottom: 2px solid #10b981;
		white-space: nowrap;
	}

	.detail-table thead th.date-h {
		z-index: 3;
		background: #ecfdf5;
		border-right: 2px solid #10b981;
		vertical-align: middle;
		min-width: 100px;
	}

	/* Branch group header spans 3 sub-cols */
	.detail-table thead th.branch-group-h {
		text-align: center;
		background: #10b981;
		color: white;
		border-left: 2px solid white;
		border-right: 2px solid white;
	}

	.detail-table thead th.total-group-h {
		text-align: center;
		background: #374151;
		color: white;
		border-left: 2px solid white;
	}

	/* Sub-column headers — second row, sits below first row (~38px) */
	.detail-table thead th.sub-h {
		top: 38px;
		background: #f3f4f6;
		font-weight: 600;
		font-size: 0.72rem;
		color: #6b7280;
		border-top: 1px solid #e5e7eb;
		border-left: 1px solid #e5e7eb;
	}

	.detail-table thead th.num-h    { text-align: right; }
	.detail-table thead th.center-h { text-align: center; }

	.detail-table tbody tr {
		border-bottom: 1px solid #f3f4f6;
		transition: background 0.1s;
	}

	.detail-table tbody tr:hover        { background: #f0fdf4; }
	.detail-table tbody tr.alt-row      { background: #fafafa; }
	.detail-table tbody tr.alt-row:hover { background: #f0fdf4; }

	.detail-table td {
		padding: 0.55rem 0.75rem;
		color: #374151;
		white-space: nowrap;
	}

	.date-cell   { font-weight: 600; color: #111; border-right: 2px solid #10b981; }
	.num-cell    { text-align: right; font-variant-numeric: tabular-nums; border-left: 1px solid #f3f4f6; }
	.avg-cell    { color: #6b7280; border-right: 1px solid #e5e7eb; }
	.trend-cell  { text-align: center; font-size: 1rem; font-weight: 700; border-right: 2px solid #e5e7eb; padding: 0.4rem 0.5rem; }
	.t-up        { color: #10b981; }
	.t-down      { color: #ef4444; }
	.t-neu       { color: #9ca3af; font-size: 0.85rem; }
	.total-cell  { background: #f0fdf4; font-weight: 600; border-left: 2px solid #10b981; }

	.detail-table tfoot .totals-row {
		background: #f0fdf4;
		border-top: 2px solid #10b981;
	}

	.detail-table tfoot td {
		padding: 0.65rem 0.75rem;
		color: #111;
	}

	.detail-table tfoot tr td {
		position: sticky;
		z-index: 2;
		background: #f0fdf4;
	}

	/* Two-row sticky tfoot: top row sits above bottom row */
	.detail-table tfoot tr.sticky-tfoot-bottom td { bottom: 0; }
	.detail-table tfoot tr.sticky-tfoot-top td    { bottom: 43px; }
</style>
