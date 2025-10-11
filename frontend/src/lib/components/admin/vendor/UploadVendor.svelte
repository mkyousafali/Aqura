<script>
	import { onMount } from 'svelte';
	import * as XLSX from 'xlsx';
	import { supabase } from '$lib/utils/supabase';

	// State management
	let selectedFile = null;
	let uploadProgress = 0;
	let isUploading = false;
	let uploadStatus = '';
	let dragOver = false;
	let uploadResults = null;

	// File validation
	function validateAndSelectFile(file) {
		if (!file) return;

		// Validate file type - Excel only
		const allowedTypes = [
			'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
			'application/vnd.ms-excel' // .xls
		];
		
		if (!allowedTypes.includes(file.type)) {
			uploadStatus = 'Error: Please select an Excel file (.xlsx or .xls) only';
			selectedFile = null;
			return;
		}

		// Validate file size (max 50MB for large vendor lists)
		if (file.size > 50 * 1024 * 1024) {
			uploadStatus = 'Error: File size must be less than 50MB';
			selectedFile = null;
			return;
		}

		selectedFile = file;
		uploadStatus = '';
		uploadResults = null;
	}

	// File selection handlers
	function handleFileSelect(event) {
		const file = event.target.files[0];
		validateAndSelectFile(file);
	}

	function handleFileDrop(event) {
		event.preventDefault();
		dragOver = false;
		const file = event.dataTransfer.files[0];
		validateAndSelectFile(file);
	}

	function handleDragOver(event) {
		event.preventDefault();
		dragOver = true;
	}

	function handleDragLeave() {
		dragOver = false;
	}

	// Remove selected file
	function removeFile() {
		selectedFile = null;
		uploadStatus = '';
		uploadResults = null;
	}

	// Download Excel template
	function downloadTemplate() {
		// Create Excel template data
		const templateData = [
			['ERP Vendor ID', 'Vendor Name'],
			[1001, 'ABC Trading Company'],
			[1002, 'شركة التجارة المتقدمة'],
			[1003, 'Global Import & Export Ltd.'],
			[1004, 'مؤسسة الأعمال الدولية'],
			[1005, 'Tech Solutions & Services']
		];

		// Create workbook using XLSX utils
		const worksheet = XLSX.utils.aoa_to_sheet(templateData);
		const workbook = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(workbook, worksheet, 'Vendors');

		// Download as Excel file
		XLSX.writeFile(workbook, 'vendor_upload_template.xlsx');

		uploadStatus = 'Excel template downloaded successfully!';
	}

	// Upload file function
	async function uploadFile() {
		if (!selectedFile) return;

		isUploading = true;
		uploadProgress = 0;
		uploadStatus = 'Starting upload...';

		try {
			// Step 1: Read Excel file
			uploadProgress = 10;
			uploadStatus = 'Reading Excel file...';
			
			const arrayBuffer = await selectedFile.arrayBuffer();
			const workbook = XLSX.read(arrayBuffer);
			const worksheet = workbook.Sheets[workbook.SheetNames[0]];
			const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

			// Step 2: Validate data structure
			uploadProgress = 20;
			uploadStatus = 'Validating file structure...';
			
			if (jsonData.length < 2) {
				throw new Error('File must contain header row and at least one data row');
			}

			const headers = jsonData[0];
			const requiredHeaders = ['ERP Vendor ID', 'Vendor Name'];
			const missingHeaders = requiredHeaders.filter(header => !headers.includes(header));
			
			if (missingHeaders.length > 0) {
				throw new Error(`Missing required columns: ${missingHeaders.join(', ')}`);
			}

			// Step 3: Process vendor data
			uploadProgress = 30;
			uploadStatus = 'Processing vendor data...';
			
			const vendorData = [];
			const errors = [];
			
			for (let i = 1; i < jsonData.length; i++) {
				const row = jsonData[i];
				const erpId = row[0];
				const vendorName = row[1];
				
				// Validate row data
				if (!erpId || isNaN(erpId)) {
					errors.push({ row: i + 1, error: 'Invalid or missing ERP Vendor ID' });
					continue;
				}
				
				if (!vendorName || vendorName.trim() === '') {
					errors.push({ row: i + 1, error: 'Vendor name is required' });
					continue;
				}
				
				vendorData.push({
					erp_vendor_id: parseInt(erpId),
					vendor_name: vendorName.toString().trim(),
					salesman_name: 'N/A',
					salesman_contact: 'N/A',
					supervisor_name: 'N/A',
					supervisor_contact: 'N/A',
					vendor_contact_number: 'N/A',
					payment_method: 'N/A',
					credit_period: null,
					bank_name: 'N/A',
					iban: 'N/A',
					status: 'Active'
				});
			}

			// Step 4: Check for duplicates in file
			uploadProgress = 50;
			uploadStatus = 'Checking for duplicates...';
			
			const seenIds = new Set();
			const duplicateRows = [];
			
			vendorData.forEach((vendor, index) => {
				if (seenIds.has(vendor.erp_vendor_id)) {
					duplicateRows.push(index + 2);
					errors.push({ row: index + 2, error: 'Duplicate ERP Vendor ID in file' });
				} else {
					seenIds.add(vendor.erp_vendor_id);
				}
			});

			// Step 5: Check database for existing IDs
			uploadProgress = 60;
			uploadStatus = 'Checking database for existing vendors...';
			
			const existingIds = vendorData.map(v => v.erp_vendor_id);
			const { data: existing, error: checkError } = await supabase
				.from('vendors')
				.select('erp_vendor_id')
				.in('erp_vendor_id', existingIds);
				
			if (checkError) throw checkError;
			
			const existingIdSet = new Set(existing.map(v => v.erp_vendor_id));
			const validVendors = vendorData.filter(vendor => {
				if (existingIdSet.has(vendor.erp_vendor_id)) {
					const rowIndex = vendorData.findIndex(v => v.erp_vendor_id === vendor.erp_vendor_id) + 2;
					errors.push({ row: rowIndex, error: 'ERP Vendor ID already exists in database' });
					return false;
				}
				return true;
			});

			// Step 6: Insert valid vendors
			uploadProgress = 80;
			uploadStatus = 'Saving to database...';
			
			let successful = 0;
			if (validVendors.length > 0) {
				const { data, error: insertError } = await supabase
					.from('vendors')
					.insert(validVendors)
					.select();
					
				if (insertError) throw insertError;
				successful = data.length;
			}

			// Step 7: Complete
			uploadProgress = 100;
			uploadStatus = 'Upload completed successfully!';
			
			uploadResults = {
				totalRecords: jsonData.length - 1, // Exclude header
				successful: successful,
				failed: errors.length,
				duplicates: duplicateRows.length,
				errors: errors
			};

		} catch (error) {
			uploadStatus = `Error: ${error.message}`;
			uploadResults = null;
		} finally {
			isUploading = false;
		}
	}

	// Reset upload state
	function resetUpload() {
		selectedFile = null;
		uploadProgress = 0;
		isUploading = false;
		uploadStatus = '';
		uploadResults = null;
		dragOver = false;
	}
</script>

<div class="upload-vendor">
	<!-- Header -->
	<div class="header">
		<h1 class="title">📤 Upload Vendor Data</h1>
		<p class="subtitle">Import vendor information from Excel files</p>
	</div>

	<!-- Template Download Section -->
	<div class="template-section">
		<div class="template-card">
			<div class="template-icon">📋</div>
			<div class="template-content">
				<h3>Download Excel Template</h3>
				<p>Get the required format with sample data</p>
			</div>
			<button class="template-btn" on:click={downloadTemplate}>
				📥 Download Template
			</button>
		</div>
	</div>

	<!-- File Upload Section -->
	<div class="upload-section">
		<div 
			class="file-drop-zone {dragOver ? 'drag-over' : ''} {selectedFile ? 'file-selected' : ''}"
			on:dragover={handleDragOver}
			on:dragleave={handleDragLeave}
			on:drop={handleFileDrop}
		>
			{#if selectedFile}
				<!-- Selected File Display -->
				<div class="selected-file">
					<div class="file-icon">📊</div>
					<div class="file-info">
						<h4>{selectedFile.name}</h4>
						<p>{(selectedFile.size / 1024 / 1024).toFixed(2)} MB • Excel File</p>
						<div class="file-details">
							<span class="file-type">✅ Valid Excel format</span>
						</div>
					</div>
					<button class="remove-file" on:click={removeFile} disabled={isUploading}>×</button>
				</div>
			{:else}
				<!-- Drop Zone -->
				<div class="drop-instructions">
					<div class="upload-icon">📁</div>
					<h3>Drop Excel file here</h3>
					<p>or click to browse files</p>
					<div class="supported-formats">
						<span>Supported: .xlsx, .xls</span>
					</div>
					<input 
						type="file" 
						accept=".xlsx,.xls" 
						on:change={handleFileSelect}
						class="hidden-input"
						id="file-input"
						disabled={isUploading}
					/>
					<label for="file-input" class="browse-btn" class:disabled={isUploading}>
						Choose Excel File
					</label>
				</div>
			{/if}
		</div>
	</div>

	<!-- Requirements Section -->
	<div class="requirements-section">
		<h3>📋 Excel File Requirements</h3>
		<div class="requirements-grid">
			<div class="requirement-item">
				<span class="req-icon">📄</span>
				<div class="req-content">
					<h4>File Format</h4>
					<p>Excel files only (.xlsx, .xls)</p>
				</div>
			</div>
			<div class="requirement-item">
				<span class="req-icon">📊</span>
				<div class="req-content">
					<h4>Required Columns</h4>
					<p>ERP Vendor ID (number), Vendor Name (text)</p>
				</div>
			</div>
			<div class="requirement-item">
				<span class="req-icon">🌐</span>
				<div class="req-content">
					<h4>Language Support</h4>
					<p>English, Arabic, or mixed text with special characters</p>
				</div>
			</div>
			<div class="requirement-item">
				<span class="req-icon">📏</span>
				<div class="req-content">
					<h4>File Size</h4>
					<p>Maximum 50MB</p>
				</div>
			</div>
		</div>
	</div>

	<!-- Upload Progress -->
	{#if isUploading || uploadProgress > 0}
		<div class="progress-section">
			<h4>Upload Progress</h4>
			<div class="progress-bar">
				<div class="progress-fill" style="width: {uploadProgress}%"></div>
			</div>
			<div class="progress-details">
				<span class="progress-text">{uploadProgress}% completed</span>
				<span class="progress-status">{uploadStatus}</span>
			</div>
		</div>
	{/if}

	<!-- Upload Results -->
	{#if uploadResults}
		<div class="results-section">
			<h4>📊 Upload Results</h4>
			<div class="results-grid">
				<div class="result-card success">
					<div class="result-number">{uploadResults.totalRecords}</div>
					<div class="result-label">Total Records</div>
				</div>
				<div class="result-card success">
					<div class="result-number">{uploadResults.successful}</div>
					<div class="result-label">Successful</div>
				</div>
				<div class="result-card warning">
					<div class="result-number">{uploadResults.duplicates}</div>
					<div class="result-label">Duplicates</div>
				</div>
				<div class="result-card error">
					<div class="result-number">{uploadResults.failed}</div>
					<div class="result-label">Failed</div>
				</div>
			</div>

			{#if uploadResults.errors.length > 0}
				<div class="errors-section">
					<h5>❌ Errors Found</h5>
					<ul class="error-list">
						{#each uploadResults.errors as error}
							<li>Row {error.row}: {error.error}</li>
						{/each}
					</ul>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Status Messages -->
	{#if uploadStatus && !isUploading}
		<div class="status-message {uploadStatus.includes('Error') ? 'error' : 'success'}">
			{uploadStatus}
		</div>
	{/if}

	<!-- Action Buttons -->
	<div class="action-buttons">
		<button class="btn btn-secondary" on:click={resetUpload} disabled={isUploading}>
			🔄 Reset
		</button>
		<button 
			class="btn btn-primary" 
			on:click={uploadFile} 
			disabled={!selectedFile || isUploading}
		>
			{#if isUploading}
				<span class="spinner"></span> Uploading...
			{:else}
				📤 Upload Vendors
			{/if}
		</button>
	</div>
</div>

<style>
	.upload-vendor {
		padding: 24px;
		height: 100%;
		background: white;
		overflow-y: auto;
	}

	.header {
		text-align: center;
		margin-bottom: 32px;
	}

	.title {
		font-size: 28px;
		font-weight: 700;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.template-section {
		margin-bottom: 32px;
	}

	.template-card {
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
		border: 2px solid #3b82f6;
		border-radius: 12px;
		padding: 20px;
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.template-icon {
		font-size: 32px;
	}

	.template-content {
		flex: 1;
	}

	.template-content h3 {
		margin: 0 0 4px 0;
		color: #1e40af;
		font-size: 18px;
		font-weight: 600;
	}

	.template-content p {
		margin: 0;
		color: #3730a3;
		font-size: 14px;
	}

	.template-btn {
		padding: 12px 20px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.template-btn:hover {
		background: #2563eb;
	}

	.upload-section {
		margin-bottom: 32px;
	}

	.file-drop-zone {
		border: 2px dashed #d1d5db;
		border-radius: 12px;
		padding: 40px;
		text-align: center;
		transition: all 0.3s;
		background: #fafafa;
	}

	.file-drop-zone.drag-over {
		border-color: #3b82f6;
		background: #eff6ff;
		transform: scale(1.02);
	}

	.file-drop-zone.file-selected {
		border-color: #10b981;
		background: #ecfdf5;
	}

	.drop-instructions {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
	}

	.upload-icon {
		font-size: 48px;
		opacity: 0.6;
	}

	.drop-instructions h3 {
		margin: 0;
		color: #374151;
		font-size: 20px;
	}

	.drop-instructions p {
		margin: 0;
		color: #6b7280;
		font-size: 16px;
	}

	.supported-formats {
		font-size: 12px;
		color: #9ca3af;
		font-style: italic;
	}

	.hidden-input {
		display: none;
	}

	.browse-btn {
		padding: 14px 28px;
		background: #3b82f6;
		color: white;
		border-radius: 8px;
		cursor: pointer;
		font-weight: 600;
		transition: all 0.2s;
		margin-top: 8px;
	}

	.browse-btn:hover:not(.disabled) {
		background: #2563eb;
		transform: translateY(-2px);
	}

	.browse-btn.disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.selected-file {
		display: flex;
		align-items: center;
		gap: 16px;
		padding: 20px;
		background: white;
		border-radius: 8px;
		border: 1px solid #10b981;
	}

	.file-icon {
		font-size: 36px;
	}

	.file-info {
		flex: 1;
	}

	.file-info h4 {
		margin: 0 0 4px 0;
		color: #111827;
		font-size: 18px;
		font-weight: 600;
	}

	.file-info p {
		margin: 0 0 8px 0;
		color: #6b7280;
		font-size: 14px;
	}

	.file-details {
		display: flex;
		gap: 12px;
	}

	.file-type {
		font-size: 12px;
		color: #059669;
		font-weight: 500;
	}

	.remove-file {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		cursor: pointer;
		font-size: 18px;
		font-weight: bold;
	}

	.remove-file:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.requirements-section {
		margin-bottom: 32px;
	}

	.requirements-section h3 {
		margin: 0 0 20px 0;
		color: #111827;
		font-size: 20px;
		font-weight: 600;
	}

	.requirements-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
		gap: 16px;
	}

	.requirement-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 16px;
		background: #f9fafb;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.req-icon {
		font-size: 24px;
	}

	.req-content h4 {
		margin: 0 0 4px 0;
		color: #111827;
		font-size: 14px;
		font-weight: 600;
	}

	.req-content p {
		margin: 0;
		color: #6b7280;
		font-size: 12px;
	}

	.progress-section {
		margin-bottom: 24px;
		padding: 20px;
		background: #f9fafb;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.progress-section h4 {
		margin: 0 0 12px 0;
		color: #111827;
		font-size: 16px;
		font-weight: 600;
	}

	.progress-bar {
		width: 100%;
		height: 12px;
		background: #e5e7eb;
		border-radius: 6px;
		overflow: hidden;
		margin-bottom: 12px;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #3b82f6 0%, #1d4ed8 100%);
		transition: width 0.3s ease;
		border-radius: 6px;
	}

	.progress-details {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: 14px;
	}

	.progress-text {
		font-weight: 600;
		color: #111827;
	}

	.progress-status {
		color: #6b7280;
	}

	.results-section {
		margin-bottom: 24px;
		padding: 20px;
		background: #f9fafb;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.results-section h4 {
		margin: 0 0 16px 0;
		color: #111827;
		font-size: 18px;
		font-weight: 600;
	}

	.results-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
		gap: 12px;
		margin-bottom: 20px;
	}

	.result-card {
		text-align: center;
		padding: 16px;
		border-radius: 8px;
		border: 2px solid;
	}

	.result-card.success {
		background: #ecfdf5;
		border-color: #10b981;
	}

	.result-card.warning {
		background: #fef3c7;
		border-color: #f59e0b;
	}

	.result-card.error {
		background: #fef2f2;
		border-color: #ef4444;
	}

	.result-number {
		font-size: 24px;
		font-weight: 700;
		margin-bottom: 4px;
	}

	.result-label {
		font-size: 12px;
		font-weight: 500;
		text-transform: uppercase;
	}

	.success .result-number, .success .result-label {
		color: #065f46;
	}

	.warning .result-number, .warning .result-label {
		color: #92400e;
	}

	.error .result-number, .error .result-label {
		color: #dc2626;
	}

	.errors-section h5 {
		margin: 0 0 12px 0;
		color: #dc2626;
		font-size: 16px;
		font-weight: 600;
	}

	.error-list {
		margin: 0;
		padding-left: 20px;
		color: #dc2626;
		font-size: 14px;
	}

	.error-list li {
		margin-bottom: 4px;
	}

	.status-message {
		padding: 12px 16px;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 500;
		margin-bottom: 24px;
	}

	.status-message.success {
		background: #dcfce7;
		color: #166534;
		border: 1px solid #10b981;
	}

	.status-message.error {
		background: #fef2f2;
		color: #dc2626;
		border: 1px solid #ef4444;
	}

	.action-buttons {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding-top: 20px;
		border-top: 1px solid #e5e7eb;
	}

	.btn {
		padding: 12px 24px;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:hover:not(:disabled) {
		background: #2563eb;
	}

	.btn-secondary {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-secondary:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.spinner {
		border: 2px solid transparent;
		border-top: 2px solid currentColor;
		border-radius: 50%;
		width: 16px;
		height: 16px;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>