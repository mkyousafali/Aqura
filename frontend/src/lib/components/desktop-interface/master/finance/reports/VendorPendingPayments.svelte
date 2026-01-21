<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	let loading = true;
	let vendors: Array<{ vendor_id: string; vendor_name: string }> = [];
	let selectedVendorId = '';
	let selectedVendorName = '';
	let payments: any[] = [];
	let loadingPayments = false;
	let searchQuery = '';
	let loadingProgress = 0;
	let branches: Array<{ id: number; name_en: string; name_ar: string }> = [];
	let selectedBranchId = '';
	let selectedPaymentMethod = '';
	let paymentMethods: string[] = [];
	let totalVendorCount = 0;
	let totalUnpaidAmount = 0;

	// Pagination
	let currentPage = 1;
	let pageSize = 10;

	// Edit Modal
	let showEditModal = false;
	let editingPayment: any = null;
	let editFormData = {
		due_date: '',
		branch_id: '',
		payment_method: ''
	};
	let savingEdit = false;

	// Filtered vendors based on search
	$: filteredVendors = vendors.filter(v => 
		v.vendor_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
		v.vendor_id.toLowerCase().includes(searchQuery.toLowerCase())
	);

	// Filtered payments based on branch and payment method
	$: filteredPayments = payments.filter(payment => {
		const branchMatch = !selectedBranchId || payment.branch_id?.toString() === selectedBranchId;
		const methodMatch = !selectedPaymentMethod || payment.payment_method === selectedPaymentMethod;
		return branchMatch && methodMatch;
	});

	// Pagination calculations (derived from filteredPayments)
	$: totalRecords = filteredPayments.length;
	$: totalPages = Math.ceil(totalRecords / pageSize);
	$: startRecord = (currentPage - 1) * pageSize + 1;
	$: endRecord = Math.min(currentPage * pageSize, totalRecords);

	// Paginated payments for display
	$: paginatedPayments = filteredPayments.slice(
		(currentPage - 1) * pageSize,
		currentPage * pageSize
	);

	// Reset to page 1 when filters change and current page is out of bounds
	$: if (currentPage > totalPages && totalPages > 0) {
		currentPage = 1;
	}

	// Calculate total amount
	$: totalAmount = filteredPayments.reduce((sum, payment) => {
		return sum + (payment.final_bill_amount || 0);
	}, 0);

	onMount(async () => {
		await Promise.all([loadVendors(), loadBranches(), loadSummary(), loadAllPaymentMethods()]);
		loading = false;
	});

	async function loadAllPaymentMethods() {
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('payment_method')
				.not('payment_method', 'is', null)
				.eq('is_paid', false);

			if (error) throw error;

			// Extract unique payment methods
			const methods = new Set<string>();
			data?.forEach(item => {
				if (item.payment_method) {
					methods.add(item.payment_method);
				}
			});
			paymentMethods = Array.from(methods).sort();
		} catch (error) {
			console.error('Error loading payment methods:', error);
		}
	}

	async function loadSummary() {
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select('vendor_id, final_bill_amount')
				.eq('is_paid', false);

			if (error) throw error;

			// Count unique vendors
			const uniqueVendors = new Set(data?.map(item => item.vendor_id));
			totalVendorCount = uniqueVendors.size;

			// Calculate total unpaid amount
			totalUnpaidAmount = data?.reduce((sum, item) => sum + (item.final_bill_amount || 0), 0) || 0;
		} catch (error) {
			console.error('Error loading summary:', error);
		}
	}

	async function loadBranches() {
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;

			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
			branches = [];
		}
	}

	async function loadVendors() {
		try {
			const pageSize = 500;
			let page = 0;
			let hasMore = true;
			const vendorMap = new Map();
			let totalLoaded = 0;

			while (hasMore) {
				const from = page * pageSize;
				const to = from + pageSize - 1;

			const { data, error, count } = await supabase
				.from('vendor_payment_schedule')
				.select('vendor_id, vendor_name', { count: 'exact' })
				.eq('is_paid', false)
				.range(from, to);				if (error) throw error;

				if (!data || data.length === 0) {
					hasMore = false;
					break;
				}

				// Add unique vendors to map
				for (const item of data) {
					if (item.vendor_id && item.vendor_name && !vendorMap.has(item.vendor_id)) {
						vendorMap.set(item.vendor_id, {
							vendor_id: item.vendor_id,
							vendor_name: item.vendor_name
						});
					}
				}

				totalLoaded += data.length;
				
				// Update progress
				if (count) {
					loadingProgress = Math.round((totalLoaded / count) * 100);
				}

				// Check if we have more data
				hasMore = data.length === pageSize;
				page++;

				// Update vendors array progressively
				vendors = Array.from(vendorMap.values()).sort((a, b) => 
					a.vendor_name.localeCompare(b.vendor_name)
				);
			}

			loadingProgress = 100;
		} catch (error) {
			console.error('Error loading vendors:', error);
			vendors = [];
		}
	}

	async function handleVendorSelect(vendorId: string, vendorName: string) {
		selectedVendorId = vendorId;
		selectedVendorName = vendorName;
		searchQuery = '';
		currentPage = 1; // Reset pagination
		await loadPayments();
	}

	async function loadPayments() {
		if (!selectedVendorId) return;

		loadingPayments = true;
		try {
			const { data, error } = await supabase
				.from('vendor_payment_schedule')
				.select(`
					*,
					branches!branch_id (
						name_en,
						name_ar
					)
				`)
				.eq('vendor_id', selectedVendorId)
				.eq('is_paid', false)
				.order('due_date', { ascending: true });

			if (error) throw error;

			payments = data || [];
		} catch (error) {
			console.error('Error loading payments:', error);
			payments = [];
		} finally {
			loadingPayments = false;
		}
	}

	function clearSelection() {
		selectedVendorId = '';
		selectedVendorName = '';
		payments = [];
		searchQuery = '';
		selectedBranchId = '';
		selectedPaymentMethod = '';
		paymentMethods = [];
		currentPage = 1;
	}

	function openEditModal(payment: any) {
		editingPayment = payment;
		editFormData = {
			due_date: payment.due_date || '',
			branch_id: payment.branch_id?.toString() || '',
			payment_method: payment.payment_method || ''
		};
		// Load payment methods before opening modal
		loadAllPaymentMethods();
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		editingPayment = null;
		editFormData = {
			due_date: '',
			branch_id: '',
			payment_method: ''
		};
	}

	async function saveEdit() {
		if (!editingPayment) return;

		savingEdit = true;
		try {
			const { error } = await supabase
				.from('vendor_payment_schedule')
				.update({
					due_date: editFormData.due_date,
					branch_id: parseInt(editFormData.branch_id),
					payment_method: editFormData.payment_method
				})
				.eq('id', editingPayment.id);

			if (error) throw error;

			// Update the local payments array
			payments = payments.map(p => 
				p.id === editingPayment.id 
					? { 
						...p, 
						due_date: editFormData.due_date,
						branch_id: parseInt(editFormData.branch_id),
						payment_method: editFormData.payment_method,
						branches: branches.find(b => b.id.toString() === editFormData.branch_id)
					}
					: p
			);

			closeEditModal();
		} catch (error) {
			console.error('Error saving edit:', error);
			alert('Failed to save changes. Please try again.');
		} finally {
			savingEdit = false;
		}
	}

	function goToPage(page: number) {
		if (page >= 1 && page <= totalPages) {
			currentPage = page;
		}
	}

	function nextPage() {
		if (currentPage < totalPages) {
			currentPage++;
		}
	}

	function previousPage() {
		if (currentPage > 1) {
			currentPage--;
		}
	}

	function formatDate(dateString: string): string {
		if (!dateString) return '-';
		const date = new Date(dateString);
		const day = String(date.getDate()).padStart(2, '0');
		const month = String(date.getMonth() + 1).padStart(2, '0');
		const year = date.getFullYear();
		return `${day}/${month}/${year}`;
	}
</script>

<div class="vendor-pending-payments">
	<div class="content">
		{#if loading}
			<div class="loading">
				<p>Loading vendors...</p>
				{#if loadingProgress > 0}
					<div class="progress-bar">
						<div class="progress-fill" style="width: {loadingProgress}%"></div>
					</div>
					<p class="progress-text">{loadingProgress}%</p>
				{/if}
			</div>
		{:else}
			<!-- Summary Card -->
			<div class="summary-card">
				<h3>Unpaid Payments Summary</h3>
				<div class="summary-stats">
					<div class="summary-item">
						<div class="summary-icon">👥</div>
						<div class="summary-details">
							<div class="summary-label">Total Vendors</div>
							<div class="summary-value">{totalVendorCount}</div>
						</div>
					</div>
					<div class="summary-item">
						<div class="summary-icon">💰</div>
						<div class="summary-details">
							<div class="summary-label">Total Unpaid Amount</div>
							<div class="summary-value amount">{totalUnpaidAmount.toLocaleString()}</div>
						</div>
					</div>
				</div>
			</div>

			<!-- Search Card -->
			<div class="search-card">
				<div class="search-header">
					<h3>Select Vendor</h3>
					{#if selectedVendorId}
						<button class="clear-btn" on:click={clearSelection}>Clear</button>
					{/if}
				</div>
				
				{#if !selectedVendorId}
					<div class="search-box">
						<input
							type="text"
							placeholder="Search vendor by name or ID..."
							bind:value={searchQuery}
							class="search-input"
						/>
						{#if searchQuery && filteredVendors.length > 0}
							<div class="vendor-dropdown">
								{#each filteredVendors as vendor}
									<button
										class="vendor-item"
										on:click={() => handleVendorSelect(vendor.vendor_id, vendor.vendor_name)}
									>
										<div class="vendor-name">{vendor.vendor_name}</div>
										<div class="vendor-id">{vendor.vendor_id}</div>
									</button>
								{/each}
							</div>
						{/if}
					</div>
				{:else}
					<div class="selected-vendor">
						<div class="vendor-info">
							<span class="label">Selected Vendor:</span>
							<span class="vendor-name">{selectedVendorName}</span>
							<span class="vendor-id">({selectedVendorId})</span>
						</div>
					</div>
				{/if}
			</div>

			<!-- Payments Table -->
			{#if selectedVendorId}
				<div class="filters-card">
					<div class="filters-row">
						<div class="filter-group">
							<label for="branch-filter">Filter by Branch:</label>
							<select id="branch-filter" bind:value={selectedBranchId} class="filter-select">
								<option value="">All Branches</option>
								{#each branches as branch}
									<option value={branch.id.toString()}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
								{/each}
							</select>
						</div>
						<div class="filter-group">
							<label for="method-filter">Filter by Payment Method:</label>
							<select id="method-filter" bind:value={selectedPaymentMethod} class="filter-select">
								<option value="">All Methods</option>
								{#each paymentMethods as method}
									<option value={method}>{method}</option>
								{/each}
							</select>
						</div>
					</div>
				</div>

				{#if loadingPayments}
					<div class="loading-payments">
						<p>Loading payments...</p>
					</div>
				{:else if filteredPayments.length > 0}
					<div class="table-header-info">
						<div class="table-stats">
							<span class="stat-label">Total Records:</span>
							<span class="stat-value">{filteredPayments.length}</span>
							<span class="stat-separator">|</span>
							<span class="stat-label">Showing:</span>
							<span class="stat-value">{startRecord}-{endRecord} of {totalRecords}</span>
							<span class="stat-separator">|</span>
							<span class="stat-label">Total Amount:</span>
							<span class="stat-value amount">{totalAmount.toLocaleString()}</span>
						</div>
					</div>
					<div class="table-container">
						<table class="payments-table">
							<thead>
								<tr>
									<th>Branch</th>
									<th>Bill Date</th>
									<th>Due Date</th>
									<th>Amount</th>
									<th>Payment Method</th>
									<th>Invoice Number</th>
									<th>Status</th>
									<th>Action</th>
								</tr>
							</thead>
							<tbody>
							{#each paginatedPayments as payment}
								<tr>
									<td>{payment.branches?.name_en || payment.branch_name || '-'}</td>
									<td>{formatDate(payment.bill_date)}</td>
									<td>{formatDate(payment.due_date)}</td>
									<td class="amount">{payment.final_bill_amount?.toLocaleString() || 'N/A'}</td>
									<td>{payment.payment_method || '-'}</td>
									<td>{payment.bill_number || '-'}</td>
									<td>
										<span class="status-badge unpaid">Unpaid</span>
									</td>
									<td>
										<button class="edit-btn" on:click={() => openEditModal(payment)} title="Edit payment details">
											✎ Edit
										</button>
									</td>
								</tr>
							{/each}
							</tbody>
						</table>
					</div>

					<!-- Pagination Controls -->
					{#if totalPages > 1}
						<div class="pagination">
							<button 
								class="pagination-btn" 
								on:click={previousPage}
								disabled={currentPage === 1}
							>
								← Previous
							</button>
							
							<div class="pagination-info">
								<span>Page</span>
								<input 
									type="number" 
									min="1" 
									max={totalPages}
									bind:value={currentPage}
									class="page-input"
								/>
								<span>of {totalPages}</span>
							</div>

							<button 
								class="pagination-btn" 
								on:click={nextPage}
								disabled={currentPage === totalPages}
							>
								Next →
							</button>
						</div>
					{/if}
				{:else}
					<div class="no-data">
						<p>No unpaid payments found {selectedBranchId || selectedPaymentMethod ? 'matching the selected filters' : 'for this vendor'}.</p>
					</div>
				{/if}
			{/if}
		{/if}
	</div>

	<!-- Edit Modal -->
	{#if showEditModal && editingPayment}
		<div class="modal-overlay" on:click={closeEditModal}>
			<div class="modal-content" on:click={e => e.stopPropagation()}>
				<div class="modal-header">
					<h2>Edit Payment Details</h2>
					<button class="close-btn" on:click={closeEditModal}>✕</button>
				</div>

				<div class="modal-body">
					<div class="form-group">
						<label for="edit-due-date">Due Date:</label>
						<input
							id="edit-due-date"
							type="date"
							bind:value={editFormData.due_date}
							class="form-input"
						/>
					</div>

					<div class="form-group">
						<label for="edit-branch">Branch:</label>
						<select id="edit-branch" bind:value={editFormData.branch_id} class="form-input">
							<option value="">Select Branch</option>
							{#each branches as branch}
								<option value={branch.id.toString()}>{branch.location_en ? `${branch.name_en} - ${branch.location_en}` : branch.name_en}</option>
							{/each}
						</select>
					</div>

					<div class="form-group">
						<label for="edit-method">Payment Method:</label>
						<select id="edit-method" bind:value={editFormData.payment_method} class="form-input">
							<option value="">Select Payment Method</option>
							{#each paymentMethods as method}
								<option value={method}>{method}</option>
							{/each}
						</select>
					</div>
				</div>

				<div class="modal-footer">
					<button class="btn-cancel" on:click={closeEditModal} disabled={savingEdit}>
						Cancel
					</button>
					<button class="btn-save" on:click={saveEdit} disabled={savingEdit}>
						{savingEdit ? 'Saving...' : 'Save Changes'}
					</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.vendor-pending-payments {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: white;
		overflow: hidden;
	}

	.content {
		flex: 1;
		overflow: auto;
		padding: 1.5rem;
	}

	.loading {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		height: 100%;
		gap: 1rem;
	}

	.progress-bar {
		width: 300px;
		height: 8px;
		background: #e5e7eb;
		border-radius: 4px;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: #3b82f6;
		transition: width 0.3s ease;
	}

	.progress-text {
		color: #6b7280;
		font-size: 0.875rem;
		margin: 0;
	}

	.search-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.search-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.search-header h3 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #111827;
	}

	.clear-btn {
		padding: 0.5rem 1rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: background 0.2s;
	}

	.clear-btn:hover {
		background: #dc2626;
	}

	.search-box {
		position: relative;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 1rem;
		transition: border-color 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.vendor-dropdown {
		position: absolute;
		top: 100%;
		left: 0;
		right: 0;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		margin-top: 0.5rem;
		max-height: 300px;
		overflow-y: auto;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		z-index: 10;
	}

	.vendor-item {
		width: 100%;
		padding: 0.75rem 1rem;
		border: none;
		background: white;
		text-align: left;
		cursor: pointer;
		transition: background 0.2s;
		border-bottom: 1px solid #f3f4f6;
	}

	.vendor-item:last-child {
		border-bottom: none;
	}

	.vendor-item:hover {
		background: #f9fafb;
	}

	.vendor-item .vendor-name {
		display: block;
		font-weight: 500;
		color: #111827;
		margin-bottom: 0.25rem;
	}

	.vendor-item .vendor-id {
		display: block;
		font-size: 0.875rem;
		color: #6b7280;
	}

	.selected-vendor {
		padding: 1rem;
		background: #f0f9ff;
		border: 1px solid #bfdbfe;
		border-radius: 6px;
	}

	.vendor-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.vendor-info .label {
		font-weight: 500;
		color: #1e40af;
	}

	.vendor-info .vendor-name {
		font-weight: 600;
		color: #111827;
	}

	.vendor-info .vendor-id {
		color: #6b7280;
		font-size: 0.875rem;
	}

	.loading-payments,
	.no-data {
		display: flex;
		justify-content: center;
		align-items: center;
		padding: 3rem;
		color: #6b7280;
	}

	.table-container {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		overflow: hidden;
	}

	.payments-table {
		width: 100%;
		border-collapse: collapse;
	}

	.payments-table thead {
		background: #f9fafb;
	}

	.payments-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.025em;
	}

	.payments-table td {
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
		color: #111827;
	}

	.payments-table tbody tr:last-child td {
		border-bottom: none;
	}

	.payments-table tbody tr:hover {
		background: #f9fafb;
	}

	.payments-table .amount {
		font-weight: 600;
		color: #059669;
	}

	.status-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
	}

	.status-badge.unpaid {
		background: #fee2e2;
		color: #991b1b;
	}

	.filters-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 1.5rem;
	}

	.filters-row {
		display: flex;
		gap: 1.5rem;
		flex-wrap: wrap;
	}

	.filter-group {
		flex: 1;
		min-width: 250px;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.filter-group label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.filter-select {
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		background: white;
		cursor: pointer;
		transition: border-color 0.2s;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.table-header-info {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px 8px 0 0;
		padding: 1rem 1.5rem;
		margin-bottom: -1px;
	}

	.table-stats {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		font-size: 0.875rem;
	}

	.stat-label {
		color: #6b7280;
		font-weight: 500;
	}

	.stat-value {
		color: #111827;
		font-weight: 600;
		font-size: 1rem;
	}

	.stat-value.amount {
		color: #059669;
	}

	.stat-separator {
		color: #d1d5db;
	}

	.summary-card {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 12px;
		padding: 2rem;
		margin-bottom: 1.5rem;
		color: white;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.summary-card h3 {
		margin: 0 0 1.5rem 0;
		font-size: 1.25rem;
		font-weight: 600;
		opacity: 0.95;
	}

	.summary-stats {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 1.5rem;
	}

	.summary-item {
		display: flex;
		align-items: center;
		gap: 1rem;
		background: rgba(255, 255, 255, 0.15);
		padding: 1.25rem;
		border-radius: 8px;
		backdrop-filter: blur(10px);
	}

	.summary-icon {
		font-size: 2.5rem;
		opacity: 0.9;
	}

	.summary-details {
		flex: 1;
	}

	.summary-label {
		font-size: 0.875rem;
		opacity: 0.9;
		margin-bottom: 0.25rem;
	}

	.summary-value {
		font-size: 1.75rem;
		font-weight: 700;
		line-height: 1;
	}

	.summary-value.amount {
		color: #fbbf24;
	}

	/* Pagination Styles */
	.pagination {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 1rem;
		padding: 1.5rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-top: none;
		border-radius: 0 0 8px 8px;
	}

	.pagination-btn {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: background 0.2s;
	}

	.pagination-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.pagination-btn:disabled {
		background: #d1d5db;
		cursor: not-allowed;
		opacity: 0.5;
	}

	.pagination-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #374151;
	}

	.page-input {
		width: 60px;
		padding: 0.375rem 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		text-align: center;
		font-size: 0.875rem;
	}

	.page-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	/* Remove spinner from number input */
	.page-input::-webkit-inner-spin-button,
	.page-input::-webkit-outer-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.page-input {
		-moz-appearance: textfield;
	}

	/* Edit Button Styles */
	.edit-btn {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: background-color 0.2s;
	}

	.edit-btn:hover {
		background: #2563eb;
	}

	.edit-btn:active {
		background: #1d4ed8;
	}

	/* Modal Overlay */
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
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #111827;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 1.5rem;
		cursor: pointer;
		color: #6b7280;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
		transition: background-color 0.2s, color 0.2s;
	}

	.close-btn:hover {
		background-color: #f3f4f6;
		color: #111827;
	}

	.modal-body {
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.form-group label {
		font-weight: 600;
		color: #111827;
		font-size: 0.875rem;
	}

	.form-input {
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		font-family: inherit;
		background: white;
	}

	.form-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
	}

	.btn-cancel,
	.btn-save {
		padding: 0.75rem 1.5rem;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		cursor: pointer;
		font-size: 0.875rem;
		transition: all 0.2s;
	}

	.btn-cancel {
		background: #f3f4f6;
		color: #111827;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.btn-save {
		background: #3b82f6;
		color: white;
	}

	.btn-save:hover:not(:disabled) {
		background: #2563eb;
	}

	.btn-cancel:disabled,
	.btn-save:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
