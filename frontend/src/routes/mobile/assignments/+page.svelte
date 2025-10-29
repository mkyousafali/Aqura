<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';
	import { locale, getTranslation } from '$lib/i18n';

	// Data
	let assignments = [];
	let filteredAssignments = [];
	let totalStats = {
		total: 0,
		completed: 0,
		in_progress: 0,
		assigned: 0,
		overdue: 0
	};

	// Loading states
	let isLoading = true;

	// Image modal state
	let showImageModal = false;
	let selectedImageUrl = '';

	// Search and filters
	let searchTerm = '';
	let statusFilter = '';
	let priorityFilter = '';
	let showCompleted = false; // Toggle for showing/hiding completed assignments

	// UI state
	let showFilters = false;

	onMount(async () => {
		await loadMyAssignments();
	});

	// Load attachments for assignments - optimized batch loading
	async function loadAssignmentAttachments() {
		// Separate assignments by type
		const quickTaskAssignments = assignments.filter(a => a.task_type === 'quick_task');
		const regularTaskAssignments = assignments.filter(a => a.task_type === 'regular');

		// Batch load quick task files
		if (quickTaskAssignments.length > 0) {
			const quickTaskIds = quickTaskAssignments.map(a => a.quick_task_id || a.task_id);
			try {
				const { data: files } = await supabase
					.from('quick_task_files')
					.select('*')
					.in('quick_task_id', quickTaskIds);
				
				if (files && files.length > 0) {
					// Create a map of quick_task_id to files
					const filesMap = new Map();
					files.forEach(file => {
						if (!filesMap.has(file.quick_task_id)) {
							filesMap.set(file.quick_task_id, []);
						}
						filesMap.get(file.quick_task_id).push({
							...file,
							file_url: `${supabase.supabaseUrl}/storage/v1/object/public/quick-task-files/${file.storage_path}`,
							source: 'quick_task'
						});
					});

					// Assign files to respective assignments
					quickTaskAssignments.forEach(assignment => {
						const taskId = assignment.quick_task_id || assignment.task_id;
						assignment.attachments = filesMap.get(taskId) || [];
					});
				}
			} catch (error) {
				console.error('Error loading quick task files:', error);
			}
		}

		// Batch load regular task images
		if (regularTaskAssignments.length > 0) {
			const taskIds = regularTaskAssignments.map(a => a.task_id);
			try {
				const { data: images } = await supabase
					.from('task_images')
					.select('*')
					.in('task_id', taskIds);
				
				if (images && images.length > 0) {
					// Create a map of task_id to images
					const imagesMap = new Map();
					images.forEach(image => {
						if (!imagesMap.has(image.task_id)) {
							imagesMap.set(image.task_id, []);
						}
						imagesMap.get(image.task_id).push({
							...image,
							file_url: `${supabase.supabaseUrl}/storage/v1/object/public/task-images/${image.file_path}`,
							source: 'task'
						});
					});

					// Assign images to respective assignments
					regularTaskAssignments.forEach(assignment => {
						assignment.attachments = imagesMap.get(assignment.task_id) || [];
					});
				}
			} catch (error) {
				console.error('Error loading task images:', error);
			}
		}
	}

	// Download file function
	async function downloadFile(file) {
		try {
			const response = await fetch(file.file_url);
			const blob = await response.blob();
			const url = window.URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = file.file_name || file.filename || 'download';
			document.body.appendChild(a);
			a.click();
			window.URL.revokeObjectURL(url);
			document.body.removeChild(a);
		} catch (error) {
			console.error('Error downloading file:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to download file',
				duration: 3000
			});
		}
	}

	// Open image preview
	function openImagePreview(imageUrl) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}

	// Close image preview
	function closeImagePreview() {
		showImageModal = false;
		selectedImageUrl = '';
	}

	async function loadMyAssignments() {
		if (!$currentUser) return;

		try {
			isLoading = true;

			// Build queries based on showCompleted toggle
			const regularQuery = supabase
				.from('task_assignments')
				.select(`
					*,
					task:tasks!task_assignments_task_id_fkey (
						id,
						title,
						description,
						priority,
						due_date,
						status,
						created_at
					),
					assigned_user:users!task_assignments_assigned_to_user_id_fkey (
						id,
						username
					)
				`)
				.eq('assigned_by', $currentUser.id)
				.order('assigned_at', { ascending: false });

			const quickQuery = supabase
				.from('quick_task_assignments')
				.select(`
					*,
					quick_task:quick_tasks!inner (
						id,
						title,
						description,
						priority,
						price_tag,
						issue_type,
						status,
						created_at,
						deadline_datetime,
						assigned_by
					),
					assigned_user:users!quick_task_assignments_assigned_to_user_id_fkey (
						id,
						username
					)
				`)
				.eq('quick_task.assigned_by', $currentUser.id)
				.order('created_at', { ascending: false });

			// Only exclude completed if showCompleted is false
			if (!showCompleted) {
				regularQuery.neq('status', 'completed');
				quickQuery.neq('status', 'completed');
			}

			// Parallel loading for better performance
			const [regularResult, quickResult] = await Promise.all([
				regularQuery,
				quickQuery
			]);

			// Process regular assignments
			let regularAssignments = [];
			if (regularResult.data && regularResult.data.length > 0) {
				console.log('Regular assignments data:', regularResult.data);
				regularAssignments = regularResult.data.map(assignment => ({
					...assignment,
					task_type: 'regular'
				}));
			}

			if (regularResult.error) {
				console.error('Error loading regular assignments:', regularResult.error);
			}

			// Process quick task assignments
			let quickAssignments = [];
			if (quickResult.data && quickResult.data.length > 0) {
				console.log('Quick task assignments data:', quickResult.data);
				quickAssignments = quickResult.data.map(assignment => ({
					...assignment,
					task_id: assignment.quick_task.id,
					task: {
						id: assignment.quick_task.id,
						title: assignment.quick_task.title,
						description: assignment.quick_task.description,
						priority: assignment.quick_task.priority,
						due_date: null,
						status: assignment.quick_task.status,
						created_at: assignment.quick_task.created_at,
						price_tag: assignment.quick_task.price_tag,
						issue_type: assignment.quick_task.issue_type,
						deadline_datetime: assignment.quick_task.deadline_datetime
					},
					assigned_at: assignment.created_at,
					deadline_date: assignment.quick_task.deadline_datetime 
						? new Date(assignment.quick_task.deadline_datetime).toISOString().split('T')[0] 
						: null,
					deadline_time: assignment.quick_task.deadline_datetime 
						? new Date(assignment.quick_task.deadline_datetime).toTimeString().split(' ')[0].slice(0, 5) 
						: null,
					task_type: 'quick_task'
				}));
			}

			if (quickResult.error) {
				console.warn('Quick tasks might not be available:', quickResult.error);
			}

			// Combine both types of assignments
			// Only include assignments where current user is the assigner
			assignments = [...regularAssignments, ...quickAssignments].filter(assignment => {
				const assignedBy = assignment.assigned_by || assignment.quick_task?.assigned_by;
				
				// Must be assigned BY current user (includes self-assigned)
				return assignedBy === $currentUser.id;
			});
			
			console.log('Total assignments loaded:', assignments.length);
			console.log('Logged user ID:', $currentUser.id);
			console.log('Sample assignment:', assignments[0]);
			
			// Sort by creation date (newest first)
			assignments.sort((a, b) => new Date(b.assigned_at) - new Date(a.assigned_at));
			
			// Load attachments for all assignments (in parallel)
			await loadAssignmentAttachments();
			
			// Calculate statistics
			calculateStats();
			
			// Apply initial filters
			applyFilters();

		} catch (error) {
			console.error('Error loading assignments:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load assignments: ' + error.message,
				duration: 5000
			});
		} finally {
			isLoading = false;
		}
	}

	function calculateStats() {
		totalStats.total = assignments.length;
		totalStats.completed = assignments.filter(a => a.status === 'completed').length;
		totalStats.in_progress = assignments.filter(a => a.status === 'in_progress').length;
		totalStats.assigned = assignments.filter(a => a.status === 'assigned' || a.status === 'pending').length;
		
		// Calculate overdue
		const now = new Date();
		totalStats.overdue = assignments.filter(a => {
			if (a.status === 'completed') return false;
			
			let deadline = null;
			
			// Handle quick tasks with deadline_datetime
			if (a.task_type === 'quick_task' && a.task?.deadline_datetime) {
				deadline = new Date(a.task.deadline_datetime);
			}
			// Handle regular tasks with deadline_date
			else if (a.deadline_date) {
				deadline = new Date(a.deadline_date);
				if (a.deadline_time) {
					const [hours, minutes] = a.deadline_time.split(':');
					deadline.setHours(parseInt(hours), parseInt(minutes));
				}
			}
			
			return deadline ? deadline < now : false;
		}).length;
	}

	function applyFilters() {
		filteredAssignments = assignments.filter(assignment => {
			// Search filter
			if (searchTerm) {
				const searchLower = searchTerm.toLowerCase();
				const taskTitle = assignment.task?.title?.toLowerCase() || '';
				const userName = assignment.assigned_user?.username?.toLowerCase() || '';
				
				if (!taskTitle.includes(searchLower) && !userName.includes(searchLower)) {
					return false;
				}
			}

			// Status filter
			if (statusFilter && assignment.status !== statusFilter) {
				return false;
			}

			// Priority filter
			if (priorityFilter && assignment.task?.priority !== priorityFilter) {
				return false;
			}

			return true;
		});
	}

	function clearFilters() {
		searchTerm = '';
		statusFilter = '';
		priorityFilter = '';
		showFilters = false;
		applyFilters();
	}

	function toggleFilters() {
		showFilters = !showFilters;
	}

	function formatDate(dateString) {
		if (!dateString) return getTranslation('mobile.assignmentsContent.taskDetails.noDeadline');
		const date = new Date(dateString);
		return date.toLocaleDateString();
	}

	function formatDateTime(dateString, timeString) {
		if (!dateString) return getTranslation('mobile.assignmentsContent.taskDetails.noDeadline');
		const date = new Date(dateString);
		if (timeString) {
			const [hours, minutes] = timeString.split(':');
			date.setHours(parseInt(hours), parseInt(minutes));
			return date.toLocaleString();
		}
		return date.toLocaleDateString();
	}

	function getStatusColor(status) {
		switch (status) {
			case 'assigned': return 'bg-blue-100 text-blue-800';
			case 'in_progress': return 'bg-yellow-100 text-yellow-800';
			case 'completed': return 'bg-green-100 text-green-800';
			case 'cancelled': return 'bg-red-100 text-red-800';
			case 'escalated': return 'bg-purple-100 text-purple-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return 'bg-red-100 text-red-800';
			case 'medium': return 'bg-yellow-100 text-yellow-800';
			case 'low': return 'bg-green-100 text-green-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

	function getStatusDisplayText(status) {
		switch (status) {
			case 'assigned': return getTranslation('mobile.assignmentsContent.statuses.assigned');
			case 'in_progress': return getTranslation('mobile.assignmentsContent.statuses.inProgress');
			case 'completed': return getTranslation('mobile.assignmentsContent.statuses.completed');
			case 'cancelled': return getTranslation('mobile.assignmentsContent.statuses.cancelled');
			case 'escalated': return getTranslation('mobile.assignmentsContent.statuses.escalated');
			case 'reassigned': return getTranslation('mobile.assignmentsContent.statuses.reassigned');
			default: return getTranslation('mobile.assignmentsContent.statuses.unknown');
		}
	}

	function isOverdue(assignment) {
		if (assignment.status === 'completed') return false;
		
		const now = new Date();
		let deadline = null;
		
		// Handle quick tasks with deadline_datetime
		if (assignment.task_type === 'quick_task' && assignment.task?.deadline_datetime) {
			deadline = new Date(assignment.task.deadline_datetime);
		}
		// Handle regular tasks with deadline_date
		else if (assignment.deadline_date) {
			deadline = new Date(assignment.deadline_date);
			if (assignment.deadline_time) {
				const [hours, minutes] = assignment.deadline_time.split(':');
				deadline.setHours(parseInt(hours), parseInt(minutes));
			}
		}
		
		return deadline ? deadline < now : false;
	}

	// Reactive statements
	$: {
		searchTerm, statusFilter, priorityFilter;
		applyFilters();
	}

	// Reload data when showCompleted changes
	$: if (showCompleted !== undefined) {
		loadMyAssignments();
	}
</script>

<svelte:head>
	<title>{getTranslation('mobile.assignmentsContent.title')}</title>
</svelte:head>

<div class="mobile-assignments">

	<!-- Statistics Cards -->
	<section class="stats-section">
		<div class="stats-grid">
			<div class="stat-card total">
				<div class="stat-number">{totalStats.total}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.total')}</div>
			</div>
			<div class="stat-card completed">
				<div class="stat-number">{totalStats.completed}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.completed')}</div>
			</div>
			<div class="stat-card progress">
				<div class="stat-number">{totalStats.in_progress}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.inProgress')}</div>
			</div>
			<div class="stat-card pending">
				<div class="stat-number">{totalStats.assigned}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.pending')}</div>
			</div>
			<div class="stat-card overdue">
				<div class="stat-number">{totalStats.overdue}</div>
				<div class="stat-label">{getTranslation('mobile.assignmentsContent.stats.overdue')}</div>
			</div>
		</div>
	</section>

	<!-- Floating Filter Button -->
	{#if !isLoading && assignments.length > 0}
		<button class="floating-filter-btn" on:click={toggleFilters} class:active={showFilters}>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M3 4h18M7 8h10M10 12h4"/>
			</svg>
			{showFilters ? 'Hide' : 'Filter'}
		</button>
	{/if}

	<!-- Filters (collapsible) -->
	{#if showFilters}
		<section class="filters-section">
			<div class="filters-content">
				<div class="search-box">
					<input
						type="text"
						bind:value={searchTerm}
						placeholder={getTranslation('mobile.assignmentsContent.search.placeholder')}
						class="search-input"
					/>
				</div>
				
				<div class="filter-row">
					<select bind:value={statusFilter} class="filter-select">
						<option value="">{getTranslation('mobile.assignmentsContent.search.allStatuses')}</option>
						<option value="assigned">{getTranslation('mobile.assignmentsContent.statuses.assigned')}</option>
						<option value="in_progress">{getTranslation('mobile.assignmentsContent.statuses.inProgress')}</option>
						<option value="completed">{getTranslation('mobile.assignmentsContent.statuses.completed')}</option>
						<option value="cancelled">{getTranslation('mobile.assignmentsContent.statuses.cancelled')}</option>
						<option value="escalated">{getTranslation('mobile.assignmentsContent.statuses.escalated')}</option>
					</select>

					<select bind:value={priorityFilter} class="filter-select">
						<option value="">{getTranslation('mobile.assignmentsContent.search.allPriorities')}</option>
						<option value="high">{getTranslation('mobile.assignmentsContent.priorities.high')}</option>
						<option value="medium">{getTranslation('mobile.assignmentsContent.priorities.medium')}</option>
						<option value="low">{getTranslation('mobile.assignmentsContent.priorities.low')}</option>
					</select>
				</div>

				<!-- Show Completed Toggle -->
				<div class="toggle-section">
					<label class="toggle-label">
						<input type="checkbox" bind:checked={showCompleted} class="toggle-checkbox" />
						<span class="toggle-text">Show completed assignments</span>
					</label>
				</div>

				<button class="clear-filters-btn" on:click={clearFilters}>
					{getTranslation('mobile.assignmentsContent.search.clearFilters')}
				</button>
			</div>
		</section>
	{/if}

	<!-- Content -->
	<main class="assignments-content">
		{#if isLoading}
			<div class="loading-skeleton">
				{#each Array(5) as _, i}
					<div class="skeleton-card">
						<div class="skeleton-header">
							<div class="skeleton-title"></div>
							<div class="skeleton-badge"></div>
						</div>
						<div class="skeleton-text"></div>
						<div class="skeleton-text short"></div>
						<div class="skeleton-details">
							<div class="skeleton-detail"></div>
							<div class="skeleton-detail"></div>
						</div>
					</div>
				{/each}
			</div>
		{:else if filteredAssignments.length === 0}
			<div class="empty-state">
				<svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
					<path d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"/>
				</svg>
				<h3>{getTranslation('mobile.assignmentsContent.emptyStates.noAssignments')}</h3>
				<p>
					{assignments.length === 0 ? getTranslation('mobile.assignmentsContent.emptyStates.noAssignmentsYet') : getTranslation('mobile.assignmentsContent.emptyStates.noMatchingFilters')}
				</p>
			</div>
		{:else}
			<div class="assignments-list">
				{#each filteredAssignments as assignment}
					<div class="assignment-card" class:overdue={isOverdue(assignment)}>
						<div class="card-header">
							<div class="task-title-section">
								<h3 class="task-title">{assignment.task?.title || getTranslation('mobile.assignmentsContent.taskDetails.unknownTask')}</h3>
								{#if assignment.task_type === 'quick_task'}
									<span class="task-type-badge quick-task">{getTranslation('mobile.assignmentsContent.taskDetails.quickTask')}</span>
								{/if}
							</div>
							<div class="card-badges">
								{#if assignment.task_type === 'quick_task'}
									<span class="quick-task-badge">{getTranslation('mobile.assignmentsContent.taskDetails.quickBadge')}</span>
								{/if}
								{#if assignment.task?.priority}
									<span class="priority-badge {getPriorityColor(assignment.task.priority)}">
										{getTranslation(`mobile.assignmentsContent.priorities.${assignment.task.priority.toLowerCase()}`)}
									</span>
								{/if}
								{#if isOverdue(assignment)}
									<span class="overdue-badge">{getTranslation('mobile.assignmentsContent.taskDetails.overdue')}</span>
								{/if}
							</div>
						</div>

						{#if assignment.task?.description}
							<p class="task-description">{assignment.task.description}</p>
						{/if}

						<div class="assignment-details">
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.assignedTo')}</span>
								<span class="detail-value">{assignment.assigned_user?.username || 'Unknown User'}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">Status:</span>
								<span class="status-badge {getStatusColor(assignment.status)}">
									{getStatusDisplayText(assignment.status)}
								</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">Assigned:</span>
								<span class="detail-value">{formatDate(assignment.assigned_at)}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.deadline')}</span>
								<span class="detail-value">
									{#if assignment.task_type === 'quick_task' && assignment.task?.deadline_datetime}
										{new Date(assignment.task.deadline_datetime).toLocaleString()}
									{:else}
										{formatDateTime(assignment.deadline_date, assignment.deadline_time)}
									{/if}
								</span>
							</div>
						</div>

						{#if assignment.task_type === 'quick_task'}
							<!-- Quick Task specific information -->
							<div class="quick-task-info">
								{#if assignment.task?.price_tag}
									<div class="quick-detail">
										<span class="quick-label">{getTranslation('mobile.assignmentsContent.taskDetails.priceTag')}</span>
										<span class="quick-value">{assignment.task.price_tag}</span>
									</div>
								{/if}
								{#if assignment.task?.issue_type}
									<div class="quick-detail">
										<span class="quick-label">{getTranslation('mobile.assignmentsContent.taskDetails.issueType')}</span>
										<span class="quick-value">{assignment.task.issue_type}</span>
									</div>
								{/if}
							</div>
						{/if}

						{#if assignment.notes}
							<div class="assignment-notes">
								<span class="notes-label">{getTranslation('mobile.assignmentsContent.taskDetails.notes')}</span>
								<p class="notes-text">{assignment.notes}</p>
							</div>
						{/if}

						<!-- Attachments Section -->
						{#if assignment.attachments && assignment.attachments.length > 0}
							<div class="attachments-section">
								<div class="attachments-header">
									<span class="attachments-label">{getTranslation('mobile.assignmentsContent.taskDetails.attachments')} ({assignment.attachments.length})</span>
								</div>
								<div class="attachments-grid">
									{#each assignment.attachments as attachment}
										<div class="attachment-item">
											{#if attachment.file_type && (attachment.file_type.startsWith('image/') || (attachment.file_name && /\.(jpg|jpeg|png|gif|webp)$/i.test(attachment.file_name)))}
												<!-- Image Attachment -->
												<div class="image-attachment">
													<img 
														src={attachment.file_url} 
														alt={attachment.file_name || 'Attachment'}
														class="attachment-thumbnail"
														on:click={() => openImagePreview(attachment.file_url)}
													/>
													<button 
														class="download-btn" 
														on:click|stopPropagation={() => downloadFile(attachment)}
														title="{getTranslation('mobile.assignmentsContent.actions.download')} {attachment.file_name || 'file'}"
													>
														⬇️
													</button>
												</div>
											{:else}
												<!-- File Attachment -->
												<div class="file-attachment">
													<div class="file-icon">📄</div>
													<div class="file-info">
														<span class="file-name">{attachment.file_name || attachment.filename || 'Unknown file'}</span>
														<button 
															class="download-file-btn" 
															on:click={() => downloadFile(attachment)}
														>
															⬇️ {getTranslation('mobile.assignmentsContent.actions.download')}
														</button>
													</div>
												</div>
											{/if}
										</div>
									{/each}
								</div>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</main>

	<!-- Footer Stats -->
	<footer class="mobile-footer">
		<div class="footer-stats">
			<span>{getTranslation('mobile.assignmentsContent.footer.showing')} {filteredAssignments.length} {getTranslation('mobile.assignmentsContent.footer.of')} {assignments.length}</span>
			<span>{getTranslation('mobile.assignmentsContent.footer.completionRate')} {assignments.length > 0 ? Math.round((totalStats.completed / assignments.length) * 100) : 0}%</span>
		</div>
	</footer>
</div>

<!-- Image Preview Modal -->
{#if showImageModal}
	<div class="image-modal-overlay" on:click={closeImagePreview}>
		<div class="image-modal-content" on:click|stopPropagation>
			<img src={selectedImageUrl} alt="Preview" class="modal-image" />
			<button class="modal-close-btn" on:click={closeImagePreview}>×</button>
		</div>
	</div>
{/if}

<style>
	.mobile-assignments {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
		padding-bottom: 5rem; /* Space for bottom nav */
	}

	/* Statistics */
	.stats-section {
		padding: 1rem 1.5rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(5, 1fr);
		gap: 0.75rem;
	}

	.stat-card {
		text-align: center;
		padding: 0.75rem 0.5rem;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
	}

	.stat-card.total { background: #F3F4F6; }
	.stat-card.completed { background: #ECFDF5; border-color: #D1FAE5; }
	.stat-card.progress { background: #FFFBEB; border-color: #FDE68A; }
	.stat-card.pending { background: #EFF6FF; border-color: #DBEAFE; }
	.stat-card.overdue { background: #FEF2F2; border-color: #FECACA; }

	.stat-number {
		font-size: 1.25rem;
		font-weight: 700;
		color: #1F2937;
	}

	.stat-label {
		font-size: 0.75rem;
		color: #6B7280;
		margin-top: 0.25rem;
	}

	/* Filters */
	.floating-filter-btn {
		position: fixed;
		bottom: 6rem;
		right: 1.5rem;
		background: #4F46E5;
		color: white;
		border: none;
		border-radius: 24px;
		padding: 0.75rem 1.25rem;
		font-weight: 600;
		font-size: 0.875rem;
		box-shadow: 0 4px 12px rgba(79, 70, 229, 0.4);
		cursor: pointer;
		z-index: 50;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		transition: all 0.3s ease;
	}

	.floating-filter-btn:hover {
		background: #4338CA;
		box-shadow: 0 6px 16px rgba(79, 70, 229, 0.5);
		transform: translateY(-2px);
	}

	.floating-filter-btn.active {
		background: #DC2626;
	}

	.floating-filter-btn.active:hover {
		background: #B91C1C;
	}

	.filters-section {
		background: white;
		border-bottom: 1px solid #E5E7EB;
		padding: 1rem 1.5rem;
	}

	.search-box {
		margin-bottom: 1rem;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		font-size: 1rem;
	}

	.filter-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.filter-select {
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		background: white;
		font-size: 0.875rem;
	}

	/* RTL Support for select dropdown arrow */
	:global([dir="rtl"]) .filter-select {
		padding-right: 0.75rem;
		padding-left: 2.5rem;
		background-position: left 0.75rem center;
	}

	/* Show Completed Toggle */
	.toggle-section {
		margin: 0.8rem 0;
		padding: 0.6rem 0.8rem;
		background: #F9FAFB;
		border-radius: 8px;
	}

	.toggle-label {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		cursor: pointer;
		user-select: none;
	}

	.toggle-checkbox {
		width: 18px;
		height: 18px;
		cursor: pointer;
		accent-color: #3B82F6;
	}

	.toggle-text {
		font-size: 0.8rem;
		color: #374151;
		font-weight: 500;
	}

	.clear-filters-btn {
		width: 100%;
		padding: 0.75rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 8px;
		color: #374151;
		font-weight: 500;
		cursor: pointer;
	}

	/* Content */
	.assignments-content {
		flex: 1;
		padding: 1rem 1.5rem;
		overflow-y: auto;
	}

	.loading-state, .empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: 4rem 2rem;
		color: #6B7280;
	}

	/* Skeleton Loading */
	.loading-skeleton {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.skeleton-card {
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 12px;
		padding: 1rem;
		animation: pulse 1.5s ease-in-out infinite;
	}

	.skeleton-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.75rem;
		gap: 1rem;
	}

	.skeleton-title {
		height: 1.25rem;
		width: 60%;
		background: #E5E7EB;
		border-radius: 4px;
	}

	.skeleton-badge {
		height: 1.5rem;
		width: 4rem;
		background: #E5E7EB;
		border-radius: 4px;
	}

	.skeleton-text {
		height: 0.875rem;
		width: 100%;
		background: #E5E7EB;
		border-radius: 4px;
		margin-bottom: 0.5rem;
	}

	.skeleton-text.short {
		width: 70%;
	}

	.skeleton-details {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-top: 1rem;
	}

	.skeleton-detail {
		height: 2rem;
		background: #E5E7EB;
		border-radius: 4px;
	}

	@keyframes pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	.empty-state svg {
		color: #9CA3AF;
		margin-bottom: 1rem;
	}

	.empty-state h3 {
		font-size: 1.125rem;
		font-weight: 600;
		color: #374151;
		margin-bottom: 0.5rem;
	}

	/* Assignment Cards */
	.assignments-list {
		space-y: 1rem;
	}

	.assignment-card {
		background: white;
		border: 1px solid #E5E7EB;
		border-radius: 12px;
		padding: 1rem;
		margin-bottom: 1rem;
		transition: all 0.3s ease;
	}

	.assignment-card.overdue {
		border-color: #F87171;
		background: #FEF2F2;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.75rem;
		gap: 0.75rem;
	}

	.task-title {
		font-size: 1.125rem;
		font-weight: 600;
		color: #1F2937;
		flex: 1;
		margin: 0;
	}

	.task-title-section {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		flex: 1;
	}

	.task-type-badge {
		font-size: 0.7rem;
		font-weight: 600;
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
		text-transform: none;
		width: fit-content;
	}

	.task-type-badge.quick-task {
		background-color: #3b82f615;
		color: #3b82f6;
		border: 1px solid #3b82f640;
	}

	.card-badges {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		flex-shrink: 0;
	}

	.priority-badge, .overdue-badge, .status-badge, .quick-task-badge {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		text-align: center;
	}

	.quick-task-badge {
		background: #F3E8FF;
		color: #7C3AED;
		font-size: 0.625rem;
	}

	.overdue-badge {
		background: #FEE2E2;
		color: #DC2626;
	}

	.task-description {
		color: #6B7280;
		font-size: 0.875rem;
		margin: 0 0 1rem 0;
		line-height: 1.5;
	}

	.assignment-details {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.detail-label {
		font-size: 0.75rem;
		font-weight: 500;
		color: #6B7280;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.detail-value {
		font-size: 0.875rem;
		color: #1F2937;
		font-weight: 500;
	}

	.assignment-notes {
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		padding: 0.75rem;
	}

	.quick-task-info {
		background: #F3E8FF;
		border: 1px solid #E5E7EB;
		border-radius: 6px;
		padding: 0.75rem;
		margin-top: 1rem;
	}

	.quick-detail {
		display: flex;
		justify-content: space-between;
		margin-bottom: 0.5rem;
	}

	.quick-detail:last-child {
		margin-bottom: 0;
	}

	.quick-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #7C3AED;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.quick-value {
		font-size: 0.875rem;
		color: #5B21B6;
		font-weight: 500;
		text-transform: capitalize;
	}

	.notes-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.notes-text {
		font-size: 0.875rem;
		color: #6B7280;
		margin: 0.25rem 0 0 0;
		line-height: 1.4;
	}

	/* Footer */
	.mobile-footer {
		background: white;
		border-top: 1px solid #E5E7EB;
		padding: 0.75rem 1.5rem;
		margin-top: auto;
	}

	.footer-stats {
		display: flex;
		justify-content: space-between;
		font-size: 0.75rem;
		color: #6B7280;
	}

	/* Responsive */
	@media (max-width: 480px) {
		.stats-grid {
			grid-template-columns: repeat(3, 1fr);
			gap: 0.5rem;
		}

		.stat-card {
			padding: 0.5rem 0.25rem;
		}

		.stat-number {
			font-size: 1rem;
		}

		.stat-label {
			font-size: 0.625rem;
		}

		.assignment-details {
			grid-template-columns: 1fr;
			gap: 0.5rem;
		}
	}

	/* Attachments Styles */
	.attachments-section {
		margin-top: 1rem;
		padding-top: 1rem;
		border-top: 1px solid #E5E7EB;
	}

	.attachments-header {
		margin-bottom: 0.75rem;
	}

	.attachments-label {
		font-size: 0.875rem;
		color: #374151;
		font-weight: 500;
	}

	.attachments-grid {
		display: flex;
		flex-wrap: wrap;
		gap: 0.75rem;
	}

	.attachment-item {
		flex: 0 0 auto;
	}

	.image-attachment {
		position: relative;
		display: inline-block;
	}

	.attachment-thumbnail {
		width: 80px;
		height: 80px;
		object-fit: cover;
		border-radius: 8px;
		border: 2px solid #E5E7EB;
		cursor: pointer;
		transition: transform 0.2s;
	}

	.attachment-thumbnail:hover {
		transform: scale(1.05);
		border-color: #3B82F6;
	}

	.download-btn {
		position: absolute;
		top: 4px;
		right: 4px;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 24px;
		height: 24px;
		font-size: 12px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.download-btn:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	.file-attachment {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #F3F4F6;
		border-radius: 8px;
		border: 1px solid #E5E7EB;
		min-width: 200px;
	}

	.file-icon {
		font-size: 1.5rem;
		flex-shrink: 0;
	}

	.file-info {
		flex: 1;
		min-width: 0;
	}

	.file-name {
		display: block;
		font-size: 0.875rem;
		color: #374151;
		font-weight: 500;
		margin-bottom: 0.25rem;
		word-break: break-word;
	}

	.download-file-btn {
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.25rem 0.75rem;
		border-radius: 6px;
		font-size: 0.75rem;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.download-file-btn:hover {
		background: #2563EB;
	}

	/* Image Modal Styles */
	.image-modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 2rem;
	}

	.image-modal-content {
		position: relative;
		max-width: 90vw;
		max-height: 90vh;
		background: white;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
	}

	.modal-image {
		width: 100%;
		height: 100%;
		object-fit: contain;
		display: block;
	}

	.modal-close-btn {
		position: absolute;
		top: 1rem;
		right: 1rem;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		width: 40px;
		height: 40px;
		font-size: 1.5rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.modal-close-btn:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.mobile-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}
	}
</style>