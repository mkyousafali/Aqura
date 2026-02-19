<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';
	import { locale, getTranslation } from '$lib/i18n';

	// Get task ID from URL params
	let taskId = '';
	let isLoading = true;
	let isSubmitting = false;
	let errorMessage = '';
	let successMessage = '';

	// Task data
	let taskDetails: any = null;
	let receivingRecordId = '';

	// Current user
	$: currentUserData = $currentUser;

	// Inventory Manager form
	let inventoryFormData = {
		erp_purchase_invoice_reference: '',
		has_erp_purchase_invoice: false,
		has_pr_excel_file: false,
		has_original_bill: false,
		completion_notes: ''
	};
	let prExcelFile: any = null;
	let originalBillFile: any = null;

	// Photo upload (for shelf_stocker and roles requiring photos)
	let photoFile: File | null = null;
	let photoPreview: string | null = null;
	let requirePhotoUpload = false;

	// Task dependencies
	let canComplete = true;
	let blockingMessages: string[] = [];
	let dependencyPhotos: any = null;

	// Purchase manager verification
	let verificationCompleted = false;
	let receivingRecordDetails: any = null;

	// Completion notes for simple roles
	let completionNotes = '';

	// Photo viewer
	let showPhotoViewer = false;
	let viewerPhotoUrl = '';

	// Determine if task is assigned to current user
	$: isAssignedToMe = taskDetails?.assigned_user_id === currentUserData?.id;

	// Auto-update checkbox for ERP reference
	$: if (inventoryFormData.erp_purchase_invoice_reference?.trim()) {
		inventoryFormData.has_erp_purchase_invoice = true;
	} else {
		inventoryFormData.has_erp_purchase_invoice = false;
	}

	// Validate inventory form
	$: isInventoryFormValid = taskDetails?.role_type !== 'inventory_manager' || (
		inventoryFormData.erp_purchase_invoice_reference.trim() &&
		inventoryFormData.has_erp_purchase_invoice &&
		inventoryFormData.has_pr_excel_file &&
		inventoryFormData.has_original_bill
	);

	// Can submit?
	$: canSubmit = (() => {
		if (!taskDetails || !isAssignedToMe) return false;
		if (!canComplete) return false;
		if (requirePhotoUpload && !photoFile) return false;

		if (taskDetails.role_type === 'inventory_manager') {
			return isInventoryFormValid;
		}
		if (taskDetails.role_type === 'purchase_manager') {
			return verificationCompleted;
		}
		return true;
	})();

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

			const { data: task, error: taskError } = await supabase
				.from('receiving_tasks')
				.select('*')
				.eq('id', taskId)
				.single();

			if (taskError || !task) {
				console.error('Task not found:', taskError);
				errorMessage = 'Task not found';
				return;
			}

			taskDetails = task;
			receivingRecordId = task.receiving_record_id;
			console.log('✅ Receiving task loaded:', task.role_type, task.id);

			// Load existing data for the receiving record
			if (receivingRecordId) {
				await loadExistingData();
			}

			// Check photo requirements
			await checkPhotoRequirement();

			// Check dependencies
			await checkTaskDependencies();

		} catch (error) {
			console.error('Error loading task:', error);
			errorMessage = 'Failed to load task details';
		} finally {
			isLoading = false;
		}
	}

	async function loadExistingData() {
		try {
			const { data: record, error: recordError } = await supabase
				.from('receiving_records')
				.select('erp_purchase_invoice_reference, pr_excel_file_url, original_bill_url, erp_purchase_invoice_uploaded, pr_excel_file_uploaded, original_bill_uploaded')
				.eq('id', receivingRecordId)
				.single();

			if (recordError || !record) return;

			// Pre-populate form with existing data
			if (record.erp_purchase_invoice_reference) {
				inventoryFormData.erp_purchase_invoice_reference = record.erp_purchase_invoice_reference;
				inventoryFormData.has_erp_purchase_invoice = true;
			}
			if (record.pr_excel_file_url) {
				inventoryFormData.has_pr_excel_file = true;
				const fileName = record.pr_excel_file_url.split('/').pop() || 'PR Excel (Already Uploaded)';
				prExcelFile = { name: fileName, alreadyUploaded: true };
			}
			if (record.original_bill_url) {
				inventoryFormData.has_original_bill = true;
				const fileName = record.original_bill_url.split('/').pop() || 'Original Bill (Already Uploaded)';
				originalBillFile = { name: fileName, alreadyUploaded: true };
			}

			// Purchase manager: load verification status
			if (taskDetails?.role_type === 'purchase_manager') {
				await loadVerificationStatus();
				await loadReceivingRecordDetails();
			}
		} catch (err) {
			console.error('Error loading existing data:', err);
		}
	}

	async function loadVerificationStatus() {
		try {
			const { data: scheduleData, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.select('pr_excel_verified')
				.eq('receiving_record_id', receivingRecordId)
				.not('bill_number', 'like', 'SPLIT_%')
				.maybeSingle();

			if (!scheduleError && scheduleData) {
				verificationCompleted = scheduleData.pr_excel_verified === true;
			} else {
				verificationCompleted = false;
			}
		} catch (err) {
			console.error('Error loading verification status:', err);
			verificationCompleted = false;
		}
	}

	async function loadReceivingRecordDetails() {
		try {
			const { data: receivingRecord, error: receivingError } = await supabase
				.from('receiving_records')
				.select('vendor_id, branch_id, bill_date, bill_amount, bill_number')
				.eq('id', receivingRecordId)
				.single();

			if (receivingError || !receivingRecord) return;

			const { data: vendor } = await supabase
				.from('vendors')
				.select('vendor_name')
				.eq('erp_vendor_id', receivingRecord.vendor_id)
				.eq('branch_id', receivingRecord.branch_id)
				.single();

			const { data: branch } = await supabase
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
		} catch (err) {
			console.error('Error loading receiving record:', err);
		}
	}

	async function checkPhotoRequirement() {
		if (!taskDetails?.template_id) return;
		try {
			const { data: template, error } = await supabase
				.from('receiving_task_templates')
				.select('require_photo_upload')
				.eq('id', taskDetails.template_id)
				.single();

			if (!error && template) {
				requirePhotoUpload = template.require_photo_upload || false;
			}
		} catch (error) {
			console.error('Error checking photo requirement:', error);
		}
	}

	async function checkTaskDependencies() {
		if (!taskDetails?.receiving_record_id || !taskDetails?.role_type) return;

		if (taskDetails.role_type === 'accountant') {
			await checkAccountantDependency();
			return;
		}

		try {
			const { data: depStatus, error } = await supabase.rpc('check_receiving_task_dependencies', {
				receiving_record_id_param: taskDetails.receiving_record_id,
				role_type_param: taskDetails.role_type
			});

			if (!error && depStatus) {
				canComplete = depStatus.can_complete || false;
				blockingMessages = depStatus.blocking_roles || [];

				if (depStatus.completed_dependencies?.length > 0) {
					await loadDependencyPhotos(depStatus.completed_dependencies);
				}
			}
		} catch (error) {
			console.error('Error checking dependencies:', error);
		}
	}

	async function checkAccountantDependency() {
		try {
			const { data: receivingRecord, error: recordError } = await supabase
				.from('receiving_records')
				.select('original_bill_uploaded, original_bill_url, pr_excel_file_uploaded, pr_excel_file_url')
				.eq('id', taskDetails.receiving_record_id)
				.single();

			if (recordError) {
				canComplete = false;
				errorMessage = 'Error checking dependencies';
				return;
			}

			const { data: scheduleData, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.select('pr_excel_verified')
				.eq('receiving_record_id', taskDetails.receiving_record_id)
				.maybeSingle();

			const missing: string[] = [];

			const hasOriginalBill = receivingRecord.original_bill_uploaded || (receivingRecord.original_bill_url?.length > 0);
			if (!hasOriginalBill) missing.push('Original Bill must be uploaded');

			const hasExcelFile = receivingRecord.pr_excel_file_uploaded || (receivingRecord.pr_excel_file_url?.length > 0);
			if (!hasExcelFile) missing.push('PR Excel File must be uploaded');

			if (!scheduleError && (!scheduleData || !scheduleData.pr_excel_verified)) {
				missing.push('PR Excel must be verified by Purchase Manager');
			}

			if (missing.length > 0) {
				canComplete = false;
				blockingMessages = missing;
			} else {
				canComplete = true;
				blockingMessages = [];
			}
		} catch (error) {
			console.error('Error checking accountant dependency:', error);
			canComplete = false;
		}
	}

	async function loadDependencyPhotos(completedDependencies: string[]) {
		try {
			const { data: photos, error } = await supabase.rpc('get_dependency_completion_photos', {
				receiving_record_id_param: taskDetails.receiving_record_id,
				dependency_role_types: completedDependencies
			});

			if (!error && photos) {
				dependencyPhotos = photos;
			}
		} catch (error) {
			console.error('Error loading dependency photos:', error);
		}
	}

	// ── File Upload Handlers ──

	async function handlePhotoUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (!file) return;

		if (!file.type.startsWith('image/')) {
			errorMessage = 'Please select a valid image file';
			return;
		}
		if (file.size > 5 * 1024 * 1024) {
			errorMessage = 'Image must be less than 5MB';
			return;
		}

		photoFile = file;
		const reader = new FileReader();
		reader.onload = (e) => { photoPreview = e.target?.result as string; };
		reader.readAsDataURL(file);
		errorMessage = '';
	}

	function removePhoto() {
		photoFile = null;
		photoPreview = null;
		const input = document.getElementById('photo-upload') as HTMLInputElement;
		if (input) input.value = '';
	}

	async function uploadPhoto(): Promise<string | null> {
		if (!photoFile) return null;
		try {
			const fileExt = photoFile.name.split('.').pop();
			const fileName = `receiving-task-${taskId}-${Date.now()}.${fileExt}`;

			const { error } = await supabase.storage
				.from('completion-photos')
				.upload(fileName, photoFile, { cacheControl: '3600', upsert: false });

			if (error) {
				console.error('Photo upload error:', error);
				return null;
			}

			const { data: urlData } = supabase.storage
				.from('completion-photos')
				.getPublicUrl(fileName);

			return urlData.publicUrl;
		} catch (error) {
			console.error('Error uploading photo:', error);
			return null;
		}
	}

	async function handlePRExcelUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (!file) return;

		if (!file.name.toLowerCase().match(/\.xlsx?$/)) {
			errorMessage = 'Please select a valid Excel file (.xls or .xlsx)';
			return;
		}
		if (file.size > 10 * 1024 * 1024) {
			errorMessage = 'Excel file must be less than 10MB';
			return;
		}

		errorMessage = '';
		prExcelFile = file;
		inventoryFormData.has_pr_excel_file = true;

		const result = await uploadFileToRecord(file, 'pr_excel');
		if (result) {
			console.log('✅ PR Excel uploaded:', result.file_url);
		}
	}

	async function handleOriginalBillUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (!file) return;

		if (file.size > 10 * 1024 * 1024) {
			errorMessage = 'File must be less than 10MB';
			return;
		}

		errorMessage = '';
		originalBillFile = file;
		inventoryFormData.has_original_bill = true;

		const result = await uploadFileToRecord(file, 'original_bill');
		if (result) {
			console.log('✅ Original bill uploaded:', result.file_url);
		}
	}

	async function uploadFileToRecord(file: File, fileType: string) {
		if (!receivingRecordId) return null;
		try {
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
				errorMessage = `Failed to upload ${fileType === 'pr_excel' ? 'PR Excel' : 'Original Bill'} file`;
				return null;
			}
			return result.data;
		} catch (err) {
			console.error(`Error uploading ${fileType}:`, err);
			errorMessage = `Failed to upload file`;
			return null;
		}
	}

	function removePRExcelFile() {
		prExcelFile = null;
		inventoryFormData.has_pr_excel_file = false;
		const input = document.getElementById('pr-excel-upload') as HTMLInputElement;
		if (input) input.value = '';
	}

	function removeOriginalBillFile() {
		originalBillFile = null;
		inventoryFormData.has_original_bill = false;
		const input = document.getElementById('original-bill-upload') as HTMLInputElement;
		if (input) input.value = '';
	}

	// ── ERP Reference Auto-Save ──
	let saveErpTimeout: ReturnType<typeof setTimeout> | null = null;

	async function saveErpReference() {
		if (!receivingRecordId || !inventoryFormData.erp_purchase_invoice_reference?.trim()) return;
		try {
			const response = await fetch('/api/receiving-records/update-erp', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					receivingRecordId,
					erpReference: inventoryFormData.erp_purchase_invoice_reference.trim()
				})
			});
			const result = await response.json();
			if (!response.ok || result.error) {
				console.error('Failed to save ERP reference:', result.error);
			}
		} catch (err) {
			console.error('Error saving ERP reference:', err);
		}
	}

	function onErpReferenceChange() {
		if (saveErpTimeout) clearTimeout(saveErpTimeout);
		saveErpTimeout = setTimeout(saveErpReference, 1000);
	}

	// ── Refresh for Purchase Manager ──
	async function refreshStatus() {
		errorMessage = '';
		await loadExistingData();
	}

	// ── Submit Completion ──
	async function submitCompletion() {
		if (!currentUserData || !canSubmit) return;

		isSubmitting = true;
		errorMessage = '';
		successMessage = '';

		try {
			// Upload photo if required
			let photoUrl: string | null = null;
			if (requirePhotoUpload && photoFile) {
				photoUrl = await uploadPhoto();
				if (!photoUrl) {
					errorMessage = 'Failed to upload photo. Please try again.';
					isSubmitting = false;
					return;
				}
			}

			const requestBody: any = {
				receiving_task_id: taskId,
				user_id: currentUserData.id,
				completion_photo_url: photoUrl,
				completion_notes: taskDetails.role_type === 'inventory_manager'
					? inventoryFormData.completion_notes
					: completionNotes
			};

			// Inventory Manager extras
			if (taskDetails.role_type === 'inventory_manager') {
				requestBody.erp_reference = inventoryFormData.erp_purchase_invoice_reference;
				requestBody.has_erp_purchase_invoice = inventoryFormData.has_erp_purchase_invoice;
				requestBody.has_pr_excel_file = inventoryFormData.has_pr_excel_file;
				requestBody.has_original_bill = inventoryFormData.has_original_bill;
			}

			console.log('📤 Completing receiving task:', requestBody);

			const response = await fetch('/api/receiving-tasks/complete', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(requestBody)
			});

			const result = await response.json();

			if (!response.ok || result.error_code) {
				throw new Error(result.error || 'Failed to complete receiving task');
			}

			successMessage = 'Task completed successfully!';
			notifications.add({ type: 'success', message: 'Receiving task completed!' });

			setTimeout(() => {
				goto('/mobile-interface/tasks');
			}, 2000);

		} catch (error: any) {
			console.error('Error completing task:', error);
			errorMessage = error.message || 'Failed to complete task';
			notifications.add({ type: 'error', message: errorMessage });
		} finally {
			isSubmitting = false;
		}
	}

	function getRoleLabel(role: string): string {
		const labels: Record<string, string> = {
			inventory_manager: 'Inventory Manager',
			purchase_manager: 'Purchase Manager',
			shelf_stocker: 'Shelf Stocker',
			branch_manager: 'Branch Manager',
			night_supervisor: 'Night Supervisor',
			accountant: 'Accountant',
			warehouse_handler: 'Warehouse Handler'
		};
		return labels[role] || role;
	}

	function formatDate(dateStr: string): string {
		if (!dateStr) return 'N/A';
		try {
			return new Date(dateStr).toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', {
				day: '2-digit', month: 'short', year: 'numeric'
			});
		} catch { return dateStr; }
	}
</script>

<svelte:head>
	<title>Complete Receiving Task</title>
</svelte:head>

<div class="receiving-completion">
	<!-- Header -->
	<div class="completion-header">
		<button class="back-btn" on:click={() => goto('/mobile-interface/tasks')}>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M19 12H5M12 19l-7-7 7-7"/>
			</svg>
		</button>
		<h1>Complete Task</h1>
	</div>

	{#if isLoading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading task details...</p>
		</div>
	{:else if !taskDetails}
		<div class="error-state">
			<div class="error-icon">⚠️</div>
			<h2>Task Not Found</h2>
			<p>This receiving task doesn't exist or you don't have access.</p>
			<button class="primary-btn" on:click={() => goto('/mobile-interface/tasks')}>Back to Tasks</button>
		</div>
	{:else if !isAssignedToMe}
		<div class="error-state">
			<div class="error-icon">🔒</div>
			<h2>Access Denied</h2>
			<p>This task is not assigned to you.</p>
			<button class="primary-btn" on:click={() => goto('/mobile-interface/tasks')}>Back to Tasks</button>
		</div>
	{:else if taskDetails.task_status === 'completed'}
		<div class="success-state">
			<div class="success-icon">✅</div>
			<h2>Already Completed</h2>
			<p>This receiving task has already been completed.</p>
			<button class="primary-btn" on:click={() => goto('/mobile-interface/tasks')}>Back to Tasks</button>
		</div>
	{:else}
		<!-- Task Info Card -->
		<div class="task-card">
			<div class="task-card-header">
				<span class="role-badge">{getRoleLabel(taskDetails.role_type)}</span>
				<span class="priority-badge priority-{taskDetails.priority?.toLowerCase() || 'medium'}">
					{taskDetails.priority || 'Medium'}
				</span>
			</div>
			<h2 class="task-title">{taskDetails.title}</h2>
			{#if taskDetails.description}
				<p class="task-desc">{taskDetails.description}</p>
			{/if}
			{#if taskDetails.due_date}
				<div class="task-meta">
					<span>📅 Due: {formatDate(taskDetails.due_date)}</span>
				</div>
			{/if}
		</div>

		<!-- Messages -->
		{#if errorMessage}
			<div class="message error-msg">
				<span>❌</span> {errorMessage}
			</div>
		{/if}
		{#if successMessage}
			<div class="message success-msg">
				<span>✅</span> {successMessage}
			</div>
		{/if}

		<!-- Dependency Warnings -->
		{#if !canComplete && blockingMessages.length > 0}
			<div class="dependency-warning">
				<h3>⏳ Cannot Complete Yet</h3>
				<ul>
					{#each blockingMessages as msg}
						<li>{msg}</li>
					{/each}
				</ul>
			</div>
		{/if}

		<!-- Dependency Photos (if available) -->
		{#if dependencyPhotos}
			<div class="dependency-photos">
				<h3>📸 Dependency Photos</h3>
				<div class="photo-grid">
					{#each Object.entries(dependencyPhotos) as [role, url]}
						{#if url}
							<button class="dep-photo" on:click={() => { viewerPhotoUrl = String(url); showPhotoViewer = true; }}>
								<img src={String(url)} alt="{role} photo" />
								<span>{getRoleLabel(String(role))}</span>
							</button>
						{/if}
					{/each}
				</div>
			</div>
		{/if}

		<!-- ROLE-SPECIFIC FORMS -->

		{#if taskDetails.role_type === 'inventory_manager'}
			<!-- ── Inventory Manager Form ── -->
			<div class="form-section">
				<h3>📦 Inventory Manager Requirements</h3>

				<!-- ERP Reference -->
				<div class="form-group">
					<label class="form-label">ERP Purchase Invoice Reference <span class="required">*</span></label>
					<input
						type="text"
						bind:value={inventoryFormData.erp_purchase_invoice_reference}
						on:input={onErpReferenceChange}
						placeholder="Enter ERP reference number"
						disabled={isSubmitting}
						class="form-input"
					/>
					<div class="check-row">
						<input type="checkbox" checked={inventoryFormData.has_erp_purchase_invoice} disabled class="check-icon" />
						<span>ERP Reference Entered</span>
					</div>
				</div>

				<!-- PR Excel Upload -->
				<div class="form-group">
					<label class="form-label">PR Excel File <span class="required">*</span></label>
					{#if !prExcelFile}
						<div class="upload-area">
							<input id="pr-excel-upload" type="file" accept=".xls,.xlsx" on:change={handlePRExcelUpload} disabled={isSubmitting} class="file-input" />
							<label for="pr-excel-upload" class="upload-btn">
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
								</svg>
								Choose Excel File
							</label>
						</div>
					{:else}
						<div class="file-preview">
							<span class="file-name">📄 {prExcelFile.name}</span>
							{#if !prExcelFile.alreadyUploaded}
								<button class="remove-btn" on:click={removePRExcelFile} disabled={isSubmitting}>✕</button>
							{/if}
						</div>
					{/if}
				</div>

				<!-- Original Bill Upload -->
				<div class="form-group">
					<label class="form-label">Original Bill <span class="required">*</span></label>
					{#if !originalBillFile}
						<div class="upload-area">
							<input id="original-bill-upload" type="file" accept="image/*,.pdf" on:change={handleOriginalBillUpload} disabled={isSubmitting} class="file-input" />
							<label for="original-bill-upload" class="upload-btn">
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
								</svg>
								Choose File
							</label>
						</div>
					{:else}
						<div class="file-preview">
							<span class="file-name">📄 {originalBillFile.name}</span>
							{#if !originalBillFile.alreadyUploaded}
								<button class="remove-btn" on:click={removeOriginalBillFile} disabled={isSubmitting}>✕</button>
							{/if}
						</div>
					{/if}
				</div>

				<!-- Notes -->
				<div class="form-group">
					<label class="form-label">Notes (Optional)</label>
					<textarea
						bind:value={inventoryFormData.completion_notes}
						placeholder="Add any notes..."
						disabled={isSubmitting}
						class="form-textarea"
						rows="3"
					></textarea>
				</div>
			</div>

		{:else if taskDetails.role_type === 'purchase_manager'}
			<!-- ── Purchase Manager Form ── -->
			<div class="form-section">
				<h3>💰 Purchase Manager</h3>

				{#if receivingRecordDetails}
					<div class="info-card">
						<div class="info-row"><span>Vendor:</span><span>{receivingRecordDetails.vendor_name}</span></div>
						<div class="info-row"><span>Branch:</span><span>{receivingRecordDetails.branch_name}</span></div>
						{#if receivingRecordDetails.bill_number}
							<div class="info-row"><span>Bill #:</span><span>{receivingRecordDetails.bill_number}</span></div>
						{/if}
						{#if receivingRecordDetails.bill_amount}
							<div class="info-row"><span>Amount:</span><span>{receivingRecordDetails.bill_amount}</span></div>
						{/if}
					</div>
				{/if}

				<div class="status-checks">
					<div class="status-item {inventoryFormData.has_pr_excel_file ? 'done' : 'pending'}">
						<span class="status-icon">{inventoryFormData.has_pr_excel_file ? '✅' : '⏳'}</span>
						<span>PR Excel File Uploaded</span>
					</div>
					<div class="status-item {verificationCompleted ? 'done' : 'pending'}">
						<span class="status-icon">{verificationCompleted ? '✅' : '⏳'}</span>
						<span>PR Excel Verified</span>
					</div>
				</div>

				{#if !verificationCompleted}
					<div class="hint-box">
						<p>PR Excel must be verified before you can complete this task.</p>
						<button class="refresh-btn" on:click={refreshStatus}>🔄 Refresh Status</button>
					</div>
				{/if}

				<div class="form-group">
					<label class="form-label">Notes (Optional)</label>
					<textarea bind:value={completionNotes} placeholder="Add any notes..." disabled={isSubmitting} class="form-textarea" rows="3"></textarea>
				</div>
			</div>

		{:else if taskDetails.role_type === 'accountant'}
			<!-- ── Accountant Form ── -->
			<div class="form-section">
				<h3>🧾 Accountant</h3>

				<div class="status-checks">
					<div class="status-item {blockingMessages.every(m => !m.includes('Original Bill')) ? 'done' : 'pending'}">
						<span class="status-icon">{blockingMessages.every(m => !m.includes('Original Bill')) ? '✅' : '⏳'}</span>
						<span>Original Bill Uploaded</span>
					</div>
					<div class="status-item {blockingMessages.every(m => !m.includes('PR Excel File')) ? 'done' : 'pending'}">
						<span class="status-icon">{blockingMessages.every(m => !m.includes('PR Excel File')) ? '✅' : '⏳'}</span>
						<span>PR Excel File Uploaded</span>
					</div>
					<div class="status-item {blockingMessages.every(m => !m.includes('verified')) ? 'done' : 'pending'}">
						<span class="status-icon">{blockingMessages.every(m => !m.includes('verified')) ? '✅' : '⏳'}</span>
						<span>PR Excel Verified</span>
					</div>
				</div>

				{#if !canComplete}
					<div class="hint-box">
						<p>Waiting for prerequisite steps to be completed.</p>
						<button class="refresh-btn" on:click={async () => { await checkAccountantDependency(); }}>🔄 Refresh Status</button>
					</div>
				{/if}

				<div class="form-group">
					<label class="form-label">Notes (Optional)</label>
					<textarea bind:value={completionNotes} placeholder="Add any notes..." disabled={isSubmitting} class="form-textarea" rows="3"></textarea>
				</div>
			</div>

		{:else}
			<!-- ── Generic Role (shelf_stocker, branch_manager, night_supervisor, warehouse_handler) ── -->
			<div class="form-section">
				<h3>✅ Complete Task</h3>

				{#if requirePhotoUpload}
					<div class="form-group">
						<label class="form-label">Completion Photo <span class="required">*</span></label>
						{#if !photoFile}
							<div class="upload-area photo-upload-area">
								<input id="photo-upload" type="file" accept="image/*" capture="environment" on:change={handlePhotoUpload} disabled={isSubmitting} class="file-input" />
								<label for="photo-upload" class="upload-btn photo-btn">
									<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/>
										<circle cx="12" cy="13" r="4"/>
									</svg>
									Take / Choose Photo
								</label>
							</div>
						{:else}
							<div class="photo-preview">
								{#if photoPreview}
									<img src={photoPreview} alt="Preview" />
								{/if}
								<button class="remove-photo-btn" on:click={removePhoto}>✕ Remove</button>
							</div>
						{/if}
					</div>
				{/if}

				<div class="form-group">
					<label class="form-label">Notes (Optional)</label>
					<textarea bind:value={completionNotes} placeholder="Add any notes..." disabled={isSubmitting} class="form-textarea" rows="3"></textarea>
				</div>
			</div>
		{/if}

		<!-- Action Buttons -->
		<div class="action-buttons">
			<button class="cancel-btn" on:click={() => goto('/mobile-interface/tasks')} disabled={isSubmitting}>
				Cancel
			</button>
			<button
				class="submit-btn"
				on:click={submitCompletion}
				disabled={!canSubmit || isSubmitting}
			>
				{#if isSubmitting}
					<div class="btn-spinner"></div>
					Completing...
				{:else}
					✅ Complete Task
				{/if}
			</button>
		</div>
	{/if}

	<!-- Photo Viewer Modal -->
	{#if showPhotoViewer}
		<div class="photo-modal" on:click={() => showPhotoViewer = false} role="dialog">
			<div class="photo-modal-content" on:click|stopPropagation role="presentation">
				<button class="photo-modal-close" on:click={() => showPhotoViewer = false} aria-label="Close">✕</button>
				<img src={viewerPhotoUrl} alt="Photo" />
			</div>
		</div>
	{/if}
</div>

<style>
	.receiving-completion {
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
		padding-bottom: 0.5rem;
	}

	/* ── Header ── */
	.completion-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.65rem 0.85rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.completion-header h1 {
		font-size: 0.95rem;
		font-weight: 600;
		margin: 0;
		color: #1F2937;
	}

	.back-btn {
		background: none;
		border: none;
		color: #374151;
		padding: 6px;
		border-radius: 6px;
		cursor: pointer;
		display: flex;
		align-items: center;
	}

	.back-btn:active {
		background: #F3F4F6;
	}

	/* ── States ── */
	.loading-state, .error-state, .success-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		text-align: center;
		min-height: 30vh;
		gap: 0.75rem;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.error-icon, .success-icon {
		font-size: 48px;
	}

	.error-state h2, .success-state h2 {
		font-size: 1.1rem;
		font-weight: 600;
		margin: 0;
		color: #1F2937;
	}

	.error-state p, .success-state p {
		color: #6B7280;
		margin: 0;
		font-size: 0.85rem;
	}

	.loading-state p {
		color: #6B7280;
		font-size: 0.85rem;
	}

	/* ── Task Card ── */
	.task-card {
		background: white;
		margin: 0.5rem 0.6rem;
		padding: 0.65rem 0.85rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.task-card-header {
		display: flex;
		gap: 0.35rem;
		margin-bottom: 0.4rem;
		flex-wrap: wrap;
		align-items: center;
	}

	.role-badge {
		display: inline-block;
		padding: 0.15rem 0.5rem;
		border-radius: 0.75rem;
		font-size: 0.7rem;
		font-weight: 600;
		background: #EFF6FF;
		color: #2563EB;
		border: 1px solid #BFDBFE;
	}

	.priority-badge {
		display: inline-block;
		padding: 0.15rem 0.5rem;
		border-radius: 0.75rem;
		font-size: 0.7rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.priority-high, .priority-urgent {
		background: #FEE2E2;
		color: #DC2626;
	}

	.priority-medium {
		background: #FEF3C7;
		color: #D97706;
	}

	.priority-low {
		background: #D1FAE5;
		color: #059669;
	}

	.task-title {
		font-size: 0.9rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.25rem;
	}

	.task-desc {
		font-size: 0.8rem;
		color: #6B7280;
		margin: 0 0 0.35rem;
		line-height: 1.5;
	}

	.task-meta {
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	/* ── Messages ── */
	.message {
		display: flex;
		align-items: center;
		gap: 0.45rem;
		padding: 0.55rem 0.85rem;
		margin: 0.5rem 0.6rem;
		border-radius: 8px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.error-msg {
		background: #FEF2F2;
		color: #DC2626;
		border: 1px solid #FECACA;
	}

	.success-msg {
		background: #F0FDF4;
		color: #059669;
		border: 1px solid #BBF7D0;
	}

	/* ── Dependency Warning ── */
	.dependency-warning {
		margin: 0.5rem 0.6rem;
		padding: 0.6rem 0.85rem;
		background: #FFFBEB;
		border: 1px solid #FDE68A;
		border-radius: 8px;
	}

	.dependency-warning h3 {
		margin: 0 0 0.4rem;
		font-size: 0.85rem;
		color: #D97706;
		font-weight: 600;
	}

	.dependency-warning ul {
		margin: 0;
		padding-left: 20px;
	}

	.dependency-warning li {
		font-size: 0.78rem;
		color: #92400E;
		line-height: 1.6;
	}

	/* ── Dependency Photos ── */
	.dependency-photos {
		background: white;
		margin: 0.5rem 0.6rem;
		padding: 0.6rem 0.85rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.dependency-photos h3 {
		margin: 0 0 0.5rem;
		font-size: 0.85rem;
		color: #1F2937;
		font-weight: 600;
	}

	.photo-grid {
		display: flex;
		gap: 10px;
		flex-wrap: wrap;
	}

	.dep-photo {
		width: 80px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		background: none;
		border: none;
		color: #374151;
		cursor: pointer;
		padding: 0;
	}

	.dep-photo img {
		width: 80px;
		height: 60px;
		object-fit: cover;
		border-radius: 6px;
		border: 1px solid #E5E7EB;
	}

	.dep-photo span {
		font-size: 0.65rem;
		color: #6B7280;
	}

	/* ── Form Section ── */
	.form-section {
		background: white;
		margin: 0.5rem 0.6rem;
		padding: 0.6rem 0.85rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.form-section h3 {
		margin: 0 0 0.6rem;
		font-size: 0.88rem;
		font-weight: 600;
		color: #1F2937;
	}

	.form-group {
		margin-bottom: 0.6rem;
	}

	.form-group:last-child {
		margin-bottom: 0;
	}

	.form-label {
		display: block;
		font-size: 0.82rem;
		font-weight: 500;
		margin-bottom: 0.3rem;
		color: #374151;
	}

	.required {
		color: #DC2626;
	}

	.form-input {
		width: 100%;
		padding: 0.5rem 0.6rem;
		background: white;
		border: 1.5px solid #D1D5DB;
		border-radius: 6px;
		color: #1F2937;
		font-size: 0.85rem;
		outline: none;
		box-sizing: border-box;
		transition: border-color 0.2s;
	}

	.form-input:focus {
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-input::placeholder {
		color: #9CA3AF;
	}

	.form-textarea {
		width: 100%;
		padding: 0.5rem 0.6rem;
		background: white;
		border: 1.5px solid #D1D5DB;
		border-radius: 6px;
		color: #1F2937;
		font-size: 0.82rem;
		outline: none;
		resize: vertical;
		font-family: inherit;
		box-sizing: border-box;
		min-height: 60px;
		transition: border-color 0.2s;
	}

	.form-textarea:focus {
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-textarea::placeholder {
		color: #9CA3AF;
	}

	.check-row {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-top: 6px;
		font-size: 0.78rem;
		color: #6B7280;
	}

	.check-icon {
		accent-color: #10B981;
	}

	/* ── File Upload ── */
	.file-input {
		display: none;
	}

	.upload-area {
		display: flex;
		justify-content: center;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem 0.85rem;
		background: #3B82F6;
		color: white;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		border: none;
		width: 100%;
		justify-content: center;
	}

	.upload-btn:hover {
		background: #2563EB;
	}

	.photo-btn {
		background: #10B981;
		padding: 1rem 0.85rem;
		flex-direction: column;
		gap: 0.5rem;
	}

	.photo-btn:hover {
		background: #059669;
	}

	.file-preview {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.5rem 0.6rem;
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		border-radius: 6px;
	}

	.file-name {
		font-size: 0.78rem;
		color: #059669;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		flex: 1;
	}

	.remove-btn {
		background: #FEE2E2;
		border: none;
		color: #DC2626;
		width: 24px;
		height: 24px;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.85rem;
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.remove-btn:hover {
		background: #FECACA;
	}

	/* ── Photo Preview ── */
	.photo-preview {
		position: relative;
	}

	.photo-preview img {
		width: 100%;
		max-height: 250px;
		object-fit: cover;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.remove-photo-btn {
		position: absolute;
		top: 8px;
		right: 8px;
		padding: 6px 12px;
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.75rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.remove-photo-btn:hover {
		background: #DC2626;
	}

	/* ── Info Card (Purchase Manager) ── */
	.info-card {
		background: #F9FAFB;
		border-radius: 6px;
		padding: 0.55rem 0.7rem;
		margin-bottom: 0.6rem;
		border: 1px solid #E5E7EB;
	}

	.info-row {
		display: flex;
		justify-content: space-between;
		padding: 0.3rem 0;
		border-bottom: 1px solid #F3F4F6;
		font-size: 0.78rem;
	}

	.info-row:last-child {
		border-bottom: none;
	}

	.info-row span:first-child {
		color: #6B7280;
	}

	.info-row span:last-child {
		color: #1F2937;
		font-weight: 500;
	}

	/* ── Status Checks ── */
	.status-checks {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
		margin-bottom: 0.6rem;
	}

	.status-item {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 0.7rem;
		border-radius: 6px;
		font-size: 0.82rem;
		color: #374151;
	}

	.status-item.done {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
	}

	.status-item.pending {
		background: #FFFBEB;
		border: 1px solid #FDE68A;
	}

	.status-icon {
		font-size: 1rem;
	}

	/* ── Hint Box ── */
	.hint-box {
		background: #EFF6FF;
		border: 1px solid #BFDBFE;
		border-radius: 6px;
		padding: 0.55rem 0.7rem;
		margin-bottom: 0.6rem;
		font-size: 0.78rem;
		color: #1D4ED8;
	}

	.hint-box p {
		margin: 0 0 0.5rem;
	}

	.refresh-btn {
		padding: 0.4rem 0.85rem;
		background: #3B82F6;
		border: none;
		color: white;
		border-radius: 6px;
		font-size: 0.78rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.refresh-btn:hover {
		background: #2563EB;
	}

	/* ── Action Buttons ── */
	.action-buttons {
		display: flex;
		gap: 0.6rem;
		padding: 0.6rem 0.85rem;
		background: white;
		border-top: 1px solid #E5E7EB;
		position: sticky;
		bottom: 0;
		z-index: 20;
	}

	.cancel-btn {
		flex: 1;
		padding: 0.6rem 0.85rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		color: #374151;
		border-radius: 8px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 40px;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #E5E7EB;
	}

	.submit-btn {
		flex: 2;
		padding: 0.6rem 0.85rem;
		background: #10B981;
		border: none;
		color: white;
		border-radius: 8px;
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		min-height: 40px;
		transition: all 0.2s;
	}

	.submit-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.submit-btn:disabled {
		background: #D1D5DB;
		color: #9CA3AF;
		cursor: not-allowed;
		transform: none;
	}

	.primary-btn {
		padding: 0.5rem 1.2rem;
		background: #3B82F6;
		border: none;
		color: white;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.primary-btn:hover {
		background: #2563EB;
	}

	.btn-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid transparent;
		border-top: 2px solid currentColor;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	/* ── Photo Modal ── */
	.photo-modal {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.8);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.photo-modal-content {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		display: flex;
		justify-content: center;
		align-items: center;
	}

	.photo-modal-content img {
		max-width: 100%;
		max-height: 85vh;
		object-fit: contain;
		border-radius: 8px;
	}

	.photo-modal-close {
		position: absolute;
		top: 0.5rem;
		right: 0.5rem;
		width: 2.5rem;
		height: 2.5rem;
		background: rgba(0, 0, 0, 0.7);
		border: none;
		color: white;
		border-radius: 50%;
		font-size: 1rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10;
		transition: background 0.2s;
	}

	.photo-modal-close:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	/* ── Photo Upload Area ── */
	.photo-upload-area {
		display: flex;
		justify-content: center;
	}

	/* ── Mobile optimizations ── */
	@media (max-width: 640px) {
		.task-card,
		.form-section,
		.dependency-photos,
		.dependency-warning {
			margin: 0.4rem 0.6rem;
		}

		.action-buttons {
			flex-direction: column;
		}

		.cancel-btn,
		.submit-btn {
			width: 100%;
		}
	}

	/* ── Safe area handling ── */
	@supports (padding: max(0px)) {
		.action-buttons {
			padding-bottom: max(0.6rem, env(safe-area-inset-bottom));
		}
	}
</style>
