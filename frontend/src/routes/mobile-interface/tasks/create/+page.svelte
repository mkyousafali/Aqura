<script>
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import FileUpload from '$lib/components/common/FileUpload.svelte';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { locale, getTranslation } from '$lib/i18n';

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
			errors.title = getTranslation('mobile.createContent.errors.titleRequired');
		}
		if (!formData.description.trim()) {
			errors.description = getTranslation('mobile.createContent.errors.descriptionRequired');
		}
		return Object.keys(errors).length === 0;
	};

	const handleSubmit = async () => {
		if (!validateForm()) {
			notifications.add({
				type: 'error',
				message: getTranslation('mobile.createContent.errors.fixFormErrors')
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
				message: getTranslation('mobile.createContent.success.taskCreated')
			});

			goto('/mobile-interface/tasks');
		} catch (error) {
			notifications.add({
				type: 'error',
				message: getTranslation('mobile.createContent.errors.createFailedTryAgain')
			});
		} finally {
			isSubmitting = false;
		}
	};

	const handleCancel = () => {
		goto('/mobile-interface/tasks');
	};
</script>

<svelte:head>
	<title>{getTranslation('mobile.createContent.title')}</title>
</svelte:head>

<input
	bind:this={cameraInput}
	type="file"
	accept="image/*"
	capture="environment"
	style="display: none;"
	on:change={handleCameraCapture}
/>

<div class="mobile-page">
	<div class="mobile-content">
		<div class="form-group">
			<label for="title">{getTranslation('mobile.createContent.taskTitle')} *</label>
			<input
				id="title"
				type="text"
				bind:value={formData.title}
				placeholder={getTranslation('mobile.createContent.taskTitlePlaceholder')}
				class:error={errors.title}
			/>
			{#if errors.title}
				<span class="error-text">{errors.title}</span>
			{/if}
		</div>

		<div class="form-group">
			<label for="description">{getTranslation('mobile.createContent.description')} *</label>
			<textarea
				id="description"
				bind:value={formData.description}
				placeholder={getTranslation('mobile.createContent.descriptionPlaceholder')}
				rows="4"
				class:error={errors.description}
			></textarea>
			{#if errors.description}
				<span class="error-text">{errors.description}</span>
			{/if}
		</div>

		<div class="form-group">
			<div class="upload-header">
				<h3>{getTranslation('mobile.createContent.attachments')}</h3>
				<button type="button" class="camera-btn" on:click={openCamera}>
					📷 {getTranslation('mobile.createContent.camera')}
				</button>
			</div>
			
			<FileUpload
				bind:this={fileUploadComponent}
				label={getTranslation('mobile.createContent.uploadFile')}
				placeholder={getTranslation('mobile.createContent.chooseFiles')}
				hint={getTranslation('mobile.createContent.supportedFormats')}
				on:uploadError={handleUploadError}
				on:uploadComplete={handleUploadComplete}
			/>
		</div>

		<!-- Inline Action Buttons -->
		<div class="inline-actions">
			<button class="action-btn secondary" on:click={handleCancel} disabled={isSubmitting}>
				{getTranslation('mobile.createContent.actions.cancel')}
			</button>
			<button class="action-btn primary" on:click={handleSubmit} disabled={isSubmitting}>
				{isSubmitting ? getTranslation('mobile.createContent.actions.creating') : getTranslation('mobile.createContent.actions.createTask')}
			</button>
		</div>
	</div>
</div>

<style>
	.mobile-page {
		min-height: 100vh;
		min-height: 100dvh;
		background: #F8FAFC;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
	}

	.mobile-content {
		flex: 1;
		padding: 1rem;
	}

	.form-group {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
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

	.inline-actions {
		background: white;
		padding: 1.5rem;
		border-top: 1px solid #e5e7eb;
		border-radius: 16px;
		margin-top: 1rem;
		display: flex;
		gap: 1rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
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
