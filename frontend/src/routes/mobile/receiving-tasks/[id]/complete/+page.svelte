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

	// Purchase manager validation states
	let verificationCompleted = false;
	let prExcelUploaded = false;

	// Photo upload states (for shelf_stocker and other roles requiring photos)
	let photoFile: File | null = null;
	let photoPreview: string | null = null;
	let requirePhotoUpload = false;

	// Task dependency states
	let dependencyStatus: any = null;
	let dependencyPhotos: any = null;
	let canComplete = true;
	let blockingRoles: string[] = [];

	// Mobile popup modal states
	let showErrorPopup = false;
	let popupTitle = '';
	let popupMessage = '';
	let popupType = 'error'; // 'error' | 'success' | 'info'

	// Photo viewer modal states
	let showPhotoViewer = false;
	let viewerPhotoUrl = '';
	let viewerPhotoTitle = '';

	// Validation - different for each role
	$: isFormValid = taskDetails?.role_type === 'inventory_manager' 
		? (formData.erp_purchase_invoice_reference.trim() && 
		   formData.has_erp_purchase_invoice && 
		   formData.has_pr_excel_file && 
		   formData.has_original_bill)
		: taskDetails?.role_type === 'purchase_manager'
		? (prExcelUploaded && verificationCompleted)
		: taskDetails?.role_type === 'shelf_stocker'
		? (requirePhotoUpload ? photoFile !== null : true)
		: canComplete; // For branch_manager, night_supervisor - check dependencies

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
				.in('role_type', ['inventory_manager', 'purchase_manager', 'shelf_stocker', 'branch_manager', 'night_supervisor', 'warehouse_handler', 'accountant'])
				.single();

			if (taskError || !task) {
				throw new Error('Task not found or not accessible');
			}

			// Task is assigned to this user, allow completion regardless of current position
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
				prExcelUploaded = true;
				// Create a fake File object to display the filename
				const fileName = receivingRecord.pr_excel_file_url.split('/').pop() || 'PR Excel (Already Uploaded)';
				prExcelFile = { name: fileName, alreadyUploaded: true } as any;
				console.log('✅ [Mobile] PR Excel file already uploaded:', receivingRecord.pr_excel_file_url);
			}

			// For purchase manager, also check verification status
			if (taskDetails?.role_type === 'purchase_manager') {
				await loadPurchaseManagerStatus();
			}

			// Check if this role requires photo upload
			await checkPhotoRequirement();

			// Check task dependencies
			await checkTaskDependencies();

			// Check for Original Bill file - look for URL, not boolean flag
			if (receivingRecord.original_bill_url) {
				formData.has_original_bill = true;
				// Create a fake File object to display the filename
				const fileName = receivingRecord.original_bill_url.split('/').pop() || 'Original Bill (Already Uploaded)';
				originalBillFile = { name: fileName, alreadyUploaded: true } as any;
				console.log('✅ [Mobile] Original bill already uploaded:', receivingRecord.original_bill_url);
			}
		}
		} catch (error) {
			console.error('Error loading task details:', error);
			errorMessage = error.message || 'Failed to load task details';
		} finally {
			isLoading = false;
		}
	}

	// Load purchase manager verification status
	async function loadPurchaseManagerStatus() {
		try {
			console.log('🔍 [Mobile] Loading purchase manager status...');
			
			const { data: paymentSchedule, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.select('pr_excel_verified')
				.eq('receiving_record_id', receivingRecord.id)
				.single();

			if (!scheduleError && paymentSchedule) {
				verificationCompleted = paymentSchedule.pr_excel_verified === true;
				console.log('✅ [Mobile] Verification status loaded:', verificationCompleted);
			} else {
				verificationCompleted = false;
				console.log('⚠️ [Mobile] No payment schedule found or verification not completed');
			}
		} catch (err) {
			console.error('❌ [Mobile] Error loading verification status:', err);
			verificationCompleted = false;
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

			// Upload photo if required and provided
			let photoUrl = null;
			if (requirePhotoUpload && photoFile) {
				console.log('📷 [Mobile] Uploading completion photo...');
				photoUrl = await uploadPhoto();
				if (!photoUrl) {
					showMobilePopup('error', 'Upload Failed', 'Failed to upload photo. Please try again.');
					return;
				}
			}

			// Check dependencies one more time before submission
			if (!canComplete) {
				showMobilePopup('error', 'Dependencies Not Met', `Cannot complete task. Waiting for: ${blockingRoles.join(', ')}`);
				return;
			}

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
					completion_notes: formData.completion_notes,
					completion_photo_url: photoUrl
				})
			});

			if (!response.ok) {
				const errorData = await response.json();
				
				// Show custom popup for different error types
				if (taskDetails?.role_type === 'purchase_manager') {
					if (errorData.error_code === 'PR_EXCEL_NOT_UPLOADED') {
						showMobilePopup('error', 'PR Excel Required', 'PR Excel not uploaded. The inventory manager must upload the PR Excel. After that, you need to verify it.');
					} else if (errorData.error_code === 'VERIFICATION_NOT_FINISHED') {
						showMobilePopup('error', 'Verification Required', 'PR Excel not verified.');
					} else {
						showMobilePopup('error', 'Error', errorData.error || 'Failed to complete task');
					}
				} else if (errorData.error_code === 'PHOTO_UPLOAD_REQUIRED') {
					showMobilePopup('error', 'Photo Required', `Photo upload is required for ${taskDetails?.role_type} tasks.`);
				} else if (errorData.error_code === 'DEPENDENCIES_NOT_MET') {
					showMobilePopup('error', 'Dependencies Not Met', errorData.error || 'Cannot complete task due to unmet dependencies.');
				} else {
					showMobilePopup('error', 'Error', errorData.error || 'Failed to complete task');
				}
				return;
			}

			const result = await response.json();
			
			// Show success popup based on role
			const roleDisplayNames = {
				'inventory_manager': 'Inventory Manager',
				'purchase_manager': 'Purchase Manager', 
				'shelf_stocker': 'Shelf Stocker',
				'branch_manager': 'Branch Manager',
				'night_supervisor': 'Night Supervisor',
				'warehouse_handler': 'Warehouse Handler',
				'accountant': 'Accountant'
			};
			
			const roleName = roleDisplayNames[taskDetails?.role_type] || taskDetails?.role_type;
			showMobilePopup('success', 'Task Completed', `${roleName} task completed successfully!`);
			
			notifications.add({
				type: 'success',
				message: 'Task completed successfully!',
				duration: 3000
			});
			
			// Auto redirect after 2 seconds
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

	// Mobile popup functions
	function showMobilePopup(type: 'error' | 'success' | 'info', title: string, message: string) {
		popupType = type;
		popupTitle = title;
		popupMessage = message;
		showErrorPopup = true;
	}

	function closeMobilePopup() {
		showErrorPopup = false;
		popupTitle = '';
		popupMessage = '';
		popupType = 'error';
	}

	// Photo viewer functions
	function openPhotoViewer(photoUrl, roleType) {
		viewerPhotoUrl = photoUrl;
		viewerPhotoTitle = roleType === 'shelf_stocker' ? 'Shelf Stocker Completion Photo' : `${roleType} Completion Photo`;
		showPhotoViewer = true;
	}

	function closePhotoViewer() {
		showPhotoViewer = false;
		viewerPhotoUrl = '';
		viewerPhotoTitle = '';
	}

	// Check if this role requires photo upload
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
				console.log(`📷 [Mobile] Photo required for ${taskDetails.role_type}: ${requirePhotoUpload}`);
			}
		} catch (error) {
			console.error('Error checking photo requirement:', error);
		}
	}

	// Check task dependencies
	async function checkTaskDependencies() {
		if (!taskDetails?.receiving_record_id || !taskDetails?.role_type) return;

		// Special check for accountant dependency on inventory manager
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
				dependencyStatus = depStatus;
				canComplete = depStatus.can_complete || false;
				blockingRoles = depStatus.blocking_roles || [];
				
				console.log(`🔗 [Mobile] Dependencies for ${taskDetails.role_type}:`, depStatus);

				// If there are completed dependencies, get their photos
				if (depStatus.completed_dependencies && depStatus.completed_dependencies.length > 0) {
					await loadDependencyPhotos(depStatus.completed_dependencies);
				}
			}
		} catch (error) {
			console.error('Error checking dependencies:', error);
		}
	}

	// Special dependency check for accountant role
	async function checkAccountantDependency() {
		try {
			console.log('🧾 [Mobile] Checking accountant dependency on inventory manager...');
			
			// Check if inventory manager task is completed
			const { data: inventoryTask, error: inventoryError } = await supabase
				.from('receiving_tasks')
				.select('task_completed, completed_at')
				.eq('receiving_record_id', taskDetails.receiving_record_id)
				.eq('role_type', 'inventory_manager')
				.maybeSingle();

			if (inventoryError) {
				console.error('❌ [Mobile] Error checking inventory task:', inventoryError);
				// Allow completion if we can't check (don't block user)
				return;
			}

			if (!inventoryTask?.task_completed) {
				canComplete = false;
				blockingRoles = ['Inventory Manager must complete their task first'];
				errorMessage = 'The Inventory Manager must complete their task before the Accountant can proceed.';
				console.log('❌ [Mobile] Inventory manager task not completed');
				return;
			}

			// Check if original bill is uploaded
			const { data: receivingRecord, error: recordError } = await supabase
				.from('receiving_records')
				.select('original_bill_uploaded, original_bill_url')
				.eq('id', taskDetails.receiving_record_id)
				.single();

			if (recordError) {
				console.error('❌ [Mobile] Error checking receiving record:', recordError);
				canComplete = false;
				errorMessage = 'Error checking dependencies. Please try again.';
				return;
			}

			// Check original bill upload status
			if (!receivingRecord.original_bill_uploaded || !receivingRecord.original_bill_url) {
				canComplete = false;
				blockingRoles = ['Original bill upload required from Inventory Manager'];
				errorMessage = 'Original bill not uploaded by the inventory manager – please follow up.';
				console.log('❌ [Mobile] Original bill not uploaded by inventory manager');
				return;
			}

			// All good, accountant can proceed
			canComplete = true;
			blockingRoles = [];
			errorMessage = '';
			console.log('✅ [Mobile] Accountant dependency check passed - original bill uploaded');
			
		} catch (error) {
			console.error('❌ [Mobile] Error checking accountant dependency:', error);
			canComplete = false;
			errorMessage = 'Error checking dependencies. Please try again.';
		}
	}

	// Load photos from completed dependency tasks
	async function loadDependencyPhotos(completedDependencies: string[]) {
		try {
			const { data: photos, error } = await supabase.rpc('get_dependency_completion_photos', {
				receiving_record_id_param: taskDetails.receiving_record_id,
				dependency_role_types: completedDependencies
			});

			if (!error && photos) {
				dependencyPhotos = photos;
				console.log(`📸 [Mobile] Dependency photos loaded:`, photos);
			}
		} catch (error) {
			console.error('Error loading dependency photos:', error);
		}
	}

	// Handle photo upload
	async function handlePhotoUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			if (!file.type.startsWith('image/')) {
				showMobilePopup('error', 'Invalid File', 'Please select a valid image file');
				return;
			}
			
			if (file.size > 5 * 1024 * 1024) {
				showMobilePopup('error', 'File Too Large', 'Image file must be less than 5MB');
				return;
			}
			
			photoFile = file;
			
			const reader = new FileReader();
			reader.onload = (e) => {
				photoPreview = e.target?.result as string;
			};
			reader.readAsDataURL(file);
			
			console.log('📷 [Mobile] Photo selected:', file.name);
		}
	}

	function removePhoto() {
		photoFile = null;
		photoPreview = null;
		
		const fileInput = document.getElementById('photo-upload') as HTMLInputElement;
		if (fileInput) {
			fileInput.value = '';
		}
	}

	// Upload photo to storage
	async function uploadPhoto(): Promise<string | null> {
		if (!photoFile || !currentUserData) return null;
		
		try {
			const fileExt = photoFile.name.split('.').pop();
			const fileName = `receiving-task-${taskId}-${Date.now()}.${fileExt}`;
			
			const { data, error } = await supabase.storage
				.from('completion-photos')
				.upload(fileName, photoFile, {
					cacheControl: '3600',
					upsert: false
				});
			
			if (error) {
				console.error('Photo upload error:', error);
				return null;
			}
			
			const { data: urlData } = supabase.storage
				.from('completion-photos')
				.getPublicUrl(fileName);
			
			console.log('✅ [Mobile] Photo uploaded successfully:', urlData.publicUrl);
			return urlData.publicUrl;
		} catch (error) {
			console.error('Error uploading photo:', error);
			return null;
		}
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
			
			{#if taskDetails?.role_type === 'inventory_manager'}
				<!-- Inventory Manager Requirements -->
				
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
			
			{:else if taskDetails?.role_type === 'purchase_manager'}
				<!-- Purchase Manager Requirements -->
				<div class="purchase-manager-info">
					<!-- Receiving Record Details -->
					{#if receivingRecord}
						<div class="info-card">
							<div class="info-header">
								<h4>📋 Receiving Record Details</h4>
							</div>
							<div class="details-grid">
								<div class="detail-row">
									<span class="detail-label">Branch:</span>
									<span class="detail-value">{receivingRecord.branch_name || 'Unknown Branch'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Vendor:</span>
									<span class="detail-value">{receivingRecord.vendor_name || 'Unknown Vendor'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Receiving Date:</span>
									<span class="detail-value">{new Date(receivingRecord.bill_date).toLocaleDateString()}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Amount:</span>
									<span class="detail-value">{receivingRecord.bill_amount}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Number:</span>
									<span class="detail-value">{receivingRecord.bill_number}</span>
								</div>
							</div>
						</div>
					{/if}

					<!-- Task Requirements Status -->
					<div class="info-card">
						<div class="info-header">
							<h4>📊 Task Requirements Status</h4>
						</div>
						<div class="requirements-checklist">
							<div class="requirement-check" class:check-success={prExcelUploaded} class:check-error={!prExcelUploaded}>
								<span class="check-icon">
									{#if prExcelUploaded}
										✅
									{:else}
										❌
									{/if}
								</span>
								<div class="check-content">
									<strong>PR Excel Upload Status</strong>
									{#if prExcelUploaded}
										<p class="status-success">PR Excel file is uploaded</p>
									{:else}
										<p class="status-error">PR Excel not uploaded. The inventory manager must upload the PR Excel. After that, you need to verify it.</p>
									{/if}
								</div>
							</div>
							<div class="requirement-check" class:check-success={verificationCompleted} class:check-error={!verificationCompleted}>
								<span class="check-icon">
									{#if verificationCompleted}
										✅
									{:else}
										❌
									{/if}
								</span>
								<div class="check-content">
									<strong>Verification Status</strong>
									{#if verificationCompleted}
										<p class="status-success">PR Excel verified</p>
									{:else}
										<p class="status-error">PR Excel not verified.</p>
									{/if}
								</div>
							</div>
						</div>
						
						{#if prExcelUploaded && verificationCompleted}
							<div class="ready-indicator">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
								</svg>
								<span><strong>Ready to complete!</strong> All requirements are met.</span>
							</div>
						{/if}
					</div>
				</div>
			
			{:else if taskDetails?.role_type === 'shelf_stocker'}
				<!-- Shelf Stocker Requirements -->
				<div class="shelf-stocker-info">
					{#if receivingRecord}
						<div class="info-card">
							<div class="info-header">
								<h4>📋 Receiving Record Details</h4>
							</div>
							<div class="details-grid">
								<div class="detail-row">
									<span class="detail-label">Branch:</span>
									<span class="detail-value">{receivingRecord.branch_name || 'Unknown Branch'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Vendor:</span>
									<span class="detail-value">{receivingRecord.vendor_name || 'Unknown Vendor'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Amount:</span>
									<span class="detail-value">{receivingRecord.bill_amount}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Number:</span>
									<span class="detail-value">{receivingRecord.bill_number}</span>
								</div>
							</div>
						</div>
					{/if}

					<!-- Photo Upload Requirement -->
					{#if requirePhotoUpload}
						<div class="info-card">
							<div class="info-header">
								<h4>📷 Photo Upload Required</h4>
							</div>
							<div class="photo-requirement">
								<p class="requirement-description">
									Please take a photo of the completed shelf stocking to document your work.
								</p>
								
								{#if !photoPreview}
									<div class="upload-section">
										<input
											id="photo-upload"
											type="file"
											accept="image/*"
											on:change={handlePhotoUpload}
											disabled={isSubmitting}
											class="file-input"
											required
										/>
										<label for="photo-upload" class="upload-btn">
											<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
												<circle cx="12" cy="13" r="4"/>
											</svg>
											Take Photo
										</label>
									</div>
								{:else}
									<div class="photo-preview">
										<img src={photoPreview} alt="Shelf stocking completion" class="preview-image" />
										<button class="remove-photo" on:click={removePhoto} disabled={isSubmitting}>
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M18 6L6 18M6 6l12 12"/>
											</svg>
										</button>
									</div>
								{/if}
							</div>
						</div>
					{/if}
				</div>

			{:else if taskDetails?.role_type === 'branch_manager' || taskDetails?.role_type === 'night_supervisor'}
				<!-- Branch Manager / Night Supervisor Requirements -->
				<div class="supervisor-info">
					{#if receivingRecord}
						<div class="info-card">
							<div class="info-header">
								<h4>📋 Receiving Record Details</h4>
							</div>
							<div class="details-grid">
								<div class="detail-row">
									<span class="detail-label">Branch:</span>
									<span class="detail-value">{receivingRecord.branch_name || 'Unknown Branch'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Vendor:</span>
									<span class="detail-value">{receivingRecord.vendor_name || 'Unknown Vendor'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Amount:</span>
									<span class="detail-value">{receivingRecord.bill_amount}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Number:</span>
									<span class="detail-value">{receivingRecord.bill_number}</span>
								</div>
							</div>
						</div>
					{/if}

					<!-- Dependency Status -->
					{#if dependencyStatus}
						<div class="info-card">
							<div class="info-header">
								<h4>📊 Task Dependencies</h4>
							</div>
							<div class="dependency-status">
								{#if canComplete}
									<div class="dependency-success">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
										</svg>
										<span><strong>Ready to complete!</strong> All dependencies are met.</span>
									</div>
								{:else}
									<div class="dependency-waiting">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<circle cx="12" cy="12" r="10"/>
											<polyline points="12,6 12,12 16,14"/>
										</svg>
										<span><strong>Waiting for:</strong> {blockingRoles.join(', ')}</span>
									</div>
								{/if}
							</div>
						</div>
					{/if}

					<!-- Dependency Photos (show completed dependency work) -->
					{#if dependencyPhotos && Object.keys(dependencyPhotos).length > 0}
						<div class="info-card">
							<div class="info-header">
								<h4>📸 Completed Work Photos</h4>
							</div>
							<div class="dependency-photos">
								{#each Object.entries(dependencyPhotos) as [roleType, photoUrl]}
									<div class="dependency-photo">
										<h5 class="photo-role-title">
											{roleType === 'shelf_stocker' ? 'Shelf Stocker' : roleType} Work:
										</h5>
										<div class="photo-container" on:click={() => openPhotoViewer(photoUrl, roleType)}>
											<img src={photoUrl} alt="{roleType} completion photo" class="dependency-photo-img" />
											<div class="photo-overlay">
												<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
													<path d="M15 3h6v6m-6 0L9 15M9 3H3v6"/>
												</svg>
												<span>Tap to view full size</span>
											</div>
										</div>
									</div>
								{/each}
							</div>
						</div>
					{/if}
				</div>

			{:else if taskDetails?.role_type === 'accountant'}
				<!-- Accountant Requirements -->
				<div class="accountant-info">
					{#if receivingRecord}
						<div class="info-card">
							<div class="info-header">
								<h4>📋 Receiving Record Details</h4>
							</div>
							<div class="details-grid">
								<div class="detail-row">
									<span class="detail-label">Branch:</span>
									<span class="detail-value">{receivingRecord.branch_name || 'Unknown Branch'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Vendor:</span>
									<span class="detail-value">{receivingRecord.vendor_name || 'Unknown Vendor'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Amount:</span>
									<span class="detail-value">{receivingRecord.bill_amount}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Number:</span>
									<span class="detail-value">{receivingRecord.bill_number}</span>
								</div>
							</div>
						</div>
					{/if}

					<!-- Accountant Dependency Status -->
					<div class="info-card">
						<div class="info-header">
							<h4>📊 Prerequisites</h4>
						</div>
						<div class="dependency-status">
							{#if canComplete}
								<div class="dependency-success">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
									</svg>
									<span><strong>Ready to complete!</strong> Original bill has been uploaded by the Inventory Manager.</span>
								</div>
							{:else}
								<div class="dependency-waiting">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<polyline points="12,6 12,12 16,14"/>
									</svg>
									<span><strong>Waiting:</strong> {blockingRoles.join(', ')}</span>
								</div>
								{#if errorMessage}
									<div class="error-message">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<circle cx="12" cy="12" r="10"/>
											<line x1="12" y1="8" x2="12" y2="12"/>
											<line x1="12" y1="16" x2="12.01" y2="16"/>
										</svg>
										<span>{errorMessage}</span>
									</div>
								{/if}
							{/if}
						</div>
					</div>

					<div class="info-card">
						<div class="info-header">
							<h4>🧾 Accountant Tasks</h4>
						</div>
						<div class="completion-info">
							<p>As the Accountant, you need to:</p>
							<ul>
								<li>Enter payment details into Purchase ERP system</li>
								<li>Process the original bill documentation</li>
								<li>Update ERP reference number</li>
								<li>Confirm all financial records are accurate</li>
							</ul>
							<p><strong>Note:</strong> You can only complete this task after the Inventory Manager has uploaded the original bill.</p>
						</div>
					</div>
				</div>

			{:else}
				<!-- Other Roles (warehouse_handler, etc.) -->
				<div class="other-role-info">
					{#if receivingRecord}
						<div class="info-card">
							<div class="info-header">
								<h4>📋 Receiving Record Details</h4>
							</div>
							<div class="details-grid">
								<div class="detail-row">
									<span class="detail-label">Branch:</span>
									<span class="detail-value">{receivingRecord.branch_name || 'Unknown Branch'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Vendor:</span>
									<span class="detail-value">{receivingRecord.vendor_name || 'Unknown Vendor'}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Amount:</span>
									<span class="detail-value">{receivingRecord.bill_amount}</span>
								</div>
								<div class="detail-row">
									<span class="detail-label">Bill Number:</span>
									<span class="detail-value">{receivingRecord.bill_number}</span>
								</div>
							</div>
						</div>
					{/if}

					<div class="info-card">
						<div class="info-header">
							<h4>✅ Task Completion</h4>
						</div>
						<div class="completion-info">
							<p>Mark this task as completed when you have finished your {taskDetails?.role_type} responsibilities for this receiving record.</p>
						</div>
					</div>
				</div>
			{/if}
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

<!-- Mobile Popup Modal -->
{#if showErrorPopup}
	<div class="mobile-popup-overlay" on:click={closeMobilePopup}>
		<div class="mobile-popup-content" on:click|stopPropagation>
			<div class="popup-header" class:popup-error={popupType === 'error'} class:popup-success={popupType === 'success'} class:popup-info={popupType === 'info'}>
				<div class="popup-icon">
					{#if popupType === 'error'}
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<line x1="15" y1="9" x2="9" y2="15"/>
							<line x1="9" y1="9" x2="15" y2="15"/>
						</svg>
					{:else if popupType === 'success'}
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
						</svg>
					{:else}
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<line x1="12" y1="16" x2="12" y2="12"/>
							<line x1="12" y1="8" x2="12.01" y2="8"/>
						</svg>
					{/if}
				</div>
				<h3 class="popup-title">{popupTitle}</h3>
			</div>
			<div class="popup-body">
				<p class="popup-message">{popupMessage}</p>
			</div>
			<div class="popup-actions">
				<button class="popup-btn popup-btn-primary" on:click={closeMobilePopup}>
					OK
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Photo Viewer Modal -->
{#if showPhotoViewer}
	<div class="photo-viewer-overlay" on:click={closePhotoViewer}>
		<div class="photo-viewer-content" on:click|stopPropagation>
			<div class="photo-viewer-header">
				<h3 class="photo-viewer-title">{viewerPhotoTitle}</h3>
				<button class="photo-viewer-close" on:click={closePhotoViewer}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
			<div class="photo-viewer-body">
				<img src={viewerPhotoUrl} alt={viewerPhotoTitle} class="photo-viewer-img" />
			</div>
		</div>
	</div>
{/if}

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

	/* Purchase Manager Styles */
	.purchase-manager-info {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.info-card {
		background: #ffffff;
		border: 1px solid #e5e7eb;
		border-radius: 12px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.info-header {
		margin-bottom: 1rem;
	}

	.info-header h4 {
		margin: 0;
		font-size: 1rem;
		font-weight: 600;
		color: #374151;
	}

	.details-grid {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.5rem 0;
		border-bottom: 1px solid #f3f4f6;
	}

	.detail-row:last-child {
		border-bottom: none;
	}

	.detail-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-value {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		text-align: right;
	}

	.requirements-checklist {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.requirement-check {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		padding: 1rem;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		transition: all 0.2s ease;
	}

	.requirement-check.check-success {
		background: #f0fdf4;
		border-color: #bbf7d0;
	}

	.requirement-check.check-error {
		background: #fef2f2;
		border-color: #fecaca;
	}

	.check-icon {
		font-size: 1.125rem;
		flex-shrink: 0;
		margin-top: 0.125rem;
	}

	.check-content {
		flex: 1;
	}

	.check-content strong {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.25rem;
	}

	.check-content p {
		margin: 0;
		font-size: 0.8125rem;
		line-height: 1.4;
	}

	.status-success {
		color: #059669;
		font-weight: 500;
	}

	.status-error {
		color: #dc2626;
		font-weight: 500;
	}

	.ready-indicator {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		border-radius: 8px;
		color: #059669;
		margin-top: 1rem;
	}

	.ready-indicator svg {
		flex-shrink: 0;
	}

	.info-header h4 {
		margin: 0;
		font-size: 16px;
		font-weight: 600;
		color: #374151;
	}

	.requirements-checklist {
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.requirement-check {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 12px;
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
	}

	.check-icon {
		font-size: 18px;
		flex-shrink: 0;
		margin-top: 2px;
	}

	.check-content {
		flex: 1;
	}

	.check-content strong {
		display: block;
		font-size: 14px;
		font-weight: 600;
		color: #374151;
		margin-bottom: 4px;
	}

	.check-content p {
		margin: 0;
		font-size: 13px;
		color: #6b7280;
		line-height: 1.4;
	}

	.info-note {
		display: flex;
		align-items: flex-start;
		gap: 8px;
		padding: 12px;
		background: #eff6ff;
		border: 1px solid #dbeafe;
		border-radius: 6px;
		font-size: 13px;
		color: #1e40af;
		line-height: 1.4;
	}

	.info-note svg {
		flex-shrink: 0;
		margin-top: 1px;
	}

	/* Mobile Popup Modal Styles */
	.mobile-popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}

	.mobile-popup-content {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
		max-width: 400px;
		width: 100%;
		max-height: 80vh;
		overflow: hidden;
		animation: popupSlideIn 0.3s ease-out;
	}

	@keyframes popupSlideIn {
		from {
			opacity: 0;
			transform: translateY(20px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}

	.popup-header {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 1.5rem 1.5rem 1rem 1.5rem;
		border-bottom: 1px solid #f3f4f6;
	}

	.popup-header.popup-error {
		color: #dc2626;
	}

	.popup-header.popup-success {
		color: #059669;
	}

	.popup-header.popup-info {
		color: #2563eb;
	}

	.popup-icon {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		border-radius: 50%;
	}

	.popup-error .popup-icon {
		background: #fef2f2;
	}

	.popup-success .popup-icon {
		background: #f0fdf4;
	}

	.popup-info .popup-icon {
		background: #eff6ff;
	}

	.popup-title {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 600;
		flex: 1;
	}

	.popup-body {
		padding: 1rem 1.5rem;
	}

	.popup-message {
		margin: 0;
		font-size: 0.875rem;
		line-height: 1.5;
		color: #6b7280;
	}

	.popup-actions {
		padding: 1rem 1.5rem 1.5rem 1.5rem;
		display: flex;
		gap: 0.75rem;
		justify-content: flex-end;
	}

	.popup-btn {
		padding: 0.5rem 1.5rem;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		border: none;
		cursor: pointer;
		transition: all 0.2s ease;
		min-width: 80px;
	}

	.popup-btn-primary {
		background: #3b82f6;
		color: white;
	}

	.popup-btn-primary:hover {
		background: #2563eb;
	}

	.popup-btn-primary:active {
		transform: translateY(1px);
	}

	/* New Role-Specific Styles */
	.shelf-stocker-info,
	.supervisor-info,
	.other-role-info {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.photo-requirement {
		padding: 1rem;
	}

	.requirement-description {
		margin: 0 0 1rem 0;
		font-size: 0.875rem;
		color: #6b7280;
		line-height: 1.5;
	}

	.upload-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s ease;
		justify-content: center;
		width: 100%;
	}

	.upload-btn:hover {
		background: #2563eb;
	}

	.upload-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.photo-preview {
		position: relative;
		display: inline-block;
		margin-top: 1rem;
	}

	.preview-image {
		width: 100%;
		max-width: 300px;
		height: 200px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
	}

	.remove-photo {
		position: absolute;
		top: -8px;
		right: -8px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.remove-photo:hover {
		background: #dc2626;
	}

	.dependency-status {
		padding: 1rem;
	}

	.dependency-success,
	.dependency-waiting {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		border-radius: 8px;
		font-size: 0.875rem;
	}

	.dependency-success {
		background: #f0fdf4;
		border: 1px solid #bbf7d0;
		color: #059669;
	}

	.dependency-waiting {
		background: #fffbeb;
		border: 1px solid #fed7aa;
		color: #d97706;
	}

	.dependency-photos {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.dependency-photo {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.photo-role-title {
		margin: 0;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
	}

	.dependency-photo-img {
		width: 100%;
		max-width: 300px;
		height: 150px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #e5e7eb;
	}

	.completion-info {
		padding: 1rem;
	}

	.completion-info p {
		margin: 0;
		font-size: 0.875rem;
		color: #6b7280;
		line-height: 1.5;
	}

	/* Accountant-specific styles */
	.dependency-status {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.dependency-success {
		display: flex;
		align-items: center;
		gap: 8px;
		color: #16a34a;
		background: #f0fdf4;
		padding: 8px 12px;
		border-radius: 6px;
		border: 1px solid #86efac;
	}

	.dependency-waiting {
		display: flex;
		align-items: center;
		gap: 8px;
		color: #ca8a04;
		background: #fefce8;
		padding: 8px 12px;
		border-radius: 6px;
		border: 1px solid #fbbf24;
	}

	.error-message {
		display: flex;
		align-items: center;
		gap: 8px;
		color: #dc2626;
		background: #fef2f2;
		padding: 8px 12px;
		border-radius: 6px;
		border: 1px solid #fca5a5;
		margin-top: 4px;
	}

	.accountant-info .completion-info ul {
		margin: 8px 0;
		padding-left: 20px;
	}

	.accountant-info .completion-info li {
		margin: 4px 0;
		color: #6b7280;
	}

	.other-role-info .completion-info {
		color: #6b7280;
	}

	/* Photo viewer styles */
	.photo-container {
		position: relative;
		cursor: pointer;
		border-radius: 8px;
		overflow: hidden;
		transition: transform 0.2s ease;
	}

	.photo-container:hover {
		transform: scale(1.02);
	}

	.photo-container:active {
		transform: scale(0.98);
	}

	.photo-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.4);
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.2s ease;
		color: white;
		font-size: 0.75rem;
		text-align: center;
		gap: 4px;
	}

	.photo-container:hover .photo-overlay {
		opacity: 1;
	}

	.photo-viewer-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.9);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 20px;
	}

	.photo-viewer-content {
		background: white;
		border-radius: 12px;
		max-width: 95vw;
		max-height: 95vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.photo-viewer-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px 20px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.photo-viewer-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.photo-viewer-close {
		background: none;
		border: none;
		cursor: pointer;
		padding: 4px;
		border-radius: 6px;
		color: #6b7280;
		transition: all 0.2s ease;
	}

	.photo-viewer-close:hover {
		background: #e5e7eb;
		color: #374151;
	}

	.photo-viewer-body {
		padding: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 300px;
		max-height: 70vh;
		overflow: hidden;
	}

	.photo-viewer-img {
		max-width: 100%;
		max-height: 100%;
		object-fit: contain;
		border-radius: 8px;
	}
</style>