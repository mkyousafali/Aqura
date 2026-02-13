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
			
			// Check if PR Excel is verified in the payment schedule
			const { data: scheduleData, error: scheduleError } = await supabase
				.from('vendor_payment_schedule')
				.select('pr_excel_verified')
				.eq('receiving_record_id', receivingRecord.id)
				.maybeSingle();

			if (scheduleError) {
				console.warn('⚠️ [Mobile] Error checking PR Excel verification:', scheduleError);
			}

			if (!scheduleError && scheduleData) {
				// Consider verified only if pr_excel_verified is explicitly true
				verificationCompleted = scheduleData.pr_excel_verified === true;
				console.log('✅ [Mobile] Verification status loaded:', verificationCompleted, '(pr_excel_verified:', scheduleData.pr_excel_verified, ')');
			} else {
				// If no schedule found or error, verification is incomplete
				verificationCompleted = false;
				console.log('⚠️ [Mobile] Could not load verification status - no payment schedule found');
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
				goto('/mobile-interface/tasks');
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
			console.log('🧾 [Mobile] Checking accountant dependency - verifying required uploads...');
			
			// Get receiving record to check file uploads
			const { data: receivingRecord, error: recordError } = await supabase
				.from('receiving_records')
				.select('original_bill_uploaded, original_bill_url, pr_excel_file_uploaded, pr_excel_file_url')
				.eq('id', taskDetails.receiving_record_id)
				.single();

			if (recordError) {
				console.error('❌ [Mobile] Error checking receiving record:', recordError);
				canComplete = false;
				errorMessage = 'Error checking dependencies. Please try again.';
				return;
			}

			const missingFiles = [];

			// Check original bill upload status
			if (!receivingRecord.original_bill_uploaded || !receivingRecord.original_bill_url) {
				missingFiles.push('Original Bill');
				console.log('❌ [Mobile] Original bill not uploaded');
			} else {
				console.log('✅ [Mobile] Original bill uploaded');
			}

			// Check PR Excel upload status
			if (!receivingRecord.pr_excel_file_uploaded || !receivingRecord.pr_excel_file_url) {
				missingFiles.push('PR Excel File');
				console.log('❌ [Mobile] PR Excel not uploaded');
			} else {
				console.log('✅ [Mobile] PR Excel uploaded');
			}

			// If any files are missing, block completion
			if (missingFiles.length > 0) {
				canComplete = false;
				blockingRoles = missingFiles.map(file => `${file} must be uploaded first`);
				errorMessage = `Missing required files: ${missingFiles.join(', ')}. Please ensure all files are uploaded before completing this task.`;
				console.log('❌ [Mobile] Missing required files:', missingFiles);
				return;
			}

			// All files uploaded, accountant can proceed
			canComplete = true;
			blockingRoles = [];
			errorMessage = '';
			console.log('✅ [Mobile] Accountant dependency check passed - all required files uploaded');
			
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
			<button class="back-btn" on:click={() => goto('/mobile-interface/tasks')}>
				← Back to Tasks
			</button>
		</div>
	{:else}
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
			<h3>Completion</h3>
			
			{#if taskDetails?.role_type === 'inventory_manager'}
				<!-- ERP Reference -->
				<div class="req-row">
					<span class="req-label required">ERP Invoice Ref</span>
					<input
						type="checkbox"
						bind:checked={formData.has_erp_purchase_invoice}
						disabled
						class="requirement-checkbox"
					/>
				</div>
				<input
					type="text"
					bind:value={formData.erp_purchase_invoice_reference}
					on:input={onErpReferenceChange}
					placeholder="Enter ERP reference number"
					disabled={isSubmitting}
					class="erp-input"
					required
				/>

				<!-- PR Excel -->
				<div class="req-row" style="margin-top: 0.5rem;">
					<span class="req-label required">PR Excel File</span>
					<input
						type="checkbox"
						bind:checked={formData.has_pr_excel_file}
						disabled
						class="requirement-checkbox"
					/>
				</div>
				{#if !prExcelFile}
					<div class="upload-section">
						<input id="pr-excel-upload" type="file" accept=".xls,.xlsx" on:change={handlePRExcelUpload} disabled={isSubmitting} class="file-input" required />
						<label for="pr-excel-upload" class="upload-btn">Choose Excel File</label>
					</div>
				{:else}
					<div class="file-preview">
						<div class="file-info">
							<span class="file-name">{prExcelFile.name}</span>
						</div>
						{#if !prExcelFile.alreadyUploaded}
							<button class="remove-file" on:click={removePRExcelFile} disabled={isSubmitting}>✕</button>
						{/if}
					</div>
				{/if}

				<!-- Original Bill -->
				<div class="req-row" style="margin-top: 0.5rem;">
					<span class="req-label required">Original Bill</span>
					<input
						type="checkbox"
						bind:checked={formData.has_original_bill}
						disabled
						class="requirement-checkbox"
					/>
				</div>
				{#if !originalBillFile}
					<div class="upload-section">
						<input id="original-bill-upload" type="file" accept=".pdf,.jpg,.jpeg,.png" on:change={handleOriginalBillUpload} disabled={isSubmitting} class="file-input" required />
						<label for="original-bill-upload" class="upload-btn">Choose Bill File</label>
					</div>
				{:else}
					<div class="file-preview">
						<div class="file-info">
							<span class="file-name">{originalBillFile.name}</span>
						</div>
						{#if !originalBillFile.alreadyUploaded}
							<button class="remove-file" on:click={removeOriginalBillFile} disabled={isSubmitting}>✕</button>
						{/if}
					</div>
				{/if}

				<!-- Notes -->
				<textarea
					bind:value={formData.completion_notes}
					placeholder="Additional notes (optional)"
					disabled={isSubmitting}
					class="notes-textarea"
					style="margin-top: 0.5rem;"
				></textarea>
			
			{:else if taskDetails?.role_type === 'purchase_manager'}
				<div class="req-row">
					<span class="req-label" class:status-ok={prExcelUploaded} class:status-fail={!prExcelUploaded}>
						{prExcelUploaded ? '✓' : '✗'} PR Excel uploaded
					</span>
				</div>
				<div class="req-row">
					<span class="req-label" class:status-ok={verificationCompleted} class:status-fail={!verificationCompleted}>
						{verificationCompleted ? '✓' : '✗'} PR Excel verified
					</span>
				</div>
				{#if prExcelUploaded && verificationCompleted}
					<div class="status-ready">Ready to complete</div>
				{/if}
			
			{:else if taskDetails?.role_type === 'shelf_stocker'}
				{#if requirePhotoUpload}
					<div class="req-row">
						<span class="req-label required">Photo Required</span>
					</div>
					{#if !photoPreview}
						<div class="upload-section">
							<input id="photo-upload" type="file" accept="image/*" on:change={handlePhotoUpload} disabled={isSubmitting} class="file-input" required />
							<label for="photo-upload" class="upload-btn">Take Photo</label>
						</div>
					{:else}
						<div class="photo-preview">
							<img src={photoPreview} alt="Completion" class="preview-image" />
							<button class="remove-photo" on:click={removePhoto} disabled={isSubmitting}>✕</button>
						</div>
					{/if}
				{/if}

			{:else if taskDetails?.role_type === 'branch_manager' || taskDetails?.role_type === 'night_supervisor'}
				{#if dependencyStatus}
					{#if canComplete}
						<div class="status-ready">All dependencies met — ready to complete</div>
					{:else}
						<div class="status-waiting">Waiting for: {blockingRoles.join(', ')}</div>
					{/if}
				{/if}

				{#if dependencyPhotos && Object.keys(dependencyPhotos).length > 0}
					<div class="photos-grid">
						{#each Object.entries(dependencyPhotos) as [roleType, photoUrl]}
							<div class="dep-photo" on:click={() => openPhotoViewer(photoUrl, roleType)}>
								<img src={photoUrl} alt="{roleType}" class="dep-photo-img" />
								<span class="dep-photo-label">{roleType === 'shelf_stocker' ? 'Shelf Stocker' : roleType}</span>
							</div>
						{/each}
					</div>
				{/if}

			{:else if taskDetails?.role_type === 'accountant'}
				{#if canComplete}
					<div class="status-ready">Original bill uploaded — ready to complete</div>
				{:else}
					<div class="status-waiting">Waiting: {blockingRoles.join(', ')}</div>
					{#if errorMessage}
						<div class="status-error-msg">{errorMessage}</div>
					{/if}
				{/if}

			{:else}
				<p class="minimal-note">Mark as completed when finished.</p>
			{/if}
		</div>

		<!-- Actions -->
		<div class="actions">
			<button class="cancel-btn" on:click={() => goto('/mobile-interface/tasks')} disabled={isSubmitting}>
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
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
		padding-bottom: 0.5rem;
	}

	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		text-align: center;
		min-height: 30vh;
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

	.task-info-section,
	.form-section {
		background: white;
		margin: 0.5rem 0.6rem;
		padding: 0.6rem 0.85rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.task-info-section h3,
	.form-section h3 {
		margin: 0 0 0.5rem 0;
		font-size: 0.88rem;
		font-weight: 600;
		color: #1F2937;
	}

	.info-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 0.4rem;
	}

	.info-item {
		display: flex;
		justify-content: space-between;
		padding: 0.45rem 0.6rem;
		background: #F9FAFB;
		border-radius: 6px;
		border: 1px solid #E5E7EB;
	}

	.info-item label {
		font-weight: 500;
		color: #374151;
		font-size: 0.8rem;
	}

	.info-item span {
		color: #1F2937;
		font-size: 0.8rem;
	}

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

	.requirement-checkbox {
		width: 20px;
		height: 20px;
		cursor: pointer;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		border: 2px solid #10B981;
		border-radius: 4px;
		background: white;
		position: relative;
		flex-shrink: 0;
	}

	.requirement-checkbox:checked {
		background: #10B981;
		border-color: #10B981;
	}

	/* Minimal requirement row */
	.req-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.25rem;
	}

	.req-label {
		font-weight: 500;
		font-size: 0.8rem;
		color: #374151;
	}

	.req-label.required {
		color: #DC2626;
	}

	.req-label.status-ok {
		color: #059669;
	}

	.req-label.status-fail {
		color: #DC2626;
	}

	.status-ready {
		padding: 0.35rem 0.6rem;
		background: #F0FDF4;
		color: #059669;
		border: 1px solid #BBF7D0;
		border-radius: 6px;
		font-size: 0.78rem;
		font-weight: 500;
		margin-top: 0.35rem;
	}

	.status-waiting {
		padding: 0.35rem 0.6rem;
		background: #FFFBEB;
		color: #D97706;
		border: 1px solid #FED7AA;
		border-radius: 6px;
		font-size: 0.78rem;
		font-weight: 500;
		margin-top: 0.35rem;
	}

	.status-error-msg {
		padding: 0.35rem 0.6rem;
		background: #FEF2F2;
		color: #DC2626;
		border: 1px solid #FECACA;
		border-radius: 6px;
		font-size: 0.72rem;
		margin-top: 0.25rem;
	}

	.minimal-note {
		margin: 0;
		font-size: 0.78rem;
		color: #6B7280;
	}

	.erp-input,
	.notes-textarea {
		width: 100%;
		padding: 0.45rem 0.55rem;
		border: 1.5px solid #D1D5DB;
		border-radius: 6px;
		font-size: 0.8rem;
		background: white;
		transition: border-color 0.2s;
		resize: vertical;
		min-height: 2.2rem;
	}

	.notes-textarea {
		min-height: 50px;
		font-family: inherit;
	}

	.erp-input:focus,
	.notes-textarea:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.upload-section {
		margin-top: 0.3rem;
	}

	.file-input {
		display: none;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.4rem 0.75rem;
		background: #3B82F6;
		color: white;
		border-radius: 6px;
		font-size: 0.78rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		border: none;
	}

	.upload-btn:hover {
		background: #2563EB;
	}

	.file-preview {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.35rem 0.5rem;
		background: white;
		border: 1.5px solid #10B981;
		border-radius: 6px;
		margin-top: 0.3rem;
	}

	.file-info {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		color: #059669;
	}

	.file-name {
		font-size: 0.78rem;
		font-weight: 500;
	}

	.remove-file {
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 22px;
		height: 22px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 0.7rem;
	}

	.photo-preview {
		position: relative;
		display: inline-block;
		margin-top: 0.3rem;
	}

	.preview-image {
		width: 100%;
		max-width: 160px;
		height: 110px;
		object-fit: cover;
		border-radius: 6px;
		border: 1px solid #E5E7EB;
	}

	.remove-photo {
		position: absolute;
		top: -6px;
		right: -6px;
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 22px;
		height: 22px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 0.7rem;
	}

	.photos-grid {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
		margin-top: 0.35rem;
	}

	.dep-photo {
		cursor: pointer;
		text-align: center;
	}

	.dep-photo-img {
		width: 100px;
		height: 70px;
		object-fit: cover;
		border-radius: 6px;
		border: 1px solid #E5E7EB;
	}

	.dep-photo-label {
		display: block;
		font-size: 0.68rem;
		color: #6B7280;
		margin-top: 0.15rem;
	}

	.actions {
		display: flex;
		gap: 0.6rem;
		padding: 0.6rem 0.85rem;
		background: white;
		border-top: 1px solid #E5E7EB;
		position: sticky;
		bottom: 0;
	}

	.cancel-btn,
	.complete-btn {
		flex: 1;
		padding: 0.6rem 0.85rem;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.82rem;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		min-height: 40px;
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
		border-radius: 6px;
		padding: 0.5rem 0.85rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		margin-top: 0.5rem;
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
			margin: 0.4rem 0.6rem;
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
			padding-bottom: max(0.6rem, env(safe-area-inset-bottom));
		}
	}

	/* Photo viewer styles */

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
		gap: 10px;
		padding: 0.75rem 0.85rem 0.5rem 0.85rem;
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
		font-size: 0.95rem;
		font-weight: 600;
		flex: 1;
	}

	.popup-body {
		padding: 0.5rem 0.85rem;
	}

	.popup-message {
		margin: 0;
		font-size: 0.8rem;
		line-height: 1.4;
		color: #6b7280;
	}

	.popup-actions {
		padding: 0.5rem 0.85rem 0.75rem 0.85rem;
		display: flex;
		gap: 0.75rem;
		justify-content: flex-end;
	}

	.popup-btn {
		padding: 0.4rem 1rem;
		border-radius: 6px;
		font-size: 0.8rem;
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

	/* Photo viewer modal */

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
