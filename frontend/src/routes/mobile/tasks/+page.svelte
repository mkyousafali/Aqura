<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase, db } from '$lib/utils/supabase';
	import { locale, getTranslation } from '$lib/i18n';

	let currentUserData = null;
	let tasks = [];
	let filteredTasks = [];
	let isLoading = true;
	let searchTerm = '';
	let filterStatus = 'all';
	let filterPriority = 'all';

	// Image preview modal variables
	let showImagePreview = false;
	let previewImageSrc = '';
	let previewImageAlt = '';

	onMount(async () => {
		currentUserData = $currentUser;
		if (currentUserData) {
			await loadTasks();
		}
		isLoading = false;
	});

	async function loadTasks() {
		try {
			// Load regular task assignments
			const { data: taskAssignments, error } = await supabase
				.from('task_assignments')
				.select(`
					*,
					task:tasks!inner(
						id,
						title,
						description,
						priority,
						due_date,
						due_time,
						status,
						created_at,
						created_by,
						created_by_name,
						require_task_finished,
						require_photo_upload,
						require_erp_reference
					)
				`)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('assigned_at', { ascending: false });

			if (error) throw error;

			// Load quick task assignments
			const { data: quickTaskAssignments, error: quickError } = await supabase
				.from('quick_task_assignments')
				.select(`
					*,
					quick_task:quick_tasks!inner(
						id,
						title,
						description,
						priority,
						deadline_datetime,
						status,
						created_at,
						assigned_by
					)
				`)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('created_at', { ascending: false });

			if (quickError) throw quickError;

			// Process regular tasks and load attachments
			const processedTasks = [];
			for (const assignment of taskAssignments) {
				// Load task attachments
				const attachmentResult = await db.taskAttachments.getByTaskId(assignment.task.id);
				const hasAttachments = attachmentResult.data && attachmentResult.data.length > 0;
				
				const processedTask = {
					...assignment.task,
					assignment_id: assignment.id,
					assignment_status: assignment.status,
					assigned_at: assignment.assigned_at,
					deadline_date: assignment.deadline_date,
					deadline_time: assignment.deadline_time,
					assigned_by: assignment.assigned_by,
					assigned_by_name: assignment.assigned_by_name,
					// Include requirement flags from assignment
					require_task_finished: assignment.require_task_finished ?? true,
					require_photo_upload: assignment.require_photo_upload ?? false,
					require_erp_reference: assignment.require_erp_reference ?? false,
					// Add attachment information
					hasAttachments: hasAttachments,
					attachments: attachmentResult.data || [],
					// Mark as regular task
					task_type: 'regular'
				};
				
				processedTasks.push(processedTask);
			}

			// Process quick tasks (no attachments for quick tasks)
			for (const assignment of quickTaskAssignments) {
				const processedQuickTask = {
					...assignment.quick_task,
					assignment_id: assignment.id,
					assignment_status: assignment.status,
					assigned_at: assignment.created_at, // Use created_at from quick_task_assignments
					deadline_date: assignment.quick_task.deadline_datetime ? assignment.quick_task.deadline_datetime.split('T')[0] : null, // Extract date from datetime
					deadline_time: assignment.quick_task.deadline_datetime ? assignment.quick_task.deadline_datetime.split('T')[1]?.substring(0, 5) : null, // Extract time from datetime
					assigned_by: assignment.quick_task.assigned_by, // Get from quick_task
					assigned_by_name: 'Quick Task Creator', // Default since we don't have this info
					created_by: assignment.quick_task.assigned_by, // Use assigned_by as created_by for quick tasks
					created_by_name: 'Quick Task Creator', // Default since we don't have this info
					// Quick tasks have simplified requirements
					require_task_finished: true,
					require_photo_upload: false,
					require_erp_reference: false,
					// No attachments for quick tasks
					hasAttachments: false,
					attachments: [],
					// Mark as quick task
					task_type: 'quick'
				};
				
				processedTasks.push(processedQuickTask);
			}

			// Sort all tasks by assigned_at date (most recent first)
			tasks = processedTasks.sort((a, b) => new Date(b.assigned_at) - new Date(a.assigned_at));
			filterTasks();
		} catch (error) {
			console.error('Error loading tasks:', error);
		}
	}

	function filterTasks() {
		console.log('Filtering tasks:', { 
			totalTasks: tasks.length, 
			searchTerm, 
			filterStatus, 
			filterPriority 
		});
		
		filteredTasks = tasks.filter(task => {
			// Safe search - handle null/undefined values
			const title = task.title || '';
			const description = task.description || '';
			const matchesSearch = searchTerm === '' || 
				title.toLowerCase().includes(searchTerm.toLowerCase()) ||
				description.toLowerCase().includes(searchTerm.toLowerCase());
			
			const matchesStatus = filterStatus === 'all' || task.assignment_status === filterStatus;
			const matchesPriority = filterPriority === 'all' || task.priority === filterPriority;
			
			return matchesSearch && matchesStatus && matchesPriority;
		});
		
		console.log('Filtered tasks result:', filteredTasks.length);
	}

	function formatDate(dateString) {
		if (!dateString) return '';
		const date = new Date(dateString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
		
		if (diffHours < 1) {
			const diffMinutes = Math.floor(diffMs / (1000 * 60));
			return diffMinutes < 1 ? 'Just now' : `${diffMinutes}m ago`;
		} else if (diffHours < 24) {
			return `${diffHours}h ago`;
		} else {
			const diffDays = Math.floor(diffHours / 24);
			return diffDays === 1 ? 'Yesterday' : `${diffDays}d ago`;
		}
	}

	function formatExactDeadline(deadlineDate, deadlineTime) {
		if (!deadlineDate) return 'No deadline';
		
		try {
			// Combine date and time if both are available
			let dateTimeString = deadlineDate;
			if (deadlineTime) {
				dateTimeString = `${deadlineDate}T${deadlineTime}`;
			}
			
			const deadline = new Date(dateTimeString);
			const now = new Date();
			
			// Format as dd-mm-yyyy
			const day = deadline.getDate().toString().padStart(2, '0');
			const month = (deadline.getMonth() + 1).toString().padStart(2, '0');
			const year = deadline.getFullYear();
			const formattedDate = `${day}-${month}-${year}`;
			
			// Format time as HH:MM AM/PM
			const hours = deadline.getHours();
			const minutes = deadline.getMinutes().toString().padStart(2, '0');
			const ampm = hours >= 12 ? 'PM' : 'AM';
			const displayHours = hours % 12 || 12;
			const formattedTime = `${displayHours}:${minutes} ${ampm}`;
			
			// Check if it's overdue
			const isOverdue = deadline < now;
			const overduePrefix = isOverdue ? '⚠️ ' : '';
			
			return `${overduePrefix}Deadline: ${formattedDate} ${formattedTime}`;
		} catch (error) {
			console.error('Error formatting deadline:', error);
			return deadlineDate;
		}
	}

	function downloadTaskAttachments(task) {
		if (!task.attachments || task.attachments.length === 0) {
			console.log('No attachments to download');
			return;
		}

		// Download all attachments
		task.attachments.forEach(attachment => {
			const downloadUrl = attachment.file_path && attachment.file_path.startsWith('http') 
				? attachment.file_path 
				: `https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/task-images/${attachment.file_path || ''}`;
			
			const link = document.createElement('a');
			link.href = downloadUrl;
			link.download = attachment.file_name || 'attachment';
			link.target = '_blank';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
		});
	}

	// Helper function to get proper file URL for attachments
	function getFileUrl(attachment) {
		if (attachment.file_path) {
			if (attachment.file_path.startsWith('http')) {
				return attachment.file_path;
			}
			return `https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/task-images/${attachment.file_path}`;
		}
		return null;
	}

	// Image preview functions
	function openImagePreview(attachment) {
		const imageUrl = getFileUrl(attachment);
		if (imageUrl) {
			previewImageSrc = imageUrl;
			previewImageAlt = attachment.file_name || 'Task attachment';
			showImagePreview = true;
		}
	}

	function closeImagePreview() {
		showImagePreview = false;
		previewImageSrc = '';
		previewImageAlt = '';
	}

	// Download single attachment
	function downloadSingleAttachment(attachment) {
		const downloadUrl = getFileUrl(attachment);
		if (downloadUrl) {
			const link = document.createElement('a');
			link.href = downloadUrl;
			link.download = attachment.file_name || 'attachment';
			link.target = '_blank';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
		}
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return '#EF4444';
			case 'medium': return '#F59E0B';
			case 'low': return '#10B981';
			default: return '#6B7280';
		}
	}

	function getStatusColor(status) {
		switch (status) {
			case 'assigned': return '#3B82F6';
			case 'in_progress': return '#F59E0B';
			case 'completed': return '#10B981';
			case 'cancelled': return '#EF4444';
			default: return '#6B7280';
		}
	}

	function isOverdue(deadlineDate, deadlineTime) {
		if (!deadlineDate) return false;
		
		const now = new Date();
		const deadline = new Date(deadlineDate);
		
		if (deadlineTime) {
			const [hours, minutes] = deadlineTime.split(':');
			deadline.setHours(parseInt(hours), parseInt(minutes));
		}
		
		return now > deadline;
	}

	function getStatusDisplayText(status) {
		switch (status) {
			case 'assigned': return 'PENDING';
			case 'in_progress': return 'IN PROGRESS';
			case 'completed': return 'COMPLETED';
			case 'cancelled': return 'CANCELLED';
			case 'escalated': return 'ESCALATED';
			case 'reassigned': return 'REASSIGNED';
			default: return status?.replace('_', ' ').toUpperCase() || 'UNKNOWN';
		}
	}

	async function markAsComplete(task) {
		// Navigate to the appropriate completion page based on task type
		if (task.task_type === 'quick') {
			goto(`/mobile/quick-tasks/${task.id}/complete`);
		} else {
			goto(`/mobile/tasks/${task.id}/complete`);
		}
	}

	function navigateToTask(task) {
		// Navigate to the appropriate task view based on task type
		if (task.task_type === 'quick') {
			// For quick tasks, go directly to completion since they don't have detailed view pages
			goto(`/mobile/quick-tasks/${task.id}/complete`);
		} else {
			goto(`/mobile/tasks/${task.id}`);
		}
	}

	// Reactive filtering - trigger when search term or filters change
	$: searchTerm, filterStatus, filterPriority, filterTasks();
</script>

<svelte:head>
	<title>{getTranslation('mobile.tasksContent.title')}</title>
</svelte:head>

<div class="mobile-tasks">
	<!-- Filters -->
	<div class="filters-section">
		<div class="search-box">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="11" cy="11" r="8"/>
				<path d="M21 21l-4.35-4.35"/>
			</svg>
			<input
				type="text"
				placeholder={getTranslation('mobile.tasksContent.searchPlaceholder')}
				bind:value={searchTerm}
				class="search-input"
			/>
		</div>

		<div class="filter-chips">
			<select bind:value={filterStatus} class="filter-select">
				<option value="all">{getTranslation('mobile.tasksContent.filters.allStatus')}</option>
				<option value="pending">{getTranslation('mobile.tasksContent.filters.pending')}</option>
				<option value="in_progress">{getTranslation('mobile.tasksContent.filters.inProgress')}</option>
				<option value="completed">{getTranslation('mobile.tasksContent.filters.completed')}</option>
				<option value="cancelled">{getTranslation('mobile.tasksContent.filters.cancelled')}</option>
			</select>

			<select bind:value={filterPriority} class="filter-select">
				<option value="all">{getTranslation('mobile.tasksContent.filters.allPriority')}</option>
				<option value="high">{getTranslation('mobile.tasksContent.filters.high')}</option>
				<option value="medium">{getTranslation('mobile.tasksContent.filters.medium')}</option>
				<option value="low">{getTranslation('mobile.tasksContent.filters.low')}</option>
			</select>
		</div>

		<div class="results-count">
			{filteredTasks.length} {filteredTasks.length !== 1 ? getTranslation('mobile.tasksContent.results.tasksFound') : getTranslation('mobile.tasksContent.results.taskFound')}
		</div>
	</div>

	<!-- Content -->
	<div class="content-section">
		{#if isLoading}
			<div class="loading-state">
				<div class="loading-spinner"></div>
				<p>{getTranslation('mobile.tasksContent.loading')}</p>
			</div>
		{:else if filteredTasks.length === 0}
			<div class="empty-state">
				<div class="empty-icon">
					<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
						<path d="M9 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-4"/>
						<rect x="9" y="7" width="6" height="5"/>
					</svg>
				</div>
				<h2>{getTranslation('mobile.tasksContent.emptyState.title')}</h2>
				<p>{getTranslation('mobile.tasksContent.emptyState.description')}</p>
			</div>
		{:else}
			<div class="task-list">
				{#each filteredTasks as task (task.assignment_id)}
					<div class="task-card" class:overdue={isOverdue(task.deadline_date, task.deadline_time)}>
						<div class="task-header" 
							on:click={() => navigateToTask(task)}
							on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && navigateToTask(task)}
							role="button" 
							tabindex="0"
						>
							<div class="task-title-section">
								<h3>{task.title}</h3>
								<div class="task-meta">
									{#if task.task_type === 'quick'}
										<span class="task-type-badge quick-task">⚡ {getTranslation('mobile.tasksContent.taskCard.quickTask')}</span>
									{/if}
									<span class="task-priority" style="background-color: {getPriorityColor(task.priority)}15; color: {getPriorityColor(task.priority)}">
										{task.priority?.toUpperCase()}
									</span>
									<span class="task-status" style="background-color: {getStatusColor(task.assignment_status)}15; color: {getStatusColor(task.assignment_status)}">
										{getStatusDisplayText(task.assignment_status)}
									</span>
								</div>
							</div>
							{#if isOverdue(task.deadline_date, task.deadline_time) && task.assignment_status !== 'completed'}
								<div class="overdue-badge">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<line x1="12" y1="8" x2="12" y2="12"/>
										<line x1="12" y1="16" x2="12.01" y2="16"/>
									</svg>
								</div>
							{/if}
						</div>

						<div class="task-content" 
							on:click={() => goto(`/mobile/tasks/${task.id}`)}
							on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && goto(`/mobile/tasks/${task.id}`)}
							role="button" 
							tabindex="0"
						>
							<p class="task-description">{task.description}</p>
							
							<div class="task-details">
								{#if task.deadline_date}
									<div class="task-detail">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<circle cx="12" cy="12" r="10"/>
											<polyline points="12,6 12,12 16,14"/>
										</svg>
										<span class="deadline-text">{formatExactDeadline(task.deadline_date, task.deadline_time)}</span>
									</div>
								{/if}
								
								<div class="task-detail">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
										<circle cx="12" cy="7" r="4"/>
									</svg>
									<span>{getTranslation('mobile.tasksContent.taskCard.by')} {task.assigned_by_name || task.created_by_name || getTranslation('mobile.tasksContent.taskCard.unknown')}</span>
								</div>
								
								<div class="task-detail">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/>
										<polyline points="12,6 12,12 16,14"/>
									</svg>
									<span>{getTranslation('mobile.tasksContent.taskCard.assigned')} {formatDate(task.assigned_at)}</span>
								</div>

								{#if task.hasAttachments}
									<div class="task-detail">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
										</svg>
										<span>{task.attachments.length} {task.attachments.length !== 1 ? getTranslation('mobile.tasksContent.taskCard.attachments') : getTranslation('mobile.tasksContent.taskCard.attachment')}</span>
									</div>
									
									<!-- Individual attachments with preview and download -->
									<div class="attachments-grid" on:click|stopPropagation>
										{#each task.attachments as attachment}
											<div class="attachment-item">
												{#if attachment.file_type && attachment.file_type.startsWith('image/')}
													<!-- Image attachment with preview -->
													<div class="attachment-image-container">
														<img 
															src={getFileUrl(attachment)} 
															alt={attachment.file_name} 
															loading="lazy"
															class="attachment-image-preview"
															on:click={() => openImagePreview(attachment)}
														/>
														<div class="attachment-actions">
															<button 
																class="attachment-download-btn"
																on:click={() => downloadSingleAttachment(attachment)}
																title="Download {attachment.file_name}"
															>
																<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																	<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
																	<polyline points="7,10 12,15 17,10"/>
																	<line x1="12" y1="15" x2="12" y2="3"/>
																</svg>
															</button>
														</div>
													</div>
													<div class="attachment-info">
														<span class="attachment-name">{attachment.file_name}</span>
														<span class="attachment-source">Task Image</span>
													</div>
												{:else}
													<!-- File attachment -->
													<div class="attachment-file">
														<div class="file-icon">
															<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																<path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"/>
															</svg>
														</div>
														<div class="attachment-info">
															<span class="attachment-name">{attachment.file_name}</span>
															<span class="attachment-source">Task File</span>
														</div>
														<button 
															class="attachment-download-btn"
															on:click={() => downloadSingleAttachment(attachment)}
															title="Download {attachment.file_name}"
														>
															<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
																<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
																<polyline points="7,10 12,15 17,10"/>
																<line x1="12" y1="15" x2="12" y2="3"/>
															</svg>
														</button>
													</div>
												{/if}
											</div>
										{/each}
									</div>
								{/if}
							</div>
						</div>

						{#if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled'}
							<div class="task-actions">
								<button class="complete-btn" on:click={() => markAsComplete(task)} disabled={isLoading}>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<polyline points="20,6 9,17 4,12"/>
									</svg>
									{getTranslation('mobile.tasksContent.taskCard.markComplete')}
								</button>
								<button class="view-btn" on:click={() => navigateToTask(task)}>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
										<circle cx="12" cy="12" r="3"/>
									</svg>
									{getTranslation('mobile.tasksContent.taskCard.viewDetails')}
								</button>
							</div>
						{:else}
							<div class="task-actions">
								<button class="view-btn full-width" on:click={() => navigateToTask(task)}>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
										<circle cx="12" cy="12" r="3"/>
									</svg>
									{getTranslation('mobile.tasksContent.taskCard.viewDetails')}
								</button>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<!-- Image Preview Modal -->
{#if showImagePreview}
	<div class="image-preview-modal" on:click={closeImagePreview}>
		<div class="image-preview-container" on:click|stopPropagation>
			<button class="image-preview-close" on:click={closeImagePreview}>
				<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="18" y1="6" x2="6" y2="18"></line>
					<line x1="6" y1="6" x2="18" y2="18"></line>
				</svg>
			</button>
			<img src={previewImageSrc} alt={previewImageAlt} class="image-preview-img" />
		</div>
	</div>
{/if}

<style>
	.mobile-tasks {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	/* Filters */
	.filters-section {
		padding: 1.2rem; /* Reduced from 1.5rem (20% smaller) */
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.search-box {
		position: relative;
		margin-bottom: 0.8rem; /* Reduced from 1rem (20% smaller) */
	}

	.search-box svg {
		position: absolute;
		left: 1rem;
		top: 50%;
		transform: translateY(-50%);
		color: #9CA3AF;
	}

	.search-input {
		width: 100%;
		padding: 0.6rem 0.8rem 0.6rem 2.4rem; /* Reduced padding (20% smaller) */
		border: 2px solid #E5E7EB;
		border-radius: 10px; /* Reduced from 12px */
		font-size: 0.8rem; /* Reduced from 1rem (20% smaller) */
		background: #F9FAFB;
		color: #374151;
		transition: all 0.3s ease;
		box-sizing: border-box;
	}

	.search-input:focus {
		outline: none;
		border-color: #3B82F6;
		background: white;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.filter-chips {
		display: flex;
		gap: 0.6rem; /* Reduced from 0.75rem (20% smaller) */
		margin-bottom: 0.8rem; /* Reduced from 1rem (20% smaller) */
	}

	.filter-select {
		flex: 1;
		padding: 0.4rem 0.6rem; /* Reduced from 0.5rem 0.75rem */
		border: 2px solid #E5E7EB;
		border-radius: 6px; /* Reduced from 8px */
		font-size: 0.7rem; /* Reduced from 0.875rem (20% smaller) */
		background: white;
		color: #374151;
		cursor: pointer;
		transition: all 0.3s ease;
	}

	.filter-select:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.results-count {
		font-size: 0.7rem; /* Reduced from 0.875rem (20% smaller) */
		color: #6B7280;
		text-align: center;
	}

	/* Content */
	.content-section {
		padding: 1.2rem; /* Reduced from 1.5rem (20% smaller) */
		padding-bottom: calc(1.2rem + env(safe-area-inset-bottom));
	}

	/* Loading State */
	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		color: #6B7280;
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

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Empty State */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
	}

	.empty-icon {
		width: 80px;
		height: 80px;
		background: #F3F4F6;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 1.5rem;
		color: #9CA3AF;
	}

	.empty-state h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.5rem 0;
	}

	.empty-state p {
		font-size: 1rem;
		color: #6B7280;
		margin: 0 0 2rem 0;
		line-height: 1.5;
	}

	/* Task List */
	.task-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.task-card {
		background: white;
		border-radius: 16px;
		overflow: hidden;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		transition: all 0.3s ease;
		border: 2px solid transparent;
	}

	.task-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.task-card.overdue {
		border-color: #FEE2E2;
		background: linear-gradient(to right, #FEF2F2, white);
	}

	.task-header {
		padding: 0.8rem 0.8rem 0.4rem; /* Reduced from 1rem 1rem 0.5rem */
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		cursor: pointer;
		touch-action: manipulation;
	}

	.task-title-section {
		flex: 1;
	}

	.task-header h3 {
		font-size: 0.88rem; /* Reduced from 1.1rem (20% smaller) */
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.6rem 0; /* Reduced from 0.75rem */
		line-height: 1.4;
	}

	.task-meta {
		display: flex;
		gap: 0.4rem; /* Reduced from 0.5rem (20% smaller) */
		flex-wrap: wrap;
	}

	.task-priority,
	.task-status,
	.task-type-badge {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 6px;
		text-transform: uppercase;
	}

	.task-type-badge.quick-task {
		background-color: #f59e0b15;
		color: #f59e0b;
		text-transform: none;
		font-weight: 500;
	}

	.overdue-badge {
		width: 32px;
		height: 32px;
		background: #FEE2E2;
		color: #DC2626;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.task-content {
		padding: 0 1rem 1rem;
		cursor: pointer;
		touch-action: manipulation;
	}

	.task-description {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0 0 1rem 0;
		line-height: 1.5;
		display: -webkit-box;
		-webkit-line-clamp: 3;
		line-clamp: 3;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.task-details {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.task-detail {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	.task-detail svg {
		flex-shrink: 0;
	}

	.deadline-text {
		color: #EF4444 !important;
		font-weight: 600;
	}

	.attachments-indicator {
		position: relative;
	}

	.download-attachments-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 0.25rem;
		margin-left: 0.5rem;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.2s ease;
		font-size: 0.75rem;
	}

	.download-attachments-btn:hover {
		background: #2563EB;
		transform: scale(1.05);
	}

	.download-attachments-btn:active {
		transform: scale(0.95);
	}

	/* Task Actions */
	.task-actions {
		padding: 1rem;
		border-top: 1px solid #F3F4F6;
		display: flex;
		gap: 0.75rem;
	}

	.complete-btn,
	.view-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		border: none;
		border-radius: 10px;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.complete-btn {
		background: #10B981;
		color: white;
	}

	.complete-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.complete-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	.view-btn {
		background: #F3F4F6;
		color: #374151;
	}

	.view-btn:hover {
		background: #E5E7EB;
		transform: translateY(-1px);
	}

	.view-btn.full-width {
		flex: unset;
		width: 100%;
	}

	/* Attachment Styles */
	.attachments-grid {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-top: 0.5rem;
	}

	.attachment-item {
		background: #F8F9FA;
		border: 1px solid #E5E7EB;
		border-radius: 8px;
		padding: 0.5rem;
	}

	.attachment-image-container {
		position: relative;
		display: flex;
		align-items: center;
		gap: 0.80rem;
	}

	.attachment-image-preview {
		width: 80px;
		height: 80px;
		object-fit: cover;
		border-radius: 6px;
		cursor: pointer;
		transition: transform 0.2s ease;
	}

	.attachment-image-preview:hover {
		transform: scale(1.05);
	}

	.attachment-file {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.file-icon {
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #E5E7EB;
		border-radius: 6px;
		color: #6B7280;
	}

	.attachment-info {
		flex: 1;
		min-width: 0;
	}

	.attachment-name {
		display: block;
		font-size: 0.75rem;
		font-weight: 500;
		color: #374151;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.attachment-source {
		display: block;
		font-size: 0.65rem;
		color: #6B7280;
		margin-top: 0.125rem;
	}

	.attachment-actions {
		position: absolute;
		top: 0.25rem;
		right: 0.25rem;
	}

	.attachment-download-btn {
		background: rgba(0, 0, 0, 0.6);
		color: white;
		border: none;
		border-radius: 4px;
		padding: 0.25rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s ease;
	}

	.attachment-download-btn:hover {
		background: rgba(0, 0, 0, 0.8);
	}

	.attachment-file .attachment-download-btn {
		background: #F3F4F6;
		color: #374151;
		position: relative;
		top: unset;
		right: unset;
	}

	.attachment-file .attachment-download-btn:hover {
		background: #E5E7EB;
	}

	/* Image Preview Modal */
	.image-preview-modal {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.9);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
	}

	.image-preview-container {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.image-preview-close {
		position: absolute;
		top: -40px;
		right: 0;
		background: rgba(255, 255, 255, 0.1);
		color: white;
		border: none;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: background-color 0.2s ease;
	}

	.image-preview-close:hover {
		background: rgba(255, 255, 255, 0.2);
	}

	.image-preview-img {
		max-width: 100%;
		max-height: 100%;
		object-fit: contain;
		border-radius: 8px;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.page-header {
			padding: 1rem;
			padding-top: calc(1rem + env(safe-area-inset-top));
		}

		.filters-section,
		.content-section {
			padding: 1rem;
		}

		.filter-chips {
			flex-direction: column;
		}

		.task-card {
			border-radius: 12px;
		}

		.task-actions {
			flex-direction: column;
		}

		.complete-btn,
		.view-btn {
			width: 100%;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.page-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}

		.content-section {
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
	}
</style>