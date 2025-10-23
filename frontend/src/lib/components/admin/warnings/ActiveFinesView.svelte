<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';

	let loading = true;
	let error = null;
	let activeFines = [];
	let filteredFines = [];
	
	// Filter options
	let searchTerm = '';
	let selectedBranch = 'all';
	let selectedStatus = 'all';
	let sortBy = 'amount_desc';
	let branches = [];

	// Pagination
	let currentPage = 1;
	let itemsPerPage = 10;
	let totalItems = 0;

	// Fine payment modal
	let showPaymentModal = false;
	let selectedFine = null;
	let paymentAmount = '';
	let paymentNote = '';
	let processingPayment = false;

	onMount(() => {
		loadBranches();
		loadActiveFines();
	});

	async function loadBranches() {
		try {
			const { data, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en')
				.order('name_en');

			if (branchError) throw branchError;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		}
	}

	async function loadActiveFines() {
		try {
			loading = true;
			error = null;

			let query = supabase
				.from('employee_warnings')
				.select(`
					*,
					branches!branch_id(name_en),
					hr_employees(name, employee_id)
				`)
				.eq('has_fine', true)
				.eq('is_deleted', false)
				.neq('fine_status', 'paid');

			if (selectedBranch !== 'all') {
				query = query.eq('branch_id', selectedBranch);
			}

			if (selectedStatus !== 'all') {
				query = query.eq('fine_status', selectedStatus);
			}

			const { data, error: queryError } = await query.order('issued_at', { ascending: false });

			if (queryError) throw queryError;

			activeFines = data || [];
			applyFiltersAndSorting();
		} catch (err) {
			console.error('Error loading active fines:', err);
			error = err.message;
		} finally {
			loading = false;
		}
	}

	function applyFiltersAndSorting() {
		let filtered = [...activeFines];

		// Apply search filter
		if (searchTerm.trim()) {
			const search = searchTerm.toLowerCase();
			filtered = filtered.filter(fine => 
				fine.hr_employees?.employee_id?.toLowerCase().includes(search) ||
				fine.hr_employees?.name?.toLowerCase().includes(search) ||
				fine.branches?.name_en?.toLowerCase().includes(search)
			);
		}

		// Apply sorting
		filtered.sort((a, b) => {
			switch (sortBy) {
				case 'amount_desc':
					return parseFloat(b.fine_amount || 0) - parseFloat(a.fine_amount || 0);
				case 'amount_asc':
					return parseFloat(a.fine_amount || 0) - parseFloat(b.fine_amount || 0);
				case 'date_desc':
					return new Date(b.issued_at).getTime() - new Date(a.issued_at).getTime();
				case 'date_asc':
					return new Date(a.issued_at).getTime() - new Date(b.issued_at).getTime();
				case 'employee':
					const nameA = a.hr_employees?.name || '';
					const nameB = b.hr_employees?.name || '';
					return nameA.localeCompare(nameB);
				default:
					return 0;
			}
		});

		filteredFines = filtered;
		totalItems = filtered.length;
		currentPage = 1; // Reset to first page when filters change
	}

	function getPaginatedFines() {
		const start = (currentPage - 1) * itemsPerPage;
		const end = start + itemsPerPage;
		return filteredFines.slice(start, end);
	}

	function getTotalPages() {
		return Math.ceil(totalItems / itemsPerPage);
	}

	function goToPage(page) {
		if (page >= 1 && page <= getTotalPages()) {
			currentPage = page;
		}
	}

	function handleFilterChange() {
		applyFiltersAndSorting();
	}

	function openPaymentModal(fine) {
		selectedFine = fine;
		paymentAmount = fine.fine_amount;
		paymentNote = '';
		showPaymentModal = true;
	}

	function closePaymentModal() {
		showPaymentModal = false;
		selectedFine = null;
		paymentAmount = '';
		paymentNote = '';
		processingPayment = false;
	}

	async function processPayment() {
		if (!selectedFine || !paymentAmount) return;

		try {
			processingPayment = true;

			const { error: updateError } = await supabase
				.from('employee_warnings')
				.update({
					fine_status: 'paid',
					fine_paid_amount: parseFloat(paymentAmount),
					fine_paid_at: new Date().toISOString(),
					fine_payment_note: paymentNote || null,
					warning_status: 'resolved',  // Mark warning as resolved when fine is paid
					updated_at: new Date().toISOString()
				})
				.eq('id', selectedFine.id);

			if (updateError) throw updateError;

			// Refresh the list
			await loadActiveFines();
			closePaymentModal();
		} catch (err) {
			console.error('Error processing payment:', err);
			alert('Error processing payment: ' + err.message);
		} finally {
			processingPayment = false;
		}
	}

	function viewWarningDetails(warning) {
		// Open warning details in a new window
		const windowId = `warning-details-${Date.now()}`;
		openWindow({
			id: windowId,
			title: `Warning Details - ${warning.hr_employees?.employee_id || 'Unknown'}`,
			component: null, // This would need to be created as a proper component
			icon: '⚠️',
			size: { width: 800, height: 600 },
			position: { x: 100, y: 100 },
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function formatCurrency(amount) {
		return new Intl.NumberFormat('en-US', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(parseFloat(amount) || 0);
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-GB', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric'
		});
	}

	function getStatusColor(status) {
		const colorMap = {
			'pending': 'text-yellow-700 bg-yellow-100 border-yellow-200',
			'overdue': 'text-red-700 bg-red-100 border-red-200',
			'partial': 'text-blue-700 bg-blue-100 border-blue-200'
		};
		return colorMap[status] || colorMap.pending;
	}

	function getDaysOverdue(issuedAt) {
		const issued = new Date(issuedAt);
		const today = new Date();
		const diffTime = today.getTime() - issued.getTime();
		const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
		return diffDays > 30 ? diffDays - 30 : 0; // Assuming 30 days grace period
	}

	// Reactive statement to handle search and filter changes
	$: {
		if (searchTerm !== undefined || selectedBranch !== undefined || selectedStatus !== undefined || sortBy !== undefined) {
			applyFiltersAndSorting();
		}
	}
</script>

<div class="active-fines">
	<!-- Header -->
	<div class="header">
		<div class="title-section">
			<h1 class="title">Active Fines Management</h1>
			<p class="subtitle">Track and manage pending fine payments</p>
		</div>
		<div class="header-actions">
			<button on:click={loadActiveFines} class="refresh-btn" disabled={loading}>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
				</svg>
				Refresh
			</button>
		</div>
	</div>

	<!-- Filters -->
	<div class="filters">
		<div class="search-box">
			<svg class="search-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
			</svg>
			<input
				type="text"
				placeholder="Search by employee ID, name, or branch..."
				bind:value={searchTerm}
				on:input={handleFilterChange}
				class="search-input"
			/>
		</div>

		<select bind:value={selectedBranch} on:change={handleFilterChange} class="filter-select">
			<option value="all">All Branches</option>
			{#each branches as branch}
				<option value={branch.id}>{branch.name_en}</option>
			{/each}
		</select>

		<select bind:value={selectedStatus} on:change={handleFilterChange} class="filter-select">
			<option value="all">All Statuses</option>
			<option value="pending">Pending</option>
			<option value="overdue">Overdue</option>
			<option value="partial">Partial Payment</option>
		</select>

		<select bind:value={sortBy} on:change={handleFilterChange} class="filter-select">
			<option value="amount_desc">Amount (High to Low)</option>
			<option value="amount_asc">Amount (Low to High)</option>
			<option value="date_desc">Date (Newest)</option>
			<option value="date_asc">Date (Oldest)</option>
			<option value="employee">Employee Name</option>
		</select>
	</div>

	{#if error}
		<div class="error-message">
			Error: {error}
		</div>
	{/if}

	{#if loading}
		<div class="loading-section">
			<div class="loading-spinner"></div>
			<p>Loading active fines...</p>
		</div>
	{:else}
		<!-- Summary Stats -->
		<div class="summary-stats">
			<div class="stat-card">
				<h3>Total Active Fines</h3>
				<p class="stat-value">{filteredFines.length}</p>
			</div>
			<div class="stat-card">
				<h3>Total Amount</h3>
				<p class="stat-value">
					{formatCurrency(filteredFines.reduce((sum, fine) => sum + parseFloat(fine.fine_amount || 0), 0))}
				</p>
			</div>
			<div class="stat-card">
				<h3>Overdue Fines</h3>
				<p class="stat-value text-red-600">
					{filteredFines.filter(fine => getDaysOverdue(fine.issued_at) > 0).length}
				</p>
			</div>
		</div>

		<!-- Fines Table -->
		<div class="table-container">
			<table class="fines-table">
				<thead>
					<tr>
						<th>Employee</th>
						<th>Branch</th>
						<th>Warning Date</th>
						<th>Fine Amount</th>
						<th>Status</th>
						<th>Days Outstanding</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each getPaginatedFines() as fine}
						<tr class="fine-row">
							<td class="employee-cell">
								<div class="employee-info">
									<div class="employee-name">
										{fine.hr_employees?.name || 'Unknown'}
									</div>
									<div class="employee-id">ID: {fine.hr_employees?.employee_id || 'N/A'}</div>
								</div>
							</td>
							<td>{fine.branches?.name_en || 'Unknown'}</td>
							<td>{formatDate(fine.issued_at)}</td>
							<td class="amount-cell">
								{formatCurrency(fine.fine_amount)}
							</td>
							<td>
								<span class="status-badge {getStatusColor(fine.fine_status)}">
									{fine.fine_status}
								</span>
								{#if getDaysOverdue(fine.issued_at) > 0}
									<span class="overdue-badge">
										{getDaysOverdue(fine.issued_at)} days overdue
									</span>
								{/if}
							</td>
							<td>
								{Math.floor((new Date().getTime() - new Date(fine.issued_at).getTime()) / (1000 * 60 * 60 * 24))} days
							</td>
							<td class="actions-cell">
								<button 
									on:click={() => viewWarningDetails(fine)}
									class="action-btn view-btn"
									title="View Warning Details"
								>
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
									</svg>
								</button>
								<button 
									on:click={() => openPaymentModal(fine)}
									class="action-btn payment-btn"
									title="Record Payment"
								>
									<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"/>
									</svg>
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>

			{#if filteredFines.length === 0}
				<div class="no-data">
					<svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
					</svg>
					<p>No active fines found</p>
				</div>
			{/if}
		</div>

		<!-- Pagination -->
		{#if getTotalPages() > 1}
			<div class="pagination">
				<button 
					on:click={() => goToPage(currentPage - 1)}
					disabled={currentPage === 1}
					class="pagination-btn"
				>
					Previous
				</button>
				
				{#each Array(getTotalPages()).fill(0) as _, i}
					<button 
						on:click={() => goToPage(i + 1)}
						class="pagination-btn {currentPage === i + 1 ? 'active' : ''}"
					>
						{i + 1}
					</button>
				{/each}
				
				<button 
					on:click={() => goToPage(currentPage + 1)}
					disabled={currentPage === getTotalPages()}
					class="pagination-btn"
				>
					Next
				</button>
			</div>
		{/if}
	{/if}
</div>

<!-- Payment Modal -->
{#if showPaymentModal && selectedFine}
	<div class="modal-overlay" on:click={closePaymentModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Record Fine Payment</h2>
				<button on:click={closePaymentModal} class="close-btn">
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
					</svg>
				</button>
			</div>
			
			<div class="modal-body">
				<div class="fine-details">
					<h3>Fine Details</h3>
					<p><strong>Employee:</strong> {selectedFine.hr_employees?.name || 'Unknown'}</p>
					<p><strong>Employee ID:</strong> {selectedFine.hr_employees?.employee_id}</p>
					<p><strong>Fine Amount:</strong> {formatCurrency(selectedFine.fine_amount)}</p>
					<p><strong>Issued Date:</strong> {formatDate(selectedFine.issued_at)}</p>
				</div>

				<div class="payment-form">
					<div class="form-group">
						<label for="payment-amount">Payment Amount</label>
						<input
							id="payment-amount"
							type="number"
							step="0.01"
							min="0"
							max={selectedFine.fine_amount}
							bind:value={paymentAmount}
							class="form-input"
							placeholder="Enter payment amount"
						/>
					</div>

					<div class="form-group">
						<label for="payment-note">Payment Note (Optional)</label>
						<textarea
							id="payment-note"
							bind:value={paymentNote}
							class="form-textarea"
							placeholder="Add any notes about the payment..."
							rows="3"
						></textarea>
					</div>
				</div>
			</div>

			<div class="modal-footer">
				<button on:click={closePaymentModal} class="cancel-btn" disabled={processingPayment}>
					Cancel
				</button>
				<button 
					on:click={processPayment} 
					class="confirm-btn"
					disabled={processingPayment || !paymentAmount || parseFloat(paymentAmount) <= 0}
				>
					{#if processingPayment}
						Processing...
					{:else}
						Record Payment
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.active-fines {
		padding: 24px;
		background: white;
		height: 100%;
		overflow-y: auto;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.subtitle {
		font-size: 14px;
		color: #6b7280;
		margin: 4px 0 0 0;
	}

	.header-actions {
		display: flex;
		gap: 8px;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 8px 16px;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.filters {
		display: flex;
		gap: 16px;
		margin-bottom: 24px;
		flex-wrap: wrap;
	}

	.search-box {
		position: relative;
		flex: 1;
		min-width: 250px;
	}

	.search-icon {
		position: absolute;
		left: 12px;
		top: 50%;
		transform: translateY(-50%);
		width: 16px;
		height: 16px;
		color: #6b7280;
	}

	.search-input {
		width: 100%;
		padding: 8px 8px 8px 40px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filter-select {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
		min-width: 150px;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 16px;
		border-radius: 8px;
		margin-bottom: 24px;
	}

	.loading-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px;
		color: #6b7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top: 3px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.summary-stats {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 16px;
		margin-bottom: 24px;
	}

	.stat-card {
		background: #f8fafc;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 16px;
		text-align: center;
	}

	.stat-card h3 {
		font-size: 14px;
		color: #6b7280;
		margin: 0 0 8px 0;
	}

	.stat-value {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.table-container {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
		margin-bottom: 20px;
	}

	.fines-table {
		width: 100%;
		border-collapse: collapse;
	}

	.fines-table th {
		background: #f9fafb;
		color: #374151;
		font-weight: 600;
		padding: 12px 16px;
		text-align: left;
		border-bottom: 1px solid #e5e7eb;
		font-size: 14px;
	}

	.fine-row {
		border-bottom: 1px solid #f3f4f6;
		transition: background-color 0.15s ease;
	}

	.fine-row:hover {
		background: #f8fafc;
	}

	.fine-row td {
		padding: 12px 16px;
		font-size: 14px;
		color: #374151;
	}

	.employee-cell {
		min-width: 200px;
	}

	.employee-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.employee-name {
		font-weight: 500;
		color: #111827;
	}

	.employee-id {
		font-size: 12px;
		color: #6b7280;
	}

	.amount-cell {
		font-weight: 600;
		color: #dc2626;
	}

	.status-badge {
		display: inline-block;
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 500;
		text-transform: capitalize;
		border: 1px solid;
	}

	.overdue-badge {
		display: block;
		font-size: 11px;
		color: #dc2626;
		font-weight: 500;
		margin-top: 2px;
	}

	.actions-cell {
		white-space: nowrap;
	}

	.action-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
		margin-right: 8px;
	}

	.view-btn {
		background: #3b82f6;
		color: white;
	}

	.view-btn:hover {
		background: #2563eb;
	}

	.payment-btn {
		background: #10b981;
		color: white;
	}

	.payment-btn:hover {
		background: #059669;
	}

	.no-data {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px;
		color: #6b7280;
	}

	.pagination {
		display: flex;
		justify-content: center;
		gap: 8px;
		margin-top: 20px;
	}

	.pagination-btn {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		background: white;
		color: #374151;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.pagination-btn:hover:not(:disabled) {
		background: #f3f4f6;
	}

	.pagination-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.pagination-btn.active {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
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
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		max-width: 500px;
		width: 90%;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h2 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.close-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 32px;
		height: 32px;
		border: none;
		background: none;
		color: #6b7280;
		cursor: pointer;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.modal-body {
		padding: 24px;
	}

	.fine-details {
		background: #f8fafc;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 24px;
	}

	.fine-details h3 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 12px 0;
	}

	.fine-details p {
		margin: 4px 0;
		font-size: 14px;
		color: #374151;
	}

	.payment-form {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.form-group label {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.form-input, .form-textarea {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s;
	}

	.form-input:focus, .form-textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 20px 24px;
		border-top: 1px solid #e5e7eb;
	}

	.cancel-btn, .confirm-btn {
		padding: 8px 16px;
		border: 1px solid;
		border-radius: 6px;
		font-size: 14px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.cancel-btn {
		background: white;
		color: #374151;
		border-color: #d1d5db;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #f3f4f6;
	}

	.confirm-btn {
		background: #10b981;
		color: white;
		border-color: #10b981;
	}

	.confirm-btn:hover:not(:disabled) {
		background: #059669;
	}

	.cancel-btn:disabled, .confirm-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	@media (max-width: 768px) {
		.filters {
			flex-direction: column;
		}
		
		.search-box {
			min-width: auto;
		}
		
		.summary-stats {
			grid-template-columns: 1fr;
		}
		
		.fines-table {
			font-size: 12px;
		}
		
		.fines-table th,
		.fine-row td {
			padding: 8px 12px;
		}
	}
</style>