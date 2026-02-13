<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { supabase, db } from '$lib/utils/supabase';

	let currentUserData = null;
	let task = null;
	let assignment = null;
	let taskAttachments = [];
	let isLoading = true;
	let isUpdating = false;
	let taskId = null;

	onMount(async () => {
		currentUserData = $currentUser;
		taskId = $page.params.id;
		
		if (currentUserData && taskId) {
			await loadTaskDetails();
		}
		isLoading = false;
	});

	function downloadAttachment(attachment) {
		try {
			const link = document.createElement('a');
			link.href = attachment.fileUrl;
			link.download = attachment.fileName;
			link.target = '_blank';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
		} catch (error) {
			console.error('Download error:', error);
			alert('Failed to download attachment. Please try again.');
		}
	}

	function formatFileSize(bytes) {
		if (bytes === 0) return '0 Bytes';
		const k = 1024;
		const sizes = ['Bytes', 'KB', 'MB', 'GB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
	}

	function getFileIcon(fileType) {
		if (fileType.startsWith('image/')) return '🖼️';
		if (fileType.includes('pdf')) return '📄';
		if (fileType.includes('sheet') || fileType.includes('excel')) return '📊';
		if (fileType.includes('word') || fileType.includes('doc')) return '📝';
		if (fileType.includes('zip') || fileType.includes('rar')) return '📦';
		return '📎';
	}

	async function loadTaskDetails() {
		try {
			// First get the task details
			const { data: taskData, error: taskError } = await supabase
				.from('tasks')
				.select('*')
				.eq('id', taskId)
				.single();

			if (taskError) throw taskError;

			// Then get the assignment details for this user - handle multiple assignments by getting the most recent one
			const { data: assignmentData, error: assignmentError } = await supabase
				.from('task_assignments')
				.select('*')
				.eq('task_id', taskId)
				.eq('assigned_to_user_id', currentUserData.id)
				.order('assigned_at', { ascending: false })
				.limit(1);

			if (assignmentError) throw assignmentError;
			
			// Check if we got any assignments
			if (!assignmentData || assignmentData.length === 0) {
				console.error('No assignment found for this task and user');
				goto('/mobile-interface/tasks');
				return;
			}

			task = taskData;
			assignment = assignmentData[0]; // Get the first (most recent) assignment

			// Load task attachments
			const attachmentResult = await db.taskAttachments.getByTaskId(taskId);
			if (attachmentResult.data && attachmentResult.data.length > 0) {
				taskAttachments = attachmentResult.data.map(attachment => ({
					id: attachment.id,
					fileName: attachment.file_name || 'Unknown File',
					fileSize: attachment.file_size || 0,
					fileType: attachment.file_type || 'application/octet-stream',
					fileUrl: attachment.file_path && attachment.file_path.startsWith('http') 
						? attachment.file_path 
						: `https://supabase.urbanaqura.com/storage/v1/object/public/task-images/${attachment.file_path || ''}`,
					uploadedBy: attachment.uploaded_by_name || attachment.uploaded_by || 'Unknown',
					uploadedAt: attachment.created_at
				}));
			} else {
				taskAttachments = [];
			}
		} catch (error) {
			console.error('Error loading task details:', error);
			// If task not found or not assigned to user, redirect back
			goto('/mobile-interface/tasks');
		}
	}

	async function updateAssignmentStatus(newStatus) {
		if (isUpdating) return;
		
		// If completing the task, navigate to completion page instead
		if (newStatus === 'completed') {
			goto(`/mobile-interface/tasks/${taskId}/complete`);
			return;
		}
		
		isUpdating = true;
		try {
			const updateData: any = { status: newStatus };

			const { error } = await supabase
				.from('task_assignments')
				.update(updateData)
				.eq('id', assignment.id);

			if (error) throw error;

			// Update local state
			assignment = { ...assignment, ...updateData };
			
		} catch (error) {
			console.error('Error updating task status:', error);
			alert('Failed to update task status. Please try again.');
		} finally {
			isUpdating = false;
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

	function formatDateTime(dateString) {
		if (!dateString) return 'Unknown';
		const date = new Date(dateString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
		
		if (diffHours < 1) {
			const diffMinutes = Math.floor(diffMs / (1000 * 60));
			return diffMinutes < 1 ? 'Just now' : `${diffMinutes} minutes ago`;
		} else if (diffHours < 24) {
			return `${diffHours} hours ago`;
		} else {
			const diffDays = Math.floor(diffHours / 24);
			if (diffDays === 1) return 'Yesterday';
			if (diffDays < 7) return `${diffDays} days ago`;
			return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
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

	/** Convert URLs in text to clickable button links */
	function linkifyText(text) {
		if (!text) return '';
		const urlRegex = /(https?:\/\/[^\s<>"]+)/g;
		return text.replace(urlRegex, '<br/><a href="$1" target="_blank" rel="noopener noreferrer" class="url-btn"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>View Clearance Certificate</a>');
	}
</script>

<svelte:head>
	<title>{task ? task.title : 'Task Details'} - Aqura Mobile</title>
</svelte:head>

<div class="mobile-task-detail">
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading...</p>
		</div>
	{:else if !task || !assignment}
		<div class="error-state">
			<p>Task not found or not accessible.</p>
			<button class="back-btn-error" on:click={() => goto('/mobile-interface/tasks')}>← Back</button>
		</div>
	{:else}
		<!-- Header -->
		<div class="task-header">
			<h2>{task.title}</h2>
			<div class="task-badges">
				<span class="priority-badge" style="background-color: {getPriorityColor(task.priority)}15; color: {getPriorityColor(task.priority)}">
					{task.priority?.toUpperCase()} PRIORITY
				</span>
				<span class="status-badge" style="background-color: {getStatusColor(assignment.status)}15; color: {getStatusColor(assignment.status)}">
					{getStatusDisplayText(assignment.status)}
				</span>
				{#if isOverdue(assignment.deadline_date, assignment.deadline_time) && assignment.status !== 'completed'}
					<span class="overdue-badge">OVERDUE</span>
				{/if}
			</div>
		</div>

			<!-- Description -->
			{#if task.description}
				<div class="info-card">
					<h3>Description</h3>
					<p class="task-description">{@html linkifyText(task.description)}</p>
				</div>
			{/if}

			<!-- Timeline -->
			<div class="info-card">
				<h3>Timeline</h3>
				<div class="timeline-grid">
					<div class="tl-row">
						<span class="tl-label">Created</span>
						<span class="tl-value">{formatDateTime(task.created_at)}</span>
						<span class="tl-sub">by {task.created_by_name || 'Unknown'}</span>
					</div>
					<div class="tl-row">
						<span class="tl-label">Assigned</span>
						<span class="tl-value">{formatDateTime(assignment.assigned_at)}</span>
						<span class="tl-sub">by {assignment.assigned_by_name || 'Unknown'}</span>
					</div>
					{#if assignment.deadline_date}
						<div class="tl-row" class:overdue-text={isOverdue(assignment.deadline_date, assignment.deadline_time)}>
							<span class="tl-label">Due</span>
							<span class="tl-value">{formatDate(assignment.deadline_date)}{assignment.deadline_time ? ' at ' + formatTime(assignment.deadline_time) : ''}</span>
						</div>
					{/if}
					{#if assignment.completed_at}
						<div class="tl-row">
							<span class="tl-label" style="color: #059669;">Done</span>
							<span class="tl-value">{formatDateTime(assignment.completed_at)}</span>
						</div>
					{/if}
				</div>
			</div>

			<!-- Attachments -->
			{#if taskAttachments.length > 0}
				<div class="info-card">
					<h3>Attachments ({taskAttachments.length})</h3>
					<div class="attachments-list">
						{#each taskAttachments as attachment}
							<div class="attachment-item">
								<div class="attachment-info">
									<span class="att-icon">{getFileIcon(attachment.fileType)}</span>
									<div class="attachment-details">
										<span class="att-name">{attachment.fileName}</span>
										<span class="att-meta">{formatFileSize(attachment.fileSize)}</span>
									</div>
								</div>
								<button class="download-btn" on:click={() => downloadAttachment(attachment)} title="Download">
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

		<!-- Actions -->
		{#if assignment.status !== 'completed' && assignment.status !== 'cancelled' && assignment.assigned_to_user_id === currentUserData?.id}
			<div class="action-section">
				<div class="action-buttons">
					{#if assignment.status === 'assigned'}
						<button class="action-btn start-btn" on:click={() => updateAssignmentStatus('in_progress')} disabled={isUpdating}>
							{#if isUpdating}<div class="btn-spinner"></div>{:else}Start Task{/if}
						</button>
					{/if}
					{#if assignment.status === 'in_progress' || assignment.status === 'assigned'}
						<button class="action-btn complete-btn" on:click={() => updateAssignmentStatus('completed')} disabled={isUpdating}>
							{#if isUpdating}<div class="btn-spinner"></div>{:else}Mark Complete{/if}
						</button>
					{/if}
				</div>
			</div>
		{:else}
			<div class="completion-section">
				<div class="completion-msg">
					<span class="completion-icon">✓</span>
					<span>Task {assignment.status === 'completed' ? 'Completed' : 'Cancelled'}</span>
				</div>
			</div>
		{/if}
	{/if}
</div>

<style>
	.mobile-task-detail {
		min-height: 100%;
		background: #F8FAFC;
		padding: 0;
		padding-bottom: 0.5rem;
	}

	/* Loading & Error States */
	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
		text-align: center;
		min-height: 40vh;
		color: #6B7280;
		font-size: 0.82rem;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid #E5E7EB;
		border-top: 2px solid #3B82F6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 0.5rem;
	}

	.error-state p {
		font-size: 0.8rem;
		color: #6B7280;
		margin: 0 0 0.75rem 0;
	}

	.back-btn-error {
		padding: 0.4rem 0.8rem;
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 500;
		cursor: pointer;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Content */
	.task-header {
		background: white;
		padding: 0.5rem 0.75rem;
		border-bottom: 1px solid #E5E7EB;
	}

	.task-header h2 {
		font-size: 0.88rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.3rem 0;
		line-height: 1.3;
	}

	.task-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.3rem;
	}

	.priority-badge,
	.status-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.2rem;
		font-size: 0.65rem;
		font-weight: 600;
		padding: 0.15rem 0.45rem;
		border-radius: 4px;
		text-transform: uppercase;
	}

	.overdue-badge {
		background: #FEE2E2;
		color: #DC2626;
		font-size: 0.65rem;
		font-weight: 700;
		padding: 0.15rem 0.45rem;
		border-radius: 4px;
	}

	/* Info Cards */
	.info-card {
		background: white;
		margin: 0.4rem 0.6rem;
		padding: 0.5rem 0.7rem;
		border-radius: 6px;
		border: 1px solid #E5E7EB;
	}

	.info-card h3 {
		font-size: 0.82rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.35rem 0;
	}

	.task-description {
		font-size: 0.78rem;
		color: #4B5563;
		line-height: 1.4;
		margin: 0;
		word-break: break-word;
		overflow-wrap: break-word;
		white-space: pre-wrap;
		max-width: 100%;
	}

	.task-description :global(.url-btn) {
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
		transition: background 0.2s;
	}

	.task-description :global(.url-btn:hover) {
		background: #2563EB;
	}

	/* Timeline */
	.timeline-grid {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
	}

	.tl-row {
		display: flex;
		align-items: baseline;
		gap: 0.4rem;
		padding: 0.2rem 0;
		border-bottom: 1px solid #F3F4F6;
		flex-wrap: wrap;
	}

	.tl-row:last-child {
		border-bottom: none;
	}

	.tl-label {
		font-weight: 500;
		color: #6B7280;
		font-size: 0.76rem;
		min-width: 55px;
	}

	.tl-value {
		font-size: 0.78rem;
		color: #1F2937;
	}

	.tl-sub {
		font-size: 0.68rem;
		color: #9CA3AF;
	}

	.overdue-text .tl-label,
	.overdue-text .tl-value {
		color: #DC2626;
	}

	/* Action Section */
	.action-section {
		position: sticky;
		bottom: 0;
		background: white;
		border-top: 1px solid #E5E7EB;
		padding: 0.5rem 0.7rem;
	}

	.action-buttons {
		display: flex;
		gap: 0.5rem;
	}

	.action-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.3rem;
		padding: 0.5rem 0.7rem;
		border: none;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 600;
		cursor: pointer;
		min-height: 36px;
	}

	.start-btn {
		background: #F59E0B;
		color: white;
	}

	.complete-btn {
		background: #10B981;
		color: white;
	}

	.action-btn:disabled {
		opacity: 0.7;
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

	/* Completion Section */
	.completion-section {
		padding: 0.5rem 0.7rem;
	}

	.completion-msg {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		background: #F0FDF4;
		border: 1px solid #BBF7D0;
		padding: 0.5rem 0.7rem;
		border-radius: 6px;
		font-size: 0.8rem;
		color: #059669;
		font-weight: 500;
	}

	.completion-icon {
		font-size: 1rem;
		color: #10B981;
	}

	/* Responsive */
	@supports (padding: max(0px)) {
		.action-section,
		.completion-section {
			padding-bottom: max(0.5rem, env(safe-area-inset-bottom));
		}
	}

	/* Attachments */
	.attachments-list {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.attachment-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.4rem 0.5rem;
		background: #F8FAFC;
		border: 1px solid #E2E8F0;
		border-radius: 6px;
	}

	.attachment-info {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		flex: 1;
		min-width: 0;
	}

	.att-icon {
		font-size: 1rem;
		flex-shrink: 0;
	}

	.attachment-details {
		flex: 1;
		min-width: 0;
	}

	.att-name {
		display: block;
		font-size: 0.76rem;
		font-weight: 500;
		color: #1F2937;
		word-break: break-word;
		line-height: 1.3;
	}

	.att-meta {
		display: block;
		font-size: 0.68rem;
		color: #6B7280;
	}

	.download-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 0.3rem;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
</style>
