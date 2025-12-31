<script>
	import { createEventDispatcher } from 'svelte';
	import { uploadToSupabase, db } from '$lib/utils/supabase';
	import { createTask, updateTask } from '$lib/stores/taskStore';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import { notifications } from '$lib/stores/notifications';
	import FileUpload from '$lib/components/common/FileUpload.svelte';
	
	// Props
	export let editMode = false;
	export let taskData = null;
	export let onTaskUpdated = null;
	
	const dispatch = createEventDispatcher();
	
	// Form data - initialize with task data if in edit mode
	let formData = {
		title: editMode && taskData ? taskData.title : '',
		description: editMode && taskData ? taskData.description : '',
		created_by: editMode && taskData ? taskData.created_by : ($currentUser?.id || '')
	};
	
	// Form state
	let isSubmitting = false;
	let attachedFiles = [];
	let fileUploadComponent;
	let fileErrors = [];
	let errors = {};
	
	// React to changes in taskData (when editing)
	$: if (editMode && taskData) {
		formData = {
			title: taskData.title || '',
			description: taskData.description || '',
			created_by: taskData.created_by || ($currentUser?.id || '')
		};
	}
	
	// Ensure created_by is always set when user auth changes
	$: if ($currentUser?.id && !editMode) {
		formData.created_by = $currentUser.id;
	}
	
	// File handling
	function handleFilesChanged(event) {
		attachedFiles = event.detail.files;
		fileErrors = event.detail.errors;
	}

	function handleUploadComplete(event) {
		console.log('� [TaskCreate] Files uploaded:', event.detail);
	}
	
	// Validation
	const validateForm = () => {
		errors = {};
		
		if (!formData.title.trim()) {
			errors.title = 'Task title is required';
		}
		
		if (!formData.description.trim()) {
			errors.description = 'Task description is required';
		}
		
		if (!formData.created_by) {
			// If no user is set, try to get it from current user or use a default
			if ($currentUser?.id) {
				formData.created_by = $currentUser.id;
			} else {
				// Use a fallback admin user ID for testing
				formData.created_by = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b';
			}
		}
		
		return Object.keys(errors).length === 0;
	};
	
	// Form submission
	const handleSubmit = async () => {
		console.log('🚀 [TaskCreate] Form submission started');
		console.log('📋 [TaskCreate] Form data:', formData);
		console.log('🔐 [TaskCreate] Current user:', $currentUser);
		
		if (!validateForm()) {
			console.log('❌ [TaskCreate] Form validation failed:', errors);
			return;
		}
		
		isSubmitting = true;
		
		try {
			let uploadedFiles = [];
			
			// Upload files if present
			if (attachedFiles.length > 0 && fileUploadComponent) {
				console.log('� [TaskCreate] Uploading files...');
				const uploadResult = await fileUploadComponent.uploadFiles();
				
				if (!uploadResult.success) {
					const errorMsg = `File upload failed: ${uploadResult.errors.join(', ')}`;
					notifications.add({
						type: 'error',
						message: errorMsg,
						duration: 6000
					});
					errors.files = errorMsg;
					isSubmitting = false;
					return;
				}
				
				uploadedFiles = uploadResult.uploadedFiles;
				console.log('📎 [TaskCreate] Files uploaded successfully:', uploadedFiles);
			}

			// Create or update the task
			console.log('📝 [TaskCreate] Creating/updating task with data:', formData);
			let result;
			if (editMode && taskData?.id) {
				result = await updateTask(taskData.id, formData);
			} else {
				result = await createTask(formData);
			}
			
			console.log('📊 [TaskCreate] Task creation result:', result);

			if (result.success) {
				// Save file attachments to database
				if (uploadedFiles.length > 0 && result.data?.id) {
					console.log('💾 [TaskCreate] Saving file attachments...');
					
					for (const file of uploadedFiles) {
						try {
							const attachmentData = {
								task_id: result.data.id,
								file_name: file.fileName,
								file_path: file.filePath,
								file_size: file.fileSize,
								file_type: file.fileType,
								attachment_type: 'task_creation',
								uploaded_by: $currentUser?.id || formData.created_by,
								uploaded_by_name: $currentUser?.username || 'Unknown User'
							};
							
							console.log('� [TaskCreate] Creating attachment record:', attachmentData);
							const attachmentResult = await db.taskAttachments.create(attachmentData);
							
							if (attachmentResult.error) {
								console.error('❌ [TaskCreate] Failed to save attachment:', attachmentResult.error);
							} else {
								console.log('✅ [TaskCreate] Attachment saved:', attachmentResult.data);
							}
						} catch (attachmentError) {
							console.error('❌ [TaskCreate] Error saving attachment:', attachmentError);
						}
					}
					
					notifications.add({
						type: 'info',
						message: `Task files uploaded and saved successfully!`,
						duration: 3000
					});
				}

				// Show success notification
				notifications.add({
					type: 'success',
					message: `Task "${formData.title}" ${editMode ? 'updated' : 'created'} successfully!`,
					duration: 4000
				});
				
				if (editMode) {
					dispatch('taskUpdated', result.data);
					if (onTaskUpdated && typeof onTaskUpdated === 'function') {
						onTaskUpdated(result.data);
					}
				} else {
					dispatch('taskCreated', result.data);
				}
				dispatch('close');
			} else {
				// Show error notification
				const errorMsg = result.error || `Failed to ${editMode ? 'update' : 'create'} task`;
				notifications.add({
					type: 'error',
					message: errorMsg,
					duration: 6000
				});
				errors.submit = errorMsg;
			}
		} catch (error) {
			console.error(`❌ [TaskCreate] Error ${editMode ? 'updating' : 'creating'} task:`, error);
			console.error('❌ [TaskCreate] Error details:', {
				message: error?.message,
				stack: error?.stack,
				name: error?.name,
				cause: error?.cause,
				formData: formData,
				editMode: editMode,
				taskData: taskData
			});
			const errorMsg = `An unexpected error occurred: ${error?.message || 'Unknown error'}`;
			
			// Show error notification
			notifications.add({
				type: 'error',
				message: errorMsg,
				duration: 6000
			});
			errors.submit = errorMsg;
		} finally {
			isSubmitting = false;
		}
	};
	
	const handleClose = () => {
		dispatch('close');
	};
</script>

<div class="bg-white h-full flex flex-col overflow-hidden">
	<div class="flex-1 overflow-y-auto">
		<div class="p-6">
			<!-- Header -->
			<div class="flex items-center justify-between mb-6">
				<h2 class="text-xl font-semibold text-gray-900">
					{editMode ? 'Edit Task' : 'Create New Task'}
				</h2>
			</div>

			<form on:submit|preventDefault={handleSubmit} class="space-y-6">
				<!-- Task Title -->
				<div>
					<label for="task-title" class="block text-sm font-medium text-gray-700 mb-2">
						Task Title *
					</label>
					<input
						id="task-title"
						type="text"
						bind:value={formData.title}
						class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						placeholder="Enter task title"
						class:border-red-500={errors.title}
					/>
					{#if errors.title}
						<p class="mt-1 text-sm text-red-600">{errors.title}</p>
					{/if}
				</div>

				<!-- Task Description -->
				<div>
					<label for="task-description" class="block text-sm font-medium text-gray-700 mb-2">
						Task Description *
					</label>
					<textarea
						id="task-description"
						bind:value={formData.description}
						rows="4"
						class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
						placeholder="Enter task description"
						class:border-red-500={errors.description}
					></textarea>
					{#if errors.description}
						<p class="mt-1 text-sm text-red-600">{errors.description}</p>
					{/if}
				</div>

				<!-- Upload Files (optional) -->
				<div>
					<FileUpload 
						bind:this={fileUploadComponent}
						acceptedTypes="image/*,.pdf,.doc,.docx,.xls,.xlsx,.txt,.sql,.zip,.rar"
						maxSizeInMB={50}
						bucket="task-images"
						multiple={true}
						showPreview={true}
						label="Upload Files (optional)"
						placeholder="Upload images, documents, spreadsheets, or other files"
						bind:currentFiles={attachedFiles}
						on:filesChanged={handleFilesChanged}
						on:uploadComplete={handleUploadComplete}
					/>
					
					{#if fileErrors.length > 0}
						<div class="error-messages">
							{#each fileErrors as error}
								<p class="text-sm text-red-600">{error}</p>
							{/each}
						</div>
					{/if}
				</div>

				<!-- Submit Error -->
				{#if errors.submit}
					<div class="bg-red-50 border border-red-200 rounded-md p-3">
						<p class="text-sm text-red-600">{errors.submit}</p>
					</div>
				{/if}

				<!-- Action Buttons -->
				<div class="flex justify-end space-x-3 pt-4 border-t">
					<button
						type="button"
						on:click={handleClose}
						class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 border border-gray-300 rounded-md hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-gray-500 transition-colors"
						disabled={isSubmitting}
					>
						Cancel
					</button>
					<button
						type="submit"
						class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
						disabled={isSubmitting}
					>
						{isSubmitting 
							? (editMode ? 'Updating...' : 'Creating...') 
							: (editMode ? 'Update Task' : 'Create Task')
						}
					</button>
				</div>
			</form>
		</div>
	</div>
</div>

<style>
	/* Custom checkbox styling */
	input[type="checkbox"]:checked {
		background-color: #3b82f6;
		border-color: #3b82f6;
	}
	
	/* File input styling */
	input[type="file"]::-webkit-file-upload-button {
		cursor: pointer;
	}
</style>