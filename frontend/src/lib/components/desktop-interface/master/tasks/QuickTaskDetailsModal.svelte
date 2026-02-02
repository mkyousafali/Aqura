<script>
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { windowManager } from '$lib/stores/windowManager';
	import FileDownload from '$lib/components/common/FileDownload.svelte';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let task;

	let loading = true;
	let taskAttachments = []; // For FileDownload component
	let incidentData = null;
	let incidentAttachments = [];

	// Get current user data
	$: currentUserData = $currentUser;

	onMount(async () => {
		if (task) {
			try {
				// Load incident data if this task is linked to an incident
				if (task.incident_id) {
					const { data: incident, error: incidentError } = await supabase
						.from('incidents')
						.select('id, incident_types(incident_type_en, incident_type_ar), attachments, employee_id, branch_id')
						.eq('id', task.incident_id)
						.single();
					
					if (incident && !incidentError) {
						incidentData = incident;
						incidentAttachments = incident.attachments || [];
						console.log('📎 [QuickTaskDetails] Incident attachments loaded:', incidentAttachments.length);
					}
				}

				// Load task attachments for FileDownload component - Quick Tasks use different file structure
				if (task.files && task.files.length > 0) {
					// Transform Quick Task files to match FileDownload component format
					taskAttachments = task.files.map(file => ({
						id: file.id,
						file_name: file.file_name,
						file_path: file.file_path,
						file_type: file.file_type,
						file_size: file.file_size,
						uploaded_at: file.uploaded_at
					}));
					console.log('📎 [QuickTaskDetails] Quick task attachments loaded:', taskAttachments.length);
				} else {
					taskAttachments = [];
					console.log('📎 [QuickTaskDetails] No attachments for quick task');
				}
			} catch (error) {
				console.error('Error loading quick task attachments:', error);
				taskAttachments = [];
			}
		}
		loading = false;
	});

	function getStatusColor(status) {
		switch (status) {
			case 'pending': return 'text-blue-600 bg-blue-100';
			case 'in_progress': return 'text-yellow-600 bg-yellow-100';
			case 'completed': return 'text-green-600 bg-green-100';
			case 'cancelled': return 'text-red-600 bg-red-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}

	function getPriorityColor(priority) {
		switch (priority) {
			case 'high': return 'text-red-600 bg-red-100';
			case 'medium': return 'text-yellow-600 bg-yellow-100';
			case 'low': return 'text-green-600 bg-green-100';
			default: return 'text-gray-600 bg-gray-100';
		}
	}

	function formatIssueType(issueType) {
		if (!issueType) return 'Not specified';
		return issueType.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase());
	}

	function formatPriceTag(priceTag) {
		if (!priceTag) return 'Not specified';
		return priceTag.toUpperCase();
	}

	function openQuickTaskCompletion() {
		// For Quick Tasks, we use a simplified completion process similar to MyTasksView
		if (confirm('Are you sure you want to mark this Quick Task as completed?')) {
			completeQuickTask();
		}
	}

	async function completeQuickTask() {
		try {
			console.log('🔵 [QuickTaskDetails] Completing task:', { taskId: task.id, assignmentId: task.assignment_id });
			
			// Update the quick task assignment status to completed
			const { data, error } = await supabase.from('quick_task_assignments')
				.update({ 
					status: 'completed',
					completed_at: new Date().toISOString()
				})
				.eq('id', task.assignment_id);

			if (error) {
				console.error('❌ [QuickTaskDetails] Error completing quick task:', error);
				alert('Error completing task: ' + (error.message || 'Unknown error'));
				return;
			}

			console.log('✅ [QuickTaskDetails] Quick task completed successfully:', data);

			// Update the task object to reflect completion
			task.assignment_status = 'completed';
			task.completed_at = new Date().toISOString();

			// Call onTaskCompleted callback if provided
			if (onTaskCompleted) {
				onTaskCompleted();
			}

			alert('Quick Task completed successfully!');
		} catch (error) {
			console.error('❌ [QuickTaskDetails] Error completing quick task:', error);
			alert('Error completing task: ' + (error.message || 'Unknown error'));
		}
	}
</script>

<div class="quick-task-details-modal p-6 space-y-6 bg-white">
	{#if loading}
		<div class="flex items-center justify-center py-8">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-600"></div>
			<span class="ml-3 text-gray-600">Loading quick task details...</span>
		</div>
	{:else}
		<!-- Header Section -->
		<div class="flex items-start justify-between border-b pb-4">
			<div class="flex-1">
				<div class="flex items-center space-x-2 mb-2">
					<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
						⚡ QUICK TASK
					</span>
					<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getStatusColor(task.assignment_status)}">
						{task.assignment_status ? task.assignment_status.replace('_', ' ').toUpperCase() : 'Unknown'}
					</span>
					{#if task.priority}
						<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getPriorityColor(task.priority)}">
							{task.priority.toUpperCase()}
						</span>
					{/if}
				</div>
				<h1 class="text-2xl font-bold text-gray-900 mb-2">{task.title}</h1>
				{#if task.description}
					<p class="text-gray-600">{task.description}</p>
				{:else}
					<p class="text-gray-400 italic">No description provided</p>
				{/if}
			</div>
		</div>

		<!-- Quick Task Specific Information -->
		<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
			<div class="space-y-4">
				<div>
					<h3 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Issue Type</h3>
					<p class="mt-1 text-lg text-gray-900">{formatIssueType(task.issue_type)}</p>
				</div>
				
				<div>
					<h3 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Price Tag</h3>
					<p class="mt-1 text-lg text-gray-900">{formatPriceTag(task.price_tag)}</p>
				</div>

				{#if task.deadline_datetime}
					<div>
						<h3 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Deadline</h3>
						<p class="mt-1 text-lg text-gray-900">{new Date(task.deadline_datetime).toLocaleString()}</p>
					</div>
				{/if}
			</div>

			<div class="space-y-4">
				<div>
					<h3 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Assigned By</h3>
					<p class="mt-1 text-lg text-gray-900">{task.assigned_by_name || 'Unknown'}</p>
				</div>
				
				<div>
					<h3 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Assigned Date</h3>
					<p class="mt-1 text-lg text-gray-900">
						{task.assigned_at ? new Date(task.assigned_at).toLocaleDateString() : 'Unknown'}
					</p>
				</div>

				{#if task.completed_at}
					<div>
						<h3 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Completed Date</h3>
						<p class="mt-1 text-lg text-green-600">
							{new Date(task.completed_at).toLocaleDateString()}
						</p>
					</div>
				{/if}
			</div>
		</div>

		<!-- Incident Attachments Section -->
		{#if incidentAttachments && incidentAttachments.length > 0}
			<div class="space-y-4">
				<h3 class="text-lg font-semibold text-gray-900 border-b pb-2">📎 Incident Attachments ({incidentAttachments.length})</h3>
				<div class="flex flex-col gap-3">
					{#each incidentAttachments as attachment}
						{#if attachment.type === 'image'}
							<div class="rounded-lg overflow-hidden border border-gray-200 group cursor-pointer hover:shadow-md transition bg-gray-50">
								<img src={attachment.url} alt={attachment.name || 'Incident attachment'} class="w-full h-auto max-h-80 object-contain" />
								<div class="bg-gray-50 p-2 text-xs text-gray-600 truncate border-t">{attachment.name || 'Image'}</div>
							</div>
						{:else}
							<a 
								href={attachment.url} 
								target="_blank" 
								rel="noopener noreferrer" 
								class="flex items-center gap-3 p-3 bg-gray-50 border border-gray-200 rounded-lg hover:bg-gray-100 transition"
							>
								<span class="text-2xl">{attachment.type === 'pdf' ? '📄' : '📁'}</span>
								<span class="text-sm text-gray-700">{attachment.name || 'File'}</span>
							</a>
						{/if}
					{/each}
				</div>
				{#if incidentData}
					<div class="bg-gray-50 p-3 text-sm text-gray-600 border rounded-lg">
						<p><strong>Incident:</strong> {incidentData.id}</p>
						<p><strong>Type:</strong> {incidentData.incident_types?.incident_type_en || 'Unknown'}</p>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Task Files Section -->
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
					<p>No files attached to this quick task</p>
				</div>
			</div>
		{/if}

		<!-- Task Completion Section -->
		<div class="space-y-4">
			<h3 class="text-lg font-semibold text-gray-900 border-b pb-2">Task Completion</h3>
			{#if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled' && task.assigned_to_user_id === currentUserData?.id}
				<div class="bg-blue-50 border border-blue-200 p-4 rounded-lg">
					<div class="flex items-start space-x-3">
						<div class="flex-shrink-0">
							<svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
							</svg>
						</div>
						<div class="flex-1">
							<h4 class="text-sm font-medium text-blue-900 mb-1">Complete Quick Task</h4>
							
							<!-- Completion Requirements Checklist -->
							<div class="mb-4">
								<p class="text-sm text-blue-700 mb-3">Complete the following requirements to finish this task:</p>
								
								<div class="flex flex-wrap gap-4 items-center">
									<!-- Always required - mark as finished -->
									<label class="flex items-center space-x-2 text-xs bg-green-50 px-3 py-2 rounded border">
										<input type="checkbox" class="w-4 h-4 text-green-600 border-2 border-gray-400 rounded" disabled checked />
										<span class="text-green-700 font-medium">✅ Task Done</span>
									</label>
									
									<!-- Photo Upload Requirement -->
									<label class="flex items-center space-x-2 text-xs bg-blue-50 px-3 py-2 rounded border cursor-pointer hover:bg-blue-100">
										<input type="checkbox" class="w-4 h-4 text-blue-600 border-2 border-gray-400 rounded" />
										<span class="text-blue-700">📷 Photo</span>
									</label>
									
									<!-- ERP Reference Requirement -->
									<label class="flex items-center space-x-2 text-xs bg-purple-50 px-3 py-2 rounded border cursor-pointer hover:bg-purple-100">
										<input type="checkbox" class="w-4 h-4 text-purple-600 border-2 border-gray-400 rounded" />
										<span class="text-purple-700">🔢 ERP Ref</span>
									</label>
									
									<!-- File Upload Requirement -->
									<label class="flex items-center space-x-2 text-xs bg-orange-50 px-3 py-2 rounded border cursor-pointer hover:bg-orange-100">
										<input type="checkbox" class="w-4 h-4 text-orange-600 border-2 border-gray-400 rounded" />
										<span class="text-orange-700">📎 File Upload</span>
									</label>
								</div>
							</div>
							
							<div class="text-xs text-gray-500 mb-3">
								Current Status: {task.assignment_status || 'Unknown'}
							</div>
							<button 
								on:click={openQuickTaskCompletion}
								class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center space-x-2"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
								</svg>
								<span>Complete Quick Task</span>
							</button>
						</div>
					</div>
				</div>
			{:else if task.assignment_status !== 'completed' && task.assignment_status !== 'cancelled'}
				<div class="bg-yellow-50 border border-yellow-200 p-4 rounded-lg">
					<div class="flex items-center space-x-3">
						<div class="flex-shrink-0">
							<svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.084 16.5c-.77.833.192 2.5 1.732 2.5z"/>
							</svg>
						</div>
						<div class="flex-1">
							<h4 class="text-sm font-medium text-yellow-900">Access Restricted</h4>
							<p class="text-sm text-yellow-700">This quick task is not assigned to you. Only assigned users can complete tasks.</p>
						</div>
					</div>
				</div>
			{:else}
				<div class="bg-gray-50 border border-gray-200 p-4 rounded-lg">
					<div class="flex items-center space-x-3">
						<div class="flex-shrink-0">
							{#if task.assignment_status === 'completed'}
								<svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
								</svg>
							{:else}
								<svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>
								</svg>
							{/if}
						</div>
						<div class="flex-1">
							<h4 class="text-sm font-medium text-gray-900">
								Task {task.assignment_status === 'completed' ? 'Completed' : 'Cancelled'}
							</h4>
							<div class="text-xs text-gray-500 mb-1">
								Current Status: {task.assignment_status || 'Unknown'}
							</div>
							{#if task.completed_at}
								<p class="text-sm text-gray-600">
									Completed on: {new Date(task.completed_at).toLocaleString()}
								</p>
							{/if}
						</div>
					</div>
				</div>
			{/if}
		</div>

		<!-- Additional Details Section -->
		<div class="bg-purple-50 rounded-lg p-4 border border-purple-200">
			<h3 class="text-sm font-medium text-purple-800 mb-2">Quick Task Information</h3>
			<p class="text-sm text-purple-700">
				This is a quick task that requires immediate attention. Quick tasks are designed for rapid completion 
				and may have simplified workflows compared to regular tasks.
			</p>
		</div>
	{/if}
</div>

<style>
	.quick-task-details-modal {
		max-height: calc(100vh - 200px);
		overflow-y: auto;
	}
</style>