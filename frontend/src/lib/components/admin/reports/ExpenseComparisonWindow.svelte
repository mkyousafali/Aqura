<script lang="ts">
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';

	let expenses: any[] = [];
	let allCategories: { name: string; color: string }[] = [];
	let branches: Array<{id: number, name_en: string, name_ar: string}> = [];
	let selectedBranch: string = 'all';
	let loading = true;
	let error: string | null = null;

	// Modal state
	let showDetailsModal = false;
	let selectedCategory: string = '';
	let categoryDetails: any[] = [];
	let selectedPeriod: string = 'total'; // 'total', 'previous', 'current', 'period1', 'period2'

	// Custom period modal state
	let showCustomPeriodModal = false;
	let period1StartDate = '';
	let period1EndDate = '';
	let period2StartDate = '';
	let period2EndDate = '';
	let showCustomPeriods = false;
	let period1ExpensesByCategory: { category: string; amount: number; percentage: number; color: string }[] = [];
	let period2ExpensesByCategory: { category: string; amount: number; percentage: number; color: string }[] = [];

	// Data for charts
	let totalExpensesByCategory: { category: string; amount: number; percentage: number; color: string }[] = [];
	let previousMonthExpensesByCategory: { category: string; amount: number; percentage: number; color: string }[] = [];
	let currentMonthExpensesByCategory: { category: string; amount: number; percentage: number; color: string }[] = [];

	const colors = [
		'#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6',
		'#ec4899', '#14b8a6', '#f97316', '#06b6d4', '#84cc16',
		'#6366f1', '#f43f5e', '#22c55e', '#eab308', '#a855f7',
		'#64748b', '#dc2626', '#059669', '#d97706', '#7c3aed',
		'#db2777', '#0d9488', '#ea580c', '#0891b2', '#65a30d'
	];

	onMount(async () => {
		await loadCategories();
		await loadBranches();
		await loadExpenses();
	});

	async function loadBranches() {
		try {
			const { data, error: fetchError } = await supabaseAdmin
				.from('branches')
				.select('id, name_en, name_ar')
				.order('name_en');

			if (fetchError) throw fetchError;
			branches = data || [];
			console.log('✅ Loaded branches:', branches.length);
		} catch (err: any) {
			console.error('❌ Error loading branches:', err);
		}
	}

	async function loadCategories() {
		try {
			const { data, error: fetchError } = await supabaseAdmin
				.from('expense_sub_categories')
				.select('name_en')
				.eq('is_active', true)
				.order('name_en');

			if (fetchError) throw fetchError;

			// Create a color map for all categories and remove duplicates
			const uniqueCategories = new Map<string, string>();
			(data || []).forEach((cat, index) => {
				if (!uniqueCategories.has(cat.name_en)) {
					uniqueCategories.set(cat.name_en, colors[uniqueCategories.size % colors.length]);
				}
			});

			allCategories = Array.from(uniqueCategories.entries()).map(([name, color]) => ({
				name,
				color
			}));

			console.log('✅ Loaded categories:', allCategories.length);
		} catch (err: any) {
			console.error('❌ Error loading categories:', err);
		}
	}

	async function loadExpenses() {
		loading = true;
		error = null;
		try {
			const { data, error: fetchError } = await supabaseAdmin
				.from('expense_scheduler')
				.select(`
					*,
					branches:branch_id (
						id,
						name_en,
						name_ar
					)
				`)
				.order('created_at', { ascending: false });

			if (fetchError) throw fetchError;

			expenses = (data || []).filter(exp => exp.amount && Number(exp.amount) !== 0);
			
			// Process data for charts
			processChartData();
			
			loading = false;
		} catch (err: any) {
			console.error('❌ Error loading expenses:', err);
			error = `Failed to load expenses: ${err.message}`;
			loading = false;
		}
	}

	function processChartData() {
		const now = new Date();
		const currentMonth = now.getMonth();
		const currentYear = now.getFullYear();
		const previousMonth = currentMonth === 0 ? 11 : currentMonth - 1;
		const previousMonthYear = currentMonth === 0 ? currentYear - 1 : currentYear;

		// Filter expenses by branch if selected
		const filteredExpenses = selectedBranch === 'all' 
			? expenses 
			: expenses.filter(exp => exp.branch_id === parseInt(selectedBranch));

		// Group all expenses by category
		const totalByCategory = new Map<string, number>();
		const previousMonthByCategory = new Map<string, number>();
		const currentMonthByCategory = new Map<string, number>();

		filteredExpenses.forEach(expense => {
			const category = expense.expense_category_name_en || 'Uncategorized';
			const amount = Number(expense.amount || 0);
			const expenseDate = new Date(expense.due_date || expense.bill_date || expense.created_at);
			const expenseMonth = expenseDate.getMonth();
			const expenseYear = expenseDate.getFullYear();

			// Total expenses
			totalByCategory.set(category, (totalByCategory.get(category) || 0) + amount);

			// Previous month
			if (expenseMonth === previousMonth && expenseYear === previousMonthYear) {
				previousMonthByCategory.set(category, (previousMonthByCategory.get(category) || 0) + amount);
			}

			// Current month
			if (expenseMonth === currentMonth && expenseYear === currentYear) {
				currentMonthByCategory.set(category, (currentMonthByCategory.get(category) || 0) + amount);
			}
		});

		// Convert to chart data
		totalExpensesByCategory = convertToChartData(totalByCategory);
		previousMonthExpensesByCategory = convertToChartData(previousMonthByCategory);
		currentMonthExpensesByCategory = convertToChartData(currentMonthByCategory);
		
		// Update custom periods if they exist
		if (showCustomPeriods) {
			applyCustomPeriodsWithoutClosing();
		}
	}

	function convertToChartData(dataMap: Map<string, number>) {
		const total = Array.from(dataMap.values()).reduce((sum, val) => sum + val, 0);
		
		// Create data for all categories in the same order, even those with 0 amount
		return allCategories.map(cat => {
			const amount = dataMap.get(cat.name) || 0;
			return {
				category: cat.name,
				amount,
				percentage: total > 0 ? (amount / total) * 100 : 0,
				color: cat.color
			};
		});
		// Don't sort - keep original order from expense_sub_categories
	}

	function formatAmount(amount: number): string {
		return `SAR ${amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
	}

	function getPreviousMonthName(): string {
		const now = new Date();
		const previousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
		return previousMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
	}

	function getCurrentMonthName(): string {
		const now = new Date();
		return now.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
	}

	function showCategoryDetails(category: string, amount: number, period: string = 'total') {
		if (amount === 0) return; // Don't show popup for zero amounts
		
		selectedCategory = category;
		selectedPeriod = period;
		
		const now = new Date();
		const currentMonth = now.getMonth();
		const currentYear = now.getFullYear();
		const previousMonth = currentMonth === 0 ? 11 : currentMonth - 1;
		const previousMonthYear = currentMonth === 0 ? currentYear - 1 : currentYear;
		
		// Filter expenses based on category and branch
		let filteredExpenses = expenses.filter(exp => exp.expense_category_name_en === category);
		
		// Apply branch filter if selected
		if (selectedBranch !== 'all') {
			filteredExpenses = filteredExpenses.filter(exp => exp.branch_id === parseInt(selectedBranch));
		}
		
		if (period === 'previous') {
			filteredExpenses = filteredExpenses.filter(exp => {
				const expenseDate = new Date(exp.due_date || exp.bill_date || exp.created_at);
				return expenseDate.getMonth() === previousMonth && expenseDate.getFullYear() === previousMonthYear;
			});
		} else if (period === 'current') {
			filteredExpenses = filteredExpenses.filter(exp => {
				const expenseDate = new Date(exp.due_date || exp.bill_date || exp.created_at);
				return expenseDate.getMonth() === currentMonth && expenseDate.getFullYear() === currentYear;
			});
		} else if (period === 'period1') {
			filteredExpenses = filteredExpenses.filter(exp => {
				const expenseDate = new Date(exp.due_date || exp.bill_date || exp.created_at);
				const startDate = new Date(period1StartDate);
				const endDate = new Date(period1EndDate);
				return expenseDate >= startDate && expenseDate <= endDate;
			});
		} else if (period === 'period2') {
			filteredExpenses = filteredExpenses.filter(exp => {
				const expenseDate = new Date(exp.due_date || exp.bill_date || exp.created_at);
				const startDate = new Date(period2StartDate);
				const endDate = new Date(period2EndDate);
				return expenseDate >= startDate && expenseDate <= endDate;
			});
		}
		// If period === 'total', show all expenses for that category
		
		categoryDetails = filteredExpenses.sort((a, b) => 
			new Date(b.due_date || b.bill_date || b.created_at).getTime() - new Date(a.due_date || a.bill_date || a.created_at).getTime()
		);
		
		showDetailsModal = true;
	}

	function closeModal() {
		showDetailsModal = false;
		selectedCategory = '';
		categoryDetails = [];
	}

	function formatDate(dateString: string): string {
		if (!dateString) return '-';
		const date = new Date(dateString);
		return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
	}

	function openCustomPeriodModal() {
		showCustomPeriodModal = true;
	}

	function closeCustomPeriodModal() {
		showCustomPeriodModal = false;
	}

	function applyCustomPeriods() {
		if (!period1StartDate || !period1EndDate || !period2StartDate || !period2EndDate) {
			alert('Please fill in all date fields');
			return;
		}

		applyCustomPeriodsWithoutClosing();
		showCustomPeriods = true;
		closeCustomPeriodModal();
	}

	function applyCustomPeriodsWithoutClosing() {
		// Filter expenses by branch if selected
		const filteredExpenses = selectedBranch === 'all' 
			? expenses 
			: expenses.filter(exp => exp.branch_id === parseInt(selectedBranch));

		// Process custom period 1
		const period1ByCategory = new Map<string, number>();
		filteredExpenses.forEach(expense => {
			const category = expense.expense_category_name_en || 'Uncategorized';
			const amount = Number(expense.amount || 0);
			const expenseDate = new Date(expense.due_date || expense.bill_date || expense.created_at);
			const startDate = new Date(period1StartDate);
			const endDate = new Date(period1EndDate);

			if (expenseDate >= startDate && expenseDate <= endDate) {
				period1ByCategory.set(category, (period1ByCategory.get(category) || 0) + amount);
			}
		});

		// Process custom period 2
		const period2ByCategory = new Map<string, number>();
		filteredExpenses.forEach(expense => {
			const category = expense.expense_category_name_en || 'Uncategorized';
			const amount = Number(expense.amount || 0);
			const expenseDate = new Date(expense.due_date || expense.bill_date || expense.created_at);
			const startDate = new Date(period2StartDate);
			const endDate = new Date(period2EndDate);

			if (expenseDate >= startDate && expenseDate <= endDate) {
				period2ByCategory.set(category, (period2ByCategory.get(category) || 0) + amount);
			}
		});

		period1ExpensesByCategory = convertToChartData(period1ByCategory);
		period2ExpensesByCategory = convertToChartData(period2ByCategory);
	}

	function formatPeriodLabel(startDate: string, endDate: string): string {
		const start = new Date(startDate);
		const end = new Date(endDate);
		return `${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} - ${end.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
	}
</script>

<div class="comparison-window">
	<div class="header">
		<h2>📊 Expense Comparison by Category</h2>
		<div class="header-controls">
			<select class="branch-filter" bind:value={selectedBranch} on:change={processChartData}>
				<option value="all">All Branches</option>
				{#each branches as branch}
					<option value={branch.id}>{branch.name_en}</option>
				{/each}
			</select>
			<button class="custom-period-btn" on:click={openCustomPeriodModal}>
				📅 Custom Period
			</button>
		</div>
	</div>

	{#if loading}
		<div class="loading">
			<div class="spinner">⏳</div>
			<p>Loading expense data...</p>
		</div>
	{:else if error}
		<div class="error-message">
			<div class="error-icon">❌</div>
			<p>{error}</p>
			<button class="retry-btn" on:click={loadExpenses}>Retry</button>
		</div>
	{:else}
		<div class="charts-container">
			<!-- Total Expenses Chart -->
			<div class="chart-section">
				<h3>Total Expenses by Category</h3>
				<div class="total-section">
					<div class="total-label">Total Amount:</div>
					<div class="total-amount">{formatAmount(totalExpensesByCategory.reduce((sum, item) => sum + item.amount, 0))}</div>
				</div>
				{#if totalExpensesByCategory.length > 0}
					<div class="legend">
						{#each totalExpensesByCategory as item}
							<div 
								class="legend-item" 
								class:zero-amount={item.amount === 0}
								class:clickable={item.amount > 0}
								on:click={() => showCategoryDetails(item.category, item.amount, 'total')}
							>
								<span class="legend-color" style="background-color: {item.color}"></span>
								<span class="legend-label">{item.category}</span>
								<span class="legend-value">{formatAmount(item.amount)}</span>
								<span class="legend-percentage">({item.percentage.toFixed(1)}%)</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="no-data">
						<p>No expense data available</p>
					</div>
				{/if}
			</div>

			<!-- Previous Month Chart -->
			<div class="chart-section">
				<h3>Previous Month ({getPreviousMonthName()})</h3>
				<div class="total-section">
					<div class="total-label">Total Amount:</div>
					<div class="total-amount">{formatAmount(previousMonthExpensesByCategory.reduce((sum, item) => sum + item.amount, 0))}</div>
				</div>
				{#if previousMonthExpensesByCategory.length > 0}
					<div class="legend">
						{#each previousMonthExpensesByCategory as item}
							<div 
								class="legend-item" 
								class:zero-amount={item.amount === 0}
								class:clickable={item.amount > 0}
								on:click={() => showCategoryDetails(item.category, item.amount, 'previous')}
							>
								<span class="legend-color" style="background-color: {item.color}"></span>
								<span class="legend-label">{item.category}</span>
								<span class="legend-value">{formatAmount(item.amount)}</span>
								<span class="legend-percentage">({item.percentage.toFixed(1)}%)</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="no-data">
						<p>No expenses for this month</p>
					</div>
				{/if}
			</div>

			<!-- Current Month Chart -->
			<div class="chart-section">
				<h3>Current Month ({getCurrentMonthName()})</h3>
				<div class="total-section">
					<div class="total-label">Total Amount:</div>
					<div class="total-amount">{formatAmount(currentMonthExpensesByCategory.reduce((sum, item) => sum + item.amount, 0))}</div>
				</div>
				{#if currentMonthExpensesByCategory.length > 0}
					<div class="legend">
						{#each currentMonthExpensesByCategory as item}
							<div 
								class="legend-item" 
								class:zero-amount={item.amount === 0}
								class:clickable={item.amount > 0}
								on:click={() => showCategoryDetails(item.category, item.amount, 'current')}
							>
								<span class="legend-color" style="background-color: {item.color}"></span>
								<span class="legend-label">{item.category}</span>
								<span class="legend-value">{formatAmount(item.amount)}</span>
								<span class="legend-percentage">({item.percentage.toFixed(1)}%)</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="no-data">
						<p>No expenses for this month</p>
					</div>
				{/if}
			</div>

			<!-- Custom Period 1 -->
			{#if showCustomPeriods}
			<div class="chart-section">
				<h3>Period 1: {formatPeriodLabel(period1StartDate, period1EndDate)}</h3>
				<div class="total-section">
					<div class="total-label">Total Amount:</div>
					<div class="total-amount">{formatAmount(period1ExpensesByCategory.reduce((sum, item) => sum + item.amount, 0))}</div>
				</div>
				{#if period1ExpensesByCategory.length > 0}
					<div class="legend">
						{#each period1ExpensesByCategory as item}
							<div 
								class="legend-item" 
								class:zero-amount={item.amount === 0}
								class:clickable={item.amount > 0}
								on:click={() => showCategoryDetails(item.category, item.amount, 'period1')}
							>
								<span class="legend-color" style="background-color: {item.color}"></span>
								<span class="legend-label">{item.category}</span>
								<span class="legend-value">{formatAmount(item.amount)}</span>
								<span class="legend-percentage">({item.percentage.toFixed(1)}%)</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="no-data">
						<p>No expenses for this period</p>
					</div>
				{/if}
			</div>

			<!-- Custom Period 2 -->
			<div class="chart-section">
				<h3>Period 2: {formatPeriodLabel(period2StartDate, period2EndDate)}</h3>
				<div class="total-section">
					<div class="total-label">Total Amount:</div>
					<div class="total-amount">{formatAmount(period2ExpensesByCategory.reduce((sum, item) => sum + item.amount, 0))}</div>
				</div>
				{#if period2ExpensesByCategory.length > 0}
					<div class="legend">
						{#each period2ExpensesByCategory as item}
							<div 
								class="legend-item" 
								class:zero-amount={item.amount === 0}
								class:clickable={item.amount > 0}
								on:click={() => showCategoryDetails(item.category, item.amount, 'period2')}
							>
								<span class="legend-color" style="background-color: {item.color}"></span>
								<span class="legend-label">{item.category}</span>
								<span class="legend-value">{formatAmount(item.amount)}</span>
								<span class="legend-percentage">({item.percentage.toFixed(1)}%)</span>
							</div>
						{/each}
					</div>
				{:else}
					<div class="no-data">
						<p>No expenses for this period</p>
					</div>
				{/if}
			</div>
			{/if}
		</div>
	{/if}
</div>

<!-- Custom Period Modal -->
{#if showCustomPeriodModal}
	<div class="modal-overlay" on:click={closeCustomPeriodModal}>
		<div class="modal-content custom-period-modal" on:click|stopPropagation>
			<div class="modal-header">
				<h3>📅 Select Custom Periods</h3>
				<button class="close-btn" on:click={closeCustomPeriodModal}>✕</button>
			</div>
			<div class="modal-body">
				<div class="period-form">
					<div class="period-group">
						<h4>Period 1</h4>
						<div class="date-row">
							<div class="form-field">
								<label for="period1-start">Start Date</label>
								<input 
									type="date" 
									id="period1-start"
									bind:value={period1StartDate}
								/>
							</div>
							<div class="form-field">
								<label for="period1-end">End Date</label>
								<input 
									type="date" 
									id="period1-end"
									bind:value={period1EndDate}
								/>
							</div>
						</div>
					</div>

					<div class="period-group">
						<h4>Period 2</h4>
						<div class="date-row">
							<div class="form-field">
								<label for="period2-start">Start Date</label>
								<input 
									type="date" 
									id="period2-start"
									bind:value={period2StartDate}
								/>
							</div>
							<div class="form-field">
								<label for="period2-end">End Date</label>
								<input 
									type="date" 
									id="period2-end"
									bind:value={period2EndDate}
								/>
							</div>
						</div>
					</div>
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeCustomPeriodModal}>Cancel</button>
				<button class="apply-btn" on:click={applyCustomPeriods}>Apply</button>
			</div>
		</div>
	</div>
{/if}

<!-- Details Modal -->
{#if showDetailsModal}
	<div class="modal-overlay" on:click={closeModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>📊 {selectedCategory} - Expense Details</h3>
				<button class="close-btn" on:click={closeModal}>✕</button>
			</div>
			<div class="modal-body">
				{#if categoryDetails.length > 0}
					<div class="table-wrapper">
						<table class="details-table">
							<thead>
								<tr>
									<th>Bill #</th>
									<th>Branch</th>
									<th>Date</th>
									<th>Due Date</th>
									<th>Amount</th>
									<th>Payment Method</th>
									<th>Status</th>
									<th>Description</th>
								</tr>
							</thead>
							<tbody>
								{#each categoryDetails as detail}
									<tr>
										<td class="bill-number">{detail.bill_number || '-'}</td>
										<td>{detail.branches?.name_en || '-'}</td>
										<td>{formatDate(detail.bill_date || detail.created_at)}</td>
										<td>{formatDate(detail.due_date)}</td>
										<td class="amount">{formatAmount(detail.amount)}</td>
										<td>{detail.payment_method || '-'}</td>
										<td>
											<span class="status-badge" class:paid={detail.is_paid}>
												{detail.is_paid ? '✓ Paid' : '✗ Unpaid'}
											</span>
										</td>
										<td class="description">{detail.description || '-'}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
					<div class="modal-footer">
						<div class="total-summary">
							<strong>Total Expenses:</strong> 
							{formatAmount(categoryDetails.reduce((sum, d) => sum + Number(d.amount || 0), 0))}
							<span class="count">({categoryDetails.length} transaction{categoryDetails.length !== 1 ? 's' : ''})</span>
						</div>
					</div>
				{:else}
					<div class="no-data">
						<p>No expenses found for this category</p>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.comparison-window {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f8f9fa;
		overflow: auto;
	}

	.header {
		padding: 20px;
		background: white;
		border-bottom: 2px solid #e9ecef;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.header h2 {
		margin: 0;
		font-size: 24px;
		color: #333;
		font-weight: 600;
	}

	.header-controls {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.branch-filter {
		padding: 10px 16px;
		background: white;
		border: 2px solid #667eea;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		color: #333;
		cursor: pointer;
		transition: all 0.2s;
		min-width: 180px;
	}

	.branch-filter:hover {
		border-color: #5568d3;
		box-shadow: 0 2px 4px rgba(102, 126, 234, 0.2);
	}

	.branch-filter:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.custom-period-btn {
		padding: 10px 20px;
		background: #667eea;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 600;
		transition: all 0.2s;
		box-shadow: 0 2px 4px rgba(102, 126, 234, 0.2);
	}

	.custom-period-btn:hover {
		background: #5568d3;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(102, 126, 234, 0.3);
	}

	.charts-container {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
		gap: 20px;
		padding: 20px;
	}

	.chart-section {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.chart-section h3 {
		margin: 0 0 20px 0;
		font-size: 18px;
		font-weight: 600;
		color: #333;
		text-align: center;
	}

	.total-section {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		padding: 16px 20px;
		border-radius: 8px;
		margin-bottom: 20px;
		text-align: center;
		box-shadow: 0 4px 6px rgba(102, 126, 234, 0.2);
	}

	.total-label {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-bottom: 6px;
	}

	.total-amount {
		font-size: 24px;
		font-weight: 700;
		color: white;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.legend {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.legend-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px;
		border-radius: 6px;
		transition: background 0.2s;
	}

	.legend-item:hover {
		background: #f8f9fa;
	}

	.legend-item.zero-amount {
		opacity: 0.4;
	}

	.legend-item.clickable {
		cursor: pointer;
		transition: all 0.2s;
	}

	.legend-item.clickable:hover {
		background: #e3f2fd;
		transform: translateX(4px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.legend-color {
		width: 16px;
		height: 16px;
		border-radius: 3px;
		flex-shrink: 0;
	}

	.legend-label {
		flex: 1;
		font-size: 14px;
		color: #333;
		font-weight: 500;
	}

	.legend-value {
		font-size: 14px;
		font-weight: 600;
		color: #333;
	}

	.legend-percentage {
		font-size: 12px;
		color: #666;
		margin-left: 4px;
	}

	.no-data {
		text-align: center;
		padding: 40px 20px;
		color: #666;
	}

	.no-data p {
		margin: 0;
		font-size: 16px;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 60px 20px;
		color: #666;
	}

	.spinner {
		font-size: 48px;
		animation: spin 2s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	.error-message {
		text-align: center;
		padding: 40px 20px;
		color: #dc3545;
	}

	.error-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.error-message p {
		margin: 8px 0 16px 0;
		font-size: 16px;
	}

	.retry-btn {
		padding: 10px 20px;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		transition: background 0.2s;
	}

	.retry-btn:hover {
		background: #0056b3;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		justify-content: center;
		align-items: center;
		z-index: 1000;
		padding: 20px;
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		width: 90%;
		max-width: 1200px;
		max-height: 85vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 24px;
		border-bottom: 2px solid #e9ecef;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 20px;
		color: #333;
		font-weight: 600;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 28px;
		cursor: pointer;
		color: #999;
		padding: 0;
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: #f8f9fa;
		color: #333;
	}

	.modal-body {
		flex: 1;
		overflow: auto;
		padding: 24px;
	}

	.table-wrapper {
		overflow-x: auto;
		border: 1px solid #dee2e6;
		border-radius: 8px;
	}

	.details-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
	}

	.details-table thead {
		background: #f8f9fa;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.details-table th {
		padding: 12px;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 2px solid #dee2e6;
		white-space: nowrap;
	}

	.details-table td {
		padding: 12px;
		border-bottom: 1px solid #dee2e6;
	}

	.details-table tbody tr:hover {
		background: #f8f9fa;
	}

	.details-table tbody tr:last-child td {
		border-bottom: none;
	}

	.bill-number {
		font-weight: 600;
		color: #007bff;
	}

	.amount {
		font-weight: 600;
		color: #333;
		white-space: nowrap;
	}

	.status-badge {
		display: inline-block;
		padding: 4px 10px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		background: #f8d7da;
		color: #721c24;
	}

	.status-badge.paid {
		background: #d4edda;
		color: #155724;
	}

	.description {
		max-width: 250px;
		word-wrap: break-word;
		white-space: normal;
	}

	.modal-footer {
		padding: 20px 24px;
		border-top: 2px solid #e9ecef;
		background: #f8f9fa;
		border-bottom-left-radius: 12px;
		border-bottom-right-radius: 12px;
	}

	.total-summary {
		font-size: 16px;
		color: #333;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.total-summary .count {
		color: #666;
		font-size: 14px;
		font-weight: normal;
	}

	/* Custom Period Modal Styles */
	.custom-period-modal {
		max-width: 600px;
	}

	.period-form {
		display: flex;
		flex-direction: column;
		gap: 24px;
	}

	.period-group {
		background: #f8f9fa;
		padding: 20px;
		border-radius: 8px;
	}

	.period-group h4 {
		margin: 0 0 16px 0;
		font-size: 16px;
		font-weight: 600;
		color: #333;
	}

	.date-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
	}

	.form-field {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.form-field label {
		font-size: 14px;
		font-weight: 500;
		color: #555;
	}

	.form-field input[type="date"] {
		padding: 10px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
		font-family: inherit;
		transition: border-color 0.2s;
	}

	.form-field input[type="date"]:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
	}

	.cancel-btn {
		padding: 10px 20px;
		background: #6c757d;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		transition: background 0.2s;
	}

	.cancel-btn:hover {
		background: #5a6268;
	}

	.apply-btn {
		padding: 10px 20px;
		background: #667eea;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 600;
		transition: background 0.2s;
	}

	.apply-btn:hover {
		background: #5568d3;
	}
</style>
