<script lang="ts">
	import { onMount } from 'svelte';
	import { auth } from '$lib/stores/auth';
	import { notificationManagement } from '$lib/utils/notificationManagement';

	// Current user and role information
	$: currentUser = $auth?.user;
	$: userRole = currentUser?.role || 'Position-based';
	$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

	// Form data
	let notificationData = {
		title: '',
		message: '',
		priority: 'medium' as 'low' | 'medium' | 'high' | 'urgent',
		type: 'info' as 'info' | 'success' | 'warning' | 'error' | 'announcement',
		target_type: 'all_users' as any,
		target_branches: [] as number[],
		target_users: [] as string[],
		target_roles: [] as string[],
		attachment: null as File | null,
		photo: null as File | null
	};

	// Available branches from API
	let branches: Array<{ id: string; name: string }> = [];
	let isLoadingBranches = true;

	// Form state
	let isLoading = false;
	let successMessage = '';
	let errorMessage = '';
	let attachmentInput: HTMLInputElement;
	let cameraInput: HTMLInputElement;

	// Load branches on mount
	onMount(async () => {
		await loadBranches();
	});

	async function loadBranches() {
		try {
			isLoadingBranches = true;
			const branchesData = await notificationManagement.getBranches();
			branches = [
				{ id: 'all', name: 'All Branches' },
				...branchesData
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

	// File handling
	function handleFileUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			if (file.size > 5 * 1024 * 1024) { // 5MB limit
				errorMessage = 'File size must be less than 5MB';
				return;
			}
			
			notificationData.attachment = file;
			errorMessage = '';
		}
	}

	function handleCameraCapture(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			notificationData.photo = file;
			errorMessage = '';
		}
	}

	function removeAttachment() {
		notificationData.attachment = null;
		if (attachmentInput) attachmentInput.value = '';
	}

	function removePhoto() {
		notificationData.photo = null;
		if (cameraInput) cameraInput.value = '';
	}

	async function createNotification() {
		// Validate required fields
		if (!notificationData.title.trim() || !notificationData.message.trim()) {
			errorMessage = 'Title and message are required';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Prepare notification data for API
			const apiData = {
				title: notificationData.title.trim(),
				message: notificationData.message.trim(),
				type: notificationData.type,
				priority: notificationData.priority,
				target_type: notificationData.target_type,
				target_branches: notificationData.target_branches.length > 0 ? notificationData.target_branches : undefined,
				target_users: notificationData.target_users.length > 0 ? notificationData.target_users : undefined,
				target_roles: notificationData.target_roles.length > 0 ? notificationData.target_roles : undefined
			};

			// Create the notification
			const result = await notificationManagement.createNotification(apiData);
			
			if (result.success && result.notification) {
				// Handle file uploads if present
				const notificationId = result.notification.id;
				
				if (notificationData.attachment) {
					try {
						await notificationManagement.uploadAttachment(notificationId, notificationData.attachment);
					} catch (attachmentError) {
						console.error('Error uploading attachment:', attachmentError);
						// Don't fail the whole process for attachment errors
					}
				}

				if (notificationData.photo) {
					try {
						await notificationManagement.uploadAttachment(notificationId, notificationData.photo);
					} catch (photoError) {
						console.error('Error uploading photo:', photoError);
						// Don't fail the whole process for photo errors
					}
				}

				successMessage = 'Notification created successfully!';
				
				// Reset form after delay
				setTimeout(() => {
					resetForm();
					successMessage = '';
				}, 2000);
			} else {
				errorMessage = 'Failed to create notification. Please try again.';
			}

		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Failed to create notification. Please try again.';
			console.error('Create notification error:', error);
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
			target_branches: [],
			target_users: [],
			target_roles: [],
			attachment: null,
			photo: null
		};
		if (attachmentInput) attachmentInput.value = '';
		if (cameraInput) cameraInput.value = '';
	}

	function getFileSize(file: File): string {
		const size = file.size;
		if (size < 1024) return size + ' B';
		if (size < 1024 * 1024) return Math.round(size / 1024) + ' KB';
		return Math.round(size / (1024 * 1024)) + ' MB';
	}
</script>

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
					<select id="target_type" bind:value={notificationData.target_type}>
						<option value="all_users">All Users</option>
						<option value="all_admins">All Admins</option>
						<option value="all_employees">All Employees</option>
						<option value="all_managers">All Managers</option>
						<option value="specific_branches">Specific Branches</option>
						<option value="specific_roles">Specific Roles</option>
						<option value="specific_users">Specific Users</option>
					</select>
				</div>

				{#if notificationData.target_type === 'specific_branches'}
					<div class="form-group">
						<label for="branches">Target Branches</label>
						{#if isLoadingBranches}
							<p class="loading-text">Loading branches...</p>
						{:else}
							<div class="multi-select">
								{#each branches as branch}
									{#if branch.id !== 'all'}
										<label class="checkbox-option">
											<input 
												type="checkbox" 
												bind:group={notificationData.target_branches} 
												value={parseInt(branch.id)}
											/>
											{branch.name}
										</label>
									{/if}
								{/each}
							</div>
						{/if}
					</div>
				{/if}

				{#if notificationData.target_type === 'specific_roles'}
					<div class="form-group">
						<label for="roles">Target Roles</label>
						<div class="multi-select">
							<label class="checkbox-option">
								<input type="checkbox" bind:group={notificationData.target_roles} value="Admin" />
								Admin
							</label>
							<label class="checkbox-option">
								<input type="checkbox" bind:group={notificationData.target_roles} value="Manager" />
								Manager
							</label>
							<label class="checkbox-option">
								<input type="checkbox" bind:group={notificationData.target_roles} value="Employee" />
								Employee
							</label>
							<label class="checkbox-option">
								<input type="checkbox" bind:group={notificationData.target_roles} value="Position-based" />
								Position-based
							</label>
						</div>
					</div>
				{/if}
			</div>

			<!-- Attachments -->
			<div class="form-section">
				<h3 class="section-title">Attachments (Optional)</h3>
				
				<div class="attachment-controls">
					<!-- File Upload -->
					<div class="upload-group">
						<label class="upload-btn">
							<input 
								type="file" 
								bind:this={attachmentInput}
								on:change={handleFileUpload}
								accept="image/*,application/pdf,.doc,.docx,.txt"
								hidden
							/>
							📎 Upload File
						</label>
						{#if notificationData.attachment}
							<div class="file-preview">
								<span class="file-name">{notificationData.attachment.name}</span>
								<span class="file-size">({getFileSize(notificationData.attachment)})</span>
								<button type="button" class="remove-btn" on:click={removeAttachment}>×</button>
							</div>
						{/if}
					</div>

					<!-- Camera Capture -->
					<div class="upload-group">
						<label class="upload-btn camera-btn">
							<input 
								type="file" 
								bind:this={cameraInput}
								on:change={handleCameraCapture}
								accept="image/*"
								capture="environment"
								hidden
							/>
							📷 Take Photo
						</label>
						{#if notificationData.photo}
							<div class="file-preview">
								<span class="file-name">{notificationData.photo.name}</span>
								<span class="file-size">({getFileSize(notificationData.photo)})</span>
								<button type="button" class="remove-btn" on:click={removePhoto}>×</button>
							</div>
						{/if}
					</div>
				</div>
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
						📤 Send Notification
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

	.attachment-controls {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.upload-group {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 16px;
		background: #f9fafb;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		color: #374151;
		transition: all 0.2s;
		width: fit-content;
	}

	.upload-btn:hover {
		background: #f3f4f6;
		border-color: #10b981;
	}

	.camera-btn {
		background: #eff6ff;
		border-color: #3b82f6;
		color: #1e40af;
	}

	.camera-btn:hover {
		background: #dbeafe;
	}

	.file-preview {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 12px;
		background: #f0fdf4;
		border: 1px solid #10b981;
		border-radius: 6px;
		font-size: 13px;
	}

	.file-name {
		color: #065f46;
		font-weight: 500;
	}

	.file-size {
		color: #6b7280;
	}

	.remove-btn {
		background: #ef4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 20px;
		height: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 12px;
		margin-left: auto;
	}

	.multi-select {
		display: flex;
		flex-direction: column;
		gap: 8px;
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		background: white;
		max-height: 150px;
		overflow-y: auto;
	}

	.checkbox-option {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 14px;
		color: #374151;
		cursor: pointer;
	}

	.checkbox-option input[type="checkbox"] {
		width: auto;
		margin: 0;
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
</style>