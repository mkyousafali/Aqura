<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase, db, getStoragePublicUrl } from '$lib/utils/supabase';
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

	// Photo upload (multi-photo)
	let photoFiles: File[] = [];
	let photoPreviews: string[] = [];

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
			if (photoFiles.length > 0 && completionData.photo_uploaded_completed) completed++;
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
		const photoCheck = !resolvedRequirePhotoUpload || (photoFiles.length > 0 && completionData.photo_uploaded_completed);
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
					fileUrl: file.storage_path ? getStoragePublicUrl(file.storage_bucket || 'quick-task-files', file.storage_path) : '',
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
				day: 'numeric',
				timeZone: 'Asia/Riyadh'
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
				minute: '2-digit',
				timeZone: 'Asia/Riyadh'
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
				message: 'Failed to download file / فشل تنزيل الملف',
				duration: 3000
			});
		}
	}
	
	async function handlePhotoUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const files = target.files;
		
		if (files && files.length > 0) {
			for (const file of Array.from(files)) {
				if (!file.type.startsWith('image/')) {
					errorMessage = 'Please select a valid image file';
					continue;
				}
				
				if (file.size > 5 * 1024 * 1024) {
					errorMessage = 'Image file must be less than 5MB';
					continue;
				}
				
				photoFiles = [...photoFiles, file];
				
				const reader = new FileReader();
				reader.onload = (e) => { 
					photoPreviews = [...photoPreviews, e.target?.result as string]; 
				};
				reader.readAsDataURL(file);
			}
			
			completionData.photo_uploaded_completed = photoFiles.length > 0;
			errorMessage = '';
			
			// Reset input so same file can be re-selected
			target.value = '';
		}
	}
	
	function removePhoto(index: number) {
		photoFiles = photoFiles.filter((_, i) => i !== index);
		photoPreviews = photoPreviews.filter((_, i) => i !== index);
		completionData.photo_uploaded_completed = photoFiles.length > 0;
	}
	
	async function uploadPhotos(): Promise<string[]> {
		if (photoFiles.length === 0 || !currentUserData) return [];
		
		const paths: string[] = [];
		for (const file of photoFiles) {
			try {
				const fileExt = file.name.split('.').pop();
				const fileName = `quick-task-completion-${assignmentDetails.id}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${fileExt}`;
				
				const { data, error } = await supabase.storage
					.from('completion-photos')
					.upload(fileName, file, {
						cacheControl: '3600',
						upsert: false
					});
				
				if (error) {
					console.error('Storage upload error:', error);
					continue;
				}
				
				paths.push(data.path);
			} catch (error) {
				console.error('Error uploading photo:', error);
			}
		}
		return paths;
	}
	
	async function submitCompletion() {
		if (!currentUserData || !canSubmit) return;
		
		// Check if this is an incident follow-up task that requires incident resolution first
		if (taskDetails?.issue_type === 'incident_followup' && taskDetails?.incident_id) {
			try {
				const { data: incident, error } = await supabase
					.from('incidents')
					.select('resolution_status')
					.eq('id', taskDetails.incident_id)
					.single();
				
				if (!error && incident && incident.resolution_status !== 'resolved') {
					errorMessage = 'Cannot complete this task until the linked incident is resolved. / لا يمكن إكمال هذه المهمة حتى يتم حل الحادثة المرتبطة.';
					notifications.add({
						type: 'error',
						message: 'Incident must be resolved first. / يجب حل الحادثة أولاً.',
						duration: 4000
					});
					return;
				}
			} catch (err) {
				console.error('Error checking incident status:', err);
			}
		}

		// Check if this is a product request task that requires accept/reject first
		if ((taskDetails?.issue_type === 'product_request_follow_up' || taskDetails?.issue_type === 'product_request_process') && taskDetails?.product_request_id && taskDetails?.product_request_type) {
			try {
				const tableName = taskDetails.product_request_type === 'PO' ? 'product_request_po' : taskDetails.product_request_type === 'ST' ? 'product_request_st' : 'product_request_bt';
				const { data: reqData, error } = await supabase
					.from(tableName)
					.select('status')
					.eq('id', taskDetails.product_request_id)
					.single();

				if (!error && reqData && reqData.status === 'pending') {
					errorMessage = 'Cannot complete this task until the product request is accepted or rejected. / لا يمكن إكمال هذه المهمة حتى يتم قبول أو رفض طلب المنتج.';
					notifications.add({
						type: 'error',
						message: 'Product request must be accepted or rejected first. / يجب قبول أو رفض طلب المنتج أولاً.',
						duration: 4000
					});
					return;
				}
			} catch (err) {
				console.error('Error checking product request status:', err);
			}
		}

		// Check if BT process task requires document_url to be uploaded first
		if (taskDetails?.issue_type === 'product_request_process' && taskDetails?.product_request_type === 'BT' && taskDetails?.product_request_id) {
			try {
				const { data: btData, error } = await supabase
					.from('product_request_bt')
					.select('document_url')
					.eq('id', taskDetails.product_request_id)
					.single();

				if (!error && btData && (!btData.document_url || btData.document_url.trim() === '')) {
					errorMessage = 'Cannot complete this task until the BT document is uploaded. / لا يمكن إكمال هذه المهمة حتى يتم رفع مستند النقل الفرعي.';
					notifications.add({
						type: 'error',
						message: 'BT document must be uploaded first. / يجب رفع مستند النقل الفرعي أولاً.',
						duration: 4000
					});
					return;
				}
			} catch (err) {
				console.error('Error checking BT document_url:', err);
			}
		}
		
		isSubmitting = true;
		errorMessage = '';
		successMessage = '';
		
		try {
			let photoPaths: string[] = [];
			
			// Upload photos if required and provided
			if (resolvedRequirePhotoUpload && photoFiles.length > 0) {
				try {
					photoPaths = await uploadPhotos();
					if (photoPaths.length === 0) {
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
					p_photos: photoPaths.length > 0 ? photoPaths : null,
					p_erp_reference: completionData.erp_reference_number || null
				});
				
				if (error) {
					console.error('Error submitting completion:', error);
					throw error;
				}
				
				console.log('✅ Quick task completion submitted successfully:', completionId);
				
				// Update incident user status to acknowledged if this task is linked to an incident
				if (taskDetails?.incident_id && currentUserData?.id) {
					try {
						const { data: incident } = await supabase
							.from('incidents')
							.select('user_statuses')
							.eq('id', taskDetails.incident_id)
							.single();
						
						if (incident) {
							const userStatuses = typeof incident.user_statuses === 'string' 
								? JSON.parse(incident.user_statuses)
								: (incident.user_statuses || {});
							
							userStatuses[currentUserData.id] = {
								...userStatuses[currentUserData.id],
								status: 'acknowledged',
								acknowledged_at: new Date().toISOString()
							};
							
							await supabase
								.from('incidents')
								.update({ user_statuses: userStatuses })
								.eq('id', taskDetails.incident_id);
							
							console.log('✅ Incident user status updated to acknowledged');
						}
					} catch (statusError) {
						console.warn('Could not update incident status:', statusError);
						// Non-blocking error - continue with success
					}
				}
			} catch (completionError) {
				console.error('Error creating quick task completion:', completionError);
				throw completionError;
			}
			
			successMessage = 'Quick Task completed successfully! / تم إكمال المهمة السريعة بنجاح!';
			
			notifications.add({
				type: 'success',
				message: 'Quick Task completed successfully! / تم إكمال المهمة السريعة بنجاح!',
				duration: 3000
			});
			
			setTimeout(() => {
				goto('/mobile-interface/tasks');
			}, 2000);
			
		} catch (error) {
			console.error('Error submitting completion:', error);
			errorMessage = error.message || 'Failed to complete task / فشل إكمال المهمة';
			
			notifications.add({
				type: 'error',
				message: 'Failed to complete task. Please try again. / فشل إكمال المهمة. يرجى المحاولة مرة أخرى.',
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
				<button class="back-btn" on:click={() => goto('/mobile-interface/tasks')}>
					← Back to Tasks
				</button>
			</div>
		</div>
	{:else}
		<!-- Compact Task Info Bar -->
		<div class="task-info-bar">
			<div class="info-bar-title">{taskDetails.title}</div>
			<div class="info-bar-row">
				<span class="priority-badge {getPriorityColor(taskDetails.priority)}">
					{taskDetails.priority?.toUpperCase() || 'MEDIUM'}
				</span>
				{#if taskDetails.issue_type}
					<span class="info-chip">{formatIssueType(taskDetails.issue_type)}</span>
				{/if}
				{#if taskDetails.deadline_datetime}
					<span class="info-chip {isOverdue(taskDetails.deadline_datetime) ? 'overdue' : 'on-time'}">
						{#if isOverdue(taskDetails.deadline_datetime)}
							Overdue by {getOverdueTime(taskDetails.deadline_datetime)}
						{:else}
							{liveCountdown} remaining
						{/if}
					</span>
				{/if}
			</div>
			{#if assignedByUserName}
				<div class="info-bar-assigned">👤 Assigned by: {assignedByUserName}</div>
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
						<span class="requirement-label required">Task Finished (Required)</span>
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
						<span class="requirement-label required">📷 Upload Photos (Required)</span>
					</div>
					
					<div class="upload-section">
						<!-- Camera capture button -->
						<input
							id="camera-capture"
							type="file"
							accept="image/*"
							capture="environment"
							on:change={handlePhotoUpload}
							disabled={isSubmitting}
							class="file-input"
						/>
						<label for="camera-capture" class="upload-btn camera-btn">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/>
								<circle cx="12" cy="13" r="4"/>
							</svg>
							Take Photo
						</label>

						<!-- File chooser button -->
						<input
							id="photo-upload"
							type="file"
							accept="image/*"
							multiple
							on:change={handlePhotoUpload}
							disabled={isSubmitting}
							class="file-input"
						/>
						<label for="photo-upload" class="upload-btn">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
							</svg>
							Choose Files ({photoFiles.length})
						</label>
					</div>

					{#if photoPreviews.length > 0}
						<div class="photo-grid">
							{#each photoPreviews as preview, i}
								<div class="photo-preview-item">
									<img src={preview} alt="Photo {i + 1}" class="preview-image" />
									<button class="remove-photo" on:click={() => removePhoto(i)} disabled={isSubmitting} aria-label="Remove photo {i + 1}">
										<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M18 6L6 18M6 6l12 12"/>
										</svg>
									</button>
								</div>
							{/each}
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
			<button class="cancel-btn" on:click={() => goto('/mobile-interface/tasks')} disabled={isSubmitting}>
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

	/* Compact Task Info Bar */
	.task-info-bar {
		background: white;
		margin: 0.5rem 0.6rem;
		padding: 0.65rem 0.85rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.info-bar-title {
		font-size: 0.9rem;
		font-weight: 600;
		color: #1F2937;
		margin-bottom: 0.4rem;
	}

	.info-bar-row {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		align-items: center;
		margin-bottom: 0.3rem;
	}

	.info-chip {
		display: inline-block;
		padding: 0.15rem 0.5rem;
		border-radius: 0.75rem;
		font-size: 0.7rem;
		font-weight: 500;
		background: #F3F4F6;
		color: #374151;
		border: 1px solid #E5E7EB;
	}

	.info-chip.overdue {
		background: #FEF2F2;
		color: #DC2626;
		border-color: #FECACA;
		font-weight: 600;
	}

	.info-chip.on-time {
		background: #F0FDF4;
		color: #16A34A;
		border-color: #BBF7D0;
	}

	.info-bar-assigned {
		font-size: 0.75rem;
		color: #6B7280;
	}

	.priority-badge {
		display: inline-block;
		padding: 0.15rem 0.5rem;
		border-radius: 0.75rem;
		font-size: 0.7rem;
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

	.progress-section {
		background: white;
		margin: 0.5rem 0.6rem;
		padding: 0.6rem 0.85rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.progress-label {
		font-size: 0.8rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.35rem;
	}

	.progress-bar {
		width: 100%;
		height: 6px;
		background: #E5E7EB;
		border-radius: 3px;
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

	.requirements-section {
		background: white;
		margin: 0.5rem 0.6rem;
		padding: 0.6rem 0.85rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.requirements-section h4 {
		margin: 0 0 0.6rem 0;
		font-size: 0.88rem;
		font-weight: 600;
		color: #1F2937;
	}

	.requirement-item {
		margin-bottom: 0.6rem;
		padding: 0.55rem 0.7rem;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		background: #F9FAFB;
	}

	.requirement-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.4rem;
	}

	.requirement-label {
		font-weight: 500;
		font-size: 0.82rem;
	}

	.requirement-label.required {
		color: #DC2626;
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

	.input-section {
		margin-top: 0.35rem;
	}

	.file-input {
		display: none;
	}

	.upload-section {
		margin-top: 0.35rem;
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		padding: 0.5rem 0.85rem;
		background: #3B82F6;
		color: white;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.8rem;
		font-weight: 500;
		transition: background 0.2s;
		border: none;
	}

	.upload-btn:hover {
		background: #2563EB;
	}

	.camera-btn {
		background: #10B981;
	}
	
	.camera-btn:hover {
		background: #059669;
	}

	.photo-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.4rem;
		margin-top: 0.5rem;
	}

	.photo-preview-item {
		position: relative;
		aspect-ratio: 1;
		border-radius: 6px;
		overflow: hidden;
		border: 1px solid #E5E7EB;
	}

	.photo-preview-item .preview-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 0;
		border: none;
		max-width: none;
	}

	.remove-photo {
		position: absolute;
		top: 3px;
		right: 3px;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 22px;
		height: 22px;
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
		padding: 0.5rem 0.6rem;
		border: 1.5px solid #D1D5DB;
		border-radius: 6px;
		font-size: 0.8rem;
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
		padding: 0.5rem 0.6rem;
		border: 1.5px solid #D1D5DB;
		border-radius: 6px;
		font-size: 0.8rem;
		background: white;
		transition: border-color 0.2s;
		resize: vertical;
		min-height: 60px;
		font-family: inherit;
	}

	.notes-textarea:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
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

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Mobile optimizations */
	@media (max-width: 640px) {
		.header {
			padding: 0.4rem 0.5rem;
		}

		.requirements-section,
		.progress-section,
		.task-info-bar {
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
		.header {
			padding-top: max(0.4rem, env(safe-area-inset-top));
		}

		.actions {
			padding-bottom: max(0.5rem, env(safe-area-inset-bottom));
		}
	}
</style>
