<script lang="ts">
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';
	import { t } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import ExpenseComparisonWindow from '$lib/components/desktop-interface/master/finance/reports/ExpenseComparisonWindow.svelte';

	let expenses: any[] = [];
	let filteredExpenses: any[] = [];
	let loading = true;
	let error: string | null = null;
	let searchTerm = '';
	let filterBranch = '';
	let filterCategory = '';
	let filterPaymentStatus = '';
	let filterBillType = '';
	let filterDatePreset = '';
	let filterDateFrom = '';
	let filterDateTo = '';
	
	let branches: Array<{id: number, name_en: string, name_ar: string}> = [];
	let categories: string[] = [];
	let subCategories: Array<{id: number, name_en: string, name_ar: string}> = [];
	let billTypes: string[] = [];

	// Edit modal state
	let showEditModal = false;
	let editingExpense: any = null;
	let editForm = {
		category: '',
		bill_type: '',
		description: '',
		due_date: ''
	};

	// Check if current user can edit
	$: canEdit = $currentUser?.role === 'Admin' || $currentUser?.role === 'Master Admin';

	async function loadSubCategories() {
		try {
			const { data, error } = await supabaseAdmin
				.from('expense_sub_categories')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			subCategories = data || [];
			console.log('✅ Loaded sub-categories:', subCategories.length);
		} catch (err: any) {
			console.error('❌ Error loading sub-categories:', err);
		}
	}

	onMount(async () => {
		await loadSubCategories();
		await loadExpenses();
	});

	async function loadExpenses() {
		loading = true;
		error = null;
		try {
			console.log('🔍 Fetching expenses from expense_scheduler...');
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

			if (fetchError) {
				console.error('❌ Supabase error:', fetchError);
				error = `Database error: ${fetchError.message}`;
				throw fetchError;
			}

		console.log('✅ Raw data received:', data);
		console.log('📊 Total records:', data?.length || 0);
		if (data && data.length > 0) {
			console.log('📝 Sample expense record:', data[0]);
			console.log('🏢 Sample branch data:', data[0]?.branches);
		}

		// Filter out zero amounts in the application layer
		expenses = (data || []).filter(exp => exp.amount && Number(exp.amount) !== 0);
			console.log('📊 After filtering zero amounts:', expenses.length);
			
		// Extract unique branches from joined data
		const uniqueBranchesMap = new Map();
		expenses.forEach(exp => {
			if (exp.branches && exp.branches.id) {
				uniqueBranchesMap.set(exp.branches.id, {
					id: exp.branches.id,
					name_en: exp.branches.name_en,
					name_ar: exp.branches.name_ar
				});
			}
		});
		branches = Array.from(uniqueBranchesMap.values()).sort((a, b) => 
			a.name_en.localeCompare(b.name_en)
		);
		
		const categoryNames = expenses.map(e => e.expense_category_name_en?.trim()).filter(Boolean);
		categories = [...new Set(categoryNames)].sort();
		
		// Extract unique bill types
		const billTypeNames = expenses.map(e => e.bill_type?.trim()).filter(Boolean);
		billTypes = [...new Set(billTypeNames)].sort();
		
		console.log('🏢 Branches found:', branches);
		console.log('📋 Categories found:', categories);
		console.log('📄 Bill types found:', billTypes);
		applyFilters();
		} catch (err: any) {
			console.error('❌ Error loading expenses:', err);
			error = err.message || 'Failed to load expenses';
			expenses = [];
		} finally {
			loading = false;
		}
	}

	function applyFilters() {
		filteredExpenses = expenses.filter(expense => {
			// Search filter
			const matchesSearch = !searchTerm || 
				expense.bill_number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				expense.description?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				expense.co_user_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				expense.expense_category_name_en?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				expense.branches?.name_en?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				expense.branch_name?.toLowerCase().includes(searchTerm.toLowerCase());

			// Branch filter
			const matchesBranch = !filterBranch || expense.branch_id === Number(filterBranch);

			// Category filter
			const matchesCategory = !filterCategory || expense.expense_category_name_en === filterCategory;

			// Bill type filter
			const matchesBillType = !filterBillType || expense.bill_type === filterBillType;

			// Payment status filter
			const matchesPaymentStatus = !filterPaymentStatus || 
				(filterPaymentStatus === 'paid' && expense.is_paid) ||
				(filterPaymentStatus === 'unpaid' && !expense.is_paid);

			// Date range filter based on due_date
			const expenseDueDate = expense.due_date || expense.bill_date;
			const matchesDateFrom = !filterDateFrom || 
				!expenseDueDate || 
				new Date(expenseDueDate) >= new Date(filterDateFrom);

			const matchesDateTo = !filterDateTo || 
				!expenseDueDate || 
				new Date(expenseDueDate) <= new Date(filterDateTo);

			return matchesSearch && matchesBranch && matchesCategory && matchesBillType &&
				   matchesPaymentStatus && matchesDateFrom && matchesDateTo;
		});
	}

	function resetFilters() {
		searchTerm = '';
		filterBranch = '';
		filterCategory = '';
		filterBillType = '';
		filterPaymentStatus = '';
		filterDatePreset = '';
		filterDateFrom = '';
		filterDateTo = '';
		applyFilters();
	}

	function handleDatePresetChange() {
		const today = new Date();
		const todayStr = today.toISOString().split('T')[0];
		
		if (filterDatePreset === 'today') {
			filterDateFrom = todayStr;
			filterDateTo = todayStr;
		} else if (filterDatePreset === 'yesterday') {
			const yesterday = new Date(today);
			yesterday.setDate(yesterday.getDate() - 1);
			const yesterdayStr = yesterday.toISOString().split('T')[0];
			filterDateFrom = yesterdayStr;
			filterDateTo = yesterdayStr;
		} else if (filterDatePreset === 'custom') {
			// Keep existing date values or clear them
			if (!filterDateFrom && !filterDateTo) {
				filterDateFrom = '';
				filterDateTo = '';
			}
		} else {
			filterDateFrom = '';
			filterDateTo = '';
		}
		applyFilters();
	}

	function formatDate(dateString: string | null) {
		if (!dateString) return '-';
		return new Date(dateString).toLocaleDateString();
	}

	function formatAmount(amount: number) {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR'
		}).format(amount);
	}

	function getStatusBadgeClass(status: string) {
		const statusMap: Record<string, string> = {
			pending: 'status-pending',
			approved: 'status-approved',
			rejected: 'status-rejected',
			paid: 'status-paid'
		};
		return statusMap[status] || 'status-default';
	}

	function openEditModal(expense: any) {
		editingExpense = expense;
		console.log('📝 Opening edit modal with expense:', expense);
		console.log('📝 Bill type from DB:', expense.bill_type);
		editForm = {
			category: expense.expense_category_name_en || '',
			bill_type: expense.bill_type || '',
			description: expense.description || '',
			due_date: expense.due_date || ''
		};
		console.log('📝 Edit form:', editForm);
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		editingExpense = null;
	}

	async function saveEdit() {
		if (!editingExpense) return;

		try {
			const { error: updateError } = await supabaseAdmin
				.from('expense_scheduler')
				.update({
					expense_category_name_en: editForm.category,
					bill_type: editForm.bill_type,
					description: editForm.description,
					due_date: editForm.due_date
				})
				.eq('id', editingExpense.id);

			if (updateError) throw updateError;

			// Refresh the data
			await loadExpenses();
			closeEditModal();
		} catch (err: any) {
			console.error('Error updating expense:', err);
			alert('Failed to update expense: ' + err.message);
		}
	}

	$: if (searchTerm !== undefined || filterBranch !== undefined || 
		   filterCategory !== undefined || filterBillType !== undefined ||
		   filterPaymentStatus !== undefined || filterDatePreset !== undefined ||
		   filterDateFrom !== undefined || filterDateTo !== undefined) {
		applyFilters();
	}

	$: if (filterDatePreset !== undefined) {
		handleDatePresetChange();
	}

	// Calculate totals
	$: totalAmount = filteredExpenses.reduce((sum, exp) => sum + Number(exp.amount || 0), 0);
	$: paidAmount = filteredExpenses
		.filter(exp => exp.is_paid)
		.reduce((sum, exp) => sum + Number(exp.amount || 0), 0);
	$: unpaidAmount = filteredExpenses
		.filter(exp => !exp.is_paid)
		.reduce((sum, exp) => sum + Number(exp.amount || 0), 0);

	function openComparisonWindow() {
		const windowId = `expense-comparison-${Date.now()}`;
		openWindow({
			id: windowId,
			title: '📊 Expense Comparison',
			component: ExpenseComparisonWindow,
			icon: '📊',
			size: { width: 1400, height: 900 },
			position: { 
				x: 100 + (Math.random() * 50),
				y: 100 + (Math.random() * 50) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}
</script>

<div class="expense-tracker">
	<div class="header">
		<h2>💰 Expense Tracker</h2>
		<div class="header-buttons">
			<button class="compare-btn" on:click={openComparisonWindow}>
				📊 Compare
			</button>
			<button class="refresh-btn" on:click={loadExpenses} disabled={loading}>
				🔄 Refresh
			</button>
		</div>
	</div>

	<!-- Summary Cards -->
	<div class="summary-cards">
		<div class="summary-card total">
			<div class="card-label">Total Expenses</div>
			<div class="card-value">{formatAmount(totalAmount)}</div>
			<div class="card-count">{filteredExpenses.length} transactions</div>
		</div>
		<div class="summary-card paid">
			<div class="card-label">Paid</div>
			<div class="card-value">{formatAmount(paidAmount)}</div>
			<div class="card-count">{filteredExpenses.filter(e => e.is_paid).length} bills</div>
		</div>
		<div class="summary-card unpaid">
			<div class="card-label">Unpaid</div>
			<div class="card-value">{formatAmount(unpaidAmount)}</div>
			<div class="card-count">{filteredExpenses.filter(e => !e.is_paid).length} bills</div>
		</div>
	</div>

	<!-- Filters Section -->
	<div class="filters-section">
		<div class="filters-row">
			<input
				type="text"
				class="search-input"
				placeholder="🔍 Search by bill number, description, user, category..."
				bind:value={searchTerm}
			/>
			
			<select class="filter-select" bind:value={filterBranch}>
				<option value="">All Branches</option>
				{#each branches as branch}
					<option value={branch.id}>{branch.name_en}</option>
				{/each}
			</select>

			<select class="filter-select" bind:value={filterCategory}>
				<option value="">All Categories</option>
				{#each categories as category}
					<option value={category}>{category}</option>
				{/each}
			</select>

			<select class="filter-select" bind:value={filterBillType}>
				<option value="">All Bill Types</option>
				{#each billTypes as type}
					<option value={type}>{type}</option>
				{/each}
			</select>

			<select class="filter-select" bind:value={filterPaymentStatus}>
				<option value="">Payment Status</option>
				<option value="paid">Paid</option>
				<option value="unpaid">Unpaid</option>
			</select>

			<select class="filter-select" bind:value={filterDatePreset}>
				<option value="">Date Filter</option>
				<option value="today">Today</option>
				<option value="yesterday">Yesterday</option>
				<option value="custom">Custom</option>
			</select>
		</div>

		{#if filterDatePreset === 'custom'}
		<div class="filters-row">
			<input
				type="date"
				class="date-input"
				placeholder="From Date"
				bind:value={filterDateFrom}
			/>
			<input
				type="date"
				class="date-input"
				placeholder="To Date"
				bind:value={filterDateTo}
			/>
			<button class="reset-btn" on:click={resetFilters}>
				Clear Filters
			</button>
		</div>
		{:else}
		<div class="filters-row">
			<button class="reset-btn" on:click={resetFilters}>
				Clear Filters
			</button>
		</div>
		{/if}
	</div>

	<!-- Table -->
	<div class="table-container">
		{#if loading}
			<div class="loading">
				<div class="spinner">⏳</div>
				<p>Loading expenses...</p>
			</div>
		{:else if error}
			<div class="error-message">
				<div class="error-icon">❌</div>
				<p>{error}</p>
				<button class="retry-btn" on:click={loadExpenses}>Retry</button>
			</div>
		{:else if filteredExpenses.length === 0}
			<div class="no-data">
				<div class="no-data-icon">📭</div>
				<p>No expenses found</p>
				{#if expenses.length === 0}
					<p class="hint">The expense_scheduler table appears to be empty.</p>
				{:else}
					<p class="hint">Try adjusting your filters.</p>
				{/if}
			</div>
		{:else}
			<table class="expenses-table">
				<thead>
					<tr>
						<th>Bill #</th>
						<th>Branch</th>
						<th>Category</th>
						<th>Bill Type</th>
						<th>User</th>
						<th>Bill Date</th>
						<th>Due Date</th>
						<th>Amount</th>
						<th>Payment Method</th>
						<th>Paid</th>
						<th>Description</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredExpenses as expense}
					<tr>
						<td class="bill-number">{expense.bill_number || '-'}</td>
						<td class="branch-name">{expense.branches?.name_en || expense.branch_name || '-'}</td>
							<td>{expense.expense_category_name_en || '-'}</td>
							<td>
								<span class="bill-type-badge">{expense.bill_type?.replace('_', ' ')}</span>
							</td>
							<td>{expense.co_user_name || '-'}</td>
							<td>{formatDate(expense.bill_date)}</td>
							<td>{formatDate(expense.due_date)}</td>
							<td class="amount">{formatAmount(expense.amount)}</td>
							<td>{expense.payment_method || '-'}</td>
							<td>
								<span class="paid-badge {expense.is_paid ? 'paid' : 'unpaid'}">
									{expense.is_paid ? '✓ Paid' : '✗ Unpaid'}
								</span>
							</td>
						<td class="description">{expense.description || '-'}</td>
						<td class="actions">
							<div class="action-buttons">
								{#if canEdit}
									<button class="edit-btn" on:click={() => openEditModal(expense)}>
										✏️ Edit
									</button>
								{/if}
								{#if expense.bill_file_url}
									<button class="view-bill-btn" on:click={() => window.open(expense.bill_file_url, '_blank')}>
										📄 View Bill
									</button>
								{:else}
									<span class="no-bill">No Bill</span>
								{/if}
							</div>
						</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{/if}
	</div>
</div>

<!-- Edit Modal -->
{#if showEditModal}
	<div class="modal-overlay" on:click={closeEditModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h3>✏️ Edit Expense</h3>
				<button class="close-btn" on:click={closeEditModal}>✕</button>
			</div>
			<div class="modal-body">
				<div class="form-group">
					<label for="category">Category</label>
					<select id="category" bind:value={editForm.category}>
						<option value="" disabled>Select Category</option>
						{#each subCategories as subCategory}
							<option value="{subCategory.name_en}">{subCategory.name_en}</option>
						{/each}
					</select>
				</div>
				<div class="form-group">
					<label for="bill_type">Bill Type</label>
					<select id="bill_type" bind:value={editForm.bill_type}>
						<option value="" disabled>Select Bill Type</option>
						<option value="vat_applicable">Vat Applicable</option>
						<option value="no_vat">No Vat</option>
						<option value="no_bill">No Bill</option>
					</select>
				</div>
				<div class="form-group">
					<label for="description">Description</label>
					<textarea
						id="description"
						bind:value={editForm.description}
						placeholder="Enter description"
						rows="3"
					></textarea>
				</div>
				<div class="form-group">
					<label for="due_date">Due Date</label>
					<input
						type="date"
						id="due_date"
						bind:value={editForm.due_date}
					/>
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" on:click={closeEditModal}>Cancel</button>
				<button class="save-btn" on:click={saveEdit}>Save Changes</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.expense-tracker {
		padding: 20px;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f8f9fa;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
	}

	.header h2 {
		margin: 0;
		font-size: 24px;
		color: #333;
	}

	.header-buttons {
		display: flex;
		gap: 10px;
	}

	.compare-btn {
		padding: 8px 16px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		transition: background 0.2s;
		font-weight: 500;
	}

	.compare-btn:hover {
		background: #059669;
	}

	.refresh-btn {
		padding: 8px 16px;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		transition: background 0.2s;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #0056b3;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.summary-cards {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 15px;
		margin-bottom: 20px;
	}

	.summary-card {
		background: white;
		padding: 20px;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.summary-card.total {
		border-left: 4px solid #007bff;
	}

	.summary-card.paid {
		border-left: 4px solid #28a745;
	}

	.summary-card.unpaid {
		border-left: 4px solid #dc3545;
	}

	.card-label {
		font-size: 14px;
		color: #666;
		margin-bottom: 8px;
	}

	.card-value {
		font-size: 24px;
		font-weight: bold;
		color: #333;
		margin-bottom: 4px;
	}

	.card-count {
		font-size: 12px;
		color: #999;
	}

	.filters-section {
		background: white;
		padding: 20px;
		border-radius: 8px;
		margin-bottom: 20px;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.filters-row {
		display: flex;
		gap: 10px;
		margin-bottom: 10px;
	}

	.filters-row:last-child {
		margin-bottom: 0;
	}

	.search-input {
		flex: 2;
		padding: 10px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
	}

	.filter-select,
	.date-input {
		flex: 1;
		padding: 10px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.reset-btn {
		padding: 10px 20px;
		background: #6c757d;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		white-space: nowrap;
	}

	.reset-btn:hover {
		background: #5a6268;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0,0,0,0.1);
	}

	.expenses-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
	}

	.expenses-table thead {
		position: sticky;
		top: 0;
		background: #f8f9fa;
		z-index: 10;
	}

	.expenses-table th {
		padding: 12px;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 2px solid #dee2e6;
		white-space: nowrap;
	}

	.expenses-table td {
		padding: 12px;
		border-bottom: 1px solid #dee2e6;
	}

	.expenses-table tbody tr:hover {
		background: #f8f9fa;
	}

	.bill-number {
		font-weight: 600;
		color: #007bff;
	}

	.branch-name {
		max-width: 120px;
		word-wrap: break-word;
		white-space: normal;
	}

	.amount {
		font-weight: 600;
		color: #28a745;
		text-align: right;
	}

	.bill-type-badge {
		display: inline-block;
		padding: 4px 8px;
		background: #e9ecef;
		border-radius: 4px;
		font-size: 12px;
		text-transform: capitalize;
	}

	.status-badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		text-transform: capitalize;
	}

	.status-pending {
		background: #fff3cd;
		color: #856404;
	}

	.status-approved {
		background: #d1ecf1;
		color: #0c5460;
	}

	.status-rejected {
		background: #f8d7da;
		color: #721c24;
	}

	.status-paid {
		background: #d4edda;
		color: #155724;
	}

	.status-default {
		background: #e9ecef;
		color: #495057;
	}

	.paid-badge {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
	}

	.paid-badge.paid {
		background: #d4edda;
		color: #155724;
	}

	.paid-badge.unpaid {
		background: #f8d7da;
		color: #721c24;
	}

	.description {
		max-width: 200px;
		word-wrap: break-word;
		white-space: normal;
	}

	.actions {
		text-align: center;
		white-space: nowrap;
	}

	.action-buttons {
		display: flex;
		gap: 8px;
		justify-content: center;
		align-items: center;
	}

	.edit-btn {
		padding: 6px 12px;
		background: #28a745;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 12px;
		transition: background 0.2s;
	}

	.edit-btn:hover {
		background: #218838;
	}

	.view-bill-btn {
		padding: 6px 12px;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 12px;
		transition: background 0.2s;
	}

	.view-bill-btn:hover {
		background: #0056b3;
	}

	.no-bill {
		font-size: 12px;
		color: #999;
	}

	/* Modal Styles */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		justify-content: center;
		align-items: center;
		z-index: 1000;
	}

	.modal-content {
		background: white;
		border-radius: 8px;
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		border-bottom: 1px solid #dee2e6;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 20px;
		color: #333;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		cursor: pointer;
		color: #999;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		color: #333;
	}

	.modal-body {
		padding: 20px;
	}

	.form-group {
		margin-bottom: 20px;
	}

	.form-group label {
		display: block;
		margin-bottom: 8px;
		font-weight: 600;
		color: #333;
		font-size: 14px;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		width: 100%;
		padding: 10px;
		border: 1px solid #ddd;
		border-radius: 4px;
		font-size: 14px;
		font-family: inherit;
	}

	.form-group textarea {
		resize: vertical;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 10px;
		padding: 20px;
		border-top: 1px solid #dee2e6;
	}

	.cancel-btn {
		padding: 10px 20px;
		background: #6c757d;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 14px;
	}

	.cancel-btn:hover {
		background: #5a6268;
	}

	.save-btn {
		padding: 10px 20px;
		background: #28a745;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 14px;
	}

	.save-btn:hover {
		background: #218838;
	}

	.loading,
	.no-data,
	.error-message {
		padding: 40px;
		text-align: center;
		color: #666;
		font-size: 16px;
	}

	.spinner,
	.no-data-icon,
	.error-icon {
		font-size: 48px;
		margin-bottom: 16px;
	}

	.loading p,
	.no-data p,
	.error-message p {
		margin: 8px 0;
	}

	.hint {
		font-size: 14px;
		color: #999;
		margin-top: 8px;
	}

	.retry-btn {
		margin-top: 16px;
		padding: 10px 20px;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
	}

	.retry-btn:hover {
		background: #0056b3;
	}

	.error-message {
		color: #dc3545;
	}
</style>
