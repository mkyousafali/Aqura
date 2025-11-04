<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let taskId;
	export let receivingRecordId;
	export let onComplete = () => {};

	let loading = false;
	let loadingTask = true;
	let error = null;
	let success = false;
	let taskDetails = null;

	// Inventory Manager form data
	let inventoryFormData = {
		erp_purchase_invoice_reference: '',
		has_erp_purchase_invoice: false,
		has_pr_excel_file: false,
		has_original_bill: false,
		completion_notes: ''
	};
	let prExcelFile = null;
	let originalBillFile = null;

	// Load task details to determine role type
	onMount(async () => {
		await loadTaskDetails();
		if (receivingRecordId) {
			await loadExistingData();
		}
	});

	async function loadExistingData() {
		try {
			console.log('📋 Loading existing receiving record data...');
			
			// Load receiving record data
			const { data: record, error: recordError } = await supabase
				.from('receiving_records')
				.select('erp_purchase_invoice_reference, pr_excel_file_url, original_bill_url, erp_purchase_invoice_uploaded, pr_excel_file_uploaded, original_bill_uploaded')
				.eq('id', receivingRecordId)
				.single();

			if (recordError || !record) {
				console.error('❌ Failed to load receiving record:', recordError);
				return;
			}

			console.log('✅ Existing data loaded:', record);

			// Pre-populate form with existing data
			if (record.erp_purchase_invoice_reference) {
				inventoryFormData.erp_purchase_invoice_reference = record.erp_purchase_invoice_reference;
				inventoryFormData.has_erp_purchase_invoice = true;
			}

			if (record.pr_excel_file_url) {
				inventoryFormData.has_pr_excel_file = true;
				// Create a fake File object to display the filename
				const fileName = record.pr_excel_file_url.split('/').pop() || 'PR Excel (Already Uploaded)';
				prExcelFile = { name: fileName, alreadyUploaded: true };
				console.log('✅ PR Excel file already uploaded:', record.pr_excel_file_url);
			}

			if (record.original_bill_url) {
				inventoryFormData.has_original_bill = true;
				// Create a fake File object to display the filename
				const fileName = record.original_bill_url.split('/').pop() || 'Original Bill (Already Uploaded)';
				originalBillFile = { name: fileName, alreadyUploaded: true };
				console.log('✅ Original bill already uploaded:', record.original_bill_url);
			}

			// For purchase manager, also check verification status and load details
			if (taskDetails?.role_type === 'purchase_manager') {
				await loadVerificationStatus();
				await loadReceivingRecordDetails();
			}

		} catch (err) {
			console.error('❌ Error loading existing data:', err);
		}
	}

	// New function to load verification status for purchase managers
	let verificationCompleted = false;
	let receivingRecordDetails = null;
	
	async function loadVerificationStatus() {
		try {
			console.log('🔍 Loading verification status for purchase manager...');
			
			const { data: paymentSchedule, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.select('pr_excel_verified')
				.eq('receiving_record_id', receivingRecordId)
				.single();

			if (!scheduleError && paymentSchedule) {
				verificationCompleted = paymentSchedule.pr_excel_verified === true;
				console.log('✅ Verification status loaded:', verificationCompleted);
			} else {
				verificationCompleted = false;
				console.log('⚠️ No payment schedule found or verification not completed');
			}
		} catch (err) {
			console.error('❌ Error loading verification status:', err);
			verificationCompleted = false;
		}
	}

	async function loadReceivingRecordDetails() {
		try {
			console.log('📋 Loading receiving record details...');
			
			// First get the receiving record with vendor_id and branch_id
			const { data: receivingRecord, error: receivingError } = await supabase
				.from('receiving_records')
				.select('vendor_id, branch_id, bill_date, bill_amount, bill_number')
				.eq('id', receivingRecordId)
				.single();

			if (receivingError || !receivingRecord) {
				console.error('❌ Failed to load receiving record:', receivingError);
				return;
			}

			// Get vendor information
			const { data: vendor, error: vendorError } = await supabase
				.from('vendors')
				.select('vendor_name')
				.eq('erp_vendor_id', receivingRecord.vendor_id)
				.eq('branch_id', receivingRecord.branch_id)
				.single();

			// Get branch information
			const { data: branch, error: branchError } = await supabase
				.from('branches')
				.select('name_en')
				.eq('id', receivingRecord.branch_id)
				.single();

			receivingRecordDetails = {
				vendor_name: vendor?.vendor_name || 'Unknown Vendor',
				branch_name: branch?.name_en || 'Unknown Branch',
				bill_date: receivingRecord.bill_date,
				bill_amount: receivingRecord.bill_amount,
				bill_number: receivingRecord.bill_number
			};

			console.log('✅ Receiving record details loaded:', receivingRecordDetails);

			if (vendorError) {
				console.error('⚠️ Failed to load vendor details:', vendorError);
			}
			if (branchError) {
				console.error('⚠️ Failed to load branch details:', branchError);
			}
		} catch (err) {
			console.error('❌ Error loading receiving record details:', err);
		}
	}

	// Refresh status for purchase managers
	async function refreshStatus() {
		console.log('🔄 Refreshing status...');
		error = null; // Clear any existing errors
		await loadExistingData(); // This will reload PR Excel, verification status, and receiving record details
		console.log('✅ Status refreshed');
	}

	async function loadTaskDetails() {
		try {
			loadingTask = true;
			console.log('🔍 Loading task details for taskId:', taskId);
			
			const { data: task, error: taskError } = await supabase
				.from('receiving_tasks')
				.select('*')
				.eq('id', taskId)
				.single();

			console.log('📊 Task query result:', { data: task, error: taskError });

			if (taskError || !task) {
				console.error('❌ Task not found or error:', taskError);
				throw new Error('Task not found');
			}

			taskDetails = task;
			console.log('✅ Task details loaded:', taskDetails);
		} catch (err) {
			console.error('Error loading task details:', err);
			error = err.message;
		} finally {
			loadingTask = false;
		}
	}

	// File upload handlers for Inventory Manager
	async function handlePRExcelUpload(event) {
		const file = event.target.files?.[0];
		if (file) {
			if (!file.name.toLowerCase().includes('.xls') && !file.name.toLowerCase().includes('.xlsx')) {
				error = 'Please select a valid Excel file (.xls or .xlsx)';
				return;
			}
			if (file.size > 10 * 1024 * 1024) { // 10MB limit
				error = 'Excel file must be less than 10MB';
				return;
			}
			
			error = null;
			prExcelFile = file;
			inventoryFormData.has_pr_excel_file = true;
			
			// Immediately upload the file
			const uploadResult = await uploadFile(file, 'pr_excel');
			if (uploadResult) {
				console.log('✅ PR Excel file URL saved:', uploadResult.file_url);
			}
		}
	}

	async function handleOriginalBillUpload(event) {
		const file = event.target.files?.[0];
		if (file) {
			if (file.size > 10 * 1024 * 1024) { // 10MB limit
				error = 'File must be less than 10MB';
				return;
			}
			
			error = null;
			originalBillFile = file;
			inventoryFormData.has_original_bill = true;
			
			// Immediately upload the file
			const uploadResult = await uploadFile(file, 'original_bill');
			if (uploadResult) {
				console.log('✅ Original bill file URL saved:', uploadResult.file_url);
			}
		}
	}

	function removePRExcelFile() {
		prExcelFile = null;
		inventoryFormData.has_pr_excel_file = false;
		const fileInput = /** @type {any} */ (document.getElementById('pr-excel-upload'));
		if (fileInput) fileInput.value = '';
	}

	function removeOriginalBillFile() {
		originalBillFile = null;
		inventoryFormData.has_original_bill = false;
		const fileInput = /** @type {any} */ (document.getElementById('original-bill-upload'));
		if (fileInput) fileInput.value = '';
	}

	// Incremental save functions
	let saveErpTimeout = null;
	async function saveErpReference() {
		if (!receivingRecordId || !inventoryFormData.erp_purchase_invoice_reference?.trim()) {
			return;
		}

		try {
			console.log('💾 Saving ERP reference:', inventoryFormData.erp_purchase_invoice_reference);
			
			const response = await fetch('/api/receiving-records/update-erp', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					receivingRecordId: receivingRecordId,
					erpReference: inventoryFormData.erp_purchase_invoice_reference.trim()
				})
			});

			const result = await response.json();
			
			if (!response.ok || result.error) {
				console.error('❌ Failed to save ERP reference:', result.error);
				error = 'Failed to save ERP reference. Please try again.';
				return;
			}

			console.log('✅ ERP reference saved successfully');
			
		} catch (err) {
			console.error('❌ Error saving ERP reference:', err);
			error = 'Failed to save ERP reference. Please try again.';
		}
	}

	// Debounced ERP reference save
	function onErpReferenceChange() {
		if (saveErpTimeout) {
			clearTimeout(saveErpTimeout);
		}
		saveErpTimeout = setTimeout(saveErpReference, 1000); // Save after 1 second of no typing
	}

	async function uploadFile(file, fileType) {
		if (!receivingRecordId || !file) {
			return null;
		}

		try {
			console.log(`📁 Uploading ${fileType} file:`, file.name);
			
			const formData = new FormData();
			formData.append('file', file);
			formData.append('receiving_record_id', receivingRecordId);
			formData.append('file_type', fileType);

			const response = await fetch('/api/receiving-records/upload-file', {
				method: 'POST',
				body: formData
			});

			const result = await response.json();
			
			if (!response.ok || result.error) {
				console.error(`❌ Failed to upload ${fileType} file:`, result.error);
				error = `Failed to upload ${fileType === 'pr_excel' ? 'PR Excel' : 'Original Bill'} file. Please try again.`;
				return null;
			}

			console.log(`✅ ${fileType} file uploaded successfully:`, result.data.file_url);
			return result.data;
			
		} catch (err) {
			console.error(`❌ Error uploading ${fileType} file:`, err);
			error = `Failed to upload ${fileType === 'pr_excel' ? 'PR Excel' : 'Original Bill'} file. Please try again.`;
			return null;
		}
	}

	// Auto-update ERP checkbox when reference is entered
	$: if (inventoryFormData.erp_purchase_invoice_reference?.trim()) {
		inventoryFormData.has_erp_purchase_invoice = true;
	} else {
		inventoryFormData.has_erp_purchase_invoice = false;
	}

	// Validate inventory form
	$: isInventoryFormValid = inventoryFormData.erp_purchase_invoice_reference.trim() && 
	                         inventoryFormData.has_erp_purchase_invoice && 
	                         inventoryFormData.has_pr_excel_file && 
	                         inventoryFormData.has_original_bill;

	async function completeTask() {
		if (!taskId) {
			error = 'Task ID is required';
			return;
		}

		// For Inventory Manager, validate form
		if (taskDetails?.role_type === 'inventory_manager') {
			if (!isInventoryFormValid) {
				error = 'Please fill in all required fields for Inventory Manager task';
				return;
			}
		}

		loading = true;
		error = null;

		try {
			console.log('🚀 Starting task completion...');
			console.log('📋 Task Details:', taskDetails);
			console.log('👤 Current User:', $currentUser);

			const requestBody = {
				receiving_task_id: taskId,
				user_id: $currentUser?.id
			};

			// Add Inventory Manager specific data
			if (taskDetails?.role_type === 'inventory_manager') {
				console.log('📦 Adding Inventory Manager data...');
				requestBody.erp_reference = inventoryFormData.erp_purchase_invoice_reference;
				requestBody.has_erp_purchase_invoice = inventoryFormData.has_erp_purchase_invoice;
				requestBody.has_pr_excel_file = inventoryFormData.has_pr_excel_file;
				requestBody.has_original_bill = inventoryFormData.has_original_bill;
				requestBody.completion_notes = inventoryFormData.completion_notes;
			}

			console.log('📤 Request Body:', requestBody);

			const response = await fetch('/api/receiving-tasks/complete', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify(requestBody)
			});

			console.log('📥 API Response:', { status: response.status, ok: response.ok });

			const result = await response.json();
			console.log('📊 API Result:', result);

			if (!response.ok || result.error_code) {
				throw new Error(result.error || 'Failed to complete receiving task');
			}

			success = true;
			console.log('✅ Task completed successfully!');
			
			// Wait a moment to show success message
			setTimeout(() => {
				onComplete();
			}, 1500);

		} catch (err) {
			console.error('❌ Error completing receiving task:', err);
			error = err.message || 'Failed to complete task. Please try again.';
		} finally {
			loading = false;
		}
	}
</script>

<div class="completion-dialog">
	{#if loadingTask}
		<div class="loading-state">
			<div class="spinner-large"></div>
			<p>Loading task details...</p>
		</div>
	{:else if success}
		<div class="success-message">
			<div class="success-icon">✅</div>
			<h3>Task Completed Successfully!</h3>
			<p>The receiving task has been marked as completed.</p>
		</div>
	{:else if taskDetails}
		<div class="dialog-content">
			<h2>Complete {taskDetails.role_type === 'inventory_manager' ? 'Inventory Manager' : taskDetails.role_type === 'purchase_manager' ? 'Purchase Manager' : 'Receiving'} Task</h2>
			
			{#if taskDetails.role_type === 'inventory_manager'}
				<!-- Inventory Manager Form -->
				<div class="inventory-manager-form">
					<p class="form-description">
						As an Inventory Manager, you need to provide the following information to complete this task:
					</p>

					<!-- ERP Purchase Invoice Reference -->
					<div class="form-group">
						<label class="form-label required">ERP Purchase Invoice Reference</label>
						<input
							type="text"
							bind:value={inventoryFormData.erp_purchase_invoice_reference}
							on:input={onErpReferenceChange}
							placeholder="Enter ERP purchase invoice reference number"
							disabled={loading}
							class="form-input"
						/>
						<div class="checkbox-group">
							<input
								type="checkbox"
								bind:checked={inventoryFormData.has_erp_purchase_invoice}
								disabled
								class="form-checkbox"
							/>
							<label class="checkbox-label">ERP Reference Entered</label>
						</div>
					</div>

					<!-- PR Excel File Upload -->
					<div class="form-group">
						<label class="form-label required">PR Excel File</label>
						{#if !prExcelFile}
							<div class="file-upload-area">
								<input
									id="pr-excel-upload"
									type="file"
									accept=".xls,.xlsx"
									on:change={handlePRExcelUpload}
									disabled={loading}
									class="file-input"
								/>
								<label for="pr-excel-upload" class="file-upload-btn">
									<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
									</svg>
									Choose Excel File
								</label>
							</div>
						{:else}
							<div class="file-preview">
								<div class="file-info">
									<svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
									</svg>
									<span class="file-name">{prExcelFile.name}</span>
								</div>
								{#if !prExcelFile.alreadyUploaded}
									<button on:click={removePRExcelFile} disabled={loading} class="remove-file-btn">
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
										</svg>
									</button>
								{/if}
							</div>
						{/if}
						<div class="checkbox-group">
							<input
								type="checkbox"
								bind:checked={inventoryFormData.has_pr_excel_file}
								disabled
								class="form-checkbox"
							/>
							<label class="checkbox-label">PR Excel File Uploaded</label>
						</div>
					</div>

					<!-- Original Bill Upload -->
					<div class="form-group">
						<label class="form-label required">Original Bill</label>
						{#if !originalBillFile}
							<div class="file-upload-area">
								<input
									id="original-bill-upload"
									type="file"
									accept=".pdf,.jpg,.jpeg,.png"
									on:change={handleOriginalBillUpload}
									disabled={loading}
									class="file-input"
								/>
								<label for="original-bill-upload" class="file-upload-btn">
									<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
									</svg>
									Choose Bill File
								</label>
							</div>
						{:else}
							<div class="file-preview">
								<div class="file-info">
									<svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
									</svg>
									<span class="file-name">{originalBillFile.name}</span>
								</div>
								{#if !originalBillFile.alreadyUploaded}
									<button on:click={removeOriginalBillFile} disabled={loading} class="remove-file-btn">
										<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
										</svg>
									</button>
								{/if}
							</div>
						{/if}
						<div class="checkbox-group">
							<input
								type="checkbox"
								bind:checked={inventoryFormData.has_original_bill}
								disabled
								class="form-checkbox"
							/>
							<label class="checkbox-label">Original Bill Uploaded</label>
						</div>
					</div>

					<!-- Completion Notes -->
					<div class="form-group">
						<label class="form-label">Additional Notes (Optional)</label>
						<textarea
							bind:value={inventoryFormData.completion_notes}
							placeholder="Add any additional notes about the inventory task completion..."
							disabled={loading}
							rows="3"
							class="form-textarea"
						></textarea>
					</div>
				</div>
			{:else if taskDetails.role_type === 'purchase_manager'}
				<!-- Purchase Manager Task Completion -->
				<div class="purchase-manager-form">
					<!-- Receiving Record Details -->
					{#if receivingRecordDetails}
						<div class="receiving-details">
							<h4>Receiving Record Details</h4>
							<div class="details-grid">
								<div class="detail-item">
									<span class="detail-label">Branch:</span>
									<span class="detail-value">{receivingRecordDetails.branch_name}</span>
								</div>
								<div class="detail-item">
									<span class="detail-label">Vendor:</span>
									<span class="detail-value">{receivingRecordDetails.vendor_name}</span>
								</div>
								<div class="detail-item">
									<span class="detail-label">Receiving Date:</span>
									<span class="detail-value">{new Date(receivingRecordDetails.bill_date).toLocaleDateString()}</span>
								</div>
								<div class="detail-item">
									<span class="detail-label">Bill Amount:</span>
									<span class="detail-value">{receivingRecordDetails.bill_amount}</span>
								</div>
								<div class="detail-item">
									<span class="detail-label">Bill Number:</span>
									<span class="detail-value">{receivingRecordDetails.bill_number}</span>
								</div>
							</div>
						</div>
					{/if}

					<div class="status-section">
						<h4>Task Requirements Status</h4>
						
						<!-- PR Excel Upload Status -->
						<div class="status-item" class:status-success={inventoryFormData.has_pr_excel_file} class:status-error={!inventoryFormData.has_pr_excel_file}>
							<div class="status-icon">
								{#if inventoryFormData.has_pr_excel_file}
									✅
								{:else}
									❌
								{/if}
							</div>
							<div class="status-content">
								<h5>PR Excel Upload Status</h5>
								{#if inventoryFormData.has_pr_excel_file}
									<p class="status-success">PR Excel file is uploaded</p>
								{:else}
									<p class="status-error">PR Excel not uploaded. The inventory manager must upload the PR Excel. After that, you need to verify it.</p>
								{/if}
							</div>
						</div>

						<!-- Verification Status -->
						<div class="status-item" class:status-success={verificationCompleted} class:status-error={!verificationCompleted}>
							<div class="status-icon">
								{#if verificationCompleted}
									✅
								{:else}
									❌
								{/if}
							</div>
							<div class="status-content">
								<h5>Verification Status</h5>
								{#if verificationCompleted}
									<p class="status-success">PR Excel verified</p>
								{:else}
									<p class="status-error">PR Excel not verified.</p>
								{/if}
							</div>
						</div>
					</div>

					{#if inventoryFormData.has_pr_excel_file && verificationCompleted}
						<div class="ready-box">
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							<span><strong>Ready to complete!</strong> All requirements are met.</span>
						</div>
					{/if}
				</div>
			{:else}
				<!-- Regular Task Completion -->
				<p class="confirmation-text">
					Are you sure you want to mark this task as completed? This action confirms that you have finished all required activities for this receiving record.
				</p>
			{/if}

			{#if error}
				<div class="error-message">
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
					</svg>
					{error}
				</div>
			{/if}

			<div class="actions">
				<button 
					class="btn btn-cancel" 
					on:click={onComplete}
					disabled={loading}
				>
					Cancel
				</button>
				
				{#if taskDetails.role_type === 'purchase_manager'}
					<!-- Purchase manager button - always visible but disabled when requirements not met -->
					<button 
						class="btn btn-complete" 
						on:click={completeTask}
						disabled={loading || !inventoryFormData.has_pr_excel_file || !verificationCompleted}
					>
						{#if loading}
							<span class="spinner"></span>
							Completing...
						{:else}
							✅ Complete Task
						{/if}
					</button>
				{:else}
					<!-- For all other roles (inventory manager, etc.) -->
					<button 
						class="btn btn-complete" 
						on:click={completeTask}
						disabled={loading || (taskDetails.role_type === 'inventory_manager' && !isInventoryFormValid)}
					>
						{#if loading}
							<span class="spinner"></span>
							Completing...
						{:else}
							✅ Complete Task
						{/if}
					</button>
				{/if}
			</div>
		</div>
	{:else}
		<div class="error-state">
			<p>❌ Failed to load task details</p>
			{#if error}
				<p class="error-details">{error}</p>
			{/if}
		</div>
	{/if}
</div>

<style>
	.completion-dialog {
		padding: 24px;
		min-height: 200px;
		max-height: 80vh;
		overflow-y: auto;
	}

	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 40px;
		text-align: center;
		gap: 16px;
	}

	.spinner-large {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-top: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.error-details {
		color: #dc2626;
		font-size: 14px;
		margin: 0;
	}

	.dialog-content {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	h2 {
		margin: 0;
		font-size: 24px;
		font-weight: 600;
		color: #1f2937;
	}

	.confirmation-text,
	.form-description {
		color: #6b7280;
		line-height: 1.6;
		margin: 0;
	}

	.form-description {
		background: #f0f9ff;
		padding: 12px;
		border-radius: 6px;
		border: 1px solid #0ea5e9;
	}

	.inventory-manager-form {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.form-label {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.form-label.required::before {
		content: '* ';
		color: #dc2626;
	}

	.form-input,
	.form-textarea {
		padding: 10px 12px;
		border: 2px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s;
	}

	.form-input:focus,
	.form-textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-textarea {
		resize: vertical;
		min-height: 80px;
		font-family: inherit;
	}

	.checkbox-group {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-top: 4px;
	}

	.form-checkbox {
		width: 16px;
		height: 16px;
		accent-color: #10b981;
	}

	.checkbox-label {
		font-size: 12px;
		color: #6b7280;
		margin: 0;
	}

	.file-upload-area {
		border: 2px dashed #d1d5db;
		border-radius: 6px;
		padding: 20px;
		text-align: center;
		transition: border-color 0.2s;
	}

	.file-upload-area:hover {
		border-color: #3b82f6;
		background: #f8fafc;
	}

	.file-input {
		display: none;
	}

	.file-upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #3b82f6;
		color: white;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.file-upload-btn:hover {
		background: #2563eb;
	}

	.file-preview {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px;
		background: #f0fdf4;
		border: 2px solid #10b981;
		border-radius: 6px;
	}

	.file-info {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.file-name {
		font-size: 14px;
		font-weight: 500;
		color: #059669;
	}

	.remove-file-btn {
		background: #dc2626;
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

	.remove-file-btn:hover {
		background: #991b1b;
	}

	.error-message {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px;
		background: #fee2e2;
		border: 1px solid #fca5a5;
		border-radius: 6px;
		color: #991b1b;
		font-size: 14px;
	}

	.error-message svg {
		width: 20px;
		height: 20px;
		flex-shrink: 0;
	}

	.success-message {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: 40px 20px;
		gap: 16px;
	}

	.success-icon {
		font-size: 64px;
		animation: scaleIn 0.3s ease-out;
	}

	@keyframes scaleIn {
		from {
			transform: scale(0);
		}
		to {
			transform: scale(1);
		}
	}

	.success-message h3 {
		margin: 0;
		font-size: 20px;
		font-weight: 600;
		color: #065f46;
	}

	.success-message p {
		margin: 0;
		color: #6b7280;
	}

	.actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		margin-top: 8px;
	}

	.btn {
		padding: 10px 20px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-cancel {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.btn-complete {
		background: #10b981;
		color: white;
	}

	.btn-complete:hover:not(:disabled) {
		background: #059669;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Purchase Manager Form Styles */
	.purchase-manager-form {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.receiving-details {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		padding: 16px;
	}

	.receiving-details h4 {
		margin: 0 0 12px 0;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
	}

	.details-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 12px;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.detail-label {
		font-size: 12px;
		font-weight: 500;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-value {
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.status-section {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.status-section h4 {
		margin: 0;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
	}

	.status-item {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 16px;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		transition: all 0.2s ease;
	}

	.status-item.status-success {
		background: #f0fdf4;
		border-color: #bbf7d0;
	}

	.status-item.status-error {
		background: #fef2f2;
		border-color: #fecaca;
	}

	.status-icon {
		font-size: 18px;
		flex-shrink: 0;
		margin-top: 2px;
	}

	.status-content {
		flex: 1;
	}

	.status-content h5 {
		margin: 0 0 4px 0;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
	}

	.status-content p {
		margin: 0;
		font-size: 13px;
		line-height: 1.4;
	}

	.status-content .status-success {
		color: #059669;
		font-weight: 500;
	}

	.status-content .status-error {
		color: #dc2626;
		font-weight: 500;
	}

	.ready-box {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 16px;
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		border-radius: 8px;
		color: #059669;
	}

	.ready-box svg {
		width: 20px;
		height: 20px;
		flex-shrink: 0;
	}

	.info-box {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 12px;
		background: #eff6ff;
		border: 1px solid #dbeafe;
		border-radius: 6px;
		font-size: 13px;
		color: #1e40af;
	}

	.info-box svg {
		flex-shrink: 0;
		margin-top: 1px;
	}

	.info-box strong {
		font-weight: 600;
	}
</style>
