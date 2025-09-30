<script>
	import { createEventDispatcher } from 'svelte';
	import { uploadToSupabase } from '$lib/utils/supabase';
	import { createTask, updateTask } from '$lib/stores/taskStore';
	import { auth } from '$lib/stores/auth';
	import { notifications } from '$lib/stores/notifications';
	
	// Props
	export let editMode = false;
	export let taskData = null;
	export let onTaskUpdated = null;
	
	const dispatch = createEventDispatcher();
	
	// Form data - initialize with task data if in edit mode
	let formData = {
		title: editMode && taskData ? taskData.title : '',
		description: editMode && taskData ? taskData.description : '',
		created_by: editMode && taskData ? taskData.created_by : ($auth?.user?.id || '')
	};
	
	// Form state
	let isSubmitting = false;
	let imageFile = null;
	let imagePreview = null;
	let errors = {};
	
	// React to changes in taskData (when editing)
	$: if (editMode && taskData) {
		formData = {
			title: taskData.title || '',
			description: taskData.description || '',
			created_by: taskData.created_by || ($auth?.user?.id || '')
		};
	}
	
	// Ensure created_by is always set when user auth changes
	$: if ($auth?.user?.id && !editMode) {
		formData.created_by = $auth.user.id;
	}
	
	// Image handling
	const handleImageUpload = (event) => {
		const file = event.target.files[0];
		if (file) {
			// Validate file type
			if (!file.type.startsWith('image/')) {
				errors.image = 'Please select a valid image file';
				return;
			}
			
			// Validate file size (5MB max)
			if (file.size > 5 * 1024 * 1024) {
				errors.image = 'Image size must be less than 5MB';
				return;
			}
			
			imageFile = file;
			errors.image = null;
			
			// Create preview
			const reader = new FileReader();
			reader.onload = (e) => {
				imagePreview = e.target.result;
			};
			reader.readAsDataURL(file);
		}
	};
	
	const removeImage = () => {
		imageFile = null;
		imagePreview = null;
		// Clear the file input
		document.getElementById('image-upload').value = '';
	};
	
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
			errors.created_by = 'User authentication required to create tasks';
		}
		
		return Object.keys(errors).length === 0;
	};
	
	// Form submission
	const handleSubmit = async () => {
		if (!validateForm()) {
			return;
		}
		
		isSubmitting = true;
		
		try {
			let uploadResult = null;
			
			// Upload image if present
			if (imageFile) {
				console.log('🔍 [TaskCreate] Attempting to upload image:', imageFile.name, imageFile.type, imageFile.size);
				uploadResult = await uploadToSupabase(imageFile, 'task-images');
				console.log('📤 [TaskCreate] Upload result:', uploadResult);
				
				if (uploadResult.error) {
					console.error('❌ [TaskCreate] Upload error details:', uploadResult.error);
					const errorMsg = `Failed to upload image: ${uploadResult.error.message || JSON.stringify(uploadResult.error)}`;
					
					// Show error notification for image upload
					notifications.add({
						type: 'error',
						message: errorMsg,
						duration: 6000
					});
					errors.image = errorMsg;
					return;
				}
			}

			// Create or update the task
			let result;
			if (editMode && taskData?.id) {
				result = await updateTask(taskData.id, formData);
			} else {
				result = await createTask(formData);
			}

			if (result.success) {
				// If we uploaded an image and created a task successfully, save the image record
				if (uploadResult && uploadResult.data && result.data?.id) {
					console.log('💾 [TaskCreate] Saving image record to task_images table...');
					try {
						// Import the db module for direct database access
						const { db } = await import('$lib/utils/supabase');
						
						const imageRecord = {
							task_id: result.data.id,
							file_name: imageFile.name,
							file_size: imageFile.size,
							file_type: imageFile.type,
							file_url: uploadResult.data.publicUrl,
							image_type: 'task_creation',
							uploaded_by: $auth?.user?.id || formData.created_by,
							uploaded_by_name: $auth?.user?.username || 'Unknown User'
						};
						
						console.log('📝 [TaskCreate] Creating image record:', imageRecord);
						const imageInsertResult = await db.taskImages.create(imageRecord);
						
						if (imageInsertResult.error) {
							console.error('❌ [TaskCreate] Failed to save image record:', imageInsertResult.error);
							// Don't fail the task creation if image record fails, just warn
							notifications.add({
								type: 'warning',
								message: 'Task created successfully, but failed to save image reference',
								duration: 4000
							});
						} else {
							console.log('✅ [TaskCreate] Image record saved successfully');
						}
					} catch (imageError) {
						console.error('❌ [TaskCreate] Error saving image record:', imageError);
						// Don't fail the task creation if image record fails, just warn
						notifications.add({
							type: 'warning',
							message: 'Task created successfully, but failed to save image reference',
							duration: 4000
						});
					}
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
			console.error(`Error ${editMode ? 'updating' : 'creating'} task:`, error);
			const errorMsg = 'An unexpected error occurred';
			
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

				<!-- Upload Image (optional) -->
				<div>
					<label for="image-upload" class="block text-sm font-medium text-gray-700 mb-2">
						Upload Image (optional)
					</label>
					<div class="space-y-3">
						{#if imagePreview}
							<div class="relative inline-block">
								<img src={imagePreview} alt="Preview" class="w-32 h-32 object-cover rounded-lg" />
							</div>
						{/if}
						<input
							id="image-upload"
							type="file"
							accept="image/*"
							on:change={handleImageUpload}
							class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
						/>
						{#if errors.image}
							<p class="text-sm text-red-600">{errors.image}</p>
						{/if}
					</div>
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