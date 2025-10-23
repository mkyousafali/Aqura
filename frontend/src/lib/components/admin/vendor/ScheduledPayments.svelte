<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
	import MonthDetails from './MonthDetails.svelte';

	// Current date and navigation
	let currentDate = new Date();
	let currentWeek = new Date();
	
	// Payment data
	let scheduledPayments = [];
	let weekDays = [];
	let totalScheduledAmount = 0;
	
	// Selected day details
	let selectedDay = null;
	let showDetails = false;
	
	// Filters
	let filterBranch = '';
	let filterPaymentMethod = '';
	let branches = [];
	let paymentMethods = [];
	
	// Monthly totals
	let monthlyData = [];
	let currentMonthIndex = 0; // Starting from current month
	let visibleMonthsCount = 6; // Show 6 months at a time

	// Initialize component
	onMount(async () => {
		generateWeekDays();
		calculateMonthlyTotals();
		await loadBranches();
		await loadPaymentMethods();
		await loadScheduledPayments();
	});

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
				.eq('payment_status', 'scheduled')
				.order('due_date', { ascending: true });

			if (error) {
				console.error('Error loading scheduled payments:', error);
				return;
			}

			console.log('Loaded scheduled payments:', data);
			scheduledPayments = data || [];
			totalScheduledAmount = scheduledPayments.reduce((sum, payment) => sum + (payment.final_bill_amount || 0), 0);
			
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

	// Load branches for filter
	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('name_en, name_ar, is_active')
				.eq('is_active', true)
				.order('name_en');

			if (error) {
				console.error('Error loading branches:', error);
				return;
			}

			branches = data || [];
			console.log('Loaded branches:', branches.map(b => b.name_en));
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

	// Filter payments based on selected filters
	$: filteredPayments = scheduledPayments.filter(payment => {
		const branchMatch = !filterBranch || payment.branch_name === filterBranch;
		const paymentMethodMatch = !filterPaymentMethod || payment.payment_method === filterPaymentMethod;
		return branchMatch && paymentMethodMatch;
	});

	// Re-group payments when filters change
	$: if (filteredPayments && weekDays.length > 0) {
		groupPaymentsByDay();
		calculateMonthlyTotals();
	}

	// Filter selected day payments
	$: filteredSelectedDayPayments = selectedDay?.payments.filter(payment => {
		const branchMatch = !filterBranch || payment.branch_name === filterBranch;
		const paymentMethodMatch = !filterPaymentMethod || payment.payment_method === filterPaymentMethod;
		return branchMatch && paymentMethodMatch;
	}) || [];

	// Calculate filtered total
	$: filteredSelectedDayTotal = filteredSelectedDayPayments.reduce(
		(sum, payment) => sum + (payment.final_bill_amount || 0), 
		0
	);

	// Group payments by day
	function groupPaymentsByDay() {
		console.log('Grouping payments by day...', filteredPayments.length, 'payments');
		weekDays.forEach(day => {
			day.payments = filteredPayments.filter(payment => {
				const paymentDate = new Date(payment.due_date);
				const matches = paymentDate.toDateString() === day.fullDate.toDateString();
				if (matches) {
					console.log(`Payment matched for ${day.fullDate.toDateString()}:`, payment);
				}
				return matches;
			});
			day.totalAmount = day.payments.reduce((sum, payment) => sum + (payment.final_bill_amount || 0), 0);
			console.log(`Day ${day.dayName} ${day.date}: ${day.payments.length} payments, total: ${day.totalAmount}`);
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
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 0,
			maximumFractionDigits: 0
		}).format(amount).replace('SAR', 'SAR');
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
				methodTotals[method] += (payment.final_bill_amount || 0);
			} else {
				// If method not in our categories, add to default
				methodTotals['Cash on Delivery'] += (payment.final_bill_amount || 0);
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
		
		openWindow({
			id: windowId,
			title: `${monthData.monthName} ${monthData.year} - Payment Details #${instanceNumber}`,
			component: MonthDetails,
			props: { monthData },
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
		
		// Calculate totals from scheduled payments
		scheduledPayments.forEach(payment => {
			const paymentDate = new Date(payment.due_date);
			const paymentMonth = paymentDate.getMonth();
			const paymentYear = paymentDate.getFullYear();
			
			// Find matching month in visible data
			const monthData = monthlyData.find(m => m.month === paymentMonth && m.year === paymentYear);
			if (monthData) {
				monthData.total += (payment.final_bill_amount || 0);
				monthData.paymentCount++;
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
<div class="scheduled-payments">
	<div class="header">
		<div class="title-section">
			<h1>💰 Scheduled Payments</h1>
			<p>Total Scheduled: <strong>{formatCurrency(totalScheduledAmount)}</strong></p>
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

	<div class="week-view">
		{#each weekDays as day}
			<div class="day-card" class:today={isToday(day.fullDate)} class:has-payments={hasPayments(day)} class:clickable={hasPayments(day)} on:click={() => handleDayClick(day)}>
				<div class="day-header">
					<div class="day-name">{day.dayShort}</div>
					<div class="day-date">{day.date} {day.month}</div>
				</div>
				
				<div class="day-content">
					{#if hasPayments(day)}
						<div class="payment-summary">
							<div class="payment-count">{day.payments.length} payment{day.payments.length > 1 ? 's' : ''}</div>
							<div class="payment-amount">{formatCurrency(day.totalAmount)}</div>
						</div>
						
						<div class="payment-categories">
							{#each getPaymentMethodsForDay(day) as method}
								<div class="category-item">
									<span class="category-name">{method.name}</span>
									<span class="category-amount">{formatCurrency(method.amount)}</span>
								</div>
							{/each}
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
					
					<div class="month-details">
						<span class="payment-count">{monthData.paymentCount} payment{monthData.paymentCount !== 1 ? 's' : ''}</span>
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
						<option value={branch.name_en}>{branch.name_en}</option>
					{/each}
				</select>
				
				<select class="filter-select" bind:value={filterPaymentMethod}>
					<option value="">All Payment Methods</option>
					{#each paymentMethods as method}
						<option value={method}>{method}</option>
					{/each}
				</select>
			</div>

			<div class="details-table">
				<table>
					<thead>
						<tr>
							<th>Vendor Name</th>
							<th>Branch</th>
							<th>Bill Number</th>
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
								<td class="vendor-cell">
									<div class="vendor-name">{payment.vendor_name || 'Unknown Vendor'}</div>
									<div class="vendor-id">ID: {payment.vendor_id || 'N/A'}</div>
								</td>
								<td>{payment.branch_name || 'N/A'}</td>
								<td>{payment.bill_number || 'N/A'}</td>
								<td>
									<span class="payment-method-badge">{payment.payment_method || 'Cash on Delivery'}</span>
								</td>
								<td class="amount-cell">{formatCurrency(payment.final_bill_amount || 0)}</td>
								<td class="amount-cell">{formatCurrency(payment.original_bill_amount || 0)}</td>
								<td class="amount-cell">{formatCurrency(payment.original_final_amount || 0)}</td>
								<td>{new Date(payment.due_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</td>
								<td>{payment.original_due_date ? new Date(payment.original_due_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : 'N/A'}</td>
								<td>
									<span class="status-badge status-{payment.payment_status}">{payment.payment_status || 'scheduled'}</span>
								</td>
							</tr>
						{/each}
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
		justify-content: space-between;
		align-items: center;
		margin-bottom: 32px;
		padding: 20px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		gap: 20px;
		flex-wrap: wrap;
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



</style>