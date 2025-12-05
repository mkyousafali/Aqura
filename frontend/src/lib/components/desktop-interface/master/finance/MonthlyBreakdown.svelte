<script>
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';

	export let onRefresh = null;
	export let setRefreshCallback = null;

	let selectedMonth = new Date().getMonth();
	let selectedYear = new Date().getFullYear();
	let isLoading = false;

	const months = [
		'January', 'February', 'March', 'April', 'May', 'June',
		'July', 'August', 'September', 'October', 'November', 'December'
	];

	let branches = [];
	let breakdownData = [];
	let totalSummary = {
		totalVendor: 0,
		totalExpense: 0,
		grandTotal: 0
	};

	// Helper to format currency
	function formatCurrency(amount) {
		if (amount === null || amount === undefined || isNaN(amount)) return 'SAR 0.00';
		return `SAR ${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
	}

	// Load branches
	async function loadBranches() {
		try {
			const { data, error } = await supabaseAdmin
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en', { ascending: true });

			if (error) {
				console.error('Error loading branches:', error);
				return;
			}

			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	// Load monthly breakdown data
	async function loadBreakdownData() {
		isLoading = true;
		try {
			const startDate = new Date(selectedYear, selectedMonth, 1);
			const endDate = new Date(selectedYear, selectedMonth + 1, 0);
			const daysInMonth = endDate.getDate();

			const startDateStr = startDate.toISOString().split('T')[0];
			const endDateStr = endDate.toISOString().split('T')[0];

			// Load vendor payments
			const { data: vendorData, error: vendorError } = await supabaseAdmin
				.from('vendor_payment_schedule')
				.select('due_date, branch_id, payment_method, final_bill_amount')
				.gte('due_date', startDateStr)
				.lte('due_date', endDateStr);

			if (vendorError) {
				console.error('Error loading vendor payments:', vendorError);
				return;
			}

			// Load expense payments
			const { data: expenseData, error: expenseError } = await supabaseAdmin
				.from('expense_scheduler')
				.select('due_date, branch_id, payment_method, amount')
				.gte('due_date', startDateStr)
				.lte('due_date', endDateStr);

			if (expenseError) {
				console.error('Error loading expense payments:', expenseError);
				return;
			}

			// Build breakdown structure
			const breakdown = [];
			let totalVendor = 0;
			let totalExpense = 0;

			for (let day = 1; day <= daysInMonth; day++) {
				const dateStr = `${selectedYear}-${String(selectedMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
				
				// Group by branch
				const branchTotals = {};
				
				branches.forEach(branch => {
					branchTotals[branch.id] = {
						branchName: branch.name_en,
						vendorTotal: 0,
						expenseTotal: 0,
						paymentMethods: {}
					};
				});

				// Process vendor payments
				vendorData?.filter(p => p.due_date === dateStr).forEach(payment => {
					if (payment.branch_id && branchTotals[payment.branch_id]) {
						const amount = payment.final_bill_amount || 0;
						branchTotals[payment.branch_id].vendorTotal += amount;
						totalVendor += amount;

						const method = payment.payment_method || 'Unknown';
						if (!branchTotals[payment.branch_id].paymentMethods[method]) {
							branchTotals[payment.branch_id].paymentMethods[method] = 0;
						}
						branchTotals[payment.branch_id].paymentMethods[method] += amount;
					}
				});

				// Process expense payments
				expenseData?.filter(p => p.due_date === dateStr).forEach(payment => {
					if (payment.branch_id && branchTotals[payment.branch_id]) {
						const amount = payment.amount || 0;
						branchTotals[payment.branch_id].expenseTotal += amount;
						totalExpense += amount;

						const method = payment.payment_method || 'Unknown';
						if (!branchTotals[payment.branch_id].paymentMethods[method]) {
							branchTotals[payment.branch_id].paymentMethods[method] = 0;
						}
						branchTotals[payment.branch_id].paymentMethods[method] += amount;
					}
				});

				breakdown.push({
					day,
					date: dateStr,
					branches: branchTotals
				});
			}

			breakdownData = breakdown;
			totalSummary = {
				totalVendor,
				totalExpense,
				grandTotal: totalVendor + totalExpense
			};
		} catch (error) {
			console.error('Error loading breakdown data:', error);
		} finally {
			isLoading = false;
		}
	}

	// Reload when month/year changes
	$: if (selectedMonth !== undefined && selectedYear) {
		loadData();
	}

	async function loadData() {
		await loadBranches();
		await loadBreakdownData();
	}

	onMount(() => {
		loadData();
	});
</script>

<div class="breakdown-container">
	<!-- Header Section -->
	<div class="header-section">
		<h2 class="title">📊 Monthly Breakdown Report</h2>
		
		<div class="month-selector">
			<label for="month-select">Select Month:</label>
			<select id="month-select" bind:value={selectedMonth}>
				{#each months as month, index}
					<option value={index}>{month}</option>
				{/each}
			</select>
			<select id="year-select" bind:value={selectedYear}>
				{#each Array(10) as _, i}
					<option value={new Date().getFullYear() - 5 + i}>
						{new Date().getFullYear() - 5 + i}
					</option>
				{/each}
			</select>
		</div>

		<!-- Total Summary -->
		<div class="summary-cards">
			<div class="summary-card vendor">
				<div class="card-label">Total Vendor Payments</div>
				<div class="card-value">{formatCurrency(totalSummary.totalVendor)}</div>
			</div>
			<div class="summary-card expense">
				<div class="card-label">Total Expense Payments</div>
				<div class="card-value">{formatCurrency(totalSummary.totalExpense)}</div>
			</div>
			<div class="summary-card grand">
				<div class="card-label">Grand Total</div>
				<div class="card-value">{formatCurrency(totalSummary.grandTotal)}</div>
			</div>
		</div>
	</div>

	<!-- Breakdown Table -->
	{#if isLoading}
		<div class="loading">Loading breakdown data...</div>
	{:else}
		<div class="table-container">
			<table class="breakdown-table">
				<thead>
					<tr>
						<th rowspan="2">Day</th>
						<th rowspan="2">Date</th>
						<th rowspan="2">Branch</th>
						<th colspan="2">Payment Totals</th>
						<th rowspan="2">Payment Methods</th>
					</tr>
					<tr>
						<th>Vendor</th>
						<th>Expense</th>
					</tr>
				</thead>
				<tbody>
					{#each breakdownData as dayData}
						{@const activeBranches = Object.entries(dayData.branches).filter(([_, data]) => 
							data.vendorTotal > 0 || data.expenseTotal > 0
						)}
						{#if activeBranches.length > 0}
							{#each activeBranches as [branchId, branchData], index}
								<tr>
									{#if index === 0}
										<td rowspan={activeBranches.length} class="day-cell">{dayData.day}</td>
										<td rowspan={activeBranches.length}>{dayData.date}</td>
									{/if}
									<td class="branch-cell">{branchData.branchName}</td>
									<td class="amount-cell">{formatCurrency(branchData.vendorTotal)}</td>
									<td class="amount-cell">{formatCurrency(branchData.expenseTotal)}</td>
									<td class="methods-cell">
										{#each Object.entries(branchData.paymentMethods) as [method, amount]}
											<div class="method-item">
												<span class="method-name">{method}:</span>
												<span class="method-amount">{formatCurrency(amount)}</span>
											</div>
										{/each}
									</td>
								</tr>
							{/each}
						{/if}
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<style>
	.breakdown-container {
		width: 100%;
		height: 100%;
		padding: 24px;
		background: #f8fafc;
		overflow-y: auto;
	}

	.header-section {
		margin-bottom: 24px;
		padding: 20px;
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.title {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 20px 0;
	}

	.month-selector {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 20px;
	}

	.month-selector label {
		font-weight: 600;
		color: #475569;
		font-size: 14px;
	}

	.month-selector select {
		padding: 8px 12px;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		background: white;
		font-size: 14px;
		color: #1e293b;
		cursor: pointer;
		outline: none;
		transition: border-color 0.2s;
	}

	.month-selector select:hover {
		border-color: #3b82f6;
	}

	.summary-cards {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 16px;
	}

	.summary-card {
		padding: 20px;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.summary-card.vendor {
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
	}

	.summary-card.expense {
		background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
	}

	.summary-card.grand {
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
	}

	.card-label {
		color: rgba(255, 255, 255, 0.9);
		font-size: 14px;
		font-weight: 500;
		margin-bottom: 8px;
	}

	.card-value {
		color: white;
		font-size: 24px;
		font-weight: 700;
	}

	.loading {
		text-align: center;
		padding: 40px;
		color: #64748b;
		font-size: 16px;
	}

	.table-container {
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		overflow: hidden;
	}

	.breakdown-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.breakdown-table thead {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.breakdown-table th {
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		border: 1px solid rgba(255, 255, 255, 0.2);
	}

	.breakdown-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #e2e8f0;
		vertical-align: top;
	}

	.breakdown-table tbody tr:hover {
		background: #f8fafc;
	}

	.day-cell {
		font-weight: 700;
		color: #3b82f6;
		text-align: center;
		font-size: 16px;
	}

	.branch-cell {
		font-weight: 600;
		color: #1e293b;
	}

	.amount-cell {
		text-align: right;
		font-weight: 600;
		color: #059669;
	}

	.methods-cell {
		font-size: 12px;
	}

	.method-item {
		display: flex;
		justify-content: space-between;
		padding: 4px 0;
		border-bottom: 1px solid #f1f5f9;
	}

	.method-item:last-child {
		border-bottom: none;
	}

	.method-name {
		color: #64748b;
		font-weight: 500;
	}

	.method-amount {
		color: #1e293b;
		font-weight: 600;
	}
</style>
