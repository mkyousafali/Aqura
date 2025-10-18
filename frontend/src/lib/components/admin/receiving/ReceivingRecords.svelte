<script>
	import { onMount } from 'svelte';

	// State for receiving records
	let receivingRecords = [];
	let filteredRecords = [];
	let searchTerm = '';
	let filterVendorId = '';
	let filterVatNumber = '';
	let filterVendorName = '';
	let filterFromDays = '';
	let filterToDays = '';
	let filterOverdueDays = '';
	let loading = false;
	let uploadingBillId = null;

	onMount(() => {
		loadReceivingRecords();
	});

	async function loadReceivingRecords() {
		loading = true;
		try {
			// Import supabase here to avoid circular dependencies
			const { supabase } = await import('$lib/utils/supabase');
			
			const { data, error } = await supabase
				.from('receiving_records')
				.select(`
					*,
					vendors (
						erp_vendor_id,
						vendor_name,
						vat_number,
						salesman_name,
						salesman_contact
					),
					branches (
						name_en
					)
				`)
				.order('created_at', { ascending: false });

			if (error) {
				console.error('Error loading receiving records:', error);
				receivingRecords = [];
			} else {
				receivingRecords = data || [];
			}
			
			applyFilters();
		} catch (err) {
			console.error('Error in loadReceivingRecords:', err);
			receivingRecords = [];
		} finally {
			loading = false;
		}
	}

	function applyFilters() {
		filteredRecords = receivingRecords.filter(record => {
			const matchesSearch = !searchTerm || 
				record.bill_number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				record.vendors?.vendor_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				record.vendors?.vat_number?.toLowerCase().includes(searchTerm.toLowerCase());
			
			const matchesVendorId = !filterVendorId || 
				record.vendors?.erp_vendor_id?.toString().includes(filterVendorId);
			
			const matchesVatNumber = !filterVatNumber || 
				record.vendors?.vat_number?.toLowerCase().includes(filterVatNumber.toLowerCase());
			
			const matchesVendorName = !filterVendorName || 
				record.vendors?.vendor_name?.toLowerCase().includes(filterVendorName.toLowerCase());

			// Calculate days remaining for this record
			let daysRemaining = null;
			if (record.due_date) {
				const dueDate = new Date(record.due_date);
				const today = new Date();
				today.setHours(0, 0, 0, 0);
				dueDate.setHours(0, 0, 0, 0);
				const diffTime = dueDate.getTime() - today.getTime();
				daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
			}

			// Filter by days range (from days to to days)
			const matchesDaysRange = (!filterFromDays && !filterToDays) || 
				(daysRemaining !== null && 
				 (!filterFromDays || daysRemaining >= parseInt(filterFromDays)) &&
				 (!filterToDays || daysRemaining <= parseInt(filterToDays)));

			// Filter by overdue days (only show records overdue by specific number of days)
			const matchesOverdueDays = !filterOverdueDays || 
				(daysRemaining !== null && 
				 daysRemaining < 0 && 
				 Math.abs(daysRemaining) >= parseInt(filterOverdueDays));

			return matchesSearch && matchesVendorId && matchesVatNumber && matchesVendorName && matchesDaysRange && matchesOverdueDays;
		}).sort((a, b) => {
			// Calculate days remaining for both records
			const getDaysForRecord = (record) => {
				if (!record.due_date) return 999999; // Records without due dates go to bottom
				const dueDate = new Date(record.due_date);
				const today = new Date();
				today.setHours(0, 0, 0, 0);
				dueDate.setHours(0, 0, 0, 0);
				const diffTime = dueDate.getTime() - today.getTime();
				return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
			};

			const daysA = getDaysForRecord(a);
			const daysB = getDaysForRecord(b);

			// Sort by days remaining (ascending: most overdue first, then closest due dates)
			return daysA - daysB;
		});
	}

	function viewCertificate(certificateUrl) {
		if (certificateUrl) {
			window.open(certificateUrl, '_blank');
		}
	}

	function viewOriginalBill(billUrl) {
		if (billUrl) {
			window.open(billUrl, '_blank');
		}
	}

	// Helper function to check if file is PDF
	function isPdfFile(url) {
		if (!url) return false;
		return url.toLowerCase().includes('.pdf');
	}

	// Helper function to get file extension
	function getFileExtension(url) {
		if (!url) return '';
		return url.split('.').pop().toLowerCase();
	}

	async function uploadOriginalBill(recordId) {
		uploadingBillId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.pdf,.jpg,.jpeg,.png,.gif,.bmp,.webp';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				uploadingBillId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Generate unique filename
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_original_bill_${Date.now()}.${fileExt}`;

				// Upload file to original-bills storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('original-bills')
					.upload(fileName, file);

				if (uploadError) {
					console.error('Error uploading file:', uploadError);
					alert('Error uploading file. Please try again.');
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('original-bills')
					.getPublicUrl(fileName);

				// Update the record with the file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ original_bill_url: publicUrl })
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record:', updateError);
					alert('Error saving file reference. Please try again.');
					return;
				}

				// Reload records to show updated data
				await loadReceivingRecords();
				
			} catch (error) {
				console.error('Error in upload process:', error);
				alert('Error uploading file. Please try again.');
			} finally {
				uploadingBillId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	// Helper function to format dates as dd/mm/yyyy
	function formatDate(dateString) {
		if (!dateString) return 'N/A';
		try {
			const date = new Date(dateString);
			const day = date.getDate().toString().padStart(2, '0');
			const month = (date.getMonth() + 1).toString().padStart(2, '0');
			const year = date.getFullYear();
			return `${day}/${month}/${year}`;
		} catch (error) {
			return 'Invalid Date';
		}
	}

	// Helper function to calculate days remaining to due date
	function getDaysRemaining(dueDateString) {
		if (!dueDateString) return 'N/A';
		try {
			const dueDate = new Date(dueDateString);
			const today = new Date();
			today.setHours(0, 0, 0, 0);
			dueDate.setHours(0, 0, 0, 0);
			
			const diffTime = dueDate.getTime() - today.getTime();
			const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
			
			if (diffDays < 0) {
				return `${diffDays} days`;
			} else if (diffDays === 0) {
				return '0 days';
			} else {
				return `${diffDays} days`;
			}
		} catch (error) {
			return 'Invalid Date';
		}
	}

	// Reactive statement to apply filters when search/filter values change
	$: if (searchTerm !== undefined || filterVendorId !== undefined || filterVatNumber !== undefined || filterVendorName !== undefined || filterFromDays !== undefined || filterToDays !== undefined || filterOverdueDays !== undefined) {
		applyFilters();
	}
</script>

<!-- Receiving Records Window Content -->
<div class="receiving-records-window">
	<!-- Search and Filter Section -->
	<div class="filters-section">
		<div class="search-bar">
			<input 
				type="text" 
				placeholder="Search by bill number, vendor name, or VAT number..." 
				bind:value={searchTerm}
				class="search-input"
			/>
		</div>
		
		<div class="filters-row">
			<input 
				type="text" 
				placeholder="Filter by Vendor ID" 
				bind:value={filterVendorId}
				class="filter-input"
			/>
			<input 
				type="text" 
				placeholder="Filter by VAT Number" 
				bind:value={filterVatNumber}
				class="filter-input"
			/>
			<input 
				type="text" 
				placeholder="Filter by Vendor Name" 
				bind:value={filterVendorName}
				class="filter-input"
			/>
		</div>

		<div class="filters-row">
			<input 
				type="number" 
				placeholder="From Days (e.g., -10 for overdue)" 
				bind:value={filterFromDays}
				class="filter-input"
			/>
			<input 
				type="number" 
				placeholder="To Days (e.g., 30)" 
				bind:value={filterToDays}
				class="filter-input"
			/>
			<input 
				type="number" 
				placeholder="Overdue by at least X days" 
				bind:value={filterOverdueDays}
				class="filter-input"
			/>
		</div>
	</div>

	<!-- Records Table -->
	<div class="records-container">
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>Loading receiving records...</p>
			</div>
		{:else if filteredRecords.length === 0}
			<div class="no-records">
				<p>No receiving records found.</p>
			</div>
		{:else}
			<div class="records-table">
				<div class="table-header">
					<div class="header-cell">Certificate</div>
					<div class="header-cell">Original Bill</div>
					<div class="header-cell">Bill Info</div>
					<div class="header-cell">Vendor Details</div>
					<div class="header-cell">Branch</div>
					<div class="header-cell">Payment Info</div>
					<div class="header-cell">Days to Due</div>
					<div class="header-cell">Amounts</div>
					<div class="header-cell">ERP Invoice Ref</div>
					<div class="header-cell">Date</div>
				</div>
				
				{#each filteredRecords as record}
					<div class="table-row">
						<div class="cell certificate-cell">
							{#if record.certificate_url}
								<div class="certificate-thumbnail" on:click={() => viewCertificate(record.certificate_url)}>
									<img src={record.certificate_url} alt="Certificate" loading="lazy" />
									<div class="thumbnail-overlay">
										<span>🔍</span>
									</div>
								</div>
							{:else}
								<div class="no-certificate">
									<span>📄</span>
									<small>No Certificate</small>
								</div>
							{/if}
						</div>
						
						<div class="cell certificate-cell">
							{#if record.original_bill_url}
								<div class="certificate-thumbnail" on:click={() => viewOriginalBill(record.original_bill_url)}>
									{#if isPdfFile(record.original_bill_url)}
										<div class="pdf-thumbnail">
											<div class="pdf-icon">📄</div>
											<div class="pdf-label">PDF</div>
										</div>
									{:else}
										<img src={record.original_bill_url} alt="Original Bill" loading="lazy" />
									{/if}
									<div class="thumbnail-overlay">
										<span>🔍</span>
									</div>
								</div>
							{:else}
								<div class="upload-bill-container">
									{#if uploadingBillId === record.id}
										<div class="uploading-indicator">
											<div class="spinner-small"></div>
											<small>Uploading...</small>
										</div>
									{:else}
										<button class="upload-bill-btn" on:click={() => uploadOriginalBill(record.id)}>
											<span>📎</span>
											<small>Original Bill Not Uploaded</small>
										</button>
									{/if}
								</div>
							{/if}
						</div>
						
						<div class="cell">
							<div class="bill-info">
								<strong>#{record.bill_number || 'N/A'}</strong>
								<small>{formatDate(record.bill_date)}</small>
							</div>
						</div>
						
						<div class="cell">
							<div class="vendor-info">
								<strong>{record.vendors?.vendor_name || 'N/A'}</strong>
								<small>ID: {record.vendors?.erp_vendor_id || 'N/A'}</small>
								<small>VAT: {record.vendors?.vat_number || 'N/A'}</small>
							</div>
						</div>
						
						<div class="cell">
							<span>{record.branches?.name_en || 'N/A'}</span>
						</div>
						
						<div class="cell">
							<div class="payment-info">
								<strong>{record.payment_method || 'N/A'}</strong>
								<small>Due: {formatDate(record.due_date)}</small>
								{#if record.credit_period}
									<small>{record.credit_period} days</small>
								{/if}
							</div>
						</div>
						
						<div class="cell">
							<div class="days-remaining" class:overdue={record.due_date && getDaysRemaining(record.due_date).includes('-')}>
								<span>{getDaysRemaining(record.due_date)}</span>
							</div>
						</div>
						
						<div class="cell">
							<div class="amounts">
								<div>Bill: {parseFloat(record.bill_amount || 0).toFixed(2)}</div>
								<div>Final: {parseFloat(record.final_bill_amount || 0).toFixed(2)}</div>
							</div>
						</div>
						
						<div class="cell">
							<div class="erp-reference">
								{#if record.erp_purchase_invoice_reference}
									<span class="erp-ref-value">{record.erp_purchase_invoice_reference}</span>
								{:else}
									<span class="erp-ref-empty">Not Entered</span>
								{/if}
							</div>
						</div>
						
						<div class="cell">
							<small>{formatDate(record.created_at)}</small>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.receiving-records-window {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.filters-section {
		margin-bottom: 24px;
		padding: 20px;
		background: #f8fafc;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
	}

	.search-bar {
		margin-bottom: 16px;
	}

	.search-input {
		width: 100%;
		padding: 12px 16px;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 16px;
		transition: border-color 0.2s ease;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filters-row {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.filter-input {
		padding: 10px 12px;
		border: 2px solid #e2e8f0;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s ease;
	}

	.filter-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	.records-container {
		background: white;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
		overflow: hidden;
		flex: 1;
	}

	.loading {
		text-align: center;
		padding: 60px 20px;
		color: #6b7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-left: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 16px;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.no-records {
		text-align: center;
		padding: 60px 20px;
		color: #6b7280;
	}

	.records-table {
		display: flex;
		flex-direction: column;
	}

	.table-header {
		display: grid;
		grid-template-columns: 120px 120px 1fr 1fr 1fr 1fr 120px 1fr 140px 100px;
		gap: 16px;
		padding: 16px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		font-weight: 600;
		color: #374151;
		font-size: 14px;
	}

	.table-row {
		display: grid;
		grid-template-columns: 120px 120px 1fr 1fr 1fr 1fr 120px 1fr 140px 100px;
		gap: 16px;
		padding: 16px;
		border-bottom: 1px solid #f1f5f9;
		transition: background-color 0.2s ease;
	}

	.table-row:hover {
		background: #f8fafc;
	}

	.cell {
		display: flex;
		align-items: center;
		font-size: 14px;
		color: #374151;
	}

	.certificate-cell {
		justify-content: center;
	}

	.certificate-thumbnail {
		width: 80px;
		height: 60px;
		border-radius: 8px;
		overflow: hidden;
		cursor: pointer;
		position: relative;
		border: 2px solid #e2e8f0;
		transition: all 0.2s ease;
	}

	.certificate-thumbnail:hover {
		border-color: #3b82f6;
		transform: scale(1.05);
	}

	.certificate-thumbnail img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.thumbnail-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.2s ease;
		color: white;
		font-size: 20px;
	}

	.certificate-thumbnail:hover .thumbnail-overlay {
		opacity: 1;
	}

	.no-certificate {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
		background: #f1f5f9;
		border-radius: 8px;
		color: #6b7280;
		font-size: 12px;
	}

	.no-certificate span {
		font-size: 20px;
		margin-bottom: 4px;
	}

	.bill-info, .vendor-info, .payment-info, .amounts {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.bill-info strong, .vendor-info strong, .payment-info strong {
		color: #1f2937;
		font-weight: 600;
	}

	.bill-info small, .vendor-info small, .payment-info small {
		color: #6b7280;
		font-size: 12px;
	}

	.amounts div {
		font-size: 12px;
		color: #374151;
	}

	.erp-reference {
		display: flex;
		align-items: center;
		justify-content: center;
		text-align: center;
		font-size: 12px;
		padding: 4px 8px;
		border-radius: 6px;
		font-weight: 500;
	}

	.erp-ref-value {
		background: #f0fdf4;
		color: #16a34a;
		border: 1px solid #bbf7d0;
		padding: 6px 10px;
		border-radius: 6px;
		font-family: 'Courier New', monospace;
		font-weight: 600;
		font-size: 11px;
		word-break: break-all;
	}

	.erp-ref-empty {
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #fecaca;
		padding: 6px 10px;
		border-radius: 6px;
		font-style: italic;
		font-size: 11px;
	}

	.days-remaining {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 8px 12px;
		border-radius: 8px;
		font-weight: 600;
		font-size: 12px;
		text-align: center;
		background: #f0fdf4;
		color: #16a34a;
		border: 1px solid #bbf7d0;
	}

	.days-remaining.overdue {
		background: #fef2f2;
		color: #dc2626;
		border-color: #fecaca;
	}

	.upload-bill-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
	}

	.upload-bill-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f8fafc;
		border: 2px dashed #d1d5db;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #6b7280;
		font-size: 12px;
		padding: 4px;
	}

	.upload-bill-btn:hover {
		background: #f0f9ff;
		border-color: #3b82f6;
		color: #3b82f6;
		transform: scale(1.02);
	}

	.upload-bill-btn span {
		font-size: 16px;
		margin-bottom: 2px;
	}

	.uploading-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #fef3c7;
		border: 2px solid #f59e0b;
		border-radius: 8px;
		color: #92400e;
		font-size: 10px;
	}

	.spinner-small {
		width: 16px;
		height: 16px;
		border: 2px solid #fde68a;
		border-left: 2px solid #f59e0b;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 2px;
	}

	.pdf-thumbnail {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		border-radius: 6px;
		position: relative;
	}

	.pdf-icon {
		font-size: 24px;
		margin-bottom: 2px;
	}

	.pdf-label {
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.5px;
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.receiving-records-window {
			padding: 16px;
		}

		.table-header, .table-row {
			grid-template-columns: 80px 1fr 1fr 1fr;
			gap: 8px;
			font-size: 12px;
		}

		.certificate-thumbnail {
			width: 60px;
			height: 45px;
		}

		.upload-bill-container {
			width: 60px;
			height: 45px;
		}

		.upload-bill-btn {
			font-size: 10px;
		}

		.upload-bill-btn span {
			font-size: 12px;
		}

		.filters-row {
			grid-template-columns: 1fr;
		}

		/* Hide original bill, payment info, days remaining, amounts, and ERP columns on mobile for space */
		.table-header .header-cell:nth-child(2),
		.table-header .header-cell:nth-child(6),
		.table-header .header-cell:nth-child(7),
		.table-header .header-cell:nth-child(8),
		.table-header .header-cell:nth-child(9),
		.table-row .cell:nth-child(2),
		.table-row .cell:nth-child(6),
		.table-row .cell:nth-child(7),
		.table-row .cell:nth-child(8),
		.table-row .cell:nth-child(9) {
			display: none;
		}
	}
</style>