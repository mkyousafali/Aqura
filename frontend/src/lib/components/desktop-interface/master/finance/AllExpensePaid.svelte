<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import * as XLSX from 'xlsx';

	// Data
	let allExpensePaidData = [];
	let branches = [];
	let branchMap = {};
	let isLoading = false;
	let loadingProgress = 0;
	let totalCount = 0;

	// Search
	let searchQuery = '';
	let selectedBranch = '';
	let erpFilter = 'all'; // 'all', 'available', 'not-available'

	// Filtered data based on search, branch and ERP filter
	$: filteredData = allExpensePaidData.filter(p => {
		// Search filter
		if (searchQuery.trim()) {
			const query = searchQuery.toLowerCase();
			const matchesSearch = 
				(p.expense_category_name_en && p.expense_category_name_en.toLowerCase().includes(query)) ||
				(p.expense_category_name_ar && p.expense_category_name_ar.toLowerCase().includes(query)) ||
				(p.description && p.description.toLowerCase().includes(query));
			if (!matchesSearch) return false;
		}
		// Branch filter
		if (selectedBranch && p.branch_id !== selectedBranch) return false;
		// ERP Reference filter
		if (erpFilter === 'available' && !p.payment_reference) return false;
		if (erpFilter === 'not-available' && p.payment_reference) return false;
		return true;
	});

	// Pagination
	const pageSize = 500;
	let currentPage = 0;
	let hasMoreData = true;

	// Helper to format currency
	function formatCurrency(amount) {
		if (amount === null || amount === undefined || isNaN(amount)) return '0.00';
		return Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
	}

	// Helper to format date as dd/mm/yyyy
	function formatDate(dateInput) {
		if (!dateInput) return 'N/A';
		try {
			const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
			if (isNaN(date.getTime())) return 'N/A';
			const day = String(date.getDate()).padStart(2, '0');
			const month = String(date.getMonth() + 1).padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return 'N/A';
		}
	}

	// Get branch name
	function getBranchName(branchId) {
		if (!branchId) return 'N/A';
		return branchMap[branchId] || 'N/A';
	}

	// Load branches
	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en', { ascending: true })
				.limit(5000);

			if (error) {
				console.error('Error loading branches:', error);
				return;
			}

			branches = data || [];
			branchMap = {};
			branches.forEach(branch => {
				const display = branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en;
				branchMap[branch.id] = display;
			});
		} catch (error) {
			console.error('Error loading branches:', error);
		}
	}

	// Load all expense paid data with pagination
	async function loadAllExpensePaid() {
		isLoading = true;
		loadingProgress = 0;
		allExpensePaidData = [];
		currentPage = 0;
		hasMoreData = true;

		try {
			// First get total count
			const { count: totalRecords } = await supabase
				.from('expense_scheduler')
				.select('id', { count: 'exact', head: true })
				.eq('is_paid', true);

			totalCount = totalRecords || 0;

			while (hasMoreData) {
				const from = currentPage * pageSize;
				const to = from + pageSize - 1;

				const { data, error } = await supabase
					.from('expense_scheduler')
					.select('id, expense_category_name_en, expense_category_name_ar, branch_id, payment_method, amount, paid_date, due_date, description, payment_reference')
					.eq('is_paid', true)
					.order('paid_date', { ascending: false })
					.range(from, to);

				if (error) {
					console.error('Error loading expense paid:', error);
					break;
				}

				if (data && data.length > 0) {
					allExpensePaidData = [...allExpensePaidData, ...data];
					currentPage++;
					loadingProgress = Math.min(95, Math.round((allExpensePaidData.length / totalCount) * 100));

					if (data.length < pageSize) {
						hasMoreData = false;
					}
				} else {
					hasMoreData = false;
				}
			}
			loadingProgress = 100;
			console.log('✅ Loaded all expense paid:', allExpensePaidData.length, 'records');
		} catch (error) {
			console.error('Error loading expense paid:', error);
		} finally {
			isLoading = false;
		}
	}

	// Export filtered data to Excel
	function exportToExcel() {
		try {
			const excelData = filteredData.map(payment => ({
				'Voucher #': payment.id,
				'Sub-Category': payment.expense_category_name_en || payment.expense_category_name_ar || 'N/A',
				'Branch': getBranchName(payment.branch_id),
				'Payment Method': payment.payment_method || 'N/A',
				'Amount': payment.amount || 0,
				'Paid Date': formatDate(payment.paid_date || payment.due_date),
				'Description': payment.description || 'N/A',
				'ERP Reference': payment.payment_reference || 'N/A'
			}));

			const worksheet = XLSX.utils.json_to_sheet(excelData);
			const workbook = XLSX.utils.book_new();
			XLSX.utils.book_append_sheet(workbook, worksheet, 'Expense Paid');

			// Set column widths
			worksheet['!cols'] = [
				{ wch: 12 }, // Voucher #
				{ wch: 25 }, // Sub-Category
				{ wch: 25 }, // Branch
				{ wch: 15 }, // Payment Method
				{ wch: 15 }, // Amount
				{ wch: 12 }, // Paid Date
				{ wch: 30 }, // Description
				{ wch: 20 }  // ERP Reference
			];

			const now = new Date();
			const dateStr = now.toISOString().split('T')[0];
			const filename = `Expense_Paid_${dateStr}.xlsx`;
			XLSX.writeFile(workbook, filename);
		} catch (err) {
			console.error('Error exporting to Excel:', err);
			alert('Failed to export to Excel');
		}
	}

	onMount(async () => {
		await loadBranches();
		await loadAllExpensePaid();
	});
</script>

<div class="all-expense-paid-container">
	{#if isLoading}
		<div class="loading-section">
			<div class="loading-spinner"></div>
			<div class="loading-text">Loading all expense paid records...</div>
			<div class="progress-bar">
				<div class="progress-fill" style="width: {loadingProgress}%"></div>
			</div>
			<div class="progress-text">{allExpensePaidData.length} of {totalCount} records ({loadingProgress}%)</div>
		</div>
	{:else}
		<div class="header-section">
			<h2>💳 All Expense Paid Transactions</h2>
			<div class="stats">
				<span class="stat-badge">{filteredData.length} / {allExpensePaidData.length} Records</span>
				<button class="export-btn" on:click={exportToExcel}>📄 Export</button>
				<button class="refresh-btn" on:click={loadAllExpensePaid}>🔄 Refresh</button>
			</div>
		</div>

		<div class="search-section">
			<div class="filters-row">
				<div class="search-input-wrapper">
					<span class="search-icon">🔍</span>
					<input
						type="text"
						placeholder="Search by Category or Description..."
						bind:value={searchQuery}
						class="search-input"
					/>
					{#if searchQuery}
						<button class="clear-search" on:click={() => searchQuery = ''}>✕</button>
					{/if}
				</div>
				<select bind:value={selectedBranch} class="filter-select">
					<option value="">All Branches</option>
					{#each branches as branch}
						<option value={branch.id}>{branch.name_en}{branch.location_en ? ` - ${branch.location_en}` : ''}</option>
					{/each}
				</select>
				<select bind:value={erpFilter} class="filter-select erp-filter">
					<option value="all">All ERP Status</option>
					<option value="available">ERP Available</option>
					<option value="not-available">ERP Not Available</option>
				</select>
			</div>
		</div>

		<div class="table-wrapper">
			<div class="table-header">
				<table class="data-table">
					<thead>
						<tr>
							<th>Voucher #</th>
							<th>Sub-Category</th>
							<th>Branch</th>
							<th>Payment Method</th>
							<th>Amount</th>
							<th>Paid Date</th>
							<th>Description</th>
							<th>ERP Reference</th>
						</tr>
					</thead>
				</table>
			</div>
			<div class="table-body">
				<table class="data-table">
					<tbody>
						{#each filteredData as payment}
							<tr>
								<td><span class="bill-badge">#{payment.id}</span></td>
								<td class="category-name">{payment.expense_category_name_en || payment.expense_category_name_ar || 'N/A'}</td>
								<td>{getBranchName(payment.branch_id)}</td>
								<td><span class="method-badge">{payment.payment_method || 'N/A'}</span></td>
								<td class="amount-cell">{formatCurrency(payment.amount)}</td>
								<td class="date-cell">{formatDate(payment.paid_date || payment.due_date)}</td>
								<td class="description-cell" title={payment.description || ''}>{payment.description || 'N/A'}</td>
								<td class="erp-ref">{payment.payment_reference || 'N/A'}</td>
							</tr>
						{:else}
							<tr>
								<td colspan="8" class="empty-row">No expense paid records found</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{/if}
</div>

<style>
	.all-expense-paid-container {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f8fafc;
		overflow: hidden;
	}

	.loading-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 20px;
		padding: 80px;
	}

	.loading-spinner {
		width: 60px;
		height: 60px;
		border: 6px solid #e2e8f0;
		border-top-color: #8b5cf6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.loading-text {
		font-size: 18px;
		color: #475569;
		font-weight: 600;
	}

	.progress-bar {
		width: 400px;
		height: 10px;
		background: #e2e8f0;
		border-radius: 10px;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #8b5cf6 0%, #a855f7 100%);
		transition: width 0.3s ease;
		border-radius: 10px;
	}

	.progress-text {
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
	}

	.header-section {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px 24px;
		background: white;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		flex-shrink: 0;
	}

	.header-section h2 {
		margin: 0;
		font-size: 22px;
		font-weight: 700;
		color: #1e293b;
	}

	.stats {
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.stat-badge {
		padding: 8px 16px;
		background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%);
		color: white;
		border-radius: 20px;
		font-weight: 600;
		font-size: 14px;
	}

	/* Search Section */
	.search-section {
		padding: 12px 24px;
		background: white;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		flex-shrink: 0;
	}

	.search-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
	}

	.search-icon {
		position: absolute;
		left: 14px;
		font-size: 18px;
		color: #94a3b8;
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 12px 40px 12px 44px;
		border: 2px solid #e2e8f0;
		border-radius: 10px;
		font-size: 15px;
		color: #1e293b;
		outline: none;
		transition: all 0.2s;
	}

	.search-input:focus {
		border-color: #8b5cf6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.search-input::placeholder {
		color: #94a3b8;
	}

	.clear-search {
		position: absolute;
		right: 12px;
		background: #e2e8f0;
		border: none;
		color: #64748b;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		font-size: 12px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
	}

	.clear-search:hover {
		background: #cbd5e1;
		color: #1e293b;
	}

	.filters-row {
		display: flex;
		gap: 12px;
		align-items: center;
		flex-wrap: wrap;
	}

	.filter-select {
		padding: 10px 14px;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 14px;
		color: #1e293b;
		background: white;
		cursor: pointer;
		min-width: 160px;
		outline: none;
		transition: all 0.2s;
	}

	.filter-select:focus {
		border-color: #8b5cf6;
		box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
	}

	.erp-filter {
		min-width: 180px;
	}

	.export-btn {
		padding: 8px 16px;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.export-btn:hover {
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		transform: translateY(-1px);
	}

	.refresh-btn {
		padding: 8px 16px;
		background: #e2e8f0;
		color: #475569;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.refresh-btn:hover {
		background: #cbd5e1;
	}

	.table-wrapper {
		flex: 1;
		display: flex;
		flex-direction: column;
		margin: 16px 24px;
		border-radius: 12px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		overflow: hidden;
		background: white;
	}

	.table-header {
		flex-shrink: 0;
		background: #6d28d9;
	}

	.table-body {
		flex: 1;
		overflow-y: auto;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
		table-layout: fixed;
	}

	.data-table th {
		padding: 14px 12px;
		text-align: left;
		font-weight: 600;
		color: white;
		white-space: nowrap;
		background: #6d28d9;
	}

	.data-table td {
		padding: 12px;
		border-bottom: 1px solid #f1f5f9;
		color: #1e293b;
	}

	.data-table tbody tr:hover {
		background: #f8fafc;
	}

	.bill-badge {
		background: #f3e8ff;
		color: #7c3aed;
		padding: 4px 10px;
		border-radius: 6px;
		font-weight: 600;
		font-size: 12px;
	}

	.category-name {
		font-weight: 500;
	}

	.amount-cell {
		text-align: right;
		font-weight: 600;
		color: #059669;
	}

	.date-cell {
		color: #059669;
		font-weight: 500;
	}

	.method-badge {
		background: #fee2e2;
		color: #991b1b;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
	}

	.description-cell {
		max-width: 200px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.erp-ref {
		color: #64748b;
	}

	.empty-row {
		text-align: center;
		padding: 60px !important;
		color: #94a3b8;
		font-style: italic;
		font-size: 16px;
	}
</style>
