<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';

	// Get task ID from URL params
	let taskId = '';
	let isLoading = true;
	let isSubmitting = false;
	let errorMessage = '';
	let successMessage = '';

	// Task data
	let taskDetails: any = null;
	let receivingRecord: any = null;

	// Current user
	$: currentUserData = $currentUser;

	// Form data for Inventory Manager
	let formData = {
		erp_purchase_invoice_reference: '',
		has_erp_purchase_invoice: false,
		has_pr_excel_file: false,
		has_original_bill: false,
		completion_notes: ''
	};

	// File upload states
	let prExcelFile: (File & { alreadyUploaded?: boolean }) | null = null;
	let originalBillFile: (File & { alreadyUploaded?: boolean }) | null = null;

	// Validation
	$: isFormValid = formData.erp_purchase_invoice_reference.trim() && 
					 formData.has_erp_purchase_invoice && 
					 formData.has_pr_excel_file && 
					 formData.has_original_bill;

	onMount(async () => {
		taskId = $page.params.id;
		
		if (!$isAuthenticated || !currentUserData) {
			goto('/login');
			return;
		}

		if (taskId) {
			await loadTaskDetails();
		}
		isLoading = false;
	});

	async function loadTaskDetails() {
		try {
			isLoading = true;
			
			// First get the receiving task with receiving record
			const { data: task, error: taskError } = await supabase
				.from('receiving_tasks')
				.select(`
					*,
					receiving_record:receiving_records(*)
				`)
				.eq('id', taskId)
				.eq('assigned_user_id', currentUserData.id)
				.eq('role_type', 'inventory_manager')
				.single();

			if (taskError || !task) {
				throw new Error('Task not found or not accessible');
			}

			taskDetails = task;
			receivingRecord = task.receiving_record;

			// Now get branch and vendor info separately if we have a receiving record
			if (receivingRecord) {
				// Get branch info
				const { data: branchData } = await supabase
					.from('branches')
					.select('name_en')
					.eq('id', receivingRecord.branch_id)
					.single();

				// Get vendor info
				const { data: vendorData } = await supabase
					.from('vendors')
					.select('vendor_name')
					.eq('erp_vendor_id', receivingRecord.vendor_id)
					.eq('branch_id', receivingRecord.branch_id)
					.single();

				// Attach the fetched data
				if (branchData) {
					receivingRecord.branch_name = branchData.name_en;
				}
				if (vendorData) {
					receivingRecord.vendor_name = vendorData.vendor_name;
				}

				// Pre-fill form if data exists - load from database with proper field names
				console.log('📋 [Mobile] Loading existing data:', receivingRecord);
				
			formData.erp_purchase_invoice_reference = receivingRecord.erp_purchase_invoice_reference || '';
			
			// Check for ERP reference
			if (receivingRecord.erp_purchase_invoice_reference) {
				formData.has_erp_purchase_invoice = true;
			}

			// Check for PR Excel file - look for URL, not boolean flag
			if (receivingRecord.pr_excel_file_url) {
				formData.has_pr_excel_file = true;
				// Create a fake File object to display the filename
				const fileName = receivingRecord.pr_excel_file_url.split('/').pop() || 'PR Excel (Already Uploaded)';
				prExcelFile = { name: fileName, alreadyUploaded: true } as any;
				console.log('✅ [Mobile] PR Excel file already uploaded:', receivingRecord.pr_excel_file_url);
			}

			// Check for Original Bill file - look for URL, not boolean flag
			if (receivingRecord.original_bill_url) {
				formData.has_original_bill = true;
				// Create a fake File object to display the filename
				const fileName = receivingRecord.original_bill_url.split('/').pop() || 'Original Bill (Already Uploaded)';
				originalBillFile = { name: fileName, alreadyUploaded: true } as any;
				console.log('✅ [Mobile] Original bill already uploaded:', receivingRecord.original_bill_url);
			}
		}		} catch (error) {
			console.error('Error loading task details:', error);
			errorMessage = error.message || 'Failed to load task details';
		} finally {
			isLoading = false;
		}
	}

	async function handlePRExcelUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			if (!file.name.toLowerCase().includes('.xls') && !file.name.toLowerCase().includes('.xlsx')) {
				errorMessage = 'Please select a valid Excel file (.xls or .xlsx)';
				return;
			}
			
			if (file.size > 10 * 1024 * 1024) { // 10MB limit
				errorMessage = 'Excel file must be less than 10MB';
				return;
			}
			
			errorMessage = '';
			prExcelFile = file;
			formData.has_pr_excel_file = true;

			// Immediately upload the file
			const uploadResult = await uploadFileToStorage(file, 'pr_excel');
			if (uploadResult) {
				console.log('✅ [Mobile] PR Excel file URL saved:', uploadResult.file_url);
			}
		}
	}

	async function handleOriginalBillUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			if (file.size > 10 * 1024 * 1024) { // 10MB limit
				errorMessage = 'File must be less than 10MB';
				return;
			}
			
			errorMessage = '';
			originalBillFile = file;
			formData.has_original_bill = true;

			// Immediately upload the file
			const uploadResult = await uploadFileToStorage(file, 'original_bill');
			if (uploadResult) {
				console.log('✅ [Mobile] Original bill file URL saved:', uploadResult.file_url);
			}
		}
	}

	function removePRExcelFile() {
		prExcelFile = null;
		formData.has_pr_excel_file = false;
		const fileInput = document.getElementById('pr-excel-upload') as HTMLInputElement;
		if (fileInput) fileInput.value = '';
	}

	function removeOriginalBillFile() {
		originalBillFile = null;
		formData.has_original_bill = false;
		const fileInput = document.getElementById('original-bill-upload') as HTMLInputElement;
		if (fileInput) fileInput.value = '';
	}

	// Incremental save functions
	let saveErpTimeout: ReturnType<typeof setTimeout> | null = null;
	async function saveErpReference() {
		if (!receivingRecord?.id || !formData.erp_purchase_invoice_reference?.trim()) {
			return;
		}

		try {
			console.log('💾 [Mobile] Saving ERP reference:', formData.erp_purchase_invoice_reference);
			
			const response = await fetch('/api/receiving-records/update-erp', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					receivingRecordId: receivingRecord.id,
					erpReference: formData.erp_purchase_invoice_reference.trim()
				})
			});

			const result = await response.json();
			
			if (!response.ok || result.error) {
				console.error('❌ [Mobile] Failed to save ERP reference:', result.error);
				errorMessage = 'Failed to save ERP reference. Please try again.';
				return;
			}

			console.log('✅ [Mobile] ERP reference saved successfully');
			
		} catch (err) {
			console.error('❌ [Mobile] Error saving ERP reference:', err);
			errorMessage = 'Failed to save ERP reference. Please try again.';
		}
	}

	// Debounced ERP reference save
	function onErpReferenceChange() {
		if (saveErpTimeout) {
			clearTimeout(saveErpTimeout);
		}
		saveErpTimeout = setTimeout(saveErpReference, 1000); // Save after 1 second of no typing
	}

	async function uploadFileToStorage(file: File, fileType: 'pr_excel' | 'original_bill') {
		if (!receivingRecord?.id || !file) {
			return null;
		}

		try {
			console.log(`📁 [Mobile] Uploading ${fileType} file:`, file.name);
			
			const formData = new FormData();
			formData.append('file', file);
			formData.append('receiving_record_id', receivingRecord.id);
			formData.append('file_type', fileType);

			const response = await fetch('/api/receiving-records/upload-file', {
				method: 'POST',
				body: formData
			});

			const result = await response.json();
			
			if (!response.ok || result.error) {
				console.error(`❌ [Mobile] Failed to upload ${fileType} file:`, result.error);
				errorMessage = `Failed to upload ${fileType === 'pr_excel' ? 'PR Excel' : 'Original Bill'} file. Please try again.`;
				return null;
			}

			console.log(`✅ [Mobile] ${fileType} file uploaded successfully:`, result.data.file_url);
			return result.data;
			
		} catch (err) {
			console.error(`❌ [Mobile] Error uploading ${fileType} file:`, err);
			errorMessage = `Failed to upload ${fileType === 'pr_excel' ? 'PR Excel' : 'Original Bill'} file. Please try again.`;
			return null;
		}
	}

	async function submitCompletion() {
		if (!currentUserData || !isFormValid) return;
		
		isSubmitting = true;
		errorMessage = '';
		successMessage = '';
		
		try {
			console.log('🚀 [Mobile] Submitting task completion...');

			// Submit completion (files are already uploaded incrementally)
			const response = await fetch('/api/receiving-tasks/complete', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					receiving_task_id: taskId,
					user_id: currentUserData.id,
					erp_reference: formData.erp_purchase_invoice_reference,
					has_erp_purchase_invoice: formData.has_erp_purchase_invoice,
					has_pr_excel_file: formData.has_pr_excel_file,
					has_original_bill: formData.has_original_bill,
					completion_notes: formData.completion_notes
				})
			});

			if (!response.ok) {
				const error = await response.json();
				throw new Error(error.error || 'Failed to complete task');
			}

			successMessage = 'Inventory Manager task completed successfully!';
			
			notifications.add({
				type: 'success',
				message: 'Task completed successfully!',
				duration: 3000
			});
			
			setTimeout(() => {
				goto('/mobile/tasks');
			}, 2000);
			
		} catch (error) {
			console.error('❌ [Mobile] Error completing task:', error);
			errorMessage = error.message || 'Failed to complete task';
			
			notifications.add({
				type: 'error',
				message: 'Failed to complete task. Please try again.',
				duration: 4000
			});
		} finally {
			isSubmitting = false;
		}
	}

	// Auto-update ERP checkbox when reference is entered
	$: if (formData.erp_purchase_invoice_reference.trim()) {
		formData.has_erp_purchase_invoice = true;
	} else {
		formData.has_erp_purchase_invoice = false;
	}
</script>

<svelte:head>
	<title>Complete Inventory Manager Task - Aqura Mobile</title>
</svelte:head>

<div class="mobile-inventory-completion">
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading task details...</p>
		</div>
	{:else if !taskDetails}
		<div class="error-state">
			<div class="error-icon">
				<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<circle cx="12" cy="12" r="10"/>
					<line x1="12" y1="8" x2="12" y2="12"/>
					<line x1="12" y1="16" x2="12.01" y2="16"/>
				</svg>
			</div>
			<h2>Task Not Found</h2>
			<p>This inventory manager task doesn't exist or you don't have access to it.</p>
			<button class="back-btn" on:click={() => goto('/mobile/tasks')}>
				← Back to Tasks
			</button>
		</div>
	{:else}
		<!-- Header -->
		<div class="header-section">
			<h1>📦 Complete Inventory Task</h1>
			<p class="task-title">{taskDetails.title}</p>
		</div>

		<!-- Task Details -->
		<div class="task-info-section">
			<h3>📋 Task Information</h3>
			<div class="info-grid">
				<div class="info-item">
					<label>Branch:</label>
					<span>{receivingRecord?.branch_name || 'Unknown'}</span>
				</div>
				<div class="info-item">
					<label>Vendor:</label>
					<span>{receivingRecord?.vendor_name || 'Unknown'}</span>
				</div>
				<div class="info-item">
					<label>Bill Number:</label>
					<span>{receivingRecord?.bill_number || 'N/A'}</span>
				</div>
				<div class="info-item">
					<label>Bill Amount:</label>
					<span>{receivingRecord?.bill_amount || 'N/A'}</span>
				</div>
				<div class="info-item">
					<label>Bill Date:</label>
					<span>{receivingRecord?.bill_date || 'Not set'}</span>
				</div>
			</div>
		</div>

		<!-- Messages -->
		{#if errorMessage}
			<div class="message error">
				<span class="icon">❌</span>
				{errorMessage}
			</div>
		{/if}

		{#if successMessage}
			<div class="message success">
				<span class="icon">✅</span>
				{successMessage}
			</div>
		{/if}

		<!-- Completion Form -->
		<div class="form-section">
			<h3>✅ Completion Requirements</h3>
			
			<!-- ERP Purchase Invoice Reference -->
			<div class="requirement-item">
				<div class="requirement-header">
					<span class="requirement-label required">🔢 ERP Purchase Invoice Reference</span>
					<input
						type="checkbox"
						bind:checked={formData.has_erp_purchase_invoice}
						disabled
						class="requirement-checkbox"
					/>
				</div>
				<div class="input-section">
					<input
						type="text"
						bind:value={formData.erp_purchase_invoice_reference}
						on:input={onErpReferenceChange}
						placeholder="Enter ERP purchase invoice reference number"
						disabled={isSubmitting}
						class="erp-input"
						required
					/>
				</div>
			</div>

			<!-- PR Excel File Upload -->
			<div class="requirement-item">
				<div class="requirement-header">
					<span class="requirement-label required">📊 PR Excel File</span>
					<input
						type="checkbox"
						bind:checked={formData.has_pr_excel_file}
						disabled
						class="requirement-checkbox"
					/>
				</div>
				
				{#if !prExcelFile}
					<div class="upload-section">
						<input
							id="pr-excel-upload"
							type="file"
							accept=".xls,.xlsx"
							on:change={handlePRExcelUpload}
							disabled={isSubmitting}
							class="file-input"
							required
						/>
						<label for="pr-excel-upload" class="upload-btn">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
								<polyline points="14,2 14,8 20,8"/>
								<line x1="16" y1="13" x2="8" y2="13"/>
								<line x1="16" y1="17" x2="8" y2="17"/>
								<polyline points="10,9 9,9 8,9"/>
							</svg>
							Choose Excel File
						</label>
					</div>
				{:else}
					<div class="file-preview">
						<div class="file-info">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
								<polyline points="14,2 14,8 20,8"/>
							</svg>
							<span class="file-name">{prExcelFile.name}</span>
						</div>
						{#if !prExcelFile.alreadyUploaded}
							<button class="remove-file" on:click={removePRExcelFile} disabled={isSubmitting}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M18 6L6 18M6 6l12 12"/>
								</svg>
							</button>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Original Bill Upload -->
			<div class="requirement-item">
				<div class="requirement-header">
					<span class="requirement-label required">📄 Original Bill</span>
					<input
						type="checkbox"
						bind:checked={formData.has_original_bill}
						disabled
						class="requirement-checkbox"
					/>
				</div>
				
				{#if !originalBillFile}
					<div class="upload-section">
						<input
							id="original-bill-upload"
							type="file"
							accept=".pdf,.jpg,.jpeg,.png"
							on:change={handleOriginalBillUpload}
							disabled={isSubmitting}
							class="file-input"
							required
						/>
						<label for="original-bill-upload" class="upload-btn">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
								<polyline points="7,10 12,15 17,10"/>
								<line x1="12" y1="15" x2="12" y2="3"/>
							</svg>
							Choose Bill File
						</label>
					</div>
				{:else}
					<div class="file-preview">
						<div class="file-info">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
								<polyline points="14,2 14,8 20,8"/>
							</svg>
							<span class="file-name">{originalBillFile.name}</span>
						</div>
						{#if !originalBillFile.alreadyUploaded}
							<button class="remove-file" on:click={removeOriginalBillFile} disabled={isSubmitting}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M18 6L6 18M6 6l12 12"/>
								</svg>
							</button>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Completion Notes -->
			<div class="requirement-item">
				<div class="requirement-header">
					<span class="requirement-label">📝 Additional Notes (Optional)</span>
				</div>
				<div class="input-section">
					<textarea
						bind:value={formData.completion_notes}
						placeholder="Add any additional notes about the inventory task completion..."
						disabled={isSubmitting}
						class="notes-textarea"
					></textarea>
				</div>
			</div>
		</div>

		<!-- Actions -->
		<div class="actions">
			<button class="cancel-btn" on:click={() => goto('/mobile/tasks')} disabled={isSubmitting}>
				Cancel
			</button>
			<button 
				class="complete-btn" 
				on:click={submitCompletion} 
				disabled={!isFormValid || isSubmitting}
				class:disabled={!isFormValid}
			>
				{#if isSubmitting}
					<div class="btn-spinner"></div>
					Completing Task...
				{:else}
					Complete Task
				{/if}
			</button>
		</div>
	{/if}
</div>

<style>
	.mobile-inventory-completion {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		min-height: 50vh;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top: 3px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	.error-icon {
		color: #EF4444;
		margin-bottom: 1rem;
	}

	.header-section {
		background: white;
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.header-section h1 {
		margin: 0 0 0.5rem 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}

	.task-title {
		margin: 0;
		font-size: 0.875rem;
		color: #6B7280;
		font-weight: 500;
	}

	.task-info-section,
	.form-section {
		background: white;
		margin: 1rem;
		padding: 1.5rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
	}

	.task-info-section h3,
	.form-section h3 {
		margin: 0 0 1rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
	}

	.info-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 0.75rem;
	}

	.info-item {
		display: flex;
		justify-content: space-between;
		padding: 0.75rem;
		background: #F9FAFB;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.info-item label {
		font-weight: 500;
		color: #374151;
		font-size: 0.875rem;
	}

	.info-item span {
		color: #1F2937;
		font-size: 0.875rem;
	}

	.message {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem 1.5rem;
		margin: 1rem;
		border-radius: 12px;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.message.error {
		background: #FEF2F2;
		color: #DC2626;
		border: 1px solid #FECACA;
	}

	.message.success {
		background: #F0FDF4;
		color: #059669;
		border: 1px solid #BBF7D0;
	}

	.requirement-item {
		margin-bottom: 1.5rem;
		padding: 1rem;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		background: #F9FAFB;
	}

	.requirement-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.75rem;
	}

	.requirement-label {
		font-weight: 500;
		font-size: 0.875rem;
	}

	.requirement-label.required {
		color: #DC2626;
	}

	.requirement-checkbox {
		width: 20px;
		height: 20px;
		accent-color: #10B981;
		cursor: pointer;
		border: 2px solid #10B981;
		border-radius: 4px;
	}

	.input-section {
		margin-top: 0.75rem;
	}

	.erp-input,
	.notes-textarea {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		transition: border-color 0.2s;
		resize: vertical;
		min-height: 2.5rem;
	}

	.notes-textarea {
		min-height: 80px;
		font-family: inherit;
	}

	.erp-input:focus,
	.notes-textarea:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.upload-section {
		margin-top: 0.75rem;
	}

	.file-input {
		display: none;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #3B82F6;
		color: white;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		border: none;
		text-decoration: none;
	}

	.upload-btn:hover {
		background: #2563EB;
	}

	.file-preview {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.75rem;
		background: white;
		border: 2px solid #10B981;
		border-radius: 8px;
		margin-top: 0.75rem;
	}

	.file-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #059669;
	}

	.file-name {
		font-size: 0.875rem;
		font-weight: 500;
	}

	.remove-file {
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background 0.2s;
	}

	.remove-file:hover {
		background: #DC2626;
	}

	.actions {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		background: white;
		border-top: 1px solid #E5E7EB;
		position: sticky;
		bottom: 0;
	}

	.cancel-btn,
	.complete-btn {
		flex: 1;
		padding: 1rem 1.5rem;
		border-radius: 12px;
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		min-height: 48px;
	}

	.cancel-btn {
		background: #F3F4F6;
		color: #374151;
		border: 1px solid #D1D5DB;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #E5E7EB;
	}

	.complete-btn {
		background: #10B981;
		color: white;
	}

	.complete-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.complete-btn:disabled,
	.complete-btn.disabled {
		background: #D1D5DB;
		color: #9CA3AF;
		cursor: not-allowed;
		transform: none;
	}

	.btn-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid transparent;
		border-top: 2px solid currentColor;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.back-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 0.75rem 1.5rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		margin-top: 1rem;
	}

	.back-btn:hover {
		background: #2563EB;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Mobile optimizations */
	@media (max-width: 640px) {
		.task-info-section,
		.form-section {
			margin: 0.75rem;
		}

		.actions {
			flex-direction: column;
		}

		.cancel-btn,
		.complete-btn {
			width: 100%;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.actions {
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
	}
</style>