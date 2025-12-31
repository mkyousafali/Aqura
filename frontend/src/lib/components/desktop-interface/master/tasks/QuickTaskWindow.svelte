<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase, uploadToSupabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

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
	let cameraStream = null; // Camera stream reference
	let showCameraModal = false; // Camera modal visibility

	// Quick Task Completion Requirements
	let requirePhotoUpload = false;
	let requireErpReference = false;
	let requireFileUpload = false;

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
	$: {
		console.log('Branch update:', { 
			selectedBranch, 
			selectedBranchType: typeof selectedBranch,
			selectedBranchName, 
			branches: branches.length,
			branchData: branches.find(b => b.id == selectedBranch),
			allBranchIds: branches.map(b => ({ id: b.id, type: typeof b.id, name: b.name_en }))
		});
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
				priceTag = preferences.default_price_tag || '';
				issueType = preferences.default_issue_type || '';
				priority = preferences.default_priority || '';
				
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
		console.log('Branch changed to:', { 
			rawValue: event.target.value, 
			selectedBranch, 
			type: typeof selectedBranch 
		});
		if (selectedBranch) {
			await loadBranchUsers(selectedBranch);
			// Auto-hide the selector after selection
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

	function useDefaultUsers() {
		selectedUsers = [...defaultUserIds];
		showUserSelector = false;
	}

	function toggleUserSelection(userId) {
		if (selectedUsers.includes(userId)) {
			selectedUsers = selectedUsers.filter(id => id !== userId);
		} else {
			selectedUsers = [...selectedUsers, userId];
		}
	}

	function toggleAllUsers() {
		if (selectedUsers.length === filteredUsers.length) {
			selectedUsers = [];
		} else {
			selectedUsers = filteredUsers.map(user => user.id);
		}
	}

	async function saveAsDefaults() {
		if (!setAsDefaultBranch && !setAsDefaultUsers && !setAsDefaultSettings) {
			return;
		}

		try {
			const updates: {
				default_branch_id?: number;
				selected_user_ids?: string[];
				default_price_tag?: string;
				default_issue_type?: string;
				default_priority?: string;
				updated_at?: string;
			} = {};
			
			if (setAsDefaultBranch) {
				updates.default_branch_id = selectedBranch;
			}
			
			if (setAsDefaultUsers) {
				updates.selected_user_ids = selectedUsers;
			}
			
			if (setAsDefaultSettings) {
				updates.default_price_tag = priceTag;
				updates.default_issue_type = issueType;
				updates.default_priority = priority;
			}

		updates.updated_at = new Date().toISOString();

		// First, try to check if user preferences exist
		const { data: existingPrefs } = await supabase
			.from('quick_task_user_preferences')
			.select('user_id')
			.eq('user_id', $currentUser?.id)
			.single();

		let error;
		if (existingPrefs) {
			// Update existing preferences
			const updateResult = await supabase
				.from('quick_task_user_preferences')
				.update(updates)
				.eq('user_id', $currentUser?.id);
			error = updateResult.error;
		} else {
			// Insert new preferences
			const insertResult = await supabase
				.from('quick_task_user_preferences')
				.insert({
					user_id: $currentUser?.id,
					...updates
				});
			error = insertResult.error;
		}			if (error) {
				console.error('Error saving preferences:', error);
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

		// Create the quick task (use admin client to bypass RLS)
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
		
		console.log('📋 [QuickTask] Assignment Objects to Insert:', assignments);

		const { data: insertedAssignments, error: assignmentError } = await supabase
			.from('quick_task_assignments')
			.insert(assignments)
			.select();			if (assignmentError) {
				console.error('❌ Error creating assignments:', assignmentError);
				alert('Error assigning task to users. Please try again.');
				return;
			}
			
			console.log('✅ [QuickTask] Assignments created:', insertedAssignments);
			console.log('🔍 [QuickTask] First assignment details:', JSON.stringify(insertedAssignments[0], null, 2));

			// TODO: Send notifications
			console.log(`✅ Task assigned successfully! ${uploadedFiles.length > 0 ? `${uploadedFiles.length} file(s) uploaded.` : ''}`);
			
			// Don't reset form immediately so we can see the logs
			setTimeout(() => {
				alert(`Task assigned successfully! ${uploadedFiles.length > 0 ? `${uploadedFiles.length} file(s) uploaded.` : ''}`);
				resetForm();
			}, 100);

		} catch (error) {
			console.error('Error assigning task:', error);
			alert('Error assigning task. Please try again.');
		}
	}

	function resetForm() {
		taskTitle = '';
		taskDescription = '';
		if (!setAsDefaultSettings) {
			priceTag = '';
			issueType = '';
			priority = '';
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

	function handleDrop(event) {
		event.preventDefault();
		const files = Array.from(event.dataTransfer.files);
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
	}

	function handleDragOver(event) {
		event.preventDefault();
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
	async function openCamera() {
		try {
			showCameraModal = true;
			cameraStream = await navigator.mediaDevices.getUserMedia({ 
				video: { facingMode: 'environment' } // Use back camera if available
			});
			
			// Set video source after modal is shown
			setTimeout(() => {
				const video = document.getElementById('camera-video');
				if (video && cameraStream) {
					video.srcObject = cameraStream;
				}
			}, 100);
		} catch (error) {
			console.error('Error accessing camera:', error);
			alert('Unable to access camera. Please check permissions or use file upload instead.');
			showCameraModal = false;
		}
	}

	function closeCamera() {
		if (cameraStream) {
			cameraStream.getTracks().forEach(track => track.stop());
			cameraStream = null;
		}
		showCameraModal = false;
	}

	function capturePhoto() {
		const video = document.getElementById('camera-video');
		const canvas = document.getElementById('capture-canvas');
		
		if (video && canvas) {
			const ctx = canvas.getContext('2d');
			canvas.width = video.videoWidth;
			canvas.height = video.videoHeight;
			ctx.drawImage(video, 0, 0);
			
			canvas.toBlob(blob => {
				if (blob) {
					const file = new File([blob], `photo-${Date.now()}.jpg`, { type: 'image/jpeg' });
					selectedFiles = [...selectedFiles, {
						file,
						name: file.name,
						size: file.size,
						type: file.type,
						id: Date.now() + Math.random()
					}];
				}
				closeCamera();
			}, 'image/jpeg', 0.8);
		}
	}
</script>

<div class="quick-task-window">
	{#if loading}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>Loading Quick Task...</p>
		</div>
	{:else}
		<div class="window-header">
			<h2>Quick Task Assignment</h2>
			<p>Create and assign tasks quickly to users</p>
		</div>
		
		<div class="window-content">
			<!-- Step 1: Branch Selection -->
			<div class="form-section">
				<div class="section-header">
					<h3>1. Select Branch</h3>
				</div>
				
				{#if selectedBranch && !showBranchSelector}
					<div class="current-selection">
						<div class="selection-display selected-branch-card">
							<div class="selection-info">
								<div class="branch-display">
									<div class="branch-details">
										<span class="branch-label">Selected Branch:</span>
										<span class="branch-name">
											{#if selectedBranchName}
												{selectedBranchName}
											{:else if selectedBranch}
												Branch ID: {selectedBranch}
											{:else}
												No Branch Selected
											{/if}
										</span>
										{#if isUsingDefaultBranch}
											<span class="default-badge">✨ Default</span>
										{/if}
									</div>
								</div>
							</div>
							<button type="button" on:click={showBranchSelection} class="change-btn">
								📝 Change Branch
							</button>
						</div>
					</div>
				{:else}
					<div class="form-group">
						<label for="branch-select">Choose Branch:</label>
						<select id="branch-select" bind:value={selectedBranch} on:change={handleBranchChange}>
							<option value="">-- Select Branch --</option>
							{#each branches as branch}
								<option value={branch.id}>{branch.name_en}</option>
							{/each}
						</select>
					</div>
					{#if selectedBranch}
						<div class="branch-actions">
							<div class="checkbox-group">
								<label class="checkbox-label">
									<input type="checkbox" bind:checked={setAsDefaultBranch} />
									<span class="checkmark"></span>
									Set as default branch
								</label>
							</div>
							<button type="button" on:click={hideBranchSelection} class="confirm-btn">
								✓ Confirm Branch
							</button>
						</div>
					{/if}
				{/if}
			</div>

			{#if selectedBranch && !showBranchSelector}
				<!-- Step 2: User Selection -->
				<div class="form-section">
					<div class="section-header">
						<h3>2. Select Users</h3>
					</div>
					
					{#if selectedUsers.length > 0 && !showUserSelector}
						<div class="current-selection">
							<div class="selection-display">
								<div class="selection-info">
									<span class="label">Selected Users:</span>
									<span class="value">{selectedUsers.length} user(s) selected</span>
									{#if isUsingDefaultUsers}
										<span class="default-badge">Default Selection</span>
									{/if}
								</div>
								<div class="user-actions-compact">
									{#if defaultUserIds.length > 0 && !isUsingDefaultUsers}
										<button type="button" on:click={useDefaultUsers} class="default-btn">
											🔄 Use Default Users
										</button>
									{/if}
									<button type="button" on:click={showUserSelection} class="change-btn">
										📝 Change Users
									</button>
								</div>
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
						</div>
					{:else}
						{#if users.length > 0}
							<div class="user-selection-controls">
								<div class="user-actions">
									<input 
										type="text" 
										placeholder="Search by username, name, or employee ID..." 
										bind:value={searchTerm}
										class="search-input"
									/>
									<div class="button-group">
										{#if defaultUserIds.length > 0}
											<button type="button" on:click={useDefaultUsers} class="default-btn">
												🔄 Use Default Users
											</button>
										{/if}
										<button type="button" on:click={toggleAllUsers} class="toggle-all-btn">
											{selectedUsers.length === filteredUsers.length ? 'Deselect All' : 'Select All'}
										</button>
									</div>
								</div>
							</div>
							
							<div class="users-table-container">
								<table class="users-table">
									<thead>
										<tr>
											<th>Select</th>
											<th>Username</th>
											<th>Employee Name</th>
											<th>Position</th>
											<th>Employee ID</th>
										</tr>
									</thead>
									<tbody>
										{#each filteredUsers as user}
											<tr class:selected={selectedUsers.includes(user.id)}>
												<td>
													<input 
														type="checkbox" 
														checked={selectedUsers.includes(user.id)}
														on:change={() => toggleUserSelection(user.id)}
														style="width: 16px; height: 16px; cursor: pointer;"
													/>
												</td>
												<td>{user.username}</td>
												<td>{user.hr_employees?.name || 'N/A'}</td>
												<td>{user.position_info?.position_title_en || 'N/A'}</td>
												<td>{user.hr_employees?.employee_id || 'N/A'}</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
							
						{#if selectedUsers.length > 0 && !showUserSelector && !showBranchSelector}
								<div class="selection-summary">
									<span>{selectedUsers.length} user(s) selected</span>
									<div class="summary-actions">
										<label class="checkbox-label">
											<input type="checkbox" bind:checked={setAsDefaultUsers} />
											<span class="checkmark"></span>
											Set as default users
										</label>
										<button type="button" on:click={hideUserSelection} class="confirm-btn">
											✓ Confirm Selection
										</button>
									</div>
								</div>
							{/if}
						{:else}
							<p class="no-users">No users found in this branch.</p>
						{/if}
					{/if}
				</div>
			{/if}

			{#if selectedUsers.length > 0 && !showUserSelector && !showBranchSelector}
				<!-- Step 3: Task Details -->
				<div class="form-section">
						<div class="section-header">
							<h3>3. Task Details</h3>
						</div>
						
						<div class="form-row">
							<div class="form-group">
								<label for="issue-type">Issue Type *</label>
								<select id="issue-type" bind:value={issueTypeWithPrice} required>
									<option value="">-- Select Issue Type --</option>
									{#each issueTypeOptions as option}
										<option value={option.value}>{option.label}</option>
									{/each}
								</select>
							</div>
							
							<div class="form-group">
								<label for="priority">Priority *</label>
								<select id="priority" bind:value={priority} required>
									<option value="">-- Select Priority --</option>
									{#each priorityOptions as option}
										<option value={option.value}>{option.label}</option>
									{/each}
								</select>
							</div>
						</div>

						{#if issueType === 'other'}
						<div class="form-row">
							<div class="form-group">
								<label for="custom-issue">Custom Issue Type *</label>
								<input 
									type="text" 
									id="custom-issue" 
									bind:value={customIssueType} 
									placeholder="Enter custom issue type..."
									required
								/>
							</div>
						</div>
						{/if}

						<div class="checkbox-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={setAsDefaultSettings} />
								<span class="checkmark"></span>
								Set as default settings
							</label>
						</div>

						<!-- File Upload Section -->
						<div class="form-group">
							<label for="attachments">Attachments</label>
							
							<!-- Hidden file input -->
							<input 
								type="file" 
								bind:this={fileInput}
								on:change={handleFileSelect}
								multiple
								accept="image/*,.pdf,.xlsx,.xls,.docx,.doc,.txt,.csv"
								style="display: none;"
							/>
							
							<div class="file-upload-area" id="attachments">
								<div class="upload-options">
									<button type="button" class="camera-btn" on:click={openCamera} title="Take Photo">
										📷 Camera
									</button>
									<div 
										class="file-drop-zone" 
										on:click={openFileBrowser}
										on:drop={handleDrop}
										on:dragover={handleDragOver}
									>
										<p>📎 Drop files here or click to browse</p>
										<p class="file-types">Supported: Images, PDF, Excel, Word documents</p>
									</div>
								</div>
							</div>

							<!-- Selected Files Display -->
							{#if selectedFiles.length > 0}
								<div class="selected-files">
									<h4>Selected Files ({selectedFiles.length})</h4>
									{#each selectedFiles as fileItem (fileItem.id)}
										<div class="file-item">
											<div class="file-info">
												<span class="file-name">{fileItem.name}</span>
												<span class="file-size">{formatFileSize(fileItem.size)}</span>
											</div>
											<button 
												type="button" 
												class="remove-file-btn" 
												on:click={() => removeFile(fileItem.id)}
												title="Remove file"
											>
												✕
											</button>
										</div>
									{/each}
								</div>
							{/if}
						</div>

						<div class="form-group">
							<label for="task-description">Task Description</label>
							<textarea 
								id="task-description" 
								bind:value={taskDescription}
								placeholder="Enter detailed task description..."
								rows="4"
							></textarea>
						</div>

						<!-- Completion Requirements Section -->
						<div class="form-group">
							<label class="section-label">📋 Completion Requirements</label>
							<div class="completion-requirements">
								<p class="section-description">Select what users must do to complete this Quick Task</p>
								
								<div class="requirement-options compact">
									<label class="requirement-pill">
										<input 
											type="checkbox" 
											bind:checked={requirePhotoUpload}
											class="requirement-checkbox-small"
										/>
										<span class="pill-text">📷 Photo</span>
									</label>

									<label class="requirement-pill">
										<input 
											type="checkbox" 
											bind:checked={requireErpReference}
											class="requirement-checkbox-small"
										/>
										<span class="pill-text">🔢 ERP Ref</span>
									</label>

									<label class="requirement-pill">
										<input 
											type="checkbox" 
											bind:checked={requireFileUpload}
											class="requirement-checkbox-small"
										/>
										<span class="pill-text">📎 File Upload</span>
									</label>
								</div>

								{#if requirePhotoUpload || requireErpReference || requireFileUpload}
									<div class="requirements-summary compact">
										<span class="summary-label">Required:</span>
										<div class="summary-pills">
											{#if requirePhotoUpload}
												<span class="summary-pill photo">📷 Photo</span>
											{/if}
											{#if requireErpReference}
												<span class="summary-pill erp">🔢 ERP Ref</span>
											{/if}
											{#if requireFileUpload}
												<span class="summary-pill file">📎 File</span>
											{/if}
										</div>
									</div>
								{:else}
									<div class="requirements-summary compact">
										<em class="no-requirements">No additional requirements - users can complete with just marking as done</em>
									</div>
								{/if}
							</div>
						</div>

						<!-- Assignment Actions -->
						<div class="assignment-actions">
							<button type="button" on:click={assignTask} class="assign-btn">
								📋 Assign Task
							</button>
							<button type="button" on:click={resetForm} class="reset-btn">
								🔄 Reset Form
							</button>
						</div>
					</div>
				{/if}
		</div>
	{/if}
</div>

<!-- Camera Modal -->
{#if showCameraModal}
	<div class="camera-modal-overlay" on:click={closeCamera}>
		<div class="camera-modal" on:click|stopPropagation>
			<div class="camera-header">
				<h3>📷 Take Photo</h3>
				<button type="button" class="close-camera-btn" on:click={closeCamera}>✕</button>
			</div>
			<div class="camera-content">
				<video id="camera-video" autoplay playsinline></video>
				<canvas id="capture-canvas" style="display: none;"></canvas>
			</div>
			<div class="camera-actions">
				<button type="button" class="capture-btn" on:click={capturePhoto}>📸 Capture Photo</button>
				<button type="button" class="cancel-btn" on:click={closeCamera}>Cancel</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.quick-task-window {
		padding: 20px;
		height: 100%;
		background: white;
		display: flex;
		flex-direction: column;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		gap: 16px;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #f3f4f6;
		border-top: 3px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.window-header {
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 2px solid #e5e7eb;
	}

	.window-header h2 {
		margin: 0 0 8px 0;
		font-size: 20px;
		font-weight: 600;
		color: #1f2937;
	}

	.window-header p {
		margin: 0;
		font-size: 14px;
		color: #6b7280;
	}

	.window-content {
		flex: 1;
		overflow-y: auto;
		padding-right: 8px;
	}

	.form-section {
		margin-bottom: 32px;
		padding: 20px;
		background: #f9fafb;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.section-header {
		margin-bottom: 16px;
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.section-header h3 {
		margin: 0;
		font-size: 16px;
		font-weight: 600;
		color: #374151;
	}

	.user-actions {
		display: flex;
		gap: 12px;
		align-items: center;
	}

	.search-input {
		padding: 8px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		width: 250px;
	}

	.toggle-all-btn {
		padding: 8px 16px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		cursor: pointer;
		transition: background 0.2s;
	}

	.toggle-all-btn:hover {
		background: #2563eb;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-row {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 16px;
	}

	.form-group label {
		display: block;
		margin-bottom: 6px;
		font-weight: 500;
		color: #374151;
		font-size: 14px;
	}

	.form-group input,
	.form-group select,
	.form-group textarea {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		background: white;
	}

	.form-group input:focus,
	.form-group select:focus,
	.form-group textarea:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.checkbox-group {
		margin-top: 12px;
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 14px;
		color: #374151;
		cursor: pointer;
		user-select: none;
	}

	.checkbox-label input[type="checkbox"] {
		width: 16px;
		height: 16px;
		margin: 0;
		cursor: pointer;
	}

	.checkmark {
		position: relative;
	}

	.users-table-container {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		background: white;
	}

	.users-table {
		width: 100%;
		border-collapse: collapse;
	}

	.users-table th {
		background: #f3f4f6;
		padding: 12px;
		text-align: left;
		font-weight: 600;
		font-size: 14px;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
	}

	.users-table td {
		padding: 12px;
		border-bottom: 1px solid #f3f4f6;
		font-size: 14px;
		color: #374151;
	}

	.users-table tr:hover {
		background: #f9fafb;
	}

	.users-table tr.selected {
		background: #eff6ff;
	}

	.selection-summary {
		margin-top: 12px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px;
		background: #e0f2fe;
		border-radius: 6px;
		font-size: 14px;
	}

	.summary-actions {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.current-selection {
		background: #f8f9fa;
		border: 1px solid #dee2e6;
		border-radius: 8px;
		padding: 16px;
	}

	.selected-branch-card {
		background: #ffffff;
		border: 1px solid #dee2e6;
		box-shadow: none;
	}

	.selection-display {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 12px;
	}

	.selection-info {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.branch-display {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.branch-details {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.branch-label {
		font-size: 12px;
		font-weight: 500;
		color: #6c757d;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.branch-name {
		font-size: 18px;
		font-weight: 600;
		color: #495057;
		line-height: 1.2;
	}

	.selection-info .label {
		font-weight: 600;
		color: #374151;
	}

	.selection-info .value {
		color: #1f2937;
		font-weight: 500;
	}

	.default-badge {
		background: #6c757d;
		color: white;
		padding: 4px 10px;
		border-radius: 16px;
		font-size: 11px;
		font-weight: 500;
		box-shadow: none;
		align-self: flex-start;
	}

	.change-btn {
		padding: 6px 12px;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		cursor: pointer;
		transition: background 0.2s;
	}

	.change-btn:hover {
		background: #2563eb;
	}

	.confirm-btn {
		padding: 8px 16px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.confirm-btn:hover {
		background: #059669;
	}

	.default-btn {
		padding: 6px 12px;
		background: #f59e0b;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		cursor: pointer;
		transition: background 0.2s;
	}

	.default-btn:hover {
		background: #d97706;
	}

	.branch-actions {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: 12px;
	}

	.user-selection-controls {
		margin-bottom: 16px;
	}

	.user-actions-compact {
		display: flex;
		gap: 8px;
	}

	.button-group {
		display: flex;
		gap: 8px;
	}

	.selected-users-preview {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
		margin-top: 8px;
	}

	.user-chip {
		background: #dbeafe;
		color: #1e40af;
		padding: 4px 8px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 500;
		border: 1px solid #bfdbfe;
	}

	.user-chip.more {
		background: #f3f4f6;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.no-users {
		text-align: center;
		color: #6b7280;
		font-style: italic;
		padding: 20px;
	}

	.file-upload-area {
		border: 2px dashed #d1d5db;
		border-radius: 8px;
		padding: 24px;
		background: #fafafa;
		transition: all 0.2s;
	}

	.file-upload-area:hover {
		border-color: #3b82f6;
		background: #f0f9ff;
	}

	.upload-options {
		display: flex;
		gap: 16px;
		align-items: center;
	}

	.camera-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px 20px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
		min-width: 120px;
		justify-content: center;
	}

	.camera-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
	}

	.file-drop-zone {
		flex: 1;
		text-align: center;
		cursor: pointer;
	}

	.file-types {
		font-size: 12px;
		color: #6b7280;
		margin-top: 4px;
	}

	.selected-files {
		margin-top: 16px;
		padding: 16px;
		background: #f9fafb;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
	}

	.selected-files h4 {
		margin: 0 0 12px 0;
		font-size: 14px;
		color: #374151;
		font-weight: 600;
	}

	.file-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 12px;
		background: white;
		border-radius: 6px;
		border: 1px solid #d1d5db;
		margin-bottom: 8px;
	}

	.file-item:last-child {
		margin-bottom: 0;
	}

	.file-info {
		display: flex;
		flex-direction: column;
		flex: 1;
	}

	.file-name {
		font-size: 14px;
		color: #374151;
		font-weight: 500;
	}

	.file-size {
		font-size: 12px;
		color: #6b7280;
	}

	.remove-file-btn {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 4px;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 12px;
		transition: background 0.2s;
	}

	.remove-file-btn:hover {
		background: #dc2626;
	}

	/* Camera Modal Styles */
	.camera-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.camera-modal {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		max-width: 500px;
		width: 90%;
		max-height: 80vh;
	}

	.camera-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 16px 20px;
		background: #f3f4f6;
		border-bottom: 1px solid #e5e7eb;
	}

	.camera-header h3 {
		margin: 0;
		font-size: 18px;
		color: #374151;
	}

	.close-camera-btn {
		background: none;
		border: none;
		font-size: 20px;
		color: #6b7280;
		cursor: pointer;
		padding: 4px;
		border-radius: 4px;
		transition: background 0.2s;
	}

	.close-camera-btn:hover {
		background: #e5e7eb;
	}

	.camera-content {
		padding: 20px;
		display: flex;
		justify-content: center;
	}

	#camera-video {
		width: 100%;
		max-width: 400px;
		border-radius: 8px;
		background: #000;
	}

	.camera-actions {
		display: flex;
		gap: 12px;
		justify-content: center;
		padding: 16px 20px;
		background: #f9fafb;
		border-top: 1px solid #e5e7eb;
	}

	.capture-btn {
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px 24px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.capture-btn:hover {
		background: #2563eb;
	}

	.cancel-btn {
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px 24px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.cancel-btn:hover {
		background: #4b5563;
	}

	.assignment-actions {
		display: flex;
		gap: 12px;
		justify-content: center;
		padding: 20px;
		background: white;
		border-top: 1px solid #e5e7eb;
		margin: -20px -20px 0 -20px;
		border-radius: 0 0 8px 8px;
	}

	.assign-btn {
		padding: 12px 24px;
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.assign-btn:hover {
		background: #059669;
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
	}

	.reset-btn {
		padding: 12px 24px;
		background: #6b7280;
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.reset-btn:hover {
		background: #4b5563;
		transform: translateY(-1px);
	}

	/* Scrollbar styling */
	.window-content::-webkit-scrollbar,
	.users-table-container::-webkit-scrollbar {
		width: 8px;
	}

	.window-content::-webkit-scrollbar-track,
	.users-table-container::-webkit-scrollbar-track {
		background: #f1f5f9;
		border-radius: 4px;
	}

	.window-content::-webkit-scrollbar-thumb,
	.users-table-container::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 4px;
	}

	.window-content::-webkit-scrollbar-thumb:hover,
	.users-table-container::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}

	/* Completion Requirements Styles */
	.completion-requirements {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		border-radius: 8px;
		padding: 16px;
		margin-top: 8px;
	}

	.section-description {
		color: #64748b;
		font-size: 14px;
		margin-bottom: 16px;
	}

	.requirement-options {
		display: flex;
		flex-direction: column;
		gap: 12px;
		margin-bottom: 16px;
	}

	.requirement-options.compact {
		flex-direction: row;
		flex-wrap: wrap;
		gap: 8px;
		margin-bottom: 12px;
	}

	.requirement-option {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 12px;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 6px;
		cursor: pointer;
		transition: all 0.2s;
	}

	.requirement-pill {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px 12px;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 20px;
		cursor: pointer;
		transition: all 0.2s;
		font-size: 12px;
		font-weight: 500;
	}

	.requirement-option:hover {
		border-color: #7c3aed;
		background: #faf5ff;
	}

	.requirement-pill:hover {
		border-color: #7c3aed;
		background: #faf5ff;
		transform: translateY(-1px);
	}

	.requirement-checkbox {
		width: 16px;
		height: 16px;
		margin-top: 2px;
		accent-color: #7c3aed;
	}

	.requirement-checkbox-small {
		width: 16px;
		height: 16px;
		accent-color: #7c3aed;
		cursor: pointer;
		border: 2px solid #d1d5db;
		border-radius: 3px;
		appearance: none;
		background: white;
		position: relative;
		transition: all 0.2s ease;
	}

	.requirement-checkbox-small:checked {
		background: #7c3aed;
		border-color: #7c3aed;
	}

	.requirement-checkbox-small:checked::before {
		content: '✓';
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		color: white;
		font-size: 12px;
		font-weight: bold;
		line-height: 1;
	}

	.requirement-checkbox-small:hover {
		border-color: #7c3aed;
		box-shadow: 0 0 0 3px rgba(124, 58, 237, 0.1);
	}

	.pill-text {
		font-size: 12px;
		font-weight: 500;
		color: #374151;
	}

	.requirement-content {
		display: flex;
		flex-direction: column;
		gap: 4px;
		flex: 1;
	}

	.requirement-title {
		font-weight: 600;
		color: #334155;
		font-size: 14px;
	}

	.requirement-description {
		font-size: 12px;
		color: #64748b;
		line-height: 1.4;
	}

	.requirements-summary {
		background: #ecfdf5;
		border: 1px solid #d1fae5;
		border-radius: 6px;
		padding: 12px;
		font-size: 14px;
		color: #065f46;
	}

	.requirements-summary.compact {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 12px;
		font-size: 12px;
	}

	.summary-label {
		font-weight: 600;
		color: #065f46;
		white-space: nowrap;
	}

	.summary-pills {
		display: flex;
		gap: 4px;
		flex-wrap: wrap;
	}

	.summary-pill {
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 11px;
		font-weight: 500;
		white-space: nowrap;
	}

	.summary-pill.photo {
		background: #dcfce7;
		color: #166534;
	}

	.summary-pill.erp {
		background: #dbeafe;
		color: #1e40af;
	}

	.summary-pill.file {
		background: #fed7aa;
		color: #c2410c;
	}

	.no-requirements {
		font-size: 12px;
		color: #6b7280;
	}

	.requirements-summary ul {
		margin: 8px 0 0 0;
		padding-left: 16px;
	}

	.requirements-summary li {
		margin: 4px 0;
	}
</style>