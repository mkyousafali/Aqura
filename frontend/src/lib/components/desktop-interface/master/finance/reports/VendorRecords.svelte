<script lang="ts">
	import { onMount } from 'svelte';
	import { supabaseAdmin } from '$lib/utils/supabase';

	let loading = true;
	let loadingRecords = false;
	let records: any[] = [];
	let totalCount = 0;
	let searchQuery = '';
	let branches: Array<{ id: number; name_en: string; name_ar: string }> = [];
	let selectedBranchId = '';

	// Server-side Pagination
	let currentPage = 1;
	let pageSize = 10;

	// Track previous filter values
	let prevSearchQuery = '';
	let prevBranchId = '';

	// Pagination calculations
	$: totalPages = Math.ceil(totalCount / pageSize);
	$: startRecord = totalCount > 0 ? (currentPage - 1) * pageSize + 1 : 0;
	$: endRecord = Math.min(currentPage * pageSize, totalCount);

	// Reset to page 1 when filters change
	$: if (searchQuery !== prevSearchQuery || selectedBranchId !== prevBranchId) {
		prevSearchQuery = searchQuery;
		prevBranchId = selectedBranchId;
		currentPage = 1;
		loadRecords();
	}

	onMount(async () => {
		await loadBranches();
		await loadRecords();
		loading = false;
	});

	async function loadBranches() {
		try {
			const { data, error } = await supabaseAdmin
				.from('branches')
				.select('id, name_en, name_ar')
				.eq('is_active', true)
				.order('name_en');

			if (error) throw error;
			branches = data || [];
		} catch (error) {
			console.error('Error loading branches:', error);
			branches = [];
		}
	}

	async function loadRecords() {
		loadingRecords = true;
		try {
			// Build query
			let query = supabaseAdmin
				.from('receiving_records')
				.select(`
					id,
					bill_number,
					bill_date,
					due_date,
					final_bill_amount,
					payment_method,
					credit_period,
					branch_id,
					vendor_id,
					bank_name,
					iban,
					certificate_url,
					original_bill_url,
					erp_purchase_invoice_reference,
					created_at,
					vendors!inner (
						vendor_name,
						erp_vendor_id,
						vat_number,
						bank_name,
						iban
					),
					branches!inner (
						name_en,
						name_ar
					)
				`, { count: 'exact' });

			// Apply filters
			if (selectedBranchId) {
				query = query.eq('branch_id', parseInt(selectedBranchId));
			}

			if (searchQuery) {
				query = query.or(`bill_number.ilike.%${searchQuery}%,vendors.vendor_name.ilike.%${searchQuery}%`);
			}

			// Apply pagination
			const from = (currentPage - 1) * pageSize;
			const to = from + pageSize - 1;

			const { data, error, count } = await query
				.order('created_at', { ascending: false })
				.range(from, to);

			if (error) throw error;

			totalCount = count || 0;
			records = (data || []).map(record => ({
				...record,
				vendor_name: record.vendors?.vendor_name,
				vendor_erp_id: record.vendors?.erp_vendor_id,
				vendor_vat: record.vendors?.vat_number,
				branch_name: record.branches?.name_en
			}));
		} catch (error) {
			console.error('Error loading records:', error);
			records = [];
			totalCount = 0;
		} finally {
			loadingRecords = false;
		}
	}

	function formatDate(dateString: string): string {
		if (!dateString) return '-';
		const date = new Date(dateString);
		return date.toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function formatCurrency(amount: number): string {
		if (!amount) return '0.00';
		return amount.toLocaleString('en-US', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		});
	}

	function viewDocument(url: string) {
		if (url) {
			window.open(url, '_blank');
		}
	}

	function isPdfFile(url: string): boolean {
		return url?.toLowerCase().endsWith('.pdf') || false;
	}

	function nextPage() {
		if (currentPage < totalPages) {
			currentPage++;
			loadRecords();
		}
	}

	function previousPage() {
		if (currentPage > 1) {
			currentPage--;
			loadRecords();
		}
	}

	function resetFilters() {
		searchQuery = '';
		selectedBranchId = '';
		currentPage = 1;
	}

	function handlePageInput(event: Event) {
		const target = event.target as HTMLInputElement;
		const value = parseInt(target.value);
		if (value >= 1 && value <= totalPages) {
			currentPage = value;
			loadRecords();
		}
	}
</script>

<div class="vendor-records">
	<!-- Fixed Header Section -->
	<div class="header-section">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>Loading vendor records...</p>
			</div>
		{:else}
			<!-- Header Card -->
			<div class="header-card">
				<div class="header-info">
					<h2>Vendor Receiving Records</h2>
					<p class="record-count">Total Records: <strong>{totalCount}</strong></p>
				</div>
				<button class="refresh-btn" on:click={() => loadRecords()} disabled={loadingRecords}>
					{loadingRecords ? '🔄 Loading...' : '🔄 Refresh'}
				</button>
			</div>

			<!-- Filters Card -->
			<div class="filters-card">
				<div class="filters-row">
					<div class="filter-group">
						<label for="search">Search:</label>
						<input
							id="search"
							type="text"
							bind:value={searchQuery}
							placeholder="Search by bill number or vendor name..."
							class="search-input"
							disabled={loadingRecords}
						/>
					</div>
					<div class="filter-group">
						<label for="branch-filter">Branch:</label>
						<select 
							id="branch-filter" 
							bind:value={selectedBranchId} 
							class="filter-select"
							disabled={loadingRecords}
						>
							<option value="">All Branches</option>
							{#each branches as branch}
								<option value={branch.id.toString()}>{branch.name_en}</option>
							{/each}
						</select>
					</div>
					{#if searchQuery || selectedBranchId}
						<button class="reset-btn" on:click={resetFilters} disabled={loadingRecords}>
							Clear Filters
						</button>
					{/if}
				</div>
			</div>

			<!-- Table Info -->
			{#if totalCount > 0}
				<div class="table-info">
					<span>Showing {startRecord}-{endRecord} of {totalCount} records</span>
				</div>
			{/if}
		{/if}
	</div>

	<!-- Scrollable Table Section -->
	{#if !loading}
		{#if records.length > 0}
			<div class="table-section">
				{#if loadingRecords}
					<div class="table-loading">
						<div class="spinner"></div>
						<p>Loading records...</p>
					</div>
				{:else}
					<table class="records-table">
						<thead>
							<tr>
								<th>Certificate</th>
								<th>Original Bill</th>
								<th>Bill Info</th>
								<th>Vendor Details</th>
								<th>Branch</th>
								<th>Bank Info</th>
								<th>Payment Info</th>
								<th>Amount</th>
								<th>ERP Reference</th>
							</tr>
						</thead>
						<tbody>
							{#each records as record}
								<tr>
									<td class="thumbnail-cell">
										{#if record.certificate_url}
											<div class="thumbnail" on:click={() => viewDocument(record.certificate_url)}>
												<img src={record.certificate_url} alt="Certificate" loading="lazy" />
												<div class="overlay">🔍</div>
											</div>
										{:else}
											<div class="no-document">
												<span>📄</span>
												<small>No Cert</small>
											</div>
										{/if}
									</td>
									<td class="thumbnail-cell">
										{#if record.original_bill_url}
											<div class="thumbnail" on:click={() => viewDocument(record.original_bill_url)}>
												{#if isPdfFile(record.original_bill_url)}
													<div class="pdf-icon">
														<span>📄</span>
														<small>PDF</small>
													</div>
												{:else}
													<img src={record.original_bill_url} alt="Bill" loading="lazy" />
												{/if}
												<div class="overlay">🔍</div>
											</div>
										{:else}
											<div class="no-document">
												<span>📄</span>
												<small>No Bill</small>
											</div>
										{/if}
									</td>
									<td>
										<div class="bill-info">
											<strong>#{record.bill_number || 'N/A'}</strong>
											<small>Date: {formatDate(record.bill_date)}</small>
											<small>Due: {formatDate(record.due_date)}</small>
										</div>
									</td>
									<td>
										<div class="vendor-info">
											<strong>{record.vendor_name || 'N/A'}</strong>
											<small>ID: {record.vendor_erp_id || record.vendor_id || 'N/A'}</small>
											<small>VAT: {record.vendor_vat || 'N/A'}</small>
										</div>
									</td>
									<td>{record.branch_name || 'N/A'}</td>
									<td>
										<div class="bank-info">
											<strong>{record.bank_name || record.vendors?.bank_name || 'N/A'}</strong>
											<small>{record.iban || record.vendors?.iban || 'N/A'}</small>
										</div>
									</td>
									<td>
										<div class="payment-info">
											<strong>{record.payment_method || 'N/A'}</strong>
											{#if record.credit_period}
												<small>{record.credit_period} days</small>
											{/if}
										</div>
									</td>
									<td class="amount-cell">
										{formatCurrency(record.final_bill_amount)}
									</td>
									<td>
										<span class="erp-ref">{record.erp_purchase_invoice_reference || 'N/A'}</span>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}
			</div>

			<!-- Pagination Controls -->
			{#if totalPages > 1}
				<div class="pagination">
					<button 
						class="pagination-btn" 
						on:click={previousPage}
						disabled={currentPage === 1 || loadingRecords}
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
							on:blur={handlePageInput}
							class="page-input"
							disabled={loadingRecords}
						/>
						<span>of {totalPages}</span>
					</div>

					<button 
						class="pagination-btn" 
						on:click={nextPage}
						disabled={currentPage === totalPages || loadingRecords}
					>
						Next →
					</button>
				</div>
			{/if}
		{:else}
			<div class="no-data">
				<span class="no-data-icon">📋</span>
				<p>No vendor records found matching your filters</p>
			</div>
		{/if}
	{/if}
</div>

<style>
	.vendor-records {
		display: flex;
		flex-direction: column;
		height: 100vh;
		background: #f9fafb;
		overflow: hidden;
	}

	.header-section {
		flex-shrink: 0;
		padding: 1.5rem;
		background: #f9fafb;
	}

	.table-section {
		flex: 0 1 auto;
		max-height: calc(100vh - 320px);
		overflow: auto;
		background: white;
		border: 1px solid #e5e7eb;
		border-bottom: none;
		margin: 0 1.5rem;
	}

	.loading {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		padding: 3rem;
		gap: 1rem;
	}

	.table-loading {
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		padding: 3rem;
		gap: 1rem;
		background: white;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #e5e7eb;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.header-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 1.5rem;
		display: flex;
		justify-content: space-between;
		align-items: center;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.header-info h2 {
		margin: 0 0 0.5rem 0;
		font-size: 1.5rem;
		font-weight: 600;
		color: #111827;
	}

	.record-count {
		margin: 0;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.record-count strong {
		color: #3b82f6;
		font-weight: 600;
	}

	.refresh-btn {
		padding: 0.625rem 1.25rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: background 0.2s;
		min-width: 120px;
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
	}

	.refresh-btn:disabled {
		background: #93c5fd;
		cursor: not-allowed;
	}

	.filters-card {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.filters-row {
		display: flex;
		gap: 1.5rem;
		align-items: flex-end;
		flex-wrap: wrap;
	}

	.filter-group {
		flex: 1;
		min-width: 200px;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.filter-group label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.search-input,
	.filter-select {
		padding: 0.625rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 0.875rem;
		background: white;
		transition: border-color 0.2s;
	}

	.search-input:focus,
	.filter-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-input:disabled,
	.filter-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.filter-select {
		cursor: pointer;
	}

	.reset-btn {
		padding: 0.625rem 1rem;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: background 0.2s;
		align-self: flex-end;
	}

	.reset-btn:hover:not(:disabled) {
		background: #dc2626;
	}

	.reset-btn:disabled {
		background: #fca5a5;
		cursor: not-allowed;
	}

	.table-info {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px 8px 0 0;
		padding: 0.75rem 1rem;
		font-size: 0.875rem;
		color: #6b7280;
		font-weight: 500;
		margin: 0 1.5rem;
	}

	.records-table {
		width: 100%;
		border-collapse: collapse;
		min-width: 1200px;
	}

	.records-table thead {
		background: #f9fafb;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.records-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 2px solid #e5e7eb;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.025em;
		white-space: nowrap;
	}

	.records-table td {
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
		color: #111827;
		font-size: 0.875rem;
	}

	.records-table tbody tr:hover {
		background: #f9fafb;
	}

	.thumbnail-cell {
		width: 80px;
	}

	.thumbnail {
		position: relative;
		width: 60px;
		height: 60px;
		cursor: pointer;
		border-radius: 4px;
		overflow: hidden;
		border: 1px solid #e5e7eb;
	}

	.thumbnail img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.thumbnail .overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.2s;
		font-size: 1.5rem;
	}

	.thumbnail:hover .overlay {
		opacity: 1;
	}

	.pdf-icon {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		background: #fee2e2;
		color: #dc2626;
	}

	.pdf-icon span {
		font-size: 1.5rem;
	}

	.pdf-icon small {
		font-size: 0.625rem;
		font-weight: 600;
	}

	.no-document {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 60px;
		height: 60px;
		background: #f3f4f6;
		border: 1px solid #e5e7eb;
		border-radius: 4px;
		color: #9ca3af;
	}

	.no-document span {
		font-size: 1.25rem;
	}

	.no-document small {
		font-size: 0.625rem;
	}

	.bill-info,
	.vendor-info,
	.bank-info,
	.payment-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.bill-info strong,
	.vendor-info strong,
	.bank-info strong,
	.payment-info strong {
		color: #111827;
		font-weight: 600;
	}

	.bill-info small,
	.vendor-info small,
	.bank-info small,
	.payment-info small {
		color: #6b7280;
		font-size: 0.75rem;
	}

	.amount-cell {
		font-weight: 600;
		color: #059669;
		text-align: right;
	}

	.erp-ref {
		font-family: monospace;
		color: #6b7280;
	}

	.no-data {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		color: #6b7280;
		margin: 0 1.5rem 1.5rem 1.5rem;
	}

	.no-data-icon {
		font-size: 3rem;
		margin-bottom: 1rem;
		opacity: 0.5;
	}

	.no-data p {
		margin: 0;
		font-size: 1rem;
	}

	/* Pagination Styles */
	.pagination {
		flex-shrink: 0;
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 1rem;
		padding: 1.5rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-top: none;
		margin: 0 1.5rem 1.5rem 1.5rem;
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

	.page-input:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.page-input::-webkit-inner-spin-button,
	.page-input::-webkit-outer-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.page-input {
		-moz-appearance: textfield;
	}
</style>
