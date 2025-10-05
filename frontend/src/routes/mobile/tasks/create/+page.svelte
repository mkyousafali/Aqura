<script>
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import FileUpload from '$lib/components/common/FileUpload.svelte';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';

	let fileUploadComponent;
	let cameraInput;
	
	let formData = {
		title: '',
		description: '',
		created_by: ''
	};

	let errors = {};
	let isSubmitting = false;

	onMount(() => {
		if ($currentUser?.id) {
			formData.created_by = $currentUser.id;
		}
	});

	function openCamera() {
		if (cameraInput) {
			cameraInput.click();
		}
	}

	function handleCameraCapture(event) {
		const files = event.target.files;
		if (files && files.length > 0 && fileUploadComponent) {
			fileUploadComponent.addFiles(files);
			event.target.value = '';
		}
	}

	function handleUploadError(event) {
		console.log('Upload error:', event.detail);
	}

	function handleUploadComplete(event) {
		console.log('Upload complete:', event.detail);
	}

	const validateForm = () => {
		errors = {};
		if (!formData.title.trim()) {
			errors.title = 'Task title is required';
		}
		if (!formData.description.trim()) {
			errors.description = 'Task description is required';
		}
		return Object.keys(errors).length === 0;
	};

	const handleSubmit = async () => {
		if (!validateForm()) {
			notifications.add({
				type: 'error',
				message: 'Please fix the form errors before submitting.'
			});
			return;
		}

		isSubmitting = true;
		try {
			const taskData = {
				title: formData.title.trim(),
				description: formData.description.trim(),
				created_by: formData.created_by
			};

			const response = await fetch('/api/tasks', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(taskData)
			});

			if (!response.ok) {
				throw new Error('Failed to create task');
			}

			notifications.add({
				type: 'success',
				message: 'Task created successfully!'
			});

			goto('/mobile/tasks');
		} catch (error) {
			notifications.add({
				type: 'error',
				message: 'Failed to create task. Please try again.'
			});
		} finally {
			isSubmitting = false;
		}
	};

	const handleCancel = () => {
		goto('/mobile/tasks');
	};
</script>

<input
	bind:this={cameraInput}
	type="file"
	accept="image/*"
	capture="environment"
	style="display: none;"
	on:change={handleCameraCapture}
/>

<div class="mobile-page">
	<div class="mobile-header">
		<button class="header-btn" on:click={handleCancel}>
			Back
		</button>
		<h1>Create Task</h1>
		<button class="header-btn" on:click={handleSubmit} disabled={isSubmitting}>
			{isSubmitting ? 'Saving...' : 'Save'}
		</button>
	</div>

	<div class="mobile-content">
		<div class="form-group">
			<label for="title">Task Title *</label>
			<input
				id="title"
				type="text"
				bind:value={formData.title}
				placeholder="Enter task title"
				class:error={errors.title}
			/>
			{#if errors.title}
				<span class="error-text">{errors.title}</span>
			{/if}
		</div>

		<div class="form-group">
			<label for="description">Description *</label>
			<textarea
				id="description"
				bind:value={formData.description}
				placeholder="Describe the task"
				rows="4"
				class:error={errors.description}
			></textarea>
			{#if errors.description}
				<span class="error-text">{errors.description}</span>
			{/if}
		</div>

		<div class="form-group">
			<div class="upload-header">
				<h3>Attachments</h3>
				<button type="button" class="camera-btn" on:click={openCamera}>
					📷 Camera
				</button>
			</div>
			
			<FileUpload
				bind:this={fileUploadComponent}
				on:uploadError={handleUploadError}
				on:uploadComplete={handleUploadComplete}
			/>
		</div>
	</div>

	<div class="mobile-actions">
		<button class="action-btn secondary" on:click={handleCancel} disabled={isSubmitting}>
			Cancel
		</button>
		<button class="action-btn primary" on:click={handleSubmit} disabled={isSubmitting}>
			{isSubmitting ? 'Creating...' : 'Create Task'}
		</button>
	</div>
</div>

<style>
	.mobile-page {
		min-height: 100vh;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		display: flex;
		flex-direction: column;
	}

	.mobile-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		background: rgba(255, 255, 255, 0.1);
		backdrop-filter: blur(10px);
		color: white;
	}

	.header-btn {
		background: none;
		border: none;
		color: white;
		padding: 0.5rem;
		border-radius: 8px;
		cursor: pointer;
	}

	.header-btn:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	.mobile-content {
		flex: 1;
		padding: 1rem;
		padding-bottom: 6rem;
	}

	.form-group {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 1rem;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
	}

	.upload-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.camera-btn {
		background: #3B82F6;
		color: white;
		border: none;
		padding: 0.5rem 1rem;
		border-radius: 8px;
		cursor: pointer;
	}

	label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
	}

	input, textarea {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		box-sizing: border-box;
	}

	input.error, textarea.error {
		border-color: #ef4444;
	}

	.error-text {
		color: #ef4444;
		font-size: 0.875rem;
		margin-top: 0.25rem;
	}

	.mobile-actions {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		background: white;
		padding: 1.5rem;
		display: flex;
		gap: 1rem;
	}

	.action-btn {
		flex: 1;
		padding: 1rem;
		border: none;
		border-radius: 12px;
		font-weight: 600;
		cursor: pointer;
	}

	.action-btn.secondary {
		background: #f3f4f6;
		color: #374151;
	}

	.action-btn.primary {
		background: #3B82F6;
		color: white;
	}

	.action-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>