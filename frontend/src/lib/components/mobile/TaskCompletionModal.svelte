<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { db } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { notifications } from '$lib/stores/notifications';

	const dispatch = createEventDispatcher();

	// Props
	export let task: any = null;
	export let assignment: any = null;
	export let onClose: () => void = () => {};
	export let onTaskCompleted: () => void = () => {};

	// Current user
	$: currentUserData = $currentUser;

	// Assignment details loaded from database
	let assignmentDetails: any = null;

	// Resolve requirement flags from assignment details first, then task object
	$: resolvedRequireTaskFinished = assignmentDetails?.require_task_finished ?? assignment?.require_task_finished ?? task?.require_task_finished ?? true;
	$: resolvedRequirePhotoUpload = assignmentDetails?.require_photo_upload ?? assignment?.require_photo_upload ?? task?.require_photo_upload ?? false;
	$: resolvedRequireErpReference = assignmentDetails?.require_erp_reference ?? assignment?.require_erp_reference ?? task?.require_erp_reference ?? false;

	// Debug logging for requirements
	$: {
		console.log('📋 [TaskCompletionModal] Requirements resolved:', {
			task_finished: resolvedRequireTaskFinished,
			photo_upload: resolvedRequirePhotoUpload,
			erp_reference: resolvedRequireErpReference
		});
		console.log('📋 [TaskCompletionModal] Data sources:', {
			assignmentDetails,
			assignment,
			task
		});
	}

	// Load assignment details on component mount (but don't override passed requirements)
	onMount(async () => {
		if (assignment?.id) {
			try {
				const { data: assignmentData, error } = await supabase
					.from('task_assignments')
					.select('*')
					.eq('id', assignment.id)
					.single();

				if (error) {
					console.error('Error loading assignment details:', error);
				} else {
					// Only load assignment details for non-requirement fields
					// Don't override the requirement flags that were passed as props
					assignmentDetails = {
						...assignmentData,
						// Preserve the requirement flags from the passed assignment prop
						require_task_finished: assignment.require_task_finished ?? assignmentData.require_task_finished,
						require_photo_upload: assignment.require_photo_upload ?? assignmentData.require_photo_upload,
						require_erp_reference: assignment.require_erp_reference ?? assignmentData.require_erp_reference
					};
					console.log('📋 [TaskCompletionModal] Assignment details loaded with preserved requirements:', assignmentDetails);
				}
			} catch (error) {
				console.error('Error loading assignment details:', error);
			}
		}
	});

	// Component state
	let isSubmitting = false;
	let errorMessage = '';
	let successMessage = '';

	// Completion form data
	let completionData = {
		task_finished_completed: false,
		photo_uploaded_completed: false,
		erp_reference_completed: false,
		erp_reference_number: '',
		completion_notes: ''
	};

	// Photo upload
	let photoFile: File | null = null;
	let photoPreview: string | null = null;

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
			if (photoFile) completed++;
		}
		if (resolvedRequireErpReference) {
			total++;
			if (completionData.erp_reference_number.trim()) completed++;
		}

		return total > 0 ? Math.round((completed / total) * 100) : 0;
	})();

	// Check if form can be submitted
	$: canSubmit = (() => {
		const taskCheck = !resolvedRequireTaskFinished || completionData.task_finished_completed;
		const photoCheck = !resolvedRequirePhotoUpload || !!photoFile;
		const erpCheck = !resolvedRequireErpReference || !!completionData.erp_reference_number?.trim();
		
		return taskCheck && photoCheck && erpCheck;
	})();

	// Auto-update completion flags
	$: if (completionData.erp_reference_number?.trim()) {
		completionData.erp_reference_completed = true;
	} else {
		completionData.erp_reference_completed = false;
	}

	function handleClose() {
		onClose();
		dispatch('close');
	}

	async function handlePhotoUpload(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (file) {
			// Validate file type and size
			if (!file.type.startsWith('image/')) {
				errorMessage = 'Please select a valid image file';
				return;
			}
			
			if (file.size > 5 * 1024 * 1024) { // 5MB limit
				errorMessage = 'Image file must be less than 5MB';
				return;
			}
			
			photoFile = file;
			
			// Create preview
			const reader = new FileReader();
			reader.onload = (e) => {
				photoPreview = e.target?.result as string;
			};
			reader.readAsDataURL(file);
			
			// Mark photo as uploaded when file is selected
			completionData.photo_uploaded_completed = true;
			errorMessage = '';
		}
	}

	function removePhoto() {
		photoFile = null;
		photoPreview = null;
		completionData.photo_uploaded_completed = false;
		
		// Reset file input
		const fileInput = document.getElementById('photo-upload') as HTMLInputElement;
		if (fileInput) {
			fileInput.value = '';
		}
	}

	async function uploadPhoto(): Promise<string | null> {
		if (!photoFile || !currentUserData) return null;
		
		try {
			const fileExt = photoFile.name.split('.').pop();
			const fileName = `task-completion-${task.id}-${Date.now()}.${fileExt}`;
			
			const { data, error } = await supabase.storage
				.from('completion-photos')
				.upload(fileName, photoFile, {
					cacheControl: '3600',
					upsert: false
				});
			
			if (error) {
				console.error('Error uploading photo:', error);
				// Continue without photo if upload fails
				return null;
			}
			
			// Get public URL
			const { data: urlData } = supabase.storage
				.from('completion-photos')
				.getPublicUrl(fileName);
			
			return urlData.publicUrl;
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
			let photoUrl = null;
			
			// Upload photo if required and provided
			if (resolvedRequirePhotoUpload && photoFile) {
				try {
					photoUrl = await uploadPhoto();
					if (!photoUrl) {
						console.warn('Photo upload failed, continuing without photo');
					}
				} catch (uploadError) {
					console.error('Photo upload failed:', uploadError);
				}
			}
			
			// Create completion record
			const completionRecord = {
				task_id: task.id,
				assignment_id: assignment.id,
				completed_by: currentUserData.id,
				completed_by_name: currentUserData.username,
				// Note: completed_by_branch_id removed - branch_id is bigint, not uuid. Branch info can be retrieved from users table via completed_by.
				task_finished_completed: resolvedRequireTaskFinished ? completionData.task_finished_completed : null,
				photo_uploaded_completed: resolvedRequirePhotoUpload ? (photoUrl ? true : false) : null,
				completion_photo_url: photoUrl,
				erp_reference_completed: resolvedRequireErpReference ? completionData.erp_reference_completed : null,
				erp_reference_number: resolvedRequireErpReference ? completionData.erp_reference_number : null,
				completion_notes: completionData.completion_notes || null,
				completed_at: new Date().toISOString()
			};
			
			console.log('Creating completion record:', completionRecord);
			
			// Insert completion record
			const { data, error } = await supabase
				.from('task_completions')
				.insert([completionRecord])
				.select()
				.single();
			
			if (error) throw error;
			
			console.log('Completion record created successfully:', data);
			
			// Update task assignment status
			const { error: assignmentError } = await supabase
				.from('task_assignments')
				.update({ 
					status: 'completed',
					completed_at: new Date().toISOString()
				})
				.eq('id', assignment.id);
			
			if (assignmentError) {
				console.error('Error updating assignment status:', assignmentError);
			}
			
			// If this is a payment task with ERP reference, update vendor_payment_schedule
			// ONLY for tasks that are specifically payment-related (with payment_schedule_id in metadata)
			if (resolvedRequireErpReference && completionData.erp_reference_number?.trim()) {
				try {
					// Get task metadata to check if this is a payment task
					const { data: taskData, error: taskError } = await supabase
						.from('tasks')
						.select('metadata')
						.eq('id', task.id)
						.single();
					
					// Only update if this task has payment_schedule_id in metadata (payment tasks only)
					if (taskData?.metadata?.payment_schedule_id && taskData?.metadata?.payment_type === 'vendor_payment') {
						const paymentScheduleId = taskData.metadata.payment_schedule_id;
						console.log('💳 [Mobile] Updating payment_reference for payment schedule:', paymentScheduleId);
						
						// Update payment_reference in vendor_payment_schedule
						const { error: updateError } = await supabase
							.from('vendor_payment_schedule')
							.update({ 
								payment_reference: completionData.erp_reference_number.trim(),
								updated_at: new Date().toISOString()
							})
							.eq('id', paymentScheduleId);
						
						if (updateError) {
							console.error('❌ [Mobile] Failed to update payment_reference:', updateError);
						} else {
							console.log('✅ [Mobile] Payment reference updated successfully');
						}
					} else {
						console.log('ℹ️ [Mobile] Task has ERP reference but is not a payment task, skipping vendor_payment_schedule update');
					}
				} catch (paymentUpdateError) {
					console.error('❌ [Mobile] Error updating payment schedule:', paymentUpdateError);
					// Don't fail task completion if payment update fails
				}
			}
			
			successMessage = 'Task completed successfully!';
			
			// Show success notification
			notifications.add({
				type: 'success',
				message: 'Task completed successfully!',
				duration: 3000
			});
			
			// Call completion callbacks
			onTaskCompleted();
			
			// Close modal after brief delay
			setTimeout(() => {
				handleClose();
			}, 1500);
			
		} catch (error) {
			console.error('Error completing task:', error);
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

	function formatDate(dateString) {
		if (!dateString) return 'Not set';
		const date = new Date(dateString);
		return date.toLocaleDateString('en-US', {
			weekday: 'long',
			year: 'numeric',
			month: 'long',
			day: 'numeric'
		});
	}

	function formatTime(timeString) {
		if (!timeString) return 'Not set';
		const [hours, minutes] = timeString.split(':');
		const date = new Date();
		date.setHours(parseInt(hours), parseInt(minutes));
		return date.toLocaleTimeString('en-US', {
			hour: 'numeric',
			minute: '2-digit',
			hour12: true
		});
	}
</script>

<div class="modal-overlay" on:click={handleClose} role="button" tabindex="0" on:keydown={(e) => e.key === 'Escape' && handleClose()}>
	<div class="completion-modal" 
		on:click|stopPropagation 
		on:keydown={() => {}}
		role="dialog" 
		aria-labelledby="modal-title"
		tabindex="-1"
	>
		<!-- Header -->
		<div class="modal-header">
			<h2 id="modal-title">Complete Task</h2>
			<button class="close-btn" on:click={handleClose} disabled={isSubmitting} aria-label="Close modal">
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M18 6L6 18M6 6l12 12"/>
				</svg>
			</button>
		</div>

		<!-- Task Info -->
		<div class="task-info">
			<h3>{task?.title}</h3>
			{#if task?.description}
				<p class="task-description">{task.description}</p>
			{/if}
			
			<!-- Deadline Info -->
			{#if assignment?.deadline_date}
				<div class="deadline-info">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"/>
						<polyline points="12,6 12,12 16,14"/>
					</svg>
					<span>Deadline: {formatDate(assignment.deadline_date)}</span>
					{#if assignment?.deadline_time}
						<span>at {formatTime(assignment.deadline_time)}</span>
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
			
			<!-- Task Finished -->
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
			
			<!-- Photo Upload -->
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
							<button class="remove-photo" on:click={removePhoto} disabled={isSubmitting} aria-label="Remove photo">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M18 6L6 18M6 6l12 12"/>
								</svg>
							</button>
						</div>
					{/if}
				</div>
			{/if}
			
			<!-- ERP Reference -->
			{#if resolvedRequireErpReference}
				<div class="requirement-item">
					<div class="requirement-header">
						<span class="requirement-label required">🔢 ERP Reference (Required)</span>
					</div>
					
					<div class="input-section">
						<input
							type="text"
							bind:value={completionData.erp_reference_number}
							placeholder="Enter ERP reference number"
							disabled={isSubmitting}
							class="erp-input"
							required
						/>
					</div>
				</div>
			{/if}
			
			<!-- Completion Notes -->
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
		<div class="modal-actions">
			<button class="cancel-btn" on:click={handleClose} disabled={isSubmitting}>
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
					Complete Task
				{/if}
			</button>
		</div>
	</div>
</div>

<style>
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.completion-modal {
		background: white;
		border-radius: 12px;
		width: 100%;
		max-width: 500px;
		max-height: 90vh;
		overflow-y: auto;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
	}

	.close-btn {
		background: none;
		border: none;
		padding: 0.5rem;
		cursor: pointer;
		color: #6B7280;
		border-radius: 6px;
		transition: all 0.2s;
	}

	.close-btn:hover {
		background: #F3F4F6;
		color: #374151;
	}

	.task-info {
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.task-info h3 {
		margin: 0 0 0.5rem 0;
		font-size: 1.1rem;
		font-weight: 600;
		color: #1F2937;
	}

	.task-description {
		margin: 0.5rem 0;
		color: #6B7280;
		font-size: 0.9rem;
		line-height: 1.4;
	}

	.deadline-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-top: 0.75rem;
		padding: 0.5rem;
		background: #FEF3C7;
		border: 1px solid #F59E0B;
		border-radius: 6px;
		color: #92400E;
		font-size: 0.875rem;
	}

	.progress-section {
		padding: 1.5rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.progress-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.5rem;
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
		gap: 0.5rem;
		padding: 1rem 1.5rem;
		margin: 0;
		font-size: 0.875rem;
		font-weight: 500;
	}

	.message.error {
		background: #FEF2F2;
		color: #DC2626;
		border-left: 4px solid #DC2626;
	}

	.message.success {
		background: #F0FDF4;
		color: #059669;
		border-left: 4px solid #059669;
	}

	.requirements-section {
		padding: 1.5rem;
	}

	.requirements-section h4 {
		margin: 0 0 1rem 0;
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

	.upload-section {
		margin-top: 0.75rem;
	}

	.file-input {
		display: none;
	}

	.upload-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		background: #3B82F6;
		color: white;
		border-radius: 6px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
		border: none;
		text-decoration: none;
	}

	.upload-btn:hover {
		background: #2563EB;
	}

	.photo-preview {
		position: relative;
		display: inline-block;
		margin-top: 0.75rem;
	}

	.preview-image {
		width: 120px;
		height: 120px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #E5E7EB;
	}

	.remove-photo {
		position: absolute;
		top: -8px;
		right: -8px;
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background 0.2s;
	}

	.remove-photo:hover {
		background: #DC2626;
	}

	.input-section {
		margin-top: 0.75rem;
	}

	.erp-input, .notes-textarea {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #D1D5DB;
		border-radius: 6px;
		font-size: 0.875rem;
		background: white;
		transition: border-color 0.2s;
		resize: vertical;
		min-height: 2.5rem;
	}

	.notes-textarea {
		min-height: 80px;
		font-family: inherit;
	}

	.erp-input:focus, .notes-textarea:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.modal-actions {
		display: flex;
		gap: 1rem;
		padding: 1.5rem;
		border-top: 1px solid #E5E7EB;
	}

	.cancel-btn, .complete-btn {
		flex: 1;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-weight: 500;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
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
	}

	.complete-btn:disabled,
	.complete-btn.disabled {
		background: #D1D5DB;
		color: #9CA3AF;
		cursor: not-allowed;
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
		.completion-modal {
			margin: 0;
			border-radius: 0;
			height: 100vh;
			max-height: 100vh;
		}

		.modal-overlay {
			padding: 0;
		}

		.preview-image {
			width: 100px;
			height: 100px;
		}

		.modal-actions {
			flex-direction: column;
		}

		.cancel-btn, .complete-btn {
			width: 100%;
		}
	}
</style>