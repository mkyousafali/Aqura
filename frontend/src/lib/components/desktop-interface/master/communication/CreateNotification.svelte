<script lang="ts">
	import { onMount } from 'svelte';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { supabase, db, uploadToSupabase } from '$lib/utils/supabase';
	import FileUpload from '$lib/components/common/FileUpload.svelte';

	// Current user and role information
	$: userRole = $currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Form data
	let notificationData = {
		title: '',
		message: '',
		priority: 'medium' as 'low' | 'medium' | 'high' | 'urgent',
		type: 'info' as 'info' | 'success' | 'warning' | 'error' | 'announcement',
		target_type: 'all_users' as 'all_users' | 'specific_users',
		target_users: [] as string[]
	};

	// File upload variables - replaced image-specific with general file support
	let attachedFiles: File[] = [];
	let fileUploadComponent: FileUpload;
	let fileErrors: string[] = [];
	let cameraInput: HTMLInputElement;

	// Available branches and users from API
	let branches: Array<{ id: string; name: string }> = [];
	let allUsers: Array<{ 
		id: string; 
		username: string; 
		employee_name?: string; 
		employee_id?: string;
		position_name?: string;
		role_type: string; 
		branch_id?: string; 
		branch_name?: string 
	}> = [];
	let filteredUsers: Array<{ 
		id: string; 
		username: string; 
		employee_name?: string; 
		employee_id?: string;
		position_name?: string;
		role_type: string; 
		branch_id?: string; 
		branch_name?: string; 
		selected: boolean 
	}> = [];
	let selectedBranchFilter = 'all';
	let userSearchTerm = '';
	let isLoadingBranches = true;
	let isLoadingUsers = false;

	// Form state
	let isLoading = false;
	let successMessage = '';
	let errorMessage = '';

	// Load branches and users on mount
	onMount(async () => {
		await loadBranches();
		await loadUsers();
	});

	async function loadBranches() {
		try {
			isLoadingBranches = true;
			const branchesData = await notificationManagement.getBranches();
			branches = [
				{ id: 'all', name: 'All Branches' },
				...branchesData.map(branch => ({ id: branch.id.toString(), name: branch.name_en || branch.name }))
			];
		} catch (error) {
			console.error('Error loading branches:', error);
			// Use fallback branches
			branches = [
				{ id: 'all', name: 'All Branches' },
				{ id: '1', name: 'Main Branch' },
				{ id: '2', name: 'Downtown Branch' },
				{ id: '3', name: 'Westside Branch' }
			];
		} finally {
			isLoadingBranches = false;
		}
	}

	async function loadUsers() {
		try {
			isLoadingUsers = true;
			
			// Get users with employee information and branch details
			const { data: users, error } = await supabase
				.from('users')
				.select(`
					id,
					username,
					employee_id,
					branch_id,
					hr_employees!users_employee_id_fkey(id, name),
					branches(id, name_en)
				`)
				.order('username');

			if (error) {
				console.error('Supabase error loading users:', error);
				throw error;
			}

			// Transform users data with proper relationships
			console.log('🔍 Raw users data from Supabase:', users);
			
			allUsers = users?.map(user => {
				const employee = user.hr_employees;
				const branch = user.branches;
				
				console.log(`👤 Processing user ${user.username}:`, {
					employee_data: employee,
					branch_data: branch,
					raw_user: user
				});
				
				// Get current position assignment
				const currentPosition = employee?.hr_position_assignments?.find(
					assignment => assignment.is_current === true
				);
				
				const transformed = {
					id: user.id,
					username: user.username,
					employee_name: employee?.name || null,
					employee_id: employee?.employee_id || null,
					position_name: currentPosition?.hr_positions?.position_title_en || null,
					role_type: user.role_type,
					branch_id: user.branch_id?.toString() || null,
					branch_name: branch?.name_en || 'Unknown Branch'
				};
				
				console.log(`✅ Transformed user ${user.username}:`, transformed);
				return transformed;
			}) || [];

			// Initialize filtered users
			updateFilteredUsers();
		} catch (error) {
			console.error('Error loading users:', error);
			// Fallback: try to get basic user data
			try {
				const usersData = await notificationManagement.getUsers();
				allUsers = usersData.map(user => ({
					id: user.id,
					username: user.username,
					employee_name: null,
					employee_id: null,
					position_name: null,
					role_type: user.role_type || 'Employee',
					branch_id: null,
					branch_name: 'Unknown Branch'
				}));
				updateFilteredUsers();
			} catch (fallbackError) {
				console.error('Fallback user loading failed:', fallbackError);
				allUsers = [];
				filteredUsers = [];
			}
		} finally {
			isLoadingUsers = false;
		}
	}

	function updateFilteredUsers() {
		let filtered = allUsers;
		
		// Filter by branch if specific branch is selected
		if (selectedBranchFilter !== 'all') {
			filtered = allUsers.filter(user => user.branch_id === selectedBranchFilter);
		}
		
		// Filter by search term if provided
		if (userSearchTerm.trim()) {
			const searchLower = userSearchTerm.toLowerCase();
			filtered = filtered.filter(user => 
				user.username.toLowerCase().includes(searchLower) ||
				user.employee_name?.toLowerCase().includes(searchLower) ||
				user.employee_id?.toLowerCase().includes(searchLower) ||
				user.position_name?.toLowerCase().includes(searchLower) ||
				user.branch_name?.toLowerCase().includes(searchLower)
			);
		}
		
		// Add selected property and preserve existing selections
		filteredUsers = filtered.map(user => ({
			...user,
			selected: notificationData.target_users.includes(user.id)
		}));
	}

	// Handle branch filter change
	function onBranchFilterChange() {
		updateFilteredUsers();
	}

	// Handle search term change
	function onSearchChange() {
		updateFilteredUsers();
	}

	// Handle user selection change
	function onUserSelectionChange(userId: string, selected: boolean) {
		if (selected) {
			notificationData.target_users = [...notificationData.target_users, userId];
		} else {
			notificationData.target_users = notificationData.target_users.filter(id => id !== userId);
		}
		
		// Update local state
		filteredUsers = filteredUsers.map(user => 
			user.id === userId ? { ...user, selected } : user
		);
	}

	// File handling functions - updated to support multiple file types
	function handleFilesChanged(event: CustomEvent) {
		attachedFiles = event.detail.files;
		fileErrors = event.detail.errors;
	}

	function handleUploadComplete(event: CustomEvent) {
		console.log('� [Notification] Files uploaded:', event.detail);
	}

	// Camera functions
	function openCamera() {
		if (cameraInput) {
			cameraInput.click();
		}
	}

	function handleCameraCapture(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = target.files;
		if (files && files.length > 0 && fileUploadComponent) {
			// Add captured photos to the file upload component
			const fileArray = Array.from(files);
			fileUploadComponent.addFiles(fileArray);
			target.value = ''; // Clear the input for next use
		}
	}

	// Select/deselect all visible users
	function toggleSelectAll() {
		const allSelected = filteredUsers.every(user => user.selected);
		
		if (allSelected) {
			// Deselect all visible users
			filteredUsers.forEach(user => {
				notificationData.target_users = notificationData.target_users.filter(id => id !== user.id);
				user.selected = false;
			});
		} else {
			// Select all visible users
			filteredUsers.forEach(user => {
				if (!user.selected) {
					notificationData.target_users = [...notificationData.target_users, user.id];
					user.selected = true;
				}
			});
		}
		
		// Trigger reactivity
		filteredUsers = [...filteredUsers];
		notificationData.target_users = [...notificationData.target_users];
	}

	async function createNotification() {
		// Validate required fields
		if (!notificationData.title.trim() || !notificationData.message.trim()) {
			errorMessage = 'Title and message are required';
			return;
		}

		// Validate user selection for specific users
		if (notificationData.target_type === 'specific_users' && notificationData.target_users.length === 0) {
			errorMessage = 'Please select at least one user for specific user targeting';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			let uploadedFiles: any[] = [];

			// Upload files if present
			if (attachedFiles.length > 0 && fileUploadComponent) {
				console.log('📎 [Notification] Uploading files...');
				const uploadResult = await fileUploadComponent.uploadFiles();
				
				if (!uploadResult.success) {
					errorMessage = `File upload failed: ${uploadResult.errors.join(', ')}`;
					isLoading = false;
					return;
				}
				
				uploadedFiles = uploadResult.uploadedFiles;
				console.log('📎 [Notification] Files uploaded successfully:', uploadedFiles);
			}

			// Prepare notification data for API
			const apiData = {
				title: notificationData.title.trim(),
				message: notificationData.message.trim(),
				type: notificationData.type,
				priority: notificationData.priority,
				target_type: notificationData.target_type,
				target_users: notificationData.target_type === 'specific_users' ? notificationData.target_users : undefined,
				// Include the first uploaded image as image_url for backward compatibility
				image_url: uploadedFiles.find(f => f.originalFile.type.startsWith('image/'))?.fileUrl || null,
				has_attachments: uploadedFiles.length > 0
			};

			// Create the notification
			console.log('🧪 Debug currentUser:', $currentUser);
			
			const createdByUser = $currentUser?.username || 'madmin'; // Fallback to known user
			console.log('🧪 Using createdByUser:', createdByUser);
			
			const result = await notificationManagement.createNotification(apiData, createdByUser);
			
			if (result && result.id) {
				// Save file attachments to database
				if (uploadedFiles.length > 0) {
					console.log('💾 [Notification] Saving file attachments...');
					
					for (const file of uploadedFiles) {
						try {
							const attachmentData = {
								notification_id: result.id,
								file_name: file.fileName,
								file_path: file.filePath,
								file_size: file.fileSize,
								file_type: file.fileType,
								uploaded_by: $currentUser?.id || 'system'
							};
							
							console.log('� [Notification] Creating attachment record:', attachmentData);
							const attachmentResult = await db.notificationAttachments.create(attachmentData);
							
							if (attachmentResult.error) {
								console.error('❌ [Notification] Failed to save attachment:', attachmentResult.error);
							} else {
								console.log('✅ [Notification] Attachment saved:', attachmentResult.data);
							}
						} catch (attachmentError) {
							console.error('❌ [Notification] Error saving attachment:', attachmentError);
						}
					}
				}

				successMessage = 'Notification published successfully!';
				
				// Reset form after delay
				setTimeout(() => {
					resetForm();
					successMessage = '';
				}, 2000);
			} else {
				errorMessage = 'Failed to publish notification. Please try again.';
			}

		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Failed to publish notification. Please try again.';
			console.error('Publish notification error:', error);
		} finally {
			isLoading = false;
		}
	}

	function resetForm() {
		notificationData = {
			title: '',
			message: '',
			priority: 'medium' as 'low' | 'medium' | 'high' | 'urgent',
			type: 'info' as 'info' | 'success' | 'warning' | 'error' | 'announcement',
			target_type: 'all_users',
			target_users: []
		};
		
		// Reset file upload
		if (fileUploadComponent) {
			fileUploadComponent.clearFiles();
		}
		attachedFiles = [];
		fileErrors = [];
		
		// Reset user selections
		filteredUsers = filteredUsers.map(user => ({ ...user, selected: false }));
		selectedBranchFilter = 'all';
		userSearchTerm = '';
		updateFilteredUsers();
	}
</script>

<!-- Hidden camera input -->
<input
	bind:this={cameraInput}
	type="file"
	accept="image/*"
	capture="environment"
	style="display: none;"
	on:change={handleCameraCapture}
/>

<div class="create-notification">
	<!-- Success/Error Messages -->
	{#if successMessage}
		<div class="message success">
			<span class="icon">✅</span>
			{successMessage}
		</div>
	{/if}

	{#if errorMessage}
		<div class="message error">
			<span class="icon">❌</span>
			{errorMessage}
		</div>
	{/if}

	<!-- Form -->
	<div class="form-content">
		<form on:submit|preventDefault={createNotification}>
			<!-- User Info Section -->
			<div class="user-section">
				<div class="user-info">
					<span class="role-label">Creating as:</span>
					<span class="role-badge {userRole.toLowerCase().replace(' ', '-')}">{userRole}</span>
				</div>
			</div>

			<!-- Basic Information -->
			<div class="form-section">
				<h3 class="section-title">Basic Information</h3>
				
				<div class="form-group">
					<label for="title">Title *</label>
					<input 
						id="title"
						type="text" 
						bind:value={notificationData.title}
						placeholder="Enter notification title"
						maxlength="100"
						required
					/>
				</div>

				<div class="form-group">
					<label for="message">Message *</label>
					<textarea 
						id="message"
						bind:value={notificationData.message}
						placeholder="Enter your notification message..."
						rows="4"
						maxlength="500"
						required
					></textarea>
				</div>

				<!-- File Upload Section -->
				<div class="form-group">
					<div class="upload-header">
						<label>Upload Files (optional)</label>
						<button type="button" class="camera-btn" on:click={openCamera}>
							📷 Camera
						</button>
					</div>
					
					<FileUpload 
						bind:this={fileUploadComponent}
						acceptedTypes="image/*,.pdf,.doc,.docx,.xls,.xlsx,.txt,.sql,.zip,.rar"
						maxSizeInMB={50}
						bucket="notification-images"
						multiple={true}
						showPreview={true}
						label=""
						placeholder="Upload images, documents, spreadsheets, or other files"
						bind:currentFiles={attachedFiles}
						on:filesChanged={handleFilesChanged}
						on:uploadComplete={handleUploadComplete}
					/>
					
					{#if fileErrors.length > 0}
						<div class="error-messages">
							{#each fileErrors as error}
								<p class="error-text">{error}</p>
							{/each}
						</div>
					{/if}
				</div>

				<div class="form-row">
					<div class="form-group">
						<label for="priority">Priority</label>
						<select id="priority" bind:value={notificationData.priority}>
							<option value="low">Low Priority</option>
							<option value="medium">Medium Priority</option>
							<option value="high">High Priority</option>
							<option value="urgent">Urgent Priority</option>
						</select>
					</div>

					<div class="form-group">
						<label for="type">Type</label>
						<select id="type" bind:value={notificationData.type}>
							<option value="info">Information</option>
							<option value="success">Success</option>
							<option value="warning">Warning</option>
							<option value="error">Error</option>
							<option value="announcement">Announcement</option>
						</select>
					</div>
				</div>
			</div>

			<!-- Target Audience -->
			<div class="form-section">
				<h3 class="section-title">Target Audience</h3>
				
				<div class="form-group">
					<label for="target_type">Target Type</label>
					<select id="target_type" bind:value={notificationData.target_type} on:change={() => { notificationData.target_users = []; userSearchTerm = ''; updateFilteredUsers(); }}>
						<option value="all_users">All Users</option>
						<option value="specific_users">User Specific</option>
					</select>
				</div>

				{#if notificationData.target_type === 'specific_users'}
					<div class="users-selection">
						<div class="users-header">
							<h4 class="users-title">Select Users</h4>
							<div class="users-controls">
								<div class="search-filter">
									<label for="user_search">🔍 Search Users:</label>
									<input 
										id="user_search" 
										type="text" 
										bind:value={userSearchTerm}
										on:input={onSearchChange}
										placeholder="Search by username, name, ID, position, or branch..."
										class="search-input"
									/>
								</div>
								<div class="branch-filter">
									<label for="branch_filter">Filter by Branch:</label>
									<select id="branch_filter" bind:value={selectedBranchFilter} on:change={onBranchFilterChange}>
										{#if isLoadingBranches}
											<option value="all">Loading branches...</option>
										{:else}
											{#each branches as branch}
												<option value={branch.id}>{branch.name}</option>
											{/each}
										{/if}
									</select>
								</div>
								<button type="button" class="select-all-btn" on:click={toggleSelectAll}>
									{filteredUsers.every(user => user.selected) ? 'Deselect All' : 'Select All'}
								</button>
							</div>
						</div>

						{#if isLoadingUsers}
							<div class="loading-users">
								<div class="loading-spinner-small"></div>
								<p>Loading users...</p>
							</div>
						{:else if filteredUsers.length === 0}
							<div class="no-users">
								{#if userSearchTerm.trim()}
									<p>No users found matching "{userSearchTerm}".</p>
									<p>Try adjusting your search terms or branch filter.</p>
								{:else if selectedBranchFilter !== 'all'}
									<p>No users found for the selected branch.</p>
									<p>Try selecting "All Branches" to see all users.</p>
								{:else}
									<p>No users available.</p>
								{/if}
							</div>
						{:else}
							<div class="users-table">
								<div class="table-header">
									<div class="col-select">Select</div>
									<div class="col-username">Username</div>
									<div class="col-name">Employee Name</div>
									<div class="col-employee-id">Employee ID</div>
									<div class="col-position">Position</div>
									<div class="col-role">Role</div>
									<div class="col-branch">Branch</div>
								</div>
								<div class="table-body">
									{#each filteredUsers as user}
										<div class="table-row" class:selected={user.selected}>
											<div class="col-select">
												<input 
													type="checkbox" 
													checked={user.selected}
													on:change={(e) => onUserSelectionChange(user.id, e.target.checked)}
												/>
											</div>
											<div class="col-username">{user.username}</div>
											<div class="col-name">{user.employee_name || '-'}</div>
											<div class="col-employee-id">{user.employee_id || '-'}</div>
											<div class="col-position">{user.position_name || '-'}</div>
											<div class="col-role">{user.role_type}</div>
											<div class="col-branch">{user.branch_name}</div>
										</div>
									{/each}
								</div>
							</div>
							{#if notificationData.target_users.length > 0}
								<div class="selection-summary">
									<strong>{notificationData.target_users.length} user(s) selected</strong>
									{#if filteredUsers.length < allUsers.length}
										<span class="filter-info">({filteredUsers.length} shown of {allUsers.length} total users)</span>
									{/if}
								</div>
							{/if}
						{/if}
					</div>
				{/if}
			</div>

			<!-- Action Buttons -->
			<div class="form-actions">
				<button type="button" class="btn secondary" on:click={resetForm} disabled={isLoading}>
					Reset
				</button>
				<button type="submit" class="btn primary" disabled={isLoading}>
					{#if isLoading}
						<span class="loading-spinner"></span>
						Sending...
					{:else}
						📋 Publish
					{/if}
				</button>
			</div>
		</form>
	</div>
</div>

<style>
	.create-notification {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		overflow: hidden;
		padding: 20px;
	}

	.message {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px;
		border-radius: 6px;
		margin-bottom: 16px;
		font-size: 14px;
		font-weight: 500;
	}

	.message.success {
		background: #d1fae5;
		color: #065f46;
		border: 1px solid #10b981;
	}

	.message.error {
		background: #fee2e2;
		color: #991b1b;
		border: 1px solid #ef4444;
	}

	.form-content {
		flex: 1;
		overflow-y: auto;
	}

	.user-section {
		margin-bottom: 20px;
		padding: 12px 16px;
		background: #f8fafc;
		border-radius: 8px;
		border: 1px solid #e2e8f0;
	}

	.user-info {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.role-label {
		font-size: 14px;
		color: #64748b;
		font-weight: 500;
	}

	.role-badge {
		padding: 4px 12px;
		border-radius: 12px;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.role-badge.admin {
		background: #dbeafe;
		color: #1e40af;
	}

	.role-badge.master-admin {
		background: #fef3c7;
		color: #d97706;
	}

	.role-badge.position-based {
		background: #f3f4f6;
		color: #374151;
	}

	.form-section {
		margin-bottom: 24px;
	}

	.section-title {
		font-size: 16px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 16px 0;
		padding-bottom: 8px;
		border-bottom: 1px solid #f3f4f6;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.upload-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 12px;
	}

	.upload-header label {
		margin: 0;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
	}

	.camera-btn {
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		transition: background-color 0.2s ease;
	}

	.camera-btn:hover {
		background: #2563EB;
	}

	.camera-btn:active {
		transform: scale(0.98);
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
	}

	label {
		display: block;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 6px;
	}

	input[type="text"],
	textarea,
	select {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s;
		background: white;
	}

	input[type="text"]:focus,
	textarea:focus,
	select:focus {
		outline: none;
		border-color: #10b981;
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	textarea {
		resize: vertical;
		min-height: 80px;
	}

	.loading-text {
		color: #6b7280;
		font-style: italic;
		margin: 0;
	}

	.form-actions {
		display: flex;
		gap: 12px;
		justify-content: flex-end;
		padding-top: 20px;
		border-top: 1px solid #e5e7eb;
		margin-top: 24px;
	}

	.btn {
		padding: 10px 20px;
		border: none;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn.secondary {
		background: #f9fafb;
		color: #374151;
		border: 1px solid #d1d5db;
	}

	.btn.secondary:hover:not(:disabled) {
		background: #f3f4f6;
	}

	.btn.primary {
		background: #10b981;
		color: white;
	}

	.btn.primary:hover:not(:disabled) {
		background: #059669;
	}

	.loading-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Scrollbar styling */
	.form-content::-webkit-scrollbar {
		width: 6px;
	}

	.form-content::-webkit-scrollbar-track {
		background: #f1f5f9;
		border-radius: 3px;
	}

	.form-content::-webkit-scrollbar-thumb {
		background: #cbd5e1;
		border-radius: 3px;
	}

	.form-content::-webkit-scrollbar-thumb:hover {
		background: #94a3b8;
	}

	/* User Table Styles */
	.users-selection {
		margin-top: 16px;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		background: white;
	}

	.users-header {
		padding: 16px;
		border-bottom: 1px solid #e5e7eb;
		background: #f9fafb;
	}

	.users-title {
		font-size: 16px;
		font-weight: 600;
		color: #374151;
		margin: 0 0 12px 0;
	}

	.users-controls {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 16px;
		flex-wrap: wrap;
	}

	.search-filter {
		display: flex;
		align-items: center;
		gap: 8px;
		flex: 1;
		min-width: 300px;
	}

	.search-filter label {
		font-size: 14px;
		font-weight: 500;
		margin: 0;
		white-space: nowrap;
	}

	.search-input {
		flex: 1;
		padding: 6px 10px;
		font-size: 14px;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		background: white;
		transition: border-color 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-input::placeholder {
		color: #9ca3af;
	}

	.branch-filter {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.branch-filter label {
		font-size: 14px;
		font-weight: 500;
		margin: 0;
		white-space: nowrap;
	}

	.branch-filter select {
		min-width: 150px;
		padding: 6px 10px;
		font-size: 14px;
	}

	.select-all-btn {
		padding: 6px 12px;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		background: white;
		color: #374151;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.select-all-btn:hover {
		background: #f3f4f6;
		border-color: #10b981;
	}

	.loading-users {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 12px;
		padding: 40px;
		color: #6b7280;
	}

	.loading-spinner-small {
		width: 20px;
		height: 20px;
		border: 2px solid #f3f4f6;
		border-top: 2px solid #10b981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.no-users {
		padding: 40px;
		text-align: center;
		color: #6b7280;
	}

	.no-users p {
		margin: 8px 0;
	}

	.users-table {
		max-height: 300px;
		overflow-y: auto;
	}

	.table-header {
		display: grid;
		grid-template-columns: 60px 120px 150px 100px 140px 100px 120px;
		gap: 8px;
		padding: 12px 16px;
		background: #f8fafc;
		border-bottom: 1px solid #e5e7eb;
		font-size: 13px;
		font-weight: 600;
		color: #374151;
	}

	.table-body {
		min-height: 100px;
		max-height: 240px;
		overflow-y: auto;
	}

	.table-row {
		display: grid;
		grid-template-columns: 60px 120px 150px 100px 140px 100px 120px;
		gap: 8px;
		padding: 10px 16px;
		border-bottom: 1px solid #f3f4f6;
		transition: background-color 0.2s;
		align-items: center;
		font-size: 13px;
	}

	.table-row:hover {
		background: #f8fafc;
	}

	.table-row.selected {
		background: #f0fdf4;
		border-color: #bbf7d0;
	}

	.col-select {
		display: flex;
		justify-content: center;
		align-items: center;
	}

	.col-select input[type="checkbox"] {
		width: 16px !important;
		height: 16px !important;
		margin: 0 !important;
		padding: 0 !important;
		transform: scale(1.2);
		cursor: pointer;
		appearance: auto !important;
		-webkit-appearance: checkbox !important;
		-moz-appearance: checkbox !important;
		background: white !important;
		border: 1px solid #d1d5db !important;
		border-radius: 2px !important;
		display: inline-block !important;
		position: relative;
	}

	.col-select input[type="checkbox"]:checked {
		background-color: #10b981 !important;
		border-color: #10b981 !important;
	}

	.col-select input[type="checkbox"]:focus {
		outline: 2px solid #10b981 !important;
		outline-offset: 2px;
	}

	.col-username {
		color: #6b7280;
		font-family: monospace;
		font-size: 12px;
		word-break: break-all;
	}

	.col-name {
		font-weight: 500;
		color: #111827;
	}

	.col-employee-id {
		color: #6b7280;
		font-family: monospace;
		font-size: 12px;
	}

	.col-position {
		font-size: 12px;
		color: #374151;
		word-break: break-word;
	}

	.col-role {
		font-size: 12px;
		color: #374151;
	}

	.col-branch {
		font-size: 12px;
		color: #6b7280;
		word-break: break-word;
	}

	.selection-summary {
		padding: 12px 16px;
		background: #f0fdf4;
		border-top: 1px solid #bbf7d0;
		color: #065f46;
		font-size: 14px;
		text-align: center;
	}

	.filter-info {
		color: #6b7280;
		font-weight: normal;
		margin-left: 8px;
	}

	/* Image Upload Styles */
	.image-upload-section {
		margin-top: 8px;
	}

	.image-preview {
		position: relative;
		display: inline-block;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 8px;
		background: #f9fafb;
		margin-bottom: 12px;
	}

	.preview-image {
		width: 120px;
		height: 120px;
		object-fit: cover;
		border-radius: 6px;
		display: block;
	}

	.remove-image-btn {
		position: absolute;
		top: -6px;
		right: -6px;
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		cursor: pointer;
		font-size: 16px;
		line-height: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.remove-image-btn:hover {
		background: #dc2626;
	}

	.image-info {
		margin-top: 8px;
		text-align: center;
	}

	.file-name {
		font-size: 12px;
		font-weight: 500;
		color: #374151;
		margin-bottom: 2px;
	}

	.file-size {
		font-size: 11px;
		color: #6b7280;
	}

	.dimensions {
		font-size: 11px;
		color: #6b7280;
	}

	.image-input {
		width: 100%;
		padding: 8px;
		border: 2px dashed #d1d5db;
		border-radius: 6px;
		background: #f9fafb;
		font-size: 14px;
		cursor: pointer;
		transition: border-color 0.2s, background-color 0.2s;
	}

	.image-input:hover {
		border-color: #9ca3af;
		background: #f3f4f6;
	}

	.image-input:focus {
		outline: none;
		border-color: #3b82f6;
		background: white;
	}

	.upload-hint {
		font-size: 12px;
		color: #6b7280;
		margin-top: 4px;
		margin-bottom: 0;
	}

	.error-text {
		color: #ef4444;
		font-size: 12px;
		margin-top: 4px;
		margin-bottom: 0;
	}
</style>