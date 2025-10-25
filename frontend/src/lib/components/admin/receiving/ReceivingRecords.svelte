<script>
	import { onMount } from 'svelte';
	import ClearanceCertificateManager from './ClearanceCertificateManager.svelte';

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
	let selectedBranch = '';
	let branchFilterMode = 'all'; // 'all', 'branch'
	let branches = [];
	let loading = false;
	let uploadingBillId = null;
	let uploadingExcelId = null;
	let generatingCertificateId = null;
	let updatingBillId = null;

	// Certificate generation state
	let showCertificateModal = false;
	let selectedRecordForCertificate = null;

	// ERP Reference popup state
	let showErpPopup = false;
	let selectedRecord = null;
	let erpReferenceValue = '';
	let updatingErp = false;

	onMount(() => {
		console.log('🔍 ReceivingRecords component mounted');
		loadBranches();
		loadReceivingRecords();
	});

	async function loadBranches() {
		try {
			console.log('🔍 Loading branches...');
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en')
				.order('name_en');

			if (error) throw error;
			branches = data || [];
			console.log('🔍 Branches loaded:', branches.length);
		} catch (err) {
			console.error('Error loading branches:', err);
			branches = [];
		}
	}

	async function loadReceivingRecords() {
		loading = true;
		try {
			console.log('🔍 Loading receiving records...');
			// Import supabase here to avoid circular dependencies
			const { supabase } = await import('$lib/utils/supabase');
			
			// First, get receiving records with user and branch information
			const { data: records, error: recordsError } = await supabase
				.from('receiving_records')
				.select(`
					*,
					branches (
						name_en
					),
					users!receiving_records_user_id_fkey (
						id,
						username,
						hr_employees (
							name
						)
					)
				`)
				.order('created_at', { ascending: false });

			if (recordsError) {
				throw recordsError;
			}

			// Then, for each record, get the vendor info manually
			const recordsWithVendors = await Promise.all((records || []).map(async (record) => {
				const { data: vendorData, error: vendorError } = await supabase
					.from('vendors')
					.select('erp_vendor_id, vendor_name, vat_number, salesman_name, salesman_contact')
					.eq('erp_vendor_id', record.vendor_id)
					.eq('branch_id', record.branch_id)
					.single();

				if (vendorError) {
					console.warn(`Could not find vendor ${record.vendor_id} for branch ${record.branch_id}:`, vendorError);
					return {
						...record,
						vendors: null
					};
				}

				return {
					...record,
					vendors: vendorData
				};
			}));

			receivingRecords = recordsWithVendors;
			console.log('🔍 Receiving records loaded:', receivingRecords.length);
			
			applyFilters();
		} catch (err) {
			console.error('Error in loadReceivingRecords:', err);
			receivingRecords = [];
		} finally {
			loading = false;
		}
	}

	function applyFilters() {
		console.log('Filter values:', { 
			branchFilterMode, 
			selectedBranch, 
			recordCount: receivingRecords.length 
		});
		
		filteredRecords = receivingRecords.filter(record => {
			const matchesSearch = !searchTerm || 
				record.bill_number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				record.vendors?.vendor_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				record.vendors?.vat_number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				record.users?.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
				record.users?.hr_employees?.name?.toLowerCase().includes(searchTerm.toLowerCase());
			
			const matchesVendorId = !filterVendorId || 
				record.vendors?.erp_vendor_id?.toString().includes(filterVendorId);
			
			const matchesVatNumber = !filterVatNumber || 
				record.vendors?.vat_number?.toLowerCase().includes(filterVatNumber.toLowerCase());
			
			const matchesVendorName = !filterVendorName || 
				record.vendors?.vendor_name?.toLowerCase().includes(filterVendorName.toLowerCase());

			// Filter by branch
			const matchesBranch = branchFilterMode === 'all' || 
				(branchFilterMode === 'branch' && selectedBranch && record.branch_id?.toString() === selectedBranch.toString());
			
			if (branchFilterMode === 'branch') {
				console.log('Branch filter debug:', {
					recordId: record.id,
					recordBranchId: record.branch_id,
					selectedBranch,
					matches: matchesBranch
				});
			}

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

			return matchesSearch && matchesVendorId && matchesVatNumber && matchesVendorName && matchesBranch && matchesDaysRange && matchesOverdueDays;
		}).sort((a, b) => {
			// Sort by creation date (newest first - latest receiving bills on top)
			const dateA = new Date(a.created_at);
			const dateB = new Date(b.created_at);
			return dateB.getTime() - dateA.getTime();
		});
	}

	// Reactive statements to trigger filtering when filter values change
	$: if (searchTerm !== undefined || filterVendorId !== undefined || filterVatNumber !== undefined || 
	      filterVendorName !== undefined || filterFromDays !== undefined || filterToDays !== undefined || 
	      filterOverdueDays !== undefined || branchFilterMode !== undefined || selectedBranch !== undefined) {
		applyFilters();
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

	async function updateOriginalBill(recordId) {
		updatingBillId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.pdf,.jpg,.jpeg,.png,.gif,.bmp,.webp';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				updatingBillId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Generate unique filename with "updated" prefix
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_original_bill_updated_${Date.now()}.${fileExt}`;

				// Upload file to original-bills storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('original-bills')
					.upload(fileName, file);

				if (uploadError) {
					console.error('Error uploading updated file:', uploadError);
					alert('Error uploading updated file. Please try again.');
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('original-bills')
					.getPublicUrl(fileName);

				// Update the record with the new file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ 
						original_bill_url: publicUrl,
						updated_at: new Date().toISOString()
					})
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record:', updateError);
					alert('Error saving updated file reference. Please try again.');
					return;
				}

				// Show success message
				alert('Original bill updated successfully!');

				// Reload records to show updated data
				await loadReceivingRecords();
				
			} catch (error) {
				console.error('Error in update process:', error);
				alert('Error updating file. Please try again.');
			} finally {
				updatingBillId = null;
			}
		};

		// Trigger file selection
		fileInput.click();
	}

	async function uploadPRExcel(recordId) {
		uploadingExcelId = recordId;
		
		// Create file input element
		const fileInput = document.createElement('input');
		fileInput.type = 'file';
		fileInput.accept = '.xlsx,.xls,.csv';
		fileInput.multiple = false;

		fileInput.onchange = async (event) => {
			const file = event.target.files[0];
			if (!file) {
				uploadingExcelId = null;
				return;
			}

			try {
				// Import supabase here to avoid circular dependencies
				const { supabase } = await import('$lib/utils/supabase');
				
				// Generate unique filename
				const fileExt = file.name.split('.').pop();
				const fileName = `${recordId}_pr_excel_${Date.now()}.${fileExt}`;

				// Upload file to pr-excel-files storage bucket
				const { data: uploadData, error: uploadError } = await supabase.storage
					.from('pr-excel-files')
					.upload(fileName, file);

				if (uploadError) {
					console.error('Error uploading PR Excel file:', uploadError);
					alert('Error uploading PR Excel file. Please try again.');
					return;
				}

				// Get public URL
				const { data: { publicUrl } } = supabase.storage
					.from('pr-excel-files')
					.getPublicUrl(fileName);

				// Update the record with the file URL
				const { error: updateError } = await supabase
					.from('receiving_records')
					.update({ pr_excel_file_url: publicUrl })
					.eq('id', recordId);

				if (updateError) {
					console.error('Error updating record with PR Excel:', updateError);
					alert('Error saving PR Excel file reference. Please try again.');
					return;
				}

				// Reload records to show updated data
				await loadReceivingRecords();
				alert('PR Excel file uploaded successfully!');
				
			} catch (error) {
				console.error('Error in PR Excel upload process:', error);
				alert('Error uploading PR Excel file. Please try again.');
			} finally {
				uploadingExcelId = null;
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

	// ERP Invoice Reference Functions
	function openErpPopup(record) {
		selectedRecord = record;
		erpReferenceValue = record.erp_purchase_invoice_reference || '';
		showErpPopup = true;
	}

	function closeErpPopup() {
		showErpPopup = false;
		selectedRecord = null;
		erpReferenceValue = '';
		updatingErp = false;
	}

	async function updateErpReference() {
		if (!selectedRecord || !erpReferenceValue?.trim()) return;

		try {
			updatingErp = true;
			
			const response = await fetch('/api/receiving-records/update-erp', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					receivingRecordId: selectedRecord.id,
					erpReference: erpReferenceValue.trim()
				})
			});

			if (!response.ok) {
				const error = await response.text();
				throw new Error(error);
			}

			// Update the record in our local data
			const updatedRecords = filteredRecords.map(record => 
				record.id === selectedRecord.id 
					? { ...record, erp_purchase_invoice_reference: erpReferenceValue.trim() }
					: record
			);
			filteredRecords = updatedRecords;

			// Also update the main records array
			receivingRecords = receivingRecords.map(record => 
				record.id === selectedRecord.id 
					? { ...record, erp_purchase_invoice_reference: erpReferenceValue.trim() }
					: record
			);

			closeErpPopup();
			alert('ERP invoice reference updated successfully');
		} catch (error) {
			console.error('Error updating ERP reference:', error);
			alert(`Failed to update ERP reference: ${error.message}`);
		} finally {
			updatingErp = false;
		}
	}

	async function generateCertificate(record) {
		selectedRecordForCertificate = record;
		showCertificateModal = true;
	}

	function closeCertificateModal() {
		showCertificateModal = false;
		selectedRecordForCertificate = null;
	}

	function handleCertificateGenerated() {
		// Reload records to show the updated certificate
		loadReceivingRecords();
		closeCertificateModal();
	}

	// Reactive statement to apply filters when search/filter values change
	$: if (searchTerm !== undefined || filterVendorId !== undefined || filterVatNumber !== undefined || filterVendorName !== undefined || filterFromDays !== undefined || filterToDays !== undefined || filterOverdueDays !== undefined) {
		applyFilters();
	}
</script>

<!-- Receiving Records Window Content -->
<div class="receiving-records-window">
	<!-- Window Header -->
	<div class="window-header">
		<div class="window-title">
			<h2>📦 Receiving Records</h2>
			<p>Manage and track all receiving records</p>
		</div>
		<div class="window-actions">
			<button 
				class="refresh-btn" 
				on:click={loadReceivingRecords}
				disabled={loading}
				title="Refresh receiving records"
			>
				{#if loading}
					<div class="spinner-small"></div>
				{:else}
					<span>🔄</span>
				{/if}
				Refresh
			</button>
		</div>
	</div>

	<!-- Search and Filter Section -->
	<div class="filters-section">
		<div class="search-bar">
			<input 
				type="text" 
				placeholder="Search by bill number, vendor name, VAT number, or reviewer..." 
				bind:value={searchTerm}
				class="search-input"
			/>
		</div>
		
		<!-- Branch Filter -->
		<div class="filter-section">
			<div class="branch-filter">
				<h4>🏢 Filter by Branch</h4>
				<div class="filter-controls">
					<div class="filter-options">
						<label class="filter-option">
							<input 
								type="radio" 
								bind:group={branchFilterMode} 
								value="all"
							/>
							<span class="option-text">All Branches</span>
						</label>
						
						<label class="filter-option">
							<input 
								type="radio" 
								bind:group={branchFilterMode} 
								value="branch"
							/>
							<span class="option-text">By Branch</span>
						</label>
					</div>
					
					{#if branchFilterMode === 'branch'}
						<div class="branch-selector">
							<select bind:value={selectedBranch} class="branch-select">
								<option value="">Choose a branch...</option>
								{#each branches as branch}
									<option value={branch.id}>
										{branch.name_en}
									</option>
								{/each}
							</select>
						</div>
					{/if}
				</div>
			</div>
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
					<div class="header-cell">PR Excel</div>
					<div class="header-cell">Bill Info</div>
					<div class="header-cell">Vendor Details</div>
					<div class="header-cell">Branch</div>
					<div class="header-cell">Received By</div>
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
								<div class="generate-certificate-container">
									{#if generatingCertificateId === record.id}
										<div class="generating-indicator">
											<div class="spinner-small"></div>
											<small>Generating...</small>
										</div>
									{:else}
										<button class="generate-certificate-btn" on:click={() => generateCertificate(record)}>
											<span>�</span>
											<small>Generate Certificate</small>
										</button>
									{/if}
								</div>
							{/if}
						</div>
						
						<div class="cell certificate-cell">
							{#if record.original_bill_url}
								<div class="original-bill-with-update">
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
									<div class="update-bill-section">
										{#if updatingBillId === record.id}
											<div class="updating-indicator">
												<div class="spinner-small"></div>
												<small>Updating...</small>
											</div>
										{:else}
											<button class="update-bill-btn" on:click={() => updateOriginalBill(record.id)} title="Upload updated version">
												<span>🔄</span>
												<small>Update</small>
											</button>
										{/if}
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
						
						<div class="cell certificate-cell">
							{#if record.pr_excel_file_url}
								<div class="excel-file-container">
									<a href={record.pr_excel_file_url} target="_blank" class="excel-file-link">
										<div class="excel-icon">📊</div>
										<small>PR Excel</small>
									</a>
								</div>
							{:else}
								<div class="upload-excel-container">
									{#if uploadingExcelId === record.id}
										<div class="uploading-indicator">
											<div class="spinner-small"></div>
											<small>Uploading...</small>
										</div>
									{:else}
										<button class="upload-excel-btn" on:click={() => uploadPRExcel(record.id)}>
											<span>📊</span>
											<small>PR Excel Not Uploaded</small>
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
							<div class="reviewed-by-info">
								<strong>{record.users?.hr_employees?.name || record.users?.username || 'N/A'}</strong>
								<small>@{record.users?.username || 'unknown'}</small>
							</div>
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
										<button 
											class="erp-ref-empty clickable" 
											on:click={() => openErpPopup(record)}
											title="Click to enter ERP invoice reference"
										>
											Not Entered
										</button>
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

<!-- ERP Invoice Reference Popup -->
{#if showErpPopup}
	<div class="erp-popup-overlay" on:click={closeErpPopup}>
		<div class="erp-popup-modal" on:click|stopPropagation>
			<div class="erp-popup-header">
				<h3>Enter ERP Invoice Reference</h3>
				<button class="erp-popup-close" on:click={closeErpPopup}>&times;</button>
			</div>
			<div class="erp-popup-content">
				<p>Record: {selectedRecord?.bill_number || 'Unknown Bill'}</p>
				<p>Vendor: {selectedRecord?.vendor_name || 'Unknown Vendor'}</p>
				<div class="erp-input-group">
					<label for="erpRef">ERP Invoice Reference:</label>
					<input 
						id="erpRef"
						type="text" 
						bind:value={erpReferenceValue}
						placeholder="Enter ERP invoice reference number"
						class="erp-input"
						disabled={updatingErp}
					/>
				</div>
			</div>
			<div class="erp-popup-actions">
				<button 
					class="erp-btn-cancel" 
					on:click={closeErpPopup}
					disabled={updatingErp}
				>
					Cancel
				</button>
				<button 
					class="erp-btn-save" 
					on:click={updateErpReference}
					disabled={updatingErp || !erpReferenceValue?.trim()}
				>
					{#if updatingErp}
						<div class="spinner-small"></div>
						Updating...
					{:else}
						Save Reference
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Certificate Generation Modal -->
{#if showCertificateModal && selectedRecordForCertificate}
	<ClearanceCertificateManager 
		receivingRecord={selectedRecordForCertificate}
		show={true}
		on:certificateGenerated={handleCertificateGenerated}
		on:close={closeCertificateModal}
	/>
{/if}

<style>
	.receiving-records-window {
		padding: 24px;
		height: 100vh;
		background: white;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.window-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e2e8f0;
	}

	.window-title h2 {
		margin: 0 0 4px 0;
		color: #1e293b;
		font-size: 24px;
		font-weight: 700;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.window-title p {
		margin: 0;
		color: #64748b;
		font-size: 14px;
		font-weight: 400;
	}

	.window-actions {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
	}

	.refresh-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.refresh-btn span {
		font-size: 16px;
		animation: none;
	}

	.refresh-btn:hover:not(:disabled) span {
		animation: rotate 0.6s ease-in-out;
	}

	@keyframes rotate {
		from { transform: rotate(0deg); }
		to { transform: rotate(360deg); }
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

	.filter-section {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 16px;
	}

	.branch-filter h4 {
		margin: 0 0 1rem 0;
		color: #1e293b;
		font-size: 1.1rem;
		font-weight: 600;
	}

	.filter-controls {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.filter-options {
		display: flex;
		gap: 2rem;
		flex-wrap: wrap;
	}

	.filter-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-weight: 500;
		color: #475569;
	}

	.filter-option input[type="radio"] {
		margin: 0;
		transform: scale(1.2);
	}

	.option-text {
		font-size: 0.95rem;
	}

	.branch-selector {
		margin-top: 0.5rem;
	}

	.branch-select {
		padding: 0.75rem 1rem;
		border: 2px solid #e2e8f0;
		border-radius: 8px;
		font-size: 1rem;
		background: white;
		color: #1e293b;
		min-width: 300px;
		cursor: pointer;
	}

	.branch-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.records-container {
		background: white;
		border-radius: 12px;
		border: 1px solid #e2e8f0;
		overflow: hidden;
		flex: 1;
		max-height: 70vh;
		display: flex;
		flex-direction: column;
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
		flex: 1;
		overflow: auto;
	}

	.table-header {
		display: grid;
		grid-template-columns: 120px 120px 80px 1fr 1fr 1fr 120px 1fr 120px 1fr 140px 100px;
		gap: 16px;
		padding: 16px;
		background: #f8fafc;
		border-bottom: 1px solid #e2e8f0;
		font-weight: 600;
		color: #374151;
		font-size: 14px;
		position: sticky;
		top: 0;
		z-index: 10;
		flex-shrink: 0;
	}

	.table-row {
		display: grid;
		grid-template-columns: 120px 120px 80px 1fr 1fr 1fr 120px 1fr 120px 1fr 140px 100px;
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

	.generate-certificate-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 80px;
		height: 60px;
	}

	.generate-certificate-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f0f9ff;
		border: 2px dashed #3b82f6;
		border-radius: 8px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #1d4ed8;
		font-size: 10px;
		padding: 4px;
	}

	.generate-certificate-btn:hover {
		background: #dbeafe;
		border-color: #2563eb;
		color: #1e40af;
		transform: scale(1.02);
	}

	.generate-certificate-btn span {
		font-size: 16px;
		margin-bottom: 2px;
	}

	.generating-indicator {
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

	.bill-info, .vendor-info, .payment-info, .amounts, .reviewed-by-info {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.bill-info strong, .vendor-info strong, .payment-info strong, .reviewed-by-info strong {
		color: #1f2937;
		font-weight: 600;
	}

	.bill-info small, .vendor-info small, .payment-info small, .reviewed-by-info small {
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

	.erp-ref-empty.clickable {
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.erp-ref-empty.clickable:hover {
		background: #fee2e2;
		border-color: #fca5a5;
		transform: translateY(-1px);
	}

	/* ERP Popup Styles */
	.erp-popup-overlay {
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

	.erp-popup-modal {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
		width: 90%;
		max-width: 500px;
		max-height: 90vh;
		overflow: hidden;
	}

	.erp-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.erp-popup-header h3 {
		margin: 0;
		color: #111827;
		font-size: 18px;
		font-weight: 600;
	}

	.erp-popup-close {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 30px;
		height: 30px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: all 0.2s ease;
	}

	.erp-popup-close:hover {
		background: #e5e7eb;
		color: #374151;
	}

	.erp-popup-content {
		padding: 24px;
	}

	.erp-popup-content p {
		margin: 0 0 16px 0;
		color: #6b7280;
		font-size: 14px;
	}

	.erp-input-group {
		margin-top: 20px;
	}

	.erp-input-group label {
		display: block;
		margin-bottom: 8px;
		color: #374151;
		font-weight: 500;
		font-size: 14px;
	}

	.erp-input {
		width: 100%;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 14px;
		transition: all 0.2s ease;
		box-sizing: border-box;
	}

	.erp-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.erp-input:disabled {
		background: #f9fafb;
		color: #6b7280;
		cursor: not-allowed;
	}

	.erp-popup-actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding: 20px 24px;
		border-top: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.erp-btn-cancel,
	.erp-btn-save {
		padding: 10px 20px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
		border: 1px solid;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.erp-btn-cancel {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.erp-btn-cancel:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.erp-btn-save {
		background: #3b82f6;
		color: white;
		border-color: #3b82f6;
	}

	.erp-btn-save:hover:not(:disabled) {
		background: #2563eb;
		border-color: #2563eb;
	}

	.erp-btn-save:disabled,
	.erp-btn-cancel:disabled {
		opacity: 0.5;
		cursor: not-allowed;
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

	/* Original Bill with Update Button Styles */
	.original-bill-with-update {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 8px;
		width: 100%;
		justify-content: space-between;
	}

	.update-bill-section {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.update-bill-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #fef3c7;
		border: 1px solid #f59e0b;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: #92400e;
		font-size: 9px;
		min-width: 40px;
		height: 40px;
	}

	.update-bill-btn:hover {
		background: #fbbf24;
		color: #78350f;
		transform: scale(1.05);
		border-color: #d97706;
	}

	.update-bill-btn span {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.updating-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4px 6px;
		background: #f3f4f6;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		color: #6b7280;
		font-size: 9px;
		min-width: 40px;
		height: 40px;
	}

	/* PR Excel Upload Styles */
	.upload-excel-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		min-height: 50px;
	}

	.upload-excel-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f0f9ff;
		border: 2px dashed #0ea5e9;
		border-radius: 6px;
		color: #0369a1;
		cursor: pointer;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px;
		min-height: 50px;
	}

	.upload-excel-btn:hover {
		background: #e0f2fe;
		border-color: #0284c7;
		transform: scale(1.02);
	}

	.upload-excel-btn span {
		font-size: 12px;
		margin-bottom: 1px;
	}

	.excel-file-container {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		min-height: 50px;
	}

	.excel-file-link {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f0fdf4;
		border: 2px solid #22c55e;
		border-radius: 6px;
		color: #15803d;
		text-decoration: none;
		transition: all 0.3s ease;
		font-size: 8px;
		padding: 4px;
		min-height: 50px;
	}

	.excel-file-link:hover {
		background: #dcfce7;
		border-color: #16a34a;
		transform: scale(1.02);
	}

	.excel-icon {
		font-size: 12px;
		margin-bottom: 1px;
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

		.window-header {
			flex-direction: column;
			align-items: flex-start;
			gap: 12px;
		}

		.window-title h2 {
			font-size: 20px;
		}

		.window-actions {
			align-self: flex-end;
		}

		.refresh-btn {
			padding: 8px 12px;
			font-size: 12px;
		}

		.refresh-btn span {
			font-size: 14px;
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

		.generate-certificate-container {
			width: 60px;
			height: 45px;
		}

		.generate-certificate-btn {
			font-size: 8px;
		}

		.generate-certificate-btn span {
			font-size: 12px;
		}

		.upload-bill-btn {
			font-size: 10px;
		}

		.upload-bill-btn span {
			font-size: 12px;
		}

		.upload-excel-container {
			width: 50px;
			height: 40px;
		}

		.upload-excel-btn {
			font-size: 7px;
			min-height: 40px;
		}

		.upload-excel-btn span {
			font-size: 10px;
		}

		.excel-file-container {
			width: 50px;
			height: 40px;
		}

		.filters-row {
			grid-template-columns: 1fr;
		}

		/* Hide original bill, PR Excel, received by, payment info, days remaining, amounts, and ERP columns on mobile for space */
		.table-header .header-cell:nth-child(2),
		.table-header .header-cell:nth-child(3),
		.table-header .header-cell:nth-child(7),
		.table-header .header-cell:nth-child(8),
		.table-header .header-cell:nth-child(9),
		.table-header .header-cell:nth-child(10),
		.table-header .header-cell:nth-child(11),
		.table-header .header-cell:nth-child(12),
		.table-row .cell:nth-child(2),
		.table-row .cell:nth-child(3),
		.table-row .cell:nth-child(7),
		.table-row .cell:nth-child(8),
		.table-row .cell:nth-child(9),
		.table-row .cell:nth-child(10),
		.table-row .cell:nth-child(11),
		.table-row .cell:nth-child(12) {
			display: none;
		}
	}
</style>