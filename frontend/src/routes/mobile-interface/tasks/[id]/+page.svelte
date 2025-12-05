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
			goto(`/mobile/tasks/${taskId}/complete`);
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
</script>

<svelte:head>
	<title>{task ? task.title : 'Task Details'} - Aqura Mobile</title>
</svelte:head>

<div class="mobile-task-detail">
	{#if isLoading}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading task details...</p>
		</div>
	{:else if !task || !assignment}
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
			<button class="back-btn-error" on:click={() => goto('/mobile-interface/tasks')}>
				Back to Tasks
			</button>
		</div>
	{:else}
		<!-- Content -->
		<div class="content-section">
			<!-- Task Header Card -->
			<div class="task-header-card" class:overdue={isOverdue(assignment.deadline_date, assignment.deadline_time)}>
				<div class="task-title-section">
					<h2>{task.title}</h2>
					<div class="task-badges">
						<span class="priority-badge" style="background-color: {getPriorityColor(task.priority)}15; color: {getPriorityColor(task.priority)}">
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
							</svg>
							{task.priority?.toUpperCase()} PRIORITY
						</span>
						<span class="status-badge" style="background-color: {getStatusColor(assignment.status)}15; color: {getStatusColor(assignment.status)}">
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								{#if assignment.status === 'completed'}
									<polyline points="20,6 9,17 4,12"/>
								{:else if assignment.status === 'in_progress'}
									<circle cx="12" cy="12" r="10"/>
									<polyline points="12,6 12,12 16,14"/>
								{:else}
									<circle cx="12" cy="12" r="10"/>
								{/if}
							</svg>
							{getStatusDisplayText(assignment.status)}
						</span>
					</div>
				</div>
				
				{#if isOverdue(assignment.deadline_date, assignment.deadline_time) && assignment.status !== 'completed'}
					<div class="overdue-indicator">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"/>
							<line x1="12" y1="8" x2="12" y2="12"/>
							<line x1="12" y1="16" x2="12.01" y2="16"/>
						</svg>
						<span>OVERDUE</span>
					</div>
				{/if}
			</div>

			<!-- Task Description -->
			<div class="info-card">
				<h3>Description</h3>
				<p class="task-description">{task.description || 'No description provided.'}</p>
			</div>

			<!-- Task Timeline -->
			<div class="info-card">
				<h3>Timeline</h3>
				<div class="timeline-grid">
					<div class="timeline-item">
						<div class="timeline-icon created">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<line x1="12" y1="5" x2="12" y2="19"/>
								<line x1="5" y1="12" x2="19" y2="12"/>
							</svg>
						</div>
						<div class="timeline-content">
							<div class="timeline-title">Task Created</div>
							<div class="timeline-time">{formatDateTime(task.created_at)}</div>
							<div class="timeline-person">By {task.created_by_name || 'Unknown'}</div>
						</div>
					</div>

					<div class="timeline-item">
						<div class="timeline-icon assigned">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
								<circle cx="9" cy="7" r="4"/>
								<path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
								<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
							</svg>
						</div>
						<div class="timeline-content">
							<div class="timeline-title">Assigned to You</div>
							<div class="timeline-time">{formatDateTime(assignment.assigned_at)}</div>
							<div class="timeline-person">By {assignment.assigned_by_name || 'Unknown'}</div>
						</div>
					</div>

					{#if assignment.deadline_date}
						<div class="timeline-item">
							<div class="timeline-icon deadline" class:overdue={isOverdue(assignment.deadline_date, assignment.deadline_time)}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<circle cx="12" cy="12" r="10"/>
									<polyline points="12,6 12,12 16,14"/>
								</svg>
							</div>
							<div class="timeline-content">
								<div class="timeline-title">Due Date</div>
								<div class="timeline-time">{formatDate(assignment.deadline_date)}</div>
								{#if assignment.deadline_time}
									<div class="timeline-person">at {formatTime(assignment.deadline_time)}</div>
								{/if}
							</div>
						</div>
					{/if}

					{#if assignment.completed_at}
						<div class="timeline-item">
							<div class="timeline-icon completed">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<polyline points="20,6 9,17 4,12"/>
								</svg>
							</div>
							<div class="timeline-content">
								<div class="timeline-title">Completed</div>
								<div class="timeline-time">{formatDateTime(assignment.completed_at)}</div>
							</div>
						</div>
					{/if}
				</div>
			</div>

			<!-- Task Attachments -->
			{#if taskAttachments.length > 0}
				<div class="info-card">
					<h3>Attachments ({taskAttachments.length})</h3>
					<div class="attachments-list">
						{#each taskAttachments as attachment}
							<div class="attachment-item">
								<div class="attachment-info">
									<div class="attachment-icon">
										{getFileIcon(attachment.fileType)}
									</div>
									<div class="attachment-details">
										<div class="attachment-name">{attachment.fileName}</div>
										<div class="attachment-meta">
											<span class="attachment-size">{formatFileSize(attachment.fileSize)}</span>
											{#if attachment.uploadedBy}
												<span class="attachment-by">• by {attachment.uploadedBy}</span>
											{/if}
										</div>
									</div>
								</div>
								<button 
									class="download-btn"
									on:click={() => downloadAttachment(attachment)}
									title="Download {attachment.fileName}"
								>
									<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
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

		<!-- Action Buttons -->
		{#if assignment.status !== 'completed' && assignment.status !== 'cancelled' && assignment.assigned_to_user_id === currentUserData?.id}
			<div class="action-section">
				<div class="action-buttons">
					{#if assignment.status === 'assigned'}
						<button 
							class="action-btn start-btn" 
							on:click={() => updateAssignmentStatus('in_progress')}
							disabled={isUpdating}
						>
							{#if isUpdating}
								<div class="btn-spinner"></div>
							{:else}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<polygon points="5,3 19,12 5,21"/>
								</svg>
							{/if}
							Start Task
						</button>
					{/if}

					{#if assignment.status === 'in_progress' || assignment.status === 'assigned'}
						<button 
							class="action-btn complete-btn" 
							on:click={() => updateAssignmentStatus('completed')}
							disabled={isUpdating}
						>
							{#if isUpdating}
								<div class="btn-spinner"></div>
							{:else}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<polyline points="20,6 9,17 4,12"/>
								</svg>
							{/if}
							Mark Complete
						</button>
					{/if}
				</div>
			</div>
		{:else}
			<div class="completion-section">
				<div class="completion-message">
					<div class="completion-icon">
						<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20,6 9,17 4,12"/>
						</svg>
					</div>
					<h3>Task {assignment.status === 'completed' ? 'Completed' : 'Cancelled'}</h3>
					<p>
						{#if assignment.status === 'completed'}
							Great job! This task has been marked as completed.
						{:else}
							This task has been cancelled and is no longer active.
						{/if}
					</p>
				</div>
			</div>
		{/if}
	{/if}
</div>

<style>
	.mobile-task-detail {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	/* Loading & Error States */
	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		min-height: 100vh;
		min-height: 100dvh;
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

	.error-icon {
		width: 80px;
		height: 80px;
		background: #FEE2E2;
		color: #DC2626;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-bottom: 1.5rem;
	}

	.error-state h2 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #374151;
		margin: 0 0 0.5rem 0;
	}

	.error-state p {
		font-size: 1rem;
		color: #6B7280;
		margin: 0 0 2rem 0;
		line-height: 1.5;
	}

	.back-btn-error {
		padding: 0.75rem 1.5rem;
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
	}

	.back-btn-error:hover {
		background: #2563EB;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* Content */
	.content-section {
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	/* Task Header Card */
	.task-header-card {
		background: white;
		border-radius: 16px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		border: 2px solid transparent;
	}

	.task-header-card.overdue {
		border-color: #FEE2E2;
		background: linear-gradient(to right, #FEF2F2, white);
	}

	.task-title-section h2 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #1F2937;
		margin: 0 0 1rem 0;
		line-height: 1.3;
	}

	.task-badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.priority-badge,
	.status-badge {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.375rem 0.75rem;
		border-radius: 8px;
		text-transform: uppercase;
	}

	.overdue-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		background: #FEE2E2;
		color: #DC2626;
		padding: 0.75rem;
		border-radius: 12px;
		font-size: 0.75rem;
		font-weight: 700;
		text-align: center;
		min-width: 80px;
	}

	.overdue-indicator span {
		margin-top: 0.25rem;
	}

	/* Info Cards */
	.info-card {
		background: white;
		border-radius: 16px;
		padding: 1.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.info-card h3 {
		font-size: 1.1rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 1rem 0;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.task-description {
		font-size: 1rem;
		color: #4B5563;
		line-height: 1.6;
		margin: 0;
	}

	/* Timeline */
	.timeline-grid {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.timeline-item {
		display: flex;
		align-items: flex-start;
		gap: 1rem;
	}

	.timeline-icon {
		width: 32px;
		height: 32px;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.timeline-icon.created {
		background: #DBEAFE;
		color: #3B82F6;
	}

	.timeline-icon.assigned {
		background: #FEF3C7;
		color: #F59E0B;
	}

	.timeline-icon.deadline {
		background: #F3E8FF;
		color: #8B5CF6;
	}

	.timeline-icon.deadline.overdue {
		background: #FEE2E2;
		color: #DC2626;
	}

	.timeline-icon.completed {
		background: #D1FAE5;
		color: #10B981;
	}

	.timeline-content {
		flex: 1;
	}

	.timeline-title {
		font-size: 1rem;
		font-weight: 600;
		color: #1F2937;
		margin-bottom: 0.25rem;
	}

	.timeline-time {
		font-size: 0.875rem;
		color: #6B7280;
		margin-bottom: 0.125rem;
	}

	.timeline-person {
		font-size: 0.75rem;
		color: #9CA3AF;
	}

	/* Details Grid */
	.details-grid {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.detail-item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 0;
		border-bottom: 1px solid #F3F4F6;
	}

	.detail-item:last-child {
		border-bottom: none;
	}

	.detail-label {
		font-size: 0.875rem;
		color: #6B7280;
		font-weight: 500;
	}

	.detail-value {
		font-size: 0.875rem;
		color: #1F2937;
		font-weight: 600;
	}

	/* Action Section */
	.action-section {
		position: sticky;
		bottom: 0;
		background: white;
		border-top: 1px solid #E5E7EB;
		padding: 1.5rem;
		padding-bottom: calc(1.5rem + env(safe-area-inset-bottom));
		box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
	}

	.action-buttons {
		display: flex;
		gap: 1rem;
	}

	.action-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 1rem 1.5rem;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		touch-action: manipulation;
		min-height: 48px;
	}

	.start-btn {
		background: #F59E0B;
		color: white;
	}

	.start-btn:hover:not(:disabled) {
		background: #D97706;
		transform: translateY(-1px);
	}

	.complete-btn {
		background: #10B981;
		color: white;
	}

	.complete-btn:hover:not(:disabled) {
		background: #059669;
		transform: translateY(-1px);
	}

	.action-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
		transform: none;
	}

	.btn-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid transparent;
		border-top: 2px solid currentColor;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	/* Completion Section */
	.completion-section {
		padding: 1.5rem;
		padding-bottom: calc(1.5rem + env(safe-area-inset-bottom));
	}

	.completion-message {
		background: white;
		border-radius: 16px;
		padding: 2rem;
		text-align: center;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.completion-icon {
		width: 64px;
		height: 64px;
		background: #D1FAE5;
		color: #10B981;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 1rem;
	}

	.completion-message h3 {
		font-size: 1.25rem;
		font-weight: 600;
		color: #1F2937;
		margin: 0 0 0.5rem 0;
	}

	.completion-message p {
		font-size: 1rem;
		color: #6B7280;
		margin: 0;
		line-height: 1.5;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.page-header {
			padding: 1rem;
			padding-top: calc(1rem + env(safe-area-inset-top));
		}

		.content-section {
			padding: 1rem;
			gap: 1rem;
		}

		.task-header-card {
			padding: 1rem;
			flex-direction: column;
			gap: 1rem;
		}

		.task-title-section h2 {
			font-size: 1.25rem;
		}

		.action-section {
			padding: 1rem;
			padding-bottom: calc(1rem + env(safe-area-inset-bottom));
		}

		.action-buttons {
			flex-direction: column;
		}
	}

	/* Safe area handling */
	@supports (padding: max(0px)) {
		.page-header {
			padding-top: max(1rem, env(safe-area-inset-top));
		}

		.action-section,
		.completion-section {
			padding-bottom: max(1.5rem, env(safe-area-inset-bottom));
		}
	}

	/* Attachments Styles */
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
		background: #F8FAFC;
		border: 1px solid #E2E8F0;
		border-radius: 8px;
		transition: all 0.2s ease;
	}

	.attachment-item:hover {
		background: #F1F5F9;
		border-color: #CBD5E1;
	}

	.attachment-info {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		flex: 1;
		min-width: 0;
	}

	.attachment-icon {
		font-size: 1.5rem;
		flex-shrink: 0;
	}

	.attachment-details {
		flex: 1;
		min-width: 0;
	}

	.attachment-name {
		font-size: 0.875rem;
		font-weight: 500;
		color: #1F2937;
		margin-bottom: 0.25rem;
		word-break: break-word;
		line-height: 1.3;
	}

	.attachment-meta {
		font-size: 0.75rem;
		color: #6B7280;
		display: flex;
		align-items: center;
		gap: 0.25rem;
	}

	.attachment-size {
		font-weight: 500;
	}

	.attachment-by {
		opacity: 0.8;
	}

	.download-btn {
		background: #3B82F6;
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.5rem;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.download-btn:hover {
		background: #2563EB;
		transform: scale(1.05);
	}

	.download-btn:active {
		transform: scale(0.95);
	}
</style>
