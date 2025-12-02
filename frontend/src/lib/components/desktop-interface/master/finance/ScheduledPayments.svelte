<script>
	import { onMount } from 'svelte';
	import { supabase, supabaseAdmin } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import MonthDetails from '$lib/components/desktop-interface/master/finance/MonthDetails.svelte';

	// Props for window refresh functionality
	export let onRefresh = null; // Window refresh callback
	export let setRefreshCallback = null; // Function to register our refresh function

	// Helper function to format date as dd/mm/yyyy
	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		try {
			const date = new Date(dateString);
			// Check if date is valid
			if (isNaN(date.getTime())) return 'N/A';
			const day = String(date.getDate()).padStart(2, '0');
			const month = String(date.getMonth() + 1).padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return 'N/A';
		}
	}

	// Current date and navigation
	let currentDate = new Date();
	let currentWeek = new Date();
	
	// Payment data
	let scheduledPayments = [];
	let expenseSchedulerPayments = [];
	let weekDays = [];
	let totalScheduledAmount = 0;
	let totalExpensesScheduled = 0;
	let refreshing = false;
	let scheduledPaymentsElement;
	
	// Selected day details
	let selectedDay = null;
	let showDetails = false;
	
	// Filters
	let filterBranch = '';
	let filterPaymentMethod = '';
	let filterVendor = '';
	let searchVendor = '';
	let branches = [];
	let branchMap = {}; // Map of branch_id to branch name
	let paymentMethods = [];
	let vendors = [];
	let totalVendorsInDB = 0; // Total count from vendors table
	
	// Vendor search state
	let showVendorSearch = false;
	let vendorSearchResults = [];
	let selectedVendor = null;

	// Use the total vendor count from database
	$: totalVendorCount = totalVendorsInDB;
	
	// Get branch name by ID from branchMap
	function getBranchName(branchId) {
		if (!branchId) return 'N/A';
		return branchMap[branchId] || 'N/A';
	}
	
	// Monthly totals
	let monthlyData = [];
	let currentMonthIndex = 0; // Starting from current month
	let visibleMonthsCount = 6; // Show 6 months at a time

	// Refresh function to reload all data
	async function refreshData() {
		if (refreshing) return; // Prevent multiple simultaneous refreshes
		
		try {
			refreshing = true;
			console.log('🔄 [ScheduledPayments] Starting complete data refresh...');
			console.log('🔍 [ScheduledPayments] Current scheduledPayments:', scheduledPayments.length);
			console.log('🔍 [ScheduledPayments] Current expenseSchedulerPayments:', expenseSchedulerPayments.length);
			
			// Clear existing data first
			scheduledPayments = [];
			expenseSchedulerPayments = [];
			weekDays = [];
			
			console.log('✅ [ScheduledPayments] Data cleared, reloading...');
			
			// Reload all data sources
			generateWeekDays();
			calculateMonthlyTotals();
			
			console.log('✅ [ScheduledPayments] Week days and calculations regenerated');
			
			await Promise.all([
				loadBranches(),
				loadPaymentMethods(),
				loadVendors(),
				loadScheduledPayments(),
				loadExpenseSchedulerPayments()
			]);
			
			console.log('✅ [ScheduledPayments] All data reloaded successfully');
			console.log('🔍 [ScheduledPayments] New scheduledPayments:', scheduledPayments.length);
			console.log('🔍 [ScheduledPayments] New expenseSchedulerPayments:', expenseSchedulerPayments.length);
			
		} catch (error) {
			console.error('❌ [ScheduledPayments] Error during complete refresh:', error);
			alert('Error refreshing data. Please try again.');
		} finally {
			refreshing = false;
			console.log('🏁 [ScheduledPayments] Refresh completed, refreshing state reset');
		}
	}

	// Initialize component
	async function loadInitialData() {
		generateWeekDays();
		calculateMonthlyTotals();
		await loadBranches();
		await loadPaymentMethods();
		await loadVendors();
		await loadScheduledPayments();
		await loadExpenseSchedulerPayments();
	}

	onMount(async () => {
		console.log('🚀 [ScheduledPayments] Component mounted');
		console.log('🔍 [ScheduledPayments] setRefreshCallback:', setRefreshCallback);
		console.log('🔍 [ScheduledPayments] onRefresh:', onRefresh);
		
		await loadInitialData();
		
		// Register our refresh function with the window
		if (setRefreshCallback) {
			console.log('✅ [ScheduledPayments] Registering refreshData function with window');
			setRefreshCallback(refreshData);
		} else {
			console.log('❌ [ScheduledPayments] No setRefreshCallback provided');
		}
	});

	// Expose refreshData function to parent/window
	$: if (scheduledPaymentsElement) {
		scheduledPaymentsElement.refreshData = refreshData;
	}

	// Generate week view (7 days starting from current week)
	function generateWeekDays() {
		const startOfWeek = new Date(currentWeek);
		startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay()); // Start from Sunday
		
		weekDays = [];
		for (let i = 0; i < 7; i++) {
			const day = new Date(startOfWeek);
			day.setDate(startOfWeek.getDate() + i);
			
			weekDays.push({
				dayName: day.toLocaleDateString('en-US', { weekday: 'long' }),
				dayShort: day.toLocaleDateString('en-US', { weekday: 'short' }),
				date: day.getDate(),
				month: day.toLocaleDateString('en-US', { month: 'short' }),
				fullDate: new Date(day),
				payments: [],
				totalAmount: 0
			});
		}
	}

	// Load scheduled payments from database
	async function loadScheduledPayments() {
		try {
			console.log('Loading scheduled payments...');
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('*')
				.eq('is_paid', false)
				.order('due_date', { ascending: true });

			if (error) {
				console.error('Error loading scheduled payments:', error);
				return;
			}

			console.log('Loaded scheduled payments:', data);
			scheduledPayments = data || [];
			
			// Group payments by day after loading data
			groupPaymentsByDay();
			
			// Calculate monthly totals after loading data
			calculateMonthlyTotals();
			
			// Force reactivity update
			weekDays = weekDays;
		} catch (err) {
			console.error('Error loading scheduled payments:', err);
		}
	}

	// Load expense scheduler payments from database
	async function loadExpenseSchedulerPayments() {
		try {
			console.log('Loading expense scheduler payments...');
			const { data, error } = await supabaseAdmin
				.from('expense_scheduler')
				.select(`
					*,
					creator:users!created_by(username)
				`)
				.order('due_date', { ascending: true });

			if (error) {
				console.error('Error loading expense scheduler payments:', error);
				return;
			}

			console.log('Loaded expense scheduler payments:', data);
			expenseSchedulerPayments = data || [];
			
			// Group payments by day after loading data
			groupPaymentsByDay();
			
			// Calculate monthly totals after loading data
			calculateMonthlyTotals();
			
			// Force reactivity update
			weekDays = weekDays;
		} catch (err) {
			console.error('Error loading expense scheduler payments:', err);
		}
	}

	// Load branches for filter
	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, is_active')
				.eq('is_active', true)
				.order('name_en');

			if (error) {
				console.error('Error loading branches:', error);
				return;
			}

			branches = data || [];
			
			// Build branch ID to name mapping
			branchMap = {};
			branches.forEach(branch => {
				branchMap[branch.id] = branch.name_en;
			});
			
			console.log('Loaded branches:', branches.map(b => b.name_en));
			console.log('Branch map:', branchMap);
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	// Load payment methods for filter
	async function loadPaymentMethods() {
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('payment_method')
				.not('payment_method', 'is', null);

			if (error) {
				console.error('Error loading payment methods:', error);
				return;
			}

			// Get unique payment methods
			const uniqueMethods = [...new Set(data.map(item => item.payment_method))];
			paymentMethods = uniqueMethods.filter(method => method).sort();
			console.log('Loaded payment methods:', paymentMethods);
		} catch (err) {
			console.error('Error loading payment methods:', err);
		}
	}

	// Load vendors for filter
	async function loadVendors() {
		try {
			// Get total count of vendors
			const { count, error } = await supabase
				.from('vendors')
				.select('*', { count: 'exact', head: true });

			if (error) {
				console.error('Error loading vendor count:', error);
			} else {
				totalVendorsInDB = count || 0;
				console.log('Total vendors in database:', totalVendorsInDB);
			}

			// Get unique vendor names for search functionality
			const { data, error: dataError } = await supabase
				.from('vendors')
				.select('vendor_name')
				.not('vendor_name', 'is', null);

			if (dataError) {
				console.error('Error loading vendor names:', dataError);
				return;
			}

			// Get unique vendor names
			const uniqueVendors = [...new Set(data.map(item => item.vendor_name))];
			vendors = uniqueVendors.filter(vendor => vendor).sort();
			
			console.log('Loaded unique vendor names:', vendors.length);
		} catch (err) {
			console.error('Error loading vendors:', err);
		}
	}

	// Clear all filters
	function clearFilters() {
		filterBranch = '';
		filterPaymentMethod = '';
		filterVendor = '';
		searchVendor = '';
		selectedVendor = null;
		showVendorSearch = false;
		vendorSearchResults = [];
	}

	// Handle vendor search input
	function handleVendorSearch() {
		if (searchVendor.length >= 2) {
			// Get scheduled payments based on selected branch
			let availablePayments;
			if (filterBranch) {
				availablePayments = scheduledPayments.filter(payment => payment.branch_id == filterBranch);
			} else {
				availablePayments = scheduledPayments;
			}
			
			// Get unique vendors with their IDs
			const vendorMap = new Map();
			availablePayments.forEach(payment => {
				if (payment.vendor_name) {
					const key = payment.vendor_name;
					if (!vendorMap.has(key)) {
						vendorMap.set(key, {
							name: payment.vendor_name,
							id: payment.vendor_id
						});
					}
				}
			});
			
			const uniqueVendors = Array.from(vendorMap.values());
			
			// Filter vendors based on search input (search both name and ID)
			const searchLower = searchVendor.toLowerCase();
			vendorSearchResults = uniqueVendors.filter(vendor => 
				vendor.name.toLowerCase().includes(searchLower) ||
				(vendor.id && vendor.id.toString().toLowerCase().includes(searchLower))
			).slice(0, 10); // Limit to 10 results
			
			showVendorSearch = vendorSearchResults.length > 0;
		} else {
			showVendorSearch = false;
			vendorSearchResults = [];
		}
		
		// Clear selected vendor when search changes
		selectedVendor = null;
		filterVendor = '';
	}

	// Select vendor from search results
	function selectVendor(vendorObj) {
		selectedVendor = vendorObj.name;
		filterVendor = vendorObj.name;
		searchVendor = vendorObj.name;
		showVendorSearch = false;
		vendorSearchResults = [];
	}

	// Check if payment is due soon (within 3 days)
	function isPaymentDueSoon(payment) {
		const dueDate = new Date(payment.due_date);
		const today = new Date();
		const diffTime = dueDate.getTime() - today.getTime();
		const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
		return diffDays <= 3 && diffDays >= 0;
	}

	// Filter payments based on selected filters
	$: filteredPayments = scheduledPayments.filter(payment => {
		const branchMatch = !filterBranch || payment.branch_id == filterBranch;
		const paymentMethodMatch = !filterPaymentMethod || payment.payment_method === filterPaymentMethod;
		const vendorMatch = !filterVendor || payment.vendor_name === filterVendor;
		const notPaid = !payment.is_paid; // Only show unpaid payments
		return branchMatch && paymentMethodMatch && vendorMatch && notPaid;
	});

	// Calculate total from filtered payments
	$: totalScheduledAmount = filteredPayments.reduce((sum, payment) => sum + (payment.final_bill_amount || payment.bill_amount || 0), 0);
	$: totalExpensesScheduled = expenseSchedulerPayments.reduce((sum, expense) => sum + (expense.amount || 0), 0);

	// Re-group payments when filters change
	$: if (filteredPayments && weekDays.length > 0) {
		groupPaymentsByDay();
		calculateMonthlyTotals();
	}

	// Filter selected day payments
	$: filteredSelectedDayPayments = selectedDay?.payments.filter(payment => {
		const branchMatch = !filterBranch || payment.branch_id == filterBranch;
		const paymentMethodMatch = !filterPaymentMethod || payment.payment_method === filterPaymentMethod;
		const vendorMatch = !filterVendor || payment.vendor_name === filterVendor;
		const notPaid = !payment.is_paid; // Only show unpaid payments
		return branchMatch && paymentMethodMatch && vendorMatch && notPaid;
	}) || [];

	// Calculate filtered total
	$: filteredSelectedDayTotal = filteredSelectedDayPayments.reduce(
		(sum, payment) => sum + (payment.final_bill_amount || 0), 
		0
	);

	// Group payments by day
	function groupPaymentsByDay() {
		console.log('Grouping payments by day...', filteredPayments.length, 'vendor payments', expenseSchedulerPayments.length, 'expense payments');
		weekDays.forEach(day => {
			// Filter vendor payments for this day
			day.payments = filteredPayments.filter(payment => {
				const paymentDate = new Date(payment.due_date);
				const matches = paymentDate.toDateString() === day.fullDate.toDateString();
				if (matches) {
					console.log(`Vendor payment matched for ${day.fullDate.toDateString()}:`, payment);
				}
				return matches;
			});
			
			// Filter expense scheduler payments for this day
			day.expensePayments = expenseSchedulerPayments.filter(expense => {
				if (!expense.due_date) return false;
				const expenseDate = new Date(expense.due_date);
				const matches = expenseDate.toDateString() === day.fullDate.toDateString();
				if (matches) {
					console.log(`Expense payment matched for ${day.fullDate.toDateString()}:`, expense);
				}
				return matches;
			});
			
			// Calculate totals
			day.totalAmount = day.payments.reduce((sum, payment) => sum + (payment.final_bill_amount || payment.bill_amount || 0), 0);
			day.expenseTotalAmount = day.expensePayments.reduce((sum, expense) => sum + (expense.amount || 0), 0);
			day.combinedTotalAmount = day.totalAmount + day.expenseTotalAmount;
			
			console.log(`Day ${day.dayName} ${day.date}: ${day.payments.length} vendor payments (${day.totalAmount}), ${day.expensePayments.length} expense payments (${day.expenseTotalAmount}), combined total: ${day.combinedTotalAmount}`);
		});
	}

	// Navigate weeks
	function previousWeek() {
		currentWeek.setDate(currentWeek.getDate() - 7);
		currentWeek = new Date(currentWeek);
		generateWeekDays();
		if (scheduledPayments.length > 0) {
			groupPaymentsByDay();
		}
		calculateMonthlyTotals();
	}

	function nextWeek() {
		currentWeek.setDate(currentWeek.getDate() + 7);
		currentWeek = new Date(currentWeek);
		generateWeekDays();
		if (scheduledPayments.length > 0) {
			groupPaymentsByDay();
		}
		calculateMonthlyTotals();
	}

	// Format currency
	function formatCurrency(amount) {
		if (!amount || amount === 0) return '0.00';
		
		// Convert to number and format with exact precision (no rounding)
		const numericAmount = typeof amount === 'string' ? parseFloat(amount) : Number(amount);
		
		// Format with exactly 2 decimal places without rounding for display
		const formattedAmount = numericAmount.toFixed(2);
		
		// Add thousand separators while preserving exact decimals
		const [integer, decimal] = formattedAmount.split('.');
		const integerWithCommas = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
		
		return `${integerWithCommas}.${decimal}`;
	}

	// Check if day is today
	function isToday(date) {
		const today = new Date();
		return date.toDateString() === today.toDateString();
	}

	// Check if day has payments
	function hasPayments(day) {
		return day.payments && day.payments.length > 0;
	}

	// Get payment methods breakdown for a day
	function getPaymentMethodsForDay(day) {
		// Initialize all payment categories with 0
		const methodTotals = {
			'Cash on Delivery': 0,
			'Bank on Delivery': 0,
			'Cash Credit': 0,
			'Bank Credit': 0
		};
		
		// Add actual payment amounts
		day.payments.forEach(payment => {
			const method = payment.payment_method || 'Cash on Delivery';
			if (methodTotals.hasOwnProperty(method)) {
				methodTotals[method] += (payment.final_bill_amount || payment.bill_amount || 0);
			} else {
				// If method not in our categories, add to default
				methodTotals['Cash on Delivery'] += (payment.final_bill_amount || payment.bill_amount || 0);
			}
		});

		// Return all categories, even those with 0 amounts
		return Object.entries(methodTotals).map(([name, amount]) => ({
			name,
			amount
		}));
	}

	// Handle day click to show details
	function handleDayClick(day) {
		if (hasPayments(day)) {
			selectedDay = day;
			showDetails = true;
		}
	}

	// Close details view
	function closeDetails() {
		selectedDay = null;
		showDetails = false;
	}

	// Generate unique window ID
	function generateWindowId(type) {
		return `${type}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
	}

	// Handle month click to open month details window
	function handleMonthClick(monthData) {
		const windowId = generateWindowId('month-details');
		const instanceNumber = Math.floor(Math.random() * 1000) + 1;
		
		let monthDetailsRefreshFunction = null;

		openWindow({
			id: windowId,
			title: `${monthData.monthName} ${monthData.year} - Payment Details #${instanceNumber}`,
			component: MonthDetails,
			props: { 
				monthData,
				setRefreshCallback: (fn) => {
					console.log('📝 [ScheduledPayments] Refresh function registered from MonthDetails');
					monthDetailsRefreshFunction = fn;
				},
				onRefresh: async () => {
					console.log('🔄 [ScheduledPayments] onRefresh called from window');
					console.log('🔍 [ScheduledPayments] monthDetailsRefreshFunction:', monthDetailsRefreshFunction);
					if (monthDetailsRefreshFunction) {
						console.log('✅ [ScheduledPayments] Calling MonthDetails refresh function');
						return await monthDetailsRefreshFunction();
					} else {
						console.log('❌ [ScheduledPayments] No refresh function available');
					}
				}
			},
			icon: '📊',
			size: { width: 1400, height: 900 },
			position: { 
				x: 50 + (Math.random() * 100), 
				y: 50 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});

		// Close day details if open
		showDetails = false;
		selectedDay = null;
	}



	// Generate months data (unlimited)
	function generateMonthsData(startIndex, count) {
		const now = new Date();
		const currentMonth = now.getMonth();
		const currentYear = now.getFullYear();
		
		const months = [];
		
		for (let i = startIndex; i < startIndex + count; i++) {
			const monthDate = new Date(currentYear, currentMonth + i, 1);
			const month = monthDate.getMonth();
			const year = monthDate.getFullYear();
			
			const monthInfo = {
				index: i,
				month: month,
				year: year,
				monthName: monthDate.toLocaleDateString('en-US', { month: 'long' }),
				fullName: monthDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
				shortName: monthDate.toLocaleDateString('en-US', { month: 'short', year: 'numeric' }),
				total: 0,
				paymentCount: 0,
				isCurrent: i === 0,
				isNext: i === 1
			};
			
			months.push(monthInfo);
		}
		
		return months;
	}

	// Calculate monthly totals for visible months
	function calculateMonthlyTotals() {
		// Generate visible months
		monthlyData = generateMonthsData(currentMonthIndex, visibleMonthsCount);
		
		// Calculate totals from ALL vendor scheduled payments (ignore filters for monthly totals)
		scheduledPayments.forEach(payment => {
			const paymentDate = new Date(payment.due_date);
			const paymentMonth = paymentDate.getMonth();
			const paymentYear = paymentDate.getFullYear();
			
			// Find matching month in visible data
			const monthData = monthlyData.find(m => m.month === paymentMonth && m.year === paymentYear);
			if (monthData) {
				monthData.total += (payment.final_bill_amount || payment.bill_amount || 0);
				monthData.paymentCount++;
			}
		});
		
		// Calculate totals from ALL expense scheduler payments
		expenseSchedulerPayments.forEach(expense => {
			if (!expense.due_date) return;
			const expenseDate = new Date(expense.due_date);
			const expenseMonth = expenseDate.getMonth();
			const expenseYear = expenseDate.getFullYear();
			
			// Find matching month in visible data
			const monthData = monthlyData.find(m => m.month === expenseMonth && m.year === expenseYear);
			if (monthData) {
				monthData.expenseTotal = (monthData.expenseTotal || 0) + (expense.amount || 0);
				monthData.expenseCount = (monthData.expenseCount || 0) + 1;
			}
		});
	}

	// Navigate months
	function previousMonths() {
		if (currentMonthIndex > -12) { // Don't go back more than 1 year
			currentMonthIndex -= visibleMonthsCount;
			calculateMonthlyTotals();
		}
	}

	function nextMonths() {
		currentMonthIndex += visibleMonthsCount;
		calculateMonthlyTotals();
	}
</script>

<!-- Scheduled Payments Window Content -->
<div class="scheduled-payments" data-refresh-target bind:this={scheduledPaymentsElement}>
	<div class="header">
		<div class="header-top">
			<div class="title-section">
				<h1>💰 Scheduled Payments 
					<button 
						class="inline-refresh-btn"
						disabled={refreshing}
						on:click={() => {
							console.log('🖱️ [ScheduledPayments] Refresh button clicked!');
							refreshData();
						}}
						title={refreshing ? "Refreshing..." : "Refresh data"}
					>
						{refreshing ? "⏳" : "🔄"}
					</button>
				</h1>
				<p>Total Vendor Scheduled: <strong>{formatCurrency(totalScheduledAmount)}</strong> | Total Expenses Scheduled: <strong style="color: #dc2626;">{formatCurrency(totalExpensesScheduled)}</strong></p>
			</div>
			
			<div class="week-navigation">
				<button class="nav-btn" on:click={previousWeek}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
						<path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/>
					</svg>
				</button>
				
				<span class="week-info">
					{currentWeek.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
				</span>
				
				<button class="nav-btn" on:click={nextWeek}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
						<path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/>
					</svg>
				</button>
			</div>
		</div>
		
		<!-- Main Search and Filter Controls -->
		<div class="main-filter-controls">
			<select class="filter-select" bind:value={filterBranch}>
				<option value="">All Branches</option>
				{#each branches as branch}
					<option value={branch.id}>{branch.name_en}</option>
				{/each}
			</select>
			
			<select class="filter-select" bind:value={filterPaymentMethod}>
				<option value="">All Payment Methods</option>
				{#each paymentMethods as method}
					<option value={method}>{method}</option>
				{/each}
			</select>
			
			<input 
				type="text" 
				placeholder="🔍 Search vendors by name or ID..." 
				bind:value={searchVendor}
				on:input={handleVendorSearch}
				class="search-input"
			/>

			<button class="clear-filters-btn" on:click={clearFilters}>
				Clear Filters
			</button>
		</div>

		{#if filterBranch || filterPaymentMethod || selectedVendor}
		<div class="main-filter-summary">
			<span class="filter-summary-text">
				📊 Showing {filteredPayments.length} of {scheduledPayments.length} payments
				{#if selectedVendor}, for vendor: "{selectedVendor}"{/if}
			</span>
		</div>
		{/if}
	</div>

	<!-- Vendor Search Results -->
	{#if showVendorSearch && vendorSearchResults.length > 0}
	<div class="vendor-search-results">
		<div class="vendor-search-header">
			<h4>🔍 Select Vendor</h4>
			<span class="vendor-count">{vendorSearchResults.length} vendors found</span>
		</div>
		<div class="vendor-list">
			{#each vendorSearchResults as vendor}
			<div class="vendor-item" on:click={() => selectVendor(vendor)}>
				<div class="vendor-info">
					<span class="vendor-name">{vendor.name}</span>
					{#if vendor.id}
						<span class="vendor-id-badge">ID: {vendor.id}</span>
					{/if}
				</div>
				<span class="select-hint">Click to select</span>
			</div>
			{/each}
		</div>
	</div>
	{/if}

	<!-- Search Results Table -->
	{#if selectedVendor && filteredPayments.length > 0}
	<div class="search-results-section">
		<div class="search-results-header">
			<h3>📋 Payments for {selectedVendor}</h3>
			<div class="results-summary">
				<span class="results-count">{filteredPayments.length} payments found</span>
				<span class="results-total">Total: {formatCurrency(totalScheduledAmount)}</span>
			</div>
		</div>
		
		<div class="search-results-table">
			<table>
				<thead>
					<tr>
						<th>Vendor Name</th>
						<th>Bill Number</th>
						<th>Due Date</th>
						<th>Amount</th>
						<th>Payment Method</th>
						<th>Branch</th>
						<th>Status</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredPayments as payment}
					<tr class="payment-row">
						<td class="vendor-name">{payment.vendor_name || 'N/A'}</td>
						<td class="bill-number">{payment.bill_number || 'N/A'}</td>
						<td class="due-date">{formatDate(payment.due_date)}</td>
						<td class="amount">{formatCurrency(payment.final_bill_amount || payment.bill_amount || 0)}</td>
						<td class="payment-method">{payment.payment_method || 'N/A'}</td>
						<td class="branch">{getBranchName(payment.branch_id)}</td>
						<td class="status">
							<span class="status-badge" class:overdue={new Date(payment.due_date) < new Date()} class:due-soon={isPaymentDueSoon(payment)} class:normal={!new Date(payment.due_date) < new Date() && !isPaymentDueSoon(payment)}>
								{new Date(payment.due_date) < new Date() ? 'Overdue' : isPaymentDueSoon(payment) ? 'Due Soon' : 'Scheduled'}
							</span>
						</td>
					</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</div>
	{/if}

	<div class="week-view">
		{#each weekDays as day}
			<div class="day-card" class:today={isToday(day.fullDate)} class:has-payments={hasPayments(day) || (day.expensePayments && day.expensePayments.length > 0)} class:clickable={hasPayments(day) || (day.expensePayments && day.expensePayments.length > 0)} on:click={() => handleDayClick(day)}>
				<div class="day-header">
					<div class="day-name">{day.dayShort}</div>
					<div class="day-date">{day.date} {day.month}</div>
				</div>
				
				<div class="day-content">
					{#if hasPayments(day) || (day.expensePayments && day.expensePayments.length > 0)}
						<div class="payment-summary">
							<div class="payment-count">{day.payments.length + (day.expensePayments?.length || 0)} payment{(day.payments.length + (day.expensePayments?.length || 0)) > 1 ? 's' : ''}</div>
							<div class="payment-amount">{formatCurrency(day.combinedTotalAmount || day.totalAmount)}</div>
						</div>
						
						<div class="payment-categories">
							{#each getPaymentMethodsForDay(day) as method}
								<div class="category-item">
									<span class="category-name">{method.name}</span>
									<span class="category-amount">{formatCurrency(method.amount)}</span>
								</div>
							{/each}
							{#if day.expensePayments && day.expensePayments.length > 0}
								<div class="category-item" style="border-top: 1px solid #fee2e2; padding-top: 4px; margin-top: 4px;">
									<span class="category-name" style="color: #dc2626; font-weight: 600;">Expenses</span>
									<span class="category-amount" style="color: #dc2626;">{formatCurrency(day.expenseTotalAmount)}</span>
								</div>
							{/if}
						</div>
					{:else}
						<div class="no-payments">
							<div class="no-payments-text">No payments</div>
						</div>
					{/if}
				</div>
			</div>
		{/each}
	</div>

	<!-- Monthly Totals Section -->
	<div class="monthly-totals">
		<div class="monthly-header">
			<h2>📊 Monthly Schedule Overview</h2>
			<div class="monthly-navigation">
				<button class="nav-btn" on:click={previousMonths} disabled={currentMonthIndex <= -12}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
						<path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/>
					</svg>
				</button>
				
				<span class="nav-info">
					{#if currentMonthIndex === 0}
						Current Period
					{:else if currentMonthIndex > 0}
						+{currentMonthIndex} months ahead
					{:else}
						{Math.abs(currentMonthIndex)} months ago
					{/if}
				</span>
				
				<button class="nav-btn" on:click={nextMonths}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
						<path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/>
					</svg>
				</button>
			</div>
		</div>

		<div class="months-grid">
			{#each monthlyData as monthData, index}
				<div class="month-card" class:current={monthData.isCurrent} class:next={monthData.isNext} class:has-payments={monthData.total > 0} class:clickable={monthData.total > 0} on:click={() => handleMonthClick(monthData)}>
					<div class="month-header">
						<div class="month-icon">
							{#if monthData.isCurrent}
								📅
							{:else if monthData.isNext}
								📆
							{:else if monthData.index < 0}
								📋
							{:else}
								🗓️
							{/if}
						</div>
						<div class="month-info">
							<div class="month-name">{monthData.monthName} {monthData.year}</div>
							<div class="month-label">
								{#if monthData.isCurrent}
									Current Month
								{:else if monthData.isNext}
									Next Month
								{:else if monthData.index < 0}
									{Math.abs(monthData.index)} month{Math.abs(monthData.index) !== 1 ? 's' : ''} ago
								{:else}
									+{monthData.index} month{monthData.index !== 1 ? 's' : ''}
								{/if}
							</div>
						</div>
					</div>
					
					<div class="month-amount">{formatCurrency(monthData.total)}</div>
					{#if monthData.expenseTotal}
						<div class="month-expense-amount" style="color: #dc2626; font-size: 14px; font-weight: 600; margin-top: 4px;">
							+ {formatCurrency(monthData.expenseTotal)} Expenses
						</div>
					{/if}
					
					<div class="month-details">
						<span class="payment-count">{monthData.paymentCount} vendor{monthData.paymentCount !== 1 ? 's' : ''}</span>
						{#if monthData.expenseCount}
							<span class="payment-count" style="color: #dc2626; margin-left: 8px;">{monthData.expenseCount} expense{monthData.expenseCount !== 1 ? 's' : ''}</span>
						{/if}
					</div>
					
					<div class="month-status">
						{#if monthData.total > 0}
							<span class="status-active">Active Schedule</span>
						{:else}
							<span class="status-empty">No Payments</span>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	</div>



	<!-- Payment Details Section -->
	{#if showDetails && selectedDay}
		<div class="details-section">
			<div class="details-header">
				<h3>📋 Payment Details for {selectedDay.dayName}, {selectedDay.date} {selectedDay.month}</h3>
				<button class="close-btn" on:click={closeDetails}>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
						<path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
					</svg>
				</button>
			</div>
			
			<div class="details-summary">
				<div class="summary-item">
					<span class="summary-label">Total Payments:</span>
					<span class="summary-value">{filteredSelectedDayPayments.length}</span>
				</div>
				<div class="summary-item">
					<span class="summary-label">Total Amount:</span>
					<span class="summary-value">{formatCurrency(filteredSelectedDayTotal)}</span>
				</div>
			</div>

			<div class="filter-controls">
				<select class="filter-select" bind:value={filterBranch}>
					<option value="">All Branches</option>
					{#each branches as branch}
						<option value={branch.id}>{branch.name_en}</option>
					{/each}
				</select>
				
				<select class="filter-select" bind:value={filterPaymentMethod}>
					<option value="">All Payment Methods</option>
					{#each paymentMethods as method}
						<option value={method}>{method}</option>
					{/each}
				</select>
				
				<select class="filter-select" bind:value={filterVendor}>
					<option value="">All Vendors</option>
					{#each vendors as vendor}
						<option value={vendor}>{vendor}</option>
					{/each}
				</select>
				
				<input 
					type="text" 
					placeholder="Search vendors..." 
					bind:value={searchVendor}
					class="search-input"
				/>
				
				<button class="clear-filters-btn" on:click={clearFilters}>
					Clear Filters
				</button>
			</div>

			{#if filterBranch || filterPaymentMethod || filterVendor || searchVendor}
			<div class="filter-summary">
				<span class="filter-summary-text">
					Showing {filteredPayments.length} of {scheduledPayments.length} payments
					{#if searchVendor}, filtered by vendor: "{searchVendor}"{/if}
				</span>
			</div>
			{/if}

			<div class="details-table">
				<table>
					<thead>
						<tr>
							<th>Type</th>
							<th>Vendor/C.O. Name</th>
							<th>Branch</th>
							<th>Bill/Req Number</th>
							<th>Payment Method</th>
							<th>Amount</th>
							<th>Original Bill Amount</th>
							<th>Original Final Amount</th>
							<th>Due Date</th>
							<th>Original Due Date</th>
							<th>Status</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredSelectedDayPayments as payment}
							<tr>
								<td>
									<span class="type-badge vendor-type">Vendor</span>
								</td>
								<td class="vendor-cell">
									<div class="vendor-name">{payment.vendor_name || 'Unknown Vendor'}</div>
									<div class="vendor-id">ID: {payment.vendor_id || 'N/A'}</div>
								</td>
								<td>{getBranchName(payment.branch_id)}</td>
								<td>{payment.bill_number || 'N/A'}</td>
								<td>
									<span class="payment-method-badge">{payment.payment_method || 'Cash on Delivery'}</span>
								</td>
								<td class="amount-cell">{formatCurrency(payment.final_bill_amount || 0)}</td>
								<td class="amount-cell">{formatCurrency(payment.original_bill_amount || 0)}</td>
								<td class="amount-cell">{formatCurrency(payment.original_final_amount || 0)}</td>
								<td>{formatDate(payment.due_date)}</td>
								<td>{formatDate(payment.original_due_date)}</td>
								<td>
									<span class="status-badge {payment.is_paid ? 'status-paid' : 'status-scheduled'}">
									{payment.is_paid ? 'Paid' : 'Scheduled'}
								</span>
								</td>
							</tr>
						{/each}
						{#if selectedDay?.expensePayments}
							{#each selectedDay.expensePayments as expense}
								<tr style="background: #fef2f2;">
									<td>
										<span class="type-badge expense-type">Expense</span>
									</td>
									<td class="vendor-cell">
										<div class="vendor-name">{expense.co_user_name || 'N/A'}</div>
										<div class="vendor-id">Category: {expense.expense_category_name_en || 'N/A'}</div>
									</td>
									<td>{getBranchName(expense.branch_id)}</td>
									<td>{expense.requisition_number || 'N/A'}</td>
									<td>
										<span class="payment-method-badge" style="background: #fee2e2; color: #991b1b;">Expense</span>
									</td>
									<td class="amount-cell" style="color: #dc2626;">{formatCurrency(expense.amount || 0)}</td>
									<td class="amount-cell">-</td>
									<td class="amount-cell">-</td>
									<td>{formatDate(expense.due_date)}</td>
									<td>{formatDate(expense.original_due_date)}</td>
									<td>
										<span class="status-badge {expense.is_paid ? 'status-paid' : 'status-scheduled'}">
										{expense.is_paid ? 'Paid' : 'Scheduled'}
									</span>
									</td>
								</tr>
							{/each}
						{/if}
					</tbody>
				</table>
			</div>
		</div>
	{/if}

</div>

<style>
	.scheduled-payments {
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
		overflow-y: auto;
	}

	.header {
		display: flex;
		flex-direction: column;
		gap: 20px;
		margin-bottom: 32px;
		padding: 20px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.main-filter-controls {
		display: flex;
		gap: 12px;
		align-items: center;
		flex-wrap: wrap;
		padding: 16px;
		background: #f8fafc;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
	}

	.vendor-count-display {
		display: flex;
		flex-direction: column;
		gap: 4px;
		padding: 12px 16px;
		background: #e0f2fe;
		border: 1px solid #0891b2;
		border-radius: 6px;
		font-size: 14px;
		min-width: 200px;
	}

	.vendor-count-row {
		display: flex;
		align-items: center;
		gap: 4px;
		white-space: nowrap;
	}

	.vendor-count-row.total-vendors {
		padding-top: 4px;
		border-top: 1px solid #0891b2;
		opacity: 0.8;
	}

	.vendor-count-label {
		color: #0c4a6e;
		font-weight: 500;
	}

	.vendor-count-number {
		color: #0c4a6e;
		font-weight: 700;
		font-size: 16px;
	}

	.vendor-count-context {
		color: #0369a1;
		font-size: 12px;
		font-style: italic;
	}

	.main-filter-summary {
		padding: 12px 16px;
		background: #f1f5f9;
		border-radius: 6px;
		border-left: 4px solid #3b82f6;
	}

	.main-filter-summary .filter-summary-text {
		color: #475569;
		font-size: 14px;
		font-weight: 500;
	}

	.header-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 20px;
	}

	.header-actions {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.inline-refresh-btn {
		background: rgba(255, 255, 255, 0.9);
		border: 1px solid #d1d5db;
		border-radius: 6px;
		cursor: pointer;
		font-size: 16px;
		transition: all 0.2s ease;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
		margin-left: 8px;
		vertical-align: middle;
	}

	.inline-refresh-btn:hover {
		background: rgba(59, 130, 246, 0.1);
		border-color: #3b82f6;
		color: #3b82f6;
		transform: rotate(180deg);
	}

	.inline-refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		pointer-events: none;
	}

	.small-refresh-btn {
		background: rgba(255, 255, 255, 0.9);
		border: 1px solid #d1d5db;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: 24px;
		height: 24px;
	}

	.small-refresh-btn:hover {
		background: rgba(255, 255, 255, 1);
		border-color: #3b82f6;
		color: #3b82f6;
		transform: rotate(180deg);
	}

	.small-refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		pointer-events: none;
	}

	/* Vendor Search Results Styles */
	.vendor-search-results {
		margin: 16px 0;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		border: 1px solid #e2e8f0;
		max-width: 600px;
	}

	.vendor-search-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px 20px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		border-radius: 8px 8px 0 0;
	}

	.vendor-search-header h4 {
		margin: 0;
		color: #1e293b;
		font-size: 16px;
		font-weight: 600;
	}

	.vendor-count {
		background: #3b82f6;
		color: white;
		padding: 4px 8px;
		border-radius: 8px;
		font-size: 12px;
		font-weight: 600;
	}

	.vendor-list {
		max-height: 300px;
		overflow-y: auto;
	}

	.vendor-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 20px;
		border-bottom: 1px solid #f1f5f9;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.vendor-item:hover {
		background: #f8fafc;
		transform: translateX(4px);
	}

	.vendor-item:hover .select-hint {
		background: #3b82f6;
		color: white;
		transform: scale(1.05);
	}

	.vendor-item:last-child {
		border-bottom: none;
	}

	.vendor-name {
		font-weight: 600;
		color: #1e293b;
	}

	.vendor-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.vendor-id-badge {
		font-size: 11px;
		color: #64748b;
		background: #f1f5f9;
		padding: 2px 8px;
		border-radius: 4px;
		width: fit-content;
	}

	.select-hint {
		color: #64748b;
		font-size: 12px;
		padding: 6px 16px;
		background: #f1f5f9;
		border-radius: 6px;
		font-weight: 500;
		transition: all 0.2s ease;
		border: 1px solid #e2e8f0;
	}

	/* Search Results Table Styles */
	.search-results-section {
		margin: 24px 0;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		overflow: hidden;
	}

	.search-results-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
	}

	.search-results-header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 18px;
		font-weight: 600;
	}

	.results-summary {
		display: flex;
		flex-direction: column;
		gap: 8px;
		align-items: flex-end;
	}

	.results-count {
		background: #3b82f6;
		color: white;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.results-total {
		background: #10b981;
		color: white;
		padding: 6px 12px;
		border-radius: 12px;
		font-size: 14px;
		font-weight: 700;
		border: 1px solid #059669;
	}

	.search-results-table {
		overflow-x: auto;
	}

	.search-results-table table {
		width: 100%;
		border-collapse: collapse;
	}

	.search-results-table th {
		background: #f1f5f9;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e2e8f0;
		font-size: 14px;
	}

	.search-results-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f1f5f9;
		color: #374151;
		font-size: 14px;
	}

	.payment-row:hover {
		background: #f8fafc;
	}

	.vendor-name {
		font-weight: 600;
		color: #1e293b;
	}

	.amount {
		font-weight: 600;
		color: #059669;
	}

	.status-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-badge.overdue {
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
	}

	.status-badge.due-soon {
		background: #fff7ed;
		color: #ea580c;
		border: 1px solid #fed7aa;
	}

	.status-badge.normal {
		background: #f0fdf4;
		color: #16a34a;
		border: 1px solid #bbf7d0;
	}

	.title-section h1 {
		margin: 0;
		color: #1e293b;
		font-size: 28px;
		font-weight: 700;
	}

	.title-section p {
		margin: 8px 0 0 0;
		color: #64748b;
		font-size: 16px;
	}

	.filter-controls {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.filter-select {
		padding: 10px 16px;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		background: white;
		color: #1e293b;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 180px;
	}

	.filter-select:hover {
		border-color: #3b82f6;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-input {
		padding: 10px 16px;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		background: white;
		color: #1e293b;
		font-size: 14px;
		font-weight: 500;
		transition: all 0.2s;
		min-width: 200px;
	}

	.search-input:hover {
		border-color: #3b82f6;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-input::placeholder {
		color: #64748b;
		font-weight: normal;
	}

	.clear-filters-btn {
		padding: 10px 20px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.clear-filters-btn:hover {
		background: #dc2626;
		transform: translateY(-1px);
	}

	.clear-filters-btn:active {
		transform: translateY(0);
	}

	.filter-summary {
		margin: 10px 0;
		padding: 8px 12px;
		background: #f1f5f9;
		border-radius: 6px;
		border-left: 4px solid #3b82f6;
	}

	.filter-summary-text {
		color: #475569;
		font-size: 14px;
		font-weight: 500;
	}

	.week-navigation {
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.nav-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.nav-btn:hover {
		background: #2563eb;
		transform: scale(1.05);
	}

	.week-info {
		font-size: 18px;
		font-weight: 600;
		color: #1e293b;
		min-width: 200px;
		text-align: center;
	}

	.week-view {
		display: grid;
		grid-template-columns: repeat(7, 1fr);
		gap: 16px;
		margin-bottom: 40px;
	}

	.day-card {
		background: white;
		border-radius: 12px;
		padding: 16px;
		min-height: 200px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		transition: all 0.3s;
		border: 2px solid transparent;
	}

	.day-card:hover {
		transform: translateY(-4px);
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
	}

	.day-card.today {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #dbeafe 0%, #ffffff 100%);
	}

	.day-card.has-payments {
		border-color: #10b981;
		background: linear-gradient(135deg, #d1fae5 0%, #ffffff 100%);
	}

	.day-card.clickable {
		cursor: pointer;
	}

	.day-card.clickable:hover {
		transform: translateY(-6px);
		box-shadow: 0 12px 32px rgba(0, 0, 0, 0.2);
	}

	.day-header {
		text-align: center;
		margin-bottom: 16px;
		padding-bottom: 12px;
		border-bottom: 1px solid #e2e8f0;
	}

	.day-name {
		font-size: 14px;
		font-weight: 600;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.day-date {
		font-size: 18px;
		font-weight: 700;
		color: #1e293b;
		margin-top: 4px;
	}

	.payment-summary {
		text-align: center;
		margin-bottom: 16px;
	}

	.payment-count {
		font-size: 12px;
		color: #10b981;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.payment-amount {
		font-size: 20px;
		font-weight: 700;
		color: #059669;
		margin-top: 4px;
	}

	.payment-categories {
		margin-top: 12px;
	}

	.category-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: #f1f5f9;
		padding: 6px 10px;
		border-radius: 4px;
		margin-bottom: 4px;
		font-size: 11px;
	}

	.category-name {
		color: #475569;
		font-weight: 500;
		flex: 1;
	}

	.category-amount {
		color: #059669;
		font-weight: 600;
		margin-left: 8px;
	}

	.no-payments {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100px;
	}

	.no-payments-text {
		color: #94a3b8;
		font-size: 14px;
		font-style: italic;
	}

	/* Monthly Totals Section */
	.monthly-totals {
		background: white;
		border-radius: 12px;
		padding: 24px;
		margin-top: 32px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.monthly-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 24px;
	}

	.monthly-header h2 {
		margin: 0;
		color: #1e293b;
		font-size: 22px;
		font-weight: 700;
	}

	.monthly-navigation {
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.monthly-navigation .nav-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.monthly-navigation .nav-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: scale(1.05);
	}

	.monthly-navigation .nav-btn:disabled {
		background: #94a3b8;
		cursor: not-allowed;
		opacity: 0.5;
	}

	.nav-info {
		font-size: 14px;
		font-weight: 600;
		color: #64748b;
		min-width: 150px;
		text-align: center;
	}

	.months-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 20px;
	}

	.month-card {
		background: linear-gradient(135deg, #f8fafc 0%, #ffffff 100%);
		border: 2px solid #e2e8f0;
		border-radius: 12px;
		padding: 16px;
		transition: all 0.3s;
		position: relative;
		overflow: hidden;

	}

	.month-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
		border-color: #3b82f6;
	}

	.month-card.current {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #dbeafe 0%, #ffffff 100%);
	}

	.month-card.next {
		border-color: #10b981;
		background: linear-gradient(135deg, #d1fae5 0%, #ffffff 100%);
	}

	.month-card.has-payments {
		border-color: #f59e0b;
		background: linear-gradient(135deg, #fef3c7 0%, #ffffff 100%);
	}

	.month-card.current.has-payments {
		border-color: #3b82f6;
		background: linear-gradient(135deg, #dbeafe 0%, #ffffff 100%);
	}

	.month-card.clickable {
		cursor: pointer;
	}

	.month-card.clickable:hover {
		transform: translateY(-4px);
		box-shadow: 0 12px 32px rgba(0, 0, 0, 0.2);
	}

	.month-header {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
	}

	.month-icon {
		font-size: 24px;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #dbeafe;
		border-radius: 8px;
	}

	.month-info {
		flex: 1;
	}

	.month-name {
		font-size: 16px;
		font-weight: 600;
		color: #1e293b;
		margin-bottom: 2px;
	}

	.month-label {
		font-size: 12px;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.month-amount {
		font-size: 24px;
		font-weight: 700;
		color: #059669;
		margin-bottom: 8px;
		text-align: center;
	}

	.month-details {
		text-align: center;
		margin-bottom: 8px;
	}

	.payment-count {
		font-size: 11px;
		color: #64748b;
		font-weight: 500;
	}

	.month-status {
		text-align: center;
	}

	.status-active {
		background: #d1fae5;
		color: #065f46;
		padding: 4px 12px;
		border-radius: 20px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.status-empty {
		background: #f1f5f9;
		color: #64748b;
		padding: 4px 12px;
		border-radius: 20px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	/* Details Section */
	.details-section {
		background: white;
		border-radius: 12px;
		padding: 24px;
		margin-top: 32px;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.details-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e5e7eb;
	}

	.details-header h3 {
		margin: 0;
		color: #1e293b;
		font-size: 20px;
		font-weight: 600;
	}

	.close-btn {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		background: #dc2626;
		transform: scale(1.05);
	}

	.details-summary {
		display: flex;
		gap: 32px;
		margin-bottom: 24px;
		padding: 16px;
		background: #f8fafc;
		border-radius: 8px;
	}

	.details-section .filter-controls {
		display: flex;
		gap: 12px;
		margin-bottom: 20px;
		padding: 16px;
		background: #f8fafc;
		border-radius: 8px;
		align-items: center;
	}

	.details-section .filter-controls::before {
		content: '🔍 Filters:';
		font-size: 14px;
		font-weight: 600;
		color: #475569;
		margin-right: 8px;
	}

	.summary-item {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.summary-label {
		font-size: 12px;
		color: #64748b;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.summary-value {
		font-size: 18px;
		color: #1e293b;
		font-weight: 700;
	}

	.details-table {
		flex: 1;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		min-height: 300px;
		max-height: 60vh;
		overflow: auto;
		background: white;
	}

	.details-table table {
		width: 100%;
		min-width: 1200px;
		border-collapse: collapse;
		background: white;
	}

	.details-table th {
		background: #f1f5f9;
		color: #475569;
		font-weight: 600;
		font-size: 12px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		padding: 16px 12px;
		text-align: left;
		border-bottom: 1px solid #e2e8f0;
		white-space: nowrap;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.details-table td {
		padding: 16px 12px;
		border-bottom: 1px solid #f1f5f9;
		font-size: 14px;
		color: #374151;
	}

	.details-table tbody tr:hover {
		background: #f8fafc;
	}

	.vendor-cell {
		min-width: 200px;
	}

	.vendor-name {
		font-weight: 600;
		color: #1e293b;
		margin-bottom: 2px;
	}

	.vendor-id {
		font-size: 11px;
		color: #64748b;
	}

	.amount-cell {
		font-weight: 700;
		color: #059669;
		text-align: right;
	}

	.payment-method-badge {
		background: #dbeafe;
		color: #1e40af;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
	}

	.status-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		text-transform: uppercase;
	}

	.status-scheduled {
		background: #fef3c7;
		color: #92400e;
	}

	.status-paid {
		background: #d1fae5;
		color: #065f46;
	}

	.status-overdue {
		background: #fee2e2;
		color: #991b1b;
	}

	.type-badge {
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		white-space: nowrap;
	}

	.vendor-type {
		background: #dbeafe;
		color: #1e40af;
	}

	.expense-type {
		background: #fee2e2;
		color: #991b1b;
	}



</style>