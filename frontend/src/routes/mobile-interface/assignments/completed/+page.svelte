<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase, getStoragePublicUrl, resolveStorageUrl } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';
	import { locale, getTranslation } from '$lib/i18n';

	// Data
	let completedAssignments = [];
	let filteredAssignments = [];

	// Loading states
	let isLoading = true;

	// Image modal state
	let showImageModal = false;
	let selectedImageUrl = '';

	// Search
	let searchTerm = '';

	onMount(async () => {
		await loadCompletedAssignments();
	});

	async function loadCompletedAssignments() {
		if (!$currentUser) return;

		try {
			isLoading = true;

			// Load completed regular task assignments
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
						username,
						hr_employee_master!hr_employee_master_user_id_fkey (
							name_en,
							name_ar
						)
					)
				`)
				.eq('assigned_by', $currentUser.id)
				.eq('status', 'completed')
				.order('completed_at', { ascending: false });

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
						assigned_by,
						product_request_id,
						product_request_type
					),
					assigned_user:users!quick_task_assignments_assigned_to_user_id_fkey (
						id,
						username,
						hr_employee_master!hr_employee_master_user_id_fkey (
							name_en,
							name_ar
						)
					)
				`)
				.eq('quick_task.assigned_by', $currentUser.id)
				.eq('status', 'completed')
				.order('created_at', { ascending: false });

			const [regularResult, quickResult] = await Promise.all([
				regularQuery,
				quickQuery
			]);

			let regularAssignments = [];
			if (regularResult.data && regularResult.data.length > 0) {
				regularAssignments = regularResult.data.map(assignment => ({
					...assignment,
					task_type: 'regular'
				}));
			}

			let quickAssignments = [];
			if (quickResult.data && quickResult.data.length > 0) {
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

			// Combine and filter by current user as assigner
			completedAssignments = [...regularAssignments, ...quickAssignments].filter(assignment => {
				const assignedBy = assignment.assigned_by || assignment.quick_task?.assigned_by;
				return assignedBy === $currentUser.id;
			});

			// Sort by completion date (newest first)
			completedAssignments.sort((a, b) => {
				const dateA = new Date(a.completed_at || a.assigned_at);
				const dateB = new Date(b.completed_at || b.assigned_at);
				return dateB.getTime() - dateA.getTime();
			});

			// Load attachments and completion photos
			await Promise.all([loadAttachments(), loadCompletionPhotos()]);

			applyFilters();

		} catch (error) {
			console.error('Error loading completed assignments:', error);
			notifications.add({
				type: 'error',
				message: 'Failed to load completed assignments',
				duration: 5000
			});
		} finally {
			isLoading = false;
		}
	}

	async function loadAttachments() {
		const quickTaskAssignments = completedAssignments.filter(a => a.task_type === 'quick_task');
		const regularTaskAssignments = completedAssignments.filter(a => a.task_type === 'regular');

		if (quickTaskAssignments.length > 0) {
			const quickTaskIds = quickTaskAssignments.map(a => a.quick_task_id || a.task_id);
			try {
				const { data: files } = await supabase
					.from('quick_task_files')
					.select('*')
					.in('quick_task_id', quickTaskIds);
				
				if (files && files.length > 0) {
					const filesMap = new Map();
					files.forEach(file => {
						if (!filesMap.has(file.quick_task_id)) {
							filesMap.set(file.quick_task_id, []);
						}
						filesMap.get(file.quick_task_id).push({
							...file,
							file_url: getStoragePublicUrl('quick-task-files', file.storage_path),
							source: 'quick_task'
						});
					});
					quickTaskAssignments.forEach(assignment => {
						const taskId = assignment.quick_task_id || assignment.task_id;
						assignment.attachments = filesMap.get(taskId) || [];
					});
				}
			} catch (error) {
				console.error('Error loading quick task files:', error);
			}
		}

		if (regularTaskAssignments.length > 0) {
			const taskIds = regularTaskAssignments.map(a => a.task_id);
			try {
				const { data: images } = await supabase
					.from('task_images')
					.select('*')
					.in('task_id', taskIds);
				
				if (images && images.length > 0) {
					const imagesMap = new Map();
					images.forEach(image => {
						if (!imagesMap.has(image.task_id)) {
							imagesMap.set(image.task_id, []);
						}
						imagesMap.get(image.task_id).push({
							...image,
							file_url: getStoragePublicUrl('task-images', image.file_path),
							source: 'task'
						});
					});
					regularTaskAssignments.forEach(assignment => {
						assignment.attachments = imagesMap.get(assignment.task_id) || [];
					});
				}
			} catch (error) {
				console.error('Error loading task images:', error);
			}
		}
	}

	async function loadCompletionPhotos() {
		const quickTaskAssignments = completedAssignments.filter(a => a.task_type === 'quick_task');
		const regularTaskAssignments = completedAssignments.filter(a => a.task_type === 'regular');

		// Load completion photos for regular tasks
		if (regularTaskAssignments.length > 0) {
			const taskIds = regularTaskAssignments.map(a => a.task_id);
			try {
				const { data: completions } = await supabase
					.from('task_completions')
					.select('id, task_id, assignment_id, completion_photo_url, completion_notes, completed_by_name, completed_at')
					.in('task_id', taskIds);

				if (completions && completions.length > 0) {
					const completionMap = new Map();
					completions.forEach(c => {
						const key = c.assignment_id || c.task_id;
						if (!completionMap.has(key)) completionMap.set(key, []);
						if (c.completion_photo_url) {
							completionMap.get(key).push({
								file_url: resolveStorageUrl(c.completion_photo_url),
								file_name: `completion-photo-${c.id}.jpg`,
								file_type: 'image/jpeg',
								completed_by_name: c.completed_by_name,
								completed_at: c.completed_at,
								notes: c.completion_notes
							});
						}
					});
					regularTaskAssignments.forEach(assignment => {
						const photos = completionMap.get(assignment.id) || completionMap.get(assignment.task_id) || [];
						assignment.completionPhotos = photos;
						// Also store completion notes
						const completion = completions.find(c => c.assignment_id === assignment.id || c.task_id === assignment.task_id);
						if (completion?.completion_notes) assignment.completionNotes = completion.completion_notes;
					});
				}
			} catch (error) {
				console.error('Error loading regular task completion photos:', error);
			}
		}

		// Load completion photos for quick tasks
		if (quickTaskAssignments.length > 0) {
			const assignmentIds = quickTaskAssignments.map(a => a.id);
			try {
				const { data: completions } = await supabase
					.from('quick_task_completions')
					.select('id, quick_task_id, assignment_id, photo_path, completion_notes, completed_by_user_id, created_at')
					.in('assignment_id', assignmentIds);

				if (completions && completions.length > 0) {
					const completionMap = new Map();
					completions.forEach(c => {
						if (!completionMap.has(c.assignment_id)) completionMap.set(c.assignment_id, []);
						if (c.photo_path) {
							// photo_path may contain comma-separated paths for multi-photo completions
							const paths = c.photo_path.split(',').map(p => p.trim()).filter(p => p);
							paths.forEach((path, idx) => {
								completionMap.get(c.assignment_id).push({
									file_url: getStoragePublicUrl('completion-photos', path),
									file_name: `completion-photo-${c.id}-${idx + 1}.jpg`,
									file_type: 'image/jpeg',
									completed_at: c.created_at,
									notes: c.completion_notes
								});
							});
						}
					});
					quickTaskAssignments.forEach(assignment => {
						assignment.completionPhotos = completionMap.get(assignment.id) || [];
						const completion = completions.find(c => c.assignment_id === assignment.id);
						if (completion?.completion_notes) assignment.completionNotes = completion.completion_notes;
					});
				}
			} catch (error) {
				console.error('Error loading quick task completion photos:', error);
			}
		}
	}

	function applyFilters() {
		filteredAssignments = completedAssignments.filter(assignment => {
			if (searchTerm) {
				const searchLower = searchTerm.toLowerCase();
				const taskTitle = assignment.task?.title?.toLowerCase() || '';
				const userName = getEmployeeName(assignment.assigned_user)?.toLowerCase() || '';
				if (!taskTitle.includes(searchLower) && !userName.includes(searchLower)) {
					return false;
				}
			}
			return true;
		});
	}

	function formatDate(dateString) {
		if (!dateString) return '-';
		const date = new Date(dateString);
		const dd = String(date.getDate()).padStart(2, '0');
		const mm = String(date.getMonth() + 1).padStart(2, '0');
		const yyyy = date.getFullYear();
		return `${dd}-${mm}-${yyyy}`;
	}

	function formatTimeAgo(dateString) {
		if (!dateString) return '';
		const date = new Date(dateString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const isAr = $locale === 'ar';
		
		const totalMinutes = Math.floor(diffMs / 60000);
		const totalHours = Math.floor(totalMinutes / 60);
		const days = Math.floor(totalHours / 24);
		const hours = totalHours % 24;
		const mins = totalMinutes % 60;
		
		if (days > 0) {
			return isAr ? `منذ ${days} يوم ${hours} ساعة` : `${days}d ${hours}h ago`;
		} else if (hours > 0) {
			return isAr ? `منذ ${hours} ساعة ${mins} دقيقة` : `${hours}h ${mins}m ago`;
		} else {
			return isAr ? `منذ ${mins} دقيقة` : `${mins}m ago`;
		}
	}

	function getEmployeeName(assignedUser) {
		if (!assignedUser) return getTranslation('mobile.assignmentsContent.taskDetails.unknownTask');
		const emp = assignedUser.hr_employee_master;
		const empData = Array.isArray(emp) ? emp[0] : emp;
		if (empData) {
			if ($locale === 'ar' && empData.name_ar) return empData.name_ar;
			if ($locale !== 'ar' && empData.name_en) return empData.name_en;
			return empData.name_en || empData.name_ar || assignedUser.username || 'Unknown';
		}
		return assignedUser.username || 'Unknown';
	}

	function getLocalizedContent(text) {
		if (!text) return '';
		const currentLocale = $locale;
		if (text.includes(' | ')) {
			const parts = text.split(' | ');
			if (parts.length === 2) {
				return currentLocale === 'ar' ? parts[1].trim() : parts[0].trim();
			}
		}
		const descSeparator = text.match(/\n-{3,}\n/);
		if (descSeparator) {
			const parts = text.split(descSeparator[0]);
			if (parts.length === 2) {
				return currentLocale === 'ar' ? parts[1].trim() : parts[0].trim();
			}
		}
		return text;
	}

	function linkifyText(text) {
		if (!text) return '';
		const urlRegex = /(https?:\/\/[^\s<>"]+)/g;
		return text.replace(urlRegex, '<br/><a href="$1" target="_blank" rel="noopener noreferrer" class="url-btn"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>View</a>');
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return 'bg-red-100 text-red-800';
			case 'medium': return 'bg-yellow-100 text-yellow-800';
			case 'low': return 'bg-green-100 text-green-800';
			default: return 'bg-gray-100 text-gray-800';
		}
	}

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
		}
	}

	function openImagePreview(imageUrl) {
		selectedImageUrl = imageUrl;
		showImageModal = true;
	}

	function closeImagePreview() {
		showImageModal = false;
		selectedImageUrl = '';
	}

	$: {
		searchTerm;
		applyFilters();
	}
</script>

<svelte:head>
	<title>{getTranslation('mobile.completedAssignments.title')}</title>
</svelte:head>

<div class="completed-assignments-page">

	<!-- Header with back & stats -->
	<section class="page-header">
		<button class="back-btn" on:click={() => goto('/mobile-interface/assignments')}>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M19 12H5M12 19l-7-7 7-7"/>
			</svg>
			<span>{getTranslation('mobile.completedAssignments.backToAssignments')}</span>
		</button>
		<div class="header-stats">
			<div class="total-completed">
				<span class="completed-icon">✅</span>
				<span class="completed-count">{completedAssignments.length}</span>
				<span class="completed-label">{getTranslation('mobile.completedAssignments.completedTotal')}</span>
			</div>
		</div>
	</section>

	<!-- Search -->
	{#if !isLoading && completedAssignments.length > 0}
		<section class="search-section">
			<input
				type="text"
				bind:value={searchTerm}
				placeholder={getTranslation('mobile.completedAssignments.searchPlaceholder')}
				class="search-input"
			/>
		</section>
	{/if}

	<!-- Content -->
	<main class="content-area">
		{#if isLoading}
			<div class="loading-container">
				<div class="loading-spinner"></div>
				<p>{getTranslation('mobile.completedAssignments.loading')}</p>
			</div>
		{:else if filteredAssignments.length === 0}
			<div class="empty-state">
				<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
				</svg>
				<h3>{getTranslation('mobile.completedAssignments.noCompleted')}</h3>
				<p>{searchTerm ? getTranslation('mobile.completedAssignments.noMatchingSearch') : getTranslation('mobile.completedAssignments.noCompletedYet')}</p>
			</div>
		{:else}
			<div class="assignments-list">
				{#each filteredAssignments as assignment}
					<div class="assignment-card completed">
						<div class="card-header">
							<div class="task-title-section">
								<h3 class="task-title">{getLocalizedContent(assignment.task?.title) || getTranslation('mobile.assignmentsContent.taskDetails.unknownTask')}</h3>
								{#if assignment.task_type === 'quick_task'}
									<span class="task-type-badge quick-task">{getTranslation('mobile.assignmentsContent.taskDetails.quickTask')}</span>
								{/if}
							</div>
							<div class="card-badges">
								<span class="completed-badge">✅ {getTranslation('mobile.assignmentsContent.statuses.completed')}</span>
								{#if assignment.task?.priority}
									<span class="priority-badge {getPriorityColor(assignment.task.priority)}">
										{getTranslation(`mobile.assignmentsContent.priorities.${assignment.task.priority.toLowerCase()}`)}
									</span>
								{/if}
							</div>
						</div>

						{#if assignment.task?.description}
							<p class="task-description">{@html linkifyText(getLocalizedContent(assignment.task.description))}</p>
						{/if}

						<div class="assignment-details">
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.assignedTo')}</span>
								<span class="detail-value">{getEmployeeName(assignment.assigned_user)}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.completedAssignments.completedAt')}</span>
								<span class="detail-value completed-date">{formatDate(assignment.completed_at)}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.assignedDate')}</span>
								<span class="detail-value">{formatTimeAgo(assignment.assigned_at)}</span>
							</div>
							<div class="detail-item">
								<span class="detail-label">{getTranslation('mobile.assignmentsContent.taskDetails.deadline')}</span>
								<span class="detail-value">{formatDate(assignment.deadline_date || assignment.task?.deadline_datetime)}</span>
							</div>
						</div>

						{#if assignment.notes}
							<div class="assignment-notes">
								<span class="notes-label">{getTranslation('mobile.assignmentsContent.taskDetails.notes')}</span>
								<p class="notes-text">{@html linkifyText(assignment.notes)}</p>
							</div>
						{/if}

						<!-- Task Attachments (sent by assigner) -->
						{#if assignment.attachments && assignment.attachments.length > 0}
							<div class="attachments-section">
								<div class="attachments-header">
									<span class="attachments-label task-photos-label">📎 {getTranslation('mobile.assignmentsContent.taskDetails.taskPhotos')} ({assignment.attachments.length})</span>
								</div>
								<div class="attachments-grid">
									{#each assignment.attachments as attachment}
										<div class="attachment-item">
											{#if attachment.file_type && (attachment.file_type.startsWith('image/') || (attachment.file_name && /\.(jpg|jpeg|png|gif|webp)$/i.test(attachment.file_name)))}
												<div class="image-attachment">
													<!-- svelte-ignore a11y-click-events-have-key-events -->
													<!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
													<img 
														src={attachment.file_url} 
														alt={attachment.file_name || 'Attachment'}
														class="attachment-thumbnail"
														on:click={() => openImagePreview(attachment.file_url)}
													/>
													<button 
														class="view-photo-btn" 
														on:click={() => openImagePreview(attachment.file_url)}
													>
														👁️ {getTranslation('mobile.assignmentsContent.actions.view')}
													</button>
												</div>
											{:else}
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

						<!-- Completion Photos (sent by completer) -->
						{#if assignment.completionPhotos && assignment.completionPhotos.length > 0}
							<div class="attachments-section completion-photos-section">
								<div class="attachments-header">
									<span class="attachments-label completion-photos-label">📸 {getTranslation('mobile.assignmentsContent.taskDetails.completionPhotos')} ({assignment.completionPhotos.length})</span>
								</div>
								<div class="attachments-grid">
									{#each assignment.completionPhotos as photo}
										<div class="attachment-item">
											<div class="image-attachment completion-photo">
												<!-- svelte-ignore a11y-click-events-have-key-events -->
												<!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
												<img 
													src={photo.file_url} 
													alt="Completion"
													class="attachment-thumbnail"
													on:click={() => openImagePreview(photo.file_url)}
												/>
												<button 
													class="view-photo-btn" 
													on:click={() => openImagePreview(photo.file_url)}
												>
													👁️ {getTranslation('mobile.assignmentsContent.actions.view')}
												</button>
											</div>
										</div>
									{/each}
								</div>
							</div>
						{/if}

						<!-- Completion Notes -->
						{#if assignment.completionNotes}
							<div class="assignment-notes completion-notes-section">
								<span class="notes-label">📝 {getTranslation('mobile.assignmentsContent.taskDetails.completionNotes')}</span>
								<p class="notes-text">{@html linkifyText(assignment.completionNotes)}</p>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</main>

	<!-- Footer -->
	<footer class="page-footer">
		<span>{getTranslation('mobile.completedAssignments.showing')} {filteredAssignments.length} {getTranslation('mobile.completedAssignments.of')} {completedAssignments.length}</span>
	</footer>
</div>

<!-- Image Preview Modal -->
{#if showImageModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<div class="image-modal-overlay" on:click={closeImagePreview}>
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<div class="image-modal-content" on:click|stopPropagation>
			<img src={selectedImageUrl} alt="Preview" class="modal-image" />
			<button class="modal-close-btn" on:click={closeImagePreview}>×</button>
		</div>
	</div>
{/if}

<style>
	.completed-assignments-page {
		min-height: 100%;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
		padding: 0;
		padding-bottom: 0.5rem;
	}

	/* Header */
	.page-header {
		background: white;
		border-bottom: 1px solid #E5E7EB;
		padding: 0.5rem 0.6rem;
	}

	.back-btn {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		background: none;
		border: none;
		color: #3B82F6;
		font-size: 0.78rem;
		font-weight: 500;
		cursor: pointer;
		padding: 0.2rem 0;
		margin-bottom: 0.4rem;
	}

	.header-stats {
		display: flex;
		align-items: center;
	}

	.total-completed {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		background: #ECFDF5;
		border: 1px solid #D1FAE5;
		border-radius: 6px;
		padding: 0.4rem 0.6rem;
		width: 100%;
	}

	.completed-icon {
		font-size: 1rem;
	}

	.completed-count {
		font-size: 1.1rem;
		font-weight: 700;
		color: #065F46;
	}

	.completed-label {
		font-size: 0.74rem;
		color: #047857;
		font-weight: 500;
	}

	/* Search */
	.search-section {
		padding: 0.4rem 0.6rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.search-input {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.78rem;
		box-sizing: border-box;
	}

	.search-input:focus {
		outline: none;
		border-color: #3B82F6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
	}

	/* Content */
	.content-area {
		flex: 1;
		padding: 0.4rem 0.6rem;
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		color: #6B7280;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 2px solid rgba(16, 185, 129, 0.3);
		border-top: 2px solid #10B981;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 0.5rem;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: 2rem 1rem;
		color: #6B7280;
	}

	.empty-state svg {
		color: #9CA3AF;
		margin-bottom: 0.5rem;
	}

	.empty-state h3 {
		font-size: 0.88rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.25rem 0;
	}

	.empty-state p {
		font-size: 0.76rem;
		margin: 0;
	}

	/* Assignment Cards */
	.assignments-list {
		display: flex;
		flex-direction: column;
	}

	.assignment-card {
		background: white;
		border: 1px solid #D1FAE5;
		border-radius: 6px;
		padding: 0.5rem 0.6rem;
		margin-bottom: 0.4rem;
		border-left: 3px solid #10B981;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.3rem;
		gap: 0.4rem;
	}

	.task-title-section {
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
		flex: 1;
	}

	.task-title {
		font-size: 0.82rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0;
		line-height: 1.3;
	}

	.task-type-badge {
		font-size: 0.62rem;
		font-weight: 600;
		padding: 0.1rem 0.3rem;
		border-radius: 3px;
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

	.completed-badge {
		font-size: 0.62rem;
		font-weight: 600;
		padding: 0.12rem 0.35rem;
		border-radius: 3px;
		background: #ECFDF5;
		color: #059669;
		border: 1px solid #A7F3D0;
		text-align: center;
	}

	.priority-badge {
		font-size: 0.62rem;
		font-weight: 600;
		padding: 0.12rem 0.35rem;
		border-radius: 3px;
		text-align: center;
	}

	.task-description {
		color: #6B7280;
		font-size: 0.74rem;
		margin: 0 0 0.4rem 0;
		line-height: 1.4;
		word-break: break-word;
		overflow-wrap: break-word;
		white-space: pre-wrap;
	}

	.task-description :global(.url-btn),
	.notes-text :global(.url-btn) {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		margin-top: 0.3rem;
		padding: 0.3rem 0.6rem;
		background: #3B82F6;
		color: white;
		border-radius: 5px;
		font-size: 0.74rem;
		font-weight: 500;
		text-decoration: none;
	}

	.assignment-details {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.3rem;
		margin-bottom: 0.4rem;
	}

	.detail-item {
		display: flex;
		flex-direction: column;
		gap: 0.1rem;
	}

	.detail-label {
		font-size: 0.66rem;
		font-weight: 500;
		color: #6B7280;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.detail-value {
		font-size: 0.76rem;
		color: #1F2937;
		font-weight: 500;
	}

	.detail-value.completed-date {
		color: #059669;
		font-weight: 600;
	}

	.quick-task-info {
		background: #F3E8FF;
		border: 1px solid #E5E7EB;
		border-radius: 5px;
		padding: 0.4rem 0.5rem;
		margin-top: 0.4rem;
	}

	.quick-detail {
		display: flex;
		justify-content: space-between;
		margin-bottom: 0.25rem;
	}

	.quick-detail:last-child {
		margin-bottom: 0;
	}

	.quick-label {
		font-size: 0.66rem;
		font-weight: 600;
		color: #7C3AED;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.quick-value {
		font-size: 0.76rem;
		color: #5B21B6;
		font-weight: 500;
		text-transform: capitalize;
	}

	.assignment-notes {
		background: #F9FAFB;
		border: 1px solid #E5E7EB;
		border-radius: 5px;
		padding: 0.4rem 0.5rem;
	}

	.notes-label {
		font-size: 0.66rem;
		font-weight: 600;
		color: #374151;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.notes-text {
		font-size: 0.76rem;
		color: #6B7280;
		margin: 0.15rem 0 0 0;
		line-height: 1.4;
	}

	/* Attachments */
	.attachments-section {
		margin-top: 0.4rem;
		padding-top: 0.4rem;
		border-top: 1px solid #E5E7EB;
	}

	.task-photos-label {
		color: #3B82F6;
	}

	.completion-photos-section {
		background: #FFFBEB;
		border: 1px solid #FDE68A;
		border-radius: 5px;
		padding: 0.4rem 0.5rem;
		border-top: none;
	}

	.completion-photos-label {
		color: #D97706;
		font-weight: 600;
	}

	.completion-photo {
		border: 2px solid #F59E0B;
		border-radius: 6px;
	}

	.view-photo-btn {
		display: block;
		width: 100%;
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.2rem 0;
		border-radius: 0 0 4px 4px;
		font-size: 0.62rem;
		font-weight: 600;
		cursor: pointer;
		text-align: center;
	}

	.view-photo-btn:active {
		background: #2563EB;
	}

	.completion-notes-section {
		background: #FEF3C7;
		border-color: #FDE68A;
	}

	.attachments-header {
		margin-bottom: 0.3rem;
	}

	.attachments-label {
		font-size: 0.74rem;
		color: #374151;
		font-weight: 500;
	}

	.attachments-grid {
		display: flex;
		flex-wrap: wrap;
		gap: 0.4rem;
	}

	.image-attachment {
		position: relative;
		display: inline-block;
	}

	.attachment-thumbnail {
		width: 60px;
		height: 60px;
		object-fit: cover;
		border-radius: 5px;
		border: 1px solid #E5E7EB;
		cursor: pointer;
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
	}

	.file-attachment {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.4rem 0.5rem;
		background: #F3F4F6;
		border-radius: 5px;
		border: 1px solid #E5E7EB;
		min-width: 160px;
	}

	.file-icon {
		font-size: 1rem;
		flex-shrink: 0;
	}

	.file-info { flex: 1; min-width: 0; }

	.file-name {
		display: block;
		font-size: 0.74rem;
		color: #374151;
		font-weight: 500;
		margin-bottom: 0.15rem;
		word-break: break-word;
	}

	.download-file-btn {
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.2rem 0.5rem;
		border-radius: 4px;
		font-size: 0.68rem;
		cursor: pointer;
	}

	/* Footer */
	.page-footer {
		background: white;
		border-top: 1px solid #E5E7EB;
		padding: 0.35rem 0.6rem;
		margin-top: auto;
		font-size: 0.68rem;
		color: #6B7280;
		text-align: center;
	}

	/* Tailwind-like utility classes */
	.bg-red-100 { background: #FEE2E2; }
	.text-red-800 { color: #991B1B; }
	.bg-yellow-100 { background: #FEF3C7; }
	.text-yellow-800 { color: #92400E; }
	.bg-green-100 { background: #DCFCE7; }
	.text-green-800 { color: #166534; }
	.bg-gray-100 { background: #F3F4F6; }
	.text-gray-800 { color: #1F2937; }

	/* Image Modal */
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
	}

	/* Responsive */
	@media (max-width: 480px) {
		.assignment-details {
			grid-template-columns: 1fr;
			gap: 0.3rem;
		}
	}
</style>
