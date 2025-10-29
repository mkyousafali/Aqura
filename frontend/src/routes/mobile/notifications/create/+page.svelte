<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { supabase, db } from '$lib/utils/supabase';
	import FileUpload from '$lib/components/common/FileUpload.svelte';
	import { getTranslation, currentLocale } from '$lib/i18n';

	// Current user and role information
	$: userRole = $currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Redirect if not admin
	$: if (!isAdminOrMaster) {
		goto('/mobile/notifications');
	}

	// Form data
	let notificationData = {
		title: '',
		message: '',
		priority: 'medium' as 'low' | 'medium' | 'high' | 'urgent',
		type: 'info' as 'info' | 'success' | 'warning' | 'error' | 'announcement',
		target_type: 'specific_users' as 'all_users' | 'specific_users',
		target_users: [] as string[]
	};

	// File upload variables
	let fileUploadComponent: FileUpload;

	// Available users from API
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
	let userSearchTerm = '';
	let isLoadingUsers = false;

	// Form state
	let isLoading = false;
	let successMessage = '';
	let errorMessage = '';

	// Load users on mount
	onMount(async () => {
		await loadUsers();
	});

	// Reload users when language changes to update position titles
	$: if ($currentLocale) {
		loadUsers();
	}

	async function loadUsers() {
		try {
			isLoadingUsers = true;
			
			// Get users with employee information, position, and branch details
			const { data: users, error } = await supabase
				.from('users')
				.select(`
					id,
					username,
					role_type,
					employee_id,
					branch_id,
					hr_employees(
						id,
						name,
						employee_id,
						branch_id,
						hr_position_assignments(
							id,
							position_id,
							is_current,
							hr_positions(position_title_en, position_title_ar)
						)
					),
					branches(
						id,
						name_en
					)
				`)
				.order('username');

			if (error) {
				console.error('Supabase error loading users:', error);
				throw error;
			}

			// Transform users data with proper relationships
			allUsers = users?.map(user => {
				const employee = user.hr_employees;
				const branch = user.branches;
				
				// Get current position assignment
				const currentPosition = employee?.hr_position_assignments?.find(
					assignment => assignment.is_current === true
				);
				
				// Use Arabic position title if current locale is Arabic, otherwise use English
				const isArabic = $currentLocale === 'ar';
				const positionTitle = currentPosition?.hr_positions 
					? (isArabic ? currentPosition.hr_positions.position_title_ar : currentPosition.hr_positions.position_title_en)
					: null;
				
				return {
					id: user.id,
					username: user.username,
					employee_name: employee?.name || null,
					employee_id: employee?.employee_id || null,
					position_name: positionTitle || null,
					role_type: user.role_type,
					branch_id: user.branch_id?.toString() || null,
					branch_name: branch?.name_en || 'Unknown Branch'
				};
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
		
		// Filter by search term if provided
		if (userSearchTerm.trim()) {
			const searchLower = userSearchTerm.toLowerCase();
			filtered = filtered.filter(user => 
				user.username.toLowerCase().includes(searchLower) ||
				user.employee_name?.toLowerCase().includes(searchLower) ||
				user.employee_id?.toLowerCase().includes(searchLower) ||
				user.position_name?.toLowerCase().includes(searchLower)
			);
		}
		
		// Add selected property to all users
		filteredUsers = filtered.map(user => ({
			...user,
			selected: notificationData.target_users.includes(user.id)
		}));
	}

	function toggleUserSelection(userId: string) {
		if (notificationData.target_users.includes(userId)) {
			notificationData.target_users = notificationData.target_users.filter(id => id !== userId);
		} else {
			notificationData.target_users = [...notificationData.target_users, userId];
		}
		updateFilteredUsers();
	}

	function selectAllUsers() {
		notificationData.target_users = filteredUsers.map(user => user.id);
		updateFilteredUsers();
	}

	function deselectAllUsers() {
		notificationData.target_users = [];
		updateFilteredUsers();
	}

	async function submitNotification() {
		// Validation
		if (!notificationData.title.trim()) {
			errorMessage = getTranslation('mobile.createNotificationContent.errors.titleRequired');
			return;
		}

		if (!notificationData.message.trim()) {
			errorMessage = getTranslation('mobile.createNotificationContent.errors.messageRequired');
			return;
		}

		if (notificationData.target_type === 'specific_users' && notificationData.target_users.length === 0) {
			errorMessage = getTranslation('mobile.createNotificationContent.errors.usersRequired');
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			let uploadedFiles: any[] = [];

			// Upload files if present
			if (fileUploadComponent) {
				console.log('📎 [Notification] Uploading files...');
				const uploadResult = await fileUploadComponent.uploadFiles();
				
				if (!uploadResult.success) {
					errorMessage = `${getTranslation('mobile.createNotificationContent.errors.uploadFailed')}: ${uploadResult.errors.join(', ')}`;
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
			const createdByUser = $currentUser?.username || 'madmin';
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
							
							const attachmentResult = await db.notificationAttachments.create(attachmentData);
							
							if (attachmentResult.error) {
								console.error('❌ [Notification] Failed to save attachment:', attachmentResult.error);
							}
						} catch (attachmentError) {
							console.error('❌ [Notification] Error saving attachment:', attachmentError);
						}
					}
				}

				successMessage = getTranslation('mobile.createNotificationContent.success');
				
				// Reset form and navigate back after delay
				setTimeout(() => {
					goto('/mobile/notifications');
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
			target_type: 'specific_users' as 'all_users' | 'specific_users',
			target_users: [] as string[]
		};
		if (fileUploadComponent) {
			fileUploadComponent.clearFiles();
		}
		updateFilteredUsers();
	}

	// Reactive statements - react to specific variable changes
	$: if (userSearchTerm !== undefined || notificationData.target_users) {
		updateFilteredUsers();
	}
</script>

<div class="mobile-create-notification">
	<!-- Success Message -->
	{#if successMessage}
		<div class="success-banner">
			<span class="success-icon">✅</span>
			{successMessage}
		</div>
	{/if}

	<!-- Error Message -->
	{#if errorMessage}
		<div class="error-banner">
			<span class="error-icon">❌</span>
			{errorMessage}
		</div>
	{/if}

	<div class="form-container">
		<!-- Basic Information -->
		<div class="form-section">
			<h2 class="section-title">{getTranslation('mobile.createNotificationContent.basicInformation')}</h2>
			
			<div class="form-group">
				<label for="title" class="form-label">{getTranslation('mobile.createNotificationContent.title')} *</label>
				<input 
					type="text" 
					id="title"
					bind:value={notificationData.title}
					placeholder={getTranslation('mobile.createNotificationContent.titlePlaceholder')}
					class="form-input"
					required
				/>
			</div>

			<div class="form-group">
				<label for="message" class="form-label">{getTranslation('mobile.createNotificationContent.message')} *</label>
				<textarea 
					id="message"
					bind:value={notificationData.message}
					placeholder={getTranslation('mobile.createNotificationContent.messagePlaceholder')}
					class="form-textarea"
					rows="4"
					required
				></textarea>
			</div>

			<div class="form-row">
				<div class="form-group">
					<label for="type" class="form-label">{getTranslation('mobile.createNotificationContent.type')}</label>
					<select id="type" bind:value={notificationData.type} class="form-select">
						<option value="info">{getTranslation('mobile.createNotificationContent.types.info')}</option>
						<option value="success">{getTranslation('mobile.createNotificationContent.types.success')}</option>
						<option value="warning">{getTranslation('mobile.createNotificationContent.types.warning')}</option>
						<option value="error">{getTranslation('mobile.createNotificationContent.types.error')}</option>
						<option value="announcement">{getTranslation('mobile.createNotificationContent.types.announcement')}</option>
					</select>
				</div>

				<div class="form-group">
					<label for="priority" class="form-label">{getTranslation('mobile.createNotificationContent.priority')}</label>
					<select id="priority" bind:value={notificationData.priority} class="form-select">
						<option value="low">{getTranslation('mobile.createNotificationContent.priorities.low')}</option>
						<option value="medium">{getTranslation('mobile.createNotificationContent.priorities.medium')}</option>
						<option value="high">{getTranslation('mobile.createNotificationContent.priorities.high')}</option>
						<option value="urgent">{getTranslation('mobile.createNotificationContent.priorities.urgent')}</option>
					</select>
				</div>
			</div>
		</div>

		<!-- Target Audience -->
		<div class="form-section">
			<h2 class="section-title">{getTranslation('mobile.createNotificationContent.targetAudience')}</h2>
			
			<div class="form-group">
				<label class="form-label">{getTranslation('mobile.createNotificationContent.sendTo')}</label>
				<div class="radio-group" style="display: none;">
					<label class="radio-option">
						<input type="radio" bind:group={notificationData.target_type} value="all_users" />
						<span class="radio-label">{getTranslation('mobile.createNotificationContent.allUsers')}</span>
					</label>
					<label class="radio-option">
						<input type="radio" bind:group={notificationData.target_type} value="specific_users" />
						<span class="radio-label">{getTranslation('mobile.createNotificationContent.specificUsers')}</span>
					</label>
				</div>
			</div>

			{#if notificationData.target_type === 'specific_users'}
				<div class="user-selection">
					<div class="search-header">
						<input 
							type="text" 
							bind:value={userSearchTerm}
							on:input={updateFilteredUsers}
							placeholder={getTranslation('mobile.createNotificationContent.searchPlaceholder')}
							class="search-input"
						/>
						<div class="selection-actions">
							<button type="button" on:click={selectAllUsers} class="select-all-btn">
								{getTranslation('mobile.createNotificationContent.selectAll')}
							</button>
							<button type="button" on:click={deselectAllUsers} class="deselect-all-btn">
								{getTranslation('mobile.createNotificationContent.deselectAll')}
							</button>
						</div>
					</div>

					{#if isLoadingUsers}
						<div class="loading-users">{getTranslation('mobile.createNotificationContent.loadingUsers')}</div>
					{:else}
						<div class="users-list">
							{#each filteredUsers as user (user.id)}
								<label class="user-item">
									<input 
										type="checkbox" 
										checked={user.selected}
										on:change={() => toggleUserSelection(user.id)}
									/>
									<div class="user-info">
										<div class="user-name">{user.employee_name || user.username}</div>
										<div class="user-details">
											{user.username} • {user.position_name || user.role_type}
										</div>
									</div>
								</label>
							{/each}
						</div>

						{#if filteredUsers.length === 0}
							<div class="no-users">{getTranslation('mobile.createNotificationContent.noUsers')}</div>
						{/if}
					{/if}

					{#if notificationData.target_users.length > 0}
						<div class="selected-count">
							{notificationData.target_users.length} {getTranslation('mobile.createNotificationContent.userSelected')}
						</div>
					{/if}
				</div>
			{/if}
		</div>

		<!-- File Attachments -->
		<div class="form-section">
			<h2 class="section-title">{getTranslation('mobile.createNotificationContent.attachments')}</h2>
			<FileUpload
				bind:this={fileUploadComponent}
				acceptedTypes="image/*,application/pdf,.doc,.docx,.txt"
				maxSizeInMB={10}
				bucket="notification-images"
				multiple={true}
				showPreview={true}
				label={getTranslation('mobile.createNotificationContent.fileUpload.label')}
				placeholder={getTranslation('mobile.createNotificationContent.fileUpload.placeholder')}
				hint={getTranslation('mobile.createNotificationContent.fileUpload.hint')}
			/>
		</div>

		<!-- Submit Actions -->
		<div class="form-actions">
			<button 
				type="button" 
				on:click={resetForm} 
				class="reset-btn"
				disabled={isLoading}
			>
				{getTranslation('mobile.createNotificationContent.reset')}
			</button>
			<button 
				type="button" 
				on:click={submitNotification} 
				class="submit-btn"
				disabled={isLoading}
			>
				{#if isLoading}
					{getTranslation('mobile.createNotificationContent.publishing')}
				{:else}
					{getTranslation('mobile.createNotificationContent.publish')}
				{/if}
			</button>
		</div>
	</div>
</div>

<style>
	.mobile-create-notification {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		padding-top: 1rem;
	}

	.success-banner, .error-banner {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 1rem;
		margin: 1rem;
		border-radius: 8px;
		font-size: 0.875rem;
	}

	.success-banner {
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		color: #166534;
	}

	.error-banner {
		background: #FEF2F2;
		border: 1px solid #FECACA;
		color: #DC2626;
	}

	.form-container {
		padding: 1rem;
		max-width: 600px;
		margin: 0 auto;
	}

	.form-section {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 1rem;
		border: 1px solid #E5E7EB;
	}

	.section-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #111827;
		margin: 0 0 1rem 0;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.form-label {
		display: block;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.form-input, .form-textarea, .form-select, .search-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 1rem;
		transition: border-color 0.2s;
	}

	.form-input:focus, .form-textarea:focus, .form-select:focus, .search-input:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.radio-group {
		display: flex;
		gap: 1rem;
	}

	.radio-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
	}

	.radio-label {
		font-size: 0.875rem;
		color: #374151;
	}

	.user-selection {
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		overflow: hidden;
	}

	.search-header {
		padding: 1rem;
		border-bottom: 1px solid #E5E7EB;
		background: #F9FAFB;
	}

	.selection-actions {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.75rem;
	}

	.select-all-btn, .deselect-all-btn {
		padding: 0.5rem 1rem;
		border: 1px solid #D1D5DB;
		border-radius: 6px;
		background: white;
		color: #374151;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.select-all-btn:hover, .deselect-all-btn:hover {
		background: #F3F4F6;
	}

	.users-list {
		max-height: 300px;
		overflow-y: auto;
	}

	.user-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #F3F4F6;
		cursor: pointer;
		transition: background 0.2s;
	}

	.user-item:hover {
		background: #F9FAFB;
	}

	.user-item:last-child {
		border-bottom: none;
	}

	.user-info {
		flex: 1;
	}

	.user-name {
		font-weight: 500;
		color: #111827;
		font-size: 0.875rem;
	}

	.user-details {
		font-size: 0.75rem;
		color: #6B7280;
	}

	.loading-users, .no-users, .selected-count {
		padding: 1rem;
		text-align: center;
		color: #6B7280;
		font-size: 0.875rem;
	}

	.selected-count {
		background: #EFF6FF;
		color: #1D4ED8;
		border-top: 1px solid #E5E7EB;
	}

	.form-actions {
		display: flex;
		gap: 1rem;
		margin-top: 2rem;
	}

	.reset-btn, .submit-btn {
		flex: 1;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
	}

	.reset-btn {
		background: white;
		border: 1px solid #D1D5DB;
		color: #374151;
	}

	.reset-btn:hover:not(:disabled) {
		background: #F3F4F6;
	}

	.submit-btn {
		background: linear-gradient(135deg, #10B981, #059669);
		border: none;
		color: white;
	}

	.submit-btn:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(16, 185, 129, 0.25);
	}

	.reset-btn:disabled, .submit-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
		transform: none;
	}

	/* Mobile optimizations */
	@media (max-width: 640px) {
		.form-row {
			grid-template-columns: 1fr;
		}

		.radio-group {
			flex-direction: column;
		}

		.selection-actions {
			flex-direction: column;
		}

		.form-actions {
			flex-direction: column;
		}
	}
</style>