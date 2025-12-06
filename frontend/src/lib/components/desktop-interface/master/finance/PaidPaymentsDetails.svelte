<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	// Props
	export let payments = [];

	// Expense scheduler payments
	let expenseSchedulerPayments = [];

	// Filter and search state
	let searchQuery = '';
	let selectedBranch = '';
	let selectedPaymentMethod = '';
	let selectedType = ''; // 'vendor', 'expense', or '' for all
	let dateFrom = '';
	let dateTo = '';
	let filteredPayments = [];
	let filteredExpenses = [];

	// Load expense scheduler payments
	onMount(async () => {
		await loadExpenseSchedulerPayments();
	});

	async function loadExpenseSchedulerPayments() {
		try {
			const { data, error } = await supabase
				.from('expense_scheduler')
				.select('*')
				.eq('is_paid', true)
				.order('paid_date', { ascending: false });

			if (error) {
				console.error('Error loading expense scheduler payments:', error);
				return;
			}

			console.log('Loaded paid expense scheduler payments:', data);
			expenseSchedulerPayments = data || [];
		} catch (err) {
			console.error('Error loading expense scheduler payments:', err);
		}
	}

	// Reference editing state
	let editingReference = null;
	let editingValue = '';
	let editingType = null; // 'vendor' or 'expense'
	let isUpdating = false;

	// Get unique values for filters
	// Build branch list keyed by branch_id to display unique branches with their IDs
	$: uniqueBranchesMap = new Map();
	$: {
		uniqueBranchesMap.clear();
		payments.forEach(p => {
			const branchId = p.receiving_records?.branch_id;
			const branchName = p.receiving_records?.branches?.name_en;
			if (branchId && branchName) {
				uniqueBranchesMap.set(branchId, branchName);
			}
		});
	}
	$: uniqueBranches = Array.from(uniqueBranchesMap.entries()).map(([id, name]) => ({ id, name })).sort((a, b) => a.name.localeCompare(b.name));
	$: uniquePaymentMethods = [...new Set(payments.map(p => p.payment_method).filter(Boolean))].sort();

	// Filter payments based on search and filters
	$: {
		filteredPayments = payments.filter(payment => {
			// Search filter
			if (searchQuery) {
				const query = searchQuery.toLowerCase();
			const matchesSearch = 
				payment.vendor_name?.toLowerCase().includes(query) ||
				payment.receiving_records?.vendor_id?.toString().includes(query) ||
				payment.receiving_records?.branches?.name_en?.toLowerCase().includes(query) ||
				payment.bill_number?.toLowerCase().includes(query) ||
				payment.payment_reference?.toLowerCase().includes(query) ||
				(payment.final_bill_amount || payment.bill_amount)?.toString().includes(query) ||
				payment.payment_method?.toLowerCase().includes(query);				if (!matchesSearch) return false;
			}

			// Branch filter - use branch_id instead of branch name for accurate filtering
			if (selectedBranch && payment.receiving_records?.branch_id?.toString() !== selectedBranch) {
				return false;
			}

			// Payment method filter
			if (selectedPaymentMethod && payment.payment_method !== selectedPaymentMethod) {
				return false;
			}

		// Date range filter
		if (dateFrom || dateTo) {
			const paymentDate = new Date(payment.paid_date || payment.transaction_date);
			if (dateFrom && paymentDate < new Date(dateFrom)) return false;
			if (dateTo && paymentDate > new Date(dateTo)) return false;
		}

		return true;
	});

	// Filter expense scheduler payments
	filteredExpenses = expenseSchedulerPayments.filter(expense => {
		// Search filter
		if (searchQuery) {
			const query = searchQuery.toLowerCase();
			const matchesSearch = 
				expense.co_user_name?.toLowerCase().includes(query) ||
				expense.branch_name?.toLowerCase().includes(query) ||
				expense.requisition_number?.toLowerCase().includes(query) ||
				expense.expense_category_name_en?.toLowerCase().includes(query) ||
				expense.amount?.toString().includes(query);
			if (!matchesSearch) return false;
		}

		// Branch filter
		if (selectedBranch && expense.branch_name !== selectedBranch) {
			return false;
		}

		// Date range filter
		if (dateFrom || dateTo) {
			const expenseDate = new Date(expense.paid_date);
			if (dateFrom && expenseDate < new Date(dateFrom)) return false;
			if (dateTo && expenseDate > new Date(dateTo)) return false;
		}

		return true;
	}).sort((a, b) => {
		// Sort by paid_date descending (latest first)
		const dateA = new Date(a.paid_date);
		const dateB = new Date(b.paid_date);
		return dateB.getTime() - dateA.getTime();
	});
}

// Calculate filtered totals
$: filteredTotal = filteredPayments.reduce((sum, p) => sum + (parseFloat(p.final_bill_amount || p.bill_amount) || 0), 0);
$: filteredExpenseTotal = filteredExpenses.reduce((sum, e) => sum + (parseFloat(e.amount) || 0), 0);
$: combinedTotal = filteredTotal + filteredExpenseTotal;

// Combine and sort vendor and expense payments by date, then filter by type
$: combinedPayments = [
	...filteredPayments.map(p => ({ ...p, type: 'vendor', sortDate: new Date(p.paid_date || p.transaction_date) })),
	...filteredExpenses.map(e => ({ ...e, type: 'expense', sortDate: new Date(e.paid_date) }))
]
	.filter(item => !selectedType || item.type === selectedType) // Filter by type if selected
	.sort((a, b) => b.sortDate - a.sortDate);

// Format currency
	function formatCurrency(amount) {
		if (!amount) return 'SAR 0.00';
		return `SAR ${parseFloat(amount).toFixed(2)}`;
	}

	// Format date to dd/mm/yyyy
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

	// View original bill in new tab
	function viewOriginalBill(url) {
		if (url) {
			window.open(url, '_blank');
		}
	}

	// Clear all filters
	function clearFilters() {
		searchQuery = '';
		selectedBranch = '';
		selectedPaymentMethod = '';
		selectedType = '';
		dateFrom = '';
		dateTo = '';
	}

	// Start editing reference
	function startEditReference(paymentId, currentReference, itemType = 'vendor') {
		editingReference = paymentId;
		editingValue = currentReference || '';
		editingType = itemType; // Store the type being edited
	}

	// Cancel editing reference
	function cancelEditReference() {
		editingReference = null;
		editingValue = '';
		editingType = null;
	}

	// Update reference number
	async function updateReference(paymentId) {
		if (isUpdating) return;
		
		isUpdating = true;
		try {
			if (editingType === 'expense') {
				// Update expense scheduler reference
				const { error } = await supabase
					.from('expense_scheduler')
					.update({ payment_reference: editingValue.trim() || null })
					.eq('id', paymentId);

				if (error) {
					console.error('Error updating expense reference:', error);
					alert('Error updating reference number. Please try again.');
					return;
				}

				// Update the local expense array
				const expenseIndex = expenseSchedulerPayments.findIndex(e => e.id === paymentId);
				if (expenseIndex !== -1) {
					expenseSchedulerPayments[expenseIndex].payment_reference = editingValue.trim() || null;
					expenseSchedulerPayments = [...expenseSchedulerPayments]; // Trigger reactivity
				}
			} else {
				// Update vendor payment reference
				const { error } = await supabase
					.from('vendor_payment_schedule')
					.update({ payment_reference: editingValue.trim() || null })
					.eq('id', paymentId);

				if (error) {
					console.error('Error updating reference:', error);
					alert('Error updating reference number. Please try again.');
					return;
				}

				// Update the local payments array
				const paymentIndex = payments.findIndex(p => p.id === paymentId);
				if (paymentIndex !== -1) {
					payments[paymentIndex].payment_reference = editingValue.trim() || null;
					payments = [...payments]; // Trigger reactivity
				}
			}

			// Clear editing state
			editingReference = null;
			editingValue = '';
			editingType = null;
		} catch (err) {
			console.error('Error updating reference:', err);
			alert('Error updating reference number. Please try again.');
		} finally {
			isUpdating = false;
		}
	}

	// Handle Enter key press
	function handleKeyPress(event, paymentId) {
		if (event.key === 'Enter') {
			updateReference(paymentId);
		} else if (event.key === 'Escape') {
			cancelEditReference();
		}
	}
</script>

<div class="paid-payments-window">
	<div class="window-header">
		<h2>Paid Payments Details</h2>
		<div class="summary">
			Showing: {filteredPayments.length} vendor + {filteredExpenses.length} expense records | 
			Vendor Total: {formatCurrency(filteredTotal)} | 
			<span style="color: #059669;">Expense Total: {formatCurrency(filteredExpenseTotal)}</span> |
			<strong>Combined Total: {formatCurrency(combinedTotal)}</strong>
		</div>
	</div>

	<!-- Filters and Search -->
	<div class="filters-section">
		<div class="search-row">
			<div class="search-input-wrapper">
				<input 
					type="text" 
					bind:value={searchQuery}
					placeholder="Search by vendor name, ID, branch, bill number, reference, amount..."
					class="search-input"
				/>
				<span class="search-icon">🔍</span>
			</div>
			
			{#if searchQuery || selectedBranch || selectedPaymentMethod || selectedType || dateFrom || dateTo}
				<button class="clear-filters-btn" on:click={clearFilters}>
					Clear Filters
				</button>
			{/if}
		</div>

		<div class="filter-row">
			<div class="filter-group">
				<label for="type-filter">Type:</label>
				<select id="type-filter" bind:value={selectedType} class="filter-select">
					<option value="">All Types</option>
					<option value="vendor">Vendor</option>
					<option value="expense">Expense</option>
				</select>
			</div>

			<div class="filter-group">
				<label for="branch-filter">Branch:</label>
				<select id="branch-filter" bind:value={selectedBranch} class="filter-select">
					<option value="">All Branches</option>
					{#each uniqueBranches as branch}
						<option value={branch.id.toString()}>{branch.name}</option>
					{/each}
				</select>
			</div>

			<div class="filter-group">
				<label for="method-filter">Payment Method:</label>
				<select id="method-filter" bind:value={selectedPaymentMethod} class="filter-select">
					<option value="">All Methods</option>
					{#each uniquePaymentMethods as method}
						<option value={method}>{method}</option>
					{/each}
				</select>
			</div>

			<div class="filter-group">
				<label for="date-from">Date From:</label>
				<input 
					id="date-from"
					type="date" 
					bind:value={dateFrom}
					class="date-input"
				/>
			</div>

			<div class="filter-group">
				<label for="date-to">Date To:</label>
				<input 
					id="date-to"
					type="date" 
					bind:value={dateTo}
					class="date-input"
				/>
			</div>
		</div>
	</div>
	
	<div class="table-container">
		{#if filteredPayments.length > 0 || filteredExpenses.length > 0}
			<table class="payments-table">
				<thead>
					<tr>
						<th>Type</th>
						<th>Transaction Date</th>
						<th>Amount</th>
						<th>Bill Number / Requisition</th>
						<th>Vendor / CO Name</th>
						<th>Category</th>
						<th>Branch</th>
						<th>Payment Method</th>
						<th>Payment Status</th>
						<th>Bank Info</th>
						<th>Reference</th>
						<th>Bill</th>
					</tr>
				</thead>
				<tbody>
					{#each combinedPayments as item}
						<tr class:expense-row={item.type === 'expense'}>
							<td>
								<span class="type-badge {item.type === 'vendor' ? 'vendor-badge' : 'expense-badge'}">
									{item.type === 'vendor' ? 'Vendor' : 'Expense'}
								</span>
							</td>
							<td class="date-cell">
								{formatDate(item.type === 'vendor' ? (item.paid_date || item.transaction_date) : item.paid_date)}
							</td>
							<td class="amount-cell">
								{formatCurrency(item.type === 'vendor' ? (item.final_bill_amount || item.bill_amount) : item.amount)}
							</td>
							<td class="{item.type === 'vendor' ? 'bill-number-cell' : 'requisition-cell'}">
								{item.type === 'vendor' ? (item.bill_number || 'N/A') : (item.requisition_number || 'N/A')}
							</td>
							<td class="{item.type === 'vendor' ? 'vendor-cell' : 'co-cell'}">
								{#if item.type === 'vendor'}
									<div class="vendor-info">
										<div class="vendor-name">
											{item.vendor_name || 'N/A'}
										</div>
										<div class="vendor-id">
											ID: {item.receiving_records?.vendor_id || 'N/A'}
										</div>
									</div>
								{:else}
									{item.co_user_name || 'N/A'}
								{/if}
							</td>
							<td class="category-cell">
								{#if item.type === 'vendor'}
									<span class="category-na">N/A</span>
								{:else}
									{item.expense_category_name_en || 'N/A'}
								{/if}
							</td>
							<td class="branch-cell">
								{item.type === 'vendor' ? (item.receiving_records?.branches?.name_en || 'N/A') : (item.branch_name || 'N/A')}
							</td>
							<td class="method-cell">
								<div class="payment-method">
									{item.payment_method || 'N/A'}
								</div>
							</td>
							<td class="status-cell">
								<div class="payment-status-badge paid">
									✓ Paid
								</div>
							</td>
							<td class="bank-cell">
								{#if item.type === 'vendor'}
									<div class="bank-info">
										{#if item.bank_name}
											<div class="bank-name">Bank: {item.bank_name}</div>
										{/if}
										{#if item.iban}
											<div class="iban">IBAN: {item.iban}</div>
										{/if}
										{#if !item.bank_name && !item.iban}
											<span class="no-info">N/A</span>
										{/if}
									</div>
								{:else}
									<span class="no-info">N/A</span>
								{/if}
							</td>
							<td class="reference-cell">
								{#if item.type === 'vendor'}
									{#if editingReference === item.id}
										<div class="reference-edit-container">
											<input 
												type="text" 
												bind:value={editingValue}
												on:keypress={(e) => handleKeyPress(e, item.id)}
												class="reference-input"
												placeholder="Enter reference number"
												disabled={isUpdating}
												autofocus
											/>
											<div class="reference-edit-buttons">
												<button 
													class="save-btn" 
													on:click={() => updateReference(item.id)}
													disabled={isUpdating}
													title="Save"
												>
													{#if isUpdating}
														⏳
													{:else}
														✅
													{/if}
												</button>
												<button 
													class="cancel-btn" 
													on:click={cancelEditReference}
													disabled={isUpdating}
													title="Cancel"
												>
													❌
												</button>
											</div>
										</div>
									{:else}
										<div 
											class="reference-display"
											on:click={() => startEditReference(item.id, item.payment_reference, 'vendor')}
											title="Click to edit reference number"
										>
											{item.payment_reference || 'Click to add'}
										</div>
									{/if}
								{:else}
									<!-- Expense reference editing -->
									{#if editingReference === item.id}
										<div class="reference-edit-container">
											<input 
												type="text" 
												bind:value={editingValue}
												on:keypress={(e) => handleKeyPress(e, item.id)}
												class="reference-input"
												placeholder="Enter reference number"
												disabled={isUpdating}
												autofocus
											/>
											<div class="reference-edit-buttons">
												<button 
													class="save-btn" 
													on:click={() => updateReference(item.id)}
													disabled={isUpdating}
													title="Save"
												>
													{#if isUpdating}
														⏳
													{:else}
														✅
													{/if}
												</button>
												<button 
													class="cancel-btn" 
													on:click={cancelEditReference}
													disabled={isUpdating}
													title="Cancel"
												>
													❌
												</button>
											</div>
										</div>
									{:else}
										<div 
											class="reference-display"
											on:click={() => startEditReference(item.id, item.payment_reference, 'expense')}
											title="Click to edit reference number"
										>
											{item.payment_reference || 'Click to add'}
										</div>
									{/if}
								{/if}
							</td>
							<td class="bill-cell">
								{#if item.type === 'vendor'}
									{#if item.receiving_records?.original_bill_url}
										<button 
											class="view-bill-btn" 
											on:click={() => viewOriginalBill(item.receiving_records.original_bill_url)}
											title="View Original Bill"
										>
											{#if item.receiving_records.original_bill_url.toLowerCase().includes('.pdf')}
												📄 PDF
											{:else}
												🖼️ Image
											{/if}
										</button>
									{:else}
										<span class="no-bill">No Bill</span>
									{/if}
								{:else}
									{#if item.bill_file_url}
										<button 
											class="view-bill-btn"
											on:click={() => viewOriginalBill(item.bill_file_url)}
											title="View Bill"
										>
											{#if item.bill_file_url.toLowerCase().includes('.pdf')}
												📄 PDF
											{:else}
												🖼️ Image
											{/if}
										</button>
									{:else if item.receipt_url}
										<button 
											class="view-bill-btn"
											on:click={() => window.open(item.receipt_url, '_blank')}
											title="View Receipt"
										>
											🧾 Receipt
										</button>
									{:else}
										<span class="no-bill">No Bill</span>
									{/if}
								{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		{:else}
			<div class="no-data">
				<div class="no-data-icon">💳</div>
				<h3>No Matching Transactions Found</h3>
				<p>
					{#if payments.length === 0 && expenseSchedulerPayments.length === 0}
						There are currently no paid payment transactions to display.
					{:else}
						No transactions match your current filter criteria. Try adjusting your search or filters.
					{/if}
				</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.paid-payments-window {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #ffffff;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	.window-header {
		padding: 20px;
		border-bottom: 2px solid #e2e8f0;
		background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
		flex-shrink: 0;
	}

	.window-header h2 {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
		margin: 0 0 8px 0;
	}

	.summary {
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
	}

	/* Filters Section */
	.filters-section {
		padding: 20px;
		background: #f8fafc;
		border-bottom: 2px solid #e2e8f0;
		flex-shrink: 0;
	}

	.search-row {
		display: flex;
		align-items: center;
		gap: 16px;
		margin-bottom: 16px;
	}

	.search-input-wrapper {
		position: relative;
		flex: 1;
		max-width: 400px;
	}

	.search-input {
		width: 100%;
		padding: 12px 16px 12px 44px;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 14px;
		background: white;
		transition: all 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-icon {
		position: absolute;
		left: 16px;
		top: 50%;
		transform: translateY(-50%);
		color: #64748b;
		font-size: 16px;
	}

	.clear-filters-btn {
		padding: 10px 16px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.clear-filters-btn:hover {
		background: #dc2626;
		transform: translateY(-1px);
	}

	.filter-row {
		display: flex;
		gap: 16px;
		flex-wrap: wrap;
		align-items: end;
	}

	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
		min-width: 160px;
	}

	.filter-group label {
		font-size: 13px;
		font-weight: 600;
		color: #475569;
		text-transform: uppercase;
		letter-spacing: 0.025em;
	}

	.filter-select,
	.date-input {
		padding: 10px 12px;
		border: 2px solid #e2e8f0;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		transition: all 0.2s ease;
	}

	.filter-select:focus,
	.date-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filter-select {
		cursor: pointer;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		padding: 0;
		background: #ffffff;
	}

	.payments-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
		background: white;
	}

	.payments-table th {
		background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
		color: #475569;
		font-weight: 600;
		padding: 12px 10px;
		text-align: left;
		border-bottom: 2px solid #cbd5e1;
		position: sticky;
		top: 0;
		z-index: 10;
		white-space: nowrap;
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.025em;
	}

	.payments-table td {
		padding: 12px 10px;
		border-bottom: 1px solid #e2e8f0;
		vertical-align: top;
		background: white;
	}

	.payments-table tbody tr:hover {
		background: #f8fafc;
	}

	.payments-table tbody tr:nth-child(even) {
		background: #fafbfc;
	}

	.payments-table tbody tr:nth-child(even):hover {
		background: #f1f5f9;
	}

	/* Type Badges */
	.type-badge {
		display: inline-flex;
		align-items: center;
		padding: 4px 10px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.vendor-badge {
		background: #dbeafe;
		color: #1e40af;
	}

	.expense-badge {
		background: #fee2e2;
		color: #b91c1c;
	}

	/* Expense Row Styling */
	.expense-row {
		background: #fef2f2 !important;
	}

	.expense-row:hover {
		background: #fee2e2 !important;
	}

	.date-cell {
		font-weight: 500;
		color: #475569;
		min-width: 100px;
	}

	.amount-cell {
		font-weight: 700;
		color: #059669;
		text-align: right;
		font-family: 'JetBrains Mono', monospace;
		min-width: 120px;
	}

	.bill-number-cell {
		font-family: 'JetBrains Mono', monospace;
		color: #475569;
		font-weight: 600;
		min-width: 120px;
		background: #f8fafc;
		font-size: 13px;
	}

	.vendor-cell {
		min-width: 200px;
	}

	.vendor-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.vendor-name {
		font-weight: 600;
		color: #1e293b;
		line-height: 1.3;
	}

	.vendor-id {
		font-size: 12px;
		color: #64748b;
		font-weight: 500;
	}

	.category-cell {
		color: #475569;
		font-weight: 500;
		min-width: 150px;
	}

	.category-na {
		color: #94a3b8;
		font-style: italic;
	}

	.requisition-cell {
		font-family: 'JetBrains Mono', monospace;
		color: #475569;
		font-weight: 600;
		min-width: 120px;
		background: #fef3c7;
		font-size: 13px;
	}

	.co-cell {
		color: #475569;
		font-weight: 500;
		min-width: 150px;
	}

	.branch-cell {
		color: #475569;
		font-weight: 500;
		min-width: 150px;
	}

	.method-cell {
		min-width: 120px;
	}

	.payment-method {
		display: inline-block;
		padding: 6px 12px;
		background: linear-gradient(135deg, #ddd6fe 0%, #c4b5fd 100%);
		color: #5b21b6;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 600;
		text-align: center;
		border: 1px solid #a78bfa;
	}

	.status-cell {
		min-width: 100px;
	}

	.payment-status-badge {
		display: inline-block;
		padding: 6px 12px;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 600;
		text-align: center;
		white-space: nowrap;
	}

	.payment-status-badge.paid {
		background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
		color: #065f46;
		border: 1px solid #6ee7b7;
	}

	.bank-cell {
		min-width: 180px;
	}

	.bank-info {
		font-size: 12px;
		color: #475569;
		line-height: 1.4;
	}

	.bank-name {
		font-weight: 500;
		margin-bottom: 2px;
	}

	.iban {
		font-family: 'JetBrains Mono', monospace;
		color: #64748b;
	}

	.no-info {
		color: #9ca3af;
		font-style: italic;
	}

	.reference-cell {
		font-family: 'JetBrains Mono', monospace;
		color: #475569;
		font-size: 13px;
		min-width: 180px;
		position: relative;
	}

	.reference-display {
		cursor: pointer;
		padding: 6px 8px;
		border-radius: 4px;
		transition: all 0.2s ease;
		border: 1px solid transparent;
		min-height: 32px;
		display: flex;
		align-items: center;
	}

	.reference-display:hover {
		background: #f1f5f9;
		border-color: #cbd5e1;
	}

	.reference-display:empty::before {
		content: 'Click to add';
		color: #9ca3af;
		font-style: italic;
	}

	.reference-edit-container {
		display: flex;
		align-items: center;
		gap: 8px;
		width: 100%;
	}

	.reference-input {
		flex: 1;
		padding: 6px 8px;
		border: 2px solid #3b82f6;
		border-radius: 4px;
		font-size: 13px;
		font-family: 'JetBrains Mono', monospace;
		background: white;
		min-width: 120px;
	}

	.reference-input:focus {
		outline: none;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.reference-input:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.reference-edit-buttons {
		display: flex;
		gap: 4px;
		flex-shrink: 0;
	}

	.save-btn,
	.cancel-btn {
		padding: 4px 6px;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 12px;
		transition: all 0.2s ease;
		min-width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.save-btn {
		background: #22c55e;
		color: white;
	}

	.save-btn:hover:not(:disabled) {
		background: #16a34a;
		transform: scale(1.05);
	}

	.save-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.cancel-btn {
		background: #ef4444;
		color: white;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #dc2626;
		transform: scale(1.05);
	}

	.cancel-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.bill-cell {
		text-align: center;
		min-width: 100px;
	}

	.view-bill-btn {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 6px 12px;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 12px;
		font-weight: 600;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.view-bill-btn:hover {
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.view-bill-btn:active {
		transform: translateY(0);
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.no-bill {
		color: #9ca3af;
		font-style: italic;
		font-size: 12px;
	}

	.no-data {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 400px;
		text-align: center;
		color: #64748b;
		background: #f8fafc;
		margin: 20px;
		border-radius: 12px;
		border: 2px dashed #cbd5e1;
	}

	.no-data-icon {
		font-size: 48px;
		margin-bottom: 16px;
		opacity: 0.6;
	}

	.no-data h3 {
		font-size: 18px;
		font-weight: 600;
		color: #475569;
		margin: 0 0 8px 0;
	}

	.no-data p {
		font-size: 14px;
		color: #64748b;
		margin: 0;
	}

	/* Responsive design */
	@media (max-width: 1200px) {
		.payments-table {
			font-size: 13px;
		}
		
		.payments-table th,
		.payments-table td {
			padding: 8px 6px;
		}

		.vendor-name {
			font-size: 13px;
		}

		.window-header h2 {
			font-size: 20px;
		}

		.filter-row {
			gap: 12px;
		}

		.filter-group {
			min-width: 140px;
		}
	}

	@media (max-width: 768px) {
		.window-header {
			padding: 16px;
		}

		.filters-section {
			padding: 16px;
		}

		.search-row {
			flex-direction: column;
			align-items: stretch;
			gap: 12px;
		}

		.search-input-wrapper {
			max-width: none;
		}

		.filter-row {
			flex-direction: column;
			gap: 16px;
		}

		.filter-group {
			min-width: auto;
		}

		.payments-table {
			font-size: 12px;
		}
		
		.amount-cell {
			min-width: 100px;
		}

		.bill-number-cell {
			min-width: 100px;
			font-size: 12px;
		}
		
		.vendor-cell {
			min-width: 150px;
		}

		.branch-cell {
			min-width: 120px;
		}

		.reference-cell {
			min-width: 140px;
		}

		.reference-input {
			min-width: 80px;
			font-size: 12px;
		}

		.reference-edit-buttons {
			gap: 2px;
		}

		.save-btn,
		.cancel-btn {
			min-width: 20px;
			height: 20px;
			font-size: 10px;
		}
	}
</style>