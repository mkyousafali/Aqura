<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase, uploadToSupabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { locale, getTranslation, currentLocale } from '$lib/i18n';
	import { notifications } from '$lib/stores/notifications';

	// State management
	let loading = true;
	let branches = [];
	let selectedBranch = null;
	let defaultBranchId = null;
	let setAsDefaultBranch = false;
	let users = [];
	let selectedUsers = [];
	let defaultUserIds = [];
	let searchTerm = '';
	let setAsDefaultUsers = false;
	let showBranchSelector = false;
	let showUserSelector = false;
	let showUserPopup = false;
	let isSubmitting = false;
	let showSuccessMessage = false;
	let successMessage = '';
	let showSuccessPopup = false;
	let successTaskData = null;

	// Form data
	let taskTitle = ''; // Auto-generated from issue type
	let issueTypeWithPrice = ''; // Combined selection (issue + price)
	let issueType = ''; // Extracted issue type
	let customIssueType = ''; // Custom issue type for "Other"
	let priceTag = 'medium'; // Extracted or default price tag
	let priority = 'medium'; // Default priority
	let taskDescription = '';
	let selectedFiles = [];
	let setAsDefaultSettings = false;
	let fileInput; // Reference to hidden file input
	let cameraInput; // Reference to camera input

	// Quick Task Completion Requirements
	let requirePhotoUpload = false;
	let requireErpReference = false;
	let requireFileUpload = false;

	// Reactive Options with Translation Support
	$: issueTypeOptions = [
		{ value: 'price-tag', label: getTranslation('mobile.quickTaskContent.issueTypes.priceTag'), issueType: 'price-tag', priceTag: 'medium' },
		{ value: 'cleaning', label: getTranslation('mobile.quickTaskContent.issueTypes.cleaning'), issueType: 'cleaning', priceTag: 'medium' },
		{ value: 'display', label: getTranslation('mobile.quickTaskContent.issueTypes.display'), issueType: 'display', priceTag: 'medium' },
		{ value: 'filling', label: getTranslation('mobile.quickTaskContent.issueTypes.filling'), issueType: 'filling', priceTag: 'medium' },
		{ value: 'maintenance', label: getTranslation('mobile.quickTaskContent.issueTypes.maintenance'), issueType: 'maintenance', priceTag: 'medium' },
		{ value: 'other', label: getTranslation('mobile.quickTaskContent.issueTypes.other'), issueType: 'other', priceTag: 'medium' }
	];

	$: priorityOptions = [
		{ value: 'low', label: getTranslation('mobile.quickTaskContent.priorities.low') },
		{ value: 'medium', label: getTranslation('mobile.quickTaskContent.priorities.medium') },
		{ value: 'high', label: getTranslation('mobile.quickTaskContent.priorities.high') },
		{ value: 'urgent', label: getTranslation('mobile.quickTaskContent.priorities.urgent') }
	];

	$: priceTagOptions = [
		{ value: 'low', label: getTranslation('mobile.quickTaskContent.priceTags.low') },
		{ value: 'medium', label: getTranslation('mobile.quickTaskContent.priceTags.medium') },
		{ value: 'high', label: getTranslation('mobile.quickTaskContent.priceTags.high') },
		{ value: 'critical', label: getTranslation('mobile.quickTaskContent.priceTags.critical') }
	];

	// Extract issueType and priceTag from combined selection
	$: if (issueTypeWithPrice) {
		const selectedOption = issueTypeOptions.find(option => option.value === issueTypeWithPrice);
		if (selectedOption) {
			issueType = selectedOption.issueType;
			priceTag = selectedOption.priceTag;
		}
	}

	// Task title is automatically set from issue type or custom input
	// But allow manual override after form reset
	$: {
		if (issueType === 'other') {
			taskTitle = customIssueType;
		} else if (issueType && issueType !== '') {
			// For predefined types, use the selected label as title
			const selectedOption = issueTypeOptions.find(option => option.issueType === issueType);
			taskTitle = selectedOption ? selectedOption.label : '';
		}
		// Don't automatically clear taskTitle when issueType is empty
		// This allows users to manually type a title after form reset
	}

	// Filtered users for search
	$: filteredUsers = users.filter(user => {
		if (!searchTerm) return true;
		const term = searchTerm.toLowerCase();
		const positionNameEn = user.position_info?.position_title_en || '';
		const positionNameAr = user.position_info?.position_title_ar || '';
		return (
			user.username?.toLowerCase().includes(term) ||
			user.name_en?.toLowerCase().includes(term) ||
			user.name_ar?.toLowerCase().includes(term) ||
			user.hr_employees?.name?.toLowerCase().includes(term) ||
			user.employee_id?.toLowerCase().includes(term) ||
			positionNameEn.toLowerCase().includes(term) ||
			positionNameAr.toLowerCase().includes(term)
		);
	});

	// Get branch name by ID - handle both string and number IDs
	$: selectedBranchName = branches.find(b => b.id == selectedBranch)?.[getBranchNameField()] || 
	                       branches.find(b => b.id == selectedBranch)?.name || 
	                       'Unknown Branch';
	$: selectedBranchLocation = branches.find(b => b.id == selectedBranch)?.[getBranchLocationField()] || '';
	$: defaultBranchName = branches.find(b => b.id == defaultBranchId)?.[getBranchNameField()] || 
	                      branches.find(b => b.id == defaultBranchId)?.name || 
	                      '';

	// Helper function to get the correct name field based on locale
	function getBranchNameField() {
		return $locale === 'ar' ? 'name_ar' : 'name_en';
	}

	function getBranchLocationField() {
		return $locale === 'ar' ? 'location_ar' : 'location_en';
	}

	// Helper function to get user display name
	function getUserDisplayName(user) {
		if (!user) return '';
		
		// Priority: hr_employees name > username
		const displayName = user.hr_employees?.name || user.username || `User ${user.id}`;
		
		return displayName;
	}

	// Helper function to get the correct position title based on locale
	function getPositionTitle(positionInfo) {
		if (!positionInfo) return '';
		
		const currentLocale = $locale;
		
		// Temporary mapping for Arabic position titles until database query is fixed
		const positionMapping = {
			'Marketing Manager': 'مدير التسويق',
			'Inventory Control Supervisor': 'مشرف مراقبة المخزون',
			'Analytics & Business Intelligence': 'تحليلات وذكاء الأعمال',
			'Shelf Stockers': 'مرص البضائع',
			'Vegetable Department Head': 'رئيس قسم الخضروات',
			'Quality Assurance Manager': 'مدير ضمان الجودة',
			'Cleaners': 'منظف',
			'Cheese Department Head': 'رئيس قسم الجبن',
			'CEO': 'الرئيس التنفيذي',
			'Accountant': 'محاسب',
			'Customer Service Supervisor': 'مشرف خدمة العملاء',
			'Finance Manager': 'مدير مالي',
			'Driver': 'سائق',
			'Branch Manager': 'مدير الفرع',
			'Inventory Manager': 'مدير المخزون',
			'Night Supervisors': 'مشرف ليلي',
			'Bakers': 'خباز',
			'Bakery Department Head': 'رئيس قسم المخبز',
			'Checkout Helpers': 'مساعد الدفع',
			'Vegetable Counter Staff': 'موظف عداد الخضروات',
			'Cheese Counter Staff': 'موظف عداد الجبن',
			'No Position': 'بدون منصب'
		};
		
		// If we're in Arabic locale, try mapping first, then fallback to Arabic field
		if (currentLocale === 'ar') {
			// Try mapping from English to Arabic
			const englishTitle = positionInfo.position_title_en || positionInfo.position_title;
			if (englishTitle && positionMapping[englishTitle]) {
				return positionMapping[englishTitle];
			}
			
			// Fallback to database Arabic field if available
			if (positionInfo.position_title_ar) {
				return positionInfo.position_title_ar;
			}
		}
		
		// Fallback to English or original position title
		return positionInfo.position_title_en || positionInfo.position_title || '';
	}

	// Check if current selection matches defaults - use loose equality for type flexibility
	$: isUsingDefaultBranch = selectedBranch == defaultBranchId;
	$: isUsingDefaultUsers = defaultUserIds.length > 0 && 
		selectedUsers.length === defaultUserIds.length && 
		selectedUsers.every(id => defaultUserIds.includes(id));

	onMount(async () => {
		await loadInitialData();
		await loadUserPreferences();
		
		// If no branch is selected, auto-select logged-in user's branch
		if (!selectedBranch && $currentUser?.branch_id) {
			const userBranchId = parseInt($currentUser.branch_id);
			if (branches.find(b => b.id === userBranchId)) {
				selectedBranch = userBranchId;
				await loadBranchUsers(selectedBranch);
			}
		}
		
		// If still no branch is selected, show the branch selector
		if (!selectedBranch) {
			showBranchSelector = true;
		}
		
		loading = false;
	});

	async function loadInitialData() {
		try {
			// Load branches
			const { data: branchData, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.order('name_en');

			if (!branchError) {
				branches = branchData || [];
			}
		} catch (error) {
			console.error('Error loading initial data:', error);
		}
	}

	async function loadUserPreferences() {
		try {
			const { data: preferences, error } = await supabase
				.from('quick_task_user_preferences')
				.select('*')
				.eq('user_id', $currentUser?.id)
				.single();

			if (!error && preferences) {
				defaultBranchId = preferences.default_branch_id;
				if (preferences.default_branch_id) {
					selectedBranch = preferences.default_branch_id;
					await loadBranchUsers(selectedBranch);
				}
				priceTag = preferences.default_price_tag || 'medium';
				issueType = preferences.default_issue_type || '';
				priority = preferences.default_priority || 'medium';
				
				if (preferences.selected_user_ids) {
					defaultUserIds = preferences.selected_user_ids;
					if (users.length > 0) {
						selectedUsers = [...preferences.selected_user_ids];
					}
				}
			} else if (error && (error.code === 'PGRST116' || error.code === '406' || error.status === 406)) {
				// Table doesn't exist or not accessible (PGRST116 = no rows, 406 = Not Acceptable)
				console.log('Quick task preferences table not found, using defaults');
			} else if (error) {
				console.warn('Unexpected error loading preferences:', error);
			}
		} catch (error) {
			console.error('Error loading user preferences:', error);
		}
	}

	async function loadBranchUsers(branchId) {
		if (!branchId) {
			users = [];
			return;
		}

		try {
			const { data: employeeData, error } = await supabase
				.from('hr_employee_master')
				.select(`
					id,
					user_id,
					name_en,
					name_ar,
					current_position_id,
					hr_positions(
						id,
						position_title_en,
						position_title_ar
					)
				`)
				.eq('current_branch_id', branchId)
				.in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job'])
				.neq('user_id', 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b');

			if (error) {
				console.error('Error loading employees:', error);
				users = [];
				return;
			}

			// Map hr_employee_master data to the user format expected by the UI
			const isAr = $locale === 'ar';
			users = (employeeData || []).map(emp => ({
				id: emp.user_id,
				username: emp.name_en || emp.name_ar || '',
				employee_id: emp.id,
				name_en: emp.name_en || '',
				name_ar: emp.name_ar || '',
				hr_employees: {
					id: emp.id,
					name: isAr ? (emp.name_ar || emp.name_en || '') : (emp.name_en || emp.name_ar || '')
				},
				position_info: emp.hr_positions || null
			}));

			// If we have default user IDs and no users selected yet, use defaults
			if (defaultUserIds.length > 0 && selectedUsers.length === 0) {
				selectedUsers = [...defaultUserIds.filter(id => users.some(u => u.id === id))];
			}
		} catch (error) {
			console.error('Error loading branch users:', error);
		}
	}

	async function handleBranchChange(event) {
		selectedBranch = parseInt(event.target.value) || event.target.value;
		selectedUsers = []; // Clear user selection when branch changes
		if (selectedBranch) {
			await loadBranchUsers(selectedBranch);
			showBranchSelector = false;
		} else {
			users = [];
		}
	}

	function showBranchSelection() {
		showBranchSelector = true;
	}

	function hideBranchSelection() {
		if (selectedBranch) {
			showBranchSelector = false;
		}
	}

	function showUserSelection() {
		showUserSelector = true;
	}

	function hideUserSelection() {
		showUserSelector = false;
	}

	function toggleUserSelection(userId) {
		if (selectedUsers.includes(userId)) {
			selectedUsers = selectedUsers.filter(id => id !== userId);
		} else {
			selectedUsers = [...selectedUsers, userId];
		}
	}

	function useDefaultUsers() {
		selectedUsers = [...defaultUserIds.filter(id => users.some(u => u.id === id))];
	}

	async function saveAsDefaults() {
		if (!setAsDefaultBranch && !setAsDefaultUsers && !setAsDefaultSettings) return;

		try {
			const defaultsData = {
				user_id: $currentUser?.id,
				...(setAsDefaultBranch && { default_branch_id: selectedBranch }),
				...(setAsDefaultUsers && { selected_user_ids: selectedUsers }),
				...(setAsDefaultSettings && {
					default_price_tag: priceTag,
			default_issue_type: issueType,
			default_priority: priority
		})
	};

	const { error } = await supabase
		.from('quick_task_user_preferences')
		.upsert(defaultsData, { onConflict: 'user_id' });			if (error) {
				console.error('Error saving defaults:', error);
			} else {
				console.log('Defaults saved successfully');
			}
		} catch (error) {
			console.error('Error saving defaults:', error);
		}
	}

	async function assignTask() {
		if (!taskTitle || !selectedBranch || selectedUsers.length === 0 || !issueType || !priority) {
			notifications.add({ type: 'error', message: 'Please fill in all required fields and select at least one user.' });
			return;
		}

		isSubmitting = true;

		try {
		// Save defaults if requested
		await saveAsDefaults();

		// Create the quick task
		const { data: taskData, error: taskError } = await supabase
			.from('quick_tasks')
			.insert({
				title: taskTitle,
				description: taskDescription,
				price_tag: priceTag,
				issue_type: issueType,
				priority: priority,
				assigned_by: $currentUser?.id,
				assigned_to_branch_id: selectedBranch,
				require_task_finished: true, // Always required
				require_photo_upload: requirePhotoUpload,
				require_erp_reference: requireErpReference
			})
			.select()
			.single();			if (taskError) {
				console.error('Error creating task:', taskError);
				notifications.add({ type: 'error', message: 'Error creating task. Please try again.' });
				return;
			}

			console.log('📋 [QuickTask] Task created successfully:', taskData);

			// Upload files if any are selected
			let uploadedFiles = [];
			if (selectedFiles.length > 0) {
				console.log('📎 [QuickTask] Uploading', selectedFiles.length, 'files...');
				
				for (const selectedFile of selectedFiles) {
					try {
						// Generate unique filename
						const timestamp = Date.now();
						const randomString = Math.random().toString(36).substring(2, 15);
						const fileExtension = selectedFile.name.split('.').pop();
						const uniqueFileName = `quick-task-${timestamp}-${randomString}.${fileExtension}`;
						
						// Upload to Supabase storage
						console.log('⬆️ [QuickTask] Uploading file:', selectedFile.name);
						const uploadResult = await uploadToSupabase(selectedFile.file, 'quick-task-files', uniqueFileName);
						
					
					if (!uploadResult.error) {
						console.log('✅ [QuickTask] File uploaded successfully:', uploadResult.data);
						
						// Save file record to quick_task_files table (use admin client to bypass RLS)
						const { error: fileError } = await supabase
							.from('quick_task_files')
							.insert({
								quick_task_id: taskData.id,
								file_name: selectedFile.name,
								storage_path: uploadResult.data.path,
								file_type: selectedFile.type,
								file_size: selectedFile.size,
								mime_type: selectedFile.type,
								storage_bucket: 'quick-task-files',
								uploaded_by: $currentUser?.id,
								uploaded_at: new Date().toISOString()
							});							if (fileError) {
								console.error('❌ [QuickTask] Error saving file record:', fileError);
							} else {
								uploadedFiles.push({
									name: selectedFile.name,
									storage_path: uploadResult.data.path,
									size: selectedFile.size,
									type: selectedFile.type
								});
								console.log('✅ [QuickTask] File record saved successfully');
							}
						} else {
							console.error('❌ [QuickTask] File upload failed:', uploadResult.error);
						}
					} catch (uploadError) {
						console.error('❌ [QuickTask] Error uploading file:', uploadError);
					}
				}
				
				console.log('📎 [QuickTask] File upload complete. Uploaded files:', uploadedFiles.length);
			}

			// Create assignments for selected users with completion requirements
			const assignments = selectedUsers.map(userId => ({
				quick_task_id: taskData.id,
				assigned_to_user_id: userId,
				require_task_finished: true, // Always required
				require_photo_upload: requirePhotoUpload,
				require_erp_reference: requireErpReference
			}));

			// Store completion requirements in a separate record or in task metadata
			console.log('📋 [QuickTask] Completion Requirements:', {
				requirePhotoUpload,
				requireErpReference, 
				requireFileUpload
			});
			
		console.log('📋 [QuickTask Mobile] Assignment Objects to Insert:', assignments);

		const { data: insertedAssignments, error: assignmentError } = await supabase
			.from('quick_task_assignments')
			.insert(assignments)
			.select();			if (assignmentError) {
				console.error('Error creating assignments:', assignmentError);
				notifications.add({ type: 'error', message: 'Error assigning task to users. Please try again.' });
				return;
			}
			
			console.log('✅ [QuickTask Mobile] Assignments created:', insertedAssignments);
			console.log('🔍 [QuickTask Mobile] First assignment details:', JSON.stringify(insertedAssignments[0], null, 2));

			if (assignmentError) {
				console.error('Error creating assignments:', assignmentError);
				notifications.add({ type: 'error', message: 'Error assigning task to users. Please try again.' });
				return;
			}

			// Success - show message and reset form
			const fileText = uploadedFiles.length > 0 ? ` ${uploadedFiles.length} file(s) uploaded.` : '';
			successMessage = getTranslation('mobile.quickTaskContent.success.taskCreated') + fileText;
			
			// Show success popup with task details
			successTaskData = {
				id: taskData.id,
				title: taskData.title || taskTitle,
				assignedUsers: selectedUsers.length,
				filesUploaded: uploadedFiles.length,
				branch: selectedBranchName
			};
			showSuccessPopup = true;
			
			// Also show banner message
			showSuccessMessage = true;
			
			// Reset form but keep defaults
			resetForm();
			
			// Hide banner message after 5 seconds
			setTimeout(() => {
				showSuccessMessage = false;
			}, 5000);

		} catch (error) {
			console.error('Error assigning task:', error);
			notifications.add({ type: 'error', message: 'Error assigning task. Please try again.' });
		} finally {
			isSubmitting = false;
		}
	}

	function resetForm() {
		// Clear form data
		taskTitle = '';
		taskDescription = '';
		customIssueType = '';
		selectedFiles = [];
		
		// Reset issue type selection if not saving defaults
		// Set a reasonable default to keep the form functional
		if (!setAsDefaultSettings) {
			issueTypeWithPrice = 'filling'; // Default to filling issue
			issueType = 'filling';
			priority = 'medium';
		}
		
		// Keep selected users - they should stay selected after assignment
		// Only reset user selection if user explicitly unchecks "set as default users"
		// selectedUsers array is preserved to maintain user selection
		
		// Reset branch selection if not saving defaults  
		if (!setAsDefaultBranch) {
			showBranchSelector = false;
		}
		
		// Reset completion requirements
		requirePhotoUpload = false;
		requireErpReference = false;
		requireFileUpload = false;
		
		// Reset UI state
		searchTerm = '';
		
		// Keep the checkbox states for saving defaults
		// setAsDefaultBranch, setAsDefaultUsers, setAsDefaultSettings remain as they are
	}

	function closeSuccessPopup() {
		showSuccessPopup = false;
		successTaskData = null;
	}

	// File Upload Functions
	function openFileBrowser() {
		fileInput.click();
	}

	function handleFileSelect(event) {
		const files = Array.from(event.target.files);
		files.forEach(file => {
			if (isValidFileType(file)) {
				selectedFiles = [...selectedFiles, {
					file,
					name: file.name,
					size: file.size,
					type: file.type,
					id: Date.now() + Math.random()
				}];
			} else {
				notifications.add({ type: 'error', message: `File type not supported: ${file.name}` });
			}
		});
		// Reset file input so same file can be selected again
		event.target.value = '';
	}

	function removeFile(fileId) {
		selectedFiles = selectedFiles.filter(f => f.id !== fileId);
	}

	function isValidFileType(file) {
		const allowedTypes = [
			'image/jpeg', 'image/png', 'image/gif', 'image/webp',
			'application/pdf',
			'application/vnd.ms-excel',
			'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
			'application/msword',
			'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
			'text/plain', 'text/csv'
		];
		return allowedTypes.includes(file.type);
	}

	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
	}

	// Camera Functions
	function openCamera() {
		cameraInput.click();
	}

	function handleCameraCapture(event) {
		const files = Array.from(event.target.files);
		files.forEach(file => {
			if (isValidFileType(file)) {
				selectedFiles = [...selectedFiles, {
					file,
					name: file.name,
					size: file.size,
					type: file.type,
					id: Date.now() + Math.random()
				}];
			}
		});
		// Reset input
		event.target.value = '';
	}
</script>

<svelte:head>
	<title>{getTranslation('mobile.quickTaskContent.title')}</title>
</svelte:head>

<div class="quick-task-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>{getTranslation('mobile.quickTaskContent.loading')}</p>
		</div>
	{:else}
		<!-- Success Message -->
		{#if showSuccessMessage}
			<div class="success-message">
				<div class="success-content">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
						<polyline points="22,4 12,14.01 9,11.01"></polyline>
					</svg>
					<p>{successMessage}</p>
				</div>
				<button class="close-success" on:click={() => showSuccessMessage = false}>
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"></line>
						<line x1="6" y1="6" x2="18" y2="18"></line>
					</svg>
				</button>
			</div>
		{/if}

		<!-- Success Popup Modal -->
		{#if showSuccessPopup && successTaskData}
			<div class="popup-overlay" on:click={closeSuccessPopup}>
				<div class="popup-modal" on:click|stopPropagation>
					<div class="popup-header">
						<div class="success-icon">
							<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
								<polyline points="22,4 12,14.01 9,11.01"></polyline>
							</svg>
						</div>
						<h2>✅ {getTranslation('mobile.quickTaskContent.success.taskCreated')}</h2>
					</div>
					
					<div class="popup-content">
						<div class="task-detail">
							<span class="detail-label">📋 {getTranslation('mobile.quickTaskContent.issueTypeLabel')}</span>
							<span class="detail-value">{successTaskData.title}</span>
						</div>
						
						<div class="task-detail">
							<span class="detail-label">🏢 {getTranslation('mobile.quickTaskContent.step1.branchLabel')}</span>
							<span class="detail-value">{successTaskData.branch}</span>
						</div>
						
						<div class="task-detail">
							<span class="detail-label">👥 {getTranslation('mobile.quickTaskContent.step2.usersLabel')}</span>
							<span class="detail-value">{successTaskData.assignedUsers} {getTranslation('mobile.quickTaskContent.step2.selected')}</span>
						</div>
						
						{#if successTaskData.filesUploaded > 0}
							<div class="task-detail">
								<span class="detail-label">📎 {getTranslation('mobile.quickTaskContent.filesLabel')}</span>
								<span class="detail-value">{successTaskData.filesUploaded} file(s)</span>
							</div>
						{/if}
					</div>
					
					<div class="popup-actions">
						<button class="popup-btn primary" on:click={closeSuccessPopup}>
							{getTranslation('mobile.quickTaskContent.success.gotIt')}
						</button>
					</div>
				</div>
			</div>
		{/if}

		<!-- Step 1: Branch Selection -->
		<div class="form-section">
			<h3>{getTranslation('mobile.quickTaskContent.step1.title')}</h3>
			
			{#if selectedBranch && !showBranchSelector}
				<div class="current-selection inline-row">
					<div class="branch-name-block">
						<span class="value">{selectedBranchName}</span>
						{#if selectedBranchLocation}
							<span class="location-text">{selectedBranchLocation}</span>
						{/if}
					</div>
					{#if isUsingDefaultBranch}
						<span class="default-badge">{getTranslation('mobile.quickTaskContent.step1.defaultBadge')}</span>
					{/if}
					<button type="button" on:click={showBranchSelection} class="change-btn">
						{getTranslation('mobile.quickTaskContent.step1.change')}
					</button>
				</div>
			{:else}
				<select bind:value={selectedBranch} on:change={handleBranchChange} class="form-select">
					<option value="">{getTranslation('mobile.quickTaskContent.step1.selectBranch')}</option>
					{#each branches as branch}
						<option value={branch.id}>{branch[getBranchNameField()]} — {branch[getBranchLocationField()]}</option>
					{/each}
				</select>
				{#if selectedBranch}
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={setAsDefaultBranch} />
						{getTranslation('mobile.quickTaskContent.step1.setAsDefault')}
					</label>
					<button type="button" on:click={hideBranchSelection} class="confirm-btn">
						{getTranslation('mobile.quickTaskContent.step1.confirm')}
					</button>
				{/if}
			{/if}
		</div>

		{#if selectedBranch && !showBranchSelector}
			<!-- Step 2: User Selection -->
			<div class="form-section">
				<div class="section-header-row">
					<h3>{getTranslation('mobile.quickTaskContent.step2.title')}</h3>
					<button type="button" class="select-users-btn" on:click={() => { showUserPopup = true; searchTerm = ''; }}>
						{#if selectedUsers.length > 0}
							<span>{selectedUsers.length} {getTranslation('mobile.quickTaskContent.step2.selected')}</span>
						{:else}
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
							<span>{getTranslation('mobile.quickTaskContent.step2.usersLabel')}</span>
						{/if}
					</button>
				</div>
				{#if selectedUsers.length > 0}
					<div class="selected-users-preview">
						{#each selectedUsers as userId}
							{@const user = users.find(u => u.id === userId)}
							{#if user}
								<span class="user-chip">
									{getUserDisplayName(user)}
									<button type="button" class="chip-remove" on:click={() => toggleUserSelection(user.id)}>&times;</button>
								</span>
							{/if}
						{/each}
					</div>
				{/if}
			</div>

			<!-- User Selection Popup -->
			{#if showUserPopup}
				<div class="user-popup-overlay" on:click={() => showUserPopup = false} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && (showUserPopup = false)}>
					<div class="user-popup" on:click|stopPropagation role="none">
						<div class="user-popup-header">
							<span>{getTranslation('mobile.quickTaskContent.step2.title')}</span>
							<button type="button" class="user-popup-close" on:click={() => showUserPopup = false}>&times;</button>
						</div>
						<div class="user-popup-search">
							<input 
								type="text" 
								placeholder={getTranslation('mobile.quickTaskContent.step2.searchPlaceholder')}
								bind:value={searchTerm}
								class="search-input"
							/>
						</div>
						<div class="user-popup-list">
							{#if users.length > 0}
								{#each filteredUsers as user}
									<label class="user-item">
										<input 
											type="checkbox" 
											checked={selectedUsers.includes(user.id)}
											on:change={() => toggleUserSelection(user.id)}
										/>
										<span class="user-name">{getUserDisplayName(user)}</span>
									</label>
								{/each}
							{:else}
								<p class="no-users">No users found for this branch</p>
							{/if}
						</div>
						<div class="user-popup-footer">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={setAsDefaultUsers} />
								{getTranslation('mobile.quickTaskContent.step2.setAsDefault')}
							</label>
							<button type="button" class="confirm-btn" on:click={() => showUserPopup = false}>
								{getTranslation('mobile.quickTaskContent.step2.confirmUsers')} ({selectedUsers.length})
							</button>
						</div>
					</div>
				</div>
			{/if}

			<!-- Step 3: Task Details -->
			<div class="form-section">
				<h3>{getTranslation('mobile.quickTaskContent.step3.title')}</h3>
				
				<div class="form-group">
					<label>{getTranslation('mobile.quickTaskContent.step3.issueType')}</label>
					<select bind:value={issueTypeWithPrice} class="form-select">
						<option value="">{getTranslation('mobile.quickTaskContent.step3.selectIssueType')}</option>
						{#each issueTypeOptions as option}
							<option value={option.value}>{option.label}</option>
						{/each}
					</select>
				</div>

				{#if issueType === 'other'}
					<div class="form-group">
						<label>{getTranslation('mobile.quickTaskContent.step3.customIssueType')}</label>
						<input 
							type="text" 
							bind:value={customIssueType}
							placeholder={getTranslation('mobile.quickTaskContent.step3.customIssuePlaceholder')}
							class="form-input"
						/>
					</div>
				{/if}

				<div class="form-group">
					<label>{getTranslation('mobile.quickTaskContent.step3.priority')}</label>
					<select bind:value={priority} class="form-select">
						{#each priorityOptions as option}
							<option value={option.value}>{option.label}</option>
						{/each}
					</select>
				</div>

				<div class="form-group">
					<label>{getTranslation('mobile.quickTaskContent.step3.description')}</label>
					<textarea 
						bind:value={taskDescription}
						placeholder={getTranslation('mobile.quickTaskContent.step3.descriptionPlaceholder')}
						class="form-textarea"
						rows="3"
					></textarea>
				</div>

				<label class="checkbox-label">
					<input type="checkbox" bind:checked={setAsDefaultSettings} />
					{getTranslation('mobile.quickTaskContent.step3.saveAsDefault')}
				</label>
			</div>

			<!-- Step 4: File Attachments -->
			<div class="form-section">
				<h3>{getTranslation('mobile.quickTaskContent.step4.title')}</h3>
				
				<div class="file-actions">
					<button type="button" on:click={openFileBrowser} class="file-btn">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
							<polyline points="14,2 14,8 20,8"></polyline>
							<line x1="16" y1="13" x2="8" y2="13"></line>
							<line x1="16" y1="17" x2="8" y2="17"></line>
							<polyline points="10,9 9,9 8,9"></polyline>
						</svg>
						{getTranslation('mobile.quickTaskContent.step4.chooseFiles')}
					</button>
					<button type="button" on:click={openCamera} class="file-btn camera-btn">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path>
							<circle cx="12" cy="13" r="4"></circle>
						</svg>
						{getTranslation('mobile.quickTaskContent.step4.camera')}
					</button>
				</div>

				{#if selectedFiles.length > 0}
					<div class="file-list">
						{#each selectedFiles as file}
							<div class="file-item">
								<div class="file-info">
									<span class="file-name">{file.name}</span>
									<span class="file-size">{formatFileSize(file.size)}</span>
								</div>
								<button type="button" on:click={() => removeFile(file.id)} class="remove-file-btn">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<line x1="18" y1="6" x2="6" y2="18"></line>
										<line x1="6" y1="6" x2="18" y2="18"></line>
									</svg>
									<span class="sr-only">{getTranslation('mobile.quickTaskContent.step4.removeFile')}</span>
								</button>
							</div>
						{/each}
					</div>
				{/if}
			</div>

			<!-- Step 5: Completion Requirements -->
			<div class="form-section">
				<h3>{getTranslation('mobile.quickTaskContent.step5.title')}</h3>
				<div class="requirements-list">
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={requirePhotoUpload} />
						{getTranslation('mobile.quickTaskContent.step5.requirePhoto')}
					</label>
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={requireErpReference} />
						{getTranslation('mobile.quickTaskContent.step5.requireErp')}
					</label>
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={requireFileUpload} />
						{getTranslation('mobile.quickTaskContent.step5.requireFile')}
					</label>
				</div>
			</div>

			<!-- Submit Button -->
			<div class="form-section">
				<button 
					type="button" 
					on:click={assignTask} 
					class="assign-btn"
					disabled={isSubmitting || !taskTitle || !selectedBranch || selectedUsers.length === 0 || !issueType || !priority}
				>
					{#if isSubmitting}
						<div class="btn-spinner"></div>
						{getTranslation('mobile.quickTaskContent.actions.creatingTask')}
					{:else}
						{getTranslation('mobile.quickTaskContent.actions.assignTask')}
					{/if}
				</button>
			</div>
		{/if}
	{/if}
</div>

<!-- Hidden file inputs -->
<input 
	type="file" 
	bind:this={fileInput}
	on:change={handleFileSelect}
	accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.txt,.csv"
	multiple
	style="display: none;"
/>
<input 
	type="file" 
	bind:this={cameraInput}
	on:change={handleCameraCapture}
	accept="image/*"
	capture="environment"
	style="display: none;"
/>

<style>
	.quick-task-page {
		padding: 0;
		padding-bottom: 0.5rem;
		min-height: 100%;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 1.5rem;
		color: #666;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #f3f3f3;
		border-top: 3px solid #007bff;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Section header with inline button */
	.section-header-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.4rem;
		margin-bottom: 0.3rem;
	}

	.section-header-row h3 {
		margin: 0 !important;
	}

	.select-users-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.3rem 0.65rem;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.88rem;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
	}

	.select-users-btn:active {
		background: #0056b3;
	}

	.chip-remove {
		background: none;
		border: none;
		color: #0066cc;
		font-size: 0.85rem;
		cursor: pointer;
		padding: 0;
		margin-left: 0.15rem;
		line-height: 1;
		font-weight: 700;
	}

	.chip-remove:active {
		color: #EF4444;
	}

	/* User Selection Popup */
	.user-popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.75rem;
	}

	.user-popup {
		background: white;
		border-radius: 12px;
		width: 100%;
		max-width: 360px;
		max-height: 65vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		margin-bottom: 4rem;
	}

	.user-popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.65rem 0.85rem;
		border-bottom: 1px solid #E5E7EB;
		font-weight: 700;
		font-size: 0.9rem;
		color: #111827;
		flex-shrink: 0;
	}

	.user-popup-close {
		background: none;
		border: none;
		font-size: 1.3rem;
		cursor: pointer;
		color: #6B7280;
		line-height: 1;
		padding: 0 0.2rem;
	}

	.user-popup-search {
		padding: 0.5rem 0.75rem;
		border-bottom: 1px solid #F3F4F6;
		flex-shrink: 0;
	}

	.user-popup-search .search-input {
		margin-bottom: 0;
	}

	.user-popup-list {
		flex: 1;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		min-height: 0;
	}

	.user-popup-footer {
		padding: 0.5rem 0.75rem;
		border-top: 1px solid #E5E7EB;
		flex-shrink: 0;
	}

	.user-popup-footer .checkbox-label {
		margin-bottom: 0.3rem;
	}

	.user-popup-footer .confirm-btn {
		width: 100%;
	}

	/* Success Message Styles */
	.success-message {
		background: linear-gradient(135deg, #10B981, #059669);
		color: white;
		margin: 0.35rem 0.5rem;
		padding: 0.5rem 0.65rem;
		border-radius: 6px;
		box-shadow: 0 1px 4px rgba(16, 185, 129, 0.3);
		position: relative;
		animation: slideIn 0.3s ease-out;
	}

	.success-content {
		display: flex;
		align-items: center;
		gap: 0.35rem;
	}

	.success-content svg {
		flex-shrink: 0;
		color: white;
	}

	.success-content p {
		margin: 0;
		font-weight: 600;
		font-size: 0.9rem;
		line-height: 1.3;
	}

	.close-success {
		position: absolute;
		top: 0.25rem;
		right: 0.25rem;
		background: rgba(255, 255, 255, 0.2);
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background-color 0.15s;
	}

	.close-success:active {
		background: rgba(255, 255, 255, 0.3);
	}

	.close-success svg {
		color: white;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.form-section {
		background: white;
		border-radius: 8px;
		padding: 0.65rem 0.75rem;
		margin: 0 0.5rem 0.5rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
	}

	.form-section h3 {
		margin: 0 0 0.5rem 0;
		font-size: 0.95rem;
		font-weight: 700;
		color: #374151;
	}

	.current-selection {
		background: #f8f9fa;
		border-radius: 6px;
		padding: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.current-selection.inline-row {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		flex-wrap: nowrap;
	}

	.branch-name-block {
		display: flex;
		flex-direction: column;
		gap: 0.1rem;
	}

	.branch-name-block .location-text {
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	.default-badge {
		background: #e7f3ff;
		color: #0066cc;
		font-size: 0.75rem;
		padding: 1px 6px;
		border-radius: 10px;
		font-weight: 500;
	}

	.change-btn, .confirm-btn {
		background: #007bff;
		color: white;
		border: none;
		padding: 0.35rem 0.75rem;
		border-radius: 6px;
		font-size: 0.9rem;
		cursor: pointer;
		font-weight: 600;
		margin-left: auto;
		white-space: nowrap;
		flex-shrink: 0;
	}

	.change-btn:active, .confirm-btn:active {
		background: #0056b3;
	}

	.form-select, .form-input, .form-textarea {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 0.375rem;
		font-size: 0.9rem;
		margin-bottom: 0.5rem;
		box-sizing: border-box;
		height: 2rem;
	}

	.form-textarea {
		height: auto;
	}

	/* RTL Support for select dropdown arrow */
	:global([dir="rtl"]) .form-select {
		padding-right: 0.5rem;
		padding-left: 1.5rem;
		background-position: left 0.5rem center;
	}

	.form-select:focus, .form-input:focus, .form-textarea:focus {
		outline: none;
		border-color: #007bff;
		box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
	}

	.form-group {
		margin-bottom: 0.6rem;
	}

	.form-group:last-child {
		margin-bottom: 0;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.15rem;
		font-weight: 600;
		color: #374151;
		font-size: 0.88rem;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		margin-bottom: 0.4rem;
		cursor: pointer;
		font-size: 0.9rem;
		padding: 0.35rem 0.5rem;
		background: #f8f9fa;
		border-radius: 6px;
		border: 1px solid transparent;
		transition: all 0.15s ease;
	}

	.checkbox-label:active {
		background: #e9ecef;
		border-color: #007bff;
	}

	.checkbox-label input[type="checkbox"] {
		width: 16px;
		height: 16px;
		margin: 0;
		cursor: pointer;
		accent-color: #007bff;
		border: 2px solid #007bff;
		border-radius: 3px;
		background: white;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		position: relative;
		flex-shrink: 0;
	}

	.checkbox-label input[type="checkbox"]:checked {
		background: #007bff;
		border-color: #007bff;
	}

	.checkbox-label input[type="checkbox"]:checked::after {
		content: '✓';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		color: white;
		font-size: 11px;
		font-weight: bold;
	}

	.search-input {
		width: 100%;
		padding: 0.35rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 0.375rem;
		margin-bottom: 0.4rem;
		font-size: 0.9rem;
		box-sizing: border-box;
		height: 2rem;
	}

	.user-item {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.4rem 0.5rem;
		border-bottom: 1px solid #F3F4F6;
		cursor: pointer;
		transition: background 0.15s ease;
	}

	.user-item:active {
		background: #f0f8ff;
	}

	.user-item:last-child {
		border-bottom: none;
	}

	.user-item input[type="checkbox"] {
		width: 16px;
		height: 16px;
		margin: 0;
		cursor: pointer;
		accent-color: #007bff;
		border: 2px solid #007bff;
		border-radius: 3px;
		background: white;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		position: relative;
		flex-shrink: 0;
	}

	.user-item input[type="checkbox"]:checked {
		background: #007bff;
		border-color: #007bff;
	}

	.user-item input[type="checkbox"]:checked::after {
		content: '✓';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		color: white;
		font-size: 11px;
		font-weight: bold;
	}

	.user-info {
		flex: 1;
	}

	.user-name {
		display: block;
		font-weight: 600;
		color: #111827;
		font-size: 0.9rem;
	}

	.user-details, .user-position {
		display: block;
		font-size: 0.8rem;
		color: #6B7280;
	}

	.selected-users-preview {
		display: flex;
		gap: 0.3rem;
		flex-wrap: wrap;
		margin-top: 0.25rem;
	}

	.user-chip {
		background: #e7f3ff;
		color: #0066cc;
		padding: 2px 6px;
		border-radius: 10px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.file-actions {
		display: flex;
		gap: 0.4rem;
		margin-bottom: 0.5rem;
	}

	.file-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.4rem 0.65rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 600;
		color: #374151;
	}

	.file-btn:active {
		background: #E5E7EB;
	}

	.camera-btn {
		background: #10B981;
		color: white;
		border-color: #10B981;
	}

	.camera-btn:active {
		background: #059669;
	}

	.file-list {
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		max-height: 100px;
		overflow-y: auto;
	}

	.file-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.35rem 0.5rem;
		border-bottom: 1px solid #F3F4F6;
	}

	.file-item:last-child {
		border-bottom: none;
	}

	.file-info {
		flex: 1;
	}

	.file-name {
		display: block;
		font-weight: 600;
		color: #111827;
		font-size: 0.88rem;
	}

	.file-size {
		display: block;
		font-size: 0.8rem;
		color: #6B7280;
	}

	.remove-file-btn {
		background: none;
		border: none;
		color: #EF4444;
		cursor: pointer;
		padding: 0.1rem 0.2rem;
		border-radius: 4px;
	}

	.remove-file-btn:active {
		background: #FEE2E2;
	}

	.requirements-list {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.assign-btn {
		width: 100%;
		background: #10B981;
		color: white;
		border: none;
		padding: 0.55rem;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.35rem;
		box-shadow: 0 2px 8px rgba(16, 185, 129, 0.3);
	}

	.assign-btn:active:not(:disabled) {
		background: #059669;
	}

	.assign-btn:disabled {
		background: #9CA3AF;
		cursor: not-allowed;
		box-shadow: none;
	}

	.btn-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	.no-users {
		color: #6B7280;
		font-style: italic;
		text-align: center;
		padding: 0.75rem;
		font-size: 0.9rem;
	}

	/* Success Popup Modal */
	.popup-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		backdrop-filter: blur(4px);
		animation: fadeIn 0.3s ease-out;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.popup-modal {
		background: white;
		border-radius: 12px;
		max-width: 360px;
		width: 100%;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
		animation: slideUp 0.3s ease-out;
		overflow: hidden;
	}

	@keyframes slideUp {
		from {
			transform: translateY(50px);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}

	.popup-header {
		text-align: center;
		padding: 1rem 0.85rem 0.65rem;
		background: linear-gradient(135deg, #10B981 0%, #059669 100%);
		color: white;
	}

	.success-icon {
		margin-bottom: 0.5rem;
	}

	.success-icon svg {
		width: 64px;
		height: 64px;
		stroke: white;
		animation: checkmark 0.5s ease-out 0.2s;
		animation-fill-mode: both;
	}

	@keyframes checkmark {
		0% {
			transform: scale(0) rotate(-45deg);
		}
		50% {
			transform: scale(1.2) rotate(5deg);
		}
		100% {
			transform: scale(1) rotate(0deg);
		}
	}

	.popup-header h2 {
		margin: 0;
		font-size: 0.95rem;
		font-weight: 700;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
	}

	.popup-content {
		padding: 0.75rem 0.85rem;
	}

	.task-detail {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: 0.4rem 0.5rem;
		background: #f8f9fa;
		border-radius: 6px;
		margin-bottom: 0.4rem;
	}

	.task-detail:last-child {
		margin-bottom: 0;
	}

	.detail-label {
		font-size: 0.7rem;
		color: #6B7280;
		font-weight: 600;
	}

	.detail-value {
		font-size: 0.8rem;
		color: #111827;
		font-weight: 600;
	}

	.popup-actions {
		padding: 0.65rem 0.85rem;
		background: #f8f9fa;
		border-top: 1px solid #E5E7EB;
	}

	.popup-btn {
		width: 100%;
		padding: 0.5rem;
		border: none;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}

	.popup-btn.primary {
		background: #10B981;
		color: white;
	}

	.popup-btn.primary:active {
		background: #059669;
	}
</style>
