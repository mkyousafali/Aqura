<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase, db } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';

	// Get task ID from URL params
	let taskId = '';
	let isLoading = true;
	let isSubmitting = false;
	let errorMessage = '';
	let successMessage = '';

	// Task and assignment data
	let taskDetails: any = null;
	let assignmentDetails: any = null;
	let taskFiles: any[] = [];
	let assignedByUserName = '';
	let assignedToUserName = '';

	// Live countdown state
	let liveCountdown = '';
	let countdownInterval: NodeJS.Timeout | null = null;

	// Current user
	$: currentUserData = $currentUser;

	// Resolve requirement flags from assignment details first, then task object (same as regular tasks)
	$: resolvedRequireTaskFinished = assignmentDetails?.require_task_finished ?? taskDetails?.require_task_finished ?? true;
	$: resolvedRequirePhotoUpload = assignmentDetails?.require_photo_upload ?? taskDetails?.require_photo_upload ?? false;
	$: resolvedRequireErpReference = assignmentDetails?.require_erp_reference ?? taskDetails?.require_erp_reference ?? false;

	// Completion form data (expanded to match regular tasks)
	let completionData = {
		task_finished_completed: false,
		photo_uploaded_completed: false,
		erp_reference_completed: false,
		erp_reference_number: '',
		completion_notes: ''
	};

	// Photo upload (add photo upload functionality)
	let photoFile: File | null = null;
	let photoPreview: string | null = null;

	// UI state
	let showTaskDetails = false;

	// Calculate completion progress
	$: completionProgress = (() => {
		let completed = 0;
		let total = 0;

		if (resolvedRequireTaskFinished) {
			total++;
			if (completionData.task_finished_completed) completed++;
		}

		if (resolvedRequirePhotoUpload) {
			total++;
			if (photoFile && completionData.photo_uploaded_completed) completed++;
		}

		if (resolvedRequireErpReference) {
			total++;
			if (completionData.erp_reference_number?.trim() && completionData.erp_reference_completed) completed++;
		}

		return total > 0 ? Math.round((completed / total) * 100) : 0;
	})();

	// Check if form can be submitted
	$: canSubmit = (() => {
		// Check if task is assigned to current user
		if (!assignmentDetails) return false;
		
		// Check if assignment belongs to current user
		if (assignmentDetails.assigned_to_user_id !== currentUserData?.id) return false;
		
		// Check completion requirements
		const taskCheck = !resolvedRequireTaskFinished || completionData.task_finished_completed;
		const photoCheck = !resolvedRequirePhotoUpload || (!!photoFile && completionData.photo_uploaded_completed);
		const erpCheck = !resolvedRequireErpReference || (!!completionData.erp_reference_number?.trim() && completionData.erp_reference_completed);
		
		return taskCheck && photoCheck && erpCheck;
	})();

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

	onDestroy(() => {
		stopCountdownTimer();
	});

	async function loadTaskDetails() {
		try {
			isLoading = true;
			
			if (!taskId || taskId === 'unknown' || taskId === 'null') {
				errorMessage = 'Invalid task ID';
				return;
			}
			
			// Load quick task details
			const { data: taskData, error: taskError } = await supabase
				.from('quick_tasks')
				.select('*')
				.eq('id', taskId)
				.single();

			if (taskError) {
				console.error('Error loading quick task:', taskError);
				errorMessage = 'Failed to load task details';
				return;
			}

			taskDetails = taskData;
			
			console.log('📋 [Mobile Complete] Task Details:', taskDetails);
			
			// Load quick task files
			const { data: filesData, error: filesError } = await supabase
				.from('quick_task_files')
				.select('*')
				.eq('quick_task_id', taskId);

			if (!filesError && filesData) {
				taskFiles = filesData.map(file => ({
					id: file.id,
					fileName: file.file_name || 'Unknown File',
					fileSize: file.file_size || 0,
					fileType: file.file_type || 'application/octet-stream',
					fileUrl: file.file_url || '',
					uploadedBy: file.uploaded_by_name || 'Unknown',
					uploadedAt: file.created_at
				}));
			}
			
			// Find assignment for current user
			const { data: assignments, error: assignmentError } = await supabase
				.from('quick_task_assignments')
				.select('*')
				.eq('quick_task_id', taskId)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('created_at', { ascending: false })
				.limit(1);

			if (assignmentError) {
				console.error('Error loading assignment:', assignmentError);
			} else if (assignments && assignments.length > 0) {
				assignmentDetails = assignments[0];
				
				console.log('📋 [Mobile Complete] Assignment Details:', assignmentDetails);
				console.log('🎯 [Mobile Complete] Requirements from assignment:', {
					require_photo_upload: assignmentDetails.require_photo_upload,
					require_erp_reference: assignmentDetails.require_erp_reference,
					require_task_finished: assignmentDetails.require_task_finished
				});
				
				// Get assigned by user name
				if (taskDetails.assigned_by) {
					const assignedByResult = await db.users.getById(taskDetails.assigned_by);
					if (assignedByResult.data) {
						if (assignedByResult.data.employee_id) {
							const employeeResult = await db.employees.getById(assignedByResult.data.employee_id);
							if (employeeResult.data && employeeResult.data.name) {
								assignedByUserName = employeeResult.data.name;
							} else {
								assignedByUserName = assignedByResult.data.username || 'Unknown User';
							}
						} else {
							assignedByUserName = assignedByResult.data.username || 'Unknown User';
						}
					} else {
						assignedByUserName = 'Unknown User';
					}
				}
				
				// Set assigned to user name
				assignedToUserName = currentUserData.username || 'Unknown User';
				
				// Start the live countdown timer
				startCountdownTimer();
			}
			
		} catch (error) {
			console.error('Error loading task details:', error);
			errorMessage = 'Failed to load task details';
		} finally {
			isLoading = false;
		}
	}

	// Date and time utility functions
	function formatDate(dateString: string): string {
		if (!dateString) return 'Not set';
		try {
			return new Date(dateString).toLocaleDateString('en-US', {
				year: 'numeric',
				month: 'short',
				day: 'numeric'
			});
		} catch {
			return 'Invalid date';
		}
	}

	function formatTime(datetimeString: string): string {
		if (!datetimeString) return '';
		try {
			return new Date(datetimeString).toLocaleTimeString('en-US', {
				hour: '2-digit',
				minute: '2-digit'
			});
		} catch {
			return '';
		}
	}

	function isOverdue(deadlineString: string): boolean {
		if (!deadlineString) return false;
		try {
			return new Date(deadlineString) < new Date();
		} catch {
			return false;
		}
	}

	function getOverdueTime(deadlineString: string): string {
		if (!deadlineString) return '';
		try {
			const deadline = new Date(deadlineString);
			const now = new Date();
			const diffMs = now.getTime() - deadline.getTime();
			const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
			const diffDays = Math.floor(diffHours / 24);
			
			if (diffDays > 0) {
				return `${diffDays} day${diffDays !== 1 ? 's' : ''}`;
			} else {
				return `${diffHours} hour${diffHours !== 1 ? 's' : ''}`;
			}
		} catch {
			return 'Unknown';
		}
	}

	function getTimeUntilDeadline(deadlineString: string): string {
		if (!deadlineString) return '';
		try {
			const deadline = new Date(deadlineString);
			const now = new Date();
			const diffMs = deadline.getTime() - now.getTime();
			
			if (diffMs <= 0) {
				return 'Overdue';
			}
			
			const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
			const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
			const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
			
			let timeString = '';
			if (days > 0) {
				timeString += `${days} day${days !== 1 ? 's' : ''}`;
			}
			if (hours > 0) {
				if (timeString) timeString += ', ';
				timeString += `${hours} hour${hours !== 1 ? 's' : ''}`;
			}
			if (minutes > 0 || timeString === '') {
				if (timeString) timeString += ', ';
				timeString += `${minutes} minute${minutes !== 1 ? 's' : ''}`;
			}
			
			return timeString;
		} catch {
			return 'Unknown';
		}
	}

	function updateLiveCountdown() {
		const deadlineString = taskDetails?.deadline_datetime;
		if (deadlineString) {
			liveCountdown = getTimeUntilDeadline(deadlineString);
		} else {
			liveCountdown = '';
		}
	}

	function startCountdownTimer() {
		if (countdownInterval) {
			clearInterval(countdownInterval);
		}
		
		updateLiveCountdown();
		countdownInterval = setInterval(updateLiveCountdown, 60000);
	}

	function stopCountdownTimer() {
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
	}

	function getPriorityColor(priority: string): string {
		switch (priority?.toLowerCase()) {
			case 'high':
			case 'urgent':
				return 'priority-high';
			case 'medium':
				return 'priority-medium';
			case 'low':
				return 'priority-low';
			default:
				return 'priority-medium';
		}
	}

	function formatIssueType(issueType: string): string {
		if (!issueType) return 'Not specified';
		return issueType.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase());
	}

	function formatPriceTag(priceTag: string): string {
		if (!priceTag) return 'Not specified';
		return priceTag.toUpperCase();
	}

	// File download function
	async function downloadFile(fileUrl: string, fileName: string) {
		try {
			const response = await fetch(fileUrl);
			if (!response.ok) throw new Error('Download failed');
			
			const blob = await response.blob();
			const url = window.URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = fileName;
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
			window.URL.revokeObjectURL(url);
		} catch (error) {
			console.error('Download error:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to download file',
				duration: 3000
			});
		}
	}
	
	async function handlePhotoUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			if (!file.type.startsWith('image/')) {
				errorMessage = 'Please select a valid image file';
				return;
			}
			
			if (file.size > 5 * 1024 * 1024) {
				errorMessage = 'Image file must be less than 5MB';
				return;
			}
			
			photoFile = file;
			
			const reader = new FileReader();
			reader.onload = (e) => {
				photoPreview = e.target?.result as string;
			};
			reader.readAsDataURL(file);
			
			completionData.photo_uploaded_completed = true;
			errorMessage = '';
		}
	}
	
	function removePhoto() {
		photoFile = null;
		photoPreview = null;
		completionData.photo_uploaded_completed = false;
		
		const fileInput = document.getElementById('photo-upload') as HTMLInputElement;
		if (fileInput) {
			fileInput.value = '';
		}
	}
	
	async function uploadPhoto(): Promise<string | null> {
		if (!photoFile || !currentUserData) return null;
		
		try {
			const fileExt = photoFile.name.split('.').pop();
			const fileName = `quick-task-completion-${assignmentDetails.id}-${Date.now()}.${fileExt}`;
			
			const { data, error } = await supabase.storage
				.from('completion-photos')
				.upload(fileName, photoFile, {
					cacheControl: '3600',
					upsert: false
				});
			
			if (error) {
				console.error('Storage upload error:', error);
				return null;
			}
			
			// Return just the file path, not the full URL
			return data.path;
		} catch (error) {
			console.error('Error uploading photo:', error);
			return null;
		}
	}
	
	async function submitCompletion() {
		if (!currentUserData || !canSubmit) return;
		
		isSubmitting = true;
		errorMessage = '';
		successMessage = '';
		
		try {
			let photoPath = null;
			
			// Upload photo if required and provided
			if (resolvedRequirePhotoUpload && photoFile) {
				try {
					photoPath = await uploadPhoto();
					if (!photoPath) {
						errorMessage = 'Photo upload failed. Please try again.';
						return;
					}
				} catch (uploadError) {
					console.error('Photo upload failed:', uploadError);
					errorMessage = 'Photo upload failed. Please try again.';
					return;
				}
			}
			
			// Create completion record using the submit_quick_task_completion function
			try {
				const { data: completionId, error } = await supabase.rpc('submit_quick_task_completion', {
					p_assignment_id: assignmentDetails.id,
					p_user_id: currentUserData.id,
					p_completion_notes: completionData.completion_notes || null,
					p_photos: photoPath ? [photoPath] : null,
					p_erp_reference: completionData.erp_reference_number || null
				});
				
				if (error) {
					console.error('Error submitting completion:', error);
					throw error;
				}
				
				console.log('✅ Quick task completion submitted successfully:', completionId);
			} catch (completionError) {
				console.error('Error creating quick task completion:', completionError);
				throw completionError;
			}
			
			successMessage = 'Quick Task completed successfully!';
			
			notifications.add({
				type: 'success',
				message: 'Quick Task completed successfully!',
				duration: 3000
			});
			
			setTimeout(() => {
				goto('/mobile/assignments');
			}, 2000);
			
		} catch (error) {
			console.error('Error submitting completion:', error);
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
</script>

<svelte:head>
	<title>Complete Quick Task - Aqura Mobile</title>
</svelte:head>

<div class="mobile-task-completion">
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
			<h2>Quick Task Not Found</h2>
			<p>This quick task doesn't exist or you don't have access to it.</p>
		</div>
	{:else if !assignmentDetails || assignmentDetails.assigned_to_user_id !== currentUserData?.id}
		<div class="error-state">
			<div class="error-icon">
				<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<path d="M18.364 5.636L12 12m0 0l-6.364 6.364M12 12l6.364 6.364M12 12L5.636 5.636"/>
				</svg>
			</div>
			<h2>Access Denied</h2>
			<p>This quick task is not assigned to you. Only assigned users can complete tasks.</p>
			<div class="error-actions">
				<button class="back-btn" on:click={() => goto('/mobile/assignments')}>
					← Back to Assignments
				</button>
			</div>
		</div>
	{:else}
		<!-- Task Details Section -->
		<div class="task-details-section">
			<div class="details-header">
				<h3>⚡ Quick Task Details</h3>
				<button 
					class="toggle-btn"
					on:click={() => showTaskDetails = !showTaskDetails}
				>
					{showTaskDetails ? '▼' : '▶'} {showTaskDetails ? 'Hide' : 'Show'} Details
				</button>
			</div>

			{#if showTaskDetails && taskDetails}
				<div class="details-content">
					<div class="detail-grid">
						<div class="detail-item">
							<span class="detail-label">📝 Title:</span>
							<span class="value">{taskDetails.title}</span>
						</div>
						
						<div class="detail-item">
							<span class="detail-label">🎯 Priority:</span>
							<span class="priority-badge {getPriorityColor(taskDetails.priority)}">
								{taskDetails.priority?.toUpperCase() || 'MEDIUM'}
							</span>
						</div>

						<div class="detail-item">
							<span class="detail-label">🏷️ Price Tag:</span>
							<span class="value">{formatPriceTag(taskDetails.price_tag)}</span>
						</div>

						<div class="detail-item">
							<span class="detail-label">🔧 Issue Type:</span>
							<span class="value">{formatIssueType(taskDetails.issue_type)}</span>
						</div>
						
						<div class="detail-item">
							<span class="detail-label">📅 Created:</span>
							<span class="value">{formatDate(taskDetails.created_at)}</span>
						</div>
						
						<div class="detail-item">
							<span class="detail-label">⏰ Deadline:</span>
							<span class="value">
								{#if taskDetails.deadline_datetime}
									{formatDate(taskDetails.deadline_datetime)} at {formatTime(taskDetails.deadline_datetime)}
								{:else}
									No deadline set
								{/if}
							</span>
						</div>

						{#if taskDetails.deadline_datetime}
							<div class="detail-item">
								<span class="detail-label">⚠️ Status:</span>
								<span class="value {isOverdue(taskDetails.deadline_datetime) ? 'overdue' : 'on-time'}">
									{#if isOverdue(taskDetails.deadline_datetime)}
										Overdue by {getOverdueTime(taskDetails.deadline_datetime)}
									{:else}
										{liveCountdown} remaining
									{/if}
								</span>
							</div>
						{/if}

						<div class="detail-item">
							<span class="detail-label">📌 Assigned to:</span>
							<span class="value">{assignedToUserName}</span>
						</div>
						
						<div class="detail-item">
							<span class="detail-label">👤 Assigned by:</span>
							<span class="value">{assignedByUserName}</span>
						</div>
					</div>

					{#if taskDetails.description}
						<div class="description-block">
							<span class="detail-label">📄 Description:</span>
							<div class="description-text">{taskDetails.description}</div>
						</div>
					{/if}

					{#if taskFiles.length > 0}
						<div class="attachments-section">
							<span class="detail-label">📎 Task Files:</span>
							<div class="attachments-list">
								{#each taskFiles as file}
									<div class="attachment-item">
										<div class="attachment-info">
											<div class="attachment-name">{file.fileName}</div>
											<div class="attachment-meta">
												{#if file.fileSize}
													{Math.round(file.fileSize / 1024)} KB • 
												{/if}
												{file.uploadedBy}
											</div>
										</div>
										<button 
											class="download-btn"
											on:click={() => downloadFile(file.fileUrl, file.fileName)}
											aria-label="Download {file.fileName}"
										>
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
												<polyline points="7,10 12,15 17,10"/>
												<line x1="12" y1="15" x2="12" y2="3"/>
											</svg>
										</button>
									</div>
								{/each}
							</div>
						</div>
					{/if}
				</div>
			{/if}
		</div>

		<!-- Progress Bar -->
		<div class="progress-section">
			<div class="progress-label">
				Completion Progress: {completionProgress}%
			</div>
			<div class="progress-bar">
				<div class="progress-fill" style="width: {completionProgress}%"></div>
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

		<!-- Completion Requirements -->
		<div class="requirements-section">
			<h4>Completion Requirements:</h4>
			
			{#if resolvedRequireTaskFinished}
				<div class="requirement-item">
					<div class="requirement-header">
						<span class="requirement-label required">✅ Task Finished (Required)</span>
						<input
							type="checkbox"
							bind:checked={completionData.task_finished_completed}
							disabled={isSubmitting}
							class="requirement-checkbox"
						/>
					</div>
				</div>
			{/if}
			
			{#if resolvedRequirePhotoUpload}
				<div class="requirement-item">
					<div class="requirement-header">
						<span class="requirement-label required">📷 Upload Photo (Required)</span>
					</div>
					
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
									<path d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
								</svg>
								Choose Photo
							</label>
						</div>
					{:else}
						<div class="photo-preview">
							<img src={photoPreview} alt="Task completion" class="preview-image" />
							<button class="remove-photo" on:click={removePhoto} disabled={isSubmitting}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M18 6L6 18M6 6l12 12"/>
								</svg>
							</button>
						</div>
					{/if}
				</div>
			{/if}
			
			{#if resolvedRequireErpReference}
				<div class="requirement-item">
					<div class="requirement-header">
						<span class="requirement-label required">🔢 ERP Reference (Required)</span>
					</div>
					
					<div class="input-section">
						<input
							type="text"
							bind:value={completionData.erp_reference_number}
							on:input={() => {
								// Auto-check completion when user enters ERP reference
								completionData.erp_reference_completed = !!completionData.erp_reference_number?.trim();
							}}
							placeholder="Enter ERP reference number"
							disabled={isSubmitting}
							class="erp-input"
							required
						/>
					</div>
				</div>
			{/if}
			
			<div class="requirement-item">
				<div class="requirement-header">
					<span class="requirement-label">📝 Additional Notes (Optional)</span>
				</div>
				
				<div class="input-section">
					<textarea
						bind:value={completionData.completion_notes}
						placeholder="Add any additional notes about the task completion..."
						disabled={isSubmitting}
						class="notes-textarea"
					></textarea>
				</div>
			</div>
		</div>

		<!-- Actions -->
		<div class="actions">
			<button class="cancel-btn" on:click={() => goto('/mobile/assignments')} disabled={isSubmitting}>
				Cancel
			</button>
			<button 
				class="complete-btn" 
				on:click={submitCompletion} 
				disabled={!canSubmit || isSubmitting}
				class:disabled={!canSubmit}
			>
				{#if isSubmitting}
					<div class="btn-spinner"></div>
					Completing...
				{:else}
					Complete Quick Task
				{/if}
			</button>
		</div>
	{/if}
</div>

<style>
	.mobile-task-completion {
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

	.task-details-section {
		background: white;
		margin: 1rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
		overflow: hidden;
	}

	.details-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1rem 1.5rem;
		background: #F9FAFB;
		border-bottom: 1px solid #E5E7EB;
	}

	.details-header h3 {
		margin: 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
	}

	.toggle-btn {
		background: none;
		border: none;
		padding: 0.5rem;
		cursor: pointer;
		color: #6B7280;
		font-size: 0.875rem;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.toggle-btn:hover {
		background: #E5E7EB;
		color: #374151;
	}

	.details-content {
		padding: 1.5rem;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.detail-item {
		background: #F9FAFB;
		padding: 1rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.detail-item span.detail-label {
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
		display: block;
		font-size: 0.875rem;
	}

	.detail-item .value {
		color: #1F2937;
		font-size: 0.875rem;
	}

	.priority-badge {
		display: inline-block;
		padding: 0.25rem 0.75rem;
		border-radius: 1rem;
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.priority-high {
		background: #FEE2E2;
		color: #DC2626;
	}

	.priority-medium {
		background: #FEF3C7;
		color: #D97706;
	}

	.priority-low {
		background: #D1FAE5;
		color: #059669;
	}

	.overdue {
		color: #DC2626;
		font-weight: 600;
	}

	.on-time {
		color: #16A34A;
		font-weight: 500;
	}

	.description-block {
		margin-top: 1.5rem;
	}

	.description-block .detail-label {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	.description-text {
		background: #F9FAFB;
		padding: 1rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
		white-space: pre-wrap;
		color: #1F2937;
		line-height: 1.6;
		font-size: 0.875rem;
	}

	.attachments-section {
		margin-top: 1.5rem;
	}

	.attachments-section .detail-label {
		display: block;
		font-size: 0.875rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.75rem;
	}

	.attachments-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.attachment-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
	}

	.attachment-info {
		flex: 1;
	}

	.attachment-name {
		font-weight: 500;
		color: #1F2937;
		font-size: 0.875rem;
	}

	.attachment-meta {
		font-size: 0.75rem;
		color: #6B7280;
		margin-top: 0.25rem;
	}

	.download-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.5rem;
		cursor: pointer;
		transition: background 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.download-btn:hover {
		background: #2563EB;
	}

	.progress-section {
		background: white;
		margin: 1rem;
		padding: 1.5rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
	}

	.progress-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.75rem;
	}

	.progress-bar {
		width: 100%;
		height: 8px;
		background: #E5E7EB;
		border-radius: 4px;
		overflow: hidden;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #10B981, #059669);
		border-radius: 4px;
		transition: width 0.3s ease;
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

	.requirements-section {
		background: white;
		margin: 1rem;
		padding: 1.5rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
	}

	.requirements-section h4 {
		margin: 0 0 1.5rem 0;
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
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
		width: 18px;
		height: 18px;
		accent-color: #10B981;
		cursor: pointer;
	}

	.input-section {
		margin-top: 0.75rem;
	}

	.file-input {
		display: none;
	}

	.upload-section {
		margin-top: 0.75rem;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #3B82F6;
		color: white;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: background 0.2s;
		border: none;
	}

	.upload-btn:hover {
		background: #2563EB;
	}

	.photo-preview {
		position: relative;
		margin-top: 0.75rem;
	}

	.preview-image {
		width: 100%;
		max-width: 300px;
		height: auto;
		border-radius: 8px;
		border: 2px solid #E5E7EB;
	}

	.remove-photo {
		position: absolute;
		top: 8px;
		right: 8px;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background 0.2s;
	}

	.remove-photo:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	.erp-input {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		transition: border-color 0.2s;
	}

	.erp-input:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.notes-textarea {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #D1D5DB;
		border-radius: 8px;
		font-size: 0.875rem;
		background: white;
		transition: border-color 0.2s;
		resize: vertical;
		min-height: 80px;
		font-family: inherit;
	}

	.notes-textarea:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
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

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Mobile optimizations */
	@media (max-width: 640px) {
		.header {
			padding: 1rem;
		}

		.requirements-section,
		.progress-section,
		.task-details-section {
			margin: 0.75rem;
		}

		.actions {
			flex-direction: column;
		}

		.cancel-btn,
		.complete-btn {
			width: 100%;
		}

		.detail-grid {
			grid-template-columns: 1fr;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}

		.actions {
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
	}
</style>