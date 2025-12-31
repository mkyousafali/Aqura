<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	// Date range filters
	let startDate = '';
	let endDate = '';
	
	// Data arrays
	let paidTransactions = [];
	let filteredTransactions = [];
	let branches = [];
	let categories = [];
	
	// Filters
	let selectedBranchId = '';
	let selectedCategoryId = '';
	let searchQuery = '';
	let selectedSection = 'all'; // 'all', 'vendor', 'other_payments'
	
	// Summary stats
	let totalPaidAmount = 0;
	let vendorPaidAmount = 0;
	let otherPaymentsPaidAmount = 0;
	let transactionCount = 0;
	
	// Loading state
	let loading = false;

	onMount(async () => {
		// Set default date range (current month)
		const now = new Date();
		const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
		const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
		
		startDate = firstDay.toISOString().split('T')[0];
		endDate = lastDay.toISOString().split('T')[0];
		
		await loadInitialData();
		await loadPaidTransactions();
	});

	async function loadInitialData() {
		try {
			// Load branches
			const { data: branchesData, error: branchesError } = await supabase
				.from('branches')
				.select('*')
				.eq('is_active', true)
				.order('name_en');

			if (branchesError) throw branchesError;
			branches = branchesData || [];

			// Load categories
			const { data: categoriesData, error: categoriesError } = await supabase
				.from('expense_sub_categories')
				.select(`
					*,
					parent_category:expense_parent_categories(
						id,
						name_en,
						name_ar
					)
				`)
				.eq('is_active', true)
				.order('name_en');

			if (categoriesError) throw categoriesError;
			categories = categoriesData || [];

		} catch (error) {
			console.error('Error loading initial data:', error);
		}
	}

	async function loadPaidTransactions() {
		if (!startDate || !endDate) {
			alert('Please select both start and end dates');
			return;
		}

		loading = true;
		try {
			// Load paid transactions from expense_scheduler
			let query = supabase
				.from('expense_scheduler')
				.select(`
					*,
					branches(name_en, name_ar),
					expense_sub_categories(
						name_en,
						name_ar,
						parent_category:expense_parent_categories(name_en, name_ar)
					),
					expense_requisitions(requisition_number)
				`)
				.eq('is_paid', true)
				.gte('paid_date', startDate)
				.lte('paid_date', endDate)
				.order('paid_date', { ascending: false });

			// Apply branch filter
			if (selectedBranchId) {
				query = query.eq('branch_id', parseInt(selectedBranchId));
			}

			// Apply category filter
			if (selectedCategoryId) {
				query = query.eq('expense_category_id', parseInt(selectedCategoryId));
			}

			const { data, error } = await query;

			if (error) throw error;

			// Map and enrich data
			paidTransactions = (data || []).map(txn => ({
				...txn,
				branch_name: txn.branches?.name_en || txn.branch_name || 'N/A',
				category_name: txn.expense_sub_categories?.name_en || txn.expense_category_name_en || 'N/A',
				parent_category_name: txn.expense_sub_categories?.parent_category?.name_en || 'N/A',
				requisition_number: txn.expense_requisitions?.requisition_number || txn.requisition_number || 'N/A',
				section: determineSection(txn.schedule_type),
				amount_display: parseFloat(txn.amount || 0).toFixed(2)
			}));

			applyFilters();
			calculateSummary();

		} catch (error) {
			console.error('Error loading paid transactions:', error);
			alert('Failed to load paid transactions. Please try again.');
		} finally {
			loading = false;
		}
	}

	function determineSection(scheduleType) {
		// Vendor section: stock purchases, vendor bills
		if (scheduleType?.includes('stock_purchase') || scheduleType?.includes('vendor')) {
			return 'vendor';
		}
		// Other payments: everything else (requisitions, other bills, etc.)
		return 'other_payments';
	}

	function applyFilters() {
		let filtered = [...paidTransactions];

		// Section filter
		if (selectedSection !== 'all') {
			filtered = filtered.filter(txn => txn.section === selectedSection);
		}

		// Search filter
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase();
			filtered = filtered.filter(txn =>
				txn.requisition_number?.toLowerCase().includes(query) ||
				txn.bill_number?.toLowerCase().includes(query) ||
				txn.description?.toLowerCase().includes(query) ||
				txn.branch_name?.toLowerCase().includes(query) ||
				txn.category_name?.toLowerCase().includes(query) ||
				txn.co_user_name?.toLowerCase().includes(query)
			);
		}

		filteredTransactions = filtered;
		calculateSummary();
	}

	function calculateSummary() {
		totalPaidAmount = filteredTransactions.reduce((sum, txn) => sum + parseFloat(txn.amount || 0), 0);
		vendorPaidAmount = filteredTransactions
			.filter(txn => txn.section === 'vendor')
			.reduce((sum, txn) => sum + parseFloat(txn.amount || 0), 0);
		otherPaymentsPaidAmount = filteredTransactions
			.filter(txn => txn.section === 'other_payments')
			.reduce((sum, txn) => sum + parseFloat(txn.amount || 0), 0);
		transactionCount = filteredTransactions.length;
	}

	function handleSearch() {
		applyFilters();
	}

	function handleSectionChange() {
		applyFilters();
	}

	function resetFilters() {
		selectedBranchId = '';
		selectedCategoryId = '';
		searchQuery = '';
		selectedSection = 'all';
		
		// Reset to current month
		const now = new Date();
		const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
		const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
		
		startDate = firstDay.toISOString().split('T')[0];
		endDate = lastDay.toISOString().split('T')[0];
		
		loadPaidTransactions();
	}

	function exportToCSV() {
		if (filteredTransactions.length === 0) {
			alert('No transactions to export');
			return;
		}

		// Prepare CSV data
		const headers = [
			'Paid Date',
			'Section',
			'Branch',
			'Requisition Number',
			'Bill Number',
			'Category',
			'Parent Category',
			'Payment Method',
			'Amount (SAR)',
			'CO User',
			'Description'
		];

		const rows = filteredTransactions.map(txn => [
			txn.paid_date || '',
			txn.section === 'vendor' ? 'Vendor' : 'Other Payments',
			txn.branch_name || '',
			txn.requisition_number || '',
			txn.bill_number || '',
			txn.category_name || '',
			txn.parent_category_name || '',
			txn.payment_method || '',
			txn.amount_display || '0.00',
			txn.co_user_name || '',
			txn.description || ''
		]);

		const csvContent = [
			headers.join(','),
			...rows.map(row => row.map(cell => `"${cell}"`).join(','))
		].join('\n');

		// Download CSV
		const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
		const link = document.createElement('a');
		link.href = URL.createObjectURL(blob);
		link.download = `monthly_paid_transactions_${startDate}_to_${endDate}.csv`;
		link.click();
	}
</script>

<div class="monthly-paid-manager-container">
	<div class="header">
		<h1>💰 Monthly Paid Manager</h1>
		<p class="subtitle">View all paid transactions from vendor and other payment sections</p>
	</div>

	<!-- Filters Section -->
	<div class="filters-section">
		<div class="date-range">
			<div class="filter-group">
				<label for="startDate">Start Date:</label>
				<input
					type="date"
					id="startDate"
					bind:value={startDate}
					on:change={loadPaidTransactions}
				/>
			</div>
			<div class="filter-group">
				<label for="endDate">End Date:</label>
				<input
					type="date"
					id="endDate"
					bind:value={endDate}
					on:change={loadPaidTransactions}
				/>
			</div>
		</div>

		<div class="filter-row">
			<div class="filter-group">
				<label for="branchFilter">Branch:</label>
				<select id="branchFilter" bind:value={selectedBranchId} on:change={loadPaidTransactions}>
					<option value="">All Branches</option>
					{#each branches as branch}
						<option value={branch.id}>{branch.name_en}</option>
					{/each}
				</select>
			</div>

			<div class="filter-group">
				<label for="categoryFilter">Category:</label>
				<select id="categoryFilter" bind:value={selectedCategoryId} on:change={loadPaidTransactions}>
					<option value="">All Categories</option>
					{#each categories as category}
						<option value={category.id}>
							{category.parent_category?.name_en || ''} - {category.name_en}
						</option>
					{/each}
				</select>
			</div>

			<div class="filter-group">
				<label for="sectionFilter">Section:</label>
				<select id="sectionFilter" bind:value={selectedSection} on:change={handleSectionChange}>
					<option value="all">All Sections</option>
					<option value="vendor">Vendor Section</option>
					<option value="other_payments">Other Payments Section</option>
				</select>
			</div>
		</div>

		<div class="search-row">
			<div class="filter-group search-group">
				<label for="search">Search:</label>
				<input
					type="text"
					id="search"
					bind:value={searchQuery}
					on:input={handleSearch}
					placeholder="Search by requisition, bill number, description..."
				/>
			</div>

			<button class="btn-secondary" on:click={resetFilters}>
				🔄 Reset Filters
			</button>

			<button class="btn-primary" on:click={exportToCSV} disabled={filteredTransactions.length === 0}>
				📥 Export CSV
			</button>
		</div>
	</div>

	<!-- Summary Stats -->
	<div class="summary-section">
		<div class="stat-card total">
			<div class="stat-label">Total Paid</div>
			<div class="stat-value">{totalPaidAmount.toFixed(2)} SAR</div>
			<div class="stat-count">{transactionCount} transactions</div>
		</div>
		<div class="stat-card vendor">
			<div class="stat-label">Vendor Section</div>
			<div class="stat-value">{vendorPaidAmount.toFixed(2)} SAR</div>
		</div>
		<div class="stat-card other">
			<div class="stat-label">Other Payments Section</div>
			<div class="stat-value">{otherPaymentsPaidAmount.toFixed(2)} SAR</div>
		</div>
	</div>

	<!-- Loading State -->
	{#if loading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading paid transactions...</p>
		</div>
	{/if}

	<!-- Transactions Table -->
	{#if !loading && filteredTransactions.length > 0}
		<div class="transactions-section">
			<h2>Paid Transactions ({filteredTransactions.length})</h2>
			<div class="table-container">
				<table class="transactions-table">
					<thead>
						<tr>
							<th>Paid Date</th>
							<th>Section</th>
							<th>Branch</th>
							<th>Req. Number</th>
							<th>Bill Number</th>
							<th>Category</th>
							<th>Payment Method</th>
							<th>Amount (SAR)</th>
							<th>CO User</th>
							<th>Description</th>
						</tr>
					</thead>
					<tbody>
						{#each filteredTransactions as txn}
							<tr class="section-{txn.section}">
								<td>{txn.paid_date ? new Date(txn.paid_date).toLocaleDateString() : 'N/A'}</td>
								<td>
									<span class="section-badge {txn.section}">
										{txn.section === 'vendor' ? '📦 Vendor' : '💳 Other Payments'}
									</span>
								</td>
								<td>{txn.branch_name}</td>
								<td>{txn.requisition_number}</td>
								<td>{txn.bill_number || 'N/A'}</td>
								<td>
									<div class="category-cell">
										<div class="parent-category">{txn.parent_category_name}</div>
										<div class="sub-category">{txn.category_name}</div>
									</div>
								</td>
								<td>{txn.payment_method || 'N/A'}</td>
								<td class="amount-cell">{txn.amount_display}</td>
								<td>{txn.co_user_name || 'N/A'}</td>
								<td class="description-cell">{txn.description || '-'}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{/if}

	<!-- No Results State -->
	{#if !loading && filteredTransactions.length === 0 && paidTransactions.length > 0}
		<div class="no-results">
			<p>No transactions found matching your filters.</p>
		</div>
	{/if}

	{#if !loading && paidTransactions.length === 0}
		<div class="no-results">
			<p>No paid transactions found for the selected date range.</p>
		</div>
	{/if}
</div>

<style>
	.monthly-paid-manager-container {
		padding: 2rem;
		background: #f9fafb;
		min-height: 100vh;
	}

	.header {
		margin-bottom: 2rem;
	}

	.header h1 {
		font-size: 2rem;
		font-weight: 700;
		color: #1f2937;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #6b7280;
		font-size: 1rem;
	}

	.filters-section {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 2rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.date-range,
	.filter-row,
	.search-row {
		display: flex;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.search-row {
		margin-bottom: 0;
	}

	.filter-group {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.search-group {
		flex: 2;
	}

	.filter-group label {
		font-weight: 600;
		color: #374151;
		font-size: 0.875rem;
	}

	.filter-group input,
	.filter-group select {
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 0.875rem;
		transition: all 0.2s;
	}

	.filter-group input:focus,
	.filter-group select:focus {
		outline: none;
		border-color: #4f46e5;
		box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
	}

	.btn-primary,
	.btn-secondary {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
		align-self: flex-end;
	}

	.btn-primary {
		background: #4f46e5;
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		background: #4338ca;
	}

	.btn-primary:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		opacity: 0.5;
	}

	.btn-secondary {
		background: #6b7280;
		color: white;
	}

	.btn-secondary:hover {
		background: #4b5563;
	}

	.summary-section {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.stat-card {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		border-left: 4px solid;
	}

	.stat-card.total {
		border-left-color: #4f46e5;
	}

	.stat-card.vendor {
		border-left-color: #10b981;
	}

	.stat-card.other {
		border-left-color: #f59e0b;
	}

	.stat-label {
		font-size: 0.875rem;
		color: #6b7280;
		font-weight: 500;
		margin-bottom: 0.5rem;
	}

	.stat-value {
		font-size: 1.75rem;
		font-weight: 700;
		color: #1f2937;
		margin-bottom: 0.25rem;
	}

	.stat-count {
		font-size: 0.75rem;
		color: #9ca3af;
	}

	.loading-state {
		text-align: center;
		padding: 4rem 2rem;
		background: white;
		border-radius: 12px;
	}

	.spinner {
		width: 50px;
		height: 50px;
		border: 4px solid #e5e7eb;
		border-top-color: #4f46e5;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 1rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.transactions-section {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.transactions-section h2 {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1f2937;
		margin-bottom: 1.5rem;
	}

	.table-container {
		overflow-x: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.transactions-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
		min-width: 1200px;
	}

	.transactions-table thead {
		background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
		position: sticky;
		top: 0;
		z-index: 1;
	}

	.transactions-table thead th {
		padding: 1rem 0.75rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #d1d5db;
		font-size: 0.875rem;
		white-space: nowrap;
	}

	.transactions-table tbody tr {
		border-bottom: 1px solid #f3f4f6;
		transition: background-color 0.2s;
	}

	.transactions-table tbody tr:hover {
		background: #f9fafb;
	}

	.transactions-table tbody tr.section-vendor {
		border-left: 3px solid #10b981;
	}

	.transactions-table tbody tr.section-other_payments {
		border-left: 3px solid #f59e0b;
	}

	.transactions-table tbody td {
		padding: 1rem 0.75rem;
		color: #1f2937;
		font-size: 0.875rem;
	}

	.section-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.section-badge.vendor {
		background: #d1fae5;
		color: #065f46;
	}

	.section-badge.other_payments {
		background: #fef3c7;
		color: #92400e;
	}

	.category-cell {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.parent-category {
		font-size: 0.75rem;
		color: #6b7280;
		font-weight: 500;
	}

	.sub-category {
		font-size: 0.875rem;
		color: #1f2937;
	}

	.amount-cell {
		font-weight: 600;
		color: #059669;
		text-align: right;
	}

	.description-cell {
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.no-results {
		text-align: center;
		padding: 4rem 2rem;
		background: white;
		border-radius: 12px;
		color: #6b7280;
	}

	.no-results p {
		font-size: 1.125rem;
	}
</style>
