<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase, uploadToSupabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { locale, getTranslation } from '$lib/i18n';

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
	let isSubmitting = false;
	let showSuccessMessage = false;
	let successMessage = '';

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
	$: defaultBranchName = branches.find(b => b.id == defaultBranchId)?.[getBranchNameField()] || 
	                      branches.find(b => b.id == defaultBranchId)?.name || 
	                      '';

	// Helper function to get the correct name field based on locale
	function getBranchNameField() {
		return $locale === 'ar' ? 'name_ar' : 'name_en';
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
		
		// If no branch is selected, show the branch selector
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
				.select('id, name_en, name_ar')
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
			} else if (error && error.code === 'PGRST116') {
				// Table doesn't exist yet, ignore the error
				console.log('Quick task preferences table not found, using defaults');
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
			const { data: userData, error } = await supabase
				.from('users')
				.select(`
					id,
					username,
					employee_id,
					hr_employees(
						id, 
						name,
						employee_id
					)
				`)
				.eq('branch_id', branchId)
				.eq('status', 'active')
				.order('username');

			if (error) {
				console.error('Error loading users:', error);
				// Fallback query without positions if the join fails
				const { data: fallbackData, error: fallbackError } = await supabase
					.from('users')
					.select(`
						id,
						username,
						employee_id,
						hr_employees(id, name, employee_id)
					`)
					.eq('branch_id', branchId)
					.eq('status', 'active')
					.order('username');

				if (!fallbackError) {
					users = fallbackData || [];
				}
			} else {
				users = userData || [];
			}

			// Load position information separately to avoid complex nested queries
			await loadUserPositions();

			// If we have default user IDs and no users selected yet, use defaults
			if (defaultUserIds.length > 0 && selectedUsers.length === 0) {
				selectedUsers = [...defaultUserIds.filter(id => users.some(u => u.id === id))];
			}
		} catch (error) {
			console.error('Error loading branch users:', error);
		}
	}

	// Load position information for current users
	async function loadUserPositions() {
		if (!users || users.length === 0) return;

		try {
			const employeeIds = users.map(user => user.hr_employees?.id).filter(Boolean);
			
			if (employeeIds.length === 0) return;

			const { data: positionData, error } = await supabase
				.from('hr_position_assignments')
				.select(`
					employee_id,
					hr_positions!inner(
						id,
						position_title_en,
						position_title_ar
					)
				`)
				.in('employee_id', employeeIds)
				.eq('is_current', true);

			if (!error && positionData) {
				// Merge position data with users
				users = users.map(user => {
					const position = positionData.find(p => p.employee_id === user.hr_employees?.id);
					return {
						...user,
						position_info: position?.hr_positions || null
					};
				});
			}
		} catch (error) {
			console.error('Error loading position data:', error);
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
				.upsert(defaultsData, { onConflict: 'user_id' });

			if (error) {
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
			alert('Please fill in all required fields and select at least one user.');
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
				.single();

			if (taskError) {
				console.error('Error creating task:', taskError);
				alert('Error creating task. Please try again.');
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
							
							// Save file record to quick_task_files table
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
								});

							if (fileError) {
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

			const { error: assignmentError } = await supabase
				.from('quick_task_assignments')
				.insert(assignments);

			if (assignmentError) {
				console.error('Error creating assignments:', assignmentError);
				alert('Error assigning task to users. Please try again.');
				return;
			}

			// Success - show message and reset form
			const fileText = uploadedFiles.length > 0 ? ` ${uploadedFiles.length} file(s) uploaded.` : '';
			successMessage = getTranslation('mobile.quickTaskContent.success.taskCreated') + fileText;
			showSuccessMessage = true;
			
			// Reset form but keep defaults
			resetForm();
			
			// Hide success message after 5 seconds
			setTimeout(() => {
				showSuccessMessage = false;
			}, 5000);

		} catch (error) {
			console.error('Error assigning task:', error);
			alert('Error assigning task. Please try again.');
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
				alert(`File type not supported: ${file.name}`);
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

<div class="quick-task-page">
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

		<!-- Step 1: Branch Selection -->
		<div class="form-section">
			<h3>{getTranslation('mobile.quickTaskContent.step1.title')}</h3>
			
			{#if selectedBranch && !showBranchSelector}
				<div class="current-selection">
					<div class="selection-info">
						<span class="label">{getTranslation('mobile.quickTaskContent.step1.branchLabel')}</span>
						<span class="value">{selectedBranchName}</span>
						{#if isUsingDefaultBranch}
							<span class="default-badge">{getTranslation('mobile.quickTaskContent.step1.defaultBadge')}</span>
						{/if}
					</div>
					<button type="button" on:click={showBranchSelection} class="change-btn">
						{getTranslation('mobile.quickTaskContent.step1.change')}
					</button>
				</div>
			{:else}
				<select bind:value={selectedBranch} on:change={handleBranchChange} class="form-select">
					<option value="">{getTranslation('mobile.quickTaskContent.step1.selectBranch')}</option>
					{#each branches as branch}
						<option value={branch.id}>{branch[getBranchNameField()]}</option>
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
				<h3>{getTranslation('mobile.quickTaskContent.step2.title')}</h3>
				
				{#if selectedUsers.length > 0 && !showUserSelector}
					<div class="current-selection">
						<div class="selection-info">
							<span class="label">{getTranslation('mobile.quickTaskContent.step2.usersLabel')}</span>
							<span class="value">{selectedUsers.length} {getTranslation('mobile.quickTaskContent.step2.selected')}</span>
							{#if isUsingDefaultUsers}
								<span class="default-badge">{getTranslation('mobile.quickTaskContent.step1.defaultBadge')}</span>
							{/if}
						</div>
						<button type="button" on:click={showUserSelection} class="change-btn">
							{getTranslation('mobile.quickTaskContent.step2.change')}
						</button>
					</div>
					<div class="selected-users-preview">
						{#each selectedUsers.slice(0, 3) as userId}
							{@const user = users.find(u => u.id === userId)}
							{#if user}
								<span class="user-chip">
									{getUserDisplayName(user)}
								</span>
							{/if}
						{/each}
						{#if selectedUsers.length > 3}
							<span class="user-chip more">+{selectedUsers.length - 3} {getTranslation('mobile.quickTaskContent.step2.more')}</span>
						{/if}
					</div>
				{:else}
					{#if users.length > 0}
						<input 
							type="text" 
							placeholder={getTranslation('mobile.quickTaskContent.step2.searchPlaceholder')}
							bind:value={searchTerm}
							class="search-input"
						/>
						<div class="user-list">
							{#each filteredUsers as user}
								<label class="user-item">
									<input 
										type="checkbox" 
										checked={selectedUsers.includes(user.id)}
										on:change={() => toggleUserSelection(user.id)}
									/>
									<div class="user-info">
										<span class="user-name">{getUserDisplayName(user)}</span>
										<span class="user-details">{user.username}</span>
										{#if user.position_info && getPositionTitle(user.position_info)}
											<span class="user-position">{getPositionTitle(user.position_info)}</span>
										{/if}
									</div>
								</label>
							{/each}
						</div>
						{#if selectedUsers.length > 0}
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={setAsDefaultUsers} />
								{getTranslation('mobile.quickTaskContent.step2.setAsDefault')}
							</label>
							<button type="button" on:click={hideUserSelection} class="confirm-btn">
								{getTranslation('mobile.quickTaskContent.step2.confirmUsers')}
							</button>
						{/if}
					{:else}
						<p class="no-users">No users found for this branch</p>
					{/if}
				{/if}
			</div>

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
		padding: 1rem;
		max-width: 600px;
		margin: 0 auto;
		background: #F8FAFC;
		min-height: 100vh;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
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

	/* Success Message Styles */
	.success-message {
		background: linear-gradient(135deg, #4caf50, #45a049);
		color: white;
		margin: 1rem 0;
		padding: 1rem;
		border-radius: 8px;
		box-shadow: 0 2px 8px rgba(76, 175, 80, 0.3);
		position: relative;
		animation: slideIn 0.3s ease-out;
	}

	.success-content {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.success-content svg {
		flex-shrink: 0;
		color: white;
	}

	.success-content p {
		margin: 0;
		font-weight: 500;
		font-size: 0.95rem;
		line-height: 1.4;
	}

	.close-success {
		position: absolute;
		top: 0.5rem;
		right: 0.5rem;
		background: rgba(255, 255, 255, 0.2);
		border: none;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.close-success:hover {
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
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 1rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
	}

	.form-section h3 {
		margin: 0 0 1rem 0;
		font-size: 1.1rem;
		font-weight: 600;
		color: #333;
	}

	.current-selection {
		background: #f8f9fa;
		border-radius: 8px;
		padding: 1rem;
		margin-bottom: 1rem;
	}

	.selection-info {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 8px;
	}

	.selection-info .label {
		font-weight: 500;
		color: #666;
	}

	.selection-info .value {
		font-weight: 600;
		color: #333;
	}

	.default-badge {
		background: #e7f3ff;
		color: #0066cc;
		font-size: 0.75rem;
		padding: 2px 8px;
		border-radius: 12px;
		font-weight: 500;
	}

	.change-btn, .confirm-btn {
		background: #007bff;
		color: white;
		border: none;
		padding: 8px 16px;
		border-radius: 6px;
		font-size: 0.9rem;
		cursor: pointer;
		font-weight: 500;
	}

	.change-btn:hover, .confirm-btn:hover {
		background: #0056b3;
	}

	.form-select, .form-input, .form-textarea {
		width: 100%;
		padding: 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 1rem;
		margin-bottom: 12px;
		box-sizing: border-box;
	}

	/* RTL Support for select dropdown arrow */
	:global([dir="rtl"]) .form-select {
		padding-right: 12px;
		padding-left: 40px;
		background-position: left 12px center;
	}

	.form-select:focus, .form-input:focus, .form-textarea:focus {
		outline: none;
		border-color: #007bff;
		box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 6px;
		font-weight: 500;
		color: #333;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
		cursor: pointer;
		font-size: 1rem;
		padding: 12px;
		background: #f8f9fa;
		border-radius: 8px;
		border: 2px solid transparent;
		transition: all 0.2s ease;
	}

	.checkbox-label:hover {
		background: #e9ecef;
		border-color: #007bff;
	}

	.checkbox-label input[type="checkbox"] {
		width: 20px;
		height: 20px;
		margin: 0;
		cursor: pointer;
		transform: scale(1.2);
		accent-color: #007bff;
		border: 2px solid #007bff;
		border-radius: 4px;
		background: white;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		position: relative;
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
		font-size: 14px;
		font-weight: bold;
	}

	.search-input {
		width: 100%;
		padding: 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		margin-bottom: 12px;
		font-size: 1rem;
		box-sizing: border-box;
	}

	.user-list {
		max-height: 250px;
		overflow-y: auto;
		border: 1px solid #ddd;
		border-radius: 6px;
		margin-bottom: 12px;
	}

	.user-item {
		display: flex;
		align-items: center;
		gap: 16px;
		padding: 16px;
		border-bottom: 1px solid #eee;
		cursor: pointer;
		transition: background 0.2s ease;
	}

	.user-item:hover {
		background: #f0f8ff;
	}

	.user-item:last-child {
		border-bottom: none;
	}

	.user-item input[type="checkbox"] {
		width: 20px;
		height: 20px;
		margin: 0;
		cursor: pointer;
		transform: scale(1.3);
		accent-color: #007bff;
		border: 2px solid #007bff;
		border-radius: 4px;
		background: white;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		position: relative;
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
		font-size: 14px;
		font-weight: bold;
	}

	.user-info {
		flex: 1;
	}

	.user-name {
		display: block;
		font-weight: 500;
		color: #333;
	}

	.user-details, .user-position {
		display: block;
		font-size: 0.85rem;
		color: #666;
	}

	.selected-users-preview {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
		margin-top: 8px;
	}

	.user-chip {
		background: #e7f3ff;
		color: #0066cc;
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 0.8rem;
		font-weight: 500;
	}

	.user-chip.more {
		background: #f0f0f0;
		color: #666;
	}

	.file-actions {
		display: flex;
		gap: 12px;
		margin-bottom: 1rem;
	}

	.file-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px;
		background: #f8f9fa;
		border: 1px solid #ddd;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.9rem;
		font-weight: 500;
		color: #333;
	}

	.file-btn:hover {
		background: #e9ecef;
	}

	.camera-btn {
		background: #28a745;
		color: white;
		border-color: #28a745;
	}

	.camera-btn:hover {
		background: #218838;
	}

	.file-list {
		border: 1px solid #ddd;
		border-radius: 6px;
		max-height: 150px;
		overflow-y: auto;
	}

	.file-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px;
		border-bottom: 1px solid #eee;
	}

	.file-item:last-child {
		border-bottom: none;
	}

	.file-info {
		flex: 1;
	}

	.file-name {
		display: block;
		font-weight: 500;
		color: #333;
	}

	.file-size {
		display: block;
		font-size: 0.85rem;
		color: #666;
	}

	.remove-file-btn {
		background: none;
		border: none;
		color: #dc3545;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
	}

	.remove-file-btn:hover {
		background: #f8f9fa;
	}

	.requirements-list {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.assign-btn {
		width: 100%;
		background: #28a745;
		color: white;
		border: none;
		padding: 16px;
		border-radius: 8px;
		font-size: 1.1rem;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
	}

	.assign-btn:hover:not(:disabled) {
		background: #218838;
	}

	.assign-btn:disabled {
		background: #6c757d;
		cursor: not-allowed;
	}

	.btn-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.no-users {
		color: #666;
		font-style: italic;
		text-align: center;
		padding: 2rem;
	}
</style>