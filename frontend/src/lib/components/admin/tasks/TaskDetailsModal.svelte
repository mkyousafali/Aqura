<script>
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import TaskCompletionModal from './TaskCompletionModal.svelte';
	import { db } from '$lib/utils/supabase';
	import FileDownload from '$lib/components/common/FileDownload.svelte';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let task;
	export let windowId;
	export let onTaskCompleted = () => {};

	let taskImages = [];
	let taskAttachments = []; // For FileDownload component
	let assignmentDetails = null;
	let createdByUsername = '';
	let loading = true;
	let error = '';

	// Get current user data
	$: currentUserData = $currentUser;

	onMount(async () => {
		await loadTaskDetails();
	});

	async function loadTaskDetails() {
		try {
			loading = true;
			error = '';

			console.log('🔍 [TaskDetails] Task data:', task);

			// Load task images
			const imageResult = await db.taskImages.getByTaskId(task.id);
			
			if (imageResult.error) {
				console.error('❌ [TaskDetails] Error loading task images:', imageResult.error);
			} else {
				taskImages = imageResult.data || [];
				console.log('✅ [TaskDetails] Loaded', taskImages.length, 'images');
			}

			// Load task attachments for FileDownload component
			const attachmentResult = await db.taskAttachments.getByTaskId(task.id);
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
						downloadUrl: attachment.file_path && attachment.file_path.startsWith('http') 
							? attachment.file_path 
							: `https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/task-images/${attachment.file_path || ''}`,
						uploadedBy: attachment.uploaded_by_name || attachment.uploaded_by || 'Unknown',
						uploadedAt: attachment.created_at
					}));
				console.log('📎 [TaskDetails] Task attachments loaded:', taskAttachments.length);
			} else {
				taskAttachments = [];
			}

			// Load assignment details if we have an assignment_id
			if (task.assignment_id) {
				const assignmentResult = await db.taskAssignments.getById(task.assignment_id);
				if (assignmentResult.error) {
					console.error('❌ [TaskDetails] Error loading assignment details:', assignmentResult.error);
				} else {
					assignmentDetails = assignmentResult.data;
				}
			}

			// Load username for created_by if it's a user ID
			if (task.created_by && task.created_by.length > 30) { // Likely a UUID
				try {
					const userResult = await db.users.getById(task.created_by);
					if (!userResult.error && userResult.data) {
						createdByUsername = userResult.data.username || userResult.data.name || 'Unknown User';
					}
				} catch (err) {
					console.error('Error loading user:', err);
				}
			}
		} catch (err) {
			console.error('💥 [TaskDetails] Error loading task details:', err);
			error = 'Failed to load task details';
		} finally {
			loading = false;
		}
	}

	function formatDate(dateString) {
		if (!dateString) return 'No due date';
		return new Date(dateString).toLocaleDateString();
	}

	function formatTime(timeString) {
		if (!timeString) return '';
		return timeString.slice(0, 5);
	}

	function formatDateTime(dateString, timeString = null) {
		if (!dateString) return 'Not set';
		const date = new Date(dateString);
		let formatted = date.toLocaleDateString();
		if (timeString) {
			formatted += ` at ${formatTime(timeString)}`;
		}
		return formatted;
	}

	function isOverdue(dateString, timeString = null) {
		if (!dateString) return false;
		const now = new Date();
		const deadline = new Date(dateString);
		if (timeString) {
			const [hours, minutes] = timeString.split(':');
			deadline.setHours(parseInt(hours), parseInt(minutes));
		}
		return now > deadline;
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return 'text-red-600 bg-red-100';
			case 'medium': return 'text-yellow-600 bg-yellow-100';
			case 'low': return 'text-green-600 bg-green-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}

	function getStatusColor(status) {
		switch (status) {
			case 'pending': return 'text-blue-600 bg-blue-100';
			case 'in_progress': return 'text-yellow-600 bg-yellow-100';
			case 'completed': return 'text-green-600 bg-green-100';
			case 'cancelled': return 'text-red-600 bg-red-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}

	function openTaskCompletion() {
		const completionWindowId = `task-completion-${task.id}`;
		windowManager.openWindow({
			id: completionWindowId,
			title: `Complete Task: ${task.title}`,
			component: TaskCompletionModal,
			props: {
				task: task,
				assignmentId: task.assignment_id,
				onTaskCompleted: () => {
					onTaskCompleted();
					windowManager.closeWindow(completionWindowId);
					windowManager.closeWindow(windowId); // Close details window too
				}
			},
			icon: '✅',
			size: { width: 600, height: 700 },
			position: { 
				x: 120 + (Math.random() * 200), 
				y: 70 + (Math.random() * 100) 
			},
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	function closeWindow() {
		windowManager.closeWindow(windowId);
	}
</script>

<div class="task-details-modal p-6 space-y-6 bg-white">
	{#if loading}
		<div class="flex items-center justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
			<span class="ml-3 text-gray-600">Loading task details...</span>
		</div>
	{:else if error}
		<div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
			{error}
		</div>
	{:else}
		<!-- Header -->
		<div class="border-b pb-4">
			<div class="flex items-start justify-between">
				<div class="flex-1">
					<h2 class="text-xl font-bold text-gray-900">{task.title}</h2>
					<p class="text-gray-600 mt-2">{task.description || 'No description provided'}</p>
				</div>
				<div class="ml-4 flex space-x-2">
					<span class="px-2 py-1 rounded text-xs font-medium {getPriorityColor(task.priority)}">
						{(task.priority || 'Not set').toUpperCase()}
					</span>
					<span class="px-2 py-1 rounded text-xs font-medium {getStatusColor(task.assignment_status)}">
						{(task.assignment_status || 'Unknown').replace('_', ' ').toUpperCase()}
					</span>
				</div>
			</div>
		</div>
		
		<!-- Task Information Grid -->
		<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
			<div class="space-y-4">
				<h3 class="text-lg font-semibold text-gray-900 border-b pb-2">Task Information</h3>
				
				<div class="space-y-3">
					<div>
						<span class="font-medium text-gray-700">Created by:</span>
						<div class="ml-2">{createdByUsername || task.created_by_name || task.created_by_username || task.assigned_by_name || task.assigned_by_username || 'Unknown User'}</div>
					</div>
					
					<div>
						<span class="font-medium text-gray-700">Assigned:</span>
						<div class="ml-2">{formatDate(task.assigned_at)}</div>
					</div>
				</div>
			</div>
			
			<div class="space-y-4">
				<h3 class="text-lg font-semibold text-gray-900 border-b pb-2">Assignment Details</h3>
				
				{#if assignmentDetails}
					<div class="space-y-3">
						{#if assignmentDetails.schedule_date || assignmentDetails.schedule_time}
							<div>
								<span class="font-medium text-gray-700">Scheduled:</span>
								<div class="ml-2">{formatDateTime(assignmentDetails.schedule_date, assignmentDetails.schedule_time)}</div>
							</div>
						{/if}
						
						{#if assignmentDetails.deadline_date || assignmentDetails.deadline_time}
							<div>
								<span class="font-medium text-gray-700">Deadline:</span>
								<div class="ml-2">
									{formatDateTime(assignmentDetails.deadline_date, assignmentDetails.deadline_time)}
									{#if isOverdue(assignmentDetails.deadline_date, assignmentDetails.deadline_time)}
										<span class="ml-2 px-2 py-1 bg-red-100 text-red-600 text-xs rounded font-medium">OVERDUE</span>
									{/if}
								</div>
							</div>
						{/if}
						
						{#if assignmentDetails.priority_override}
							<div>
								<span class="font-medium text-gray-700">Priority Override:</span>
								<span class="ml-2 px-2 py-1 rounded text-xs font-medium {getPriorityColor(assignmentDetails.priority_override)}">
									{assignmentDetails.priority_override.toUpperCase()}
								</span>
							</div>
						{/if}
						
						{#if assignmentDetails.notes}
							<div>
								<span class="font-medium text-gray-700">Assignment Notes:</span>
								<div class="ml-2 text-sm text-gray-600 bg-gray-50 p-2 rounded">{assignmentDetails.notes}</div>
							</div>
						{/if}
						
						{#if assignmentDetails.is_recurring}
							<div>
								<span class="font-medium text-gray-700">Recurring:</span>
								<span class="ml-2 px-2 py-1 bg-blue-100 text-blue-600 text-xs rounded font-medium">YES</span>
							</div>
						{/if}
						
						{#if assignmentDetails.is_reassignable}
							<div>
								<span class="font-medium text-gray-700">Reassignable:</span>
								<span class="ml-2 px-2 py-1 bg-green-100 text-green-600 text-xs rounded font-medium">YES</span>
							</div>
						{/if}
					</div>
				{:else}
					<div class="text-gray-500 text-sm">No assignment details available</div>
				{/if}
			</div>
		</div>
		
		<!-- Task Requirements -->
		{#if assignmentDetails && (assignmentDetails.require_task_finished || assignmentDetails.require_photo_upload || assignmentDetails.require_erp_reference)}
			<div class="space-y-4">
				<h3 class="text-lg font-semibold text-gray-900 border-b pb-2">Requirements</h3>
				<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
					{#if assignmentDetails.require_task_finished}
						<div class="bg-blue-50 border border-blue-200 p-3 rounded">
							<div class="flex items-center text-blue-700">
								<svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
								</svg>
								Task Completion Required
							</div>
						</div>
					{/if}
					{#if assignmentDetails.require_photo_upload}
						<div class="bg-yellow-50 border border-yellow-200 p-3 rounded">
							<div class="flex items-center text-yellow-700">
								<svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clip-rule="evenodd"/>
								</svg>
								Photo Upload Required
							</div>
						</div>
					{/if}
					{#if assignmentDetails.require_erp_reference}
						<div class="bg-green-50 border border-green-200 p-3 rounded">
							<div class="flex items-center text-green-700">
								<svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
									<path fill-rule="evenodd" d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd"/>
								</svg>
								ERP Reference Required
							</div>
						</div>
					{/if}
				</div>
			</div>
		{/if}
		
		<!-- Task Attachments -->
		{#if taskAttachments && taskAttachments.length > 0}
			<div class="space-y-4">
				<h3 class="text-lg font-semibold text-gray-900 border-b pb-2">Task Files ({taskAttachments.length})</h3>
				<FileDownload 
					files={taskAttachments}
					showDetails={true}
					compact={false}
					maxHeight="300px"
					on:download={(e) => console.log('Downloaded:', e.detail.file)}
					on:preview={(e) => console.log('Previewed:', e.detail.file)}
				/>
			</div>
		{:else}
			<div class="space-y-4">
				<h3 class="text-lg font-semibold text-gray-900 border-b pb-2">Task Files</h3>
				<div class="text-center py-8 text-gray-500">
					<svg class="w-12 h-12 mx-auto text-gray-300 mb-2" fill="currentColor" viewBox="0 0 20 20">
						<path fill-rule="evenodd" d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" clip-rule="evenodd"/>
						<path fill-rule="evenodd" d="M4 5a2 2 0 012-2v1a1 1 0 001 1h6a1 1 0 001-1V3a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V5zM8 8a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1zm1 3a1 1 0 100 2h2a1 1 0 100-2H9z" clip-rule="evenodd"/>
					</svg>
					<p>No files attached to this task</p>
				</div>
			</div>
		{/if}
		
		<!-- Actions -->
		<div class="pt-4 border-t flex space-x-3">
			{#if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled' && task.assigned_to_user_id === currentUserData?.id}
				<button 
					on:click={openTaskCompletion}
					class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center space-x-2"
				>
					<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
					</svg>
					<span>Complete Task</span>
				</button>
			{:else if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled'}
				<div class="px-4 py-2 bg-yellow-100 text-yellow-700 rounded-lg text-sm font-medium">
					Task not assigned to you
				</div>
			{:else}
				<div class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium">
					Task {task.assignment_status === 'completed' ? 'Completed' : 'Cancelled'}
				</div>
			{/if}
			
			<button 
				on:click={closeWindow}
				class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center space-x-2"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
				</svg>
				<span>Close</span>
			</button>
		</div>
	{/if}
</div>

<style>
	.task-details-modal {
		max-height: 90vh;
		overflow-y: auto;
	}
	
	.task-details-modal img {
		transition: transform 0.2s ease-in-out;
	}
	
	.task-details-modal img:hover {
		transform: scale(1.02);
	}

	.aspect-video {
		aspect-ratio: 16 / 9;
	}
</style>