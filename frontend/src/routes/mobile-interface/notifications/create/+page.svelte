<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notificationManagement } from '$lib/utils/notificationManagement';
	import { supabase, db } from '$lib/utils/supabase';
	import { uploadToSupabase } from '$lib/utils/supabase';
	import { getTranslation, currentLocale } from '$lib/i18n';

	// Current user and role information
	$: userRole = $currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Remove admin restriction - accessible to all users
	// $: if (!isAdminOrMaster) {
	// 	goto('/mobile-interface/notifications');
	// }

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
	let cameraInput: HTMLInputElement;
	let fileInput: HTMLInputElement;
	let attachedFiles: File[] = [];
	let previewUrls: string[] = [];

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
	let showUserPopup = false;

	function handleFilesSelected(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = Array.from(target.files || []);
		for (const file of files) {
			if (file.size > 10 * 1024 * 1024) continue;
			attachedFiles = [...attachedFiles, file];
			if (file.type.startsWith('image/')) {
				const reader = new FileReader();
				reader.onload = (e) => {
					if (e.target?.result) previewUrls = [...previewUrls, e.target.result as string];
				};
				reader.readAsDataURL(file);
			} else {
				previewUrls = [...previewUrls, ''];
			}
		}
		target.value = '';
	}

	function removeAttachedFile(index: number) {
		attachedFiles = attachedFiles.filter((_, i) => i !== index);
		previewUrls = previewUrls.filter((_, i) => i !== index);
	}

	function getFileIcon(type: string): string {
		if (type.startsWith('image/')) return '🖼️';
		if (type.includes('pdf')) return '📄';
		if (type.includes('doc')) return '📝';
		return '📎';
	}

	async function uploadAttachedFiles(): Promise<{success: boolean, uploadedFiles: any[], errors: string[]}> {
		if (attachedFiles.length === 0) return { success: true, uploadedFiles: [], errors: [] };
		const uploadedFileData: any[] = [];
		const uploadErrors: string[] = [];
		for (const file of attachedFiles) {
			const ext = file.name.split('.').pop() || 'bin';
			const uniqueName = `file-${Date.now()}-${Math.random().toString(36).substring(2)}.${ext}`;
			try {
				const result = await uploadToSupabase(file, 'notification-images', uniqueName);
				if (result.error) { uploadErrors.push(`${file.name}: ${result.error.message}`); }
				else { uploadedFileData.push({ fileName: file.name, filePath: uniqueName, fileSize: file.size, fileType: file.type, fileUrl: result.data?.publicUrl || '', originalFile: file }); }
			} catch { uploadErrors.push(`${file.name}: Upload failed`); }
		}
		return { success: uploadErrors.length === 0, uploadedFiles: uploadedFileData, errors: uploadErrors };
	}

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
					employee_id,
					branch_id,
					hr_employees!users_employee_id_fkey(
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
					role_type: 'Employee', // Default role type since column doesn't exist
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
					role_type: 'Employee',
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
			if (attachedFiles.length > 0) {
				console.log('📎 [Notification] Uploading files...');
				const uploadResult = await uploadAttachedFiles();
				
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
					goto('/mobile-interface/notifications');
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
		attachedFiles = [];
		previewUrls = [];
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
			
			<button type="button" class="audience-trigger-btn" on:click={() => showUserPopup = true}>
				<span class="audience-trigger-icon">👥</span>
				<span class="audience-trigger-text">
					{#if notificationData.target_users.length > 0}
						{notificationData.target_users.length} {getTranslation('mobile.createNotificationContent.userSelected')}
					{:else}
						{getTranslation('mobile.createNotificationContent.sendTo')}
					{/if}
				</span>
				<span class="audience-trigger-arrow">›</span>
			</button>
		</div>

		<!-- File Attachments -->
		<div class="form-section">
			<h2 class="section-title">{getTranslation('mobile.createNotificationContent.attachments')}</h2>
			<div class="attach-buttons">
				<button type="button" class="attach-btn" on:click={() => cameraInput?.click()}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
						<circle cx="12" cy="13" r="4"/>
					</svg>
					<span>{getTranslation('mobile.createNotificationContent.publish') === 'Publish' ? 'Camera' : 'كاميرا'}</span>
				</button>
				<button type="button" class="attach-btn" on:click={() => fileInput?.click()}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>
					</svg>
					<span>{getTranslation('mobile.createNotificationContent.publish') === 'Publish' ? 'File' : 'ملف'}</span>
				</button>
			</div>

			<!-- Hidden inputs -->
			<input bind:this={cameraInput} type="file" accept="image/*" capture="environment" multiple on:change={handleFilesSelected} style="display:none" />
			<input bind:this={fileInput} type="file" accept="image/*,application/pdf,.doc,.docx,.txt" multiple on:change={handleFilesSelected} style="display:none" />

			<!-- Attached files preview -->
			{#if attachedFiles.length > 0}
				<div class="attached-files-list">
					{#each attachedFiles as file, index}
						<div class="attached-file-item">
							{#if file.type.startsWith('image/') && previewUrls[index]}
								<img src={previewUrls[index]} alt="Preview" class="attached-thumb" />
							{:else}
								<span class="attached-icon">{getFileIcon(file.type)}</span>
							{/if}
							<span class="attached-name">{file.name}</span>
							<button type="button" class="attached-remove" on:click={() => removeAttachedFile(index)}>✕</button>
						</div>
					{/each}
				</div>
			{/if}
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

<!-- User Selection Popup (outside main container to escape overflow clipping) -->
{#if showUserPopup}
	<div class="popup-overlay" on:click|self={() => showUserPopup = false}>
		<div class="popup-container">
			<div class="popup-header">
				<h3 class="popup-title">{getTranslation('mobile.createNotificationContent.targetAudience')}</h3>
				<button type="button" class="popup-close-btn" on:click={() => showUserPopup = false}>✕</button>
			</div>

			<div class="popup-search">
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

			<div class="popup-body">
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
			</div>

			<div class="popup-footer">
				{#if notificationData.target_users.length > 0}
					<span class="selected-count-text">{notificationData.target_users.length} {getTranslation('mobile.createNotificationContent.userSelected')}</span>
				{/if}
				<button type="button" class="popup-done-btn" on:click={() => showUserPopup = false}>
					✓ {getTranslation('mobile.createNotificationContent.publish') === 'Publish' ? 'Done' : 'تم'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.mobile-create-notification {
		min-height: 100%;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		padding-top: 0.4rem;
	}

	.success-banner, .error-banner {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem;
		margin: 0.4rem;
		border-radius: 5px;
		font-size: 0.76rem;
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
		padding: 0.4rem;
		max-width: 600px;
		margin: 0 auto;
	}

	.form-section {
		background: white;
		border-radius: 6px;
		padding: 0.5rem;
		margin-bottom: 0.5rem;
		border: 1px solid #E5E7EB;
	}

	.section-title {
		font-size: 0.82rem;
		font-weight: 600;
		color: #111827;
		margin: 0 0 0.4rem 0;
	}

	.form-group {
		margin-bottom: 0.5rem;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.5rem;
	}

	.form-label {
		display: block;
		font-size: 0.76rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.25rem;
	}

	.form-input, .form-textarea, .form-select, .search-input {
		width: 100%;
		padding: 0.4rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.78rem;
		transition: border-color 0.2s;
	}

	.form-input:focus, .form-textarea:focus, .form-select:focus, .search-input:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	/* Audience trigger button */
	.audience-trigger-btn {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		background: white;
		cursor: pointer;
		transition: all 0.2s;
		font-size: 0.78rem;
		color: #374151;
	}

	.audience-trigger-btn:hover {
		background: #F9FAFB;
		border-color: #3B82F6;
	}

	.audience-trigger-icon {
		font-size: 1rem;
	}

	.audience-trigger-text {
		flex: 1;
		text-align: start;
	}

	.audience-trigger-arrow {
		font-size: 1.1rem;
		color: #9CA3AF;
		font-weight: 600;
	}

	/* Popup overlay & container */
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1100;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		animation: fadeIn 0.2s ease;
	}

	.popup-container {
		background: white;
		border-radius: 12px 12px 0 0;
		width: 100%;
		max-width: 600px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		animation: slideUp 0.25s ease;
	}

	.popup-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.6rem 0.75rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.popup-title {
		font-size: 0.85rem;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.popup-close-btn {
		background: none;
		border: none;
		font-size: 1rem;
		color: #6B7280;
		cursor: pointer;
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
	}

	.popup-close-btn:hover {
		background: #F3F4F6;
	}

	.popup-search {
		padding: 0.4rem 0.5rem;
		border-bottom: 1px solid #E5E7EB;
		background: #F9FAFB;
	}

	.selection-actions {
		display: flex;
		gap: 0.3rem;
		margin-top: 0.4rem;
	}

	.select-all-btn, .deselect-all-btn {
		padding: 0.3rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 4px;
		background: white;
		color: #374151;
		font-size: 0.72rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.select-all-btn:hover, .deselect-all-btn:hover {
		background: #F3F4F6;
	}

	.popup-body {
		flex: 1;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.users-list {
		max-height: none;
		overflow-y: visible;
	}

	.user-item {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem 0.6rem;
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
		font-size: 0.76rem;
	}

	.user-details {
		font-size: 0.68rem;
		color: #6B7280;
	}

	.loading-users, .no-users {
		padding: 0.6rem;
		text-align: center;
		color: #6B7280;
		font-size: 0.72rem;
	}

	.popup-footer {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.5rem 0.75rem;
		border-top: 1px solid #E5E7EB;
		background: #F9FAFB;
		padding-bottom: calc(0.5rem + env(safe-area-inset-bottom, 0px));
	}

	.selected-count-text {
		font-size: 0.74rem;
		color: #1D4ED8;
		font-weight: 500;
	}

	.popup-done-btn {
		padding: 0.4rem 1rem;
		background: linear-gradient(135deg, #3B82F6, #2563EB);
		color: white;
		border: none;
		border-radius: 5px;
		font-size: 0.76rem;
		font-weight: 500;
		cursor: pointer;
		min-height: 34px;
	}

	.popup-done-btn:hover {
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes slideUp {
		from { transform: translateY(100%); }
		to { transform: translateY(0); }
	}

	/* Attachment buttons */
	.attach-buttons {
		display: flex;
		gap: 0.4rem;
	}

	.attach-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.6rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		background: white;
		color: #374151;
		font-size: 0.72rem;
		cursor: pointer;
		transition: all 0.2s;
		min-height: 32px;
	}

	.attach-btn:hover {
		background: #F3F4F6;
		border-color: #3B82F6;
	}

	.attach-btn svg {
		color: #6B7280;
		flex-shrink: 0;
	}

	.attached-files-list {
		margin-top: 0.4rem;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.attached-file-item {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.3rem 0.4rem;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 4px;
		font-size: 0.72rem;
	}

	.attached-thumb {
		width: 28px;
		height: 28px;
		object-fit: cover;
		border-radius: 3px;
		flex-shrink: 0;
	}

	.attached-icon {
		font-size: 0.9rem;
		flex-shrink: 0;
	}

	.attached-name {
		flex: 1;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		color: #374151;
	}

	.attached-remove {
		background: none;
		border: none;
		color: #EF4444;
		font-size: 0.8rem;
		cursor: pointer;
		padding: 0.1rem 0.3rem;
		border-radius: 3px;
		flex-shrink: 0;
	}

	.attached-remove:hover {
		background: #FEE2E2;
	}

	.form-actions {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.5rem;
	}

	.reset-btn, .submit-btn {
		flex: 1;
		padding: 0.5rem 0.75rem;
		border-radius: 5px;
		font-size: 0.78rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		min-height: 36px;
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

		.selection-actions {
			flex-direction: column;
		}

		.form-actions {
			flex-direction: column;
		}
	}
</style>
