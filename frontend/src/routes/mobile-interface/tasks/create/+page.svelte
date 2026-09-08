<script>
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { notifications } from '$lib/stores/notifications';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { locale, getTranslation } from '$lib/i18n';

	let cameraInput;
	let fileInput;
	let attachedFiles = [];
	
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
		if (files && files.length > 0) {
			attachedFiles = [...attachedFiles, ...Array.from(files)];
		}
		event.target.value = '';
	}

	function handleFileSelect(event) {
		const files = event.target.files;
		if (files && files.length > 0) {
			attachedFiles = [...attachedFiles, ...Array.from(files)];
		}
		event.target.value = '';
	}

	function removeAttachedFile(index) {
		attachedFiles = attachedFiles.filter((_, i) => i !== index);
	}

	function openFilePicker() {
		if (fileInput) fileInput.click();
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

<input
	bind:this={fileInput}
	type="file"
	accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.txt"
	multiple
	style="display: none;"
	on:change={handleFileSelect}
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
			<label>{getTranslation('mobile.createContent.attachments')}</label>
			<div class="attachment-buttons">
				<button type="button" class="attach-btn" on:click={openCamera}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
						<circle cx="12" cy="13" r="4"/>
					</svg>
					{getTranslation('mobile.createContent.camera')}
				</button>
				<button type="button" class="attach-btn" on:click={openFilePicker}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>
					</svg>
					{getTranslation('mobile.createContent.chooseFiles')}
				</button>
			</div>

			{#if attachedFiles.length > 0}
				<div class="attached-files">
					{#each attachedFiles as file, index}
						<div class="attached-file-chip">
							<span class="file-chip-name">{file.name}</span>
							<button class="file-chip-remove" on:click={() => removeAttachedFile(index)}>&times;</button>
						</div>
					{/each}
				</div>
			{/if}
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
		padding: 0.5rem;
	}

	.form-group {
		background: white;
		border-radius: 6px;
		padding: 0.6rem;
		margin-bottom: 0.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
	}

	.attachment-buttons {
		display: flex;
		gap: 0.4rem;
	}

	.attach-btn {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.6rem;
		background: #F3F4F6;
		border: 1px solid #D1D5DB;
		border-radius: 5px;
		font-size: 0.72rem;
		font-weight: 500;
		color: #374151;
		cursor: pointer;
		transition: all 0.15s;
	}

	.attach-btn:hover {
		background: #E5E7EB;
		border-color: #9CA3AF;
	}

	.attached-files {
		display: flex;
		flex-wrap: wrap;
		gap: 0.3rem;
		margin-top: 0.4rem;
	}

	.attached-file-chip {
		display: inline-flex;
		align-items: center;
		gap: 0.2rem;
		background: #EFF6FF;
		border: 1px solid #BFDBFE;
		color: #1E40AF;
		padding: 0.15rem 0.4rem;
		border-radius: 9999px;
		font-size: 0.65rem;
	}

	.file-chip-name {
		max-width: 120px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.file-chip-remove {
		background: none;
		border: none;
		color: #3B82F6;
		font-size: 0.85rem;
		line-height: 1;
		cursor: pointer;
		padding: 0;
	}

	.file-chip-remove:hover {
		color: #EF4444;
	}

	label {
		display: block;
		margin-bottom: 0.3rem;
		font-weight: 500;
		font-size: 0.78rem;
	}

	input, textarea {
		width: 100%;
		padding: 0.4rem 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 5px;
		box-sizing: border-box;
		font-size: 0.78rem;
	}

	input.error, textarea.error {
		border-color: #ef4444;
	}

	.error-text {
		color: #ef4444;
		font-size: 0.7rem;
		margin-top: 0.15rem;
	}

	.inline-actions {
		background: white;
		padding: 0.5rem;
		border-top: 1px solid #e5e7eb;
		border-radius: 6px;
		margin-top: 0.5rem;
		display: flex;
		gap: 0.5rem;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
	}

	.action-btn {
		flex: 1;
		padding: 0.5rem;
		border: none;
		border-radius: 6px;
		font-weight: 600;
		font-size: 0.78rem;
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
