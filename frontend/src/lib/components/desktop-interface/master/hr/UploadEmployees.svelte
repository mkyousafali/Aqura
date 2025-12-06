<script>
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';
	import { dataService } from '$lib/utils/dataService';
	import { supabase } from '$lib/utils/supabase';
	import * as XLSX from 'xlsx';

	// State management
	let selectedBranch = '';
	let branches = [];
	let isLoading = false;
	let errorMessage = '';
	let uploadedFile = null;
	let dragOver = false;

	let fileInput;

	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		isLoading = true;
		errorMessage = '';

		try {
			const { data: branchesData, error: branchesError } = await dataService.branches.getAll();
			if (branchesError) {
				console.error('Error loading branches:', branchesError);
				errorMessage = t('admin.failedToLoadBranches') + (branchesError.message || branchesError);
				return;
			}
			branches = branchesData || [];
		} catch (error) {
			console.error('Error in loadBranches:', error);
			errorMessage = error.message || t('admin.failedToLoadBranches');
		} finally {
			isLoading = false;
		}
	}

	function handleFileSelect() {
		fileInput.click();
	}

	function handleFileChange(event) {
		const file = event.target.files[0];
		if (file) {
			handleFile(file);
		}
	}

	function handleFile(file) {
		if (!file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
			errorMessage = t('hr.selectExcelFile');
			return;
		}
		
		uploadedFile = file;
		errorMessage = '';
	}

	function handleDragOver(event) {
		event.preventDefault();
		dragOver = true;
	}

	function handleDragLeave() {
		dragOver = false;
	}

	function handleDrop(event) {
		event.preventDefault();
		dragOver = false;
		
		const files = event.dataTransfer.files;
		if (files.length > 0) {
			handleFile(files[0]);
		}
	}

	function downloadTemplate() {
		// Create a simple CSV template
		const csvContent = "Employee ID,Name\nEMP001,John Doe\nEMP002,Jane Smith";
		const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
		const link = document.createElement('a');
		const url = URL.createObjectURL(blob);
		link.setAttribute('href', url);
		link.setAttribute('download', 'employee_template.csv');
		link.style.visibility = 'hidden';
		document.body.appendChild(link);
		link.click();
		document.body.removeChild(link);
	}

	async function uploadEmployees() {
		if (!selectedBranch) {
			errorMessage = t('hr.pleaseSelectBranch');
			return;
		}
		
		if (!uploadedFile) {
			errorMessage = t('hr.pleaseSelectFile');
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Read the Excel file
			const fileBuffer = await uploadedFile.arrayBuffer();
			const workbook = XLSX.read(fileBuffer, { type: 'buffer' });
			const sheetName = workbook.SheetNames[0];
			const worksheet = workbook.Sheets[sheetName];
			const data = XLSX.utils.sheet_to_json(worksheet);

			// Validate data structure
			if (!data || data.length === 0) {
				errorMessage = t('hr.excelFileEmpty');
				return;
			}

			// Check required columns
			const firstRow = data[0];
			const requiredColumns = ['Employee ID', 'Name'];
			const missingColumns = requiredColumns.filter(col => !(col in firstRow));
			
			if (missingColumns.length > 0) {
				errorMessage = t('hr.missingRequiredColumns') + ' ' + missingColumns.join(', ');
				return;
			}

			let successCount = 0;
			let errorCount = 0;
			const errors = [];

			// Process each employee
			for (const [index, row] of data.entries()) {
				try {
					const employeeData = {
						employee_id: row['Employee ID']?.toString().trim(),
						name: row['Name']?.toString().trim(),
						branch_id: parseInt(selectedBranch), // Convert to integer to match bigint type
						hire_date: row['Hire Date'] ? new Date(row['Hire Date']).toISOString().split('T')[0] : null,
						status: row['Status']?.toString().trim() || 'active'
					};

					// Validate employee data
					if (!employeeData.employee_id || !employeeData.name) {
						errors.push(`${t('hr.rowNumber')} ${index + 2}: ${t('hr.missingEmployeeIdOrName')}`);
						errorCount++;
						continue;
					}

					// Save to database using admin client to bypass RLS
					const { data: savedEmployee, error } = await dataService.hrEmployees.create ? 
						await dataService.hrEmployees.create(employeeData) :
						await supabase.from('hr_employees').insert([employeeData]).select().single();
					
					if (error) {
						errors.push(`${t('hr.rowNumber')} ${index + 2}: ${error.message}`);
						errorCount++;
					} else {
						successCount++;
					}
				} catch (rowError) {
					errors.push(`${t('hr.rowNumber')} ${index + 2}: ${rowError.message}`);
					errorCount++;
				}
			}

			// Show results
			const branchName = branches.find(b => b.id == selectedBranch)?.name_en;
			let resultMessage = `${t('hr.uploadCompleted')} ${branchName}:\n`;
			resultMessage += `✓ ${t('hr.successfullyUploaded')} ${successCount} ${t('hr.uploadedEmployeeCount')}\n`;
			
			if (errorCount > 0) {
				resultMessage += `✗ ${t('hr.failedCount')} ${errorCount}\n\n`;
				if (errors.length > 0) {
					resultMessage += t('hr.errors') + '\n' + errors.slice(0, 5).join('\n');
					if (errors.length > 5) {
						resultMessage += `\n... ${errors.length - 5} ${t('hr.andMoreErrors')}`;
					}
				}
			}

			alert(resultMessage);
			
			// Reset form only if there were some successes
			if (successCount > 0) {
				selectedBranch = '';
				uploadedFile = null;
				if (fileInput) fileInput.value = '';
			}
			
		} catch (error) {
			console.error('Upload error:', error);
			errorMessage = t('hr.failedToProcessExcel') + ' ' + error.message;
		} finally {
			isLoading = false;
		}
	}

	function removeFile() {
		uploadedFile = null;
		if (fileInput) fileInput.value = '';
	}
</script>

<div class="upload-employees">
	<!-- Header -->
	<div class="header">
		<h2 class="title">{t('hr.uploadEmployeesTitle')}</h2>
		<p class="subtitle">{t('hr.uploadEmployeesSubtitle')}</p>
	</div>

	<!-- Content -->
	<div class="content">
		<!-- Branch Selection -->
		<div class="section">
			<h3>1. {t('hr.selectBranchLabel')}</h3>
			<div class="form-group">
				<label for="branch-select">{t('hr.chooseBranch')}</label>
				<select id="branch-select" bind:value={selectedBranch} required>
					<option value="">{t('hr.selectABranch')}</option>
					{#each branches as branch}
						<option value={branch.id}>
							{branch.name_en} - {branch.name_ar}
						</option>
					{/each}
				</select>
			</div>
		</div>

		<!-- File Upload -->
		<div class="section">
			<h3>2. {t('hr.uploadExcelFileLabel')}</h3>
			
			<div 
				class="upload-zone {dragOver ? 'drag-over' : ''} {uploadedFile ? 'has-file' : ''}"
				on:dragover={handleDragOver}
				on:dragleave={handleDragLeave}
				on:drop={handleDrop}
				on:click={handleFileSelect}
			>
				{#if uploadedFile}
					<div class="file-info">
						<div class="file-icon">📄</div>
						<div class="file-details">
							<div class="file-name">{uploadedFile.name}</div>
							<div class="file-size">{(uploadedFile.size / 1024).toFixed(1)} KB</div>
						</div>
						<button class="remove-file" on:click|stopPropagation={removeFile}>×</button>
					</div>
				{:else}
					<div class="upload-prompt">
						<div class="upload-icon">📁</div>
						<h4>{t('hr.dropYourExcelFile')}</h4>
						<p>{t('hr.orClickToBrowse')}</p>
						<div class="file-types">{t('hr.supportedFormats')}</div>
					</div>
				{/if}
			</div>

			<input 
				type="file" 
				bind:this={fileInput}
				on:change={handleFileChange}
				accept=".xlsx,.xls" 
				style="display: none;"
			>
		</div>

		<!-- Template Section -->
		<div class="section">
			<h3>3. {t('hr.excelTemplateLabel')}</h3>
			<div class="template-info">
				<div class="template-details">
					<h4>{t('hr.requiredFormat')}</h4>
					<p>{t('hr.yourExcelFileShouldContain')}</p>
					<ul>
						<li><strong>{t('hr.employeeIdLabel')}</strong> - {t('hr.employeeIdDesc')}</li>
						<li><strong>{t('hr.nameLabel')}</strong> - {t('hr.nameDesc')}</li>
					</ul>
				</div>
				<button type="button" class="template-btn" on:click={downloadTemplate}>
					<span class="icon">⬇️</span>
					{t('hr.downloadTemplate')}
				</button>
			</div>
		</div>

		<!-- Error Message -->
		{#if errorMessage}
			<div class="error-message">
				<strong>{t('common.error')}:</strong> {errorMessage}
			</div>
		{/if}

		<!-- Actions -->
		<div class="actions">
			<button 
				type="button" 
				class="upload-btn" 
				on:click={uploadEmployees}
				disabled={isLoading || !selectedBranch || !uploadedFile}
			>
				{#if isLoading}
					<span class="spinner"></span>
					{t('hr.uploading')}
				{:else}
					<span class="icon">🚀</span>
					{t('hr.uploadEmployeesBtn')}
				{/if}
			</button>
		</div>
	</div>
</div>

<style>
	.upload-employees {
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
		max-width: 800px;
		margin: 0 auto;
	}

	.section {
		margin-bottom: 32px;
		padding: 24px;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		background: #f9fafb;
	}

	.section h3 {
		font-size: 20px;
		font-weight: 600;
		color: #111827;
		margin: 0 0 16px 0;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		margin-bottom: 8px;
		font-weight: 500;
		color: #374151;
	}

	.form-group select {
		width: 100%;
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 16px;
		background: white;
		transition: border-color 0.2s;
	}

	.form-group select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.upload-zone {
		border: 2px dashed #d1d5db;
		border-radius: 12px;
		padding: 48px 24px;
		text-align: center;
		cursor: pointer;
		transition: all 0.3s ease;
		background: white;
	}

	.upload-zone:hover {
		border-color: #3b82f6;
		background: #eff6ff;
	}

	.upload-zone.drag-over {
		border-color: #10b981;
		background: #ecfdf5;
	}

	.upload-zone.has-file {
		border-color: #10b981;
		background: #f0fdf4;
		border-style: solid;
	}

	.upload-prompt {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
	}

	.upload-icon {
		font-size: 48px;
		color: #6b7280;
	}

	.upload-prompt h4 {
		margin: 0;
		font-size: 18px;
		color: #111827;
	}

	.upload-prompt p {
		margin: 0;
		color: #6b7280;
	}

	.file-types {
		font-size: 12px;
		color: #9ca3af;
		margin-top: 8px;
	}

	.file-info {
		display: flex;
		align-items: center;
		gap: 16px;
		padding: 16px;
		background: white;
		border-radius: 8px;
		position: relative;
	}

	.file-icon {
		font-size: 32px;
	}

	.file-details {
		flex: 1;
		text-align: left;
	}

	.file-name {
		font-weight: 500;
		color: #111827;
		margin-bottom: 4px;
	}

	.file-size {
		font-size: 14px;
		color: #6b7280;
	}

	.remove-file {
		position: absolute;
		top: 8px;
		right: 8px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 16px;
		line-height: 1;
	}

	.template-info {
		display: flex;
		gap: 24px;
		align-items: flex-start;
	}

	.template-details {
		flex: 1;
	}

	.template-details h4 {
		margin: 0 0 8px 0;
		color: #111827;
	}

	.template-details p {
		margin: 0 0 12px 0;
		color: #6b7280;
	}

	.template-details ul {
		margin: 0;
		padding-left: 20px;
		color: #374151;
	}

	.template-details li {
		margin-bottom: 4px;
	}

	.template-btn {
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
		white-space: nowrap;
	}

	.template-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 24px;
	}

	.actions {
		text-align: center;
		margin-top: 32px;
	}

	.upload-btn {
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 16px 32px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		display: inline-flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.upload-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.upload-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		transform: none;
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
		font-size: 16px;
	}

	@media (max-width: 768px) {
		.template-info {
			flex-direction: column;
		}
		
		.section {
			padding: 16px;
		}
		
		.upload-zone {
			padding: 32px 16px;
		}
	}
</style>