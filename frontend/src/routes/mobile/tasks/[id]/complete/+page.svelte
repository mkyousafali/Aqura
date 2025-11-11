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
    let taskImages: any[] = [];
    let taskAttachments: any[] = [];
    let assignedByUserName = '';
    let assignedToUserName = '';

    // Live countdown state
    let liveCountdown = '';
    let countdownInterval: NodeJS.Timeout | null = null;

    // Current user
    $: currentUserData = $currentUser;

    // Resolve requirement flags from assignment details first, then task object
    $: resolvedRequireTaskFinished = assignmentDetails?.require_task_finished ?? taskDetails?.require_task_finished ?? true;
    $: resolvedRequirePhotoUpload = assignmentDetails?.require_photo_upload ?? taskDetails?.require_photo_upload ?? false;
    $: resolvedRequireErpReference = assignmentDetails?.require_erp_reference ?? taskDetails?.require_erp_reference ?? false;

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

	// UI state
	let showTaskDetails = false;
	let showImageModal = false;
	let selectedImageUrl = '';    // Calculate completion progress
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
        // Check if task is assigned to current user
        if (!assignmentDetails) return false;
        
        // Check if assignment belongs to current user
        if (assignmentDetails.assigned_to_user_id !== currentUserData?.id) return false;
        
        // Check completion requirements
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
            
            // Load task details
            const taskResult = await db.tasks.getById(taskId);
            if (taskResult.data) {
                taskDetails = taskResult.data;
            }
            
            // Load task images
            const imageResult = await db.taskImages.getByTaskId(taskId);
            if (imageResult.data) {
                taskImages = imageResult.data;
            }
            
            // Load task attachments
            const attachmentResult = await db.taskAttachments.getByTaskId(taskId);
            if (attachmentResult.data && attachmentResult.data.length > 0) {
                taskAttachments = attachmentResult.data
                    .filter(attachment => attachment && attachment.file_name && attachment.file_path)
                    .map(attachment => ({
                        id: attachment.id,
                        fileName: attachment.file_name || 'Unknown File',
                        fileSize: attachment.file_size || 0,
                        fileType: attachment.file_type || 'application/octet-stream',
                        fileUrl: attachment.file_path && attachment.file_path.startsWith('http') 
                            ? attachment.file_path 
                            : `https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/task-images/${attachment.file_path || ''}`,
                        uploadedBy: attachment.uploaded_by_name || attachment.uploaded_by || 'Unknown',
                        uploadedAt: attachment.created_at
                    }));
            } else {
                taskAttachments = [];
            }
            
			// Find assignment for current user
			const { data: assignments, error: assignmentError } = await supabase
				.from('task_assignments')
				.select('*')
				.eq('task_id', taskId)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('assigned_at', { ascending: false })
				.limit(1);

            console.log('🔍 Assignment query result:', { 
                taskId, 
                userId: currentUserData.id,
                assignments, 
                error: assignmentError 
            });

            if (assignmentError) {
                console.error('Error loading assignment:', assignmentError);
            } else if (assignments && assignments.length > 0) {
                assignmentDetails = assignments[0];
                console.log('✅ Assignment loaded:', assignmentDetails);
                
                // Fetch assigned by user name
                if (assignmentDetails.assigned_by) {
                    const assignedByResult = await db.users.getById(assignmentDetails.assigned_by);
                    if (assignedByResult.data) {
                        if (assignedByResult.data.employee_id) {
                            const employeeResult = await db.employees.getById(assignedByResult.data.employee_id);
                            if (employeeResult.data && employeeResult.data.name) {
                                assignedByUserName = employeeResult.data.name;
                            } else {
                                assignedByUserName = assignedByResult.data.username || assignmentDetails.assigned_by_name || 'Unknown User';
                            }
                        } else {
                            assignedByUserName = assignedByResult.data.username || assignmentDetails.assigned_by_name || 'Unknown User';
                        }
                    } else {
                        assignedByUserName = assignmentDetails.assigned_by_name || 'Unknown User';
                    }
                }
                
                // Fetch assigned to user name
                if (assignmentDetails.assigned_to_user_id) {
                    const assignedToResult = await db.users.getById(assignmentDetails.assigned_to_user_id);
                    if (assignedToResult.data) {
                        if (assignedToResult.data.employee_id) {
                            const employeeResult = await db.employees.getById(assignedToResult.data.employee_id);
                            if (employeeResult.data && employeeResult.data.name) {
                                assignedToUserName = employeeResult.data.name;
                            } else {
                                assignedToUserName = assignedToResult.data.username || 'Unknown User';
                            }
                        } else {
                            assignedToUserName = assignedToResult.data.username || 'Unknown User';
                        }
                    } else {
                        assignedToUserName = 'Unknown User';
                    }
                } else {
                    assignedToUserName = 'Not assigned to specific user';
                }
                
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
        const deadlineString = assignmentDetails?.deadline_datetime || assignmentDetails?.deadline_date;
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

    // Image modal functions
    function openImageModal(imageUrl: string) {
        selectedImageUrl = imageUrl;
        showImageModal = true;
    }
    
    function closeImageModal() {
        showImageModal = false;
        selectedImageUrl = '';
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
            const fileName = `task-completion-${taskId}-${Date.now()}.${fileExt}`;
            
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
            
            if (resolvedRequirePhotoUpload && photoFile) {
                try {
                    photoUrl = await uploadPhoto();
                    if (!photoUrl) {
                        throw new Error('Photo upload failed. Please try again.');
                    }
                } catch (uploadError) {
                    console.error('Photo upload failed:', uploadError);
                    throw new Error('Required photo upload failed. Please check your connection and try again.');
                }
            }
            
            // Validate all requirements before submission
            if (resolvedRequirePhotoUpload && !photoUrl) {
                throw new Error('Photo is required but was not uploaded successfully.');
            }
            
            if (resolvedRequireErpReference && !completionData.erp_reference_number?.trim()) {
                throw new Error('ERP reference is required but was not provided.');
            }
            
            // Validate assignment_id is a valid UUID
            const assignmentId = assignmentDetails?.id;
            const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
            
            if (!assignmentId || !uuidRegex.test(assignmentId)) {
                console.error('Invalid assignment ID:', {
                    assignmentId,
                    assignmentDetails,
                    isValidUUID: assignmentId ? uuidRegex.test(assignmentId) : false
                });
                throw new Error('Invalid assignment ID. Please contact support.');
            }
            
            const completionRecord = {
                task_id: taskId,
                assignment_id: assignmentId,
                completed_by: currentUserData.id,
                completed_by_name: currentUserData.username,
                // Skip completed_by_branch_id for now - column type mismatch issue
                task_finished_completed: resolvedRequireTaskFinished ? completionData.task_finished_completed : null,
                photo_uploaded_completed: resolvedRequirePhotoUpload ? (photoUrl ? true : false) : null,
                completion_photo_url: photoUrl,
                erp_reference_completed: resolvedRequireErpReference ? completionData.erp_reference_completed : null,
                erp_reference_number: resolvedRequireErpReference ? completionData.erp_reference_number : null,
                completion_notes: completionData.completion_notes || null,
                completed_at: new Date().toISOString()
            };
            
            console.log('📋 Submitting completion record:', completionRecord);
            
            const { data, error } = await supabase
                .from('task_completions')
                .insert([completionRecord])
                .select()
                .single();
            
            if (error) throw error;
            
            if (assignmentDetails?.id) {
                const { error: assignmentError } = await supabase
                    .from('task_assignments')
                    .update({ 
                        status: 'completed',
                        completed_at: new Date().toISOString()
                    })
                    .eq('id', assignmentDetails.id);
                
                if (assignmentError) {
                    console.error('Error updating assignment status:', assignmentError);
                }
            }
            
            successMessage = 'Task completed successfully!';
            
            notifications.add({
                type: 'success',
                message: 'Task completed successfully!',
                duration: 3000
            });
            
            setTimeout(() => {
                goto('/mobile/tasks');
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
    <title>Complete Task - Aqura Mobile</title>
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
            <h2>Task Not Found</h2>
            <p>This task doesn't exist or you don't have access to it.</p>
        </div>
    {:else if !assignmentDetails || assignmentDetails.assigned_to_user_id !== currentUserData?.id}
        <div class="error-state">
            <div class="error-icon">
                <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <path d="M18.364 5.636L12 12m0 0l-6.364 6.364M12 12l6.364 6.364M12 12L5.636 5.636"/>
                </svg>
            </div>
            <h2>Access Denied</h2>
            <p>This task is not assigned to you. Only assigned users can complete tasks.</p>
            <div class="error-actions">
                <button class="back-btn" on:click={() => goto('/mobile/tasks')}>
                    ← Back to Tasks
                </button>
            </div>
        </div>
    {:else}
        <!-- Task Details Section -->
        <div class="task-details-section">
            <div class="details-header">
                <h3>📋 Task Details</h3>
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
                            <label>📝 Title:</label>
                            <span class="value">{taskDetails.title}</span>
                        </div>
                        
                        <div class="detail-item">
                            <label>🎯 Priority:</label>
                            <span class="priority-badge {getPriorityColor(taskDetails.priority)}">
                                {taskDetails.priority?.toUpperCase() || 'MEDIUM'}
                            </span>
                        </div>
                        
                        <div class="detail-item">
                            <label>📅 Created:</label>
                            <span class="value">{formatDate(taskDetails.created_at)}</span>
                        </div>
                        
                        <div class="detail-item">
                            <label>⏰ Deadline:</label>
                            <span class="value">
                                {#if assignmentDetails?.deadline_datetime}
                                    {formatDate(assignmentDetails.deadline_datetime)} at {formatTime(assignmentDetails.deadline_datetime)}
                                {:else if assignmentDetails?.deadline_date}
                                    {formatDate(assignmentDetails.deadline_date)}
                                    {#if assignmentDetails?.deadline_time}
                                        at {assignmentDetails.deadline_time}
                                    {/if}
                                {:else}
                                    No deadline set
                                {/if}
                            </span>
                        </div>

                        {#if assignmentDetails?.deadline_datetime || assignmentDetails?.deadline_date}
                            <div class="detail-item">
                                <label>⚠️ Status:</label>
                                <span class="value {isOverdue(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date) ? 'overdue' : 'on-time'}">
                                    {#if isOverdue(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date)}
                                        Overdue by {getOverdueTime(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date)}
                                    {:else}
                                        {liveCountdown} remaining
                                    {/if}
                                </span>
                            </div>
                        {/if}

                        {#if assignmentDetails}
                            <div class="detail-item">
                                <label>📌 Assigned to:</label>
                                <span class="value">{assignedToUserName}</span>
                            </div>
                            
                            <div class="detail-item">
                                <label>👤 Assigned by:</label>
                                <span class="value">{assignedByUserName}</span>
                            </div>
                        {/if}
                    </div>

                    {#if taskDetails.description}
                        <div class="description-block">
                            <label>📄 Description:</label>
                            <div class="description-text">{taskDetails.description}</div>
                        </div>
                    {/if}

                    {#if assignmentDetails?.notes}
                        <div class="description-block">
                            <label>📝 Assignment Notes:</label>
                            <div class="description-text">{assignmentDetails.notes}</div>
                        </div>
                    {/if}

                    {#if taskImages.length > 0}
                        <div class="images-section">
                            <label>🖼️ Task Images:</label>
                            <div class="images-grid">
                                {#each taskImages as image}
                                    <div class="image-item" on:click={() => openImageModal(image.image_url)} role="button" tabindex="0">
                                        <img src={image.image_url} alt="Task image" loading="lazy" />
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {/if}

                    {#if taskAttachments.length > 0}
                        <div class="attachments-section">
                            <label>📎 Task Files:</label>
                            <div class="attachments-list">
                                {#each taskAttachments as attachment}
                                    <div class="attachment-item">
                                        <div class="attachment-info">
                                            <div class="attachment-name">{attachment.fileName}</div>
                                            <div class="attachment-meta">
                                                {#if attachment.fileSize}
                                                    {Math.round(attachment.fileSize / 1024)} KB • 
                                                {/if}
                                                {attachment.uploadedBy}
                                            </div>
                                        </div>
                                        <button 
                                            class="download-btn"
                                            on:click={() => downloadFile(attachment.fileUrl, attachment.fileName)}
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
            <button class="cancel-btn" on:click={() => goto('/mobile/tasks')} disabled={isSubmitting}>
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
    {/if}
</div>

<!-- Image Modal -->
{#if showImageModal}
    <div class="modal-overlay" on:click={closeImageModal} role="button" tabindex="0">
        <div class="image-modal" on:click|stopPropagation role="dialog" tabindex="-1">
            <button class="image-close-btn" on:click={closeImageModal}>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M18 6L6 18M6 6l12 12"/>
                </svg>
            </button>
            <img
                src={selectedImageUrl}
                alt="Task image full size"
                class="modal-image"
            />
        </div>
    </div>
{/if}

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

    .detail-item label {
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

    .description-block label {
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

    .images-section,
    .attachments-section {
        margin-top: 1.5rem;
    }

    .images-section label,
    .attachments-section label {
        display: block;
        font-size: 0.875rem;
        font-weight: 600;
        color: #374151;
        margin-bottom: 0.75rem;
    }

    .images-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
        gap: 0.75rem;
    }

    .image-item {
        aspect-ratio: 1;
        border-radius: 8px;
        overflow: hidden;
        cursor: pointer;
        transition: transform 0.2s;
    }

    .image-item:hover {
        transform: scale(1.05);
    }

    .image-item img {
        width: 100%;
        height: 100%;
        object-fit: cover;
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
        width: 20px;
        height: 20px;
        accent-color: #10B981;
        cursor: pointer;
        border: 2px solid #10B981;
        border-radius: 4px;
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
        border-radius: 8px;
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

    .erp-input,
    .notes-textarea {
        width: 100%;
        padding: 0.75rem;
        border: 2px solid #D1D5DB;
        border-radius: 8px;
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

    .erp-input:focus,
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

    /* Modal Styles */
    .modal-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.8);
        z-index: 1000;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 1rem;
    }

    .image-modal {
        position: relative;
        max-width: 90vw;
        max-height: 90vh;
        display: flex;
        justify-content: center;
        align-items: center;
    }

    .image-close-btn {
        position: absolute;
        top: 1rem;
        right: 1rem;
        background: rgba(0, 0, 0, 0.7);
        color: white;
        border: none;
        border-radius: 50%;
        width: 3rem;
        height: 3rem;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        z-index: 10;
        transition: background-color 0.2s;
    }

    .image-close-btn:hover {
        background: rgba(0, 0, 0, 0.9);
    }

    .modal-image {
        max-width: 100%;
        max-height: 100%;
        object-fit: contain;
        border-radius: 8px;
    }

    @keyframes spin {
        to {
            transform: rotate(360deg);
        }
    }

    /* Mobile optimizations */
    @media (max-width: 640px) {
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

        .images-grid {
            grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
        }
    }

    /* Safe area handling */
    @supports (padding: max(0px)) {
        .actions {
            padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
        }
    }
</style>