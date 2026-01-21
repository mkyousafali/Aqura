<script lang="ts">
	import { onMount } from 'svelte';

	let vendorTotal = 0;
	let expenseTotal = 0;
	let vendorTotalUnpaid = 0;
	let expenseTotalUnpaid = 0;
	let isLoading = true;
	let showVendorTable = false;
	let showExpenseTable = false;
	let vendorData: any[] = [];
	let expenseData: any[] = [];
	let loadingVendor = false;
	let loadingExpense = false;
	let vendorLoadingPercent = 0;
	let expenseLoadingPercent = 0;
	let branches: any[] = [];
	let selectedVendorBranch: number | null = null;
	let selectedExpenseBranch: number | null = null;
	let filteredVendorData: any[] = [];
	let filteredExpenseData: any[] = [];
	let editingVendorId: number | null = null;
	let editingVendorDate = '';
	let editingExpenseId: number | null = null;
	let editingExpenseDate = '';

	onMount(async () => {
		await fetchOverduesData();
		await fetchBranches();
		isLoading = false;
	});

	async function fetchBranches() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data } = await supabase
				.from('branches')
				.select('id, name_en, location_en')
				.eq('is_active', true)
				.order('name_en', { ascending: true });
			branches = data || [];
		} catch (err) {
			console.error('Error fetching branches:', err);
		}
	}

	async function fetchOverduesData() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const today = new Date();
			const fiveDaysFromNow = new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000);
			const dueDateLimit = fiveDaysFromNow.toISOString().split('T')[0];

			// Fetch vendor overdue data (due within 5 days)
			const vendorOverdueResponse = await supabase
				.from('vendor_payment_schedule')
				.select('final_bill_amount')
				.lte('due_date', dueDateLimit)
				.eq('is_paid', false);

			// Fetch vendor total unpaid (all unpaid regardless of due date)
			const vendorUnpaidResponse = await supabase
				.from('vendor_payment_schedule')
				.select('final_bill_amount')
				.eq('is_paid', false);

			// Fetch expense overdue data (due within 5 days)
			const expenseOverdueResponse = await supabase
				.from('expense_scheduler')
				.select('amount')
				.lte('due_date', dueDateLimit)
				.eq('is_paid', false);

			// Fetch expense total unpaid (all unpaid regardless of due date)
			const expenseUnpaidResponse = await supabase
				.from('expense_scheduler')
				.select('amount')
				.eq('is_paid', false);

			// Process vendor overdue data
			if (!vendorOverdueResponse.error && vendorOverdueResponse.data) {
				vendorTotal = vendorOverdueResponse.data.reduce((sum, item) => sum + (item.final_bill_amount || 0), 0);
			}

			// Process vendor total unpaid
			if (!vendorUnpaidResponse.error && vendorUnpaidResponse.data) {
				vendorTotalUnpaid = vendorUnpaidResponse.data.reduce((sum, item) => sum + (item.final_bill_amount || 0), 0);
			}

			// Process expense overdue data
			if (!expenseOverdueResponse.error && expenseOverdueResponse.data) {
				expenseTotal = expenseOverdueResponse.data.reduce((sum, item) => sum + (item.amount || 0), 0);
			}

			// Process expense total unpaid
			if (!expenseUnpaidResponse.error && expenseUnpaidResponse.data) {
				expenseTotalUnpaid = expenseUnpaidResponse.data.reduce((sum, item) => sum + (item.amount || 0), 0);
			}
		} catch (err) {
			console.error('Error fetching overdues data:', err);
		}
	}

	async function loadVendorTable() {
		loadingVendor = true;
		vendorLoadingPercent = 0;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const today = new Date();
			const fiveDaysFromNow = new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000);
			const dueDateLimit = fiveDaysFromNow.toISOString().split('T')[0];

		vendorLoadingPercent = 25;

		const { data: vendorPayments, error: vendorError } = await supabase
			.from('vendor_payment_schedule')
			.select('id, vendor_name, final_bill_amount, due_date, is_paid, bill_date, branch_id, payment_method')
			.lte('due_date', dueDateLimit)
			.eq('is_paid', false)
			.order('due_date', { ascending: true })
			.limit(1000);

		vendorLoadingPercent = 50;

		// Fetch branch names for vendor payments
		if (!vendorError && vendorPayments && vendorPayments.length > 0) {
			const branchIds = [...new Set(vendorPayments.map(v => v.branch_id))];
			const { data: branches } = await supabase
				.from('branches')
				.select('id, name_en')
				.in('id', branchIds);

			vendorLoadingPercent = 75;

			const branchMap = new Map(branches?.map(b => [b.id, b.name_en]) || []);
			vendorData = vendorPayments
				.filter(row => parseFloat(row.final_bill_amount) >= 0.01)
				.map(row => ({
					...row,
					branch_name: branchMap.get(row.branch_id) || 'N/A'
				}));
			filteredVendorData = vendorData;
			vendorLoadingPercent = 100;
			showVendorTable = true;
		}
		} catch (err) {
			console.error('Error loading vendor table:', err);
		} finally {
			loadingVendor = false;
		}
	}

	async function loadExpenseTable() {
		loadingExpense = true;
		expenseLoadingPercent = 0;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const today = new Date();
			const fiveDaysFromNow = new Date(today.getTime() + 5 * 24 * 60 * 60 * 1000);
			const dueDateLimit = fiveDaysFromNow.toISOString().split('T')[0];

			expenseLoadingPercent = 25;

		const { data: expenseSchedules, error } = await supabase
			.from('expense_scheduler')
			.select('id, description, amount, due_date, is_paid, payment_method, branch_id')
			.lte('due_date', dueDateLimit)
			.eq('is_paid', false)
			.order('due_date', { ascending: true })
			.limit(1000);

		expenseLoadingPercent = 50;

		if (!error && expenseSchedules && expenseSchedules.length > 0) {
			const branchIds = [...new Set(expenseSchedules.map(e => e.branch_id))];
			const { data: branches } = await supabase
				.from('branches')
				.select('id, name_en')
				.in('id', branchIds);

			expenseLoadingPercent = 75;

			const branchMap = new Map(branches?.map(b => [b.id, b.name_en]) || []);
			expenseData = expenseSchedules
				.filter(row => parseFloat(row.amount) >= 0.01)
				.map(row => ({
					...row,
					branch_name: branchMap.get(row.branch_id) || 'N/A'
				}));
				filteredExpenseData = expenseData;
				expenseLoadingPercent = 100;
				showExpenseTable = true;
			}
		} catch (err) {
			console.error('Error loading expense table:', err);
		} finally {
			loadingExpense = false;
		}
	}

	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat('en-US', {
			style: 'currency',
			currency: 'SAR',
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(amount);
	}

	function formatDate(dateStr: string): string {
		const date = new Date(dateStr);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}/${month}/${year}`;
	}

	function getStatusDisplay(isPaid: boolean): string {
		return isPaid ? 'Paid' : 'Unpaid';
	}

	async function updateVendorDueDate(id: number, newDate: string) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({ due_date: newDate })
				.eq('id', id);

			if (!error) {
				// Update local data
				const index = vendorData.findIndex(row => row.id === id);
				if (index !== -1) {
					vendorData[index].due_date = newDate;
					vendorData = [...vendorData];
				}
				editingVendorId = null;
			} else {
				console.error('Error updating vendor due date:', error);
				alert('Failed to update due date');
			}
		} catch (err) {
			console.error('Error updating vendor due date:', err);
			alert('Error updating due date');
		}
	}

	async function updateExpenseDueDate(id: number, newDate: string) {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { error } = await supabase
				.from('expense_scheduler')
				.update({ due_date: newDate })
				.eq('id', id);

			if (!error) {
				// Update local data
				const index = expenseData.findIndex(row => row.id === id);
				if (index !== -1) {
					expenseData[index].due_date = newDate;
					expenseData = [...expenseData];
				}
				editingExpenseId = null;
			} else {
				console.error('Error updating expense due date:', error);
				alert('Failed to update due date');
			}
		} catch (err) {
			console.error('Error updating expense due date:', err);
			alert('Error updating due date');
		}
	}

	// Filter vendor data based on selected branch
	$: {
		if (selectedVendorBranch) {
			filteredVendorData = vendorData.filter(row => 
				row.branch_id === selectedVendorBranch && parseFloat(row.final_bill_amount) >= 0.01
			);
		} else {
			filteredVendorData = vendorData.filter(row => parseFloat(row.final_bill_amount) >= 0.01);
		}
	}

	// Filter expense data based on selected branch
	$: {
		if (selectedExpenseBranch) {
			filteredExpenseData = expenseData.filter(row => 
				row.branch_id === selectedExpenseBranch && parseFloat(row.amount) >= 0.01
			);
		} else {
			filteredExpenseData = expenseData.filter(row => parseFloat(row.amount) >= 0.01);
		}
	}
</script>

<div class="overdues-container">
	{#if isLoading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading overdues data...</p>
		</div>
	{:else}
		<div class="cards-grid">
			<div class="card summary-card">
				<div class="card-icon">📊</div>
				<div class="card-title">Overdue Summary</div>
				<div class="card-amount">{formatCurrency(vendorTotal + expenseTotal)}</div>
				<div class="card-subtitle">Total Unpaid (All): {formatCurrency(vendorTotalUnpaid + expenseTotalUnpaid)}</div>
			</div>
		</div>
		<div class="cards-grid">
			<div class="card">
				<div class="card-icon">🏢</div>
				<div class="card-title">Vendor Overdue</div>
				<div class="card-amount">{formatCurrency(vendorTotal)}</div>
				<div class="card-subtitle">Total Unpaid: {formatCurrency(vendorTotalUnpaid)}</div>
				<button class="view-btn" on:click={() => {
					if (showVendorTable) {
						showVendorTable = false;
					} else {
						loadVendorTable();
					}
				}} disabled={loadingVendor}>
					{#if loadingVendor}
						Loading {vendorLoadingPercent}%
					{:else if showVendorTable}
						Hide
					{:else}
						View
					{/if}
				</button>
			</div>
			<div class="card">
				<div class="card-icon">💸</div>
				<div class="card-title">Expense Overdue</div>
				<div class="card-amount">{formatCurrency(expenseTotal)}</div>
				<div class="card-subtitle">Total Unpaid: {formatCurrency(expenseTotalUnpaid)}</div>
				<button class="view-btn" on:click={() => {
					if (showExpenseTable) {
						showExpenseTable = false;
					} else {
						loadExpenseTable();
					}
				}} disabled={loadingExpense}>
					{#if loadingExpense}
						Loading {expenseLoadingPercent}%
					{:else if showExpenseTable}
						Hide
					{:else}
						View
					{/if}
				</button>
			</div>
		</div>

		<!-- Vendor Table -->
		{#if showVendorTable}
			<div class="table-section">
				<div class="table-header">
					<h3>Vendor Overdue Details</h3>
					<div class="filter-group">
						<label for="vendor-branch">Filter by Branch:</label>
						<select id="vendor-branch" bind:value={selectedVendorBranch} class="filter-select">
							<option value={null}>All Branches</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
							{/each}
						</select>
					</div>
				</div>
				<div class="table-wrapper">
					<table class="data-table">
						<thead>
							<tr>
								<th>Vendor Name</th>
								<th>Branch</th>
								<th>Bill Date</th>
								<th>Amount</th>
								<th>Due Date</th>
								<th>Payment Method</th>
								<th>Status</th>
							</tr>
						</thead>
						<tbody>
						{#each filteredVendorData as row (row.id)}
							<tr>
						<td>{row.vendor_name || 'N/A'}</td>
						<td>{row.branch_name || 'N/A'}</td>
						<td>{formatDate(row.bill_date || '')}</td>
						<td>{formatCurrency(row.final_bill_amount || 0)}</td>
						<td class="editable-cell" on:dblclick={() => {
							editingVendorId = row.id;
							editingVendorDate = row.due_date || '';
						}}>
							{#if editingVendorId === row.id}
								<input 
									type="date" 
									bind:value={editingVendorDate}
									on:blur={() => {
										if (editingVendorDate && editingVendorDate !== row.due_date) {
											updateVendorDueDate(row.id, editingVendorDate);
										} else {
											editingVendorId = null;
										}
									}}
									on:keydown={(e) => {
										if (e.key === 'Enter') {
											updateVendorDueDate(row.id, editingVendorDate);
										} else if (e.key === 'Escape') {
											editingVendorId = null;
										}
									}}
									autoFocus
									class="edit-input"
								/>
							{:else}
								{formatDate(row.due_date || '')}
							{/if}
						</td>
						<td>{row.payment_method || 'N/A'}</td>
						<td>{getStatusDisplay(row.is_paid)}</td>
							</tr>
						{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}

		<!-- Expense Table -->
		{#if showExpenseTable}
			<div class="table-section">
				<div class="table-header">
					<h3>Expense Overdue Details</h3>
					<div class="filter-group">
						<label for="expense-branch">Filter by Branch:</label>
						<select id="expense-branch" bind:value={selectedExpenseBranch} class="filter-select">
							<option value={null}>All Branches</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en} - {branch.location_en}</option>
							{/each}
						</select>
					</div>
				</div>
				<div class="table-wrapper">
					<table class="data-table">
						<thead>
							<tr>
								<th>Description</th>
								<th>Branch</th>
								<th>Amount</th>
								<th>Due Date</th>
								<th>Payment Method</th>
								<th>Status</th>
							</tr>
						</thead>
						<tbody>
						{#each filteredExpenseData as row (row.id)}
							<tr>
						<td>{row.description || 'N/A'}</td>
						<td>{row.branch_name || 'N/A'}</td>
						<td>{formatCurrency(row.amount || 0)}</td>
						<td class="editable-cell" on:dblclick={() => {
							editingExpenseId = row.id;
							editingExpenseDate = row.due_date || '';
						}}>
							{#if editingExpenseId === row.id}
								<input 
									type="date" 
									bind:value={editingExpenseDate}
									on:blur={() => {
										if (editingExpenseDate && editingExpenseDate !== row.due_date) {
											updateExpenseDueDate(row.id, editingExpenseDate);
										} else {
											editingExpenseId = null;
										}
									}}
									on:keydown={(e) => {
										if (e.key === 'Enter') {
											updateExpenseDueDate(row.id, editingExpenseDate);
										} else if (e.key === 'Escape') {
											editingExpenseId = null;
										}
									}}
									autoFocus
									class="edit-input"
								/>
							{:else}
								{formatDate(row.due_date || '')}
							{/if}
						</td>
						<td>{row.payment_method || 'N/A'}</td>
						<td>{getStatusDisplay(row.is_paid)}</td>
							</tr>
						{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
	{/if}
</div>

<style>
	.overdues-container {
		width: 100%;
		height: 100%;
		padding: 20px;
		background-color: #f5f5f5;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		gap: 20px;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e0e0e0;
		border-top-color: #2196f3;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.cards-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
		gap: 10px;
		margin-bottom: 10px;
	}

	.card {
		background-color: white;
		border-radius: 6px;
		padding: 10px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		cursor: pointer;
		transition: transform 0.2s, box-shadow 0.2s;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
	}

	.summary-card {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
		grid-column: 1 / -1;
	}

	.summary-card .card-title {
		color: white;
	}

	.summary-card .card-amount {
		color: #fff;
	}

	.card:hover {
		transform: translateY(-3px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.card-icon {
		font-size: 28px;
	}

	.card-title {
		font-size: 12px;
		font-weight: 600;
		color: #333;
		text-align: center;
	}

	.card-amount {
		font-size: 14px;
		font-weight: 700;
		color: #d9534f;
		text-align: center;
	}

	.card-subtitle {
		font-size: 12px;
		color: white;
		text-align: center;
		margin: 8px 0;
		font-weight: 500;
	}

	.view-btn {
		padding: 6px 12px;
		background-color: #007bff;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 12px;
		font-weight: 600;
		transition: background-color 0.2s;
	}

	.view-btn:hover:not(:disabled) {
		background-color: #0056b3;
	}

	.view-btn:disabled {
		background-color: #6c757d;
		cursor: not-allowed;
	}

	.table-section {
		margin-top: 20px;
		background-color: white;
		border-radius: 8px;
		padding: 15px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.table-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.table-header h3 {
		margin: 0;
		flex: 1;
		min-width: 200px;
		font-size: 16px;
		font-weight: 600;
		color: #333;
	}

	.filter-group {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.filter-group label {
		font-weight: 500;
		color: #333;
		white-space: nowrap;
	}

	.filter-select {
		padding: 0.5rem 0.75rem;
		border: 1px solid #ccc;
		border-radius: 4px;
		font-size: 0.95rem;
		background-color: white;
		cursor: pointer;
		transition: border-color 0.2s;
	}

	.filter-select:hover {
		border-color: #667eea;
	}

	.filter-select:focus {
		outline: none;
		border-color: #667eea;
		box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.1);
	}

	.editable-cell {
		cursor: pointer;
		position: relative;
	}

	.editable-cell:hover {
		background-color: #e8f4f8;
	}

	.edit-input {
		width: 100%;
		padding: 4px 6px;
		border: 2px solid #667eea;
		border-radius: 4px;
		font-size: 13px;
		font-family: inherit;
	}

	.edit-input:focus {
		outline: none;
		border-color: #764ba2;
		box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.2);
	}

	.table-wrapper {
		overflow-x: auto;
	}

	.data-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 13px;
	}

	.data-table thead {
		background-color: #f8f9fa;
	}

	.data-table th {
		padding: 10px;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 2px solid #dee2e6;
	}

	.data-table td {
		padding: 10px;
		border-bottom: 1px solid #dee2e6;
	}

	.data-table tbody tr:hover {
		background-color: #f8f9fa;
	}
</style>
