<script>
	import { onMount } from 'svelte';
	import { dataService } from '$lib/utils/dataService';
	import * as XLSX from 'xlsx';

	// State management
	let branches = [];
	let selectedBranch = '';
	let uploadedFile = null;
	let dragActive = false;
	let isUploading = false;
	let uploadProgress = 0;
	let uploadResult = null;
	let errorMessage = '';
	let fingerprintData = [];
	let showPreview = false;

	// File input reference
	let fileInput;

	// Data arrays loaded from database

	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		try {
			const { data: branchesData, error } = await dataService.branches.getAll();
			if (error) {
				console.error('Error loading branches:', error);
				errorMessage = 'Failed to load branches: ' + (error.message || error);
				return;
			}
			branches = branchesData || [];
		} catch (error) {
			console.error('Error in loadBranches:', error);
			errorMessage = error.message || 'Failed to load branches';
		}
	}

	function downloadTemplate() {
		// Create CSV content with proper format
		const csvContent = [
			'Employee ID,Name,Date,Time,Punch State',
			'EMP001,Ahmed Mohammed Ali,2024-09-25,08:00 AM,Check In',
			'EMP001,Ahmed Mohammed Ali,2024-09-25,05:30 PM,Check Out',
			'EMP002,Fatima Ahmed Salem,2024-09-25,08:15 AM,Check In',
			'EMP002,Fatima Ahmed Salem,2024-09-25,05:45 PM,Check Out',
			'EMP003,Khalid Abdullah Al-Mutairi,2024-09-25,09:00 AM,Check In',
			'EMP003,Khalid Abdullah Al-Mutairi,2024-09-25,06:00 PM,Check Out'
		].join('\n');

		// Create and download the file
		const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
		const link = document.createElement('a');
		const url = URL.createObjectURL(blob);
		link.setAttribute('href', url);
		link.setAttribute('download', 'fingerprint_transactions_template.csv');
		link.style.visibility = 'hidden';
		document.body.appendChild(link);
		link.click();
		document.body.removeChild(link);
		URL.revokeObjectURL(url);
	}

	function handleDragOver(event) {
		event.preventDefault();
		dragActive = true;
	}

	function handleDragLeave(event) {
		event.preventDefault();
		dragActive = false;
	}

	function handleDrop(event) {
		event.preventDefault();
		dragActive = false;
		const files = event.dataTransfer.files;
		handleFileSelection(files);
	}

	function handleFileInput(event) {
		const files = event.target.files;
		handleFileSelection(files);
	}

	function handleFileSelection(files) {
		if (files.length === 0) return;

		const file = files[0];
		
		// Validate file type
		const allowedTypes = [
			'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
			'application/vnd.ms-excel', // .xls
			'text/csv' // .csv
		];
		
		if (!allowedTypes.includes(file.type)) {
			errorMessage = 'Please select an Excel file (.xlsx, .xls) or CSV file (.csv)';
			return;
		}

		// Validate file size (max 10MB)
		if (file.size > 10 * 1024 * 1024) {
			errorMessage = 'File size must be less than 10MB';
			return;
		}

		uploadedFile = file;
		errorMessage = '';
		uploadResult = null;
		showPreview = false;
	}

	function removeFile() {
		uploadedFile = null;
		uploadResult = null;
		errorMessage = '';
		showPreview = false;
		if (fileInput) {
			fileInput.value = '';
		}
	}

	async function processFile() {
		if (!uploadedFile) {
			errorMessage = 'Please select a file first';
			return;
		}

		if (!selectedBranch) {
			errorMessage = 'Please select a branch first';
			return;
		}

		isUploading = true;
		uploadProgress = 0;
		errorMessage = '';

		try {
			// Read the Excel file
			uploadProgress = 20;
			const fileBuffer = await uploadedFile.arrayBuffer();
			const workbook = XLSX.read(fileBuffer, { type: 'buffer' });
			const sheetName = workbook.SheetNames[0];
			const worksheet = workbook.Sheets[sheetName];
			const data = XLSX.utils.sheet_to_json(worksheet);

			uploadProgress = 50;

			// Validate data structure
			if (!data || data.length === 0) {
				errorMessage = 'Excel file is empty or has no valid data';
				return;
			}

			// Check required columns
			const firstRow = data[0];
			const requiredColumns = ['Employee ID', 'Name', 'Date', 'Time', 'Punch State'];
			const missingColumns = requiredColumns.filter(col => !(col in firstRow));
			
			if (missingColumns.length > 0) {
				errorMessage = `Missing required columns: ${missingColumns.join(', ')}`;
				return;
			}

			uploadProgress = 80;

			// Process the data
			fingerprintData = data.map((row, index) => ({
				employeeId: row['Employee ID']?.toString().trim(),
				name: row['Name']?.toString().trim(),
				date: row['Date'],
				time: row['Time']?.toString().trim(),
				punchState: row['Punch State']?.toString().trim(),
				deviceId: row['Device ID']?.toString().trim() || null,
				rowIndex: index + 2 // For error reporting
			})).filter(item => item.employeeId && item.name && item.date && item.time && item.punchState);

			uploadProgress = 100;
			
			uploadResult = {
				success: true,
				totalRecords: fingerprintData.length,
				validRecords: fingerprintData.length,
				invalidRecords: 0,
				duplicateRecords: 0,
				processedAt: new Date().toISOString()
			};

			showPreview = true;

		} catch (error) {
			errorMessage = 'Failed to process file. Please check the file format and try again.';
			uploadResult = {
				success: false,
				error: 'File processing failed'
			};
		} finally {
			isUploading = false;
			uploadProgress = 0;
		}
	}

	async function saveTransactions() {
		if (!fingerprintData.length) return;

		isUploading = true;
		errorMessage = '';

		try {
			// Prepare transactions for database
			const transactions = fingerprintData.map(item => {
				// Handle date conversion more robustly
				let transactionDate;
				try {
					// If item.date is already a Date object or valid date string
					const dateObj = new Date(item.date);
					if (isNaN(dateObj.getTime())) {
						throw new Error('Invalid date');
					}
					transactionDate = dateObj.toISOString().split('T')[0]; // Convert to YYYY-MM-DD format
				} catch (error) {
					console.error('Date conversion error for:', item.date, error);
					// Fallback to current date if date parsing fails
					transactionDate = new Date().toISOString().split('T')[0];
				}

				return {
					employee_id: item.employeeId,
					name: item.name,
					branch_id: selectedBranch, // Use selectedBranch as-is (should match the branch.id type)
					transaction_date: transactionDate,
					transaction_time: item.time,
					punch_state: item.punchState,
					device_id: item.deviceId || 'DEFAULT'
				};
			});

			// Save to database
			const result = await dataService.hrFingerprint.createMany(transactions);
			
			if (result.error && result.errorCount > 0) {
				uploadResult = {
					...uploadResult,
					saved: true,
					savedAt: new Date().toISOString(),
					successCount: result.successCount,
					errorCount: result.errorCount,
					errors: result.errors,
					hasErrors: true
				};
				
				// Show first few errors
				if (result.errors.length > 0) {
					errorMessage = `${result.errorCount} transactions failed. First error: ${result.errors[0]}`;
				}
			} else {
				uploadResult = {
					...uploadResult,
					saved: true,
					savedAt: new Date().toISOString(),
					successCount: result.successCount,
					errorCount: 0,
					hasErrors: false
				};
			}

		} catch (error) {
			console.error('Error saving fingerprint transactions:', error);
			errorMessage = error.message || 'Failed to save fingerprint transactions';
		} finally {
			isUploading = false;
		}
	}

	function resetUpload() {
		uploadedFile = null;
		uploadResult = null;
		errorMessage = '';
		showPreview = false;
		fingerprintData = [];
		uploadProgress = 0;
		if (fileInput) {
			fileInput.value = '';
		}
	}

	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
	}

	function formatDate(dateString) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function formatTime(timeString) {
		return timeString;
	}

	function getPunchStateColor(state) {
		return state === 'Check In' ? 'text-green-600 bg-green-50' : 'text-red-600 bg-red-50';
	}

	function getBranchName(branchId) {
		const branch = branches.find(b => b.id === parseInt(branchId));
		return branch ? `${branch.name_en} (${branch.location_en})` : 'Unknown Branch';
	}
</script>

<div class="upload-fingerprint">
	<!-- Header -->
	<div class="header">
		<h2 class="title">Biometric Data</h2>
		<p class="subtitle">Upload employee attendance data from fingerprint devices</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Branch Selection -->
		<div class="branch-section">
			<h3>Select Branch</h3>
			<p class="section-description">Choose the branch for which you're uploading fingerprint transactions</p>
			
			<select 
				bind:value={selectedBranch}
				disabled={isUploading}
				class="branch-select"
			>
				<option value="">Choose a branch...</option>
				{#each branches as branch}
					<option value={branch.id}>
						{branch.name_en} ({branch.name_ar}) - {branch.location_en}
					</option>
				{/each}
			</select>
		</div>

		<!-- Template Download -->
		<div class="template-section">
			<div class="template-header">
				<div>
					<h3>Excel Template</h3>
					<p class="section-description">Download the template to ensure your data is in the correct format</p>
				</div>
				<button 
					class="download-btn"
					on:click={downloadTemplate}
					disabled={isUploading}
				>
					<span class="icon">📥</span>
					Download Template
				</button>
			</div>

			<div class="template-info">
				<h4>Template Format:</h4>
				<div class="format-details">
					<div class="format-item">
						<strong>Employee ID:</strong> <code>EMP001</code>
					</div>
					<div class="format-item">
						<strong>Name:</strong> <code>Ahmed Mohammed Ali</code>
					</div>
					<div class="format-item">
						<strong>Date:</strong> <code>yyyy-mm-dd</code> (e.g., 2024-09-25)
					</div>
					<div class="format-item">
						<strong>Time:</strong> <code>hh:mm AM/PM</code> (e.g., 08:00 AM, 05:30 PM)
					</div>
					<div class="format-item">
						<strong>Punch State:</strong> <code>Check In</code> or <code>Check Out</code>
					</div>
				</div>
			</div>
		</div>

		<!-- File Upload Section -->
		<div class="upload-section">
			<h3>Upload File</h3>
			<p class="section-description">Drag and drop your Excel file or click to browse</p>

			<!-- Drag and Drop Area -->
			<div 
				class="upload-area {dragActive ? 'drag-active' : ''} {uploadedFile ? 'has-file' : ''}"
				on:dragover={handleDragOver}
				on:dragleave={handleDragLeave}
				on:drop={handleDrop}
				role="button"
				tabindex="0"
			>
				{#if !uploadedFile}
					<div class="upload-placeholder">
						<div class="upload-icon">📊</div>
						<h4>Drop your Excel file here</h4>
						<p>or click to browse files</p>
						<p class="file-types">Supports: .xlsx, .xls, .csv (max 10MB)</p>
						<button 
							class="browse-btn"
							on:click={() => fileInput?.click()}
							disabled={isUploading}
						>
							Browse Files
						</button>
					</div>
				{:else}
					<div class="file-info">
						<div class="file-icon">📊</div>
						<div class="file-details">
							<div class="file-name">{uploadedFile.name}</div>
							<div class="file-size">{formatFileSize(uploadedFile.size)}</div>
							<div class="file-type">
								{uploadedFile.type || 'Unknown type'}
							</div>
						</div>
						<button 
							class="remove-file-btn"
							on:click={removeFile}
							disabled={isUploading}
							title="Remove file"
						>
							❌
						</button>
					</div>
				{/if}
			</div>

			<!-- Hidden file input -->
			<input
				bind:this={fileInput}
				type="file"
				accept=".xlsx,.xls,.csv"
				on:change={handleFileInput}
				style="display: none;"
			>
		</div>

		<!-- Error Message -->
		{#if errorMessage}
			<div class="error-message">
				<strong>Error:</strong> {errorMessage}
			</div>
		{/if}

		<!-- Upload Progress -->
		{#if isUploading && uploadProgress > 0}
			<div class="progress-section">
				<div class="progress-header">
					<span>Processing file...</span>
					<span>{uploadProgress}%</span>
				</div>
				<div class="progress-bar">
					<div class="progress-fill" style="width: {uploadProgress}%"></div>
				</div>
			</div>
		{/if}

		<!-- Process File Button -->
		{#if uploadedFile && !showPreview}
			<div class="actions">
				<button 
					class="process-btn"
					on:click={processFile}
					disabled={isUploading || !selectedBranch}
				>
					{#if isUploading}
						<span class="spinner"></span>
						Processing...
					{:else}
						<span class="icon">⚙️</span>
						Process File
					{/if}
				</button>
			</div>
		{/if}

		<!-- Upload Result -->
		{#if uploadResult}
			<div class="result-section">
				{#if uploadResult.success}
					<div class="result-success">
						<div class="result-header">
							<span class="result-icon">✅</span>
							<h4>File Processed Successfully</h4>
						</div>
						<div class="result-stats">
							<div class="stat-item">
								<span class="stat-label">Total Records:</span>
								<span class="stat-value">{uploadResult.totalRecords}</span>
							</div>
							<div class="stat-item">
								<span class="stat-label">Valid Records:</span>
								<span class="stat-value text-green-600">{uploadResult.validRecords}</span>
							</div>
							{#if uploadResult.invalidRecords > 0}
								<div class="stat-item">
									<span class="stat-label">Invalid Records:</span>
									<span class="stat-value text-red-600">{uploadResult.invalidRecords}</span>
								</div>
							{/if}
							{#if uploadResult.duplicateRecords > 0}
								<div class="stat-item">
									<span class="stat-label">Duplicate Records:</span>
									<span class="stat-value text-yellow-600">{uploadResult.duplicateRecords}</span>
								</div>
							{/if}
						</div>
						<div class="result-actions">
							{#if !uploadResult.saved}
								<button 
									class="save-btn"
									on:click={saveTransactions}
									disabled={isUploading}
								>
									{#if isUploading}
										<span class="spinner"></span>
										Saving...
									{:else}
										<span class="icon">💾</span>
										Save Transactions
									{/if}
								</button>
							{:else}
								<div class="saved-message">
									<span class="icon">✅</span>
									Transactions saved successfully!
								</div>
							{/if}
							<button 
								class="reset-btn"
								on:click={resetUpload}
								disabled={isUploading}
							>
								<span class="icon">🔄</span>
								Upload New File
							</button>
						</div>
					</div>
				{:else}
					<div class="result-error">
						<div class="result-header">
							<span class="result-icon">❌</span>
							<h4>File Processing Failed</h4>
						</div>
						<p>Please check your file format and try again.</p>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Data Preview -->
		{#if showPreview && fingerprintData.length > 0}
			<div class="preview-section">
				<div class="preview-header">
					<h3>Data Preview</h3>
					<p class="section-description">
						Showing {Math.min(10, fingerprintData.length)} of {fingerprintData.length} records
					</p>
				</div>

				<div class="preview-info">
					<div class="info-item">
						<strong>Branch:</strong> {getBranchName(selectedBranch)}
					</div>
					<div class="info-item">
						<strong>File:</strong> {uploadedFile.name}
					</div>
					<div class="info-item">
						<strong>Processed:</strong> {formatDate(uploadResult.processedAt)}
					</div>
				</div>

				<div class="table-container">
					<table class="preview-table">
						<thead>
							<tr>
								<th>Employee ID</th>
								<th>Name</th>
								<th>Date</th>
								<th>Time</th>
								<th>Punch State</th>
							</tr>
						</thead>
						<tbody>
							{#each fingerprintData.slice(0, 10) as transaction, index (index)}
								<tr class="table-row">
									<td class="employee-id">{transaction.employeeId}</td>
									<td class="employee-name">{transaction.name}</td>
									<td class="date">{formatDate(transaction.date)}</td>
									<td class="time">{formatTime(transaction.time)}</td>
									<td class="punch-state">
										<span class="punch-badge {getPunchStateColor(transaction.punchState)}">
											{transaction.punchState}
										</span>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>

				{#if fingerprintData.length > 10}
					<div class="more-records">
						<p>... and {fingerprintData.length - 10} more records</p>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>

<style>
	.upload-fingerprint {
		padding: 24px;
		height: 100%;
		overflow-y: auto;
		background: white;
	}

	.header {
		margin-bottom: 32px;
		text-align: center;
	}

	.title {
		font-size: 28px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.subtitle {
		font-size: 16px;
		color: #6b7280;
		margin: 0;
	}

	.content {
		max-width: 1200px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: 32px;
	}

	.branch-section, .template-section, .upload-section {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 24px;
	}

	.branch-section h3, .template-section h3, .upload-section h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.section-description {
		color: #6b7280;
		margin: 0 0 16px 0;
	}

	.branch-select {
		width: 100%;
		max-width: 500px;
		padding: 12px 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 16px;
		background: white;
		font-family: inherit;
		transition: all 0.2s;
	}

	.branch-select:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.branch-select:disabled {
		background: #f3f4f6;
		cursor: not-allowed;
	}

	.template-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 20px;
	}

	.download-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px 20px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
		flex-shrink: 0;
	}

	.download-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.download-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.template-info {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 20px;
	}

	.template-info h4 {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 16px 0;
	}

	.format-details {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
		gap: 12px;
	}

	.format-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.format-item:last-child {
		border-bottom: none;
	}

	.format-item strong {
		color: #374151;
		min-width: 100px;
	}

	.format-item code {
		background: #f3f4f6;
		padding: 2px 6px;
		border-radius: 4px;
		font-family: 'Courier New', monospace;
		font-size: 14px;
		color: #1f2937;
	}

	.upload-area {
		border: 2px dashed #d1d5db;
		border-radius: 12px;
		padding: 48px;
		text-align: center;
		background: white;
		transition: all 0.3s;
		cursor: pointer;
	}

	.upload-area.drag-active {
		border-color: #6366f1;
		background: #eff6ff;
	}

	.upload-area.has-file {
		cursor: default;
	}

	.upload-placeholder {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
	}

	.upload-icon {
		font-size: 48px;
		margin-bottom: 8px;
	}

	.upload-placeholder h4 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.upload-placeholder p {
		color: #6b7280;
		margin: 0;
	}

	.file-types {
		font-size: 14px;
		color: #9ca3af;
	}

	.browse-btn {
		background: #6366f1;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px 24px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		margin-top: 16px;
	}

	.browse-btn:hover:not(:disabled) {
		background: #4f46e5;
		transform: translateY(-1px);
	}

	.browse-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.file-info {
		display: flex;
		align-items: center;
		gap: 16px;
		padding: 20px;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
	}

	.file-icon {
		font-size: 32px;
		flex-shrink: 0;
	}

	.file-details {
		flex: 1;
		text-align: left;
	}

	.file-name {
		font-size: 16px;
		font-weight: 600;
		color: #111827;
		margin-bottom: 4px;
	}

	.file-size {
		font-size: 14px;
		color: #6b7280;
		margin-bottom: 2px;
	}

	.file-type {
		font-size: 12px;
		color: #9ca3af;
	}

	.remove-file-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 8px;
		border-radius: 4px;
		transition: all 0.2s;
		flex-shrink: 0;
	}

	.remove-file-btn:hover:not(:disabled) {
		background: #fef2f2;
	}

	.remove-file-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 8px;
	}

	.progress-section {
		background: #f0f9ff;
		border: 1px solid #bae6fd;
		border-radius: 8px;
		padding: 20px;
	}

	.progress-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 12px;
		font-weight: 500;
		color: #0369a1;
	}

	.progress-bar {
		background: #e0f2fe;
		border-radius: 8px;
		height: 8px;
		overflow: hidden;
	}

	.progress-fill {
		background: #0ea5e9;
		height: 100%;
		border-radius: 8px;
		transition: width 0.3s ease;
	}

	.actions {
		display: flex;
		justify-content: center;
	}

	.process-btn {
		background: #059669;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 14px 28px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.process-btn:hover:not(:disabled) {
		background: #047857;
		transform: translateY(-1px);
	}

	.process-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.result-section {
		border-radius: 12px;
		overflow: hidden;
	}

	.result-success {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		padding: 24px;
	}

	.result-error {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 24px;
	}

	.result-header {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 20px;
	}

	.result-icon {
		font-size: 24px;
	}

	.result-header h4 {
		font-size: 18px;
		font-weight: 600;
		color: #059669;
		margin: 0;
	}

	.result-error .result-header h4 {
		color: #dc2626;
	}

	.result-stats {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 16px;
		margin-bottom: 24px;
	}

	.stat-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		background: white;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.stat-label {
		font-weight: 500;
		color: #374151;
	}

	.stat-value {
		font-weight: 600;
		font-size: 18px;
		color: #111827;
	}

	.result-actions {
		display: flex;
		gap: 16px;
		align-items: center;
	}

	.save-btn, .reset-btn {
		padding: 10px 20px;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.save-btn {
		background: #059669;
		color: white;
		border-color: #059669;
	}

	.save-btn:hover:not(:disabled) {
		background: #047857;
		transform: translateY(-1px);
	}

	.reset-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.reset-btn:hover:not(:disabled) {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.save-btn:disabled, .reset-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	.saved-message {
		background: #d1fae5;
		color: #065f46;
		padding: 10px 16px;
		border-radius: 6px;
		display: flex;
		align-items: center;
		gap: 8px;
		font-weight: 500;
	}

	.preview-section {
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		overflow: hidden;
	}

	.preview-header {
		padding: 20px 24px;
		background: #f9fafb;
		border-bottom: 1px solid #e5e7eb;
	}

	.preview-header h3 {
		font-size: 18px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 8px 0;
	}

	.preview-info {
		display: flex;
		gap: 24px;
		margin-bottom: 20px;
		flex-wrap: wrap;
	}

	.info-item {
		display: flex;
		align-items: center;
		gap: 8px;
		color: #4b5563;
	}

	.info-item strong {
		color: #111827;
	}

	.table-container {
		overflow-x: auto;
	}

	.preview-table {
		width: 100%;
		border-collapse: collapse;
	}

	.preview-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.preview-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f3f4f6;
	}

	.table-row:hover {
		background: #f9fafb;
	}

	.employee-id {
		font-family: 'Courier New', monospace;
		font-weight: 600;
		color: #3b82f6;
	}

	.employee-name {
		font-weight: 500;
		color: #111827;
	}

	.date, .time {
		font-family: 'Courier New', monospace;
		color: #4b5563;
	}

	.punch-badge {
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		display: inline-block;
	}

	.more-records {
		padding: 16px 24px;
		text-align: center;
		color: #6b7280;
		font-style: italic;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
	}

	.more-records p {
		margin: 0;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.icon {
		font-size: 14px;
	}

	@media (max-width: 768px) {
		.template-header {
			flex-direction: column;
			align-items: flex-start;
			gap: 16px;
		}

		.format-details {
			grid-template-columns: 1fr;
		}

		.upload-area {
			padding: 32px 16px;
		}

		.result-stats {
			grid-template-columns: 1fr;
		}

		.result-actions {
			flex-direction: column;
			align-items: stretch;
		}

		.preview-info {
			flex-direction: column;
			gap: 12px;
		}

		.preview-table th,
		.preview-table td {
			padding: 8px 12px;
			font-size: 14px;
		}
	}
</style>