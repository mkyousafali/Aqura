<script>
	import { createEventDispatcher } from 'svelte';
	import { uploadToSupabase } from '$lib/utils/supabase';
	import { createTask, updateTask } from '$lib/stores/taskStore';
	
	// Props
	export let editMode = false;
	export let taskData = null;
	export let onTaskUpdated = null;
	
	const dispatch = createEventDispatcher();
	
	// Time conversion functions
	const convertTo12Hour = (time24h) => {
		if (!time24h || time24h.trim() === '') {
			return '';
		}
		
		// Handle time formats like "14:30:00" or "14:30"
		const timeParts = time24h.split(':');
		let hours = parseInt(timeParts[0], 10);
		const minutes = timeParts[1] || '00';
		
		const modifier = hours >= 12 ? 'PM' : 'AM';
		
		if (hours === 0) {
			hours = 12; // 00:xx becomes 12:xx AM
		} else if (hours > 12) {
			hours = hours - 12; // 13-23 becomes 1-11 PM
		}
		
		return `${hours}:${minutes} ${modifier}`;
	};
	
	// Form data - initialize with task data if in edit mode
	let formData = {
		title: editMode && taskData ? taskData.title : '',
		description: editMode && taskData ? taskData.description : '',
		priority: editMode && taskData ? taskData.priority : 'medium',
		due_date: editMode && taskData && taskData.due_date ? new Date(taskData.due_date).toISOString().split('T')[0] : '',
		due_time: editMode && taskData && taskData.due_time ? convertTo12Hour(taskData.due_time) : '',
		require_task_finished: editMode && taskData ? taskData.require_task_finished : false,
		require_photo_upload: editMode && taskData ? taskData.require_photo_upload : false,
		require_erp_reference: editMode && taskData ? taskData.require_erp_reference : false,
		can_escalate: editMode && taskData ? taskData.can_escalate : false,
		can_reassign: editMode && taskData ? taskData.can_reassign : false,
		assigned_to: '',
		image_url: ''
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
			priority: taskData.priority || 'medium',
			due_date: taskData.due_date ? new Date(taskData.due_date).toISOString().split('T')[0] : '',
			due_time: taskData.due_time ? convertTo12Hour(taskData.due_time) : '',
			require_task_finished: taskData.require_task_finished || false,
			require_photo_upload: taskData.require_photo_upload || false,
			require_erp_reference: taskData.require_erp_reference || false,
			can_escalate: taskData.can_escalate || false,
			can_reassign: taskData.can_reassign || false,
			assigned_to: '',
			image_url: taskData.image_url || ''
		};
	}
	
	// Priority options
	const priorityOptions = [
		{ value: 'low', label: 'Low', color: 'bg-green-100 text-green-800' },
		{ value: 'medium', label: 'Medium', color: 'bg-yellow-100 text-yellow-800' },
		{ value: 'high', label: 'High', color: 'bg-red-100 text-red-800' }
	];
	
	// Time options (12-hour format with AM/PM)
	const generateTimeOptions = () => {
		const times = [];
		for (let hour = 1; hour <= 12; hour++) {
			for (let minute of ['00', '15', '30', '45']) {
				times.push(`${hour}:${minute} AM`);
			}
		}
		for (let hour = 1; hour <= 12; hour++) {
			for (let minute of ['00', '15', '30', '45']) {
				times.push(`${hour}:${minute} PM`);
			}
		}
		return times;
	};
	
	const timeOptions = generateTimeOptions();
	
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
		formData.image_url = '';
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
		
		if (!formData.due_date) {
			errors.due_date = 'Due date is required';
		}
		
		if (!formData.due_time) {
			errors.due_time = 'Due time is required';
		}
		
		// Validate that at least one completion criteria is selected
		if (!formData.require_task_finished && !formData.require_photo_upload && !formData.require_erp_reference) {
			errors.completion_criteria = 'At least one completion criteria must be selected';
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
			// Upload image if present
			if (imageFile) {
				const uploadResult = await uploadToSupabase(imageFile, 'task-images');
				if (uploadResult.error) {
					errors.image = 'Failed to upload image';
					return;
				}
				formData.image_url = uploadResult.data.publicUrl;
			}
			
			// Convert 12-hour time to 24-hour format for database
			const convertTo24Hour = (time12h) => {
				if (!time12h || time12h.trim() === '') {
					return null; // Return null for empty time
				}
				
				const [time, modifier] = time12h.split(' ');
				let [hours, minutes] = time.split(':');
				
				// Convert to 24-hour format
				if (hours === '12') {
					hours = modifier === 'AM' ? '00' : '12';
				} else if (modifier === 'PM') {
					hours = (parseInt(hours, 10) + 12).toString();
				}
				
				// Return only time portion (HH:MM:SS)
				return `${hours.toString().padStart(2, '0')}:${minutes}:00`;
			};
			
			const convertedTime = convertTo24Hour(formData.due_time);
			const taskSubmitData = {
				...formData,
				due_time: convertedTime
			};
			
			// Create or update the task
			let result;
			if (editMode && taskData?.id) {
				result = await updateTask(taskData.id, taskSubmitData);
			} else {
				result = await createTask(taskSubmitData);
			}
			
			if (result.success) {
				if (editMode) {
					dispatch('taskUpdated', result.data);
					if (onTaskUpdated) {
						onTaskUpdated(result.data);
					}
				} else {
					dispatch('taskCreated', result.data);
				}
				dispatch('close');
			} else {
				errors.submit = result.error || `Failed to ${editMode ? 'update' : 'create'} task`;
			}
		} catch (error) {
			console.error(`Error ${editMode ? 'updating' : 'creating'} task:`, error);
			errors.submit = 'An unexpected error occurred';
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
				<button
					on:click={handleClose}
					class="text-gray-400 hover:text-gray-600 transition-colors"
				>
					<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
					</svg>
				</button>
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
								<button
									type="button"
									on:click={removeImage}
									class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm hover:bg-red-600 transition-colors"
								>
									×
								</button>
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

				<!-- Priority Section -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-2">
						Priority *
					</label>
					<div class="grid grid-cols-3 gap-3">
						{#each priorityOptions as option}
							<label class="relative cursor-pointer">
								<input
									type="radio"
									name="priority"
									value={option.value}
									bind:group={formData.priority}
									class="sr-only"
								/>
								<div
									class="p-3 text-center rounded-lg border-2 transition-all {formData.priority === option.value
										? 'border-blue-500 ' + option.color
										: 'border-gray-200 hover:border-gray-300'}"
								>
									<span class="font-medium">{option.label}</span>
								</div>
							</label>
						{/each}
					</div>
				</div>

				<!-- Date and Time -->
				<div class="grid grid-cols-2 gap-4">
					<!-- Date -->
					<div>
						<label for="due-date" class="block text-sm font-medium text-gray-700 mb-2">
							Date *
						</label>
						<input
							id="due-date"
							type="date"
							bind:value={formData.due_date}
							min={new Date().toISOString().split('T')[0]}
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							class:border-red-500={errors.due_date}
						/>
						{#if errors.due_date}
							<p class="mt-1 text-sm text-red-600">{errors.due_date}</p>
						{/if}
					</div>

					<!-- Time -->
					<div>
						<label for="due-time" class="block text-sm font-medium text-gray-700 mb-2">
							Time (12-hour format with AM/PM) *
						</label>
						<select
							id="due-time"
							bind:value={formData.due_time}
							class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
							class:border-red-500={errors.due_time}
						>
							<option value="">Select time</option>
							{#each timeOptions as time}
								<option value={time}>{time}</option>
							{/each}
						</select>
						{#if errors.due_time}
							<p class="mt-1 text-sm text-red-600">{errors.due_time}</p>
						{/if}
					</div>
				</div>

				<!-- Completion Criteria -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-3">
						Completion Criteria *
					</label>
					<div class="space-y-3">
						<label class="flex items-center space-x-3 cursor-pointer">
							<input
								type="checkbox"
								bind:checked={formData.require_task_finished}
								class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
							/>
							<span class="text-sm text-gray-700">☐ Task finished</span>
						</label>
						
						<label class="flex items-center space-x-3 cursor-pointer">
							<input
								type="checkbox"
								bind:checked={formData.require_photo_upload}
								class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
							/>
							<span class="text-sm text-gray-700">☐ Upload photo or take photo</span>
						</label>
						
						<label class="flex items-center space-x-3 cursor-pointer">
							<input
								type="checkbox"
								bind:checked={formData.require_erp_reference}
								class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
							/>
							<span class="text-sm text-gray-700">☐ ERP reference number</span>
						</label>
					</div>
					{#if errors.completion_criteria}
						<p class="mt-1 text-sm text-red-600">{errors.completion_criteria}</p>
					{/if}
				</div>

				<!-- Additional Options -->
				<div>
					<label class="block text-sm font-medium text-gray-700 mb-3">
						Additional Options
					</label>
					<div class="space-y-3">
						<label class="flex items-center space-x-3 cursor-pointer">
							<input
								type="checkbox"
								bind:checked={formData.can_escalate}
								class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
							/>
							<span class="text-sm text-gray-700">Can Escalate Task</span>
						</label>
						
						<label class="flex items-center space-x-3 cursor-pointer">
							<input
								type="checkbox"
								bind:checked={formData.can_reassign}
								class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
							/>
							<span class="text-sm text-gray-700">Can Reassign Task</span>
						</label>
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
	
	/* Radio button styling for priority */
	input[type="radio"]:checked + div {
		transform: scale(1.02);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}
</style>