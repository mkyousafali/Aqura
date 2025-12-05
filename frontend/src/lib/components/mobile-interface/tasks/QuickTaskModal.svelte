<script lang="ts">
	import { onMount, createEventDispatcher } from 'svelte';
	import { supabase, supabaseAdmin, uploadToSupabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	const dispatch = createEventDispatcher();

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
	let showCameraModal = false; // Camera modal visibility
	let cameraStream = null; // Camera stream reference

	// Quick Task Completion Requirements
	let requirePhotoUpload = false;
	let requireErpReference = false;
	let requireFileUpload = false;

	// Modal state
	export let isOpen = false;

	// Options - Issue Types with Price Tag Issue as first option
	const issueTypeOptions = [
		{ value: 'price-tag', label: 'Price Tag Issue', issueType: 'price-tag', priceTag: 'medium' },
		{ value: 'cleaning', label: 'Cleaning Issue', issueType: 'cleaning', priceTag: 'medium' },
		{ value: 'display', label: 'Display Issue', issueType: 'display', priceTag: 'medium' },
		{ value: 'filling', label: 'Filling Issue', issueType: 'filling', priceTag: 'medium' },
		{ value: 'maintenance', label: 'Maintenance Issue', issueType: 'maintenance', priceTag: 'medium' },
		{ value: 'other', label: 'Other Issue', issueType: 'other', priceTag: 'medium' }
	];

	const priorityOptions = [
		{ value: 'low', label: 'Low' },
		{ value: 'medium', label: 'Medium' },
		{ value: 'high', label: 'High' },
		{ value: 'urgent', label: 'Urgent' }
	];

	const priceTagOptions = [
		{ value: 'low', label: 'Low' },
		{ value: 'medium', label: 'Medium' },
		{ value: 'high', label: 'High' },
		{ value: 'critical', label: 'Critical' }
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
	$: {
		if (issueType === 'other') {
			taskTitle = customIssueType;
		} else if (issueType) {
			// For predefined types, use the selected label as title
			const selectedOption = issueTypeOptions.find(option => option.issueType === issueType);
			taskTitle = selectedOption ? selectedOption.label : '';
		} else {
			taskTitle = '';
		}
	}

	// Filtered users for search
	$: filteredUsers = users.filter(user => {
		if (!searchTerm) return true;
		const term = searchTerm.toLowerCase();
		const positionName = user.position_info?.position_title_en || '';
		return (
			user.username?.toLowerCase().includes(term) ||
			user.hr_employees?.name?.toLowerCase().includes(term) ||
			user.employee_id?.toLowerCase().includes(term) ||
			positionName.toLowerCase().includes(term)
		);
	});

	// Get branch name by ID - handle both string and number IDs
	$: selectedBranchName = branches.find(b => b.id == selectedBranch)?.name_en || 
	                       branches.find(b => b.id == selectedBranch)?.name || 
	                       'Unknown Branch';
	$: defaultBranchName = branches.find(b => b.id == defaultBranchId)?.name_en || 
	                      branches.find(b => b.id == defaultBranchId)?.name || 
	                      '';

	// Check if current selection matches defaults - use loose equality for type flexibility
	$: isUsingDefaultBranch = selectedBranch == defaultBranchId;
	$: isUsingDefaultUsers = defaultUserIds.length > 0 && 
		selectedUsers.length === defaultUserIds.length && 
		selectedUsers.every(id => defaultUserIds.includes(id));

	onMount(async () => {
		if (isOpen) {
			await loadInitialData();
			await loadUserPreferences();
			
			// If no branch is selected, show the branch selector
			if (!selectedBranch) {
				showBranchSelector = true;
			}
			
			loading = false;
		}
	});

	$: if (isOpen && loading) {
		console.log('🎯 Modal opening, loading data...');
		loadInitialData().then(() => loadUserPreferences()).then(() => {
			if (!selectedBranch) {
				showBranchSelector = true;
			}
			loading = false;
			console.log('🎯 Modal data loaded, loading set to false');
		});
	}

	$: {
		console.log('🎯 Modal state - isOpen:', isOpen, 'loading:', loading);
	}

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
			const { data: preferences, error } = await supabaseAdmin
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
			const { data: userData, error } = await supabase
				.from('users')
				.select(`
					id,
					username,
					employee_id,
					hr_employees!inner(
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

	const { error } = await supabaseAdmin
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
			alert('Please fill in all required fields and select at least one user.');
			return;
		}

		try {
		// Save defaults if requested
		await saveAsDefaults();

		// Create the quick task with completion requirements (use admin client to bypass RLS)
		const { data: taskData, error: taskError } = await supabaseAdmin
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
						
						// Save file record to quick_task_files table (use admin client to bypass RLS)
						const { error: fileError } = await supabaseAdmin
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

		// Log completion requirements being saved
		console.log('📋 [QuickTask] Completion Requirements being saved:', {
			requirePhotoUpload,
			requireErpReference, 
			requireFileUpload,
			assignments: assignments.length
		});

		const { error: assignmentError } = await supabaseAdmin
			.from('quick_task_assignments')
			.insert(assignments);			if (assignmentError) {
				console.error('Error creating assignments:', assignmentError);
				alert('Error assigning task to users. Please try again.');
				return;
			}

			// Success notification
			alert(`Task assigned successfully! ${uploadedFiles.length > 0 ? `${uploadedFiles.length} file(s) uploaded.` : ''}`);
			
			// Reset form and close modal
			resetForm();
			closeModal();

		} catch (error) {
			console.error('Error assigning task:', error);
			alert('Error assigning task. Please try again.');
		}
	}

	function resetForm() {
		taskTitle = '';
		taskDescription = '';
		if (!setAsDefaultSettings) {
			priceTag = 'medium';
			issueType = '';
			issueTypeWithPrice = '';
			priority = 'medium';
		}
		if (!setAsDefaultUsers) {
			selectedUsers = [];
		}
		selectedFiles = [];
		setAsDefaultBranch = false;
		setAsDefaultUsers = false;
		setAsDefaultSettings = false;
		
		// Reset completion requirements
		requirePhotoUpload = false;
		requireErpReference = false;
		requireFileUpload = false;

		// Reset UI state
		showBranchSelector = false;
		showUserSelector = false;
		searchTerm = '';
		customIssueType = '';
	}

	function closeModal() {
		resetForm();
		dispatch('close');
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

{#if isOpen}
	<div class="modal-overlay" on:click={closeModal}>
		<div class="modal-content" on:click|stopPropagation>
			<div class="modal-header">
				<h2>Quick Task</h2>
				<button class="close-btn" on:click={closeModal}>
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"></line>
						<line x1="6" y1="6" x2="18" y2="18"></line>
					</svg>
				</button>
			</div>

			<div class="modal-body">
				{#if loading}
					<div class="loading">
						<div class="spinner"></div>
						<p>Loading...</p>
					</div>
				{:else}
					<!-- Step 1: Branch Selection -->
					<div class="form-section">
						<h3>1. Select Branch</h3>
						
						{#if selectedBranch && !showBranchSelector}
							<div class="current-selection">
								<div class="selection-info">
									<span class="label">Branch:</span>
									<span class="value">{selectedBranchName}</span>
									{#if isUsingDefaultBranch}
										<span class="default-badge">Default</span>
									{/if}
								</div>
								<button type="button" on:click={showBranchSelection} class="change-btn">
									Change
								</button>
							</div>
						{:else}
							<select bind:value={selectedBranch} on:change={handleBranchChange} class="form-select">
								<option value="">-- Select Branch --</option>
								{#each branches as branch}
									<option value={branch.id}>{branch.name_en}</option>
								{/each}
							</select>
							{#if selectedBranch}
								<label class="checkbox-label">
									<input type="checkbox" bind:checked={setAsDefaultBranch} />
									Set as default branch
								</label>
								<button type="button" on:click={hideBranchSelection} class="confirm-btn">
									✓ Confirm
								</button>
							{/if}
						{/if}
					</div>

					{#if selectedBranch && !showBranchSelector}
						<!-- Step 2: User Selection -->
						<div class="form-section">
							<h3>2. Select Users</h3>
							
							{#if selectedUsers.length > 0 && !showUserSelector}
								<div class="current-selection">
									<div class="selection-info">
										<span class="label">Users:</span>
										<span class="value">{selectedUsers.length} selected</span>
										{#if isUsingDefaultUsers}
											<span class="default-badge">Default</span>
										{/if}
									</div>
									<button type="button" on:click={showUserSelection} class="change-btn">
										Change
									</button>
								</div>
								<div class="selected-users-preview">
									{#each selectedUsers.slice(0, 3) as userId}
										{@const user = users.find(u => u.id === userId)}
										{#if user}
											<span class="user-chip">
												{user.hr_employees?.name || user.username}
											</span>
										{/if}
									{/each}
									{#if selectedUsers.length > 3}
										<span class="user-chip more">+{selectedUsers.length - 3} more</span>
									{/if}
								</div>
							{:else}
								{#if users.length > 0}
									<input 
										type="text" 
										placeholder="Search users..." 
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
													<span class="user-name">{user.hr_employees?.name || user.username}</span>
													<span class="user-details">{user.employee_id}</span>
													{#if user.position_info?.position_title_en}
														<span class="user-position">{user.position_info.position_title_en}</span>
													{/if}
												</div>
											</label>
										{/each}
									</div>
									{#if selectedUsers.length > 0}
										<label class="checkbox-label">
											<input type="checkbox" bind:checked={setAsDefaultUsers} />
											Save as default users
										</label>
										<button type="button" on:click={hideUserSelection} class="confirm-btn">
											✓ Confirm ({selectedUsers.length} users)
										</button>
									{/if}
								{:else}
									<p class="no-users">No users found for this branch</p>
								{/if}
							{/if}
						</div>

						<!-- Step 3: Task Details -->
						<div class="form-section">
							<h3>3. Task Details</h3>
							
							<div class="form-group">
								<label>Issue Type:</label>
								<select bind:value={issueTypeWithPrice} class="form-select">
									<option value="">-- Select Issue Type --</option>
									{#each issueTypeOptions as option}
										<option value={option.value}>{option.label}</option>
									{/each}
								</select>
							</div>

							{#if issueType === 'other'}
								<div class="form-group">
									<label>Custom Issue Type:</label>
									<input 
										type="text" 
										bind:value={customIssueType}
										placeholder="Enter custom issue type"
										class="form-input"
									/>
								</div>
							{/if}

							<div class="form-group">
								<label>Priority:</label>
								<select bind:value={priority} class="form-select">
									{#each priorityOptions as option}
										<option value={option.value}>{option.label}</option>
									{/each}
								</select>
							</div>

							<div class="form-group">
								<label>Price Tag:</label>
								<select bind:value={priceTag} class="form-select">
									{#each priceTagOptions as option}
										<option value={option.value}>{option.label}</option>
									{/each}
								</select>
							</div>

							<div class="form-group">
								<label>Description (Optional):</label>
								<textarea 
									bind:value={taskDescription}
									placeholder="Enter task description..."
									class="form-textarea"
									rows="3"
								></textarea>
							</div>

							<label class="checkbox-label">
								<input type="checkbox" bind:checked={setAsDefaultSettings} />
								Save these settings as default
							</label>
						</div>

						<!-- Step 4: File Attachments -->
						<div class="form-section">
							<h3>4. Attachments (Optional)</h3>
							
							<div class="file-actions">
								<button type="button" on:click={openFileBrowser} class="file-btn">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
										<polyline points="14,2 14,8 20,8"></polyline>
										<line x1="16" y1="13" x2="8" y2="13"></line>
										<line x1="16" y1="17" x2="8" y2="17"></line>
										<polyline points="10,9 9,9 8,9"></polyline>
									</svg>
									Choose Files
								</button>
								<button type="button" on:click={openCamera} class="file-btn camera-btn">
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path>
										<circle cx="12" cy="13" r="4"></circle>
									</svg>
									Camera
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
											</button>
										</div>
									{/each}
								</div>
							{/if}
						</div>

						<!-- Step 5: Completion Requirements -->
						<div class="form-section">
							<h3>5. Completion Requirements</h3>
							<div class="requirements-list">
								<label class="checkbox-label">
									<input type="checkbox" bind:checked={requirePhotoUpload} />
									Require photo upload on completion
								</label>
								<label class="checkbox-label">
									<input type="checkbox" bind:checked={requireErpReference} />
									Require ERP reference on completion
								</label>
								<label class="checkbox-label">
									<input type="checkbox" bind:checked={requireFileUpload} />
									Require file upload on completion
								</label>
							</div>
						</div>
					{/if}
				{/if}
			</div>

			<div class="modal-footer">
				<button type="button" on:click={closeModal} class="cancel-btn">
					Cancel
				</button>
				{#if !loading && selectedBranch && !showBranchSelector && selectedUsers.length > 0 && !showUserSelector && taskTitle}
					<button type="button" on:click={assignTask} class="assign-btn">
						Assign Task
					</button>
				{/if}
			</div>
		</div>
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
{/if}

<style>
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 10000;
		padding: 20px;
	}

	.modal-content {
		background: white;
		border-radius: 12px;
		width: 100%;
		max-width: 500px;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 20px;
		border-bottom: 1px solid #eee;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.5rem;
		font-weight: 600;
		color: #333;
	}

	.close-btn {
		background: none;
		border: none;
		padding: 8px;
		color: #666;
		cursor: pointer;
		border-radius: 6px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.close-btn:hover {
		background: #f5f5f5;
		color: #333;
	}

	.modal-body {
		flex: 1;
		overflow-y: auto;
		padding: 20px;
	}

	.modal-footer {
		padding: 20px;
		border-top: 1px solid #eee;
		display: flex;
		gap: 12px;
		justify-content: flex-end;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 40px;
		color: #666;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #f3f3f3;
		border-top: 3px solid #007bff;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.form-section {
		margin-bottom: 24px;
	}

	.form-section h3 {
		margin: 0 0 16px 0;
		font-size: 1.1rem;
		font-weight: 600;
		color: #333;
	}

	.current-selection {
		background: #f8f9fa;
		border-radius: 8px;
		padding: 16px;
		margin-bottom: 12px;
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
	}

	.form-select:focus, .form-input:focus, .form-textarea:focus {
		outline: none;
		border-color: #007bff;
		box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
	}

	.form-group {
		margin-bottom: 16px;
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
		gap: 8px;
		margin-bottom: 12px;
		cursor: pointer;
		font-size: 0.9rem;
	}

	.search-input {
		width: 100%;
		padding: 12px;
		border: 1px solid #ddd;
		border-radius: 6px;
		margin-bottom: 12px;
		font-size: 1rem;
	}

	.user-list {
		max-height: 200px;
		overflow-y: auto;
		border: 1px solid #ddd;
		border-radius: 6px;
		margin-bottom: 12px;
	}

	.user-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 12px;
		border-bottom: 1px solid #eee;
		cursor: pointer;
	}

	.user-item:hover {
		background: #f8f9fa;
	}

	.user-item:last-child {
		border-bottom: none;
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
		margin-bottom: 16px;
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

	.cancel-btn {
		background: #f8f9fa;
		color: #333;
		border: 1px solid #ddd;
		padding: 12px 20px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
	}

	.cancel-btn:hover {
		background: #e9ecef;
	}

	.assign-btn {
		background: #28a745;
		color: white;
		border: none;
		padding: 12px 20px;
		border-radius: 6px;
		cursor: pointer;
		font-weight: 500;
	}

	.assign-btn:hover {
		background: #218838;
	}

	.no-users {
		color: #666;
		font-style: italic;
		text-align: center;
		padding: 20px;
	}
</style>
