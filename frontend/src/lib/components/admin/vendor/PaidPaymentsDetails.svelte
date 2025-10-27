<script>
	import { supabase } from '$lib/utils/supabase';

	// Props
	export let payments = [];

	// Filter and search state
	let searchQuery = '';
	let selectedBranch = '';
	let selectedPaymentMethod = '';
	let dateFrom = '';
	let dateTo = '';
	let filteredPayments = [];

	// Reference editing state
	let editingReference = null;
	let editingValue = '';
	let isUpdating = false;

	// Get unique values for filters
	$: uniqueBranches = [...new Set(payments.map(p => p.receiving_records?.branches?.name_en).filter(Boolean))].sort();
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

			// Branch filter
			if (selectedBranch && payment.receiving_records?.branches?.name_en !== selectedBranch) {
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
}

// Calculate filtered totals
$: filteredTotal = filteredPayments.reduce((sum, p) => sum + (parseFloat(p.final_bill_amount || p.bill_amount) || 0), 0);	// Format currency
	function formatCurrency(amount) {
		if (!amount) return 'SAR 0.00';
		return `SAR ${parseFloat(amount).toFixed(2)}`;
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
		dateFrom = '';
		dateTo = '';
	}

	// Start editing reference
	function startEditReference(paymentId, currentReference) {
		editingReference = paymentId;
		editingValue = currentReference || '';
	}

	// Cancel editing reference
	function cancelEditReference() {
		editingReference = null;
		editingValue = '';
	}

	// Update reference number
	async function updateReference(paymentId) {
		if (isUpdating) return;
		
		isUpdating = true;
		try {
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

			// Clear editing state
			editingReference = null;
			editingValue = '';
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
			Showing: {filteredPayments.length} of {payments.length} records | 
			Filtered Total: {formatCurrency(filteredTotal)} | 
			Grand Total: {formatCurrency(payments.reduce((sum, p) => sum + (parseFloat(p.final_bill_amount || p.bill_amount) || 0), 0))}
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
			
			{#if searchQuery || selectedBranch || selectedPaymentMethod || dateFrom || dateTo}
				<button class="clear-filters-btn" on:click={clearFilters}>
					Clear Filters
				</button>
			{/if}
		</div>

		<div class="filter-row">
			<div class="filter-group">
				<label for="branch-filter">Branch:</label>
				<select id="branch-filter" bind:value={selectedBranch} class="filter-select">
					<option value="">All Branches</option>
					{#each uniqueBranches as branch}
						<option value={branch}>{branch}</option>
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
		{#if filteredPayments.length > 0}
			<table class="payments-table">
				<thead>
					<tr>
						<th>Transaction Date</th>
						<th>Amount</th>
						<th>Bill Number</th>
						<th>Vendor</th>
						<th>Branch</th>
						<th>Payment Method</th>
						<th>Payment Status</th>
						<th>Bank Info</th>
						<th>Reference</th>
						<th>Bill</th>
					</tr>
				</thead>
				<tbody>
					{#each filteredPayments as payment}
						<tr>
							<td class="date-cell">
								{new Date(payment.paid_date || payment.transaction_date).toLocaleDateString('en-GB')}
							</td>
							<td class="amount-cell">
								{formatCurrency(payment.final_bill_amount || payment.bill_amount)}
							</td>
							<td class="bill-number-cell">
								{payment.bill_number || 'N/A'}
							</td>
							<td class="vendor-cell">
								<div class="vendor-info">
									<div class="vendor-name">
										{payment.vendor_name || 'N/A'}
									</div>
									<div class="vendor-id">
										ID: {payment.receiving_records?.vendor_id || 'N/A'}
									</div>
								</div>
							</td>
							<td class="branch-cell">
								{payment.receiving_records?.branches?.name_en || 'N/A'}
							</td>
							<td class="method-cell">
								<div class="payment-method">
									{payment.payment_method || 'N/A'}
								</div>
							</td>
							<td class="status-cell">
								<div class="payment-status-badge paid">
									✓ Paid
								</div>
							</td>
							<td class="bank-cell">
								<div class="bank-info">
									{#if payment.bank_name}
										<div class="bank-name">Bank: {payment.bank_name}</div>
									{/if}
									{#if payment.iban}
										<div class="iban">IBAN: {payment.iban}</div>
									{/if}
									{#if !payment.bank_name && !payment.iban}
										<span class="no-info">N/A</span>
									{/if}
								</div>
							</td>
							<td class="reference-cell">
								{#if editingReference === payment.id}
									<div class="reference-edit-container">
										<input 
											type="text" 
											bind:value={editingValue}
											on:keypress={(e) => handleKeyPress(e, payment.id)}
											class="reference-input"
											placeholder="Enter reference number"
											disabled={isUpdating}
											autofocus
										/>
										<div class="reference-edit-buttons">
											<button 
												class="save-btn" 
												on:click={() => updateReference(payment.id)}
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
										on:click={() => startEditReference(payment.id, payment.payment_reference)}
										title="Click to edit reference number"
									>
										{payment.payment_reference || 'Click to add'}
									</div>
								{/if}
							</td>
							<td class="bill-cell">
								{#if payment.receiving_records?.original_bill_url}
									<button 
										class="view-bill-btn" 
										on:click={() => viewOriginalBill(payment.receiving_records.original_bill_url)}
										title="View Original Bill"
									>
										{#if payment.receiving_records.original_bill_url.toLowerCase().includes('.pdf')}
											📄 PDF
										{:else}
											🖼️ Image
										{/if}
									</button>
								{:else}
									<span class="no-bill">No Bill</span>
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
					{#if payments.length === 0}
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