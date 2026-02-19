<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
    import { supabase, db, resolveStorageUrl } from '$lib/utils/supabase';
    import { notifications } from '$lib/stores/notifications';
    import { locale, getTranslation } from '$lib/i18n';

    const t = (key: string) => getTranslation(`mobile.taskCompletionPage.${key}`);

    // Get localized content from bilingual strings
    function getLocalizedContent(text: string | null | undefined, type: 'title' | 'description' = 'title'): string {
        if (!text) return '';
        // New format: "English|||العربية"
        if (text.includes('|||')) {
            const parts = text.split('|||');
            return $locale === 'ar' ? (parts[1] || parts[0]).trim() : parts[0].trim();
        }
        const separator = type === 'title' ? '|' : '\n---\n';
        const parts = text.split(separator);
        if (parts.length < 2) return text.trim();
        return $locale === 'ar' ? parts[1].trim() : parts[0].trim();
    }

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

    // Photo upload (multi-photo)
    let photoFiles: File[] = [];
    let photoPreviews: string[] = [];

	// UI state
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
            if (photoFiles.length > 0) completed++;
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
        const photoCheck = !resolvedRequirePhotoUpload || photoFiles.length > 0;
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
                errorMessage = t('invalidTaskId');
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
                            ? resolveStorageUrl(attachment.file_path) 
                            : resolveStorageUrl(attachment.file_path || '', 'task-images'),
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
                    const { data: byUser } = await supabase
                        .from('users')
                        .select('username, hr_employee_master!hr_employee_master_user_id_fkey (name_en, name_ar)')
                        .eq('id', assignmentDetails.assigned_by)
                        .single();
                    if (byUser) {
                        const emp = byUser.hr_employee_master?.[0] || byUser.hr_employee_master;
                        if (emp) {
                            assignedByUserName = $locale === 'ar' ? (emp.name_ar || emp.name_en || byUser.username) : (emp.name_en || byUser.username);
                        } else {
                            assignedByUserName = byUser.username || assignmentDetails.assigned_by_name || '';
                        }
                    } else {
                        assignedByUserName = assignmentDetails.assigned_by_name || '';
                    }
                }
                
                // Fetch assigned to user name
                if (assignmentDetails.assigned_to_user_id) {
                    const { data: toUser } = await supabase
                        .from('users')
                        .select('username, hr_employee_master!hr_employee_master_user_id_fkey (name_en, name_ar)')
                        .eq('id', assignmentDetails.assigned_to_user_id)
                        .single();
                    if (toUser) {
                        const emp = toUser.hr_employee_master?.[0] || toUser.hr_employee_master;
                        if (emp) {
                            assignedToUserName = $locale === 'ar' ? (emp.name_ar || emp.name_en || toUser.username) : (emp.name_en || toUser.username);
                        } else {
                            assignedToUserName = toUser.username || '';
                        }
                    } else {
                        assignedToUserName = '';
                    }
                } else {
                    assignedToUserName = '';
                }
                
                // Start the live countdown timer
                startCountdownTimer();
            }
            
        } catch (error) {
            console.error('Error loading task details:', error);
            errorMessage = t('failedToLoad');
        } finally {
            isLoading = false;
        }
    }

    // Date and time utility functions
    function formatDate(dateString: string): string {
        if (!dateString) return t('notSet');
        try {
            const d = new Date(dateString);
            const day = String(d.getDate()).padStart(2, '0');
            const month = String(d.getMonth() + 1).padStart(2, '0');
            const year = d.getFullYear();
            return `${day}-${month}-${year}`;
        } catch {
            return t('invalidDate');
        }
    }

    function formatTime(datetimeString: string): string {
        if (!datetimeString) return '';
        try {
            return new Date(datetimeString).toLocaleTimeString($locale === 'ar' ? 'ar-SA' : 'en-US', {
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
                return `${diffDays} ${diffDays !== 1 ? t('days') : t('day')}`;
            } else {
                return `${diffHours} ${diffHours !== 1 ? t('hours') : t('hour')}`;
            }
        } catch {
            return '';
        }
    }

    function getTimeUntilDeadline(deadlineString: string): string {
        if (!deadlineString) return '';
        try {
            const deadline = new Date(deadlineString);
            const now = new Date();
            const diffMs = deadline.getTime() - now.getTime();
            
            if (diffMs <= 0) {
                return t('overdueBy');
            }
            
            const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
            const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
            const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
            
            let timeString = '';
            if (days > 0) {
                timeString += `${days} ${days !== 1 ? t('days') : t('day')}`;
            }
            if (hours > 0) {
                if (timeString) timeString += ', ';
                timeString += `${hours} ${hours !== 1 ? t('hours') : t('hour')}`;
            }
            if (minutes > 0 || timeString === '') {
                if (timeString) timeString += ', ';
                timeString += `${minutes} ${minutes !== 1 ? t('minutes') : t('minute')}`;
            }
            
            return timeString;
        } catch {
            return '';
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
                message: t('downloadFailed'),
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
                    errorMessage = t('invalidImageFile');
                    continue;
                }
                
                if (file.size > 5 * 1024 * 1024) {
                    errorMessage = t('imageTooLarge');
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
        
        const urls: string[] = [];
        for (const file of photoFiles) {
            try {
                const fileExt = file.name.split('.').pop();
                const fileName = `task-completion-${taskId}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${fileExt}`;
                
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
                
                const { data: urlData } = supabase.storage
                    .from('completion-photos')
                    .getPublicUrl(fileName);
                
                urls.push(urlData.publicUrl);
            } catch (error) {
                console.error('Error uploading photo:', error);
            }
        }
        return urls;
    }
    
    async function submitCompletion() {
        if (!currentUserData || !canSubmit) return;
        
        isSubmitting = true;
        errorMessage = '';
        successMessage = '';
        
        try {
            let photoUrls: string[] = [];
            
            if (resolvedRequirePhotoUpload && photoFiles.length > 0) {
                try {
                    photoUrls = await uploadPhotos();
                    if (photoUrls.length === 0) {
                        console.warn('Photo upload failed, continuing without photos');
                    }
                } catch (uploadError) {
                    console.error('Photo upload failed:', uploadError);
                }
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
                photo_uploaded_completed: resolvedRequirePhotoUpload ? (photoUrls.length > 0 ? true : false) : null,
                completion_photo_url: photoUrls.length > 0 ? photoUrls.join(',') : null,
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
            
            successMessage = t('successMessage');
            
            notifications.add({
                type: 'success',
                message: t('successMessage'),
                duration: 3000
            });
            
            setTimeout(() => {
                goto('/mobile-interface/tasks');
            }, 2000);
            
        } catch (error) {
            console.error('Error submitting completion:', error);
            errorMessage = error.message || t('failedMessage');
            
            notifications.add({
                type: 'error',
                message: t('failedMessage'),
                duration: 4000
            });
        } finally {
            isSubmitting = false;
        }
    }
</script>

<svelte:head>
    <title>{t('pageTitle')}</title>
</svelte:head>

<div class="mobile-task-completion">
    {#if isLoading}
        <div class="loading-state">
            <div class="loading-spinner"></div>
            <p>{t('loading')}</p>
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
            <h2>{t('taskNotFound')}</h2>
            <p>{t('taskNotFoundDesc')}</p>
        </div>
    {:else if !assignmentDetails || assignmentDetails.assigned_to_user_id !== currentUserData?.id}
        <div class="error-state">
            <div class="error-icon">
                <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <path d="M18.364 5.636L12 12m0 0l-6.364 6.364M12 12l6.364 6.364M12 12L5.636 5.636"/>
                </svg>
            </div>
            <h2>{t('accessDenied')}</h2>
            <p>{t('accessDeniedDesc')}</p>
            <div class="error-actions">
                <button class="back-btn" on:click={() => goto('/mobile-interface/tasks')}>
                    {t('backToTasks')}
                </button>
            </div>
        </div>
    {:else}
        <!-- Compact Task Info Bar -->
        <div class="task-info-bar">
            <div class="info-bar-title">{getLocalizedContent(taskDetails.title)}</div>
            <div class="info-bar-row">
                <span class="priority-badge {getPriorityColor(taskDetails.priority)}">
                    {getTranslation(`mobile.assignmentsContent.priorities.${taskDetails.priority?.toLowerCase() || 'medium'}`)}
                </span>
                {#if assignmentDetails?.deadline_datetime || assignmentDetails?.deadline_date}
                    <span class="info-chip {isOverdue(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date) ? 'overdue' : 'on-time'}">
                        {#if isOverdue(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date)}
                            {t('overdueBy')} {getOverdueTime(assignmentDetails.deadline_datetime || assignmentDetails.deadline_date)}
                        {:else}
                            {liveCountdown} {t('remaining')}
                        {/if}
                    </span>
                {/if}
            </div>
            {#if assignedByUserName}
                <div class="info-bar-assigned">👤 {t('assignedByLabel')} {assignedByUserName}</div>
            {/if}
        </div>

        <!-- Progress Bar -->
        <div class="progress-section">
            <div class="progress-label">
                {t('completionProgress')}: {completionProgress}%
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
            <h4>{t('completionRequirements')}</h4>
            
            {#if resolvedRequireTaskFinished}
                <div class="requirement-item">
                    <div class="requirement-header">
                        <span class="requirement-label required">{t('taskFinishedRequired')}</span>
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
                        <span class="requirement-label required">{t('uploadPhotoRequired')}</span>
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
                            {t('takePhoto')}
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
                            {t('choosePhoto')} ({photoFiles.length})
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
                        <span class="requirement-label required">{t('erpReferenceRequired')}</span>
                    </div>
                    
                    <div class="input-section">
                        <input
                            type="text"
                            bind:value={completionData.erp_reference_number}
                            placeholder={t('erpReferencePlaceholder')}
                            disabled={isSubmitting}
                            class="erp-input"
                            required
                        />
                    </div>
                </div>
            {/if}
            
            <div class="requirement-item">
                <div class="requirement-header">
                    <span class="requirement-label">{t('additionalNotesOptional')}</span>
                </div>
                
                <div class="input-section">
                    <textarea
                        bind:value={completionData.completion_notes}
                        placeholder={t('notesPlaceholder')}
                        disabled={isSubmitting}
                        class="notes-textarea"
                    ></textarea>
                </div>
            </div>
        </div>

        <!-- Actions -->
        <div class="actions">
            <button class="cancel-btn" on:click={() => goto('/mobile-interface/tasks')} disabled={isSubmitting}>
                {t('cancel')}
            </button>
            <button 
                class="complete-btn" 
                on:click={submitCompletion} 
                disabled={!canSubmit || isSubmitting}
                class:disabled={!canSubmit}
            >
                {#if isSubmitting}
                    <div class="btn-spinner"></div>
                    {t('completing')}
                {:else}
                    {t('completeTask')}
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

    .upload-section {
        margin-top: 0.4rem;
        display: flex;
        gap: 0.5rem;
        flex-wrap: wrap;
    }

    .file-input {
        display: none;
    }

    .upload-btn {
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        padding: 0.5rem 0.85rem;
        background: #3B82F6;
        color: white;
        border-radius: 6px;
        font-size: 0.8rem;
        font-weight: 500;
        cursor: pointer;
        transition: background 0.2s;
        border: none;
        text-decoration: none;
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
    }

    .preview-image {
        width: 100%;
        aspect-ratio: 1;
        object-fit: cover;
        border-radius: 6px;
        border: 1px solid #E5E7EB;
    }

    .remove-photo {
        position: absolute;
        top: -6px;
        right: -6px;
        background: #EF4444;
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
        background: #DC2626;
    }

    .input-section {
        margin-top: 0.4rem;
    }

    .erp-input,
    .notes-textarea {
        width: 100%;
        padding: 0.5rem 0.6rem;
        border: 1.5px solid #D1D5DB;
        border-radius: 6px;
        font-size: 0.8rem;
        background: white;
        transition: border-color 0.2s;
        resize: vertical;
        min-height: 2.5rem;
    }

    .notes-textarea {
        min-height: 60px;
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

        .images-grid {
            grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
        }
    }

    /* Safe area handling */
    @supports (padding: max(0px)) {
        .actions {
            padding-bottom: max(0.6rem, env(safe-area-inset-bottom));
        }
    }
</style>
